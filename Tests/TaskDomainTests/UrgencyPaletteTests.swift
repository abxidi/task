import XCTest
@testable import TaskDomain

final class UrgencyPaletteTests: XCTestCase {
    func testEveryApprovedUrgencyHasUniqueColor() throws {
        let colors = try (-3...3).map { try UrgencyPalette.style(for: $0).hex }
        XCTAssertEqual(Set(colors).count, 7)
    }

    func testApprovedHexValuesAndTextPolarity() throws {
        XCTAssertEqual(try UrgencyPalette.style(for: -3), .init(hex: 0x354F9E, usesDarkText: false))
        XCTAssertEqual(try UrgencyPalette.style(for: -1), .init(hex: 0x68BEB0, usesDarkText: true))
        XCTAssertEqual(try UrgencyPalette.style(for: 0), .init(hex: 0x737970, usesDarkText: false))
        XCTAssertEqual(try UrgencyPalette.style(for: 2), .init(hex: 0xE38A39, usesDarkText: true))
        XCTAssertEqual(try UrgencyPalette.style(for: 3), .init(hex: 0xD73D43, usesDarkText: false))
    }

    func testRejectsObsoleteFivePointRange() {
        XCTAssertThrowsError(try UrgencyPalette.style(for: 5))
        XCTAssertThrowsError(try UrgencyPalette.style(for: -5))
    }
}
