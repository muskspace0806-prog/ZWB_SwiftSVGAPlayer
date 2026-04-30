// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Playback/ZWB_SVGADisplayLinkDriver.swift

import UIKit
import QuartzCore

/// CADisplayLink 封装，支持指定 fps 驱动
@MainActor
final class SVGADisplayLinkDriver {

    private var displayLink: CADisplayLink?
    private var tick: (() -> Void)?

    // MARK: - Public

    func start(fps: Int, tick: @escaping () -> Void) {
        stop()
        self.tick = tick
        let targetFPS = Swift.max(1, Swift.min(fps, 60))

        let link = CADisplayLink(target: WeakTarget(self), selector: #selector(WeakTarget.tick(_:)))
        link.add(to: .main, forMode: .common)

        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(targetFPS),
                maximum: Float(targetFPS),
                preferred: Float(targetFPS)
            )
        } else {
            link.preferredFramesPerSecond = targetFPS
        }

        displayLink = link
        svgaLogDebug("DisplayLink started at \(targetFPS) fps")
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        tick = nil
    }

    func pause() {
        displayLink?.isPaused = true
    }

    func resume() {
        displayLink?.isPaused = false
    }

    /// nonisolated 版本，供 deinit 调用
    nonisolated func stopFromDeinit() {
        // CADisplayLink.invalidate() 是线程安全的，可在任意线程调用
        DispatchQueue.main.async { [weak self] in
            self?.displayLink?.invalidate()
            self?.displayLink = nil
            self?.tick = nil
        }
    }

    fileprivate func handleTick() {
        tick?()
    }

    deinit {
        displayLink?.invalidate()
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
