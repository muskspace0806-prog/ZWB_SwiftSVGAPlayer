// Sources/SwiftSVGAPlayer/Render/ZWB_SVGASpriteLayer.swift

import UIKit
import QuartzCore

/// 对应一个 SVGASprite 的渲染容器
final class SVGASpriteLayer: CALayer {

    let sprite: SVGASprite
    private(set) var bitmapLayer: SVGABitmapLayer?
    private(set) var vectorLayer: SVGAVectorLayer?

    init(sprite: SVGASprite, image: UIImage?) {
        self.sprite = sprite
        super.init()
        isGeometryFlipped = false

        if image != nil || sprite.imageKey != nil {
            let bl = SVGABitmapLayer()
            bl.configure(image: image)
            addSublayer(bl)
            bitmapLayer = bl
        }

        // 如果有矢量形状，创建 vector layer
        let hasShapes = sprite.frames.contains { !$0.shapes.isEmpty }
        if hasShapes {
            let vl = SVGAVectorLayer()
            addSublayer(vl)
            vectorLayer = vl
        }
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Step to frame

    func step(to frameIndex: Int, canvasSize: CGSize, dynamicItems: SVGADynamicItems) {
        guard frameIndex < sprite.frames.count else {
            isHidden = true
            return
        }
        let frame = sprite.frames[frameIndex]

        // 动态隐藏
        let key = sprite.imageKey ?? ""
        if case .hidden = dynamicItems[key] {
            isHidden = true
            return
        }
        isHidden = false

        // Bitmap layer
        if let bl = bitmapLayer {
            // 动态图片
            if let item = dynamicItems[key] {
                switch item {
                case .image(let img):
                    bl.setDynamicImage(img)
                case .text(let attr):
                    bl.setDynamicText(attr)
                case .hidden:
                    bl.isDynamicHidden = true
                case .drawing, .imageURL:
                    break // drawing block 在 Phase 5 实现
                }
            } else {
                bl.setDynamicImage(nil)
            }
            bl.apply(frame: frame, canvasSize: canvasSize)
            // 同步 bitmap layer frame 到 sprite layer
            self.frame = bl.frame
            bl.frame = CGRect(origin: .zero, size: bl.frame.size)
        }

        // Vector layer
        if let vl = vectorLayer, !frame.shapes.isEmpty {
            vl.apply(shapes: frame.shapes, frame: frame, canvasSize: canvasSize)
        }
    }

    func clearDynamic() {
        bitmapLayer?.clearDynamic()
    }
}
