// Sources/SwiftSVGAPlayer/Playback/ZWB_SVGAFrameRange.swift

import Foundation

extension Range where Bound == Int {
    /// 将 range 限制在 [0, totalFrames) 内，并确保 lowerBound < upperBound
    func clamped(toTotalFrames totalFrames: Int) -> Range<Int> {
        guard totalFrames > 0 else { return 0..<1 }
        let lo = Swift.max(0, Swift.min(lowerBound, totalFrames - 1))
        let hi = Swift.max(lo + 1, Swift.min(upperBound, totalFrames))
        return lo..<hi
    }

    var frameCount: Int { upperBound - lowerBound }
}
