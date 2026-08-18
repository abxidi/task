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
    @State private var subtaskCount: Int
    @State private var noteHeight: CGFloat
    @State private var preview: SubtaskImagePreview?

    init(mode: TaskEditorMode, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose
        _subtaskCount = State(initialValue: mode.initialSubtaskCount)
        _noteHeight = State(initialValue: TaskEditorNoteLayout.minimumHeight)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelSize = TaskEditorOverlayLayout.panelSize(
                for: proxy.size,
                subtaskCount: subtaskCount,
                noteHeight: noteHeight
            )

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
                    outsideDismissToken: outsideDismissToken,
                    onSubtaskCountChange: { subtaskCount = $0 },
                    onNoteHeightChange: { height in
                        guard noteHeight != height else { return }
                        noteHeight = height
                    },
                    onPreview: { preview = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: panelSize.width, height: panelSize.height)

                if let preview {
                    SubtaskImagePreviewOverlay(preview: preview) {
                        self.preview = nil
                    }
                    .zIndex(1)
                }
            }
        }
        .onExitCommand {
            if preview != nil {
                preview = nil
            } else {
                outsideDismissToken = UUID()
            }
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}

enum TaskEditorOverlayLayout {
    static let preferredWidth: CGFloat = 1040
    static let minimumWidth: CGFloat = 820
    static let initialHeight: CGFloat = 360
    static let subtaskHeightIncrement: CGFloat = 41
    static let maximumHeightRatio: CGFloat = 0.88
    static let edgeInset: CGFloat = 28
    static let supportsEscapeToClose = true

    static func panelSize(
        for availableSize: CGSize,
        subtaskCount: Int,
        noteHeight: CGFloat = TaskEditorNoteLayout.minimumHeight
    ) -> CGSize {
        let noteHeightDelta = max(0, noteHeight - TaskEditorNoteLayout.minimumHeight)
        let desiredHeight = initialHeight
            + noteHeightDelta
            + CGFloat(max(0, subtaskCount)) * subtaskHeightIncrement
        return CGSize(
            width: min(preferredWidth, max(minimumWidth, availableSize.width - edgeInset * 2)),
            height: min(desiredHeight, availableSize.height * maximumHeightRatio)
        )
    }
}

private extension TaskEditorMode {
    var initialSubtaskCount: Int {
        switch self {
        case .create, .createInColumn:
            0
        case .edit(let item):
            item.subtasks.count
        }
    }
}
