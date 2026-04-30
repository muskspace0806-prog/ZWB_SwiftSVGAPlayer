// Sources/SwiftSVGAPlayer/Cache/ZWB_SVGAMemoryCache.swift

import Foundation

/// SVGAVideo 内存缓存协议
public protocol SVGAVideoCaching: AnyObject {
    func video(forKey key: String) -> SVGAVideo?
    func store(_ video: SVGAVideo, forKey key: String)
    func removeVideo(forKey key: String)
    func removeAllVideos()
}

/// 基于 NSCache 的内存缓存实现
public final class SVGAMemoryCache: SVGAVideoCaching {
    public static let shared = SVGAMemoryCache()

    private let cache = NSCache<NSString, SVGAVideoBox>()

    /// 最大缓存条目数，默认 20
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }

    public init(countLimit: Int = 20) {
        cache.countLimit = countLimit
        cache.name = "com.swiftsvgaplayer.memorycache"
    }

    public func video(forKey key: String) -> SVGAVideo? {
        return cache.object(forKey: key as NSString)?.video
    }

    public func store(_ video: SVGAVideo, forKey key: String) {
        cache.setObject(SVGAVideoBox(video), forKey: key as NSString)
    }

    public func removeVideo(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    public func removeAllVideos() {
        cache.removeAllObjects()
    }
}

/// NSCache 需要 class 类型，用 Box 包装 struct
private final class SVGAVideoBox {
    let video: SVGAVideo
    init(_ video: SVGAVideo) { self.video = video }
}
