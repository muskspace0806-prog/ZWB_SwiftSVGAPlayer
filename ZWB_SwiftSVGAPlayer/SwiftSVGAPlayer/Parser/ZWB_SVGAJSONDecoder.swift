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
        return SVGAFrame(alpha: alpha, layout: layout, transform: transform,
                         clipPath: nil, shapes: [])
    }
}
