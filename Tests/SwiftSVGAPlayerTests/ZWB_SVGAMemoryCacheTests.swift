// Tests/SwiftSVGAPlayerTests/ZWB_SVGAMemoryCacheTests.swift

import XCTest
import UIKit
@testable import SwiftSVGAPlayer

final class SVGAMemoryCacheTests: XCTestCase {

    var cache: SVGAMemoryCache!

    override func setUp() {
        super.setUp()
        cache = SVGAMemoryCache(countLimit: 10)
    }

    override func tearDown() {
        cache.removeAllVideos()
        super.tearDown()
    }

    func makeVideo() -> SVGAVideo {
        SVGAVideo(size: CGSize(width: 100, height: 100),
                  fps: 20, frames: 10,
                  sprites: [], images: [:], audios: [])
    }

    // MARK: - Tests

    func test_store_and_retrieve() {
        let video = makeVideo()
        cache.store(video, forKey: "key1")
        let retrieved = cache.video(forKey: "key1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.fps, 20)
    }

    func test_miss_returnsNil() {
        let result = cache.video(forKey: "nonexistent")
        XCTAssertNil(result)
    }

    func test_remove_specific_key() {
        let video = makeVideo()
        cache.store(video, forKey: "key1")
        cache.removeVideo(forKey: "key1")
        XCTAssertNil(cache.video(forKey: "key1"))
    }

    func test_removeAll() {
        cache.store(makeVideo(), forKey: "key1")
        cache.store(makeVideo(), forKey: "key2")
        cache.removeAllVideos()
        XCTAssertNil(cache.video(forKey: "key1"))
        XCTAssertNil(cache.video(forKey: "key2"))
    }

    // MARK: - 1.0.3 新增：内存成本估算与 cost 限制

    /// 构造一张指定像素尺寸的纯色图，用于计算真实位图字节数
    func makeImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 带图片的视频，成本应大于空视频
    func makeVideoWithImage(width: Int, height: Int) -> SVGAVideo {
        let img = makeImage(width: width, height: height)
        let res = SVGAImageResource(key: "img", image: img)
        return SVGAVideo(size: CGSize(width: width, height: height),
                         fps: 20, frames: 10,
                         sprites: [], images: ["img": res], audios: [])
    }

    /// 空图片视频成本至少为 1（避免 NSCache 不计量）
    func test_estimatedMemoryCost_empty_isAtLeastOne() {
        let video = makeVideo()
        XCTAssertGreaterThanOrEqual(video.estimatedMemoryCost, 1)
    }

    /// 含图片的视频成本应接近 宽 × 高 × 4
    func test_estimatedMemoryCost_withImage() {
        let video = makeVideoWithImage(width: 100, height: 100)
        // 100*100*4 = 40000，考虑 scale 与对齐，至少应明显大于 0
        XCTAssertGreaterThan(video.estimatedMemoryCost, 1000)
    }

    /// costLimit 可配置
    func test_costLimit_configurable() {
        let c = SVGAMemoryCache(costLimit: 1024 * 1024)
        XCTAssertEqual(c.costLimit, 1024 * 1024)
        c.costLimit = 2048
        XCTAssertEqual(c.costLimit, 2048)
    }

    func test_overwrite_existing_key() {
        let v1 = SVGAVideo(size: .zero, fps: 20, frames: 10, sprites: [], images: [:], audios: [])
        let v2 = SVGAVideo(size: .zero, fps: 30, frames: 20, sprites: [], images: [:], audios: [])
        cache.store(v1, forKey: "key")
        cache.store(v2, forKey: "key")
        XCTAssertEqual(cache.video(forKey: "key")?.fps, 30)
    }
}
