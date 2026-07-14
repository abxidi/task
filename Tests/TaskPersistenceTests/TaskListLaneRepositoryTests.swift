import SwiftData
import XCTest
@testable import TaskPersistence

@MainActor
final class TaskListLaneRepositoryTests: XCTestCase {
    func testCreatesFourReusableLocalTaskLanes() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskListLaneRepository(context: container.mainContext)

        let lanes = try repository.defaultLanes()

        XCTAssertEqual(lanes.map(\.name), ["待规划", "本周计划", "进行中", "已完成"])
        XCTAssertEqual(lanes.filter(\.isCompletionColumn).count, 1)
        XCTAssertTrue(lanes.allSatisfy { $0.project == nil })
        XCTAssertEqual(try repository.defaultLanes().map(\.id), lanes.map(\.id))
    }

    func testMovingTaskAcrossLocalLanesUpdatesCompletion() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = TaskListLaneRepository(context: container.mainContext)
        let lanes = try repository.defaultLanes()
        let item = TaskItem(title: "卡片任务")
        container.mainContext.insert(item)

        let workflow = BoardWorkflowService(context: container.mainContext)
        try workflow.move(item, to: lanes[3], now: Date(timeIntervalSince1970: 100))
        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.boardColumn?.id, lanes[3].id)

        try workflow.move(item, to: lanes[1], now: Date(timeIntervalSince1970: 200))
        XCTAssertFalse(item.isCompleted)
        XCTAssertEqual(item.boardColumn?.id, lanes[1].id)
    }
}
