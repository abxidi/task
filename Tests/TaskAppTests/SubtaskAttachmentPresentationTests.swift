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

    func testPreviewUsesLargeCenteredOverlayThatDismissesFromBackdrop() {
        XCTAssertEqual(SubtaskImagePreviewLayout.maximumDimension, 760)
        XCTAssertEqual(SubtaskImagePreviewLayout.minimumDimension, 240)
        XCTAssertTrue(SubtaskImagePreviewLayout.preservesImageAspectRatio)
        XCTAssertTrue(SubtaskImagePreviewLayout.isCenteredInApplication)
        XCTAssertTrue(SubtaskImagePreviewLayout.dismissesOnOutsideTap)
    }

    func testAttachmentInputSupportsPasteDropAndFileSelection() {
        XCTAssertTrue(SubtaskAttachmentInput.supportsPaste)
        XCTAssertTrue(SubtaskAttachmentInput.supportsDrop)
        XCTAssertTrue(SubtaskAttachmentInput.supportsFileSelection)
        XCTAssertEqual(SubtaskAttachmentInput.primaryInputMethod, "paste")
    }

    func testAttachmentInputRequiresATaskTitle() {
        XCTAssertFalse(SubtaskAttachmentInput.isAvailable(forTaskTitle: "  \n"))
        XCTAssertTrue(SubtaskAttachmentInput.isAvailable(forTaskTitle: "整理发布渠道"))
    }
}
