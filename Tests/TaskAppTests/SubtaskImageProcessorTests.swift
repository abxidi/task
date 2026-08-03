import AppKit
import XCTest
@testable import TaskApp

final class SubtaskImageProcessorTests: XCTestCase {
    func testProcessingDownscalesSourceAndCreatesThumbnail() throws {
        let source = NSImage(size: NSSize(width: 1_800, height: 1_200))
        source.lockFocus()
        NSColor.systemOrange.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: source.size)).fill()
        source.unlockFocus()

        let attachment = try SubtaskImageProcessor.process(source)
        let image = try XCTUnwrap(NSImage(data: attachment.imageData))
        let thumbnail = try XCTUnwrap(NSImage(data: attachment.thumbnailData))

        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), SubtaskImageProcessingLimits.maximumImageDimension)
        XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), SubtaskImageProcessingLimits.thumbnailDimension)
        XCTAssertFalse(attachment.imageData.isEmpty)
        XCTAssertFalse(attachment.thumbnailData.isEmpty)
    }
}
