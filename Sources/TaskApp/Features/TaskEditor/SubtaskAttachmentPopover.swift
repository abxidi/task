import AppKit
import SwiftUI
import TaskPersistence
import UniformTypeIdentifiers

struct SubtaskAttachmentPopover: View {
    let attachments: [SubtaskAttachment]
    let onAddImage: (NSImage) throws -> Void
    let onDelete: (SubtaskAttachment) throws -> Void
    let onPreview: (SubtaskImagePreview) -> Void

    @State private var isFileImporterPresented = false
    @State private var isDropTargeted = false
    @State private var errorMessage: String?

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
                        ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                            attachmentThumbnail(attachment, position: index + 1)
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
        .alert("无法添加图片", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func attachmentThumbnail(_ attachment: SubtaskAttachment, position: Int) -> some View {
        let positionLabel = String(position)
        let countLabel = String(attachments.count)
        return ZStack(alignment: .topTrailing) {
            Button {
                let images = attachments.map { SubtaskPreviewImage(id: $0.id, data: $0.imageData) }
                guard let index = images.firstIndex(where: { $0.id == attachment.id }) else { return }
                onPreview(SubtaskImagePreview(images: images, initialIndex: index))
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
            .accessibilityLabel("预览图片 " + positionLabel + "，共 " + countLabel + " 张")

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
            .accessibilityLabel("删除图片 " + positionLabel + "，共 " + countLabel + " 张")
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
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                guard let data else {
                    reportError(error?.localizedDescription ?? "无法读取拖入的图片")
                    return
                }
                guard let image = NSImage(data: data) else {
                    reportError("无法读取拖入的图片")
                    return
                }
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
            guard let image = NSImage(contentsOf: url) else {
                errorMessage = "无法读取图片：" + url.lastPathComponent
                continue
            }
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

    private func reportError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
        }
    }
}
