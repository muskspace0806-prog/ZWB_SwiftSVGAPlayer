// Sources/SwiftSVGAPlayer/Model/ZWB_SVGAVideo.swift

import CoreGraphics

/// SVGA 解析后的完整视频模型
public struct SVGAVideo {
    /// 画布尺寸
    public let size: CGSize
    /// 帧率
    public let fps: Int
    /// 总帧数
    public let frames: Int
    /// 默认播放帧数，自动排除尾部连续空帧/哨兵帧
    public let playbackFrames: Int
    /// 所有 sprite
    public let sprites: [SVGASprite]
    /// 图片资源字典，key 为 imageKey
    public let images: [String: SVGAImageResource]
    /// 音频资源列表
    public let audios: [SVGAAudio]

    public init(
        size: CGSize,
        fps: Int,
        frames: Int,
        sprites: [SVGASprite],
        images: [String: SVGAImageResource],
        audios: [SVGAAudio],
        playbackFrames: Int? = nil
    ) {
        self.size = size
        self.fps = fps
        self.frames = frames
        self.playbackFrames = playbackFrames ?? SVGAVideo.defaultPlaybackFrames(
            declaredFrames: frames,
            sprites: sprites
        )
        self.sprites = sprites
        self.images = images
        self.audios = audios
    }

    /// 有效帧率（最低 1，最高 60）
    public var clampedFPS: Int {
        return Swift.max(1, Swift.min(fps, 60))
    }
}

extension SVGAVideo {
    static func defaultPlaybackFrames(declaredFrames: Int, sprites: [SVGASprite]) -> Int {
        guard declaredFrames > 0 else { return 1 }

        var lastRenderableIndex: Int?
        for sprite in sprites {
            let upperBound = Swift.min(declaredFrames, sprite.frames.count)
            guard upperBound > 0 else { continue }

            for index in stride(from: upperBound - 1, through: 0, by: -1) {
                if sprite.frames[index].hasRenderableContent {
                    lastRenderableIndex = Swift.max(lastRenderableIndex ?? 0, index)
                    break
                }
            }
        }

        guard let lastRenderableIndex else { return declaredFrames }
        return Swift.max(1, Swift.min(declaredFrames, lastRenderableIndex + 1))
    }
}

import UIKit

// MARK: - 内存成本估算（1.0.3）
extension SVGAVideo {
    /// 估算该视频占用的内存成本（字节），用于 NSCache 的 cost 计量。
    ///
    /// SVGA 解析后会把所有图片解码成位图（UIImage）常驻内存，
    /// 真正吃内存的是这些位图，因此成本按所有图片的 `宽 × 高 × 4 字节` 累加估算。
    /// 优先使用 cgImage 的实际 `bytesPerRow × height`，更贴近真实占用。
    public var estimatedMemoryCost: Int {
        var total = 0
        for (_, resource) in images {
            let image = resource.image
            if let cg = image.cgImage {
                // 实际位图字节数：每行字节数 × 像素高度
                total += cg.bytesPerRow * cg.height
            } else {
                // 退化估算：点尺寸 × scale² × 4 通道
                let scale = image.scale
                let pixelW = image.size.width * scale
                let pixelH = image.size.height * scale
                total += Int(pixelW * pixelH * 4)
            }
        }
        // 至少计 1 字节，避免 cost 为 0 时 NSCache 不计量
        return Swift.max(total, 1)
    }
}
