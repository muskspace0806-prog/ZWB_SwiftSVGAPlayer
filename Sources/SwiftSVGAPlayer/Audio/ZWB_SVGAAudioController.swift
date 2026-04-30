// Sources/SwiftSVGAPlayer/Audio/ZWB_SVGAAudioController.swift

import AVFoundation
import Foundation

/// 音频控制器（首版：基础播放/暂停/停止/mute）
final class SVGAAudioController {

    private var players: [String: AVAudioPlayer] = [:]
    private var audios: [SVGAAudio] = []
    private var fps: Int = 20
    var isMuted: Bool = false {
        didSet { players.values.forEach { $0.volume = isMuted ? 0 : 1 } }
    }

    // MARK: - Configure

    func configure(audios: [SVGAAudio], fps: Int) {
        stop()
        self.audios = audios
        self.fps = max(1, fps)

        for audio in audios {
            guard let data = audio.data else { continue }
            do {
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                player.volume = isMuted ? 0 : 1
                players[audio.audioKey] = player
            } catch {
                svgaLogWarning("Failed to create audio player for key: \(audio.audioKey) - \(error)")
            }
        }
    }

    // MARK: - Frame Sync

    func update(frame: Int) {
        for audio in audios {
            guard let player = players[audio.audioKey] else { continue }
            if frame == audio.startFrame {
                let offset = TimeInterval(audio.startTime) / 1000.0
                player.currentTime = offset
                if !player.isPlaying { player.play() }
            } else if frame >= audio.endFrame && player.isPlaying {
                player.stop()
            }
        }
    }

    // MARK: - Control

    func pause() {
        players.values.forEach { $0.pause() }
    }

    func resume() {
        players.values.filter { !$0.isPlaying }.forEach { $0.play() }
    }

    func stop() {
        players.values.forEach { $0.stop() }
        players.removeAll()
    }

    func seek(toFrame frame: Int) {
        for audio in audios {
            guard let player = players[audio.audioKey] else { continue }
            if frame >= audio.startFrame && frame < audio.endFrame {
                let frameDelta = frame - audio.startFrame
                let timeOffset = TimeInterval(audio.startTime) / 1000.0
                    + TimeInterval(frameDelta) / TimeInterval(fps)
                player.currentTime = timeOffset
            } else {
                player.stop()
            }
        }
    }
}
