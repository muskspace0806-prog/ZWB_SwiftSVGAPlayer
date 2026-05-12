// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SwiftSVGAPlayerView.swift

import UIKit
import QuartzCore

/// SVGA 播放器视图
final class SwiftSVGAPlayerView: UIView {

    // MARK: - Public Properties

    var isMuted: Bool = false {
        didSet { audioController.isMuted = isMuted }
    }
    var isReversed: Bool = false {
        didSet {
            playbackController.isReversed = isReversed
            // 播放中途切换方向：立即从当前帧反向继续，不重置帧
        }
    }
    var isDebugLogEnabled: Bool = false {
        didSet { SVGALogger.shared.logLevel = isDebugLogEnabled ? .debug : .warning }
    }
    var clearsAfterStop: Bool = false

    // MARK: - Readonly State

    private(set) var state: SVGAPlaybackState = .idle
    private(set) var currentFrame: Int = 0
    private(set) var totalFrames: Int = 0
    var progress: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(currentFrame) / Double(totalFrames - 1)
    }

    // MARK: - Callbacks

    var onStateChange: ((SVGAPlaybackState) -> Void)?
    var onFrameChange: ((_ frame: Int, _ progress: Double) -> Void)?
    var onCompletion: (() -> Void)?
    var onError: ((SVGAError) -> Void)?

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

    init(frame: CGRect = .zero, parser: SVGAParsing = SVGAParser.shared) {
        self.parser = parser
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.parser = SVGAParser.shared
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds   = true
        // anchorPoint 默认 (0.5,0.5)，position 初始居中
        renderLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.addSublayer(renderLayer)
        setupPlaybackController()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRenderLayerFrame()
    }

    // MARK: - Layout

    override var intrinsicContentSize: CGSize {
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
    func load(_ source: SVGASource) async throws -> SVGAVideo {
        loadTask?.cancel()
        setState(.loading)
        currentSource = source

        do {
            let video = try await parser.parse(source)
            guard currentSource == source else { throw SVGAError.cancelled }

            self.currentVideo = video
            self.totalFrames  = video.frames
            self.renderLayer.configure(video: video)
            self.updateRenderLayerFrame()
            self.audioController.configure(audios: video.audios, fps: video.clampedFPS)
            self.setState(.ready)
            return video

        } catch let error as SVGAError {
            self.setState(.failed(error))
            self.onError?(error)
            throw error
        } catch {
            let e = SVGAError.internalError(error.localizedDescription)
            self.setState(.failed(e))
            self.onError?(e)
            throw e
        }
    }

    // MARK: - Play

    func play() { play(loop: pendingLoopMode) }

    func play(loop: SVGALoopMode) {
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        let range = (pendingRange ?? (0..<video.frames)).clamped(toTotalFrames: video.frames)
        startPlayback(video: video, range: range, loop: loop)
    }

    func play(_ source: SVGASource, loop: SVGALoopMode = .forever) {
        pendingLoopMode = loop
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do { try await self.load(source); self.play(loop: loop) } catch {}
        }
    }

    func play(range: Range<Int>, loop: SVGALoopMode) {
        pendingRange    = range
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        startPlayback(video: video, range: range.clamped(toTotalFrames: video.frames), loop: loop)
    }

    // MARK: - Control

    func pause()  { playbackController.pause();  audioController.pause() }
    func resume() { playbackController.resume(); audioController.resume() }

    func stop(then scene: SVGAStopScene = .clearLayers) {
        playbackController.stop()
        audioController.stop()
        applyStopScene(scene)
    }

    func seek(toFrame frame: Int) {
        playbackController.seek(toFrame: frame)
        renderLayer.step(to: frame)
        audioController.seek(toFrame: frame)
        currentFrame = frame
        onFrameChange?(frame, progress)
    }

    func seek(progress: Double) {
        guard totalFrames > 0 else { return }
        seek(toFrame: Int(Double(totalFrames - 1) * Swift.max(0, Swift.min(progress, 1))))
    }

    func clear() {
        loadTask?.cancel(); loadTask = nil
        playbackController.stop()
        audioController.stop()
        renderLayer.clearLayers()
        currentVideo = nil; currentSource = nil
        currentFrame = 0;   totalFrames   = 0
        setState(.idle)
    }

    // MARK: - Dynamic Content

    func setImage(_ image: UIImage?, forKey key: String) {
        renderLayer.setDynamicItem(image.map { .image($0) }, forKey: key)
    }

    func setImageURL(_ url: URL?, forKey key: String) {
        guard let url = url else { renderLayer.setDynamicItem(nil, forKey: key); return }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage.svga_decode(from: data) {
                    self.renderLayer.setDynamicItem(.image(image), forKey: key)
                }
            } catch {
                svgaLogWarning("Failed to load dynamic image URL: \(url)")
            }
        }
    }

    func setText(_ text: NSAttributedString?, forKey key: String) {
        renderLayer.setDynamicItem(text.map { .text($0) }, forKey: key)
    }

    func setHidden(_ hidden: Bool, forKey key: String) {
        renderLayer.setDynamicItem(hidden ? .hidden : nil, forKey: key)
    }

    func setDrawing(_ drawing: SVGADrawingBlock?, forKey key: String) {
        renderLayer.setDynamicItem(drawing.map { .drawing($0) }, forKey: key)
    }

    // MARK: - Private Helpers

    private func startPlayback(video: SVGAVideo, range: Range<Int>, loop: SVGALoopMode) {
        playbackController.loopMode   = loop
        playbackController.range      = range
        playbackController.isReversed = isReversed   // 必须在 configure 之前设置，configure 用它决定起始帧
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
        playbackController.onStateChange = { [weak self] state in self?.setState(state) }
        playbackController.onComplete    = { [weak self] in self?.onCompletion?() }
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
}
