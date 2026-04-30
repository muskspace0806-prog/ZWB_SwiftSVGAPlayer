// Sources/SwiftSVGAPlayer/Playback/ZWB_SVGADisplayLinkDriver.swift

import UIKit
import QuartzCore

/// CADisplayLink 封装，支持指定 fps 驱动
final class SVGADisplayLinkDriver {

    private var displayLink: CADisplayLink?
    private var tick: (() -> Void)?
    private var targetFPS: Int = 20
    private var frameInterval: Int = 1
    private var tickCounter: Int = 0

    // MARK: - Public

    func start(fps: Int, tick: @escaping () -> Void) {
        stop()
        self.tick = tick
        self.targetFPS = max(1, min(fps, 60))

        let link = CADisplayLink(target: WeakTarget(self), selector: #selector(WeakTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        tickCounter = 0

        // 计算跳帧间隔（屏幕刷新率 / 目标 fps）
        // iOS 15+ 可用 preferredFrameRateRange，iOS 13 用 preferredFramesPerSecond
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(targetFPS),
                maximum: Float(targetFPS),
                preferred: Float(targetFPS)
            )
        } else {
            link.preferredFramesPerSecond = targetFPS
        }

        svgaLogDebug("DisplayLink started at \(targetFPS) fps")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        tick = nil
        tickCounter = 0
    }

    func pause() {
        displayLink?.isPaused = true
    }

    func resume() {
        displayLink?.isPaused = false
    }

    // MARK: - Tick

    fileprivate func handleTick() {
        tick?()
    }

    deinit {
        stop()
    }
}

// MARK: - WeakTarget（避免 CADisplayLink 强引用循环）

private final class WeakTarget {
    weak var driver: SVGADisplayLinkDriver?
    init(_ driver: SVGADisplayLinkDriver) { self.driver = driver }

    @objc func tick(_ link: CADisplayLink) {
        driver?.handleTick()
    }
}
