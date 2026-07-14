import SwiftUI

struct SubtaskEditor: View {
    @Binding var items: [String]
    @Binding var completion: [Bool]
    @State private var newTitle = ""
    @FocusState private var isNewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("子任务")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.ink)
                Spacer()
                Text("\(items.count) 项")
                    .font(.system(size: 8))
                    .foregroundStyle(TaskDesignTokens.quiet)
            }

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
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: 0x50544C))
                                .strikethrough(completion[index])
                        }
                        .frame(minHeight: 37)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(items.count) * 38)
            }

            HStack(spacing: 8) {
                Text("＋")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.acid)
                    .frame(width: 18, height: 18)
                    .background(TaskDesignTokens.ink, in: Circle())
                TextField("添加一个子任务", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($isNewFocused)
                    .onSubmit(addNew)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 37)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color(hex: 0xD2D3CB))
            )
            .padding(.top, 10)
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
            return
        }
        items.append(trimmed)
        completion.append(false)
        newTitle = ""
        isNewFocused = true
    }

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        completion.move(fromOffsets: source, toOffset: destination)
    }
}
