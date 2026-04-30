// Sources/SwiftSVGAPlayer/Model/SVGAImageResource.swift

import UIKit

/// SVGA 中的图片资源
public struct SVGAImageResource {
    /// 图片 key（对应 sprite 的 imageKey）
    public let key: String
    /// 解码后的 UIImage
    public let image: UIImage

    public init(key: String, image: UIImage) {
        self.key = key
        self.image = image
    }
}
