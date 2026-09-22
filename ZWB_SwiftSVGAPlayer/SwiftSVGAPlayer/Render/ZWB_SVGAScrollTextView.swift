// Sources/SwiftSVGAPlayer/Render/ZWB_SVGAScrollTextView.swift

import UIKit
import QuartzCore

/// 跑马灯视图：把一个 SVGA 动态槽位替换成可无限滚动的一行文本
///
/// ## 为什么工作在视图坐标系
/// 本视图挂在播放器的覆盖容器（`animatedOverlayContainer`）里，与动图覆盖层同一层级，
/// 坐标就是播放器视图坐标。因此：
///
/// - `config.font` / `gap` / `speed` / `insets` 天然以 **屏幕 pt** 为单位，不需要画布单位换算；
/// - 播放器尺寸变化时只需更新 frame，**不必重建文本**，也就不会因为重建而重启滚动动画。
///
/// 仅在 `config.unit == .canvas` 时才按缩放比把画布单位换算成 pt（此时缩放比变化会重建）。
///
/// ## 无缝原理
/// 把「文本 + 间距」当作一个周期横向平铺 N 份，然后对内容层做一次**正好一个周期长度**
/// 的线性位移动画并无限重复 —— 位移一个周期后画面与起点完全重合，所以循环处没有接缝。
final class SVGAScrollTextView: UIView {

    // MARK: - Stored Properties

    private var config = SVGAScrollTextConfig()
    private var text: NSAttributedString?

    /// 承载平铺文本的容器。anchorPoint = .zero，方便直接用 position.x 做位移动画
    private let contentLayer = CALayer()
    private var textLayers: [CATextLayer] = []

    /// 一个周期的长度 = 文本宽度 + 间距（pt）
    private var cycleLength: CGFloat = 0
    /// 文本单份尺寸（pt）
    private var textSize: CGSize = .zero
    /// `.canvas` 模式下换算后的文本（`.point` 模式就是原串）
    private var resolvedText: NSAttributedString?
    /// 已经按哪个可用宽度铺过瓦片。用于「只增不减」的增量铺瓦
    private var tiledWidth: CGFloat = 0

    /// 画布 → 视图的缩放比。仅在 `unit == .canvas` 时参与换算
    private var renderScale: CGFloat = 1
    /// 上次构建所用的缩放比，用于 `.canvas` 模式下的重建节流
    private var resolvedScale: CGFloat = 0

    private var isPaused = false

    private static let marqueeAnimationKey = "svga.scrollText.marquee"

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false
        contentLayer.anchorPoint = .zero
        contentLayer.actions = SVGAScrollTextView.disabledActions
        layer.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard cycleLength > 0, let resolved = resolvedText else { return }

        // 宽度变大时按需补瓦片（只补不删，多余的会被 clipsToBounds 裁掉）
        ensureTiles(fillWidth: bounds.width, text: resolved)

        if config.isScrolling {
            // 滚动中只更新纵向位置，横向交给动画 —— 绝不能重启动画，否则相位会跳回起点
            let insets = resolvedInsets
            let availableHeight = max(0, bounds.height - insets.top - insets.bottom)
            let textY = insets.top + max(0, (availableHeight - textSize.height) / 2)
            if abs(contentLayer.position.y - textY) > 0.001 {
                contentLayer.position = CGPoint(x: contentLayer.position.x, y: textY)
            }
        } else {
            applyLayout()
        }
    }

    // MARK: - Public (internal)

    /// 更新文本与配置
    ///
    /// 文本与配置都没变化时直接返回 —— 避免上层周期性重复调用（例如每秒刷新一次公告）
    /// 导致跑马灯被反复重建、视觉上跳回起点。
    func update(text: NSAttributedString?, config: SVGAScrollTextConfig) {
        let textChanged   = !SVGAScrollTextView.isSameText(text, self.text)
        let configChanged = (config != self.config)
        guard textChanged || configChanged || textLayers.isEmpty else { return }
        self.text   = text
        self.config = config
        rebuild()
    }

    /// 播放器缩放比变化。仅 `unit == .canvas` 时需要重建（字号要跟着缩放走）
    func updateRenderScale(_ scale: CGFloat) {
        guard scale > 0, abs(scale - renderScale) > 0.001 else { return }
        renderScale = scale
        guard config.unit == .canvas, text != nil else { return }
        guard resolvedScale > 0 else {
            rebuild()          // 首次：必须按真实缩放比构建一次
            return
        }
        // 尺寸动画期间 layoutSubviews 每帧都会调到这里，逐帧重建会反复重启滚动动画，
        // 因此按「相对上次构建的累计变化 > 5%」节流（5% 的字号误差肉眼不可辨）
        if abs(scale - resolvedScale) / resolvedScale > 0.05 {
            rebuild()
        }
    }

    /// 与播放器 pause / resume 联动
    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        let wasPaused = isPaused
        isPaused = paused
        if paused {
            freezeContentLayer()
        } else {
            // 没真正暂停过就不要碰时间轴，否则 beginTime 会被重置成当前时刻，
            // 动画相位会被拉回起点，视觉上就是「跳一下」
            guard wasPaused else { return }
            let pausedTime = contentLayer.timeOffset
            contentLayer.speed      = 1
            contentLayer.timeOffset = 0
            contentLayer.beginTime  = 0
            contentLayer.beginTime  = contentLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        }
    }

    // MARK: - Build

    private func rebuild() {
        // 每次重建都把内容层时间轴复位到干净状态，重建完成后若处于暂停态再重新冻结
        contentLayer.speed      = 1
        contentLayer.timeOffset = 0
        contentLayer.beginTime  = 0
        defer { if isPaused { freezeContentLayer() } }

        // 放在最前面，即使下面某个 guard 提前 return 也要记上，否则节流会失效
        resolvedScale = renderScale

        textLayers.forEach { $0.removeFromSuperlayer() }
        textLayers.removeAll()
        contentLayer.removeAnimation(forKey: SVGAScrollTextView.marqueeAnimationKey)
        cycleLength  = 0
        textSize     = .zero
        resolvedText = nil
        tiledWidth   = 0

        guard let text = text, text.length > 0 else {
            contentLayer.frame = .zero
            return
        }

        let resolved = resolveText(text)
        let size     = measure(resolved)
        guard size.width > 0, size.height > 0 else {
            contentLayer.frame = .zero
            return
        }

        resolvedText = resolved
        textSize     = size
        cycleLength  = size.width + max(0, config.gap * lengthFactor)

        ensureTiles(fillWidth: bounds.width, text: resolved)
        applyLayout()
    }

    /// 按需增量铺瓦。只补不删 —— 多余的瓦片被 clipsToBounds 裁掉，且不影响动画相位
    private func ensureTiles(fillWidth: CGFloat, text: NSAttributedString) {
        guard cycleLength > 0, textSize.width > 0 else { return }
        let insets    = resolvedInsets
        let available = max(0, fillWidth - insets.left - insets.right)
        guard available > 0, available > tiledWidth else { return }

        // 要保证位移过程中可视区始终被铺满：n * cycle >= available + cycle，再多留一份冗余
        let needed = max(2, Int(ceil((available + cycleLength) / cycleLength)) + 1)
        guard needed > textLayers.count else {
            tiledWidth = available
            return
        }

        // 视图坐标空间与 pt 是 1:1 的，栅格化倍率固定为屏幕倍率即可
        let contentsScale = UIScreen.main.scale
        for index in textLayers.count..<needed {
            let textLayer = CATextLayer()
            textLayer.string          = text
            textLayer.isWrapped       = false
            textLayer.truncationMode  = .none
            textLayer.alignmentMode   = .left
            textLayer.isGeometryFlipped = false
            textLayer.contentsScale   = contentsScale
            textLayer.actions         = SVGAScrollTextView.disabledActions
            textLayer.frame = CGRect(x: CGFloat(index) * cycleLength,
                                     y: 0,
                                     width: textSize.width,
                                     height: textSize.height)
            contentLayer.addSublayer(textLayer)
            textLayers.append(textLayer)
        }
        tiledWidth = available
    }

    /// 摆放内容层并驱动滚动动画
    private func applyLayout() {
        guard cycleLength > 0 else { return }

        let insets = resolvedInsets
        let availableWidth  = max(0, bounds.width  - insets.left - insets.right)
        let availableHeight = max(0, bounds.height - insets.top  - insets.bottom)
        let textY = insets.top + max(0, (availableHeight - textSize.height) / 2)

        contentLayer.frame = CGRect(x: 0,
                                    y: textY,
                                    width: cycleLength * CGFloat(max(1, textLayers.count)),
                                    height: textSize.height)

        let startX: CGFloat
        let endX: CGFloat

        if config.isScrolling {
            // 位移一个周期后画面与起点重合，所以循环处无接缝
            switch config.effectiveDirection {
            case .rightToLeft:          // 文本整体向左移动
                startX = 0
                endX   = -cycleLength
            case .leftToRight:          // 文本整体向右移动
                startX = -cycleLength
                endX   = 0
            }
        } else {
            switch config.effectiveAlignment {
            case .right:  startX = insets.left + availableWidth - textSize.width
            case .center: startX = insets.left + (availableWidth - textSize.width) / 2
            default:      startX = insets.left
            }
            endX = startX
        }

        contentLayer.position = CGPoint(x: startX, y: contentLayer.position.y)
        contentLayer.removeAnimation(forKey: SVGAScrollTextView.marqueeAnimationKey)

        guard config.isScrolling, abs(endX - startX) > 0.001 else { return }
        let duration = CFTimeInterval(cycleLength / max(config.speed * lengthFactor, 1))
        guard duration > 0.01 else { return }

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue             = startX
        animation.toValue               = endX
        animation.duration              = duration
        animation.repeatCount           = .infinity
        animation.timingFunction        = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        contentLayer.add(animation, forKey: SVGAScrollTextView.marqueeAnimationKey)
    }

    // MARK: - Pause

    /// 冻结内容层时间轴（标准 CA 暂停写法）
    private func freezeContentLayer() {
        contentLayer.timeOffset = contentLayer.convertTime(CACurrentMediaTime(), from: nil)
        contentLayer.speed = 0
    }

    // MARK: - Units

    /// `.canvas` 模式下把画布单位换算成 pt 的系数；`.point` 模式为 1
    private var lengthFactor: CGFloat {
        guard config.unit == .canvas else { return 1 }
        return max(renderScale, 0.0001)
    }

    private var resolvedInsets: UIEdgeInsets {
        let factor = lengthFactor
        guard abs(factor - 1) > 0.0001 else { return config.insets }
        let raw = config.insets
        return UIEdgeInsets(top: raw.top * factor,
                            left: raw.left * factor,
                            bottom: raw.bottom * factor,
                            right: raw.right * factor)
    }

    /// 把文本里的字号从画布单位换算到 pt（仅 `.canvas` 模式需要）
    private func resolveText(_ text: NSAttributedString) -> NSAttributedString {
        let factor = lengthFactor
        guard abs(factor - 1) > 0.0001 else { return text }

        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: text.length)

        // 先在原串上枚举收集，再统一写入副本，避免边枚举边改
        var replacements: [(font: UIFont, range: NSRange)] = []
        text.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            replacements.append((font.withSize(font.pointSize * factor), range))
        }
        replacements.forEach { mutable.addAttribute(.font, value: $0.font, range: $0.range) }
        return mutable
    }

    // MARK: - Measure

    /// 单行文本的尺寸测量
    private func measure(_ text: NSAttributedString) -> CGSize {
        let limit = CGSize(width: 100_000, height: 100_000)
        let rect = text.boundingRect(with: limit,
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     context: nil)
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }

    // MARK: - Helpers

    private static func isSameText(_ lhs: NSAttributedString?, _ rhs: NSAttributedString?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):            return true
        case let (l?, r?):          return l.isEqual(r)
        default:                    return false
        }
    }

    private static let disabledActions: [String: CAAction] = [
        "bounds": NSNull(),
        "position": NSNull(),
        "frame": NSNull(),
        "transform": NSNull(),
        "opacity": NSNull(),
        "hidden": NSNull(),
        "contentsScale": NSNull()
    ]
}
