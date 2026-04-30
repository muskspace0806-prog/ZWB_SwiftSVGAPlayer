// Sources/SwiftSVGAPlayer/Utils/UIImage+Decode.swift

import UIKit
import ImageIO

extension UIImage {
    /// 从 Data 解码图片，强制解码到位图（避免主线程解码卡顿）
    static func svga_decode(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        // 强制解码：绘制到 bitmap context
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            return UIImage(cgImage: cgImage)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let decoded = context.makeImage() else {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(cgImage: decoded)
    }
}
