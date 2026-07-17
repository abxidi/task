import SwiftUI

struct SubtaskEditor: View {
    @Binding var items: [String]
    @Binding var completion: [Bool]
    let onToggle: (Int) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onAdd: (String) -> Void
    @State private var newTitle = ""
    @FocusState private var isNewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 8) {
                        Button {
                            onToggle(index)
                        } label: {
                            Image(systemName: completion[index] ? "checkmark.square.fill" : "square")
                                .font(.system(size: 13))
                                .foregroundStyle(completion[index] ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: TaskEditorSubtaskEntryStyle.iconFrameSize,
                            height: TaskEditorSubtaskEntryStyle.iconFrameSize
                        )
                        .accessibilityLabel(completion[index] ? "标记为未完成" : "标记为已完成")

                        TextField("子任务", text: binding(for: index))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: 0x50544C))
                            .strikethrough(completion[index])
                    }
                    .frame(minHeight: TaskEditorSubtaskEntryStyle.minimumHeight)
                    .listRowInsets(sharedRowInsets)
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: onMove)

                compactInputRow
                    .listRowInsets(sharedRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(items.count) * 41 + TaskEditorSubtaskEntryStyle.minimumHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color(hex: 0xD2D3CB))
            )
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }

    private var sharedRowInsets: EdgeInsets {
        .init(top: 0, leading: TaskEditorSubtaskEntryStyle.listRowLeadingInset, bottom: 0, trailing: 10)
    }

    private var compactInputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: TaskEditorSubtaskEntryStyle.iconSize, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(
                    width: TaskEditorSubtaskEntryStyle.iconFrameSize,
                    height: TaskEditorSubtaskEntryStyle.iconFrameSize
                )
            ZStack(alignment: .leading) {
                if TaskEditorPlaceholder.isVisible(text: newTitle, isFocused: isNewFocused) {
                    Text("添加一个子任务")
                        .font(.system(size: 12))
                        .foregroundStyle(TaskDesignTokens.quiet.opacity(TaskEditorPlaceholder.opacity))
                        .allowsHitTesting(false)
                }
                TextField("", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isNewFocused)
                    .onSubmit(addNew)
                    .accessibilityLabel("添加子任务")
            }
        }
        .frame(minHeight: TaskEditorSubtaskEntryStyle.minimumHeight)
    }

    private func addNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isNewFocused = false
            return
        }
        onAdd(trimmed)
        newTitle = ""
        isNewFocused = true
    }

}

enum TaskEditorSubtaskEntryStyle {
    static let usesSharedListRows = true
    static let startsAsInput = true
    static let iconSize: CGFloat = 12
    static let iconFrameSize: CGFloat = 18
    static let minimumHeight: CGFloat = 40
    static let listRowLeadingInset: CGFloat = 10
}
