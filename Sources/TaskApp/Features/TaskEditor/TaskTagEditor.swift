import SwiftData
import SwiftUI
import TaskPersistence

enum TaskTagDefaults {
    static let names = ["工作", "个人", "重要", "待跟进"]

    @MainActor
    static func ensurePersisted(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        let existingNames = Set(existing.map(\.name))
        let missing = names.filter { !existingNames.contains($0) }
        guard !missing.isEmpty else { return }
        missing.forEach { context.insert(Tag(name: $0)) }
        try? context.save()
    }
}

struct TaskTagEditor: View {
    @Binding var tagNames: [String]
    @Environment(\.modelContext) private var modelContext
    @State private var isPickerPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Text("任务标签")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TaskDesignTokens.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tagNames, id: \.self) { name in
                        Button {
                            tagNames.removeAll { $0 == name }
                        } label: {
                            TaskTagPill(name: name, showsRemoveIcon: true)
                        }
                        .buttonStyle(.plain)
                        .help("移除标签 \(name)")
                    }
                    tagPickerButton
                }
            }
            .frame(maxWidth: 430, alignment: .leading)
        }
        .onAppear {
            TaskTagDefaults.ensurePersisted(in: modelContext)
        }
    }

    private var tagPickerButton: some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("选择或新建标签")
        .popover(isPresented: $isPickerPresented, arrowEdge: .top) {
            TaskTagPicker(tagNames: $tagNames)
                .frame(width: 300)
        }
    }
}

struct TaskTagPill: View {
    let name: String
    var showsRemoveIcon = false

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .lineLimit(1)
            if showsRemoveIcon {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(TaskDesignTokens.muted)
        .padding(.horizontal, 8)
        .frame(minHeight: 24)
        .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct TaskTagPicker: View {
    @Binding var tagNames: [String]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var newTagName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择标签")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TaskDesignTokens.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(tags, id: \.id) { tag in
                    Button {
                        toggle(tag.name)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tagNames.contains(tag.name) ? "checkmark" : "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text(tag.name)
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(tagNames.contains(tag.name) ? TaskDesignTokens.ink : TaskDesignTokens.muted)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(tagNames.contains(tag.name) ? TaskDesignTokens.acid.opacity(0.35) : TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("新建标签", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.line, lineWidth: 1))
                    .onSubmit(createTag)
                Button(action: createTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(TaskDesignTokens.ink, in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(TaskDesignTokens.acid)
                .help("新建标签")
            }
        }
        .padding(14)
        .onAppear {
            TaskTagDefaults.ensurePersisted(in: modelContext)
        }
    }

    private func toggle(_ name: String) {
        if tagNames.contains(name) {
            tagNames.removeAll { $0 == name }
        } else {
            tagNames.append(name)
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !tags.contains(where: { $0.name == name }) {
            modelContext.insert(Tag(name: name))
            try? modelContext.save()
        }
        if !tagNames.contains(name) {
            tagNames.append(name)
        }
        newTagName = ""
    }
}
