// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGAVectorLayer.swift

import UIKit
import QuartzCore

/// 渲染矢量形状的 CALayer
/// frame 覆盖整个画布，shape 用绝对坐标定位
final class SVGAVectorLayer: CALayer {

    private var shapeLayers: [CAShapeLayer] = []

    override init() {
        super.init()
        isGeometryFlipped = false
        masksToBounds     = false
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    func apply(shapes: [SVGAShape], frame: SVGAFrame, canvasSize: CGSize) {
        // 补齐 shape layers
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

        // 覆盖整个画布
        if self.frame.size != canvasSize {
            self.frame = CGRect(origin: .zero, size: canvasSize)
        }
        self.opacity = Float(frame.alpha)

        for (i, shape) in shapes.enumerated() {
            shapeLayers[i].isHidden = false
            applyShape(shape, to: shapeLayers[i])
        }

        CATransaction.commit()
    }

    private func applyShape(_ shape: SVGAShape, to layer: CAShapeLayer) {
        layer.frame = self.bounds

        switch shape.type {
        case .shape:
            // pathData 已在 SVGABinaryDecoder.parseSVGPath 解析为 CGPath 并存入 SVGAFrame
            // 但 SVGAShape 目前只存字符串，需要在这里解析
            if let d = shape.pathData {
                layer.path = SVGAPathParser.parse(d)
            } else {
                layer.path = nil
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
            break
        }

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
        layer.transform = shape.transform != .identity
            ? CATransform3DMakeAffineTransform(shape.transform)
            : CATransform3DIdentity
    }
}

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
