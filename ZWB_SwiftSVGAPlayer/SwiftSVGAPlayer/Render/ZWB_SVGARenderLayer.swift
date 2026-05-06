// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Render/ZWB_SVGARenderLayer.swift

import UIKit
import QuartzCore

/// 顶层渲染 CALayer
/// bounds = canvasSize（原始画布尺寸，不变）
/// frame  = 由 SwiftSVGAPlayerView 根据 contentMode 计算的显示区域
/// 缩放通过 frame != bounds 由 CALayer 自动处理，不使用 transform
final class SVGARenderLayer: CALayer {

    private(set) var video: SVGAVideo?
    private var spriteLayers: [SVGASpriteLayer] = []
    private var dynamicItems: SVGADynamicItems = [:]
    private var isConfigured = false

    // MARK: - Init

    override init() {
        super.init()
        isGeometryFlipped = false
        masksToBounds     = true   // 内容限制在 renderLayer frame 内，不超出 view
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Configure

    func configure(video: SVGAVideo) {
        // 同一 video 不重建
        if isConfigured,
           let cur = self.video,
           cur.size == video.size && cur.frames == video.frames {
            return
        }
        clearLayers()
        self.video    = video
        isConfigured  = true

        let canvasSize = video.size
        // bounds 固定为画布原始尺寸，frame 由外部设置
        bounds = CGRect(origin: .zero, size: canvasSize)

        for sprite in video.sprites {
            let image       = sprite.imageKey.flatMap { video.images[$0]?.image }
            let spriteLayer = SVGASpriteLayer(sprite: sprite, image: image, canvasSize: canvasSize)
            addSublayer(spriteLayer)
            spriteLayers.append(spriteLayer)
        }

        svgaLogDebug("RenderLayer configured: \(video.sprites.count) sprites, canvas=\(canvasSize)")
    }

    // MARK: - Step

    func step(to frameIndex: Int) {
        guard let video = video, isConfigured else { return }
        let f          = Swift.max(0, Swift.min(frameIndex, video.frames - 1))
        let canvasSize = video.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sl in spriteLayers {
            sl.step(to: f, canvasSize: canvasSize, dynamicItems: dynamicItems)
        }
        CATransaction.commit()
    }

    // MARK: - Dynamic Items

    func setDynamicItems(_ items: SVGADynamicItems) { dynamicItems = items }

    func setDynamicItem(_ item: SVGADynamicItem?, forKey key: String) {
        if let item = item { dynamicItems[key] = item }
        else { dynamicItems.removeValue(forKey: key) }
    }

    // MARK: - Clear

    func clearLayers() {
        spriteLayers.forEach { $0.removeFromSuperlayer() }
        spriteLayers.removeAll()
        video        = nil
        isConfigured = false
        dynamicItems.removeAll()
    }

    func clearDynamicItems() {
        dynamicItems.removeAll()
        spriteLayers.forEach { $0.clearDynamic() }
    }
}
