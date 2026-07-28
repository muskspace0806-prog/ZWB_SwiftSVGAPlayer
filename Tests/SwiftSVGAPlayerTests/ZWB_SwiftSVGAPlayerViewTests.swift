// Tests/SwiftSVGAPlayerTests/ZWB_SwiftSVGAPlayerViewTests.swift

import XCTest
@testable import SwiftSVGAPlayer

@MainActor
final class SwiftSVGAPlayerViewTests: XCTestCase {

    func test_displayLinkRunLoopMode_defaultsToDefaultMode() {
        let view = SwiftSVGAPlayerView()
        XCTAssertEqual(view.displayLinkRunLoopMode, .default)
    }

    func test_displayLinkRunLoopMode_canUseCommonMode() {
        let view = SwiftSVGAPlayerView()
        view.displayLinkRunLoopMode = .common
        XCTAssertEqual(view.displayLinkRunLoopMode, .common)
    }
}
