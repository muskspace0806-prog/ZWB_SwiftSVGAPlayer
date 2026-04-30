// Sources/SwiftSVGAPlayer/Parser/ZWB_SVGAArchiveReader.swift
// 纯 Swift 实现的 ZIP 解析（支持 Store 和 Deflate 压缩方式）

import Foundation
import Compression

/// ZIP 解压协议
protocol SVGAArchiveReading {
    func readEntries(from data: Data) throws -> [String: Data]
}

/// 纯 Swift ZIP 解析器（不依赖任何 OC 库）
final class SVGAArchiveReader: SVGAArchiveReading {

    func readEntries(from data: Data) throws -> [String: Data] {
        // 先找 End of Central Directory (EOCD)
        guard let eocd = findEOCD(in: data) else {
            throw SVGAError.unzipFailed("Cannot find EOCD signature")
        }

        let centralDirOffset = eocd.centralDirOffset
        let centralDirSize   = eocd.centralDirSize
        let entryCount       = eocd.entryCount

        guard Int(centralDirOffset) + Int(centralDirSize) <= data.count else {
            throw SVGAError.unzipFailed("Central directory out of bounds")
        }

        var entries: [String: Data] = [:]
        var cdOffset = Int(centralDirOffset)

        for _ in 0..<entryCount {
            guard let entry = parseCentralDirectoryEntry(data: data, offset: &cdOffset) else {
                break
            }
            guard let fileData = extractLocalFile(data: data, entry: entry) else {
                svgaLogWarning("Failed to extract entry: \(entry.fileName)")
                continue
            }
            entries[entry.fileName] = fileData
            svgaLogVerbose("Extracted ZIP entry: \(entry.fileName) (\(fileData.count) bytes)")
        }

        return entries
    }

    // MARK: - EOCD

    private struct EOCD {
        let entryCount: UInt16
        let centralDirSize: UInt32
        let centralDirOffset: UInt32
    }

    private func findEOCD(in data: Data) -> EOCD? {
        // EOCD signature: 0x06054b50
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let bytes = [UInt8](data)
        // 从末尾向前搜索（最多搜索 65535 + 22 字节）
        let searchStart = max(0, bytes.count - 65535 - 22)
        for i in stride(from: bytes.count - 22, through: searchStart, by: -1) {
            if bytes[i] == signature[0] && bytes[i+1] == signature[1]
                && bytes[i+2] == signature[2] && bytes[i+3] == signature[3] {
                let entryCount      = readUInt16(bytes, offset: i + 10)
                let centralDirSize  = readUInt32(bytes, offset: i + 12)
                let centralDirOffset = readUInt32(bytes, offset: i + 16)
                return EOCD(entryCount: entryCount,
                            centralDirSize: centralDirSize,
                            centralDirOffset: centralDirOffset)
            }
        }
        return nil
    }

    // MARK: - Central Directory Entry

    private struct CDEntry {
        let fileName: String
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    private func parseCentralDirectoryEntry(data: Data, offset: inout Int) -> CDEntry? {
        let bytes = [UInt8](data)
        guard offset + 46 <= bytes.count else { return nil }
        // Central directory signature: 0x02014b50
        guard bytes[offset] == 0x50 && bytes[offset+1] == 0x4b
            && bytes[offset+2] == 0x01 && bytes[offset+3] == 0x02 else {
            return nil
        }
        let compressionMethod  = readUInt16(bytes, offset: offset + 10)
        let compressedSize     = readUInt32(bytes, offset: offset + 20)
        let uncompressedSize   = readUInt32(bytes, offset: offset + 24)
        let fileNameLength     = Int(readUInt16(bytes, offset: offset + 28))
        let extraFieldLength   = Int(readUInt16(bytes, offset: offset + 30))
        let commentLength      = Int(readUInt16(bytes, offset: offset + 32))
        let localHeaderOffset  = readUInt32(bytes, offset: offset + 42)

        guard offset + 46 + fileNameLength <= bytes.count else { return nil }
        let fileNameData = Data(bytes[offset + 46 ..< offset + 46 + fileNameLength])
        let fileName = String(data: fileNameData, encoding: .utf8)
            ?? String(data: fileNameData, encoding: .isoLatin1)
            ?? ""

        offset += 46 + fileNameLength + extraFieldLength + commentLength

        return CDEntry(
            fileName: fileName,
            compressionMethod: compressionMethod,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            localHeaderOffset: localHeaderOffset
        )
    }

    // MARK: - Local File

    private func extractLocalFile(data: Data, entry: CDEntry) -> Data? {
        let bytes = [UInt8](data)
        var offset = Int(entry.localHeaderOffset)
        guard offset + 30 <= bytes.count else { return nil }
        // Local file header signature: 0x04034b50
        guard bytes[offset] == 0x50 && bytes[offset+1] == 0x4b
            && bytes[offset+2] == 0x03 && bytes[offset+3] == 0x04 else {
            return nil
        }
        let fileNameLength   = Int(readUInt16(bytes, offset: offset + 26))
        let extraFieldLength = Int(readUInt16(bytes, offset: offset + 28))
        offset += 30 + fileNameLength + extraFieldLength

        let compressedSize = Int(entry.compressedSize)
        guard offset + compressedSize <= bytes.count else { return nil }

        let compressedData = Data(bytes[offset ..< offset + compressedSize])

        switch entry.compressionMethod {
        case 0: // Store（无压缩）
            return compressedData
        case 8: // Deflate
            return inflateDeflate(compressedData, expectedSize: Int(entry.uncompressedSize))
        default:
            svgaLogWarning("Unsupported ZIP compression method: \(entry.compressionMethod)")
            return nil
        }
    }

    // MARK: - Deflate inflate（raw，无 zlib 头）

    private func inflateDeflate(_ data: Data, expectedSize: Int) -> Data? {
        let dstSize = max(expectedSize, data.count * 4, 4096)
        return data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let src = srcPtr.baseAddress else { return nil }
            var dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dst.deallocate() }
            let written = compression_decode_buffer(
                dst, dstSize,
                src.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
            guard written > 0 else { return nil }
            return Data(bytes: dst, count: written)
        }
    }

    // MARK: - Helpers

    private func readUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private func readUInt32(_ bytes: [UInt8], offset: Int) -> UInt32 {
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}
