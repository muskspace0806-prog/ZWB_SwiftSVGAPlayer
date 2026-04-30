// Tests/SwiftSVGAPlayerTests/ZWB_SVGAArchiveReaderTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGAArchiveReaderTests: XCTestCase {

    let reader = SVGAArchiveReader()

    // MARK: - Invalid Data

    func test_invalidData_throwsUnzipFailed() {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try reader.readEntries(from: data)) { error in
            guard case SVGAError.unzipFailed = error else {
                XCTFail("Expected unzipFailed, got \(error)")
                return
            }
        }
    }

    func test_emptyData_throwsUnzipFailed() {
        XCTAssertThrowsError(try reader.readEntries(from: Data())) { error in
            guard case SVGAError.unzipFailed = error else {
                XCTFail("Expected unzipFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Valid ZIP (minimal store)

    func test_validStoreZip_returnsEntries() throws {
        // 构造一个最小的 ZIP 文件（Store 方式，包含 "hello.txt"）
        let zipData = makeMinimalStoreZip(fileName: "hello.txt", content: Data("hello".utf8))
        let entries = try reader.readEntries(from: zipData)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertNotNil(entries["hello.txt"])
        XCTAssertEqual(entries["hello.txt"], Data("hello".utf8))
    }

    // MARK: - Helpers

    /// 构造最小 Store ZIP（无压缩）
    private func makeMinimalStoreZip(fileName: String, content: Data) -> Data {
        var zip = Data()
        let fileNameData = Data(fileName.utf8)
        let crc = crc32(content)
        let size = UInt32(content.count)
        let now = dosDateTime()

        // Local file header
        let localHeaderOffset = UInt32(zip.count)
        zip += bytes(UInt32(0x04034b50))  // signature
        zip += bytes(UInt16(20))           // version needed
        zip += bytes(UInt16(0))            // flags
        zip += bytes(UInt16(0))            // compression: store
        zip += bytes(UInt16(now.time))     // mod time
        zip += bytes(UInt16(now.date))     // mod date
        zip += bytes(crc)                  // crc32
        zip += bytes(size)                 // compressed size
        zip += bytes(size)                 // uncompressed size
        zip += bytes(UInt16(fileNameData.count)) // file name length
        zip += bytes(UInt16(0))            // extra field length
        zip += fileNameData
        zip += content

        // Central directory
        let cdOffset = UInt32(zip.count)
        zip += bytes(UInt32(0x02014b50))  // signature
        zip += bytes(UInt16(20))           // version made by
        zip += bytes(UInt16(20))           // version needed
        zip += bytes(UInt16(0))            // flags
        zip += bytes(UInt16(0))            // compression
        zip += bytes(UInt16(now.time))
        zip += bytes(UInt16(now.date))
        zip += bytes(crc)
        zip += bytes(size)
        zip += bytes(size)
        zip += bytes(UInt16(fileNameData.count))
        zip += bytes(UInt16(0))            // extra
        zip += bytes(UInt16(0))            // comment
        zip += bytes(UInt16(0))            // disk start
        zip += bytes(UInt16(0))            // internal attr
        zip += bytes(UInt32(0))            // external attr
        zip += bytes(localHeaderOffset)
        zip += fileNameData

        // EOCD
        let cdSize = UInt32(zip.count) - cdOffset
        zip += bytes(UInt32(0x06054b50))  // signature
        zip += bytes(UInt16(0))            // disk number
        zip += bytes(UInt16(0))            // disk with cd
        zip += bytes(UInt16(1))            // entries on disk
        zip += bytes(UInt16(1))            // total entries
        zip += bytes(cdSize)
        zip += bytes(cdOffset)
        zip += bytes(UInt16(0))            // comment length

        return zip
    }

    private func bytes<T: FixedWidthInteger>(_ value: T) -> Data {
        var v = value.littleEndian
        return Data(bytes: &v, count: MemoryLayout<T>.size)
    }

    private func crc32(_ data: Data) -> UInt32 {
        // 简化版 CRC32（测试用）
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    private func dosDateTime() -> (time: UInt16, date: UInt16) {
        return (time: 0, date: 0x4A21) // 2017-01-01
    }
}
