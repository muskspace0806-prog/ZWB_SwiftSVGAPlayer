// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Utils/ZWB_SVGALogger.swift

import Foundation

public enum SVGALogLevel: Int, Comparable {
    case verbose = 0, debug = 1, info = 2, warning = 3, error = 4, none = 5
    public static func < (lhs: SVGALogLevel, rhs: SVGALogLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

final class SVGALogger {
    static let shared = SVGALogger()
    var logLevel: SVGALogLevel = .warning
    var handler: ((SVGALogLevel, String) -> Void)?
    private init() {}

    nonisolated func log(_ level: SVGALogLevel, _ message: @autoclosure () -> String,
                         file: String = #file, function: String = #function, line: Int = #line) {
        guard level >= SVGALogger.shared.logLevel else { return }
        let msg = message()
        let fileName = (file as NSString).lastPathComponent
        let formatted = "[SVGA][\(tag(level))] \(fileName):\(line) - \(msg)"
        if let h = SVGALogger.shared.handler { h(level, formatted) }
        else { print(formatted) }
    }

    private nonisolated func tag(_ level: SVGALogLevel) -> String {
        switch level {
        case .verbose: return "V"
        case .debug:   return "D"
        case .info:    return "I"
        case .warning: return "W"
        case .error:   return "E"
        case .none:    return "-"
        }
    }
}

nonisolated func svgaLogVerbose(_ msg: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.verbose, msg(), file: file, function: function, line: line)
}
nonisolated func svgaLogDebug(_ msg: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.debug, msg(), file: file, function: function, line: line)
}
nonisolated func svgaLogInfo(_ msg: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.info, msg(), file: file, function: function, line: line)
}
nonisolated func svgaLogWarning(_ msg: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.warning, msg(), file: file, function: function, line: line)
}
nonisolated func svgaLogError(_ msg: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    SVGALogger.shared.log(.error, msg(), file: file, function: function, line: line)
}
