// Sources/SwiftSVGAPlayer/Render/ZWB_SVGAVectorLayer.swift

import UIKit
import QuartzCore

/// 渲染矢量形状的 CALayer（使用 CAShapeLayer 子层）
final class SVGAVectorLayer: CALayer {

    private var shapeLayers: [CAShapeLayer] = []

    override init() {
        super.init()
        isGeometryFlipped = false
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    func apply(shapes: [SVGAShape], frame: SVGAFrame, canvasSize: CGSize) {
        // 复用或创建 shape layers
        while shapeLayers.count < shapes.count {
            let sl = CAShapeLayer()
            addSublayer(sl)
            shapeLayers.append(sl)
        }
        // 隐藏多余的
        for i in shapes.count..<shapeLayers.count {
            shapeLayers[i].isHidden = true
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let layout = frame.layout
        self.frame = CGRect(x: CGFloat(layout.x), y: CGFloat(layout.y),
                            width: CGFloat(layout.width), height: CGFloat(layout.height))
        self.opacity = Float(frame.alpha)

        for (i, shape) in shapes.enumerated() {
            let sl = shapeLayers[i]
            sl.isHidden = false
            applyShape(shape, to: sl)
        }

        CATransaction.commit()
    }

    private func applyShape(_ shape: SVGAShape, to layer: CAShapeLayer) {
        layer.frame = self.bounds

        // 路径
        switch shape.type {
        case .shape:
            if let d = shape.pathData {
                // 路径已在 SVGABinaryDecoder 中解析为 CGPath，这里直接用 pathData 字符串重新解析
                // 实际上 SVGAFrame.shapes 中的 SVGAShape 已经包含了解析好的路径信息
                // 这里简化处理：直接设置 nil，完整 vector 支持在 Phase 6 实现
                layer.path = nil
                svgaLogVerbose("Vector shape path: \(d.prefix(50))")
            }
        case .rect:
            if let r = shape.rectArgs {
                layer.path = CGPath(roundedRect: r, cornerWidth: 0, cornerHeight: 0, transform: nil)
            }
        case .ellipse:
            if let e = shape.ellipseArgs {
                let rect = CGRect(x: e.cx - e.rx, y: e.cy - e.ry,
                                  width: e.rx * 2, height: e.ry * 2)
                layer.path = CGPath(ellipseIn: rect, transform: nil)
            }
        case .keep:
            break // 保持上一帧路径
        }

        // 样式
        let style = shape.style
        layer.fillColor   = style.fillColor?.cgColor
        layer.strokeColor = style.strokeColor?.cgColor
        layer.lineWidth   = style.strokeWidth
        layer.lineCap     = CAShapeLayerLineCap(style.lineCap)
        layer.lineJoin    = CAShapeLayerLineJoin(style.lineJoin)
        layer.miterLimit  = style.miterLimit
        if !style.lineDashPattern.isEmpty {
            layer.lineDashPattern = style.lineDashPattern.map { NSNumber(value: Double($0)) }
            layer.lineDashPhase   = style.lineDashOffset
        }

        // 变换
        if shape.transform != .identity {
            layer.transform = CATransform3DMakeAffineTransform(shape.transform)
        } else {
            layer.transform = CATransform3DIdentity
        }
    }
}

// MARK: - CAShapeLayerLineCap / LineJoin helpers

private extension CAShapeLayerLineCap {
    init(_ cap: CGLineCap) {
        switch cap {
        case .round:  self = .round
        case .square: self = .square
        default:      self = .butt
        }
    }
}

private extension CAShapeLayerLineJoin {
    init(_ join: CGLineJoin) {
        switch join {
        case .round: self = .round
        case .bevel: self = .bevel
        default:     self = .miter
        }
    }
}
