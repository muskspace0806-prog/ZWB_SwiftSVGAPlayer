// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Playback/ZWB_SVGAPlaybackController.swift

import Foundation

/// 播放控制器，负责帧推进逻辑（主线程运行）
@MainActor
final class SVGAPlaybackController {

    // MARK: - State

    private(set) var state: SVGAPlaybackState = .idle
    private(set) var currentFrame: Int = 0
    private(set) var totalFrames: Int = 0

    var range: Range<Int> = 0..<1
    var loopMode: SVGALoopMode = .forever
    var isReversed: Bool = false

    private var loopCount: Int = 0

    // MARK: - Callbacks

    var onFrameChange: ((Int) -> Void)?
    var onStateChange: ((SVGAPlaybackState) -> Void)?
    var onLoopComplete: (() -> Void)?
    var onComplete: (() -> Void)?

    // MARK: - Driver

    private let driver = SVGADisplayLinkDriver()

    // MARK: - Configure

    func configure(totalFrames: Int, fps: Int) {
        self.totalFrames = totalFrames
        self.range = (0..<totalFrames).clamped(toTotalFrames: totalFrames)
        self.currentFrame = isReversed ? range.upperBound - 1 : range.lowerBound
        self.loopCount = 0
    }

    // MARK: - Playback Control

    func startDriver(fps: Int) {
        loopCount = 0
        currentFrame = isReversed ? range.upperBound - 1 : range.lowerBound
        driver.start(fps: fps) { [weak self] in
            self?.advance()
        }
        setState(.playing)
    }

    func pause() {
        guard state == .playing else { return }
        driver.pause()
        setState(.paused)
    }

    func resume() {
        guard state == .paused else { return }
        driver.resume()
        setState(.playing)
    }

    func stop() {
        driver.stop()
        setState(.stopped)
    }

    func seek(toFrame frame: Int) {
        guard totalFrames > 0 else { return }
        currentFrame = Swift.max(range.lowerBound, Swift.min(frame, range.upperBound - 1))
        onFrameChange?(currentFrame)
    }

    // MARK: - Private

    private func advance() {
        guard state == .playing else { return }

        onFrameChange?(currentFrame)

        if isReversed {
            if currentFrame > range.lowerBound {
                currentFrame -= 1
            } else {
                handleLoopEnd()
            }
        } else {
            if currentFrame < range.upperBound - 1 {
                currentFrame += 1
            } else {
                handleLoopEnd()
            }
        }
    }

    private func handleLoopEnd() {
        onLoopComplete?()
        loopCount += 1

        switch loopMode {
        case .once:
            driver.stop()
            setState(.completed)
            onComplete?()
            return
        case .count(let n):
            if loopCount >= Swift.max(1, n) {
                driver.stop()
                setState(.completed)
                onComplete?()
                return
            }
        case .forever:
            break
        }

        currentFrame = isReversed ? range.upperBound - 1 : range.lowerBound
    }

    private func setState(_ newState: SVGAPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    deinit {
        driver.stopFromDeinit()
    }
}
