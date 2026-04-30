// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Public/ZWB_SVGADynamicItem.swift

import UIKit

typealias SVGADrawingBlock = (_ context: CGContext, _ frame: CGRect, _ frameIndex: Int) -> Void

enum SVGADynamicItem {
    case image(UIImage)
    case imageURL(URL)
    case text(NSAttributedString)
    case hidden
    case drawing(SVGADrawingBlock)
}

typealias SVGADynamicItems = [String: SVGADynamicItem]
