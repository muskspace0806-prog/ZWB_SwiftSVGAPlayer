// Sources/SwiftSVGAPlayer/Model/ZWB_SVGASprite.swift

import Foundation

/// SVGA Sprite（对应一个动画元素）
public struct SVGASprite {
    /// 对应图片资源的 key
    public let imageKey: String?
    /// matte（遮罩）key，指向另一个 sprite 的 imageKey
    public let matteKey: String?
    /// 每帧数据，数组长度等于 SVGAVideo.frames
    public let frames: [SVGAFrame]

    public init(
        imageKey: String?,
        matteKey: String?,
        frames: [SVGAFrame]
    ) {
        self.imageKey = imageKey
        self.matteKey = matteKey
        self.frames = frames
    }
}
