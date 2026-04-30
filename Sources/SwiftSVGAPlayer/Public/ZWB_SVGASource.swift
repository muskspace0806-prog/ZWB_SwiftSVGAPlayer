// Sources/SwiftSVGAPlayer/Public/SVGASource.swift

import Foundation

/// SVGA 资源来源
public enum SVGASource {
    /// 远程 URL（http/https）
    case url(URL)
    /// 本地文件 URL
    case fileURL(URL)
    /// 原始 Data，可选提供 cacheKey；无 cacheKey 则不缓存解析结果
    case data(Data, cacheKey: String?)
    /// Bundle 内资源名（不含扩展名），默认 .main bundle
    case named(String, bundle: Bundle)

    /// 便捷初始化：named，使用 main bundle
    public static func named(_ name: String) -> SVGASource {
        return .named(name, bundle: .main)
    }

    /// 用于日志和调试的描述字符串
    public var debugDescription: String {
        switch self {
        case .url(let url):
            return "url(\(url.absoluteString))"
        case .fileURL(let url):
            return "fileURL(\(url.path))"
        case .data(_, let key):
            return "data(cacheKey: \(key ?? "nil"))"
        case .named(let name, let bundle):
            return "named(\(name), bundle: \(bundle.bundleIdentifier ?? "unknown"))"
        }
    }
}

// MARK: - Equatable（Data 只比较 cacheKey）
extension SVGASource: Equatable {
    public static func == (lhs: SVGASource, rhs: SVGASource) -> Bool {
        switch (lhs, rhs) {
        case (.url(let a), .url(let b)):
            return a == b
        case (.fileURL(let a), .fileURL(let b)):
            return a == b
        case (.data(_, let ka), .data(_, let kb)):
            // Data 本身不比较，只比较 cacheKey
            return ka == kb
        case (.named(let na, let ba), .named(let nb, let bb)):
            return na == nb && ba == bb
        default:
            return false
        }
    }
}
