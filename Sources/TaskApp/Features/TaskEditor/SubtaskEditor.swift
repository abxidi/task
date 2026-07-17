import SwiftUI

struct SubtaskEditor: View {
    @Binding var items: [String]
    @Binding var completion: [Bool]
    let onToggle: (Int) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onAdd: (String) -> Void
    @State private var newTitle = ""
    @FocusState private var isNewFocused: Bool
    @State private var isAddingFirst = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                if !items.isEmpty {
                    List {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                            HStack(spacing: 9) {
                                Button {
                                    onToggle(index)
                                } label: {
                                    Image(systemName: completion[index] ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 13))
                                        .foregroundStyle(completion[index] ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(completion[index] ? "标记为未完成" : "标记为已完成")

                                TextField("子任务", text: binding(for: index))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: 0x50544C))
                                    .strikethrough(completion[index])
                            }
                            .frame(minHeight: 40)
                            .listRowInsets(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                            .listRowSeparator(.visible)
                            .listRowBackground(Color.clear)
                        }
                        .onMove(perform: onMove)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(items.count) * 41)
                }

                if items.isEmpty && !isAddingFirst {
                    Button {
                        isAddingFirst = true
                        isNewFocused = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 19, weight: .medium))
                            Text("添加一个子任务")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(TaskDesignTokens.quiet.opacity(TaskEditorPlaceholder.opacity))
                        .frame(maxWidth: .infinity, minHeight: TaskEditorLayout.emptySubtaskHeight, alignment: .leading)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加子任务")
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TaskDesignTokens.quiet)
                            .frame(width: 18, height: 18)
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
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 40)
                }
            }
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

    private func addNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isNewFocused = false
            isAddingFirst = false
            return
        }
        onAdd(trimmed)
        newTitle = ""
        isAddingFirst = true
        isNewFocused = true
    }

}
