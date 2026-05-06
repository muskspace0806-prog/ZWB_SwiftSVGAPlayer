// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGABitmapLayer.swift

import UIKit
import QuartzCore

/// 渲染单个 bitmap sprite 的 CALayer
/// 坐标系：frame 由父层（SVGASpriteLayer，覆盖整个画布）决定
/// transform 从左上角原点（anchorPoint = 0,0）应用，与 SVGA 规范一致
final class SVGABitmapLayer: CALayer {

    private var dynamicImage: UIImage?
    private var originalImage: UIImage?
    private var textLayer: CATextLayer?
    private var drawingBlock: SVGADrawingBlock?
    private var drawingLayer: CALayer?
    var isDynamicHidden: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        // anchorPoint = (0,0)：transform 从左上角原点应用，与 SVGA 坐标系一致
        anchorPoint = CGPoint(x: 0, y: 0)
        isGeometryFlipped = false
        contentsGravity = .resize
        masksToBounds = false
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Configure

    func configure(image: UIImage?) {
        originalImage = image
        if dynamicImage == nil {
            contents = image?.cgImage
        }
    }

    // MARK: - Apply Frame

    /// canvasSize 仅供将来扩展使用，当前 layout 已是绝对坐标
    func apply(frame: SVGAFrame, canvasSize: CGSize) {
        guard !isDynamicHidden else { isHidden = true; return }

        isHidden  = frame.alpha <= 0.001
        opacity   = Float(frame.alpha)

        let layout = frame.layout

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // anchorPoint = (0,0)，所以 position = layout 左上角
        bounds   = CGRect(x: 0, y: 0, width: layout.width, height: layout.height)
        position = CGPoint(x: layout.x, y: layout.y)

        // 应用 SVGA transform（已是相对左上角的矩阵）
        self.transform = frame.transform != .identity
            ? CATransform3DMakeAffineTransform(frame.transform)
            : CATransform3DIdentity

        // 裁剪路径
        if let clipPath = frame.clipPath {
            let ml = CAShapeLayer()
            ml.path = clipPath
            self.mask = ml
        } else {
            self.mask = nil
        }

        CATransaction.commit()
    }

    // MARK: - Dynamic Content

    func setDynamicImage(_ image: UIImage?) {
        dynamicImage = image
        contents = (image ?? originalImage)?.cgImage
    }

    func setDynamicText(_ text: NSAttributedString?) {
        textLayer?.removeFromSuperlayer()
        textLayer = nil
        guard let text = text else { return }
        let tl = CATextLayer()
        tl.isWrapped      = true
        tl.contentsScale  = UIScreen.main.scale
        tl.string         = text
        tl.frame          = bounds
        addSublayer(tl)
        textLayer = tl
    }

    func setDrawingBlock(_ block: SVGADrawingBlock?) {
        drawingBlock = block
        drawingLayer?.removeFromSuperlayer()
        drawingLayer = nil
        guard block != nil else { return }
        let dl = SVGADrawingLayer()
        dl.frame = bounds
        dl.drawingBlock = block
        addSublayer(dl)
        drawingLayer = dl
    }

    /// 通知 drawing layer 重绘（每帧调用）
    func updateDrawing(frameIndex: Int) {
        guard let dl = drawingLayer as? SVGADrawingLayer else { return }
        dl.currentFrameIndex = frameIndex
        dl.setNeedsDisplay()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        textLayer?.frame = bounds
    }

    func clearDynamic() {
        dynamicImage = nil
        contents     = originalImage?.cgImage
        textLayer?.removeFromSuperlayer()
        textLayer        = nil
        drawingLayer?.removeFromSuperlayer()
        drawingLayer     = nil
        drawingBlock     = nil
        isDynamicHidden  = false
        transform        = CATransform3DIdentity
    }
}

// MARK: - SVGADrawingLayer

/// 自定义绘制层，每帧调用 drawingBlock
private final class SVGADrawingLayer: CALayer {
    var drawingBlock: SVGADrawingBlock?
    var currentFrameIndex: Int = 0

    override func draw(in ctx: CGContext) {
        guard let block = drawingBlock else { return }
        block(ctx, bounds, currentFrameIndex)
    }
}
