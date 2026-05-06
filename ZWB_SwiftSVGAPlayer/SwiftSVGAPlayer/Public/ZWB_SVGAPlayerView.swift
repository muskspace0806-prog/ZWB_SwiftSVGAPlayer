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
struct SVGAPlayerView: UIViewRepresentable {

    // MARK: - Configuration

    private let source: SVGASource
    private let loop: SVGALoopMode
    private var isReversed: Bool = false
    private var isMuted: Bool = false
    private var svgaContentMode: UIView.ContentMode = .scaleAspectFit
    private var onStateChange: ((SVGAPlaybackState) -> Void)? = nil
    private var onFrameChange: ((Int, Double) -> Void)? = nil
    private var onComplete: (() -> Void)? = nil
    private var onError: ((SVGAError) -> Void)? = nil

    // MARK: - Init

    init(source: SVGASource, loop: SVGALoopMode = .forever) {
        self.source = source
        self.loop   = loop
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> SwiftSVGAPlayerView {
        let view = SwiftSVGAPlayerView()
        view.contentMode = svgaContentMode
        return view
    }

    func updateUIView(_ uiView: SwiftSVGAPlayerView, context: Context) {
        uiView.contentMode   = svgaContentMode
        uiView.isReversed    = isReversed
        uiView.isMuted       = isMuted
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator {
        var lastSource: SVGASource? = nil
    }
}

// MARK: - Modifiers

@available(iOS 13.0, *)
extension SVGAPlayerView {

    func svgaReversed(_ reversed: Bool) -> SVGAPlayerView {
        var copy = self; copy.isReversed = reversed; return copy
    }

    func svgaMuted(_ muted: Bool) -> SVGAPlayerView {
        var copy = self; copy.isMuted = muted; return copy
    }

    func svgaContentMode(_ mode: UIView.ContentMode) -> SVGAPlayerView {
        var copy = self; copy.svgaContentMode = mode; return copy
    }

    func onSVGAStateChange(_ handler: @escaping (SVGAPlaybackState) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onStateChange = handler; return copy
    }

    func onSVGAFrameChange(_ handler: @escaping (Int, Double) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onFrameChange = handler; return copy
    }

    func onSVGAComplete(_ handler: @escaping () -> Void) -> SVGAPlayerView {
        var copy = self; copy.onComplete = handler; return copy
    }

    func onSVGAError(_ handler: @escaping (SVGAError) -> Void) -> SVGAPlayerView {
        var copy = self; copy.onError = handler; return copy
    }
}
