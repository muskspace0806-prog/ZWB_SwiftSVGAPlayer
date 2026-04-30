// Tests/SwiftSVGAPlayerTests/ZWB_SVGAMemoryCacheTests.swift

import XCTest
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

    func test_overwrite_existing_key() {
        let v1 = SVGAVideo(size: .zero, fps: 20, frames: 10, sprites: [], images: [:], audios: [])
        let v2 = SVGAVideo(size: .zero, fps: 30, frames: 20, sprites: [], images: [:], audios: [])
        cache.store(v1, forKey: "key")
        cache.store(v2, forKey: "key")
        XCTAssertEqual(cache.video(forKey: "key")?.fps, 30)
    }
}
