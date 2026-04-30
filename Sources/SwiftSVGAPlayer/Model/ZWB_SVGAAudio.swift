// Sources/SwiftSVGAPlayer/Model/ZWB_SVGAAudio.swift

import Foundation

/// SVGA 音频资源
public struct SVGAAudio {
    /// 音频文件 key（对应 zip 内文件名）
    public let audioKey: String
    /// 起始帧
    public let startFrame: Int
    /// 结束帧
    public let endFrame: Int
    /// 音频起始偏移（毫秒）
    public let startTime: Int
    /// 音频总时长（毫秒）
    public let totalTime: Int
    /// 原始音频数据
    public let data: Data?

    public init(
        audioKey: String,
        startFrame: Int,
        endFrame: Int,
        startTime: Int = 0,
        totalTime: Int = 0,
        data: Data? = nil
    ) {
        self.audioKey = audioKey
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.startTime = startTime
        self.totalTime = totalTime
        self.data = data
    }
}
