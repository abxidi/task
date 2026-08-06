import AppKit
import SwiftUI

enum AdaptiveNoteTextEditorLayout {
    static let measuresActualLineFragments = true
    static let usesInternalScrolling = true
    static let accessibilityLabel = "任务备注"
}

struct AdaptiveNoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> AdaptiveNoteScrollView {
        let scrollView = AdaptiveNoteScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        TaskScrollIndicatorStyle.configure(scrollView)

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = TaskEditorNoteLayout.font
        textView.textColor = NSColor(TaskDesignTokens.muted)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainerInset = NSSize(width: 5, height: 7)
        textView.typingAttributes = [
            .font: TaskEditorNoteLayout.font,
            .foregroundColor: NSColor(TaskDesignTokens.muted),
        ]
        textView.setAccessibilityLabel(AdaptiveNoteTextEditorLayout.accessibilityLabel)

        scrollView.documentView = textView
        scrollView.onLayout = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView, let coordinator else { return }
            coordinator.scheduleHeightReport(for: textView)
        }
        context.coordinator.scheduleHeightReport(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: AdaptiveNoteScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.scheduleHeightReport(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AdaptiveNoteTextEditor
        private var reportedHeight: CGFloat?
        private var isHeightReportScheduled = false

        init(parent: AdaptiveNoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scheduleHeightReport(for: textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func scheduleHeightReport(for textView: NSTextView) {
            guard !isHeightReportScheduled else { return }
            isHeightReportScheduled = true
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.isHeightReportScheduled = false
                self.reportHeight(for: textView)
            }
        }

        private func reportHeight(for textView: NSTextView) {
            guard
                textView.bounds.width > 0,
                let layoutManager = textView.layoutManager,
                let textContainer = textView.textContainer
            else {
                return
            }

            let lineCount = TaskEditorNoteLineCounter.count(
                using: layoutManager,
                textContainer: textContainer
            )
            let height = TaskEditorNoteLayout.height(forLineCount: lineCount)
            guard height != reportedHeight else { return }
            reportedHeight = height
            parent.onHeightChange(height)
        }
    }
}

final class AdaptiveNoteScrollView: NSScrollView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}
