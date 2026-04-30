// Sources/SwiftSVGAPlayer/Parser/ZWB_SVGALoadCoordinator.swift
// 加载防重：同一 key 的并发请求共享同一个 Task

import Foundation

/// 基于 actor 的加载协调器，防止同一 key 重复解析
actor SVGALoadCoordinator {

    private var tasks: [String: Task<SVGAVideo, Error>] = [:]

    /// 对同一 key 的并发调用共享同一个 Task；Task 完成后自动清理
    func load(
        key: String,
        operation: @escaping () async throws -> SVGAVideo
    ) async throws -> SVGAVideo {
        // 已有进行中的 Task，直接等待其结果
        if let existing = tasks[key] {
            svgaLogDebug("Reusing existing load task for key: \(key)")
            return try await existing.value
        }

        // 创建新 Task
        let task = Task<SVGAVideo, Error> {
            try await operation()
        }
        tasks[key] = task

        defer { tasks.removeValue(forKey: key) }

        return try await task.value
    }

    /// 取消指定 key 的加载任务
    func cancel(key: String) {
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }

    /// 取消所有加载任务
    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
