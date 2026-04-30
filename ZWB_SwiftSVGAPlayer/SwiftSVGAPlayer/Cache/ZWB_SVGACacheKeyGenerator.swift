// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Cache/ZWB_SVGACacheKeyGenerator.swift

import Foundation
import CryptoKit

/// 缓存 key 生成协议
protocol SVGACacheKeyGenerating {
    func cacheKey(for source: SVGASource) -> String?
}

/// 默认缓存 key 生成器（MD5）
final class SVGACacheKeyGenerator: SVGACacheKeyGenerating {
    static let shared = SVGACacheKeyGenerator()
    init() {}

    nonisolated func cacheKey(for source: SVGASource) -> String? {
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

    private nonisolated func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
