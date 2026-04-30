// Sources/SwiftSVGAPlayer/Utils/SVGAError.swift

import Foundation

/// SVGA 播放器统一错误类型
public enum SVGAError: Error, Equatable, CustomStringConvertible {
    case invalidSource
    case fileNotFound
    case downloadFailed(String)
    case invalidData
    case unzipFailed(String)
    case missingMovieFile
    case protobufDecodeFailed(String)
    case jsonDecodeFailed(String)
    case imageDecodeFailed(String)
    case unsupportedFeature(String)
    case cancelled
    case internalError(String)

    public var description: String {
        switch self {
        case .invalidSource:
            return "SVGAError: Invalid source"
        case .fileNotFound:
            return "SVGAError: File not found"
        case .downloadFailed(let msg):
            return "SVGAError: Download failed - \(msg)"
        case .invalidData:
            return "SVGAError: Invalid data"
        case .unzipFailed(let msg):
            return "SVGAError: Unzip failed - \(msg)"
        case .missingMovieFile:
            return "SVGAError: Missing movie.binary or movie.spec"
        case .protobufDecodeFailed(let msg):
            return "SVGAError: Protobuf decode failed - \(msg)"
        case .jsonDecodeFailed(let msg):
            return "SVGAError: JSON decode failed - \(msg)"
        case .imageDecodeFailed(let msg):
            return "SVGAError: Image decode failed - \(msg)"
        case .unsupportedFeature(let msg):
            return "SVGAError: Unsupported feature - \(msg)"
        case .cancelled:
            return "SVGAError: Cancelled"
        case .internalError(let msg):
            return "SVGAError: Internal error - \(msg)"
        }
    }
}
