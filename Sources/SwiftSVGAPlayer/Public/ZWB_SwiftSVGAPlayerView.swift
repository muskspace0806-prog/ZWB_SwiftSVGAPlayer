// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SwiftSVGAPlayerView.swift

import UIKit
import QuartzCore

/// SVGA 播放器视图
public final class SwiftSVGAPlayerView: UIView {

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
        setState(.loading)
        currentSource = source

        do {
            let video = try await parser.parse(source)
            guard currentSource == source else { throw SVGAError.cancelled }

            self.currentVideo = video
            self.totalFrames  = video.playbackFrames
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

    public func play() { play(loop: pendingLoopMode) }

    public func play(loop: SVGALoopMode) {
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        let range = (pendingRange ?? (0..<video.playbackFrames)).clamped(toTotalFrames: video.playbackFrames)
        startPlayback(video: video, range: range, loop: loop)
    }

    public func play(_ source: SVGASource, loop: SVGALoopMode = .forever) {
        pendingLoopMode = loop
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do { try await self.load(source); self.play(loop: loop) } catch {}
        }
    }

    public func play(range: Range<Int>, loop: SVGALoopMode) {
        pendingRange    = range
        pendingLoopMode = loop
        guard let video = currentVideo else { return }
        startPlayback(video: video, range: range.clamped(toTotalFrames: video.playbackFrames), loop: loop)
    }

    // MARK: - Control

    public func pause()  { playbackController.pause();  audioController.pause() }
    public func resume() { playbackController.resume(); audioController.resume() }

    public func stop(then scene: SVGAStopScene = .clearLayers) {
        playbackController.stop()
        audioController.stop()
        applyStopScene(scene)
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
        loadTask?.cancel(); loadTask = nil
        playbackController.stop()
        audioController.stop()
        renderLayer.clearLayers()
        currentVideo = nil; currentSource = nil
        currentFrame = 0;   totalFrames   = 0
        setState(.idle)
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

    private func setDynamicItemOnMain(_ item: SVGADynamicItem, forKey key: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.renderLayer.setDynamicItem(item, forKey: key)
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
}
