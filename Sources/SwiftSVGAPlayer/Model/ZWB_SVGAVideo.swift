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
        audios: [SVGAAudio]
    ) {
        self.size = size
        self.fps = fps
        self.frames = frames
        self.sprites = sprites
        self.images = images
        self.audios = audios
    }

    /// 有效帧率（最低 1，最高 60）
    public var clampedFPS: Int {
        return max(1, min(fps, 60))
    }
}
