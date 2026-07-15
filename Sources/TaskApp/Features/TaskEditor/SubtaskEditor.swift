import SwiftUI

struct SubtaskEditor: View {
    @Binding var items: [String]
    @Binding var completion: [Bool]
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
                                    completion[index].toggle()
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
                        .onMove(perform: move)
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
                        Image(systemName: "plus")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(TaskDesignTokens.quiet)
                            .frame(maxWidth: .infinity, minHeight: TaskEditorLayout.emptySubtaskHeight)
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
                        TextField("添加一个子任务", text: $newTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused($isNewFocused)
                            .onSubmit(addNew)
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
        items.append(trimmed)
        completion.append(false)
        newTitle = ""
        isAddingFirst = true
        isNewFocused = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        completion.move(fromOffsets: source, toOffset: destination)
    }
}
