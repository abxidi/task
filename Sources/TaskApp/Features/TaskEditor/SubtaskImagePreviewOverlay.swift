import AppKit
import SwiftUI

struct SubtaskImagePreview: Identifiable {
    let id = UUID()
    let images: [SubtaskPreviewImage]
    let initialIndex: Int
}

struct SubtaskPreviewImage: Identifiable {
    let id: UUID
    let data: Data
}

struct SubtaskImagePreviewOverlay: View {
    let preview: SubtaskImagePreview
    let onDismiss: () -> Void

    @State private var index: Int

    init(preview: SubtaskImagePreview, onDismiss: @escaping () -> Void) {
        self.preview = preview
        self.onDismiss = onDismiss
        _index = State(initialValue: preview.initialIndex)
    }

    private var current: SubtaskPreviewImage? {
        guard preview.images.indices.contains(index) else { return nil }
        return preview.images[index]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                VStack(spacing: 16) {
                    HStack {
                        Text("图片预览")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(index + 1) / \(preview.images.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(TaskDesignTokens.quiet)
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .frame(width: 28, height: 28)
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
                                    minWidth: SubtaskImagePreviewLayout.minimumDimension,
                                    maxWidth: SubtaskImagePreviewLayout.maximumDimension,
                                    minHeight: SubtaskImagePreviewLayout.minimumDimension,
                                    maxHeight: SubtaskImagePreviewLayout.maximumDimension
                                )
                                .accessibilityLabel("原图预览")
                        } else {
                            ContentUnavailableView("无法读取图片", systemImage: "photo.badge.exclamationmark")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 20) {
                        Button {
                            index = max(0, index - 1)
                        } label: {
                            Label("上一张", systemImage: "chevron.left")
                        }
                        .disabled(index == 0)

                        Button {
                            index = min(preview.images.count - 1, index + 1)
                        } label: {
                            Label("下一张", systemImage: "chevron.right")
                        }
                        .disabled(index >= preview.images.count - 1)
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(20)
                .frame(
                    width: SubtaskImagePreviewLayout.panelSize(for: proxy.size).width,
                    height: SubtaskImagePreviewLayout.panelSize(for: proxy.size).height
                )
                .background(TaskDesignTokens.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TaskDesignTokens.line, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {}
            }
        }
        .onExitCommand(perform: onDismiss)
        .accessibilityAddTraits(.isModal)
    }
}
