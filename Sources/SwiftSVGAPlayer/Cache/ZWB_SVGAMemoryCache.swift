// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Cache/ZWB_SVGAMemoryCache.swift

import UIKit

/// SVGAVideo 内存缓存协议
protocol SVGAVideoCaching: AnyObject {
    func video(forKey key: String) -> SVGAVideo?
    func store(_ video: SVGAVideo, forKey key: String)
    func removeVideo(forKey key: String)
    func removeAllVideos()
}

/// 基于 NSCache 的内存缓存实现（线程安全）
///
/// 1.0.3 起淘汰维度由「个数」改为「内存成本（字节）」：
/// - `NSCache.totalCostLimit` 控制总内存上限，`store` 时按解码位图字节数计 cost；
/// - 小图标可缓存很多个，大动画自动少缓存几个，避免「正好超过 N 个」就反复重解码或 OOM；
/// - 收到系统内存警告时自动清空，避免被系统杀进程。
///
/// 仍保留 `countLimit` 供需要的场景使用（默认 0 = 不按个数限制，只受 cost 约束）。
public final class SVGAMemoryCache: SVGAVideoCaching {
    /// 全局共享实例
    public static let shared = SVGAMemoryCache()

    /// 底层缓存（key = 资源 MD5，value = 装箱后的 SVGAVideo）
    private let cache = NSCache<NSString, SVGAVideoBox>()

    /// 默认内存成本上限：物理内存的 1/8，且不超过 256MB，不低于 32MB
    private static func defaultCostLimit() -> Int {
        let physical = Int(ProcessInfo.processInfo.physicalMemory)
        let oneEighth = physical / 8
        let upperBound = 256 * 1024 * 1024   // 256MB 绝对上限
        let lowerBound = 32 * 1024 * 1024    // 32MB 兜底下限
        return Swift.min(Swift.max(oneEighth, lowerBound), upperBound)
    }

    /// 内存成本上限（字节）。设为 0 表示不限制成本
    public var costLimit: Int {
        get { cache.totalCostLimit }
        set { cache.totalCostLimit = newValue }
    }

    /// 缓存个数上限。设为 0 表示不按个数限制（默认，仅受 costLimit 约束）
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }

    /// 初始化
    /// - Parameters:
    ///   - costLimit: 内存成本上限（字节），传 nil 使用默认值（物理内存 1/8，封顶 256MB）
    ///   - countLimit: 个数上限，默认 0 表示不限个数
    public init(costLimit: Int? = nil, countLimit: Int = 0) {
        cache.totalCostLimit = costLimit ?? SVGAMemoryCache.defaultCostLimit()
        cache.countLimit = countLimit
        cache.name = "com.swiftsvgaplayer.memorycache"
        registerMemoryWarningObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 读取缓存
    nonisolated func video(forKey key: String) -> SVGAVideo? {
        cache.object(forKey: key as NSString)?.video
    }

    /// 写入缓存（按解码位图字节数计 cost）
    nonisolated func store(_ video: SVGAVideo, forKey key: String) {
        let cost = video.estimatedMemoryCost
        cache.setObject(SVGAVideoBox(video), forKey: key as NSString, cost: cost)
    }

    /// 移除单个缓存
    nonisolated func removeVideo(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// 清空全部缓存
    nonisolated func removeAllVideos() {
        cache.removeAllObjects()
    }

    /// 监听系统内存警告，触发时清空内存缓存
    private func registerMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    /// 内存警告回调：清空内存缓存（磁盘缓存不受影响）
    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
        svgaLogWarning("Memory warning received, SVGA memory cache cleared")
    }
}

/// 缓存装箱（NSCache 需要引用类型）
private final class SVGAVideoBox {
    let video: SVGAVideo
    init(_ video: SVGAVideo) { self.video = video }
}
