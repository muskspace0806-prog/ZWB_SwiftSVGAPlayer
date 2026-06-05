// Tests/SwiftSVGAPlayerTests/ZWB_SVGAPreloaderTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGAPreloaderTests: XCTestCase {

    /// 预热空列表应正常返回（不崩溃、不挂起）
    func test_preload_emptyList_completes() async {
        await SVGAPreloader.preload([])
        XCTAssertTrue(true)
    }

    /// 预热非法/无法访问的 URL 应忽略错误并正常返回
    func test_preload_invalidURLs_ignoresError() async {
        let url = URL(string: "https://invalid.invalid/not-exist.svga")!
        await SVGAPreloader.preload(urls: [url], maxConcurrent: 2)
        XCTAssertTrue(true)
    }

    /// URL 字符串便捷入口可过滤非法字符串并正常返回
    func test_preload_urlStrings_completes() async {
        await SVGAPreloader.preload(urlStrings: ["", "https://invalid.invalid/a.svga"], maxConcurrent: 1)
        XCTAssertTrue(true)
    }
}
