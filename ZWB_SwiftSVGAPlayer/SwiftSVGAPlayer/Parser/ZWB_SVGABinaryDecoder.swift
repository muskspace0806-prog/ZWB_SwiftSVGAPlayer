// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGABinaryDecoder.swift

import UIKit
import CoreGraphics

final class SVGABinaryDecoder {

    nonisolated func decode(binaryData: Data, imageEntries: [String: Data]) throws -> SVGAVideo {
        let movie = try SVGAProtoDecoder.decodeMovie(from: binaryData)
        return try mapToVideo(movie: movie, imageEntries: imageEntries)
    }

    // MARK: - Mapping

    private nonisolated func mapToVideo(movie: SVGAProtoMovie, imageEntries: [String: Data]) throws -> SVGAVideo {
        let params = movie.params
        let size = CGSize(width: CGFloat(params.viewBoxWidth), height: CGFloat(params.viewBoxHeight))
        let fps    = params.fps > 0 ? params.fps : 20
        let frames = params.frames

        var images: [String: SVGAImageResource] = [:]
        let allImageData = mergeImageData(protoImages: movie.images, zipEntries: imageEntries)
        for (key, data) in allImageData {
            if let image = UIImage.svga_decode(from: data) {
                images[key] = SVGAImageResource(key: key, image: image)
            } else {
                svgaLogWarning("Failed to decode image for key: \(key)")
            }
        }

        let sprites = try movie.sprites.map { try mapSprite($0, totalFrames: frames) }
        let audios  = movie.audios.map { mapAudio($0, imageEntries: imageEntries) }

        return SVGAVideo(size: size, fps: fps, frames: frames,
                         sprites: sprites, images: images, audios: audios)
    }

    private nonisolated func mergeImageData(protoImages: [String: Data], zipEntries: [String: Data]) -> [String: Data] {
        var result = protoImages
        for (key, data) in zipEntries {
            let name = (key as NSString).lastPathComponent
            let keyWithoutExt = (name as NSString).deletingPathExtension
            if result[keyWithoutExt] == nil { result[keyWithoutExt] = data }
            if result[name] == nil { result[name] = data }
        }
        return result
    }

    private nonisolated func mapSprite(_ proto: SVGAProtoSprite, totalFrames: Int) throws -> SVGASprite {
        let frames = try proto.frames.map { try mapFrame($0) }
        return SVGASprite(
            imageKey: proto.imageKey.isEmpty ? nil : proto.imageKey,
            matteKey: proto.matteKey.isEmpty ? nil : proto.matteKey,
            frames: frames
        )
    }

    private nonisolated func mapFrame(_ proto: SVGAProtoFrame) throws -> SVGAFrame {
        let layout = SVGALayout(
            x: CGFloat(proto.layout.x), y: CGFloat(proto.layout.y),
            width: CGFloat(proto.layout.width), height: CGFloat(proto.layout.height)
        )
        let t = proto.transform
        let transform = CGAffineTransform(a: CGFloat(t.a), b: CGFloat(t.b),
                                          c: CGFloat(t.c), d: CGFloat(t.d),
                                          tx: CGFloat(t.tx), ty: CGFloat(t.ty))
        let clipPath: CGPath? = proto.clipPath.isEmpty ? nil : parseSVGPath(proto.clipPath)
        let shapes = proto.shapes.map { mapShape($0) }
        return SVGAFrame(alpha: CGFloat(proto.alpha), layout: layout,
                         transform: transform, clipPath: clipPath, shapes: shapes)
    }

    private nonisolated func mapShape(_ proto: SVGAProtoShape) -> SVGAShape {
        let style = mapShapeStyle(proto.style)
        let t = proto.transform
        let transform = CGAffineTransform(a: CGFloat(t.a), b: CGFloat(t.b),
                                          c: CGFloat(t.c), d: CGFloat(t.d),
                                          tx: CGFloat(t.tx), ty: CGFloat(t.ty))
        var type: SVGAShapeType = .shape
        var rectArgs: CGRect? = nil
        var ellipseArgs: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)? = nil

        switch proto.type {
        case .shape:   type = .shape
        case .rect:
            type = .rect
            if let r = proto.rectArgs {
                rectArgs = CGRect(x: CGFloat(r.x), y: CGFloat(r.y),
                                  width: CGFloat(r.width), height: CGFloat(r.height))
            }
        case .ellipse:
            type = .ellipse
            if let e = proto.ellipseArgs {
                ellipseArgs = (cx: CGFloat(e.cx), cy: CGFloat(e.cy),
                               rx: CGFloat(e.rx), ry: CGFloat(e.ry))
            }
        case .keep: type = .keep
        }

        return SVGAShape(type: type, style: style, transform: transform,
                         pathData: proto.pathArgs.isEmpty ? nil : proto.pathArgs,
                         rectArgs: rectArgs, ellipseArgs: ellipseArgs)
    }

    private nonisolated func mapShapeStyle(_ proto: SVGAProtoShapeStyle) -> SVGAShapeStyle {
        let fillColor   = proto.fill.isEmpty   ? nil : UIColor.svga_color(fromHex: proto.fill)
        let strokeColor = proto.stroke.isEmpty ? nil : UIColor.svga_color(fromHex: proto.stroke)
        let lineCap: CGLineCap
        switch proto.lineCap.lowercased() {
        case "round":  lineCap = .round
        case "square": lineCap = .square
        default:       lineCap = .butt
        }
        let lineJoin: CGLineJoin
        switch proto.lineJoin.lowercased() {
        case "round": lineJoin = .round
        case "bevel": lineJoin = .bevel
        default:      lineJoin = .miter
        }
        return SVGAShapeStyle(
            fillColor: fillColor, strokeColor: strokeColor,
            strokeWidth: CGFloat(proto.strokeWidth),
            lineCap: lineCap, lineJoin: lineJoin,
            miterLimit: CGFloat(proto.miterLimit),
            lineDashPattern: proto.lineDash.map { CGFloat($0) },
            lineDashOffset: CGFloat(proto.lineDashOffset)
        )
    }

    private nonisolated func mapAudio(_ proto: SVGAProtoAudio, imageEntries: [String: Data]) -> SVGAAudio {
        let audioData = imageEntries[proto.audioKey]
            ?? imageEntries[(proto.audioKey as NSString).lastPathComponent]
        return SVGAAudio(audioKey: proto.audioKey, startFrame: proto.startFrame,
                         endFrame: proto.endFrame, startTime: proto.startTime,
                         totalTime: proto.totalTime, data: audioData)
    }

    // MARK: - SVG Path Parser

    private nonisolated func parseSVGPath(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        var scanner = SVGPathScanner(d)
        var currentPoint = CGPoint.zero

        while !scanner.isAtEnd {
            guard let cmd = scanner.scanCommand() else { break }
            switch cmd {
            case "M", "m":
                while let p = scanner.scanPoint() {
                    let pt = cmd == "M" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    path.move(to: pt); currentPoint = pt
                }
            case "L", "l":
                while let p = scanner.scanPoint() {
                    let pt = cmd == "L" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    path.addLine(to: pt); currentPoint = pt
                }
            case "H", "h":
                while let x = scanner.scanNumber() {
                    let pt = cmd == "H" ? CGPoint(x: x, y: currentPoint.y)
                                       : CGPoint(x: currentPoint.x + x, y: currentPoint.y)
                    path.addLine(to: pt); currentPoint = pt
                }
            case "V", "v":
                while let y = scanner.scanNumber() {
                    let pt = cmd == "V" ? CGPoint(x: currentPoint.x, y: y)
                                       : CGPoint(x: currentPoint.x, y: currentPoint.y + y)
                    path.addLine(to: pt); currentPoint = pt
                }
            case "C", "c":
                while let p1 = scanner.scanPoint(), let p2 = scanner.scanPoint(), let p3 = scanner.scanPoint() {
                    let (cp1, cp2, ep): (CGPoint, CGPoint, CGPoint)
                    if cmd == "C" { cp1 = p1; cp2 = p2; ep = p3 }
                    else {
                        cp1 = CGPoint(x: currentPoint.x + p1.x, y: currentPoint.y + p1.y)
                        cp2 = CGPoint(x: currentPoint.x + p2.x, y: currentPoint.y + p2.y)
                        ep  = CGPoint(x: currentPoint.x + p3.x, y: currentPoint.y + p3.y)
                    }
                    path.addCurve(to: ep, control1: cp1, control2: cp2)
                    currentPoint = ep
                }
            case "Q", "q":
                while let p1 = scanner.scanPoint(), let p2 = scanner.scanPoint() {
                    let (cp, ep): (CGPoint, CGPoint)
                    if cmd == "Q" { cp = p1; ep = p2 }
                    else {
                        cp = CGPoint(x: currentPoint.x + p1.x, y: currentPoint.y + p1.y)
                        ep = CGPoint(x: currentPoint.x + p2.x, y: currentPoint.y + p2.y)
                    }
                    path.addQuadCurve(to: ep, control: cp)
                    currentPoint = ep
                }
            case "Z", "z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path.isEmpty ? nil : path
    }
}

// MARK: - UIColor hex helper

extension UIColor {
    static func svga_color(fromHex hex: String) -> UIColor? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str = String(str.dropFirst()) }
        var value: UInt64 = 0
        guard Scanner(string: str).scanHexInt64(&value) else { return nil }
        switch str.count {
        case 3:
            return UIColor(red: CGFloat((value >> 8) & 0xF) / 15,
                           green: CGFloat((value >> 4) & 0xF) / 15,
                           blue: CGFloat(value & 0xF) / 15, alpha: 1)
        case 6:
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                           green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        case 8:
            return UIColor(red: CGFloat((value >> 24) & 0xFF) / 255,
                           green: CGFloat((value >> 16) & 0xFF) / 255,
                           blue: CGFloat((value >> 8) & 0xFF) / 255,
                           alpha: CGFloat(value & 0xFF) / 255)
        default: return nil
        }
    }
}

// MARK: - SVG Path Scanner

private struct SVGPathScanner {
    let string: String
    var index: String.Index
    var isAtEnd: Bool { index >= string.endIndex }

    init(_ s: String) { string = s; index = s.startIndex }

    mutating func scanCommand() -> Character? {
        skipSeparators()
        guard !isAtEnd, string[index].isLetter else { return nil }
        let c = string[index]; index = string.index(after: index); return c
    }

    mutating func scanNumber() -> CGFloat? {
        skipSeparators()
        guard !isAtEnd else { return nil }
        var s = ""
        if string[index] == "-" || string[index] == "+" { s.append(string[index]); index = string.index(after: index) }
        while !isAtEnd && (string[index].isNumber || string[index] == ".") { s.append(string[index]); index = string.index(after: index) }
        if !isAtEnd && (string[index] == "e" || string[index] == "E") {
            s.append(string[index]); index = string.index(after: index)
            if !isAtEnd && (string[index] == "-" || string[index] == "+") { s.append(string[index]); index = string.index(after: index) }
            while !isAtEnd && string[index].isNumber { s.append(string[index]); index = string.index(after: index) }
        }
        return s.isEmpty ? nil : CGFloat(Double(s) ?? 0)
    }

    mutating func scanPoint() -> CGPoint? {
        guard let x = scanNumber(), let y = scanNumber() else { return nil }
        return CGPoint(x: x, y: y)
    }

    mutating func skipSeparators() {
        while !isAtEnd && (string[index].isWhitespace || string[index] == ",") {
            index = string.index(after: index)
        }
    }
}
