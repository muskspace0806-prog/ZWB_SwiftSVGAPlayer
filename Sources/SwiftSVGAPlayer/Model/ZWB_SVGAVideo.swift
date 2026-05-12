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
