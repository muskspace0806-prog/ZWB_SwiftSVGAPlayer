// Sources/SwiftSVGAPlayer/Public/SVGALoopMode.swift

import Foundation

/// 播放循环模式
public enum SVGALoopMode: Equatable {
    /// 播放一次后停止
    case once
    /// 播放指定次数后停止（count <= 0 等同于 once）
    case count(Int)
    /// 无限循环
    case forever
}
