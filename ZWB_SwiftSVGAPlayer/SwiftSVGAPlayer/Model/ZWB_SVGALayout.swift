// Sources/SwiftSVGAPlayer/Model/SVGALayout.swift

import CoreGraphics

/// 帧布局信息（对应 SVGA frame 中的 layout）
public struct SVGALayout: Equatable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat

    public init(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var rect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static let zero = SVGALayout(x: 0, y: 0, width: 0, height: 0)
}
