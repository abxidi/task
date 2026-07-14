import SwiftUI

struct SubtaskEditor: View {
    @Binding var items: [String]
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

            ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 9) {
                    Image(systemName: "square")
                        .font(.system(size: 12))
                        .foregroundStyle(TaskDesignTokens.quiet)
                    TextField("子任务", text: binding(for: index))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x50544C))
                    Button {
                        items.remove(at: index)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: 0xB0B3AA))
                    }
                    .buttonStyle(.plain)
                    .help("删除子任务")
                }
                .frame(minHeight: 38)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(hex: 0xE5E5DF)).frame(height: 1)
                }
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
        newTitle = ""
        isNewFocused = true
    }
}
