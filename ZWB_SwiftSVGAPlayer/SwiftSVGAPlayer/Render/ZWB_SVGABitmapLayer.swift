// Sources/SwiftSVGAPlayer/Render/ZWB_SVGABitmapLayer.swift

import UIKit
import QuartzCore

/// 渲染单个 bitmap sprite 的 CALayer
final class SVGABitmapLayer: CALayer {

    // MARK: - Properties

    /// 当前显示的图片（动态替换优先）
    private var dynamicImage: UIImage?
    /// 原始 SVGA 图片
    private var originalImage: UIImage?
    /// 动态文字层
    private var textLayer: CATextLayer?
    /// 是否隐藏（动态控制）
    var isDynamicHidden: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        isGeometryFlipped = false
        contentsGravity = .resize
        masksToBounds = true
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Configure

    func configure(image: UIImage?) {
        originalImage = image
        if dynamicImage == nil {
            contents = image?.cgImage
        }
    }

    // MARK: - Apply Frame

    func apply(frame: SVGAFrame, canvasSize: CGSize) {
        guard !isDynamicHidden else {
            isHidden = true
            return
        }
        isHidden = frame.alpha <= 0.001

        let layout = frame.layout
        let frameRect = CGRect(x: CGFloat(layout.x),
                               y: CGFloat(layout.y),
                               width: CGFloat(layout.width),
                               height: CGFloat(layout.height))

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        self.frame = frameRect
        self.opacity = Float(frame.alpha)

        // 应用变换（相对于 layer 中心）
        if frame.transform != .identity {
            self.transform = CATransform3DMakeAffineTransform(frame.transform)
        } else {
            self.transform = CATransform3DIdentity
        }

        // 裁剪路径
        if let clipPath = frame.clipPath {
            let maskLayer = CAShapeLayer()
            maskLayer.path = clipPath
            self.mask = maskLayer
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
        // 移除旧文字层
        textLayer?.removeFromSuperlayer()
        textLayer = nil

        guard let text = text else { return }

        let tl = CATextLayer()
        tl.isWrapped = true
        tl.contentsScale = UIScreen.main.scale
        tl.string = text
        tl.frame = bounds
        addSublayer(tl)
        textLayer = tl
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        textLayer?.frame = bounds
    }

    func clearDynamic() {
        dynamicImage = nil
        contents = originalImage?.cgImage
        textLayer?.removeFromSuperlayer()
        textLayer = nil
        isDynamicHidden = false
    }
}
