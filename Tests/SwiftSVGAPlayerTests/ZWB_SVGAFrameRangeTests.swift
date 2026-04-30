// Tests/SwiftSVGAPlayerTests/ZWB_SVGAFrameRangeTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGAFrameRangeTests: XCTestCase {

    func test_clamp_normal_range() {
        let range = (5..<15).clamped(toTotalFrames: 30)
        XCTAssertEqual(range.lowerBound, 5)
        XCTAssertEqual(range.upperBound, 15)
    }

    func test_clamp_exceeds_totalFrames() {
        let range = (0..<100).clamped(toTotalFrames: 50)
        XCTAssertEqual(range.upperBound, 50)
    }

    func test_clamp_negative_lower() {
        let range = (-10..<20).clamped(toTotalFrames: 30)
        XCTAssertEqual(range.lowerBound, 0)
    }

    func test_clamp_zero_totalFrames() {
        let range = (0..<10).clamped(toTotalFrames: 0)
        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range.upperBound, 1)
    }

    func test_clamp_ensures_lowerBound_less_than_upperBound() {
        let range = (10..<10).clamped(toTotalFrames: 30)
        XCTAssertLessThan(range.lowerBound, range.upperBound)
    }

    func test_frameCount() {
        XCTAssertEqual((0..<10).frameCount, 10)
        XCTAssertEqual((5..<15).frameCount, 10)
        XCTAssertEqual((0..<1).frameCount, 1)
    }

    func test_clamp_lowerBound_at_last_frame() {
        let range = (29..<30).clamped(toTotalFrames: 30)
        XCTAssertEqual(range.lowerBound, 29)
        XCTAssertEqual(range.upperBound, 30)
    }
}
