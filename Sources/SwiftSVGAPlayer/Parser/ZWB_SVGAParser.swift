// Sources/SwiftSVGAPlayer/Parser/ZWB_SVGAParser.swift
// 顶层解析器：SVGASource → SVGAVideo

import Foundation

/// 解析协议
public protocol SVGAParsing {
    func parse(_ source: SVGASource) async throws -> SVGAVideo
}

/// 默认解析器实现
public final class SVGAParser: SVGAParsing {

    public static let shared = SVGAParser()

    private let loader: SVGAResourceLoader
    private let archiveReader: SVGAArchiveReading
    private let binaryDecoder: SVGABinaryDecoder
    private let jsonDecoder: SVGAJSONDecoder
    private let memoryCache: SVGAVideoCaching
    private let keyGenerator: SVGACacheKeyGenerating
    private let coordinator: SVGALoadCoordinator

    public init(
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

    public func parse(_ source: SVGASource) async throws -> SVGAVideo {
        let cacheKey = keyGenerator.cacheKey(for: source)

        // 内存缓存命中
        if let key = cacheKey, let cached = memoryCache.video(forKey: key) {
            svgaLogDebug("Memory cache hit for key: \(key)")
            return cached
        }

        // 通过 coordinator 防止重复解析同一 key
        let video: SVGAVideo
        if let key = cacheKey {
            video = try await coordinator.load(key: key) { [weak self] in
                guard let self = self else { throw SVGAError.cancelled }
                return try await self.doParse(source: source)
            }
        } else {
            video = try await doParse(source: source)
        }

        // 写入内存缓存
        if let key = cacheKey {
            memoryCache.store(video, forKey: key)
        }
        return video
    }

    // MARK: - Internal parse pipeline

    private func doParse(source: SVGASource) async throws -> SVGAVideo {
        svgaLogInfo("Parsing source: \(source.debugDescription)")

        // 1. 加载原始 Data
        let rawData = try await loader.loadData(from: source)
        guard !rawData.isEmpty else { throw SVGAError.invalidData }

        // 2. 解压 ZIP
        let entries: [String: Data]
        do {
            entries = try archiveReader.readEntries(from: rawData)
        } catch {
            throw SVGAError.unzipFailed(error.localizedDescription)
        }

        svgaLogDebug("ZIP entries: \(entries.keys.sorted())")

        // 3. 分离图片/音频 entries
        let imageEntries = entries.filter { isImageEntry($0.key) }
        let audioEntries = entries.filter { isAudioEntry($0.key) }
        let allMediaEntries = imageEntries.merging(audioEntries) { a, _ in a }

        // 4. 优先解析 movie.binary（Protobuf）
        if let binaryData = entries["movie.binary"] {
            svgaLogInfo("Decoding movie.binary (Protobuf)")
            return try binaryDecoder.decode(binaryData: binaryData, imageEntries: allMediaEntries)
        }

        // 5. 降级解析 movie.spec（JSON）
        if let specData = entries["movie.spec"] {
            svgaLogInfo("Decoding movie.spec (JSON)")
            return try jsonDecoder.decode(specData: specData, imageEntries: allMediaEntries)
        }

        throw SVGAError.missingMovieFile
    }

    // MARK: - Helpers

    private func isImageEntry(_ key: String) -> Bool {
        let ext = (key as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp"].contains(ext)
    }

    private func isAudioEntry(_ key: String) -> Bool {
        let ext = (key as NSString).pathExtension.lowercased()
        return ["mp3", "wav", "aac", "m4a"].contains(ext)
    }
}
