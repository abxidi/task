import SwiftUI

@MainActor
final class TaskEditorPresentationCoordinator: ObservableObject {
    @Published private(set) var mode: TaskEditorMode?

    func present(_ mode: TaskEditorMode) {
        self.mode = mode
    }

    func dismiss() {
        mode = nil
    }
}

struct TaskEditorOverlay: View {
    let mode: TaskEditorMode
    let onClose: () -> Void
    @State private var outsideDismissToken: UUID?

    var body: some View {
        GeometryReader { proxy in
            let panelSize = TaskEditorOverlayLayout.panelSize(for: proxy.size)

            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        outsideDismissToken = UUID()
                    }

                TaskEditorSheet(
                    mode: mode,
                    onClose: onClose,
                    outsideDismissToken: outsideDismissToken
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: panelSize.width, height: panelSize.height)
            }
        }
        .onExitCommand {
            outsideDismissToken = UUID()
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}

enum TaskEditorOverlayLayout {
    static let preferredSize = CGSize(width: 1040, height: 720)
    static let minimumSize = CGSize(width: 820, height: 620)
    static let edgeInset: CGFloat = 28
    static let supportsEscapeToClose = true

    static func panelSize(for availableSize: CGSize) -> CGSize {
        CGSize(
            width: min(preferredSize.width, max(minimumSize.width, availableSize.width - edgeInset * 2)),
            height: min(preferredSize.height, max(minimumSize.height, availableSize.height - edgeInset * 2))
        )
    }
}
