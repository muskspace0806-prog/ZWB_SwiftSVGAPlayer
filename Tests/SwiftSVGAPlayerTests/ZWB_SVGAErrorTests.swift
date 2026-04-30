// Tests/SwiftSVGAPlayerTests/ZWB_SVGAErrorTests.swift

import XCTest
@testable import SwiftSVGAPlayer

final class SVGAErrorTests: XCTestCase {

    func test_equatable_sameCase() {
        XCTAssertEqual(SVGAError.invalidSource, SVGAError.invalidSource)
        XCTAssertEqual(SVGAError.fileNotFound, SVGAError.fileNotFound)
        XCTAssertEqual(SVGAError.invalidData, SVGAError.invalidData)
        XCTAssertEqual(SVGAError.missingMovieFile, SVGAError.missingMovieFile)
        XCTAssertEqual(SVGAError.cancelled, SVGAError.cancelled)
    }

    func test_equatable_associatedValues() {
        XCTAssertEqual(SVGAError.downloadFailed("err"), SVGAError.downloadFailed("err"))
        XCTAssertNotEqual(SVGAError.downloadFailed("a"), SVGAError.downloadFailed("b"))
    }

    func test_equatable_differentCases() {
        XCTAssertNotEqual(SVGAError.invalidSource, SVGAError.fileNotFound)
        XCTAssertNotEqual(SVGAError.cancelled, SVGAError.invalidData)
    }

    func test_description_notEmpty() {
        let errors: [SVGAError] = [
            .invalidSource, .fileNotFound, .downloadFailed("test"),
            .invalidData, .unzipFailed("test"), .missingMovieFile,
            .protobufDecodeFailed("test"), .jsonDecodeFailed("test"),
            .imageDecodeFailed("test"), .unsupportedFeature("test"),
            .cancelled, .internalError("test")
        ]
        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Description should not be empty for \(error)")
            XCTAssertTrue(error.description.contains("SVGAError"))
        }
    }

    func test_isError() {
        let error: Error = SVGAError.cancelled
        XCTAssertTrue(error is SVGAError)
    }
}
