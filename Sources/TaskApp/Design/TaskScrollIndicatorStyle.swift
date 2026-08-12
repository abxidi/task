import AppKit
import ObjectiveC.runtime
import SwiftUI

@MainActor
enum TaskScrollIndicatorPolicy {
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        guard
            let verticalSetter = class_getInstanceMethod(
                NSScrollView.self,
                #selector(setter: NSScrollView.hasVerticalScroller)
            ),
            let taskVerticalSetter = class_getInstanceMethod(
                NSScrollView.self,
                #selector(NSScrollView.task_setHasVerticalScroller(_:))
            ),
            let horizontalSetter = class_getInstanceMethod(
                NSScrollView.self,
                #selector(setter: NSScrollView.hasHorizontalScroller)
            ),
            let taskHorizontalSetter = class_getInstanceMethod(
                NSScrollView.self,
                #selector(NSScrollView.task_setHasHorizontalScroller(_:))
            )
        else {
            assertionFailure("Unable to install the Task scroll-indicator policy")
            return
        }

        method_exchangeImplementations(verticalSetter, taskVerticalSetter)
        method_exchangeImplementations(horizontalSetter, taskHorizontalSetter)
        isInstalled = true
    }
}

private extension NSScrollView {
    @objc dynamic func task_setHasVerticalScroller(_: Bool) {
        task_setHasVerticalScroller(false)
    }

    @objc dynamic func task_setHasHorizontalScroller(_: Bool) {
        task_setHasHorizontalScroller(false)
    }
}

enum TaskScrollIndicatorStyle {
    static let hidesSwiftUIIndicators = true
    static let appliesBeforeFirstFrame = true

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
        nsView.configureEnclosingScrollView()
        nsView.configureScrollViewsInWindow()
        nsView.scheduleScrollViewConfiguration()
    }
}

final class TaskScrollIndicatorHostView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureEnclosingScrollView()
        configureScrollViewsInWindow()
        scheduleScrollViewConfiguration()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureEnclosingScrollView()
        configureScrollViewsInWindow()
        scheduleScrollViewConfiguration()
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        configureScrollViewsInWindow()
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

    func configureScrollViewsInWindow() {
        guard let contentView = window?.contentView else { return }
        TaskScrollIndicatorStyle.configureAllScrollViews(in: contentView)
    }

    func scheduleScrollViewConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.configureScrollViewsInWindow()
        }
    }
}
