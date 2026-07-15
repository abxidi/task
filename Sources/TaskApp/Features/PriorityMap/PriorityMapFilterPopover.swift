import SwiftUI
import TaskPersistence

struct PriorityMapFilterPopover: View {
    let tags: [Tag]
    @Binding var selectedTagNames: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("筛选标签")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Button("清除") {
                    selectedTagNames.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
            }

            if tags.isEmpty {
                Text("暂无标签")
                    .font(.system(size: 11))
                    .foregroundStyle(TaskDesignTokens.quiet)
            } else {
                ForEach(tags, id: \.id) { tag in
                    Button {
                        toggle(tag.name)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTagNames.contains(tag.name) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 13))
                                .foregroundStyle(selectedTagNames.contains(tag.name) ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                            Text(tag.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TaskDesignTokens.ink)
                            Spacer()
                        }
                        .frame(minHeight: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }

    private func toggle(_ name: String) {
        if selectedTagNames.contains(name) {
            selectedTagNames.remove(name)
        } else {
            selectedTagNames.insert(name)
        }
    }
}
