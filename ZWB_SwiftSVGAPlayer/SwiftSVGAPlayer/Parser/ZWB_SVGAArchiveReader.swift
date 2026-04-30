// ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/Parser/ZWB_SVGAArchiveReader.swift
// 纯 Swift ZIP 解析（支持 Store 和 Deflate）

import Foundation
import Compression

protocol SVGAArchiveReading: AnyObject {
    func readEntries(from data: Data) throws -> [String: Data]
}

final class SVGAArchiveReader: SVGAArchiveReading {

    nonisolated func readEntries(from data: Data) throws -> [String: Data] {
        guard let eocd = findEOCD(in: data) else {
            throw SVGAError.unzipFailed("Cannot find EOCD signature")
        }
        guard Int(eocd.centralDirOffset) + Int(eocd.centralDirSize) <= data.count else {
            throw SVGAError.unzipFailed("Central directory out of bounds")
        }

        var entries: [String: Data] = [:]
        var cdOffset = Int(eocd.centralDirOffset)

        for _ in 0..<eocd.entryCount {
            guard let entry = parseCentralDirectoryEntry(data: data, offset: &cdOffset) else { break }
            guard let fileData = extractLocalFile(data: data, entry: entry) else {
                svgaLogWarning("Failed to extract entry: \(entry.fileName)"); continue
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

    private nonisolated func findEOCD(in data: Data) -> EOCD? {
        let bytes = [UInt8](data)
        let searchStart = Swift.max(0, bytes.count - 65535 - 22)
        for i in stride(from: bytes.count - 22, through: searchStart, by: -1) {
            guard i + 3 < bytes.count else { continue }
            if bytes[i] == 0x50 && bytes[i+1] == 0x4b && bytes[i+2] == 0x05 && bytes[i+3] == 0x06 {
                return EOCD(
                    entryCount:       readUInt16(bytes, offset: i + 10),
                    centralDirSize:   readUInt32(bytes, offset: i + 12),
                    centralDirOffset: readUInt32(bytes, offset: i + 16)
                )
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

    private nonisolated func parseCentralDirectoryEntry(data: Data, offset: inout Int) -> CDEntry? {
        let bytes = [UInt8](data)
        guard offset + 46 <= bytes.count else { return nil }
        guard bytes[offset] == 0x50 && bytes[offset+1] == 0x4b
           && bytes[offset+2] == 0x01 && bytes[offset+3] == 0x02 else { return nil }

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
            ?? String(data: fileNameData, encoding: .isoLatin1) ?? ""

        offset += 46 + fileNameLength + extraFieldLength + commentLength
        return CDEntry(fileName: fileName, compressionMethod: compressionMethod,
                       compressedSize: compressedSize, uncompressedSize: uncompressedSize,
                       localHeaderOffset: localHeaderOffset)
    }

    // MARK: - Local File

    private nonisolated func extractLocalFile(data: Data, entry: CDEntry) -> Data? {
        let bytes = [UInt8](data)
        var offset = Int(entry.localHeaderOffset)
        guard offset + 30 <= bytes.count else { return nil }
        guard bytes[offset] == 0x50 && bytes[offset+1] == 0x4b
           && bytes[offset+2] == 0x03 && bytes[offset+3] == 0x04 else { return nil }

        let fileNameLength   = Int(readUInt16(bytes, offset: offset + 26))
        let extraFieldLength = Int(readUInt16(bytes, offset: offset + 28))
        offset += 30 + fileNameLength + extraFieldLength

        let compressedSize = Int(entry.compressedSize)
        guard offset + compressedSize <= bytes.count else { return nil }
        let compressedData = Data(bytes[offset ..< offset + compressedSize])

        switch entry.compressionMethod {
        case 0: return compressedData
        case 8: return inflateDeflate(compressedData, expectedSize: Int(entry.uncompressedSize))
        default:
            svgaLogWarning("Unsupported ZIP compression method: \(entry.compressionMethod)")
            return nil
        }
    }

    private nonisolated func inflateDeflate(_ data: Data, expectedSize: Int) -> Data? {
        let dstSize = Swift.max(expectedSize, data.count * 4, 4096)
        return data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let src = srcPtr.baseAddress else { return nil }
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
            defer { dst.deallocate() }
            let written = compression_decode_buffer(
                dst, dstSize,
                src.assumingMemoryBound(to: UInt8.self), data.count,
                nil, COMPRESSION_ZLIB)
            guard written > 0 else { return nil }
            return Data(bytes: dst, count: written)
        }
    }

    // MARK: - Helpers

    private nonisolated func readUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private nonisolated func readUInt32(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset+1]) << 8)
            | (UInt32(bytes[offset+2]) << 16) | (UInt32(bytes[offset+3]) << 24)
    }
}
