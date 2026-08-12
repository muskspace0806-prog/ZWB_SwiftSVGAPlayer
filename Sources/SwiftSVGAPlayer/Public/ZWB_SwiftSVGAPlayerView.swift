// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SwiftSVGAPlayerView.swift

import UIKit
import QuartzCore

/// SVGA 播放器视图
public final class SwiftSVGAPlayerView: UIView {

    // MARK: - Debug

    private static var debugNextIdentifier: Int = 0
    private static var debugLiveInstanceCount: Int = 0
    private static var debugPlayingInstanceCount: Int = 0
    private static let debugLock = NSLock()

    private let debugIdentifier: Int = SwiftSVGAPlayerView.makeDebugIdentifier()
    private var debugIsPlaying: Bool = false

    // MARK: - Public Properties

    public var isMuted: Bool = false {
        didSet { audioController.isMuted = isMuted }
    }
    public var isReversed: Bool = false {
        didSet {
            playbackController.isReversed = isReversed
            // 播放中途切换方向：立即从当前帧反向继续，不重置帧
        }
    }
    public var isDebugLogEnabled: Bool = false {
        didSet { SVGALogger.shared.logLevel = isDebugLogEnabled ? .debug : .warning }
    }
    public var clearsAfterStop: Bool = false
    /// CADisplayLink 所在 RunLoop mode。默认 `.default` 以减少滚动场景抢占主线程；全屏礼物等需要滚动期间持续播放的场景可设置为 `.common`。
    public var displayLinkRunLoopMode: RunLoop.Mode = .default
    /// 外部已托管可见性时，跳过播放器内部每帧层级裁剪判断，适用于跑马灯这类父视图持续位移的场景。
    public var usesExternalVisibilityControl: Bool = false

    // MARK: - Readonly State

    public private(set) var state: SVGAPlaybackState = .idle
    public private(set) var currentFrame: Int = 0
    public private(set) var totalFrames: Int = 0
    public var progress: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(currentFrame) / Double(totalFrames - 1)
    }

    // MARK: - Callbacks

    public var onStateChange: ((SVGAPlaybackState) -> Void)?
    public var onFrameChange: ((_ frame: Int, _ progress: Double) -> Void)?
    public var onCompletion: (() -> Void)?
    public var onError: ((SVGAError) -> Void)?

    // MARK: - Private

    private let renderLayer = SVGARenderLayer()
    private let playbackController = SVGAPlaybackController()
    private let audioController = SVGAAudioController()
    private let parser: SVGAParsing

    private var currentVideo: SVGAVideo?
    private var currentSource: SVGASource?
    private var loadTask: Task<Void, Never>?
    private var loadTaskID: UInt = 0
    private var pendingLoopMode: SVGALoopMode = .forever
    private var pendingRange: Range<Int>? = nil
    private var shouldResumeWhenAttachedToWindow = false
    private var needsPlaybackOnWindowAttach = false

    private static func makeDebugIdentifier() -> Int {
        debugLock.lock()
        defer { debugLock.unlock() }
        debugNextIdentifier += 1
        return debugNextIdentifier
    }

    private static func updateDebugCounts(liveDelta: Int = 0, playingDelta: Int = 0) -> (live: Int, playing: Int) {
        debugLock.lock()
        defer { debugLock.unlock() }
        debugLiveInstanceCount += liveDelta
        debugPlayingInstanceCount += playingDelta
        return (debugLiveInstanceCount, debugPlayingInstanceCount)
    }

    private static func debugCounts() -> (live: Int, playing: Int) {
        debugLock.lock()
        defer { debugLock.unlock() }
        return (debugLiveInstanceCount, debugPlayingInstanceCount)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        let counts = SwiftSVGAPlayerView.debugCounts()
        print("【ZWB性能排查】SwiftSVGAPlayerView#\(debugIdentifier) \(message) live=\(counts.live) playing=\(counts.playing) state=\(state)")
        #endif
    }

    private func updateDebugPlaying(_ isPlaying: Bool) {
        guard debugIsPlaying != isPlaying else { return }
        debugIsPlaying = isPlaying
        let counts = SwiftSVGAPlayerView.updateDebugCounts(playingDelta: isPlaying ? 1 : -1)
        #if DEBUG
        print("【ZWB性能排查】SwiftSVGAPlayerView#\(debugIdentifier) playing=\(isPlaying) live=\(counts.live) playing=\(counts.playing)")
        #endif
    }

    // MARK: - Init

    public override init(frame: CGRect = .zero) {
        self.parser = SVGAParser.shared
        super.init(frame: frame)
        setup()
    }

    init(frame: CGRect = .zero, parser: SVGAParsing) {
        self.parser = parser
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.parser = SVGAParser.shared
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let counts = SwiftSVGAPlayerView.updateDebugCounts(liveDelta: 1)
        #if DEBUG
        print("【ZWB性能排查】SwiftSVGAPlayerView#\(debugIdentifier) init live=\(counts.live) playing=\(counts.playing)")
        #endif
        backgroundColor = .clear
        clipsToBounds   = true
        // anchorPoint 默认 (0.5,0.5)，position 初始居中
        renderLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.addSublayer(renderLayer)
        setupPlaybackController()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateRenderLayerFrame()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            pausePlaybackForWindowDetach()
        } else {
            resumePlaybackAfterWindowAttachIfNeeded()
        }
    }

    // MARK: - Layout

    public override var intrinsicContentSize: CGSize {
        return super.intrinsicContentSize
    }

    private func updateRenderLayerFrame() {
        guard let video = currentVideo else {
            renderLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            return
        }
        let canvasSize = video.size
        let viewSize   = bounds.size
        guard canvasSize.width > 0, canvasSize.height > 0,
              viewSize.width > 0,   viewSize.height > 0 else { return }

        let scale: CGFloat
        switch contentMode {
        case .scaleToFill:
            let sx = viewSize.width  / canvasSize.width
            let sy = viewSize.height / canvasSize.height
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            renderLayer.transform = CATransform3DMakeScale(sx, sy, 1)
            renderLayer.position  = CGPoint(x: bounds.midX, y: bounds.midY)
            CATransaction.commit()
            return
        case .scaleAspectFill:
            scale = Swift.max(viewSize.width  / canvasSize.width,
                              viewSize.height / canvasSize.height)
        default: // scaleAspectFit（默认）
            scale = Swift.min(viewSize.width  / canvasSize.width,
                              viewSize.height / canvasSize.height)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // bounds 保持 canvasSize 不变，transform 做均匀缩放，position 居中
        renderLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        renderLayer.position  = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    // MARK: - Load

    @discardableResult
    public func load(_ source: SVGASource) async throws -> SVGAVideo {
        loadTask?.cancel()
        loadTask = nil
        loadTaskID &+= 1
        return try await loadSource(source)
    }

    @discardableResult
    private func loadSource(_ source: SVGASource) async throws -> SVGAVideo {
        let loadStartTime = CFAbsoluteTimeGetCurrent()
        debugLog("load start source=\(source)")
        setState(.loading)
        currentSource = source

        do {
            let video = try await parser.parse(source)
            guard !Task.isCancelled else { throw SVGAError.cancelled }
            guard currentSource == source else { throw SVGAError.cancelled }

            self.currentVideo = video
            self.totalFrames  = video.playbackFrames
            self.renderLayer.configure(video: video)
            self.updateRenderLayerFrame()
            self.audioController.configure(audios: video.audios, fps: video.clampedFPS)
            self.setState(.ready)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - loadStartTime) * 1000)
            debugLog("load success elapsed=\(elapsed)ms frames=\(video.playbackFrames) fps=\(video.clampedFPS) size=\(video.size)")
            return video

        } catch let error as SVGAError {
            self.setState(.failed(error))
            self.onError?(error)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - loadStartTime) * 1000)
            debugLog("load failed elapsed=\(elapsed)ms error=\(error)")
            throw error
        } catch {
            let e = SVGAError.internalError(error.localizedDescription)
            self.setState(.failed(e))
            self.onError?(e)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - loadStartTime) * 1000)
            debugLog("load failed elapsed=\(elapsed)ms error=\(error.localizedDescription)")
            throw e
        }
    }

    // MARK: - Play

    public func play() { play(loop: pendingLoopMode) }

    public func play(loop: SVGALoopMode) {
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        let range = (pendingRange ?? (0..<video.playbackFrames)).clamped(toTotalFrames: video.playbackFrames)
        startPlayback(video: video, range: range, loop: loop)
    }

    public func play(_ source: SVGASource, loop: SVGALoopMode = .forever) {
        debugLog("play source request loop=\(loop)")
        pendingLoopMode = loop
        loadTask?.cancel()
        loadTaskID &+= 1
        let taskID = loadTaskID
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            defer {
                if self.loadTaskID == taskID {
                    self.loadTask = nil
                }
            }
            do {
                try await self.loadSource(source)
                guard !Task.isCancelled, self.loadTaskID == taskID else { return }
                self.play(loop: loop)
            } catch {}
        }
    }

    public func play(range: Range<Int>, loop: SVGALoopMode) {
        pendingRange    = range
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        startPlayback(video: video, range: range.clamped(toTotalFrames: video.playbackFrames), loop: loop)
    }

    // MARK: - Control

    public func pause()  {
        shouldResumeWhenAttachedToWindow = false
        needsPlaybackOnWindowAttach = false
        playbackController.pause()
        audioController.pause()
        updateDebugPlaying(false)
        debugLog("pause")
    }

    public func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        loadTaskID &+= 1
        if state == .loading {
            setState(currentVideo == nil ? .idle : .ready)
        }
        debugLog("cancel loading")
    }

    public func resume() {
        if needsPlaybackOnWindowAttach {
            needsPlaybackOnWindowAttach = false
            debugLog("resume deferred playback")
            play(loop: pendingLoopMode)
            return
        }
        guard window != nil else {
            shouldResumeWhenAttachedToWindow = true
            debugLog("resume deferred window=nil")
            return
        }
        playbackController.resume()
        audioController.resume()
        if currentVideo != nil {
            updateDebugPlaying(true)
        }
        debugLog("resume")
    }

    public func stop(then scene: SVGAStopScene = .clearLayers) {
        loadTask?.cancel()
        loadTask = nil
        loadTaskID &+= 1
        shouldResumeWhenAttachedToWindow = false
        needsPlaybackOnWindowAttach = false
        playbackController.stop()
        audioController.stop()
        applyStopScene(scene)
        updateDebugPlaying(false)
        debugLog("stop scene=\(scene)")
    }

    public func seek(toFrame frame: Int) {
        guard totalFrames > 0 else { return }
        let clampedFrame = Swift.max(0, Swift.min(frame, totalFrames - 1))
        playbackController.seek(toFrame: clampedFrame)
        renderLayer.step(to: clampedFrame)
        audioController.seek(toFrame: clampedFrame)
        currentFrame = clampedFrame
        onFrameChange?(clampedFrame, progress)
    }

    public func seek(progress: Double) {
        guard totalFrames > 0 else { return }
        seek(toFrame: Int(Double(totalFrames - 1) * Swift.max(0, Swift.min(progress, 1))))
    }

    public func clear() {
        loadTaskID &+= 1
        loadTask?.cancel(); loadTask = nil
        shouldResumeWhenAttachedToWindow = false
        needsPlaybackOnWindowAttach = false
        playbackController.stop()
        audioController.stop()
        renderLayer.clearLayers()
        currentVideo = nil; currentSource = nil
        currentFrame = 0;   totalFrames   = 0
        setState(.idle)
        updateDebugPlaying(false)
        debugLog("clear")
    }

    // MARK: - Dynamic Content

    public func setImage(_ image: UIImage?, forKey key: String) {
        renderLayer.setDynamicItem(image.map { .image($0) }, forKey: key)
    }

    public func setImage(_ image: UIImage?, forKey key: String, options: SVGADynamicImageOptions) {
        renderLayer.setDynamicItem(image.map { .imageWithOptions($0, options) }, forKey: key)
    }

    public func setImageURL(_ url: URL?, forKey key: String) {
        guard let url = url else { renderLayer.setDynamicItem(nil, forKey: key); return }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage.svga_decode(from: data) {
                    self.setDynamicItemOnMain(.image(image), forKey: key)
                }
            } catch {
                svgaLogWarning("Failed to load dynamic image URL: \(url)")
            }
        }
    }

    public func setImageURL(_ url: URL?, forKey key: String, options: SVGADynamicImageOptions) {
        guard let url = url else { renderLayer.setDynamicItem(nil, forKey: key); return }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage.svga_decode(from: data) {
                    self.setDynamicItemOnMain(.imageWithOptions(image, options), forKey: key)
                }
            } catch {
                svgaLogWarning("Failed to load dynamic image URL: \(url)")
            }
        }
    }

    public func setText(_ text: NSAttributedString?, forKey key: String) {
        renderLayer.setDynamicItem(text.map { .text($0) }, forKey: key)
    }

    public func setHidden(_ hidden: Bool, forKey key: String) {
        renderLayer.setDynamicItem(hidden ? .hidden : nil, forKey: key)
    }

    public func setDrawing(_ drawing: SVGADrawingBlock?, forKey key: String) {
        renderLayer.setDynamicItem(drawing.map { .drawing($0) }, forKey: key)
    }

    // MARK: - Private Helpers

    private func startPlayback(video: SVGAVideo, range: Range<Int>, loop: SVGALoopMode) {
        playbackController.loopMode   = loop
        playbackController.isReversed = isReversed   // 必须在 configure 之前设置，configure 用它决定起始帧
        playbackController.configure(totalFrames: video.playbackFrames, fps: video.clampedFPS, range: range)
        let startFrame = isReversed ? range.upperBound - 1 : range.lowerBound
        currentFrame = startFrame
        renderLayer.step(to: startFrame)
        audioController.seek(toFrame: startFrame)
        guard window != nil, isRenderableByCurrentVisibilityPolicy else {
            // 视图还未挂到 window 或处于隐藏/离屏裁剪状态时不启动 CADisplayLink，避免不可见播放器常驻刷新。
            needsPlaybackOnWindowAttach = true
            updateDebugPlaying(false)
            setState(.paused)
            debugLog("start deferred invisible frames=\(video.playbackFrames) fps=\(video.clampedFPS)")
            return
        }
        needsPlaybackOnWindowAttach = false
        playbackController.startDriver(fps: video.clampedFPS, runLoopMode: displayLinkRunLoopMode)
        updateDebugPlaying(true)
        debugLog("start playback frames=\(video.playbackFrames) fps=\(video.clampedFPS) mode=\(displayLinkRunLoopMode)")
    }

    private func setupPlaybackController() {
        playbackController.onFrameChange = { [weak self] frame in
            guard let self = self else { return }
            self.currentFrame = frame
            guard self.isRenderableByCurrentVisibilityPolicy else { return }
            self.renderLayer.step(to: frame)
            self.audioController.update(frame: frame)
            self.onFrameChange?(frame, self.progress)
        }
        playbackController.onStateChange = { [weak self] state in self?.setState(state) }
        playbackController.onComplete    = { [weak self] in self?.onCompletion?() }
    }

    private func setState(_ newState: SVGAPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    private func setDynamicItemOnMain(_ item: SVGADynamicItem, forKey key: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.renderLayer.setDynamicItem(item, forKey: key)
            guard self.isRenderableByCurrentVisibilityPolicy else { return }
            if self.totalFrames > 0 {
                self.renderLayer.step(to: self.currentFrame)
            }
        }
    }

    private func applyStopScene(_ scene: SVGAStopScene) {
        switch scene {
        case .clearLayers:
            renderLayer.clearLayers()
            if let video = currentVideo { renderLayer.configure(video: video) }
        case .stepToLeading:
            let f = playbackController.range.lowerBound
            renderLayer.step(to: f); currentFrame = f
        case .stepToTrailing:
            let f = playbackController.range.upperBound - 1
            renderLayer.step(to: f); currentFrame = f
        case .keepCurrentFrame:
            break
        }
    }

    private func pausePlaybackForWindowDetach() {
        guard state == .playing else { return }
        shouldResumeWhenAttachedToWindow = true
        playbackController.pause()
        audioController.pause()
        updateDebugPlaying(false)
        debugLog("auto pause window detach")
    }

    private func resumePlaybackAfterWindowAttachIfNeeded() {
        if needsPlaybackOnWindowAttach {
            needsPlaybackOnWindowAttach = false
            play(loop: pendingLoopMode)
            return
        }
        guard shouldResumeWhenAttachedToWindow else { return }
        shouldResumeWhenAttachedToWindow = false
        playbackController.resume()
        audioController.resume()
        if currentVideo != nil {
            updateDebugPlaying(true)
        }
        debugLog("auto resume window attach")
    }

    /// 判断播放器是否处在真实可见的裁剪层级内，避免跑马灯复制视图离屏后仍逐帧渲染。
    private var isFrameRenderableInHierarchy: Bool {
        guard window != nil,
              bounds.width > 0,
              bounds.height > 0 else { return false }

        var currentView: UIView? = self
        while let view = currentView {
            if view.isHidden || view.alpha <= 0.01 {
                return false
            }

            if let superview = view.superview {
                if superview.clipsToBounds || superview.layer.masksToBounds {
                    let visibleRect = view.convert(view.bounds, to: superview)
                    if visibleRect.isEmpty || !visibleRect.intersects(superview.bounds) {
                        return false
                    }
                }
                currentView = superview
            } else {
                break
            }
        }

        return true
    }

    private var isRenderableByCurrentVisibilityPolicy: Bool {
        usesExternalVisibilityControl || isFrameRenderableInHierarchy
    }

    deinit {
        updateDebugPlaying(false)
        let counts = SwiftSVGAPlayerView.updateDebugCounts(liveDelta: -1)
        #if DEBUG
        print("【ZWB性能排查】SwiftSVGAPlayerView#\(debugIdentifier) deinit live=\(counts.live) playing=\(counts.playing)")
        #endif
        loadTask?.cancel()
        onStateChange = nil
        onFrameChange = nil
        onCompletion = nil
        onError = nil
        currentVideo = nil
        currentSource = nil
    }
}
