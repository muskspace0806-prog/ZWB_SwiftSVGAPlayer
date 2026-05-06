// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SVGASource.swift

import Foundation

enum SVGASource {
    case url(URL)
    case fileURL(URL)
    case data(Data, cacheKey: String?)
    case named(String, bundle: Bundle)

    static func named(_ name: String) -> SVGASource { .named(name, bundle: .main) }

    var debugDescription: String {
        switch self {
        case .url(let u):          return "url(\(u.absoluteString))"
        case .fileURL(let u):      return "fileURL(\(u.path))"
        case .data(_, let k):      return "data(cacheKey: \(k ?? "nil"))"
        case .named(let n, _):     return "named(\(n))"
        }
    }
}

extension SVGASource: Equatable {
    static func == (lhs: SVGASource, rhs: SVGASource) -> Bool {
        switch (lhs, rhs) {
        case (.url(let a), .url(let b)):             return a == b
        case (.fileURL(let a), .fileURL(let b)):     return a == b
        case (.data(_, let ka), .data(_, let kb)):   return ka == kb
        case (.named(let na, let ba), .named(let nb, let bb)): return na == nb && ba == bb
        default: return false
        }
    }
}
