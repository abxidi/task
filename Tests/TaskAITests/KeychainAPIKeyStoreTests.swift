import XCTest
@testable import TaskAI

final class KeychainAPIKeyStoreTests: XCTestCase {
    func testRoundTripAndDelete() throws {
        let store = InMemoryAPIKeyStore()
        try store.save("secret")
        XCTAssertEqual(try store.read(), "secret")
        try store.delete()
        XCTAssertNil(try store.read())
    }
}
