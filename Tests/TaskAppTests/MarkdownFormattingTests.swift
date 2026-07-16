import Foundation
import XCTest
@testable import TaskApp

final class MarkdownFormattingTests: XCTestCase {
    func testBoldWrapsTheSelection() {
        let result = MarkdownFormatting.apply(
            .bold,
            to: "word",
            selection: NSRange(location: 0, length: 4)
        )

        XCTAssertEqual(result.text, "**word**")
        XCTAssertEqual(result.selection, NSRange(location: 2, length: 4))
    }

    func testHeadingPrefixesEachSelectedLine() {
        let result = MarkdownFormatting.apply(
            .heading,
            to: "one\ntwo",
            selection: NSRange(location: 0, length: 7)
        )

        XCTAssertEqual(result.text, "# one\n# two")
        XCTAssertEqual(result.selection, NSRange(location: 0, length: 11))
    }
}
