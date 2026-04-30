// Sources/SwiftSVGAPlayer/Model/SVGAFrame.swift

import UIKit

/// 单帧数据
public struct SVGAFrame {
    /// 透明度 0.0 ~ 1.0
    public let alpha: CGFloat
    /// 布局（位置和尺寸）
    public let layout: SVGALayout
    /// 变换矩阵
    public let transform: CGAffineTransform
    /// 裁剪路径（可选）
    public let clipPath: CGPath?
    /// 矢量形状列表
    public let shapes: [SVGAShape]

    public init(
        alpha: CGFloat = 1.0,
        layout: SVGALayout = .zero,
        transform: CGAffineTransform = .identity,
        clipPath: CGPath? = nil,
        shapes: [SVGAShape] = []
    ) {
        self.alpha = alpha
        self.layout = layout
        self.transform = transform
        self.clipPath = clipPath
        self.shapes = shapes
    }
}
