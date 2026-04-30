// Tests/SwiftSVGAPlayerTests/ZWB_SVGACacheKeyGeneratorTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGACacheKeyGeneratorTests: XCTestCase {

    let generator = SVGACacheKeyGenerator()

    // MARK: - URL

    func test_url_returnsMD5Key() {
        let url = URL(string: "https://example.com/test.svga")!
        let key = generator.cacheKey(for: .url(url))
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.count, 32) // MD5 hex = 32 chars
    }

    func test_url_sameURLReturnsSameKey() {
        let url = URL(string: "https://example.com/test.svga")!
        let key1 = generator.cacheKey(for: .url(url))
        let key2 = generator.cacheKey(for: .url(url))
        XCTAssertEqual(key1, key2)
    }

    func test_url_differentURLReturnsDifferentKey() {
        let url1 = URL(string: "https://example.com/a.svga")!
        let url2 = URL(string: "https://example.com/b.svga")!
        let key1 = generator.cacheKey(for: .url(url1))
        let key2 = generator.cacheKey(for: .url(url2))
        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - fileURL

    func test_fileURL_returnsMD5Key() {
        let url = URL(fileURLWithPath: "/tmp/test.svga")
        let key = generator.cacheKey(for: .fileURL(url))
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.count, 32)
    }

    // MARK: - named

    func test_named_returnsKey() {
        let key = generator.cacheKey(for: .named("gift", bundle: .main))
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.count, 32)
    }

    func test_named_sameNameSameBundleReturnsSameKey() {
        let key1 = generator.cacheKey(for: .named("gift", bundle: .main))
        let key2 = generator.cacheKey(for: .named("gift", bundle: .main))
        XCTAssertEqual(key1, key2)
    }

    func test_named_differentNameReturnsDifferentKey() {
        let key1 = generator.cacheKey(for: .named("gift", bundle: .main))
        let key2 = generator.cacheKey(for: .named("other", bundle: .main))
        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - data

    func test_data_withCacheKey_returnsCacheKey() {
        let data = Data([0x01, 0x02])
        let key = generator.cacheKey(for: .data(data, cacheKey: "my_key"))
        XCTAssertEqual(key, "my_key")
    }

    func test_data_withoutCacheKey_returnsNil() {
        let data = Data([0x01, 0x02])
        let key = generator.cacheKey(for: .data(data, cacheKey: nil))
        XCTAssertNil(key)
    }
}
