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
        actions = SVGARenderLayer.disabledActions
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    // MARK: - Configure

    func configure(video: SVGAVideo) {
        if isConfigured,
           let cur = self.video,
           cur.size == video.size && cur.frames == video.frames {
            return
        }
        clearLayers(keepsDynamicItems: true)
        self.video    = video
        isConfigured  = true

        let canvasSize = video.size
        bounds = CGRect(origin: .zero, size: canvasSize)

        // 先建所有 spriteLayer，再处理 matte（需要先有所有 layer 才能找到 matteKey 对应的 layer）
        for sprite in video.sprites {
            let image       = sprite.imageKey.flatMap { video.images[$0]?.image }
            let spriteLayer = SVGASpriteLayer(sprite: sprite, image: image, canvasSize: canvasSize)
            addSublayer(spriteLayer)
            spriteLayers.append(spriteLayer)
        }

        // 应用 matte：找到 matteKey 对应的 spriteLayer，作为 mask
        applyMatteLayers(video: video)

        svgaLogDebug("RenderLayer configured: \(video.sprites.count) sprites, canvas=\(canvasSize)")
    }

    private func applyMatteLayers(video: SVGAVideo) {
        // 建立 imageKey → spriteLayer 的映射
        var keyToLayer: [String: SVGASpriteLayer] = [:]
        for sl in spriteLayers {
            if let key = sl.sprite?.imageKey {
                keyToLayer[key] = sl
            }
        }
        // 对有 matteKey 的 sprite，把对应 layer 设为 mask
        for sl in spriteLayers {
            guard let matteKey = sl.sprite?.matteKey, !matteKey.isEmpty else { continue }
            if let matteLayer = keyToLayer[matteKey] {
                // 从父层移除 matteLayer，改为 mask
                matteLayer.removeFromSuperlayer()
                spriteLayers.removeAll { $0 === matteLayer }
                sl.mask = matteLayer
                svgaLogDebug("Applied matte: \(matteKey) → \(sl.sprite?.imageKey ?? "?")")
            }
        }
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
            // 同步更新 matte mask layer
            if let matteLayer = sl.mask as? SVGASpriteLayer {
                matteLayer.step(to: f, canvasSize: canvasSize, dynamicItems: dynamicItems)
            }
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

    func clearLayers(keepsDynamicItems: Bool = false) {
        spriteLayers.forEach { $0.removeFromSuperlayer() }
        spriteLayers.removeAll()
        video        = nil
        isConfigured = false
        if !keepsDynamicItems {
            dynamicItems.removeAll()
        }
    }

    func clearDynamicItems() {
        dynamicItems.removeAll()
        spriteLayers.forEach { $0.clearDynamic() }
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
