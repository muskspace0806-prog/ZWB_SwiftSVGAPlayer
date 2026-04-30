// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SVGAPlaybackState.swift

enum SVGAPlaybackState {
    case idle, loading, ready, playing, paused, stopped, completed
    case failed(SVGAError)
}

extension SVGAPlaybackState: Equatable {
    static func == (lhs: SVGAPlaybackState, rhs: SVGAPlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.ready, .ready),
             (.playing, .playing), (.paused, .paused),
             (.stopped, .stopped), (.completed, .completed): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

extension SVGAPlaybackState: CustomStringConvertible {
    var description: String {
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
