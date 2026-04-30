// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGAResourceLoader.swift

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

    nonisolated func loadData(from source: SVGASource) async throws -> Data {
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

    private nonisolated func loadRemote(url: URL, cacheKey: String?) async throws -> Data {
        if let key = cacheKey, let cached = diskCache.data(forKey: key) {
            svgaLogDebug("Disk cache hit for key: \(key)")
            return cached
        }
        let data = try await downloader.download(from: url)
        if let key = cacheKey {
            diskCache.store(data, forKey: key)
        }
        return data
    }

    private nonisolated func loadFile(at url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SVGAError.fileNotFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SVGAError.invalidData
        }
    }

    private nonisolated func loadNamed(_ name: String, bundle: Bundle) throws -> Data {
        // 1. 直接找（文件在 bundle 根目录）
        if let url = bundle.url(forResource: name, withExtension: "svga") {
            return try loadFile(at: url)
        }
        // 2. 不带扩展名找（文件名本身含扩展名）
        if let url = bundle.url(forResource: name, withExtension: nil) {
            return try loadFile(at: url)
        }
        // 3. 在子目录里递归搜索（文件放在 Resource/ 等子文件夹时）
        if let url = searchInSubdirectories(name: name, extension: "svga", bundle: bundle) {
            return try loadFile(at: url)
        }
        throw SVGAError.fileNotFound
    }

    private nonisolated func searchInSubdirectories(name: String, extension ext: String, bundle: Bundle) -> URL? {
        guard let bundleURL = bundle.resourceURL else { return nil }
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let targetName = "\(name).\(ext)"
        for case let url as URL in enumerator {
            if url.lastPathComponent == targetName {
                return url
            }
            // 也匹配不带扩展名的情况
            if url.lastPathComponent == name {
                return url
            }
        }
        return nil
    }
}
