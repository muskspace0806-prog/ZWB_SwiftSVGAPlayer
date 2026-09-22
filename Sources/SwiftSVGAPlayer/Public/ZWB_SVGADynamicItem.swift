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

// MARK: - 跑马灯（可无限滚动文本）

/// 跑马灯滚动方向
public enum SVGAScrollTextDirection {
    /// 从左到右（文本整体向右移动）
    case leftToRight
    /// 从右到左（文本整体向左移动）
    case rightToLeft

    /// 取反方向
    public var reversed: SVGAScrollTextDirection {
        return self == .leftToRight ? .rightToLeft : .leftToRight
    }
}

/// 跑马灯配置里长度类参数的计量单位
public enum SVGAScrollTextUnit {
    /// 屏幕点（pt）。
    ///
    /// `font` / `gap` / `insets` / `speed` 都按「最终显示在屏幕上的大小」来写，
    /// 缩放换算由播放器内部处理 —— 调用方不需要知道画布是 300×300 还是别的尺寸。
    ///
    /// 例：`font = .systemFont(ofSize: 26)` 在 300×220 的播放器里就是实打实的 26pt。
    ///
    /// **默认值，推荐使用。**
    case point

    /// 画布单位（即 SVGA 的 viewBox 尺寸，如 300×300）。
    ///
    /// 需要和设计稿画布 1:1 对应、或想让素材缩放时字号跟着一起放大缩小时使用。
    case canvas
}

/// 跑马灯文本配置
///
/// ## 坐标系说明
/// `font` / `gap` / `speed` / `insets` 的计量单位由 `unit` 决定，**默认为 `.point`（屏幕点）**：
///
/// - `.point`（默认）：直接写期望的屏幕显示大小，播放器按当前缩放比自动换算。
///   300×300 的画布放进 300×220 的播放器（`.scaleAspectFit`）时缩放比约 0.73，
///   写 `26` 屏幕上就是 26pt，不需要自己做除法。
/// - `.canvas`：按画布单位给，屏幕实际大小 = 画布单位 × 缩放比。
///   同样是 26 号字，在 0.73 的缩放下屏幕上是约 19pt。
///
/// 注意 `.scaleToFill` 下横向纵向缩放比不同，文字必然会被拉伸；
/// 跑马灯场景建议用 `.scaleAspectFit` / `.scaleAspectFill`。
public struct SVGAScrollTextConfig: Equatable {

    /// 长度类参数（`font` / `gap` / `insets` / `speed`）的计量单位，默认 `.point`
    public var unit: SVGAScrollTextUnit

    /// 是否滚动。`false` 时只显示一段静态文本（超出 slot 的部分会被裁剪）
    public var isScrolling: Bool

    /// 滚动方向
    public var direction: SVGAScrollTextDirection

    /// 阿语等 RTL 语言：翻转滚动方向，并让文本按「从右到左」排版
    public var isRTLLayout: Bool

    /// 相邻两段文本之间的间距，即「前后间距」（单位见 `unit`）
    public var gap: CGFloat

    /// 滚动速度，单位 / 秒（单位见 `unit`）。必须大于 0
    public var speed: CGFloat

    /// 字号（单位见 `unit`）。仅在使用 `String` 便捷接口时生效；
    /// 直接传 `NSAttributedString` 时以属性串里自带的字体为准
    public var font: UIFont

    /// 文字颜色。仅在使用 `String` 便捷接口时生效
    public var textColor: UIColor

    /// 内边距，在 slot 矩形内部再收缩一圈可用区域（单位见 `unit`）
    public var insets: UIEdgeInsets

    /// 不滚动时的对齐方式。`nil` 表示按方向自动决定
    /// （`.rightToLeft` → 右对齐，`.leftToRight` → 左对齐）
    public var alignment: NSTextAlignment?

    /// 是否隐藏 SVGA 中该 key 原本的占位图，避免与跑马灯内容叠在一起（默认 `true`）
    public var hidesPlaceholder: Bool

    public init(
        unit: SVGAScrollTextUnit = .point,
        isScrolling: Bool = true,
        direction: SVGAScrollTextDirection = .rightToLeft,
        isRTLLayout: Bool = false,
        gap: CGFloat = 32,
        speed: CGFloat = 60,
        font: UIFont = .systemFont(ofSize: 24, weight: .semibold),
        textColor: UIColor = .white,
        insets: UIEdgeInsets = .zero,
        alignment: NSTextAlignment? = nil,
        hidesPlaceholder: Bool = true
    ) {
        self.unit = unit
        self.isScrolling = isScrolling
        self.direction = direction
        self.isRTLLayout = isRTLLayout
        self.gap = gap
        self.speed = speed
        self.font = font
        self.textColor = textColor
        self.insets = insets
        self.alignment = alignment
        self.hidesPlaceholder = hidesPlaceholder
    }

    /// 实际生效的滚动方向（`isRTLLayout == true` 时会把 `direction` 翻转过来）
    public var effectiveDirection: SVGAScrollTextDirection {
        return isRTLLayout ? direction.reversed : direction
    }

    /// 实际生效的对齐方式（不滚动时使用）
    public var effectiveAlignment: NSTextAlignment {
        if let alignment = alignment { return alignment }
        return effectiveDirection == .rightToLeft ? .right : .left
    }

    /// 全默认配置：单位 `.point`（屏幕 pt）、滚动、从右到左、间距 32、速度 60、字号 24
    public static let `default` = SVGAScrollTextConfig()
}
