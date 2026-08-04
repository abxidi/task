import AppKit
import SwiftUI

enum TaskScrollIndicatorStyle {
    static func configure(_ scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.verticalScroller?.controlSize = .small
        scrollView.horizontalScroller?.controlSize = .small
    }
}

extension View {
    func taskSubtleScrollIndicators() -> some View {
        background(TaskScrollIndicatorConfigurator())
    }
}

private struct TaskScrollIndicatorConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> TaskScrollIndicatorHostView {
        TaskScrollIndicatorHostView()
    }

    func updateNSView(_ nsView: TaskScrollIndicatorHostView, context: Context) {
        nsView.configureEnclosingScrollView()
    }
}

private final class TaskScrollIndicatorHostView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureEnclosingScrollView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureEnclosingScrollView()
    }

    func configureEnclosingScrollView() {
        guard let scrollView = enclosingScrollView else { return }
        TaskScrollIndicatorStyle.configure(scrollView)
    }
}
