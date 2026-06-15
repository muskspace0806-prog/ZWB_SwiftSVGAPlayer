// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGABitmapLayer.swift

import UIKit
import QuartzCore

/// 渲染单个 bitmap sprite 的 CALayer
/// 坐标系：frame 由父层（SVGASpriteLayer，覆盖整个画布）决定
/// transform 使用默认中心锚点应用，并按旧版 SVGAPlayer 的 nx/ny 修正位置
final class SVGABitmapLayer: CALayer {

    private var dynamicImage: UIImage?
    private var originalImage: UIImage?
    private var dynamicImageOptions: SVGADynamicImageOptions?
    private var textLayer: CATextLayer?
    private var drawingBlock: SVGADrawingBlock?
    private var drawingLayer: CALayer?
    var isDynamicHidden: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        isGeometryFlipped = false
        contentsGravity = .resizeAspect
        masksToBounds = false
        actions = SVGABitmapLayer.disabledActions
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

        transform = CATransform3DIdentity
        self.frame = CGRect(x: layout.x, y: layout.y, width: layout.width, height: layout.height)
        transform = frame.transform != .identity
            ? CATransform3DMakeAffineTransform(frame.transform)
            : CATransform3DIdentity
        
        // 复刻旧版 SVGAPlayer 的 nx/ny 修正：transform 后把外接矩形原点拉回素材定义的最小点。
        let offsetX = self.frame.origin.x - frame.bitmapTransformedOrigin.x
        let offsetY = self.frame.origin.y - frame.bitmapTransformedOrigin.y
        position = CGPoint(x: position.x - offsetX, y: position.y - offsetY)

        // 裁剪路径
        if let clipPath = frame.clipPath {
            let ml = CAShapeLayer()
            ml.path = clipPath
            self.mask = ml
        } else {
            self.mask = nil
        }
        applyDynamicImageOptions()

        CATransaction.commit()
    }

    // MARK: - Dynamic Content

    func setDynamicImage(_ image: UIImage?, options: SVGADynamicImageOptions? = nil) {
        dynamicImage = image
        dynamicImageOptions = image == nil ? nil : options
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
        dynamicImageOptions = nil
        contentsGravity = .resizeAspect
        cornerRadius = 0
        masksToBounds = false
    }

    private func applyDynamicImageOptions() {
        guard let options = dynamicImageOptions else {
            contentsGravity = .resizeAspect
            cornerRadius = 0
            masksToBounds = false
            return
        }

        switch options.contentMode {
        case .aspectFit:
            contentsGravity = .resizeAspect
        case .aspectFill:
            contentsGravity = .resizeAspectFill
        case .scaleToFill:
            contentsGravity = .resize
        }

        switch options.cornerRadius {
        case .none:
            cornerRadius = 0
        case .fixed(let radius):
            cornerRadius = max(0, radius)
        case .circle:
            cornerRadius = min(bounds.width, bounds.height) * 0.5
        }
        masksToBounds = options.clipsToBounds || cornerRadius > 0
    }
    
    private static let disabledActions: [String: CAAction] = [
        "bounds": NSNull(),
        "position": NSNull(),
        "frame": NSNull(),
        "transform": NSNull(),
        "opacity": NSNull(),
        "hidden": NSNull(),
        "cornerRadius": NSNull(),
        "contents": NSNull()
    ]
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
