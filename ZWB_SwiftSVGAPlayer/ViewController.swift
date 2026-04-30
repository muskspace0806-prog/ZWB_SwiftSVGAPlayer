// ZWB_SwiftSVGAPlayer/ViewController.swift
// Demo ViewController - 展示 SwiftSVGAPlayer 完整功能

import UIKit

class ViewController: UIViewController {

    // MARK: - UI

    private lazy var playerView: SwiftSVGAPlayerView = {
        let v = SwiftSVGAPlayerView()
        v.contentMode = .scaleAspectFit
        v.backgroundColor = UIColor(white: 0.1, alpha: 1)
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    private lazy var stateLabel: UILabel = {
        let l = UILabel()
        l.text = "State: idle"
        l.textColor = .white
        l.font = .systemFont(ofSize: 13)
        l.textAlignment = .center
        return l
    }()

    private lazy var frameLabel: UILabel = {
        let l = UILabel()
        l.text = "Frame: 0 / 0"
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 12)
        l.textAlignment = .center
        return l
    }()

    private lazy var seekSlider: UISlider = {
        let s = UISlider()
        s.minimumValue = 0
        s.maximumValue = 1
        s.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        return s
    }()

    private lazy var playButton    = makeButton("▶ Play",    action: #selector(tapPlay))
    private lazy var pauseButton   = makeButton("⏸ Pause",   action: #selector(tapPause))
    private lazy var resumeButton  = makeButton("▶ Resume",  action: #selector(tapResume))
    private lazy var stopButton    = makeButton("⏹ Stop",    action: #selector(tapStop))
    private lazy var clearButton   = makeButton("🗑 Clear",   action: #selector(tapClear))
    private lazy var urlButton     = makeButton("🌐 URL",     action: #selector(tapURL))
    private lazy var localButton   = makeButton("📦 Local",   action: #selector(tapLocal))
    private lazy var rangeButton   = makeButton("📐 Range",   action: #selector(tapRange))
    private lazy var dynamicButton = makeButton("🎨 Dynamic", action: #selector(tapDynamic))
    private lazy var stopSceneSegment: UISegmentedControl = {
        let s = UISegmentedControl(items: ["Clear", "Leading", "Trailing", "Keep"])
        s.selectedSegmentIndex = 0
        s.tintColor = .systemBlue
        return s
    }()
    private lazy var loopSegment: UISegmentedControl = {
        let s = UISegmentedControl(items: ["Once", "×3", "∞"])
        s.selectedSegmentIndex = 2
        s.tintColor = .systemBlue
        return s
    }()
    private lazy var muteSwitch: UISwitch = {
        let sw = UISwitch()
        sw.addTarget(self, action: #selector(muteSwitchChanged(_:)), for: .valueChanged)
        return sw
    }()
    private lazy var debugSwitch: UISwitch = {
        let sw = UISwitch()
        sw.addTarget(self, action: #selector(debugSwitchChanged(_:)), for: .valueChanged)
        return sw
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.15, alpha: 1)
        title = "SwiftSVGAPlayer Demo"
        setupLayout()
        setupCallbacks()
    }

    // MARK: - Layout

    private func setupLayout() {
        // Player view
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            playerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 0.75)
        ])

        // Labels
        let labelStack = UIStackView(arrangedSubviews: [stateLabel, frameLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 4
        view.addSubview(labelStack)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: 8),
            labelStack.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            labelStack.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
        ])

        // Seek slider
        view.addSubview(seekSlider)
        seekSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            seekSlider.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 8),
            seekSlider.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            seekSlider.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
        ])

        // Loop segment
        let loopLabel = makeLabel("Loop:")
        let loopRow = makeRow([loopLabel, loopSegment])

        // Stop scene segment
        let stopLabel = makeLabel("Stop:")
        let stopRow = makeRow([stopLabel, stopSceneSegment])

        // Mute / Debug row
        let muteLabel  = makeLabel("Mute:")
        let debugLabel = makeLabel("Debug:")
        let toggleRow  = makeRow([muteLabel, muteSwitch, debugLabel, debugSwitch])

        // Control buttons
        let row1 = makeRow([playButton, pauseButton, resumeButton])
        let row2 = makeRow([stopButton, clearButton])
        let row3 = makeRow([urlButton, localButton, rangeButton, dynamicButton])

        let mainStack = UIStackView(arrangedSubviews: [
            loopRow, stopRow, toggleRow, row1, row2, row3
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: seekSlider.bottomAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
        ])
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        playerView.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.stateLabel.text = "State: \(state)"
            }
        }
        playerView.onFrameChange = { [weak self] frame, progress in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.frameLabel.text = "Frame: \(frame) / \(self.playerView.totalFrames)"
                if !self.seekSlider.isTracking {
                    self.seekSlider.value = Float(progress)
                }
            }
        }
        playerView.onCompletion = { [weak self] in
            DispatchQueue.main.async {
                self?.stateLabel.text = "State: completed ✅"
            }
        }
        playerView.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.showAlert("Error", message: error.description)
            }
        }
    }

    // MARK: - Actions

    @objc private func tapPlay() {
        playerView.play(loop: selectedLoopMode)
    }

    @objc private func tapPause() {
        playerView.pause()
    }

    @objc private func tapResume() {
        playerView.resume()
    }

    @objc private func tapStop() {
        playerView.stop(then: selectedStopScene)
    }

    @objc private func tapClear() {
        playerView.clear()
        seekSlider.value = 0
    }

    @objc private func tapURL() {
        // 弹出输入框让用户填写 URL，默认填入官方样例
        let alert = UIAlertController(title: "输入 SVGA URL", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = "https://github.com/svga/SVGA-Samples/raw/master/angel.svga"
            tf.clearButtonMode = .whileEditing
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "播放", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let text = alert?.textFields?.first?.text,
                  let url = URL(string: text) else { return }
            Task {
                do {
                    try await self.playerView.load(.url(url))
                    self.playerView.play(loop: self.selectedLoopMode)
                } catch { }
            }
        })
        present(alert, animated: true)
    }

    @objc private func tapLocal() {
        // 弹出输入框让用户填写文件名（不含扩展名）
        let alert = UIAlertController(title: "本地 SVGA 文件名", message: "输入 Bundle 内 .svga 文件名（不含扩展名）", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = "test01"
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "播放", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let name = alert?.textFields?.first?.text, !name.isEmpty else { return }
            Task {
                do {
                    try await self.playerView.load(.named(name))
                    self.playerView.play(loop: self.selectedLoopMode)
                } catch SVGAError.fileNotFound {
                    await MainActor.run {
                        self.showAlert("文件不存在", message: "Bundle 中找不到 \(name).svga\n\n请将 .svga 文件拖入 Xcode 工程并勾选 Add to target")
                    }
                } catch { }
            }
        })
        present(alert, animated: true)
    }

    @objc private func tapRange() {
        // 播放第 5~15 帧
        playerView.play(range: 5..<15, loop: selectedLoopMode)
    }

    @objc private func tapDynamic() {
        // 演示动态文字替换
        let attr = NSAttributedString(
            string: "SwiftSVGAPlayer",
            attributes: [
                .foregroundColor: UIColor.systemYellow,
                .font: UIFont.boldSystemFont(ofSize: 14)
            ]
        )
        playerView.setText(attr, forKey: "name")

        // 演示动态图片（用系统图标代替）
        if let img = UIImage(systemName: "star.fill")?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
            playerView.setImage(img, forKey: "avatar")
        }

        showAlert("Dynamic", message: "已设置动态文字 'name' 和动态图片 'avatar'")
    }

    @objc private func sliderChanged(_ slider: UISlider) {
        playerView.seek(progress: Double(slider.value))
    }

    @objc private func muteSwitchChanged(_ sw: UISwitch) {
        playerView.isMuted = sw.isOn
    }

    @objc private func debugSwitchChanged(_ sw: UISwitch) {
        playerView.isDebugLogEnabled = sw.isOn
    }

    // MARK: - Helpers

    private var selectedLoopMode: SVGALoopMode {
        switch loopSegment.selectedSegmentIndex {
        case 0: return .once
        case 1: return .count(3)
        default: return .forever
        }
    }

    private var selectedStopScene: SVGAStopScene {
        switch stopSceneSegment.selectedSegmentIndex {
        case 0: return .clearLayers
        case 1: return .stepToLeading
        case 2: return .stepToTrailing
        default: return .keepCurrentFrame
        }
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        b.backgroundColor = UIColor(white: 0.25, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 8
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 13)
        l.setContentHuggingPriority(.required, for: .horizontal)
        return l
    }

    private func makeRow(_ views: [UIView]) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.distribution = .fillProportionally
        return s
    }

    private func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
