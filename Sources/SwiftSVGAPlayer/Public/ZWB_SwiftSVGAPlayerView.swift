// Sources/SwiftSVGAPlayer/Public/ZWB_SwiftSVGAPlayerView.swift

import UIKit
import QuartzCore

/// SVGA 播放器视图（Public API 入口）
public final class SwiftSVGAPlayerView: UIView {

    // MARK: - Public Properties

    /// 是否静音
    public var isMuted: Bool = false {
        didSet { audioController.isMuted = isMuted }
    }

    /// 是否反向播放
    public var isReversed: Bool = false {
        didSet { playbackController.isReversed = isReversed }
    }

    /// 是否开启 debug 日志
    public var isDebugLogEnabled: Bool = false {
        didSet {
            SVGALogger.shared.logLevel = isDebugLogEnabled ? .debug : .warning
        }
    }

    /// 停止后是否清空图层（默认 false，由 stop(then:) 控制）
    public var clearsAfterStop: Bool = false

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
    private var pendingLoopMode: SVGALoopMode = .forever
    private var pendingRange: Range<Int>? = nil

    // MARK: - Init

    public init(frame: CGRect = .zero, parser: SVGAParsing = SVGAParser.shared) {
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
        backgroundColor = .clear
        layer.addSublayer(renderLayer)
        setupPlaybackController()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateRenderLayerFrame()
    }

    // MARK: - Layout

    private func updateRenderLayerFrame() {
        guard let video = currentVideo else {
            renderLayer.frame = bounds
            return
        }
        let canvasSize = video.size
        let viewSize = bounds.size
        guard canvasSize.width > 0, canvasSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            renderLayer.frame = bounds
            return
        }

        let frame: CGRect
        switch contentMode {
        case .scaleToFill:
            frame = bounds
        case .scaleAspectFit:
            let scale = min(viewSize.width / canvasSize.width,
                            viewSize.height / canvasSize.height)
            let w = canvasSize.width * scale
            let h = canvasSize.height * scale
            frame = CGRect(x: (viewSize.width - w) / 2,
                           y: (viewSize.height - h) / 2,
                           width: w, height: h)
        case .scaleAspectFill:
            let scale = max(viewSize.width / canvasSize.width,
                            viewSize.height / canvasSize.height)
            let w = canvasSize.width * scale
            let h = canvasSize.height * scale
            frame = CGRect(x: (viewSize.width - w) / 2,
                           y: (viewSize.height - h) / 2,
                           width: w, height: h)
        default:
            frame = CGRect(origin: .zero, size: canvasSize)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        renderLayer.frame = frame
        // 缩放 render layer 内容以适应 frame
        if frame.size != canvasSize {
            let sx = frame.width / canvasSize.width
            let sy = frame.height / canvasSize.height
            renderLayer.transform = CATransform3DMakeScale(sx, sy, 1)
        } else {
            renderLayer.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }

    // MARK: - Load

    /// 异步加载 SVGA 资源
    @discardableResult
    public func load(_ source: SVGASource) async throws -> SVGAVideo {
        // 取消上一个加载任务
        loadTask?.cancel()

        setState(.loading)
        currentSource = source

        do {
            let video = try await parser.parse(source)

            // 检查是否已被新的 load 请求取代
            guard currentSource == source else {
                throw SVGAError.cancelled
            }

            await MainActor.run {
                self.currentVideo = video
                self.totalFrames = video.frames
                self.renderLayer.configure(video: video)
                self.updateRenderLayerFrame()
                self.audioController.configure(audios: video.audios, fps: video.clampedFPS)
                self.setState(.ready)
            }
            return video
        } catch let error as SVGAError {
            await MainActor.run {
                self.setState(.failed(error))
                self.onError?(error)
            }
            throw error
        } catch {
            let svgaError = SVGAError.internalError(error.localizedDescription)
            await MainActor.run {
                self.setState(.failed(svgaError))
                self.onError?(svgaError)
            }
            throw svgaError
        }
    }

    // MARK: - Play

    /// 使用默认 loopMode（.forever）播放
    public func play() {
        play(loop: pendingLoopMode)
    }

    /// 指定循环模式播放
    public func play(loop: SVGALoopMode) {
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        let range = (pendingRange ?? (0..<video.frames)).clamped(toTotalFrames: video.frames)
        startPlayback(video: video, range: range, loop: loop)
    }

    /// 加载并播放（一行调用）
    public func play(_ source: SVGASource, loop: SVGALoopMode = .forever) {
        pendingLoopMode = loop
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.load(source)
                await MainActor.run { self.play(loop: loop) }
            } catch {
                // 错误已在 load 中处理
            }
        }
    }

    /// 指定帧范围播放
    public func play(range: Range<Int>, loop: SVGALoopMode) {
        pendingRange = range
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        let clampedRange = range.clamped(toTotalFrames: video.frames)
        startPlayback(video: video, range: clampedRange, loop: loop)
    }

    // MARK: - Control

    public func pause() {
        playbackController.pause()
        audioController.pause()
    }

    public func resume() {
        playbackController.resume()
        audioController.resume()
    }

    public func stop(then scene: SVGAStopScene = .clearLayers) {
        playbackController.stop()
        audioController.stop()

        DispatchQueue.svga_mainAsync {
            self.applyStopScene(scene)
        }
    }

    public func seek(toFrame frame: Int) {
        playbackController.seek(toFrame: frame)
        renderLayer.step(to: frame)
        audioController.seek(toFrame: frame)
        currentFrame = frame
        onFrameChange?(frame, progress)
    }

    public func seek(progress: Double) {
        guard totalFrames > 0 else { return }
        let frame = Int(Double(totalFrames - 1) * max(0, min(progress, 1)))
        seek(toFrame: frame)
    }

    public func clear() {
        loadTask?.cancel()
        loadTask = nil
        playbackController.stop()
        audioController.stop()
        renderLayer.clearLayers()
        currentVideo = nil
        currentSource = nil
        currentFrame = 0
        totalFrames = 0
        setState(.idle)
    }

    // MARK: - Dynamic Content

    public func setImage(_ image: UIImage?, forKey key: String) {
        if let image = image {
            renderLayer.setDynamicItem(.image(image), forKey: key)
        } else {
            renderLayer.setDynamicItem(nil, forKey: key)
        }
    }

    public func setImageURL(_ url: URL?, forKey key: String) {
        guard let url = url else {
            renderLayer.setDynamicItem(nil, forKey: key)
            return
        }
        // 异步加载图片
        Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage.svga_decode(from: data) {
                    await MainActor.run {
                        self?.renderLayer.setDynamicItem(.image(image), forKey: key)
                    }
                }
            } catch {
                svgaLogWarning("Failed to load dynamic image URL: \(url) - \(error)")
            }
        }
    }

    public func setText(_ text: NSAttributedString?, forKey key: String) {
        if let text = text {
            renderLayer.setDynamicItem(.text(text), forKey: key)
        } else {
            renderLayer.setDynamicItem(nil, forKey: key)
        }
    }

    public func setHidden(_ hidden: Bool, forKey key: String) {
        renderLayer.setDynamicItem(hidden ? .hidden : nil, forKey: key)
    }

    public func setDrawing(_ drawing: SVGADrawingBlock?, forKey key: String) {
        if let drawing = drawing {
            renderLayer.setDynamicItem(.drawing(drawing), forKey: key)
        } else {
            renderLayer.setDynamicItem(nil, forKey: key)
        }
    }

    // MARK: - Private Helpers

    private func startPlayback(video: SVGAVideo, range: Range<Int>, loop: SVGALoopMode) {
        playbackController.loopMode = loop
        playbackController.range = range
        playbackController.configure(totalFrames: video.frames, fps: video.clampedFPS)
        playbackController.startDriver(fps: video.clampedFPS)
    }

    private func setupPlaybackController() {
        playbackController.onFrameChange = { [weak self] frame in
            guard let self = self else { return }
            self.currentFrame = frame
            self.renderLayer.step(to: frame)
            self.audioController.update(frame: frame)
            self.onFrameChange?(frame, self.progress)
        }
        playbackController.onStateChange = { [weak self] newState in
            guard let self = self else { return }
            self.setState(newState)
        }
        playbackController.onComplete = { [weak self] in
            guard let self = self else { return }
            self.onCompletion?()
        }
    }

    private func setState(_ newState: SVGAPlaybackState) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    private func applyStopScene(_ scene: SVGAStopScene) {
        switch scene {
        case .clearLayers:
            renderLayer.clearLayers()
            if let video = currentVideo {
                renderLayer.configure(video: video)
            }
        case .stepToLeading:
            let frame = playbackController.range.lowerBound
            renderLayer.step(to: frame)
            currentFrame = frame
        case .stepToTrailing:
            let frame = playbackController.range.upperBound - 1
            renderLayer.step(to: frame)
            currentFrame = frame
        case .keepCurrentFrame:
            break // 保持当前帧，不做任何操作
        }
    }
}
