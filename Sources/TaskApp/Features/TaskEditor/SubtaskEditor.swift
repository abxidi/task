import AppKit
import SwiftUI
import TaskPersistence
import UniformTypeIdentifiers

struct SubtaskEditor: View {
    @Binding var items: [String]
    @Binding var completion: [Bool]
    @Binding var ids: [UUID]
    let onToggle: (Int) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onDelete: (Int) -> Void
    let onAdd: (String) -> Void
    let attachments: (UUID) -> [SubtaskAttachment]
    let onPasteImage: (UUID, NSImage) throws -> Void
    let onDeleteAttachment: (SubtaskAttachment) throws -> Void

    @State private var newTitle = ""
    @State private var attachmentRevision = 0
    @State private var attachmentError: String?
    @State private var insertionLocation: SubtaskReorderInsertionLocation?
    @FocusState private var isNewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                subtaskRow(index: index, id: id)
                if index < ids.count - 1 {
                    Divider()
                }
            }

            if !ids.isEmpty {
                Divider()
                reorderDropZone(after: ids[ids.count - 1])
            }

            compactInputRow
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Color(hex: 0xD2D3CB))
        )
        .alert("无法添加图片", isPresented: Binding(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(attachmentError ?? "")
        }
    }

    private func subtaskRow(index: Int, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    onToggle(index)
                } label: {
                    Image(systemName: completion[index] ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13))
                        .foregroundStyle(completion[index] ? TaskDesignTokens.success : TaskDesignTokens.quiet)
                }
                .buttonStyle(.plain)
                .frame(width: TaskEditorSubtaskEntryStyle.iconFrameSize, height: TaskEditorSubtaskEntryStyle.iconFrameSize)
                .accessibilityLabel(completion[index] ? "标记为未完成" : "标记为已完成")

                TextField("子任务", text: binding(for: index))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x50544C))
                    .strikethrough(completion[index])
                    .onPasteCommand(of: [.image]) { providers in
                        receiveImage(from: providers, for: id)
                    }
                    .accessibilityLabel("子任务")

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .help("拖动排序")

                Button {
                    onDelete(index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TaskDesignTokens.quiet)
                .help("删除子任务")
                .accessibilityLabel("删除子任务")
            }

            let currentAttachments = attachments(id)
            if !currentAttachments.isEmpty {
                attachmentThumbnails(currentAttachments)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: TaskEditorSubtaskEntryStyle.minimumHeight)
        .onDrag {
            NSItemProvider(object: id.uuidString as NSString)
        }
        .dropDestination(for: String.self) { values, _ in
            moveSubtask(from: values, before: id)
        } isTargeted: { isTargeted in
            updateInsertionLocation(
                isTargeted,
                for: .before(id)
            )
        }
        .overlay(alignment: .top) {
            if insertionLocation == .before(id) {
                SubtaskReorderInsertionIndicator()
            }
        }
    }

    private func reorderDropZone(after id: UUID) -> some View {
        Color.clear
            .frame(height: 8)
            .dropDestination(for: String.self) { values, _ in
                moveSubtask(from: values, after: id)
            } isTargeted: { isTargeted in
                updateInsertionLocation(
                    isTargeted,
                    for: .after(id)
                )
            }
            .overlay {
                if insertionLocation == .after(id) {
                    SubtaskReorderInsertionIndicator()
                }
            }
    }

    private func attachmentThumbnails(_ values: [SubtaskAttachment]) -> some View {
        let _ = attachmentRevision
        return HStack(spacing: 8) {
            ForEach(values, id: \.id) { attachment in
                ZStack(alignment: .topTrailing) {
                    if let image = NSImage(data: attachment.thumbnailData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(TaskDesignTokens.line, lineWidth: 1)
                            )
                    }

                    Button {
                        removeAttachment(attachment)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TaskDesignTokens.ink)
                    .background(TaskDesignTokens.raised, in: Circle())
                    .offset(x: 4, y: -4)
                    .help("删除图片")
                    .accessibilityLabel("删除图片")
                }
            }
        }
        .padding(.leading, TaskEditorSubtaskEntryStyle.iconFrameSize + 8)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }

    private func updateInsertionLocation(
        _ isTargeted: Bool,
        for location: SubtaskReorderInsertionLocation
    ) {
        if isTargeted {
            insertionLocation = location
        } else if insertionLocation == location {
            insertionLocation = nil
        }
    }

    private func moveSubtask(from values: [String], before id: UUID) -> Bool {
        defer { insertionLocation = nil }
        guard let value = values.first,
              let sourceID = UUID(uuidString: value),
              let sourceIndex = ids.firstIndex(of: sourceID),
              let destinationIndex = ids.firstIndex(of: id),
              sourceID != id else {
            return false
        }
        onMove(IndexSet(integer: sourceIndex), destinationIndex)
        return true
    }

    private func moveSubtask(from values: [String], after id: UUID) -> Bool {
        defer { insertionLocation = nil }
        guard let value = values.first,
              let sourceID = UUID(uuidString: value),
              let sourceIndex = ids.firstIndex(of: sourceID),
              let destinationIndex = ids.firstIndex(of: id),
              sourceID != id else {
            return false
        }
        onMove(IndexSet(integer: sourceIndex), destinationIndex + 1)
        return true
    }

    private var compactInputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: TaskEditorSubtaskEntryStyle.iconSize, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.quiet)
                .frame(width: TaskEditorSubtaskEntryStyle.iconFrameSize, height: TaskEditorSubtaskEntryStyle.iconFrameSize)
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
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        addNew()
                        return .handled
                    }
                    .accessibilityLabel("添加子任务")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: TaskEditorSubtaskEntryStyle.minimumHeight)
    }

    private func receiveImage(from providers: [NSItemProvider], for subtaskID: UUID) {
        guard let provider = providers.first else { return }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data, let image = NSImage(data: data) else { return }
            Task { @MainActor in
                do {
                    try onPasteImage(subtaskID, image)
                    attachmentRevision += 1
                } catch {
                    attachmentError = error.localizedDescription
                }
            }
        }
    }

    private func removeAttachment(_ attachment: SubtaskAttachment) {
        do {
            try onDeleteAttachment(attachment)
            attachmentRevision += 1
        } catch {
            attachmentError = error.localizedDescription
        }
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
    static let usesSharedListRows = false
    static let startsAsInput = true
    static let iconSize: CGFloat = 12
    static let iconFrameSize: CGFloat = 18
    static let minimumHeight: CGFloat = 40
    static let showsReorderInsertionIndicator = true
    static let supportsEndDropInsertion = true
}
