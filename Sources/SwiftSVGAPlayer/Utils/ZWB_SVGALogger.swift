// Sources/SwiftSVGAPlayer/Utils/SVGALogger.swift

import Foundation

/// 日志级别
public enum SVGALogLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case none = 5

    public static func < (lhs: SVGALogLevel, rhs: SVGALogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 全局日志工具，可通过 `SVGALogger.shared` 访问
public final class SVGALogger {
    public static let shared = SVGALogger()

    /// 当前最低输出级别，默认 `.warning`
    public var logLevel: SVGALogLevel = .warning

    /// 自定义日志处理器，设置后替代默认 print
    public var handler: ((SVGALogLevel, String) -> Void)?

    private init() {}

    func log(_ level: SVGALogLevel, _ message: @autoclosure () -> String,
             file: String = #file, function: String = #function, line: Int = #line) {
        guard level >= logLevel else { return }
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        let formatted = "[SwiftSVGAPlayer][\(levelTag(level))] \(fileName):\(line) \(function) - \(msg)"
        if let handler = handler {
            handler(level, formatted)
        } else {
            print(formatted)
        }
    }

    private func levelTag(_ level: SVGALogLevel) -> String {
        switch level {
        case .verbose: return "VERBOSE"
        case .debug:   return "DEBUG"
        case .info:    return "INFO"
        case .warning: return "WARNING"
        case .error:   return "ERROR"
        case .none:    return "NONE"
        }
    }
}

// MARK: - Convenience free functions

func svgaLog(_ level: SVGALogLevel, _ message: @autoclosure () -> String,
             file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(level, message(), file: file, function: function, line: line)
}

func svgaLogVerbose(_ message: @autoclosure () -> String,
                    file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.verbose, message(), file: file, function: function, line: line)
}

func svgaLogDebug(_ message: @autoclosure () -> String,
                  file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.debug, message(), file: file, function: function, line: line)
}

func svgaLogInfo(_ message: @autoclosure () -> String,
                 file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.info, message(), file: file, function: function, line: line)
}

func svgaLogWarning(_ message: @autoclosure () -> String,
                    file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.warning, message(), file: file, function: function, line: line)
}

func svgaLogError(_ message: @autoclosure () -> String,
                  file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.error, message(), file: file, function: function, line: line)
}
