// Sources/SwiftSVGAPlayer/Public/SVGAPlaybackState.swift

import Foundation

/// 播放器状态机
public enum SVGAPlaybackState {
    /// 初始空闲状态
    case idle
    /// 正在加载/解析
    case loading
    /// 已就绪，可以播放
    case ready
    /// 正在播放
    case playing
    /// 已暂停
    case paused
    /// 已停止
    case stopped
    /// 播放完成（loop 结束）
    case completed
    /// 发生错误
    case failed(SVGAError)
}

extension SVGAPlaybackState: Equatable {
    public static func == (lhs: SVGAPlaybackState, rhs: SVGAPlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.ready, .ready),
             (.playing, .playing),
             (.paused, .paused),
             (.stopped, .stopped),
             (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

extension SVGAPlaybackState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:       return "idle"
        case .loading:    return "loading"
        case .ready:      return "ready"
        case .playing:    return "playing"
        case .paused:     return "paused"
        case .stopped:    return "stopped"
        case .completed:  return "completed"
        case .failed(let e): return "failed(\(e))"
        }
    }
}
