// Sources/SwiftSVGAPlayer/Model/SVGAShape.swift

import UIKit

/// 矢量形状类型
public enum SVGAShapeType {
    case shape   // 自定义路径
    case rect    // 矩形
    case ellipse // 椭圆
    case keep    // 保持上一帧形状
}

/// 矢量形状填充/描边样式
public struct SVGAShapeStyle {
    public let fillColor: UIColor?
    public let strokeColor: UIColor?
    public let strokeWidth: CGFloat
    public let lineCap: CGLineCap
    public let lineJoin: CGLineJoin
    public let miterLimit: CGFloat
    public let lineDashPattern: [CGFloat]
    public let lineDashOffset: CGFloat

    public init(
        fillColor: UIColor? = nil,
        strokeColor: UIColor? = nil,
        strokeWidth: CGFloat = 0,
        lineCap: CGLineCap = .butt,
        lineJoin: CGLineJoin = .miter,
        miterLimit: CGFloat = 10,
        lineDashPattern: [CGFloat] = [],
        lineDashOffset: CGFloat = 0
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.lineDashPattern = lineDashPattern
        self.lineDashOffset = lineDashOffset
    }
}

/// 矢量形状（对应 SVGA shape）
public struct SVGAShape {
    public let type: SVGAShapeType
    public let style: SVGAShapeStyle
    public let transform: CGAffineTransform
    /// 路径数据（SVG path d 字符串，type == .shape 时有效）
    public let pathData: String?
    /// 矩形参数（type == .rect 时有效）
    public let rectArgs: CGRect?
    /// 矩形圆角半径（type == .rect 时有效）
    public let rectCornerRadius: CGFloat
    /// 椭圆参数（type == .ellipse 时有效）
    public let ellipseArgs: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)?

    public init(
        type: SVGAShapeType,
        style: SVGAShapeStyle,
        transform: CGAffineTransform = .identity,
        pathData: String? = nil,
        rectArgs: CGRect? = nil,
        rectCornerRadius: CGFloat = 0,
        ellipseArgs: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)? = nil
    ) {
        self.type = type
        self.style = style
        self.transform = transform
        self.pathData = pathData
        self.rectArgs = rectArgs
        self.rectCornerRadius = rectCornerRadius
        self.ellipseArgs = ellipseArgs
    }
}
