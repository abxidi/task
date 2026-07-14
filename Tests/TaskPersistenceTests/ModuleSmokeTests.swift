import XCTest
@testable import TaskPersistence

final class ModuleSmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(TaskPersistenceModule.self)
    }
}
