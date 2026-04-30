// Tests/SwiftSVGAPlayerTests/ZWB_SVGASourceTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGASourceTests: XCTestCase {

    // MARK: - Equatable

    func test_url_equality() {
        let url = URL(string: "https://example.com/test.svga")!
        XCTAssertEqual(SVGASource.url(url), SVGASource.url(url))
    }

    func test_url_inequality() {
        let a = URL(string: "https://example.com/a.svga")!
        let b = URL(string: "https://example.com/b.svga")!
        XCTAssertNotEqual(SVGASource.url(a), SVGASource.url(b))
    }

    func test_fileURL_equality() {
        let url = URL(fileURLWithPath: "/tmp/test.svga")
        XCTAssertEqual(SVGASource.fileURL(url), SVGASource.fileURL(url))
    }

    func test_named_equality() {
        XCTAssertEqual(SVGASource.named("gift", bundle: .main),
                       SVGASource.named("gift", bundle: .main))
    }

    func test_named_inequality_differentName() {
        XCTAssertNotEqual(SVGASource.named("gift", bundle: .main),
                          SVGASource.named("other", bundle: .main))
    }

    func test_data_equality_sameCacheKey() {
        let d1 = Data([0x01])
        let d2 = Data([0x02]) // 不同 data，相同 key
        XCTAssertEqual(SVGASource.data(d1, cacheKey: "key"),
                       SVGASource.data(d2, cacheKey: "key"))
    }

    func test_data_inequality_differentCacheKey() {
        let d = Data([0x01])
        XCTAssertNotEqual(SVGASource.data(d, cacheKey: "key1"),
                          SVGASource.data(d, cacheKey: "key2"))
    }

    func test_data_nil_cacheKey_equality() {
        let d = Data([0x01])
        XCTAssertEqual(SVGASource.data(d, cacheKey: nil),
                       SVGASource.data(d, cacheKey: nil))
    }

    func test_different_types_not_equal() {
        let url = URL(string: "https://example.com/test.svga")!
        XCTAssertNotEqual(SVGASource.url(url),
                          SVGASource.named("test", bundle: .main))
    }

    // MARK: - debugDescription

    func test_debugDescription_url() {
        let url = URL(string: "https://example.com/test.svga")!
        let desc = SVGASource.url(url).debugDescription
        XCTAssertTrue(desc.contains("url("))
    }

    func test_debugDescription_named() {
        let desc = SVGASource.named("gift", bundle: .main).debugDescription
        XCTAssertTrue(desc.contains("named(gift"))
    }
}
