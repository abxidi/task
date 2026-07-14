import CoreGraphics
import XCTest
@testable import TaskApp

final class PriorityMapLayoutTests: XCTestCase {
    func testMapSideUsesRemainingHeightAndCapsLargeCanvases() {
        XCTAssertEqual(PriorityMapScreenLayout.mapSide(for: CGSize(width: 900, height: 380)), 380)
        XCTAssertEqual(PriorityMapScreenLayout.mapSide(for: CGSize(width: 900, height: 900)), 620)
    }

    func testCoordinateSquareLeavesRoomForOutsideQuadrantLabels() {
        let square = PriorityMapLayout.coordinateSquare(in: CGSize(width: 500, height: 500))

        XCTAssertEqual(square.width, square.height)
        XCTAssertGreaterThanOrEqual(square.minY, PriorityMapLayout.zoneLabelBand)
        XCTAssertLessThanOrEqual(square.maxY, 500 - PriorityMapLayout.zoneLabelBand)
    }
}
