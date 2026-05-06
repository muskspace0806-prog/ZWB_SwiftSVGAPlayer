// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Cache/ZWB_SVGAMemoryCache.swift

import Foundation

/// SVGAVideo 内存缓存协议
protocol SVGAVideoCaching: AnyObject {
    func video(forKey key: String) -> SVGAVideo?
    func store(_ video: SVGAVideo, forKey key: String)
    func removeVideo(forKey key: String)
    func removeAllVideos()
}

/// 基于 NSCache 的内存缓存实现（线程安全）
final class SVGAMemoryCache: SVGAVideoCaching {
    static let shared = SVGAMemoryCache()

    private let cache = NSCache<NSString, SVGAVideoBox>()

    var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }

    init(countLimit: Int = 20) {
        cache.countLimit = countLimit
        cache.name = "com.swiftsvgaplayer.memorycache"
    }

    nonisolated func video(forKey key: String) -> SVGAVideo? {
        cache.object(forKey: key as NSString)?.video
    }

    nonisolated func store(_ video: SVGAVideo, forKey key: String) {
        cache.setObject(SVGAVideoBox(video), forKey: key as NSString)
    }

    nonisolated func removeVideo(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    nonisolated func removeAllVideos() {
        cache.removeAllObjects()
    }
}

private final class SVGAVideoBox {
    let video: SVGAVideo
    init(_ video: SVGAVideo) { self.video = video }
}
