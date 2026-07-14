import SwiftUI

struct TaskEditorOverlay: View {
    let mode: TaskEditorMode
    let onClose: () -> Void
    @State private var outsideDismissToken: UUID?

    var body: some View {
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
            .padding(28)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}
