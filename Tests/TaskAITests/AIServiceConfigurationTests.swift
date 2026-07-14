import XCTest
@testable import TaskAI

final class AIServiceConfigurationTests: XCTestCase {
    func testAcceptsHTTPSAndLoopbackHTTP() throws {
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: "model-a"))
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "http://127.0.0.1:11434/v1")!, model: "local"))
        XCTAssertNoThrow(try AIServiceConfiguration(baseURL: URL(string: "http://localhost:11434/v1")!, model: "local"))
    }

    func testRejectsRemotePlainHTTPAndEmptyModel() {
        XCTAssertThrowsError(try AIServiceConfiguration(baseURL: URL(string: "http://api.example.com/v1")!, model: "model"))
        XCTAssertThrowsError(try AIServiceConfiguration(baseURL: URL(string: "https://api.example.com/v1")!, model: " "))
    }
}
