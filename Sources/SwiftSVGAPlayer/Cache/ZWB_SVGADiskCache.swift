// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Cache/ZWB_SVGADiskCache.swift

import Foundation

/// 原始 Data 磁盘缓存
final class SVGADiskCache {
    static let shared = SVGADiskCache()

    private let directory: URL
    private let queue = DispatchQueue(label: "com.swiftsvgaplayer.diskcache", qos: .utility)

    init(directory: URL? = nil) {
        if let dir = directory {
            self.directory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.directory = caches.appendingPathComponent("com.swiftsvgaplayer.diskcache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    nonisolated func data(forKey key: String) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    nonisolated func store(_ data: Data, forKey key: String) {
        let url = fileURL(for: key)
        queue.async {
            try? data.write(to: url, options: .atomic)
        }
    }

    nonisolated func removeData(forKey key: String) {
        let url = fileURL(for: key)
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated func removeAll() {
        let dir = directory
        queue.async {
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    nonisolated func contains(key: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: key).path)
    }

    private nonisolated func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key)
    }
}
