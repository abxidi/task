import SwiftData
import SwiftUI
import TaskPersistence

@main
struct TaskApplication: App {
    private let container = try! ModelContainerFactory.make()
    private let statusBarController = StatusBarController(TaskWindowActivator.showMainWindow)
    @StateObject private var globalShortcutManager = GlobalShortcutManager()

    var body: some Scene {
        WindowGroup("Task", id: "main") {
            MainWindowContent(
                container: container,
                globalShortcutManager: globalShortcutManager
            )
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

@MainActor
private struct MainWindowContent: View {
    let container: ModelContainer
    @ObservedObject var globalShortcutManager: GlobalShortcutManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TaskAppShell()
            .modelContainer(container)
            .environmentObject(globalShortcutManager)
            .taskSubtleScrollIndicators()
            .onAppear {
                TaskWindowActivator.configureMainWindowOpening {
                    openWindow(id: "main")
                }
                globalShortcutManager.start()
            }
    }
}
