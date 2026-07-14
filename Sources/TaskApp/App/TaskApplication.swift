import SwiftData
import SwiftUI
import TaskPersistence

@main
struct TaskApplication: App {
    private let container = try! ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup("Task") {
            TaskAppShell()
                .modelContainer(container)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建任务") {
                    NotificationCenter.default.post(name: .taskCreateRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
