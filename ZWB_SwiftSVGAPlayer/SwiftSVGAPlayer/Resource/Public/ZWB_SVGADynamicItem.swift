// Sources/SwiftSVGAPlayer/Public/SVGADynamicItem.swift

import UIKit

/// 动态绘制回调类型
public typealias SVGADrawingBlock = (_ context: CGContext, _ frame: CGRect, _ frameIndex: Int) -> Void

/// 动态图片内容模式
public enum SVGADynamicImageContentMode {
    /// 等比完整显示
    case aspectFit
    /// 等比填充显示，超出图层范围的部分会被裁剪
    case aspectFill
    /// 拉伸填满图层
    case scaleToFill
}

/// 动态图片圆角
public enum SVGADynamicImageCornerRadius {
    /// 不设置圆角
    case none
    /// 固定圆角半径
    case fixed(CGFloat)
    /// 自动使用图层短边的一半，适合头像圆形裁剪
    case circle
}

/// 动态图片渲染选项
public struct SVGADynamicImageOptions {
    public var contentMode: SVGADynamicImageContentMode
    public var cornerRadius: SVGADynamicImageCornerRadius
    public var clipsToBounds: Bool

    public init(
        contentMode: SVGADynamicImageContentMode = .aspectFit,
        cornerRadius: SVGADynamicImageCornerRadius = .none,
        clipsToBounds: Bool = false
    ) {
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.clipsToBounds = clipsToBounds
    }

    public static let `default` = SVGADynamicImageOptions()

    public static func circle(contentMode: SVGADynamicImageContentMode = .aspectFill) -> SVGADynamicImageOptions {
        return SVGADynamicImageOptions(
            contentMode: contentMode,
            cornerRadius: .circle,
            clipsToBounds: true
        )
    }
}

/// 动态内容项，用于替换 SVGA 中指定 key 的内容
public enum SVGADynamicItem {
    /// 替换为静态图片
    case image(UIImage)
    /// 替换为带渲染选项的静态图片
    case imageWithOptions(UIImage, SVGADynamicImageOptions)
    /// 替换为远程图片 URL（异步加载）
    case imageURL(URL)
    /// 替换为富文本
    case text(NSAttributedString)
    /// 隐藏该元素
    case hidden
    /// 自定义绘制
    case drawing(SVGADrawingBlock)
}

/// 动态内容集合，key 对应 SVGA 中的 imageKey
public typealias SVGADynamicItems = [String: SVGADynamicItem]
