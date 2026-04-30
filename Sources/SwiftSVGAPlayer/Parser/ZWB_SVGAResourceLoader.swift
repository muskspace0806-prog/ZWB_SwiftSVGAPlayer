// Sources/SwiftSVGAPlayer/Parser/ZWB_SVGAResourceLoader.swift
// 负责从各种 SVGASource 读取原始 Data

import Foundation

final class SVGAResourceLoader {

    private let downloader: SVGADownloading
    private let diskCache: SVGADiskCache
    private let keyGenerator: SVGACacheKeyGenerating

    init(
        downloader: SVGADownloading = URLSessionSVGADownloader.shared,
        diskCache: SVGADiskCache = .shared,
        keyGenerator: SVGACacheKeyGenerating = SVGACacheKeyGenerator.shared
    ) {
        self.downloader   = downloader
        self.diskCache    = diskCache
        self.keyGenerator = keyGenerator
    }

    /// 从 source 加载原始 .svga Data
    func loadData(from source: SVGASource) async throws -> Data {
        switch source {
        case .url(let url):
            return try await loadRemote(url: url, cacheKey: keyGenerator.cacheKey(for: source))

        case .fileURL(let url):
            return try loadFile(at: url)

        case .data(let data, _):
            guard !data.isEmpty else { throw SVGAError.invalidData }
            return data

        case .named(let name, let bundle):
            return try loadNamed(name, bundle: bundle)
        }
    }

    // MARK: - Private

    private func loadRemote(url: URL, cacheKey: String?) async throws -> Data {
        // 先查磁盘缓存
        if let key = cacheKey, let cached = diskCache.data(forKey: key) {
            svgaLogDebug("Disk cache hit for key: \(key)")
            return cached
        }
        // 下载
        let data = try await downloader.download(from: url)
        // 写入磁盘缓存
        if let key = cacheKey {
            diskCache.store(data, forKey: key)
        }
        return data
    }

    private func loadFile(at url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SVGAError.fileNotFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SVGAError.invalidData
        }
    }

    private func loadNamed(_ name: String, bundle: Bundle) throws -> Data {
        // 先尝试带 .svga 扩展名
        if let url = bundle.url(forResource: name, withExtension: "svga") {
            return try loadFile(at: url)
        }
        // 再尝试不带扩展名（文件名本身含扩展名）
        if let url = bundle.url(forResource: name, withExtension: nil) {
            return try loadFile(at: url)
        }
        throw SVGAError.fileNotFound
    }
}
