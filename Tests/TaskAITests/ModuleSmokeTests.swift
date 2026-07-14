import XCTest
@testable import TaskAI

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskAIModule.self)
    }
}
