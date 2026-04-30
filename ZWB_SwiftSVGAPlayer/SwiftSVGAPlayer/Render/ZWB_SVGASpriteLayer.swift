// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGASpriteLayer.swift

import UIKit
import QuartzCore

/// 对应一个 SVGASprite 的渲染容器
final class SVGASpriteLayer: CALayer {

    // sprite 用 Optional，兼容 CALayer 的 init(layer:) / init?(coder:)
    private(set) var sprite: SVGASprite?
    private(set) var bitmapLayer: SVGABitmapLayer?
    private(set) var vectorLayer: SVGAVectorLayer?

    // MARK: - 主初始化

    init(sprite: SVGASprite, image: UIImage?) {
        self.sprite = sprite
        super.init()
        isGeometryFlipped = false
        setupSublayers(sprite: sprite, image: image)
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? SVGASpriteLayer {
            self.sprite      = other.sprite
            self.bitmapLayer = other.bitmapLayer
            self.vectorLayer = other.vectorLayer
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Setup

    private func setupSublayers(sprite: SVGASprite, image: UIImage?) {
        if image != nil || sprite.imageKey != nil {
            let bl = SVGABitmapLayer()
            bl.configure(image: image)
            addSublayer(bl)
            bitmapLayer = bl
        }

        let hasShapes = sprite.frames.contains { !$0.shapes.isEmpty }
        if hasShapes {
            let vl = SVGAVectorLayer()
            addSublayer(vl)
            vectorLayer = vl
        }
    }

    // MARK: - Step to frame

    func step(to frameIndex: Int, canvasSize: CGSize, dynamicItems: SVGADynamicItems) {
        guard let sprite = sprite else { return }
        guard frameIndex < sprite.frames.count else { isHidden = true; return }

        let frame = sprite.frames[frameIndex]
        let key   = sprite.imageKey ?? ""

        if case .hidden = dynamicItems[key] {
            isHidden = true
            return
        }
        isHidden = false

        if let bl = bitmapLayer {
            if let item = dynamicItems[key] {
                switch item {
                case .image(let img):  bl.setDynamicImage(img)
                case .text(let attr):  bl.setDynamicText(attr)
                case .hidden:          bl.isDynamicHidden = true
                case .drawing, .imageURL: break
                }
            } else {
                bl.setDynamicImage(nil)
            }
            bl.apply(frame: frame, canvasSize: canvasSize)
            self.frame = bl.frame
            bl.frame   = CGRect(origin: .zero, size: bl.frame.size)
        }

        if let vl = vectorLayer, !frame.shapes.isEmpty {
            vl.apply(shapes: frame.shapes, frame: frame, canvasSize: canvasSize)
        }
    }

    func clearDynamic() {
        bitmapLayer?.clearDynamic()
    }
}
