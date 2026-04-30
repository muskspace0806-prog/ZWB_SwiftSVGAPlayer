// Sources/SwiftSVGAPlayer/Public/SVGAStopScene.swift

import Foundation

/// 停止播放后的画面处理方式
public enum SVGAStopScene: Equatable {
    /// 清空所有图层（默认）
    case clearLayers
    /// 跳到第一帧
    case stepToLeading
    /// 跳到最后一帧
    case stepToTrailing
    /// 保持当前帧不变
    case keepCurrentFrame
}
