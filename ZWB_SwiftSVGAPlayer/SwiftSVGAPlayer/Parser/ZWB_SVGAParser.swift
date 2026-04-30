// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGAParser.swift

import Foundation

/// 解析协议
protocol SVGAParsing: AnyObject {
    func parse(_ source: SVGASource) async throws -> SVGAVideo
}

/// 默认解析器实现（nonisolated，所有操作在后台执行）
final class SVGAParser: SVGAParsing {

    static let shared = SVGAParser()

    // 所有依赖都是 nonisolated 安全的
    private let loader: SVGAResourceLoader
    private let archiveReader: SVGAArchiveReading
    private let binaryDecoder: SVGABinaryDecoder
    private let jsonDecoder: SVGAJSONDecoder
    private let memoryCache: SVGAVideoCaching
    private let keyGenerator: SVGACacheKeyGenerating
    private let coordinator: SVGALoadCoordinator

    init(
        downloader: SVGADownloading = URLSessionSVGADownloader.shared,
        diskCache: SVGADiskCache = .shared,
        memoryCache: SVGAVideoCaching = SVGAMemoryCache.shared,
        keyGenerator: SVGACacheKeyGenerating = SVGACacheKeyGenerator.shared
    ) {
        self.loader        = SVGAResourceLoader(downloader: downloader,
                                                diskCache: diskCache,
                                                keyGenerator: keyGenerator)
        self.archiveReader = SVGAArchiveReader()
        self.binaryDecoder = SVGABinaryDecoder()
        self.jsonDecoder   = SVGAJSONDecoder()
        self.memoryCache   = memoryCache
        self.keyGenerator  = keyGenerator
        self.coordinator   = SVGALoadCoordinator()
    }

    // MARK: - SVGAParsing

    nonisolated func parse(_ source: SVGASource) async throws -> SVGAVideo {
        let cacheKey = keyGenerator.cacheKey(for: source)

        // 内存缓存命中
        if let key = cacheKey, let cached = memoryCache.video(forKey: key) {
            svgaLogDebug("Memory cache hit for key: \(key)")
            return cached
        }

        // 通过 coordinator 防止重复解析同一 key
        let video: SVGAVideo
        if let key = cacheKey {
            // 用 unowned 避免 Sendable 警告，parser 生命周期由调用方保证
            let loader    = self.loader
            let archiver  = self.archiveReader
            let binary    = self.binaryDecoder
            let json      = self.jsonDecoder
            video = try await coordinator.load(key: key) {
                try await SVGAParser.doParse(
                    source: source,
                    loader: loader,
                    archiveReader: archiver,
                    binaryDecoder: binary,
                    jsonDecoder: json
                )
            }
        } else {
            video = try await SVGAParser.doParse(
                source: source,
                loader: loader,
                archiveReader: archiveReader,
                binaryDecoder: binaryDecoder,
                jsonDecoder: jsonDecoder
            )
        }

        // 写入内存缓存
        if let key = cacheKey {
            memoryCache.store(video, forKey: key)
        }
        return video
    }

    // MARK: - Internal parse pipeline（static，无 self 捕获）

    private static nonisolated func doParse(
        source: SVGASource,
        loader: SVGAResourceLoader,
        archiveReader: SVGAArchiveReading,
        binaryDecoder: SVGABinaryDecoder,
        jsonDecoder: SVGAJSONDecoder
    ) async throws -> SVGAVideo {
        svgaLogInfo("Parsing source: \(source.debugDescription)")

        let rawData = try await loader.loadData(from: source)
        guard !rawData.isEmpty else { throw SVGAError.invalidData }

        // 判断格式：
        // 1. ZIP 包（PK 头 50 4B 03 04）
        // 2. zlib 直接压缩的 protobuf（78 9C / 78 01 / 78 DA 头）
        // 3. 未压缩的 protobuf（直接解析）

        let bytes = [UInt8](rawData.prefix(4))

        // ZIP 格式
        if bytes.count >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B {
            svgaLogDebug("Detected ZIP format")
            let entries: [String: Data]
            do {
                entries = try archiveReader.readEntries(from: rawData)
            } catch {
                throw SVGAError.unzipFailed(error.localizedDescription)
            }
            svgaLogDebug("ZIP entries: \(entries.keys.sorted())")
            return try decodeFromEntries(entries, binaryDecoder: binaryDecoder, jsonDecoder: jsonDecoder)
        }

        // zlib 直接压缩（78 01 / 78 9C / 78 DA）
        if bytes.count >= 2 && bytes[0] == 0x78 &&
            (bytes[1] == 0x01 || bytes[1] == 0x9C || bytes[1] == 0xDA || bytes[1] == 0x5E) {
            svgaLogDebug("Detected zlib-compressed protobuf")
            let inflated: Data
            do {
                inflated = try rawData.zlibInflated()
            } catch {
                throw SVGAError.unzipFailed("zlib inflate failed: \(error)")
            }
            svgaLogDebug("Inflated size: \(inflated.count) bytes")
            return try binaryDecoder.decode(binaryData: inflated, imageEntries: [:])
        }

        // 尝试直接当 protobuf 解析（未压缩）
        svgaLogDebug("Trying raw protobuf decode")
        do {
            return try binaryDecoder.decode(binaryData: rawData, imageEntries: [:])
        } catch {
            throw SVGAError.missingMovieFile
        }
    }

    private static nonisolated func decodeFromEntries(
        _ entries: [String: Data],
        binaryDecoder: SVGABinaryDecoder,
        jsonDecoder: SVGAJSONDecoder
    ) throws -> SVGAVideo {
        let imageEntries = entries.filter { isImageEntry($0.key) }
        let audioEntries = entries.filter { isAudioEntry($0.key) }
        let allMediaEntries = imageEntries.merging(audioEntries) { a, _ in a }

        if let binaryData = entries["movie.binary"] {
            svgaLogInfo("Decoding movie.binary (Protobuf)")
            return try binaryDecoder.decode(binaryData: binaryData, imageEntries: allMediaEntries)
        }
        if let specData = entries["movie.spec"] {
            svgaLogInfo("Decoding movie.spec (JSON)")
            return try jsonDecoder.decode(specData: specData, imageEntries: allMediaEntries)
        }
        throw SVGAError.missingMovieFile
    }

    private static nonisolated func isImageEntry(_ key: String) -> Bool {
        ["png", "jpg", "jpeg", "gif", "webp"].contains((key as NSString).pathExtension.lowercased())
    }

    private static nonisolated func isAudioEntry(_ key: String) -> Bool {
        ["mp3", "wav", "aac", "m4a"].contains((key as NSString).pathExtension.lowercased())
    }
}
