// Sources/SwiftSVGAPlayer/Render/ZWB_SVGARenderLayer.swift

import UIKit
import QuartzCore

/// 顶层渲染 CALayer，管理所有 sprite layers
final class SVGARenderLayer: CALayer {

    // MARK: - Properties

    private(set) var video: SVGAVideo?
    private var spriteLayers: [SVGASpriteLayer] = []
    private var dynamicItems: SVGADynamicItems = [:]
    private var isConfigured = false

    // MARK: - Init

    override init() {
        super.init()
        isGeometryFlipped = false
        masksToBounds = true
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Configure

    /// 配置 video，构建 sprite layers（同一 video 重复调用不重建）
    func configure(video: SVGAVideo) {
        if isConfigured, let current = self.video,
           current.size == video.size && current.frames == video.frames {
            // 同一 video，不重建
            return
        }
        clearLayers()
        self.video = video
        isConfigured = true

        let canvasSize = video.size
        self.bounds = CGRect(origin: .zero, size: canvasSize)

        for sprite in video.sprites {
            let image = sprite.imageKey.flatMap { video.images[$0]?.image }
            let spriteLayer = SVGASpriteLayer(sprite: sprite, image: image)
            addSublayer(spriteLayer)
            spriteLayers.append(spriteLayer)
        }

        svgaLogDebug("Configured render layer: \(video.sprites.count) sprites, canvas: \(canvasSize)")
    }

    // MARK: - Step

    /// 渲染到指定帧
    func step(to frameIndex: Int) {
        guard let video = video, isConfigured else { return }
        let clampedFrame = max(0, min(frameIndex, video.frames - 1))
        let canvasSize = video.size

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for spriteLayer in spriteLayers {
            spriteLayer.step(to: clampedFrame, canvasSize: canvasSize, dynamicItems: dynamicItems)
        }

        CATransaction.commit()
    }

    // MARK: - Dynamic Items

    func setDynamicItems(_ items: SVGADynamicItems) {
        dynamicItems = items
    }

    func setDynamicItem(_ item: SVGADynamicItem?, forKey key: String) {
        if let item = item {
            dynamicItems[key] = item
        } else {
            dynamicItems.removeValue(forKey: key)
        }
    }

    // MARK: - Clear

    func clearLayers() {
        spriteLayers.forEach { $0.removeFromSuperlayer() }
        spriteLayers.removeAll()
        video = nil
        isConfigured = false
        dynamicItems.removeAll()
    }

    func clearDynamicItems() {
        dynamicItems.removeAll()
        spriteLayers.forEach { $0.clearDynamic() }
    }
}
