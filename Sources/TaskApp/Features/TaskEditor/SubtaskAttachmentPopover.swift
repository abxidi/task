import AppKit
import SwiftUI
import TaskPersistence
import UniformTypeIdentifiers

struct SubtaskAttachmentPopover: View {
    let attachments: [SubtaskAttachment]
    let onAddImage: (NSImage) throws -> Void
    let onDelete: (SubtaskAttachment) throws -> Void

    @State private var isFileImporterPresented = false
    @State private var isDropTargeted = false
    @State private var errorMessage: String?
    @State private var previewState: AttachmentPreviewState?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("子任务图片 · " + String(attachments.count))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if attachments.count > SubtaskAttachmentLayout.visibleCapacity {
                    Text("可滚动")
                        .font(.system(size: 9))
                        .foregroundStyle(TaskDesignTokens.quiet)
                }
            }

            if attachments.isEmpty {
                ContentUnavailableView {
                    Label("暂无图片", systemImage: "photo.on.rectangle")
                } description: {
                    Text("粘贴图片到这个子任务")
                }
                .frame(height: 72)
            } else {
                ScrollView(showsIndicators: attachments.count > SubtaskAttachmentLayout.visibleCapacity) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 8),
                            count: SubtaskAttachmentLayout.gridColumnCount
                        ),
                        spacing: 8
                    ) {
                        ForEach(attachments, id: \.id) { attachment in
                            attachmentThumbnail(attachment)
                        }
                    }
                    .padding(2)
                }
                .frame(height: 120)
            }

            HStack(spacing: 8) {
                Button(action: pasteFromClipboard) {
                    Label("粘贴图片", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command])

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("选择文件", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(TaskDesignTokens.muted)
            }
            .font(.system(size: 11, weight: .medium))

            Text(isDropTargeted ? "松开以添加图片" : "")
                .font(.system(size: 10))
                .foregroundStyle(TaskDesignTokens.muted)
                .frame(maxWidth: .infinity, minHeight: 14, alignment: .leading)
        }
        .padding(14)
        .frame(width: 280)
        .background(TaskDesignTokens.panel)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TaskDesignTokens.acid, lineWidth: 2)
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.image.identifier], isTargeted: $isDropTargeted) { providers in
            receiveImages(from: providers)
            return true
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            importImages(from: result)
        }
        .sheet(item: $previewState) { state in
            SubtaskImagePreviewSheet(images: state.images, initialIndex: state.initialIndex)
        }
        .alert("无法添加图片", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func attachmentThumbnail(_ attachment: SubtaskAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                let images = attachments.map { PreviewImage(id: $0.id, data: $0.imageData) }
                guard let index = images.firstIndex(where: { $0.id == attachment.id }) else { return }
                previewState = AttachmentPreviewState(images: images, initialIndex: index)
            } label: {
                if let image = NSImage(data: attachment.thumbnailData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: SubtaskAttachmentLayout.thumbnailWidth,
                            height: SubtaskAttachmentLayout.thumbnailHeight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(TaskDesignTokens.line, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(TaskDesignTokens.canvas)
                        .frame(
                            width: SubtaskAttachmentLayout.thumbnailWidth,
                            height: SubtaskAttachmentLayout.thumbnailHeight
                        )
                }

            }
            .buttonStyle(.plain)
            .help("预览图片")
            .accessibilityLabel("预览图片")

            Button {
                remove(attachment)
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

    private func pasteFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(
            forClasses: [NSImage.self],
            options: nil
        )?.first as? NSImage else {
            errorMessage = "剪贴板中没有图片"
            return
        }
        add(image)
    }

    private func receiveImages(from providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    add(image)
                }
            }
        }
    }

    private func importImages(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
            return
        }

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            guard let image = NSImage(contentsOf: url) else { continue }
            add(image)
        }
    }

    private func add(_ image: NSImage) {
        do {
            try onAddImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ attachment: SubtaskAttachment) {
        do {
            try onDelete(attachment)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AttachmentPreviewState: Identifiable {
    let id = UUID()
    let images: [PreviewImage]
    let initialIndex: Int
}

private struct PreviewImage: Identifiable {
    let id: UUID
    let data: Data
}

private struct SubtaskImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let images: [PreviewImage]
    @State private var index: Int

    init(images: [PreviewImage], initialIndex: Int) {
        self.images = images
        _index = State(initialValue: initialIndex)
    }

    private var current: PreviewImage? {
        guard images.indices.contains(index) else { return nil }
        return images[index]
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("图片预览")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(index + 1) / \(images.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("关闭预览")
                .accessibilityLabel("关闭预览")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(TaskDesignTokens.canvas)

                if let data = current?.data, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            minWidth: SubtaskAttachmentLayout.previewMinimumDimension,
                            maxWidth: SubtaskAttachmentLayout.previewMaximumDimension,
                            minHeight: SubtaskAttachmentLayout.previewMinimumDimension,
                            maxHeight: SubtaskAttachmentLayout.previewMaximumDimension
                        )
                        .accessibilityLabel("原图预览")
                } else {
                    ContentUnavailableView("无法读取图片", systemImage: "photo.badge.exclamationmark")
                }
            }
            .frame(
                minWidth: SubtaskAttachmentLayout.previewMinimumDimension,
                maxWidth: SubtaskAttachmentLayout.previewMaximumDimension,
                minHeight: SubtaskAttachmentLayout.previewMinimumDimension,
                maxHeight: SubtaskAttachmentLayout.previewMaximumDimension
            )

            HStack(spacing: 16) {
                Button {
                    index = max(0, index - 1)
                } label: {
                    Label("上一张", systemImage: "chevron.left")
                }
                .disabled(index == 0)

                Button {
                    index = min(images.count - 1, index + 1)
                } label: {
                    Label("下一张", systemImage: "chevron.right")
                }
                .disabled(index >= images.count - 1)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .medium))
        }
        .padding(18)
        .frame(minWidth: 380, minHeight: 340)
        .background(TaskDesignTokens.panel)
        .onExitCommand { dismiss() }
    }
}
