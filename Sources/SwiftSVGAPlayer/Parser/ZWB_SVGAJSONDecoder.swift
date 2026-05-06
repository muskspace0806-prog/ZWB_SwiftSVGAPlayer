// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGAJSONDecoder.swift

import UIKit
import CoreGraphics

final class SVGAJSONDecoder {

    nonisolated func decode(specData: Data, imageEntries: [String: Data]) throws -> SVGAVideo {
        guard let json = try? JSONSerialization.jsonObject(with: specData) as? [String: Any] else {
            throw SVGAError.jsonDecodeFailed("Invalid JSON structure")
        }
        return try mapToVideo(json: json, imageEntries: imageEntries)
    }

    private nonisolated func mapToVideo(json: [String: Any], imageEntries: [String: Data]) throws -> SVGAVideo {
        guard let movieJson = json["movie"] as? [String: Any] else {
            throw SVGAError.jsonDecodeFailed("Missing 'movie' key")
        }
        let viewBox = movieJson["viewBox"] as? [String: Any]
        let width   = CGFloat((viewBox?["width"]  as? Double) ?? 0)
        let height  = CGFloat((viewBox?["height"] as? Double) ?? 0)
        let fps     = (movieJson["fps"]    as? Int) ?? 20
        let frames  = (movieJson["frames"] as? Int) ?? 0

        var images: [String: SVGAImageResource] = [:]
        for (key, data) in imageEntries {
            let name = (key as NSString).lastPathComponent
            let keyWithoutExt = (name as NSString).deletingPathExtension
            if let image = UIImage.svga_decode(from: data) {
                images[keyWithoutExt] = SVGAImageResource(key: keyWithoutExt, image: image)
            }
        }

        let spritesJson = json["sprites"] as? [[String: Any]] ?? []
        let sprites = try spritesJson.map { try mapSprite($0, totalFrames: frames) }

        return SVGAVideo(size: CGSize(width: width, height: height),
                         fps: fps, frames: frames,
                         sprites: sprites, images: images, audios: [])
    }

    private nonisolated func mapSprite(_ json: [String: Any], totalFrames: Int) throws -> SVGASprite {
        let imageKey = json["imageKey"] as? String
        let matteKey = json["matteKey"] as? String
        let framesJson = json["frames"] as? [[String: Any]] ?? []
        let frames = try framesJson.map { try mapFrame($0) }
        return SVGASprite(imageKey: imageKey, matteKey: matteKey, frames: frames)
    }

    private nonisolated func mapFrame(_ json: [String: Any]) throws -> SVGAFrame {
        let alpha = CGFloat((json["alpha"] as? Double) ?? 1.0)
        let layoutJson = json["layout"] as? [String: Any]
        let layout = SVGALayout(
            x:      CGFloat((layoutJson?["x"]      as? Double) ?? 0),
            y:      CGFloat((layoutJson?["y"]      as? Double) ?? 0),
            width:  CGFloat((layoutJson?["width"]  as? Double) ?? 0),
            height: CGFloat((layoutJson?["height"] as? Double) ?? 0)
        )
        let transformJson = json["transform"] as? [String: Any]
        let transform: CGAffineTransform
        if let t = transformJson {
            transform = CGAffineTransform(
                a:  CGFloat((t["a"]  as? Double) ?? 1),
                b:  CGFloat((t["b"]  as? Double) ?? 0),
                c:  CGFloat((t["c"]  as? Double) ?? 0),
                d:  CGFloat((t["d"]  as? Double) ?? 1),
                tx: CGFloat((t["tx"] as? Double) ?? 0),
                ty: CGFloat((t["ty"] as? Double) ?? 0)
            )
        } else {
            transform = .identity
        }
        // clipPath
        let clipPath: CGPath?
        if let clipStr = json["clipPath"] as? String, !clipStr.isEmpty {
            clipPath = SVGAPathParser.parse(clipStr)
        } else {
            clipPath = nil
        }
        // shapes（JSON 格式中的矢量形状）
        let shapesJson = json["shapes"] as? [[String: Any]] ?? []
        let shapes = shapesJson.compactMap { mapJSONShape($0) }

        return SVGAFrame(alpha: alpha, layout: layout, transform: transform,
                         clipPath: clipPath, shapes: shapes)
    }

    private nonisolated func mapJSONShape(_ json: [String: Any]) -> SVGAShape? {
        let typeStr = json["type"] as? String ?? "shape"
        let type: SVGAShapeType
        switch typeStr {
        case "rect":    type = .rect
        case "ellipse": type = .ellipse
        case "keep":    type = .keep
        default:        type = .shape
        }

        let styleJson = json["style"] as? [String: Any] ?? [:]
        let style = SVGAShapeStyle(
            fillColor:       (styleJson["fill"]        as? String).flatMap { UIColor.svga_color(fromHex: $0) },
            strokeColor:     (styleJson["stroke"]      as? String).flatMap { UIColor.svga_color(fromHex: $0) },
            strokeWidth:     CGFloat((styleJson["strokeWidth"]  as? Double) ?? 0),
            lineCap:         lineCap(from: styleJson["lineCap"]  as? String),
            lineJoin:        lineJoin(from: styleJson["lineJoin"] as? String),
            miterLimit:      CGFloat((styleJson["miterLimit"]   as? Double) ?? 10),
            lineDashPattern: (styleJson["lineDash"] as? [Double] ?? []).map { CGFloat($0) },
            lineDashOffset:  CGFloat((styleJson["lineDashOffset"] as? Double) ?? 0)
        )

        let tJson = json["transform"] as? [String: Any]
        let transform: CGAffineTransform = tJson.map {
            CGAffineTransform(
                a:  CGFloat(($0["a"]  as? Double) ?? 1),
                b:  CGFloat(($0["b"]  as? Double) ?? 0),
                c:  CGFloat(($0["c"]  as? Double) ?? 0),
                d:  CGFloat(($0["d"]  as? Double) ?? 1),
                tx: CGFloat(($0["tx"] as? Double) ?? 0),
                ty: CGFloat(($0["ty"] as? Double) ?? 0)
            )
        } ?? .identity

        var pathData: String? = nil
        var rectArgs: CGRect? = nil
        var ellipseArgs: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)? = nil

        switch type {
        case .shape:
            pathData = json["d"] as? String
        case .rect:
            if let r = json["rect"] as? [String: Any] {
                rectArgs = CGRect(
                    x:      CGFloat((r["x"]      as? Double) ?? 0),
                    y:      CGFloat((r["y"]      as? Double) ?? 0),
                    width:  CGFloat((r["width"]  as? Double) ?? 0),
                    height: CGFloat((r["height"] as? Double) ?? 0)
                )
            }
        case .ellipse:
            if let e = json["ellipse"] as? [String: Any] {
                ellipseArgs = (
                    cx: CGFloat((e["cx"] as? Double) ?? 0),
                    cy: CGFloat((e["cy"] as? Double) ?? 0),
                    rx: CGFloat((e["rx"] as? Double) ?? 0),
                    ry: CGFloat((e["ry"] as? Double) ?? 0)
                )
            }
        case .keep: break
        }

        return SVGAShape(type: type, style: style, transform: transform,
                         pathData: pathData, rectArgs: rectArgs, ellipseArgs: ellipseArgs)
    }

    private nonisolated func lineCap(from str: String?) -> CGLineCap {
        switch str?.lowercased() {
        case "round":  return .round
        case "square": return .square
        default:       return .butt
        }
    }

    private nonisolated func lineJoin(from str: String?) -> CGLineJoin {
        switch str?.lowercased() {
        case "round": return .round
        case "bevel": return .bevel
        default:      return .miter
        }
    }
}
