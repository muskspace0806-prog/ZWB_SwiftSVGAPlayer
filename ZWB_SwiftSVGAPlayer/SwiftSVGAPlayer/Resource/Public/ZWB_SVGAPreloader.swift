// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SVGAPreloader.swift

import Foundation

/// SVGA 预热器（1.0.3 新增）
///
/// 用于在真正展示动画之前（例如列表数据加载完成时）提前异步解析 SVGA 资源，
/// 解析结果会自动写入内存缓存与磁盘缓存。之后在 cell 上调用 `play(_:)`
/// 时即可命中内存缓存秒开，避免滚动时同步解码造成的掉帧/卡顿。
///
/// 内部复用 `SVGAParser.shared`，因此：
/// - 已在内存缓存中的资源会直接跳过（解析内部命中即返回）；
/// - 通过 `SVGALoadCoordinator` 防止同一资源重复解析；
/// - 使用并发上限控制，避免一次性几十个并发解码把 CPU 打满反而更卡。
public enum SVGAPreloader {

    /// 预热一组资源
    /// - Parameters:
    ///   - sources: 待预热的资源列表
    ///   - maxConcurrent: 最大并发解析数，默认 3
    public static func preload(_ sources: [SVGASource], maxConcurrent: Int = 3) async {
        let limit = Swift.max(1, maxConcurrent)
        let parser = SVGAParser.shared

        await withTaskGroup(of: Void.self) { group in
            var index = 0
            // 先填满并发窗口
            let initial = Swift.min(limit, sources.count)
            while index < initial {
                let source = sources[index]
                group.addTask { await SVGAPreloader.parseIgnoringError(source, parser: parser) }
                index += 1
            }
            // 每完成一个再补一个，保持并发数不超过 limit
            while index < sources.count {
                await group.next()
                let source = sources[index]
                group.addTask { await SVGAPreloader.parseIgnoringError(source, parser: parser) }
                index += 1
            }
        }
    }

    /// 预热一组远程 URL（便捷方法）
    /// - Parameters:
    ///   - urls: 远程 URL 列表
    ///   - maxConcurrent: 最大并发解析数，默认 3
    public static func preload(urls: [URL], maxConcurrent: Int = 3) async {
        await preload(urls.map { .url($0) }, maxConcurrent: maxConcurrent)
    }

    /// 预热一组远程 URL 字符串（自动过滤非法 URL）
    /// - Parameters:
    ///   - urlStrings: 远程 URL 字符串列表
    ///   - maxConcurrent: 最大并发解析数，默认 3
    public static func preload(urlStrings: [String], maxConcurrent: Int = 3) async {
        let urls = urlStrings.compactMap { URL(string: $0) }
        await preload(urls: urls, maxConcurrent: maxConcurrent)
    }

    /// 解析单个资源，忽略错误（预热失败不应影响业务流程）
    private static func parseIgnoringError(_ source: SVGASource, parser: SVGAParser) async {
        do {
            _ = try await parser.parse(source)
        } catch {
            svgaLogDebug("Preload failed for \(source.debugDescription): \(error)")
        }
    }
}
