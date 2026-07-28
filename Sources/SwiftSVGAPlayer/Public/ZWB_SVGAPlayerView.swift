// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SVGAPlayerView.swift
// SwiftUI wrapper for SwiftSVGAPlayerView

import SwiftUI

/// SwiftUI 版 SVGA 播放器
///
/// 用法：
/// ```swift
/// SVGAPlayerView(source: .url(url), loop: .forever)
///     .frame(width: 200, height: 200)
///
/// SVGAPlayerView(source: .named("gift"), loop: .count(3))
///     .svgaReversed(true)
///     .svgaMuted(true)
///     .onSVGAComplete { print("done") }
/// ```
@available(iOS 13.0, *)
public struct SVGAPlayerView: UIViewRepresentable {

    // MARK: - Configuration

    private let source: SVGASource
    private let loop: SVGALoopMode
    private var isReversed: Bool = false
    private var isMuted: Bool = false
    private var contentMode: UIView.ContentMode = .scaleAspectFit
    private var displayLinkRunLoopMode: RunLoop.Mode = .default
    private var onStateChange: ((SVGAPlaybackState) -> Void)? = nil
    private var onFrameChange: ((Int, Double) -> Void)? = nil
    private var onComplete: (() -> Void)? = nil
    private var onError: ((SVGAError) -> Void)? = nil

    // MARK: - Init

    public init(source: SVGASource, loop: SVGALoopMode = .forever) {
        self.source = source
        self.loop   = loop
    }

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> SwiftSVGAPlayerView {
        let view = SwiftSVGAPlayerView()
        view.contentMode = contentMode
        return view
    }

    public func updateUIView(_ uiView: SwiftSVGAPlayerView, context: Context) {
        uiView.contentMode  = contentMode
        uiView.isReversed   = isReversed
        uiView.isMuted      = isMuted
        uiView.displayLinkRunLoopMode = displayLinkRunLoopMode
        uiView.onStateChange = onStateChange
        uiView.onFrameChange = onFrameChange
        uiView.onCompletion  = onComplete
        uiView.onError       = onError

        // 只在 source 变化时重新加载
        let coordinator = context.coordinator
        guard coordinator.lastSource != source else { return }
        coordinator.lastSource = source

        uiView.play(source, loop: loop)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator（记录上次 source，避免重复加载）

    public final class Coordinator {
        var lastSource: SVGASource? = nil
    }
}

// MARK: - Modifiers

@available(iOS 13.0, *)
public extension SVGAPlayerView {

    /// 反向播放
    func svgaReversed(_ reversed: Bool) -> SVGAPlayerView {
        var copy = self; copy.isReversed = reversed; return copy
    }

    /// 静音
    func svgaMuted(_ muted: Bool) -> SVGAPlayerView {
        var copy = self; copy.isMuted = muted; return copy
    }

    /// 内容缩放模式（默认 scaleAspectFit）
    func svgaContentMode(_ mode: UIView.ContentMode) -> SVGAPlayerView {
        var copy = self; copy.contentMode = mode; return copy
    }

    /// CADisplayLink 所在 RunLoop mode。默认 `.default`；需要滚动期间持续播放时可设置为 `.common`。
    func svgaDisplayLinkRunLoopMode(_ mode: RunLoop.Mode) -> SVGAPlayerView {
        var copy = self; copy.displayLinkRunLoopMode = mode; return copy
    }

    /// 状态变化回调
    func onSVGAStateChange(_ handler: @escaping (SVGAPlaybackState) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onStateChange = handler; return copy
    }

    /// 帧变化回调
    func onSVGAFrameChange(_ handler: @escaping (Int, Double) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onFrameChange = handler; return copy
    }

    /// 播放完成回调
    func onSVGAComplete(_ handler: @escaping () -> Void) -> SVGAPlayerView {
        var copy = self; copy.onComplete = handler; return copy
    }

    /// 错误回调
    func onSVGAError(_ handler: @escaping (SVGAError) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onError = handler; return copy
    }
}
