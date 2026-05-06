// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Utils/ZWB_Data+Inflate.swift

import Foundation
import Compression

extension Data {
    /// 用 zlib inflate 解压（跳过 2 字节 zlib 头）
    nonisolated func zlibInflated() throws -> Data {
        guard count > 2 else { throw SVGAError.invalidData }
        let payload = self.dropFirst(2)

        return try payload.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) throws -> Data in
            guard let src = srcPtr.baseAddress else { throw SVGAError.invalidData }
            let srcSize = payload.count
            var dstSize = Swift.max(srcSize * 4, 4096)
            var dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dst.deallocate() }

            var written = compression_decode_buffer(
                dst, dstSize,
                src.assumingMemoryBound(to: UInt8.self),
                srcSize, nil, COMPRESSION_ZLIB)

            var retries = 0
            while written == dstSize && retries < 3 {
                dstSize *= 4
                dst.deallocate()
                dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
                written = compression_decode_buffer(
                    dst, dstSize,
                    src.assumingMemoryBound(to: UInt8.self),
                    srcSize, nil, COMPRESSION_ZLIB)
                retries += 1
            }

            guard written > 0 else { throw SVGAError.unzipFailed("zlib inflate returned 0 bytes") }
            return Data(bytes: dst, count: written)
        }
    }

    /// 判断是否是 zlib 压缩数据（CMF + FLG 头）
    var isZlibCompressed: Bool {
        guard count >= 2 else { return false }
        let cmf = self[startIndex]
        let flg = self[index(after: startIndex)]
        return (cmf & 0x0F) == 8 && (Int(cmf) * 256 + Int(flg)) % 31 == 0
    }
}
