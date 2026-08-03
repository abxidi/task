import SwiftUI
import TaskAI

struct TaskAppShell: View {
    @State private var selection: AppRoute? = .priorityMap
    @State private var listScope: TaskListScope?
    @StateObject private var taskEditorCoordinator = TaskEditorPresentationCoordinator()
    @AppStorage("aiConfigurationJSON") private var configurationJSON = ""
    private let keyStore = KeychainAPIKeyStore()

    private var isAIConfigured: Bool {
        AIAvailability.isConfigured(
            configurationData: configurationJSON.data(using: .utf8),
            keyStore: keyStore
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(
                selection: $selection,
                listScope: $listScope,
                isAIConfigured: isAIConfigured
            )
            .frame(width: TaskDesignTokens.sidebarWidth)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(TaskDesignTokens.line)
                    .frame(width: 1)
            }

            Group {
                switch selection ?? .priorityMap {
                case .priorityMap:
                    PriorityMapScreen(isAIConfigured: isAIConfigured) {
                        taskEditorCoordinator.present(.create)
                    }
                case .taskList:
                    TaskListScreen(initialScope: listScope) {
                        taskEditorCoordinator.present(.create)
                    }
                case .focusPool:
                    FocusPoolScreen()
                case .projectBoard:
                    ProjectBoardScreen(isAIConfigured: isAIConfigured) {
                        taskEditorCoordinator.present(.create)
                    }
                case .insights:
                    InsightsScreen()
                case .settings:
                    SettingsScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TaskDesignTokens.canvas)
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(TaskDesignTokens.canvas)
        .environmentObject(taskEditorCoordinator)
        .overlay {
            if let mode = taskEditorCoordinator.mode {
                TaskEditorOverlay(mode: mode) {
                    taskEditorCoordinator.dismiss()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCreateRequested)) { _ in
            taskEditorCoordinator.present(.create)
        }
    }
}

extension Notification.Name {
    static let taskCreateRequested = Notification.Name("taskCreateRequested")
}
