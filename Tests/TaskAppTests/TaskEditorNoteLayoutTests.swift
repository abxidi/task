import AppKit
import XCTest
@testable import TaskApp

final class TaskEditorNoteLayoutTests: XCTestCase {
    func testOneLineAndEmptyNoteUseCompactHeight() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 0), 32)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 1), 32)
    }

    func testNoteHeightGrowsByLineHeightThroughFiveLines() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 2), 52)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 5), 112)
    }

    func testNoteHeightCapsAtFiveVisibleLines() {
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 6), 112)
        XCTAssertEqual(TaskEditorNoteLayout.height(forLineCount: 20), 112)
        XCTAssertTrue(TaskEditorNoteLayout.requiresInternalScrolling(forLineCount: 6))
    }

    func testActualLineCounterCountsExplicitLineBreaks() {
        XCTAssertEqual(TaskEditorNoteLineCounter.count(in: "一行\n二行\n三行", width: 460), 3)
    }

    func testActualLineCounterCountsSoftWraps() {
        let text = String(repeating: "任", count: 20)
        XCTAssertGreaterThan(TaskEditorNoteLineCounter.count(in: text, width: 40), 1)
    }
}
