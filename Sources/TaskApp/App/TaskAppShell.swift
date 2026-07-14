import SwiftUI
import TaskAI

struct TaskAppShell: View {
    @State private var selection: AppRoute? = .priorityMap
    @State private var listScope: TaskListScope?
    @State private var isCreatingTask = false
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
                        isCreatingTask = true
                    }
                case .taskList:
                    TaskListScreen(initialScope: listScope) {
                        isCreatingTask = true
                    }
                case .projectBoard:
                    ProjectBoardScreen(isAIConfigured: isAIConfigured) {
                        isCreatingTask = true
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
        .sheet(isPresented: $isCreatingTask) {
            TaskEditorSheet(mode: .create)
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCreateRequested)) { _ in
            isCreatingTask = true
        }
    }
}

extension Notification.Name {
    static let taskCreateRequested = Notification.Name("taskCreateRequested")
}
