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
    /// Bitmap layer 的校正位置，兼容旧版 SVGAPlayer 的 nx/ny 渲染行为。
    let bitmapPosition: CGPoint

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
        self.bitmapPosition = SVGAFrame.makeBitmapPosition(layout: layout, transform: transform)
    }
}

extension SVGAFrame {
    /// Whether this frame can draw visible content.
    ///
    /// Some SVGA exporters append default/empty frames at the end of a movie.
    /// Those frames decode to alpha 1 with zero layout, which should not extend
    /// the default playback loop because they render as a blank flash.
    var hasRenderableContent: Bool {
        guard alpha > 0.001 else { return false }
        if !shapes.isEmpty { return true }
        return layout.width > 0 && layout.height > 0
    }
    
    private static func makeBitmapPosition(layout: SVGALayout, transform: CGAffineTransform) -> CGPoint {
        let absoluteMinPoint = transformedMinPoint(
            x: layout.x,
            y: layout.y,
            width: layout.width,
            height: layout.height,
            transform: transform
        )
        let localMinPoint = transformedMinPoint(
            x: 0,
            y: 0,
            width: layout.width,
            height: layout.height,
            transform: transform
        )
        
        guard absoluteMinPoint.x.isFinite,
              absoluteMinPoint.y.isFinite,
              localMinPoint.x.isFinite,
              localMinPoint.y.isFinite else {
            return CGPoint(x: layout.x, y: layout.y)
        }
        
        return CGPoint(
            x: absoluteMinPoint.x - localMinPoint.x,
            y: absoluteMinPoint.y - localMinPoint.y
        )
    }
    
    private static func transformedMinPoint(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        transform: CGAffineTransform
    ) -> CGPoint {
        let points = [
            CGPoint(x: x, y: y),
            CGPoint(x: x + width, y: y),
            CGPoint(x: x, y: y + height),
            CGPoint(x: x + width, y: y + height)
        ].map { $0.applying(transform) }
        
        let minX = points.map { $0.x }.min() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        return CGPoint(x: minX, y: minY)
    }
}
