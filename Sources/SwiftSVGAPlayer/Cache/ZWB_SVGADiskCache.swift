// Sources/SwiftSVGAPlayer/Cache/ZWB_SVGADiskCache.swift

import Foundation

/// 原始 Data 磁盘缓存（缓存下载/读取到的 .svga 原始数据）
public final class SVGADiskCache {
    public static let shared = SVGADiskCache()

    private let directory: URL
    private let queue = DispatchQueue.svgaCache

    public init(directory: URL? = nil) {
        if let dir = directory {
            self.directory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.directory = caches.appendingPathComponent("com.swiftsvgaplayer.diskcache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    public func data(forKey key: String) -> Data? {
        let url = fileURL(for: key)
        return try? Data(contentsOf: url)
    }

    public func store(_ data: Data, forKey key: String) {
        let url = fileURL(for: key)
        queue.async {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func removeData(forKey key: String) {
        let url = fileURL(for: key)
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func removeAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let files = (try? FileManager.default.contentsOfDirectory(
                at: self.directory,
                includingPropertiesForKeys: nil
            )) ?? []
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    public func contains(key: String) -> Bool {
        return FileManager.default.fileExists(atPath: fileURL(for: key).path)
    }

    // MARK: - Private

    private func fileURL(for key: String) -> URL {
        // key 已经是 MD5 hex，直接用作文件名
        return directory.appendingPathComponent(key)
    }
}
