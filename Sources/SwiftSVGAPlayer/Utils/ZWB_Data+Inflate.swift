// Sources/SwiftSVGAPlayer/Utils/Data+Inflate.swift
// 使用系统 Compression 框架实现 zlib inflate（deflate 解压）

import Foundation
import Compression

extension Data {
    /// 尝试用 zlib raw inflate 解压数据（对应 deflate 压缩）
    func zlibInflated() throws -> Data {
        // zlib 数据通常有 2 字节头（CMF + FLG），跳过后再 inflate
        guard count > 2 else { throw SVGAError.invalidData }

        // 跳过 zlib 头部 2 字节
        let payload = self.dropFirst(2)

        return try payload.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) throws -> Data in
            guard let src = srcPtr.baseAddress else { throw SVGAError.invalidData }
            let srcSize = payload.count
            // 预分配输出缓冲区，初始为输入的 4 倍，不够则扩展
            var dstSize = max(srcSize * 4, 4096)
            var dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dst.deallocate() }

            var written = compression_decode_buffer(dst, dstSize,
                                                    src.assumingMemoryBound(to: UInt8.self),
                                                    srcSize, nil, COMPRESSION_ZLIB)
            // 如果输出缓冲区不够，扩大后重试（最多 3 次）
            var retries = 0
            while written == dstSize && retries < 3 {
                dstSize *= 4
                dst.deallocate()
                dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
                written = compression_decode_buffer(dst, dstSize,
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
        // zlib 头：(CMF * 256 + FLG) % 31 == 0，且 CM == 8
        return (cmf & 0x0F) == 8 && (Int(cmf) * 256 + Int(flg)) % 31 == 0
    }
}
