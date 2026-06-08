// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGASpriteLayer.swift

import UIKit
import QuartzCore

/// 对应一个 SVGASprite 的渲染容器
/// frame 始终覆盖整个画布（canvasSize），不随 bitmapLayer 变化
/// bitmapLayer 在其内部用绝对坐标定位
final class SVGASpriteLayer: CALayer {

    private(set) var sprite: SVGASprite?
    private(set) var bitmapLayer: SVGABitmapLayer?
    private(set) var vectorLayer: SVGAVectorLayer?

    // MARK: - Init

    init(sprite: SVGASprite, image: UIImage?, canvasSize: CGSize) {
        self.sprite = sprite
        super.init()
        isGeometryFlipped = false
        masksToBounds     = false
        actions = SVGASpriteLayer.disabledActions
        // 覆盖整个画布，子层用绝对坐标定位
        frame = CGRect(origin: .zero, size: canvasSize)
        setupSublayers(sprite: sprite, image: image)
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let o = layer as? SVGASpriteLayer {
            sprite      = o.sprite
            bitmapLayer = o.bitmapLayer
            vectorLayer = o.vectorLayer
        }
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Setup

    private func setupSublayers(sprite: SVGASprite, image: UIImage?) {
        if image != nil || sprite.imageKey != nil {
            let bl = SVGABitmapLayer()
            bl.configure(image: image)
            addSublayer(bl)
            bitmapLayer = bl
        }
        if sprite.frames.contains(where: { !$0.shapes.isEmpty }) {
            let vl = SVGAVectorLayer()
            addSublayer(vl)
            vectorLayer = vl
        }
    }

    // MARK: - Step

    func step(to frameIndex: Int, canvasSize: CGSize, dynamicItems: SVGADynamicItems) {
        guard let sprite = sprite else { return }
        guard frameIndex < sprite.frames.count else { isHidden = true; return }

        let svgaFrame = sprite.frames[frameIndex]
        let key       = sprite.imageKey ?? ""

        // 动态隐藏
        if case .hidden = dynamicItems[key] { isHidden = true; return }
        isHidden = false

        // 确保 spriteLayer 始终覆盖整个画布
        if self.frame.size != canvasSize {
            self.frame = CGRect(origin: .zero, size: canvasSize)
        }

        // Bitmap layer
        if let bl = bitmapLayer {
            // 应用动态内容
            if let item = dynamicItems[key] {
                switch item {
                case .image(let img):  bl.setDynamicImage(img)
                case .text(let attr):  bl.setDynamicText(attr)
                case .hidden:          bl.isDynamicHidden = true
                case .drawing(let block): bl.setDrawingBlock(block)
                case .imageURL: break
                }
            } else {
                bl.isDynamicHidden = false
                bl.setDynamicImage(nil)
            }
            bl.apply(frame: svgaFrame, canvasSize: canvasSize)
            bl.updateDrawing(frameIndex: frameIndex)
        }

        // Vector layer
        if let vl = vectorLayer, !svgaFrame.shapes.isEmpty {
            vl.apply(shapes: svgaFrame.shapes, frame: svgaFrame, canvasSize: canvasSize)
        }
    }

    func clearDynamic() {
        bitmapLayer?.clearDynamic()
    }
    
    private static let disabledActions: [String: CAAction] = [
        "bounds": NSNull(),
        "position": NSNull(),
        "frame": NSNull(),
        "transform": NSNull(),
        "opacity": NSNull(),
        "hidden": NSNull()
    ]
}
