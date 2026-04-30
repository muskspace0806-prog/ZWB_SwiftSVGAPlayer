// Sources/SwiftSVGAPlayer/Protobuf/ZWB_Svga.pb.swift
// 手写轻量级 Protobuf 解析器，对应 SVGA proto 定义
// 不依赖 SwiftProtobuf 运行时，完全纯 Swift 实现
// 对应 proto 版本：svga 2.x

import Foundation
import CoreGraphics

// MARK: - Protobuf Wire Types

private enum WireType: UInt8 {
    case varint          = 0
    case bit64           = 1
    case lengthDelimited = 2
    case bit32           = 5
}

// MARK: - Protobuf Reader

private struct ProtoReader {
    let data: Data
    var offset: Int = 0

    var isAtEnd: Bool { offset >= data.count }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while !isAtEnd {
            let byte = data[data.index(data.startIndex, offsetBy: offset)]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { throw SVGAError.protobufDecodeFailed("Varint overflow") }
        }
        throw SVGAError.protobufDecodeFailed("Unexpected end of data reading varint")
    }

    mutating func readTag() throws -> (fieldNumber: Int, wireType: WireType)? {
        guard !isAtEnd else { return nil }
        let raw = try readVarint()
        let fieldNumber = Int(raw >> 3)
        guard let wireType = WireType(rawValue: UInt8(raw & 0x7)) else {
            throw SVGAError.protobufDecodeFailed("Unknown wire type \(raw & 0x7)")
        }
        return (fieldNumber, wireType)
    }

    mutating func readBytes() throws -> Data {
        let length = Int(try readVarint())
        guard offset + length <= data.count else {
            throw SVGAError.protobufDecodeFailed("Length-delimited field out of bounds")
        }
        let start = data.index(data.startIndex, offsetBy: offset)
        let end   = data.index(start, offsetBy: length)
        offset += length
        return Data(data[start..<end])
    }

    mutating func readString() throws -> String {
        let bytes = try readBytes()
        return String(data: bytes, encoding: .utf8) ?? ""
    }

    mutating func readFloat() throws -> Float {
        guard offset + 4 <= data.count else {
            throw SVGAError.protobufDecodeFailed("Not enough bytes for float")
        }
        var value: Float = 0
        withUnsafeMutableBytes(of: &value) { ptr in
            data.copyBytes(to: ptr, from: data.index(data.startIndex, offsetBy: offset)..<data.index(data.startIndex, offsetBy: offset + 4))
        }
        offset += 4
        return value
    }

    mutating func skipField(wireType: WireType) throws {
        switch wireType {
        case .varint:
            _ = try readVarint()
        case .bit64:
            guard offset + 8 <= data.count else { throw SVGAError.protobufDecodeFailed("Skip bit64 OOB") }
            offset += 8
        case .lengthDelimited:
            _ = try readBytes()
        case .bit32:
            guard offset + 4 <= data.count else { throw SVGAError.protobufDecodeFailed("Skip bit32 OOB") }
            offset += 4
        }
    }
}

// MARK: - SVGA Proto Models

/// 对应 proto MovieEntity
struct SVGAProtoMovie {
    var version: String = ""
    var params: SVGAProtoMovieParams = SVGAProtoMovieParams()
    var images: [String: Data] = [:]
    var sprites: [SVGAProtoSprite] = []
    var audios: [SVGAProtoAudio] = []
}

struct SVGAProtoMovieParams {
    var viewBoxWidth: Float = 0
    var viewBoxHeight: Float = 0
    var fps: Int = 20
    var frames: Int = 0
}

struct SVGAProtoSprite {
    var imageKey: String = ""
    var frames: [SVGAProtoFrame] = []
    var matteKey: String = ""
}

struct SVGAProtoFrame {
    var alpha: Float = 1.0
    var layout: SVGAProtoLayout = SVGAProtoLayout()
    var transform: SVGAProtoTransform = SVGAProtoTransform()
    var clipPath: String = ""
    var shapes: [SVGAProtoShape] = []
}

struct SVGAProtoLayout {
    var x: Float = 0
    var y: Float = 0
    var width: Float = 0
    var height: Float = 0
}

struct SVGAProtoTransform {
    var a: Float = 1; var b: Float = 0
    var c: Float = 0; var d: Float = 1
    var tx: Float = 0; var ty: Float = 0
}

struct SVGAProtoShape {
    var type: SVGAProtoShapeType = .shape
    var style: SVGAProtoShapeStyle = SVGAProtoShapeStyle()
    var transform: SVGAProtoTransform = SVGAProtoTransform()
    var pathArgs: String = ""
    var rectArgs: SVGAProtoShapeRectArgs? = nil
    var ellipseArgs: SVGAProtoShapeEllipseArgs? = nil
}

enum SVGAProtoShapeType: Int {
    case shape = 0, rect = 1, ellipse = 2, keep = 3
}

struct SVGAProtoShapeStyle {
    var fill: String = ""
    var stroke: String = ""
    var strokeWidth: Float = 0
    var lineCap: String = "butt"
    var lineJoin: String = "miter"
    var miterLimit: Float = 10
    var lineDash: [Float] = []
    var lineDashOffset: Float = 0
}

struct SVGAProtoShapeRectArgs {
    var x: Float = 0; var y: Float = 0
    var width: Float = 0; var height: Float = 0
    var cornerRadius: Float = 0
}

struct SVGAProtoShapeEllipseArgs {
    var cx: Float = 0; var cy: Float = 0
    var rx: Float = 0; var ry: Float = 0
}

struct SVGAProtoAudio {
    var audioKey: String = ""
    var startFrame: Int = 0
    var endFrame: Int = 0
    var startTime: Int = 0
    var totalTime: Int = 0
}

// MARK: - Decoders

enum SVGAProtoDecoder {

    static func decodeMovie(from data: Data) throws -> SVGAProtoMovie {
        var reader = ProtoReader(data: data)
        var movie = SVGAProtoMovie()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: movie.version = try reader.readString()
            case 2:
                let bytes = try reader.readBytes()
                movie.params = try decodeMovieParams(from: bytes)
            case 3:
                // images: map<string, bytes>
                let bytes = try reader.readBytes()
                let (key, value) = try decodeMapEntry(from: bytes)
                movie.images[key] = value
            case 4:
                let bytes = try reader.readBytes()
                movie.sprites.append(try decodeSprite(from: bytes))
            case 5:
                let bytes = try reader.readBytes()
                movie.audios.append(try decodeAudio(from: bytes))
            default:
                try reader.skipField(wireType: tag.wireType)
            }
        }
        return movie
    }

    private static func decodeMovieParams(from data: Data) throws -> SVGAProtoMovieParams {
        var reader = ProtoReader(data: data)
        var p = SVGAProtoMovieParams()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: p.viewBoxWidth  = try reader.readFloat()
            case 2: p.viewBoxHeight = try reader.readFloat()
            case 3: p.fps    = Int(try reader.readVarint())
            case 4: p.frames = Int(try reader.readVarint())
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return p
    }

    private static func decodeMapEntry(from data: Data) throws -> (String, Data) {
        var reader = ProtoReader(data: data)
        var key = ""
        var value = Data()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: key   = try reader.readString()
            case 2: value = try reader.readBytes()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return (key, value)
    }

    private static func decodeSprite(from data: Data) throws -> SVGAProtoSprite {
        var reader = ProtoReader(data: data)
        var sprite = SVGAProtoSprite()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: sprite.imageKey = try reader.readString()
            case 2:
                let bytes = try reader.readBytes()
                sprite.frames.append(try decodeFrame(from: bytes))
            case 3: sprite.matteKey = try reader.readString()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return sprite
    }

    static func decodeFrame(from data: Data) throws -> SVGAProtoFrame {
        var reader = ProtoReader(data: data)
        var frame = SVGAProtoFrame()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: frame.alpha = try reader.readFloat()
            case 2:
                let bytes = try reader.readBytes()
                frame.layout = try decodeLayout(from: bytes)
            case 3:
                let bytes = try reader.readBytes()
                frame.transform = try decodeTransform(from: bytes)
            case 4: frame.clipPath = try reader.readString()
            case 5:
                let bytes = try reader.readBytes()
                frame.shapes.append(try decodeShape(from: bytes))
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return frame
    }

    private static func decodeLayout(from data: Data) throws -> SVGAProtoLayout {
        var reader = ProtoReader(data: data)
        var l = SVGAProtoLayout()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: l.x      = try reader.readFloat()
            case 2: l.y      = try reader.readFloat()
            case 3: l.width  = try reader.readFloat()
            case 4: l.height = try reader.readFloat()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return l
    }

    private static func decodeTransform(from data: Data) throws -> SVGAProtoTransform {
        var reader = ProtoReader(data: data)
        var t = SVGAProtoTransform()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: t.a  = try reader.readFloat()
            case 2: t.b  = try reader.readFloat()
            case 3: t.c  = try reader.readFloat()
            case 4: t.d  = try reader.readFloat()
            case 5: t.tx = try reader.readFloat()
            case 6: t.ty = try reader.readFloat()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return t
    }

    private static func decodeShape(from data: Data) throws -> SVGAProtoShape {
        var reader = ProtoReader(data: data)
        var shape = SVGAProtoShape()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: shape.type = SVGAProtoShapeType(rawValue: Int(try reader.readVarint())) ?? .shape
            case 2:
                let bytes = try reader.readBytes()
                shape.style = try decodeShapeStyle(from: bytes)
            case 3:
                let bytes = try reader.readBytes()
                shape.transform = try decodeTransform(from: bytes)
            case 4: shape.pathArgs = try reader.readString()
            case 5:
                let bytes = try reader.readBytes()
                shape.rectArgs = try decodeRectArgs(from: bytes)
            case 6:
                let bytes = try reader.readBytes()
                shape.ellipseArgs = try decodeEllipseArgs(from: bytes)
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return shape
    }

    private static func decodeShapeStyle(from data: Data) throws -> SVGAProtoShapeStyle {
        var reader = ProtoReader(data: data)
        var s = SVGAProtoShapeStyle()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: s.fill         = try reader.readString()
            case 2: s.stroke       = try reader.readString()
            case 3: s.strokeWidth  = try reader.readFloat()
            case 4: s.lineCap      = try reader.readString()
            case 5: s.lineJoin     = try reader.readString()
            case 6: s.miterLimit   = try reader.readFloat()
            case 7: s.lineDash.append(try reader.readFloat())
            case 8: s.lineDashOffset = try reader.readFloat()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return s
    }

    private static func decodeRectArgs(from data: Data) throws -> SVGAProtoShapeRectArgs {
        var reader = ProtoReader(data: data)
        var r = SVGAProtoShapeRectArgs()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: r.x            = try reader.readFloat()
            case 2: r.y            = try reader.readFloat()
            case 3: r.width        = try reader.readFloat()
            case 4: r.height       = try reader.readFloat()
            case 5: r.cornerRadius = try reader.readFloat()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return r
    }

    private static func decodeEllipseArgs(from data: Data) throws -> SVGAProtoShapeEllipseArgs {
        var reader = ProtoReader(data: data)
        var e = SVGAProtoShapeEllipseArgs()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: e.cx = try reader.readFloat()
            case 2: e.cy = try reader.readFloat()
            case 3: e.rx = try reader.readFloat()
            case 4: e.ry = try reader.readFloat()
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return e
    }

    private static func decodeAudio(from data: Data) throws -> SVGAProtoAudio {
        var reader = ProtoReader(data: data)
        var a = SVGAProtoAudio()
        while let tag = try reader.readTag() {
            switch tag.fieldNumber {
            case 1: a.audioKey   = try reader.readString()
            case 2: a.startFrame = Int(try reader.readVarint())
            case 3: a.endFrame   = Int(try reader.readVarint())
            case 4: a.startTime  = Int(try reader.readVarint())
            case 5: a.totalTime  = Int(try reader.readVarint())
            default: try reader.skipField(wireType: tag.wireType)
            }
        }
        return a
    }
}
