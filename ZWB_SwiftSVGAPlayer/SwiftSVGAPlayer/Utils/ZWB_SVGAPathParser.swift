// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Utils/ZWB_SVGAPathParser.swift
// SVG path d 字符串解析器（完整支持 M/L/H/V/C/S/Q/T/A/Z）

import CoreGraphics

enum SVGAPathParser {
    /// 将 SVG path d 字符串解析为 CGPath
    static func parse(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        var scanner = SVGAPathScanner(d)
        var cur = CGPoint.zero
        var lastCP = CGPoint.zero
        var lastCmd: Character = "M"

        while !scanner.isAtEnd {
            guard let cmd = scanner.scanCommand() else { break }
            switch cmd {

            case "M", "m":
                var first = true
                while let p = scanner.scanPoint() {
                    let pt = cmd == "M" ? p : cur + p
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                    cur = pt; lastCP = pt
                }

            case "L", "l":
                while let p = scanner.scanPoint() {
                    let pt = cmd == "L" ? p : cur + p
                    path.addLine(to: pt); cur = pt; lastCP = pt
                }

            case "H", "h":
                while let x = scanner.scanNumber() {
                    let pt = CGPoint(x: cmd == "H" ? x : cur.x + x, y: cur.y)
                    path.addLine(to: pt); cur = pt; lastCP = pt
                }

            case "V", "v":
                while let y = scanner.scanNumber() {
                    let pt = CGPoint(x: cur.x, y: cmd == "V" ? y : cur.y + y)
                    path.addLine(to: pt); cur = pt; lastCP = pt
                }

            case "C", "c":
                while let p1 = scanner.scanPoint(),
                      let p2 = scanner.scanPoint(),
                      let p3 = scanner.scanPoint() {
                    let cp1 = cmd == "C" ? p1 : cur + p1
                    let cp2 = cmd == "C" ? p2 : cur + p2
                    let ep  = cmd == "C" ? p3 : cur + p3
                    path.addCurve(to: ep, control1: cp1, control2: cp2)
                    lastCP = cp2; cur = ep
                }

            case "S", "s":
                while let p2 = scanner.scanPoint(), let p3 = scanner.scanPoint() {
                    let isCubic = lastCmd == "C" || lastCmd == "c" || lastCmd == "S" || lastCmd == "s"
                    let cp1 = isCubic ? CGPoint(x: 2*cur.x - lastCP.x, y: 2*cur.y - lastCP.y) : cur
                    let cp2 = cmd == "S" ? p2 : cur + p2
                    let ep  = cmd == "S" ? p3 : cur + p3
                    path.addCurve(to: ep, control1: cp1, control2: cp2)
                    lastCP = cp2; cur = ep
                }

            case "Q", "q":
                while let p1 = scanner.scanPoint(), let p2 = scanner.scanPoint() {
                    let cp = cmd == "Q" ? p1 : cur + p1
                    let ep = cmd == "Q" ? p2 : cur + p2
                    path.addQuadCurve(to: ep, control: cp)
                    lastCP = cp; cur = ep
                }

            case "T", "t":
                while let p = scanner.scanPoint() {
                    let isQuad = lastCmd == "Q" || lastCmd == "q" || lastCmd == "T" || lastCmd == "t"
                    let cp = isQuad ? CGPoint(x: 2*cur.x - lastCP.x, y: 2*cur.y - lastCP.y) : cur
                    let ep = cmd == "T" ? p : cur + p
                    path.addQuadCurve(to: ep, control: cp)
                    lastCP = cp; cur = ep
                }

            case "A", "a":
                while let rx    = scanner.scanNumber(),
                      let ry    = scanner.scanNumber(),
                      let xRot  = scanner.scanNumber(),
                      let large = scanner.scanFlag(),
                      let sweep = scanner.scanFlag(),
                      let p     = scanner.scanPoint() {
                    let ep = cmd == "A" ? p : cur + p
                    addEllipticalArc(to: path, from: cur, to: ep,
                                     rx: rx, ry: ry, xRotDeg: xRot,
                                     largeArc: large, sweep: sweep)
                    cur = ep; lastCP = ep
                }

            case "Z", "z":
                path.closeSubpath()

            default: break
            }
            lastCmd = cmd
        }
        return path.isEmpty ? nil : path
    }

    // MARK: - Elliptical Arc（SVG spec §B.2.4）

    private static func addEllipticalArc(
        to path: CGMutablePath,
        from p1: CGPoint, to p2: CGPoint,
        rx: CGFloat, ry: CGFloat,
        xRotDeg: CGFloat, largeArc: Bool, sweep: Bool
    ) {
        guard rx > 0, ry > 0, p1 != p2 else { path.addLine(to: p2); return }

        let phi = xRotDeg * .pi / 180
        let cos𝜙 = cos(phi), sin𝜙 = sin(phi)

        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1p =  cos𝜙 * dx + sin𝜙 * dy
        let y1p = -sin𝜙 * dx + cos𝜙 * dy

        var rx = abs(rx), ry = abs(ry)
        let Λ = (x1p*x1p)/(rx*rx) + (y1p*y1p)/(ry*ry)
        if Λ > 1 { let s = sqrt(Λ); rx *= s; ry *= s }

        let rxSq = rx*rx, rySq = ry*ry
        let x1pSq = x1p*x1p, y1pSq = y1p*y1p
        let num = Swift.max(0, rxSq*rySq - rxSq*y1pSq - rySq*x1pSq)
        let den = rxSq*y1pSq + rySq*x1pSq
        let sq  = den > 0 ? sqrt(num/den) : 0
        let sign: CGFloat = (largeArc == sweep) ? -1 : 1
        let cxp =  sign * sq * rx * y1p / ry
        let cyp = -sign * sq * ry * x1p / rx

        let cx = cos𝜙*cxp - sin𝜙*cyp + (p1.x+p2.x)/2
        let cy = sin𝜙*cxp + cos𝜙*cyp + (p1.y+p2.y)/2

        func vecAngle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux*vx + uy*vy
            let len = sqrt((ux*ux+uy*uy)*(vx*vx+vy*vy))
            guard len > 0 else { return 0 }
            let a = acos(Swift.max(-1, Swift.min(1, dot/len)))
            return (ux*vy - uy*vx < 0) ? -a : a
        }

        let θ1 = vecAngle(1, 0, (x1p-cxp)/rx, (y1p-cyp)/ry)
        var dθ  = vecAngle((x1p-cxp)/rx, (y1p-cyp)/ry, (-x1p-cxp)/rx, (-y1p-cyp)/ry)
        if !sweep && dθ > 0 { dθ -= 2 * .pi }
        if  sweep && dθ < 0 { dθ += 2 * .pi }

        var t = CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .rotated(by: phi)
            .scaledBy(x: rx, y: ry)
        path.addArc(center: .zero, radius: 1,
                    startAngle: θ1, endAngle: θ1 + dθ,
                    clockwise: !sweep, transform: t)
        _ = t
    }
}

// MARK: - CGPoint arithmetic helper

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

// MARK: - Scanner

private struct SVGAPathScanner {
    let string: String
    var index: String.Index
    var isAtEnd: Bool { index >= string.endIndex }

    init(_ s: String) { string = s; index = s.startIndex }

    mutating func scanCommand() -> Character? {
        skip()
        guard !isAtEnd, string[index].isLetter else { return nil }
        let c = string[index]; index = string.index(after: index); return c
    }

    mutating func scanNumber() -> CGFloat? {
        skip()
        guard !isAtEnd else { return nil }
        var s = ""
        if string[index] == "-" || string[index] == "+" {
            s.append(string[index]); index = string.index(after: index)
        }
        while !isAtEnd && (string[index].isNumber || string[index] == ".") {
            s.append(string[index]); index = string.index(after: index)
        }
        if !isAtEnd && (string[index] == "e" || string[index] == "E") {
            s.append(string[index]); index = string.index(after: index)
            if !isAtEnd && (string[index] == "-" || string[index] == "+") {
                s.append(string[index]); index = string.index(after: index)
            }
            while !isAtEnd && string[index].isNumber {
                s.append(string[index]); index = string.index(after: index)
            }
        }
        return s.isEmpty ? nil : CGFloat(Double(s) ?? 0)
    }

    mutating func scanPoint() -> CGPoint? {
        guard let x = scanNumber(), let y = scanNumber() else { return nil }
        return CGPoint(x: x, y: y)
    }

    mutating func scanFlag() -> Bool? {
        skip()
        guard !isAtEnd else { return nil }
        let c = string[index]
        if c == "0" { index = string.index(after: index); return false }
        if c == "1" { index = string.index(after: index); return true }
        return nil
    }

    mutating func skip() {
        while !isAtEnd && (string[index].isWhitespace || string[index] == ",") {
            index = string.index(after: index)
        }
    }
}
