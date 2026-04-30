// Sources/SwiftSVGAPlayer/Playback/ZWB_SVGAPlaybackController.swift

import Foundation

/// 播放控制器，负责帧推进逻辑（不持有 UIView / CALayer）
final class SVGAPlaybackController {

    // MARK: - State

    private(set) var state: SVGAPlaybackState = .idle
    private(set) var currentFrame: Int = 0
    private(set) var totalFrames: Int = 0

    var range: Range<Int> = 0..<1
    var loopMode: SVGALoopMode = .forever
    var isReversed: Bool = false

    /// 当前已完成的循环次数
    private var loopCount: Int = 0

    // MARK: - Callbacks

    /// 每帧回调（frame index）
    var onFrameChange: ((Int) -> Void)?
    /// 状态变化回调
    var onStateChange: ((SVGAPlaybackState) -> Void)?
    /// 一次循环完成回调（loop 结束时触发）
    var onLoopComplete: (() -> Void)?
    /// 全部播放完成回调
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

    func play() {
        guard totalFrames > 0 else { return }
        loopCount = 0
        currentFrame = isReversed ? range.upperBound - 1 : range.lowerBound
        startDriver()
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
        currentFrame = max(range.lowerBound, min(frame, range.upperBound - 1))
        onFrameChange?(currentFrame)
    }

    // MARK: - Private

    private func startDriver() {
        // fps 从外部注入，这里用 totalFrames 作为默认值（实际由 PlayerView 传入）
        driver.start(fps: 20) { [weak self] in
            self?.advance()
        }
    }

    func startDriver(fps: Int) {
        driver.start(fps: fps) { [weak self] in
            self?.advance()
        }
        setState(.playing)
    }

    private func advance() {
        guard state == .playing else { return }

        onFrameChange?(currentFrame)

        // 推进帧
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
            let maxLoops = max(1, n)
            if loopCount >= maxLoops {
                driver.stop()
                setState(.completed)
                onComplete?()
                return
            }
        case .forever:
            break
        }

        // 重置到起始帧继续循环
        currentFrame = isReversed ? range.upperBound - 1 : range.lowerBound
    }

    private func setState(_ newState: SVGAPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    deinit {
        driver.stop()
    }
}
