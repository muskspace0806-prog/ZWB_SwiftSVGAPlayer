// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGALoadCoordinator.swift

import Foundation

/// 基于 actor 的加载协调器，防止同一 key 重复解析
actor SVGALoadCoordinator {

    private var tasks: [String: Task<SVGAVideo, Error>] = [:]

    func load(
        key: String,
        operation: @escaping @Sendable () async throws -> SVGAVideo
    ) async throws -> SVGAVideo {
        if let existing = tasks[key] {
            svgaLogDebug("Reusing existing load task for key: \(key)")
            return try await existing.value
        }

        // 明确在非隔离上下文创建 Task，避免继承 @MainActor
        let task = Task<SVGAVideo, Error>(priority: .userInitiated) {
            try await operation()
        }
        tasks[key] = task
        defer { tasks.removeValue(forKey: key) }
        return try await task.value
    }

    func cancel(key: String) {
        tasks[key]?.cancel()
        tasks.removeValue(forKey: key)
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
