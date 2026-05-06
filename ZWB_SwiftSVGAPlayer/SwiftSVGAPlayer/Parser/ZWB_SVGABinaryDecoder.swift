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

    // MARK: - SVG Path Parser（完整实现，支持 M/L/H/V/C/S/Q/T/A/Z）

    private nonisolated func parseSVGPath(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        var scanner = SVGPathScanner(d)
        var currentPoint = CGPoint.zero
        var lastControlPoint = CGPoint.zero  // 用于 S/T 命令的反射控制点
        var lastCmd: Character = "M"

        while !scanner.isAtEnd {
            guard let cmd = scanner.scanCommand() else { break }

            switch cmd {
            case "M", "m":
                var first = true
                while let p = scanner.scanPoint() {
                    let pt = cmd == "M" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    if first { path.move(to: pt); first = false }
                    else { path.addLine(to: pt) }
                    currentPoint = pt; lastControlPoint = pt
                }

            case "L", "l":
                while let p = scanner.scanPoint() {
                    let pt = cmd == "L" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    path.addLine(to: pt); currentPoint = pt; lastControlPoint = pt
                }

            case "H", "h":
                while let x = scanner.scanNumber() {
                    let pt = cmd == "H" ? CGPoint(x: x, y: currentPoint.y)
                                       : CGPoint(x: currentPoint.x + x, y: currentPoint.y)
                    path.addLine(to: pt); currentPoint = pt; lastControlPoint = pt
                }

            case "V", "v":
                while let y = scanner.scanNumber() {
                    let pt = cmd == "V" ? CGPoint(x: currentPoint.x, y: y)
                                       : CGPoint(x: currentPoint.x, y: currentPoint.y + y)
                    path.addLine(to: pt); currentPoint = pt; lastControlPoint = pt
                }

            case "C", "c":
                while let p1 = scanner.scanPoint(), let p2 = scanner.scanPoint(), let p3 = scanner.scanPoint() {
                    let cp1 = cmd == "C" ? p1 : CGPoint(x: currentPoint.x + p1.x, y: currentPoint.y + p1.y)
                    let cp2 = cmd == "C" ? p2 : CGPoint(x: currentPoint.x + p2.x, y: currentPoint.y + p2.y)
                    let ep  = cmd == "C" ? p3 : CGPoint(x: currentPoint.x + p3.x, y: currentPoint.y + p3.y)
                    path.addCurve(to: ep, control1: cp1, control2: cp2)
                    lastControlPoint = cp2; currentPoint = ep
                }

            case "S", "s":
                // 平滑三次贝塞尔：cp1 是上一个 cp2 的反射点
                while let p2 = scanner.scanPoint(), let p3 = scanner.scanPoint() {
                    let cp1: CGPoint
                    if lastCmd == "C" || lastCmd == "c" || lastCmd == "S" || lastCmd == "s" {
                        cp1 = CGPoint(x: 2 * currentPoint.x - lastControlPoint.x,
                                      y: 2 * currentPoint.y - lastControlPoint.y)
                    } else {
                        cp1 = currentPoint
                    }
                    let cp2 = cmd == "S" ? p2 : CGPoint(x: currentPoint.x + p2.x, y: currentPoint.y + p2.y)
                    let ep  = cmd == "S" ? p3 : CGPoint(x: currentPoint.x + p3.x, y: currentPoint.y + p3.y)
                    path.addCurve(to: ep, control1: cp1, control2: cp2)
                    lastControlPoint = cp2; currentPoint = ep
                }

            case "Q", "q":
                while let p1 = scanner.scanPoint(), let p2 = scanner.scanPoint() {
                    let cp = cmd == "Q" ? p1 : CGPoint(x: currentPoint.x + p1.x, y: currentPoint.y + p1.y)
                    let ep = cmd == "Q" ? p2 : CGPoint(x: currentPoint.x + p2.x, y: currentPoint.y + p2.y)
                    path.addQuadCurve(to: ep, control: cp)
                    lastControlPoint = cp; currentPoint = ep
                }

            case "T", "t":
                // 平滑二次贝塞尔：控制点是上一个控制点的反射
                while let p = scanner.scanPoint() {
                    let cp: CGPoint
                    if lastCmd == "Q" || lastCmd == "q" || lastCmd == "T" || lastCmd == "t" {
                        cp = CGPoint(x: 2 * currentPoint.x - lastControlPoint.x,
                                     y: 2 * currentPoint.y - lastControlPoint.y)
                    } else {
                        cp = currentPoint
                    }
                    let ep = cmd == "T" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    path.addQuadCurve(to: ep, control: cp)
                    lastControlPoint = cp; currentPoint = ep
                }

            case "A", "a":
                // 椭圆弧：rx ry x-rotation large-arc-flag sweep-flag x y
                while let rx = scanner.scanNumber(),
                      let ry = scanner.scanNumber(),
                      let xRot = scanner.scanNumber(),
                      let largeArc = scanner.scanFlag(),
                      let sweep = scanner.scanFlag(),
                      let p = scanner.scanPoint() {
                    let ep = cmd == "A" ? p : CGPoint(x: currentPoint.x + p.x, y: currentPoint.y + p.y)
                    addArc(to: path, from: currentPoint, to: ep,
                           rx: rx, ry: ry, xRotDeg: xRot,
                           largeArc: largeArc, sweep: sweep)
                    currentPoint = ep; lastControlPoint = ep
                }

            case "Z", "z":
                path.closeSubpath()
                // closeSubpath 后 currentPoint 回到子路径起点（CGPath 内部处理）

            default:
                break
            }
            lastCmd = cmd
        }
        return path.isEmpty ? nil : path
    }

    // MARK: - SVG Arc → CGPath（端点参数化转中心参数化）

    private nonisolated func addArc(
        to path: CGMutablePath,
        from p1: CGPoint, to p2: CGPoint,
        rx: CGFloat, ry: CGFloat,
        xRotDeg: CGFloat,
        largeArc: Bool, sweep: Bool
    ) {
        guard rx > 0, ry > 0, p1 != p2 else {
            path.addLine(to: p2); return
        }

        let phi = xRotDeg * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        // Step 1: 转换到旋转坐标系
        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2
        let x1p =  cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Step 2: 修正半径
        var rx = abs(rx), ry = abs(ry)
        let x1pSq = x1p * x1p, y1pSq = y1p * y1p
        let rxSq = rx * rx, rySq = ry * ry
        let lambda = x1pSq / rxSq + y1pSq / rySq
        if lambda > 1 {
            let sqrtL = sqrt(lambda)
            rx *= sqrtL; ry *= sqrtL
        }
        let rxSq2 = rx * rx, rySq2 = ry * ry

        // Step 3: 计算中心点
        let num = Swift.max(0, rxSq2 * rySq2 - rxSq2 * y1pSq - rySq2 * x1pSq)
        let den = rxSq2 * y1pSq + rySq2 * x1pSq
        let sq = den > 0 ? sqrt(num / den) : 0
        let sign: CGFloat = (largeArc == sweep) ? -1 : 1
        let cxp =  sign * sq * rx * y1p / ry
        let cyp = -sign * sq * ry * x1p / rx

        // 转回原坐标系
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        // Step 4: 计算起始角和角度差
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            guard len > 0 else { return 0 }
            let a = acos(Swift.max(-1, Swift.min(1, dot / len)))
            return (ux * vy - uy * vx < 0) ? -a : a
        }

        let startAngle = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dAngle    = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                              (-x1p - cxp) / rx, (-y1p - cyp) / ry)

        if !sweep && dAngle > 0 { dAngle -= 2 * .pi }
        if  sweep && dAngle < 0 { dAngle += 2 * .pi }

        // Step 5: 用 CGPath addArc 近似（通过变换处理椭圆）
        var t = CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .rotated(by: phi)
            .scaledBy(x: rx, y: ry)

        path.addArc(center: .zero,
                    radius: 1,
                    startAngle: startAngle,
                    endAngle: startAngle + dAngle,
                    clockwise: !sweep,
                    transform: t)
        _ = t // suppress warning
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

    /// 扫描 arc flag（0 或 1，可能紧跟数字无分隔符）
    mutating func scanFlag() -> Bool? {
        skipSeparators()
        guard !isAtEnd else { return nil }
        let c = string[index]
        if c == "0" { index = string.index(after: index); return false }
        if c == "1" { index = string.index(after: index); return true }
        return nil
    }

    mutating func skipSeparators() {
        while !isAtEnd && (string[index].isWhitespace || string[index] == ",") {
            index = string.index(after: index)
        }
    }
}
