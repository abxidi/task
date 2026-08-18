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
    let canAttachImages: Bool
    let attachments: (UUID) -> [SubtaskAttachment]
    let onPasteImage: (UUID, NSImage) throws -> Void
    let onDeleteAttachment: (SubtaskAttachment) throws -> Void

    @State private var newTitle = ""
    @State private var attachmentRevision = 0
    @State private var attachmentPopoverSubtaskID: UUID?
    @State private var attachmentError: String?
    @StateObject private var reorderCoordinator = SubtaskReorderCoordinator()
    @State private var subtaskFrames: [UUID: CGRect] = [:]
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
        .onPreferenceChange(SubtaskReorderFramePreferenceKey.self) { subtaskFrames = $0 }
        .onDisappear { reorderCoordinator.cancel() }
        .animation(.easeOut(duration: SubtaskReorderPresentation.reorderDuration), value: ids)
    }

    private func subtaskRow(index: Int, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
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

                TextField("子任务", text: binding(for: index), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x50544C))
                    .strikethrough(completion[index])
                    .lineLimit(1...)
                    .fixedSize(horizontal: false, vertical: true)
                    .onPasteCommand(of: [.image]) { providers in
                        receiveImage(from: providers, for: id)
                    }
                    .accessibilityLabel("子任务")

                attachmentButton(for: id)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .gesture(reorderGesture(for: id))
                    .help("拖动排序")
                    .accessibilityLabel("拖动排序")

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

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: TaskEditorSubtaskEntryStyle.minimumHeight)
        .opacity(reorderCoordinator.sourceID == id ? SubtaskReorderPresentation.sourceOpacity : 1)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SubtaskReorderFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .global)]
                )
            }
        }
        .overlay(alignment: .top) {
            if reorderCoordinator.insertionLocation == .before(id) {
                SubtaskReorderInsertionIndicator()
            }
        }
        .overlay(alignment: .bottom) {
            if reorderCoordinator.insertionLocation == .after(id) {
                SubtaskReorderInsertionIndicator()
            }
        }
    }

    private func attachmentButton(for subtaskID: UUID) -> some View {
        let _ = attachmentRevision
        let values = attachments(subtaskID)
        return Button {
            attachmentPopoverSubtaskID = subtaskID
        } label: {
            HStack(spacing: 4) {
                Image(systemName: values.isEmpty ? "paperclip" : "paperclip.fill")
                    .font(.system(size: 11, weight: .medium))
                if !values.isEmpty {
                    Text("\(values.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(TaskDesignTokens.muted)
            .frame(minWidth: 28, minHeight: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canAttachImages)
        .help(
            canAttachImages
                ? (values.isEmpty ? "添加图片" : "查看子任务图片")
                : "请先填写任务标题"
        )
        .accessibilityLabel(
            canAttachImages
                ? (values.isEmpty ? "添加子任务图片" : "查看子任务图片，共 \(values.count) 张")
                : "添加子任务图片不可用，请先填写任务标题"
        )
        .popover(
            isPresented: Binding(
                get: { attachmentPopoverSubtaskID == subtaskID },
                set: { isPresented in
                    if !isPresented { attachmentPopoverSubtaskID = nil }
                }
            ),
            arrowEdge: .trailing
        ) {
            SubtaskAttachmentPopover(
                attachments: values,
                onAddImage: { image in
                    try onPasteImage(subtaskID, image)
                    attachmentRevision += 1
                },
                onDelete: { attachment in
                    try onDeleteAttachment(attachment)
                    attachmentRevision += 1
                }
            )
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { items[index] },
            set: { items[index] = $0 }
        )
    }

    private func reorderGesture(for id: UUID) -> some Gesture {
        DragGesture(minimumDistance: SubtaskReorderPresentation.dragMinimumDistance, coordinateSpace: .global)
            .onChanged { value in
                if reorderCoordinator.sourceID != id {
                    reorderCoordinator.begin(sourceID: id)
                }
                reorderCoordinator.update(
                    location: value.location,
                    orderedIDs: ids,
                    frames: subtaskFrames
                )
            }
            .onEnded { value in
                reorderCoordinator.update(
                    location: value.location,
                    orderedIDs: ids,
                    frames: subtaskFrames
                )
                guard let move = reorderCoordinator.complete() else { return }
                apply(move)
            }
    }

    private func apply(_ move: SubtaskReorderMove) {
        guard let sourceIndex = ids.firstIndex(of: move.sourceID) else { return }
        let destinationID: UUID
        let destinationOffset: Int
        switch move.insertionLocation {
        case .before(let id):
            destinationID = id
            destinationOffset = 0
        case .after(let id):
            destinationID = id
            destinationOffset = 1
        }
        guard let destinationIndex = ids.firstIndex(of: destinationID), move.sourceID != destinationID else {
            return
        }
        onMove(IndexSet(integer: sourceIndex), destinationIndex + destinationOffset)
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
        for provider in providers {
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
    static let subtaskTitlesUseMultilineField = true
    static let subtaskTitleMaximumLineCount: Int? = nil
    static let showsReorderInsertionIndicator = true
    static let supportsEndDropInsertion = true
}
