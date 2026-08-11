import AppKit
import SwiftUI

enum TaskScrollIndicatorStyle {
    static let hidesSwiftUIIndicators = true

    static func configure(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
    }

    static func configureAllScrollViews(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            configure(scrollView)
        }

        for subview in view.subviews {
            configureAllScrollViews(in: subview)
        }
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
        nsView.configureScrollViewsInWindow()
    }
}

private final class TaskScrollIndicatorHostView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureScrollViewsInWindow()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureScrollViewsInWindow()
    }

    func configureScrollViewsInWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let contentView = self?.window?.contentView else { return }
            TaskScrollIndicatorStyle.configureAllScrollViews(in: contentView)
        }
    }
}
