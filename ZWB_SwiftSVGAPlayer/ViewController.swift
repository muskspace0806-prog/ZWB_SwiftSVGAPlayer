// ZWB_SwiftSVGAPlayer/ViewController.swift

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

    private lazy var playButton        = makeButton("▶ Play",    action: #selector(tapPlay))
    private lazy var pauseResumeButton = makeButton("⏸ Pause",   action: #selector(tapPauseResume))
    private lazy var urlButton         = makeButton("🌐 URL",     action: #selector(tapURL))
    private lazy var localButton       = makeButton("📦 Local",   action: #selector(tapLocal))

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

    private lazy var reverseSwitch: UISwitch = {
        let sw = UISwitch()
        sw.addTarget(self, action: #selector(reverseSwitchChanged(_:)), for: .valueChanged)
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
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            playerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 0.75)
        ])

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

        view.addSubview(seekSlider)
        seekSlider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            seekSlider.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 8),
            seekSlider.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            seekSlider.trailingAnchor.constraint(equalTo: playerView.trailingAnchor)
        ])

        // Loop
        let loopRow = makeRow([makeLabel("Loop:"), loopSegment])

        // Mute / Debug / Reverse
        let toggleRow = makeRow([
            makeLabel("Mute:"),    muteSwitch,
            makeLabel("Debug:"),   debugSwitch,
            makeLabel("Reverse:"), reverseSwitch
        ])

        // Buttons
        let btnRow1 = makeRow([playButton, pauseResumeButton])
        let btnRow2 = makeRow([urlButton, localButton])

        let mainStack = UIStackView(arrangedSubviews: [loopRow, toggleRow, btnRow1, btnRow2])
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
            self?.stateLabel.text = "State: \(state)"
            // 同步 Pause/Resume 按钮标题
            if state == .paused {
                self?.pauseResumeButton.setTitle("▶ Resume", for: .normal)
            } else if state == .playing {
                self?.pauseResumeButton.setTitle("⏸ Pause", for: .normal)
            }
        }
        playerView.onFrameChange = { [weak self] frame, progress in
            guard let self = self else { return }
            self.frameLabel.text = "Frame: \(frame) / \(self.playerView.totalFrames)"
            if !self.seekSlider.isTracking {
                self.seekSlider.value = Float(progress)
            }
        }
        playerView.onCompletion = { [weak self] in
            self?.stateLabel.text = "State: completed ✅"
            self?.pauseResumeButton.setTitle("⏸ Pause", for: .normal)
        }
        playerView.onError = { [weak self] error in
            self?.showAlert("Error", message: error.description)
        }
    }

    // MARK: - Actions

    @objc private func tapPlay() {
        playerView.play(loop: selectedLoopMode)
    }

    @objc private func tapPauseResume() {
        switch playerView.state {
        case .playing:
            playerView.pause()
        case .paused:
            playerView.resume()
        default:
            playerView.play(loop: selectedLoopMode)
        }
    }

    @objc private func tapURL() {
        let alert = UIAlertController(title: "输入 SVGA URL", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = "https://res.gimmelive.net/level_2_boom.svga"
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
        let alert = UIAlertController(title: "本地 SVGA", message: "输入 Bundle 内文件名（不含扩展名）", preferredStyle: .alert)
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
                        self.showAlert("文件不存在", message: "找不到 \(name).svga，请确认已加入 target")
                    }
                } catch { }
            }
        })
        present(alert, animated: true)
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

    @objc private func reverseSwitchChanged(_ sw: UISwitch) {
        playerView.isReversed = sw.isOn
    }

    // MARK: - Helpers

    private var selectedLoopMode: SVGALoopMode {
        switch loopSegment.selectedSegmentIndex {
        case 0: return .once
        case 1: return .count(3)
        default: return .forever
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
