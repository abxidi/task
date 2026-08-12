import AppKit
import ObjectiveC.runtime
import SwiftUI

@MainActor
enum TaskScrollIndicatorPolicy {
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        guard
            let drawKnob = class_getInstanceMethod(
                NSScroller.self,
                #selector(NSScroller.drawKnob)
            ),
            let taskDrawKnob = class_getInstanceMethod(
                NSScroller.self,
                #selector(NSScroller.task_drawKnob)
            ),
            let drawKnobSlot = class_getInstanceMethod(
                NSScroller.self,
                #selector(NSScroller.drawKnobSlot(in:highlight:))
            ),
            let taskDrawKnobSlot = class_getInstanceMethod(
                NSScroller.self,
                #selector(NSScroller.task_drawKnobSlot(in:highlight:))
            ),
            let setScrollerStyle = class_getInstanceMethod(
                NSScrollView.self,
                #selector(setter: NSScrollView.scrollerStyle)
            ),
            let taskSetScrollerStyle = class_getInstanceMethod(
                NSScrollView.self,
                #selector(NSScrollView.task_setScrollerStyle(_:))
            ),
            let setAlphaValue = class_getInstanceMethod(
                NSView.self,
                #selector(setter: NSView.alphaValue)
            ),
            let taskSetAlphaValue = class_getInstanceMethod(
                NSView.self,
                #selector(NSView.task_setAlphaValue(_:))
            )
        else {
            assertionFailure("Unable to install the Task scroll-indicator policy")
            return
        }

        method_exchangeImplementations(drawKnob, taskDrawKnob)
        method_exchangeImplementations(drawKnobSlot, taskDrawKnobSlot)
        method_exchangeImplementations(setScrollerStyle, taskSetScrollerStyle)
        method_exchangeImplementations(setAlphaValue, taskSetAlphaValue)
        isInstalled = true
    }
}

private extension NSScroller {
    @objc dynamic func task_drawKnob() {
        // Intentionally empty. Preserve AppKit's native scroller state and
        // geometry while suppressing only the visual indicator.
    }

    @objc dynamic func task_drawKnobSlot(in _: NSRect, highlight _: Bool) {
        // Intentionally empty. Legacy scroller tracks must remain invisible too.
    }
}

private extension NSScrollView {
    @objc dynamic func task_setScrollerStyle(_: NSScroller.Style) {
        task_setScrollerStyle(.overlay)
    }
}

private extension NSView {
    @objc dynamic func task_setAlphaValue(_ alphaValue: CGFloat) {
        task_setAlphaValue(self is NSScroller ? 0 : alphaValue)
    }
}

enum TaskScrollIndicatorStyle {
    static let hidesSwiftUIIndicators = true
    static let appliesBeforeFirstFrame = true

    static func configure(_ scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScroller?.alphaValue = 0
        scrollView.horizontalScroller?.alphaValue = 0
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
