import AppKit
import SwiftUI

enum TaskScrollIndicatorStyle {
    static let hidesSwiftUIIndicators = true

    static func configure(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
    }
}

extension View {
    func taskSubtleScrollIndicators() -> some View {
        scrollIndicators(TaskScrollIndicatorStyle.hidesSwiftUIIndicators ? .hidden : .automatic)
            .background(TaskScrollIndicatorConfigurator())
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

final class TaskScrollIndicatorHostView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureEnclosingScrollView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureEnclosingScrollView()
    }

    func configureEnclosingScrollView() {
        var view: NSView? = self
        while let current = view {
            if let scrollView = current as? NSScrollView {
                TaskScrollIndicatorStyle.configure(scrollView)
                return
            }
            view = current.superview
        }
    }
}
