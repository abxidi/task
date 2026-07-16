import XCTest
@testable import TaskApp

final class MarkdownEditorPresentationTests: XCTestCase {
    func testMarkdownEditorUsesExplicitSaveAndTwoPanes() {
        XCTAssertTrue(MarkdownEditorLayout.usesExplicitSave)
        XCTAssertEqual(MarkdownEditorLayout.paneCount, 2)
    }
}
