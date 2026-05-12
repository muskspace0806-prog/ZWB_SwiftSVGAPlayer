// Tests/SwiftSVGAPlayerTests/ZWB_SVGAPlaybackControllerTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGAPlaybackControllerTests: XCTestCase {

    var controller: SVGAPlaybackController!

    override func setUp() {
        super.setUp()
        controller = SVGAPlaybackController()
    }

    override func tearDown() {
        controller.stop()
        super.tearDown()
    }

    // MARK: - Range

    func test_range_clamped_to_totalFrames() {
        let range = (0..<100).clamped(toTotalFrames: 50)
        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range.upperBound, 50)
    }

    func test_range_negative_lowerBound_clamped() {
        let range = (-5..<20).clamped(toTotalFrames: 30)
        XCTAssertEqual(range.lowerBound, 0)
    }

    func test_range_lowerBound_equals_upperBound_fixed() {
        let range = (10..<10).clamped(toTotalFrames: 30)
        XCTAssertLessThan(range.lowerBound, range.upperBound)
    }

    func test_range_frameCount() {
        let range = 5..<15
        XCTAssertEqual(range.frameCount, 10)
    }

    // MARK: - Seek

    func test_seek_clamps_to_range() {
        controller.configure(totalFrames: 30, fps: 20)
        controller.range = 5..<25
        controller.seek(toFrame: 100)
        XCTAssertEqual(controller.currentFrame, 24)
    }

    func test_seek_clamps_to_zero() {
        controller.configure(totalFrames: 30, fps: 20)
        controller.seek(toFrame: -5)
        XCTAssertEqual(controller.currentFrame, 0)
    }

    // MARK: - Loop Count

    func test_loopMode_once() {
        controller.loopMode = .once
        var completedCount = 0
        controller.onComplete = { completedCount += 1 }
        // 验证 loopMode 设置正确
        XCTAssertEqual(controller.loopMode, .once)
    }

    func test_loopMode_count() {
        controller.loopMode = .count(3)
        XCTAssertEqual(controller.loopMode, .count(3))
    }

    func test_loopMode_forever() {
        controller.loopMode = .forever
        XCTAssertEqual(controller.loopMode, .forever)
    }

    // MARK: - State

    func test_initial_state_is_idle() {
        XCTAssertEqual(controller.state, .idle)
    }

    func test_stop_sets_stopped_state() {
        controller.configure(totalFrames: 30, fps: 20)
        controller.stop()
        XCTAssertEqual(controller.state, .stopped)
    }

    // MARK: - Configure

    func test_configure_sets_totalFrames() {
        controller.configure(totalFrames: 60, fps: 30)
        XCTAssertEqual(controller.totalFrames, 60)
    }

    func test_configure_preserves_customRange() {
        controller.configure(totalFrames: 60, fps: 30, range: 10..<20)

        XCTAssertEqual(controller.range.lowerBound, 10)
        XCTAssertEqual(controller.range.upperBound, 20)
        XCTAssertEqual(controller.currentFrame, 10)
    }

    func test_configure_preserves_customRange_whenReversed() {
        controller.isReversed = true
        controller.configure(totalFrames: 60, fps: 30, range: 10..<20)

        XCTAssertEqual(controller.range.lowerBound, 10)
        XCTAssertEqual(controller.range.upperBound, 20)
        XCTAssertEqual(controller.currentFrame, 19)
    }

    func test_configure_resets_loopCount() {
        controller.configure(totalFrames: 30, fps: 20)
        controller.configure(totalFrames: 30, fps: 20)
        // 重新配置后 currentFrame 应重置
        XCTAssertEqual(controller.currentFrame, 0)
    }
}
