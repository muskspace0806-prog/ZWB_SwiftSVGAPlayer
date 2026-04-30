// Sources/SwiftSVGAPlayer/Utils/DispatchQueue+SVGA.swift

import Foundation

extension DispatchQueue {
    /// 确保在主线程执行，若已在主线程则同步执行，否则异步派发
    static func svga_mainAsync(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// 后台解析队列（QoS: userInitiated）
    static let svgaParse: DispatchQueue = DispatchQueue(
        label: "com.swiftsvgaplayer.parse",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// 缓存操作队列（QoS: utility，串行）
    static let svgaCache: DispatchQueue = DispatchQueue(
        label: "com.swiftsvgaplayer.cache",
        qos: .utility
    )
}
