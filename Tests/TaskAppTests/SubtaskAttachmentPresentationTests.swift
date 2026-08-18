import XCTest
@testable import TaskApp

final class SubtaskAttachmentPresentationTests: XCTestCase {
    func testSubtaskRowsUseCompactAttachmentCountAndPopoverGrid() {
        XCTAssertTrue(SubtaskAttachmentLayout.usesCompactCountButton)
        XCTAssertTrue(SubtaskAttachmentLayout.usesAttachmentPopover)
        XCTAssertFalse(SubtaskAttachmentLayout.usesInlineThumbnailStrip)
        XCTAssertEqual(SubtaskAttachmentLayout.gridColumnCount, 3)
        XCTAssertEqual(SubtaskAttachmentLayout.maximumVisibleRows, 2)
    }

    func testPopoverShowsSixAttachmentsBeforeInternalScrolling() {
        XCTAssertEqual(SubtaskAttachmentLayout.visibleCapacity, 6)
        XCTAssertEqual(SubtaskAttachmentLayout.visibleCount(for: 4), 4)
        XCTAssertEqual(SubtaskAttachmentLayout.visibleCount(for: 10), 6)
        XCTAssertTrue(SubtaskAttachmentLayout.requiresInternalScrolling(for: 7))
        XCTAssertFalse(SubtaskAttachmentLayout.requiresInternalScrolling(for: 6))
    }

    func testPreviewKeepsImageProportionWithinApprovedBounds() {
        XCTAssertEqual(SubtaskAttachmentLayout.previewMaximumDimension, 320)
        XCTAssertEqual(SubtaskAttachmentLayout.previewMinimumDimension, 120)
        XCTAssertTrue(SubtaskAttachmentLayout.preservesImageAspectRatio)
    }

    func testAttachmentInputSupportsPasteDropAndFileSelection() {
        XCTAssertTrue(SubtaskAttachmentInput.supportsPaste)
        XCTAssertTrue(SubtaskAttachmentInput.supportsDrop)
        XCTAssertTrue(SubtaskAttachmentInput.supportsFileSelection)
        XCTAssertEqual(SubtaskAttachmentInput.primaryInputMethod, "paste")
    }
}
