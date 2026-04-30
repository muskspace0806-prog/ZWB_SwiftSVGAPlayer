// Sources/SwiftSVGAPlayer/Cache/ZWB_SVGACacheKeyGenerator.swift

import Foundation
import CryptoKit

/// 缓存 key 生成协议
public protocol SVGACacheKeyGenerating {
    func cacheKey(for source: SVGASource) -> String?
}

/// 默认缓存 key 生成器
/// - URL：对 absoluteString 做 MD5
/// - fileURL：对 path 做 MD5
/// - named：对 "bundleID/name" 做 MD5
/// - data：直接使用调用方传入的 cacheKey，无则返回 nil
public final class SVGACacheKeyGenerator: SVGACacheKeyGenerating {
    public static let shared = SVGACacheKeyGenerator()
    public init() {}

    public func cacheKey(for source: SVGASource) -> String? {
        switch source {
        case .url(let url):
            return md5(url.absoluteString)
        case .fileURL(let url):
            return md5(url.path)
        case .data(_, let key):
            return key
        case .named(let name, let bundle):
            let bundleID = bundle.bundleIdentifier ?? "main"
            return md5("\(bundleID)/\(name)")
        }
    }

    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        if #available(iOS 13.0, *) {
            let digest = Insecure.MD5.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback：直接用字符串 hash（不会走到这里，iOS 13+ 保证）
            return String(string.hashValue, radix: 16)
        }
    }
}
