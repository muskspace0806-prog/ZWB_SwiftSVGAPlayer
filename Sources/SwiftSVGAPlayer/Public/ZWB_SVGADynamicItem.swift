// Sources/SwiftSVGAPlayer/Public/SVGADynamicItem.swift

import UIKit

/// 动态绘制回调类型
public typealias SVGADrawingBlock = (_ context: CGContext, _ frame: CGRect, _ frameIndex: Int) -> Void

/// 动态内容项，用于替换 SVGA 中指定 key 的内容
public enum SVGADynamicItem {
    /// 替换为静态图片
    case image(UIImage)
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
