import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let activationHandler: @MainActor () -> Void

    init(_ activationHandler: @escaping @MainActor () -> Void = TaskWindowActivator.showMainWindow) {
        self.activationHandler = activationHandler
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusButton()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc func activateMainWindow(_ sender: Any?) {
        activationHandler()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        button.image = Self.makeTemplateImage()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(activateMainWindow(_:))
        button.setAccessibilityLabel("显示 Task 主窗口")
    }

    private static func makeTemplateImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let body = NSBezierPath(
            roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16),
            xRadius: 4,
            yRadius: 4
        )
        NSColor.white.setFill()
        body.fill()

        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSBezierPath(rect: NSRect(x: 4, y: 10.5, width: 10, height: 2.5)).fill()
        NSBezierPath(rect: NSRect(x: 7.75, y: 4, width: 2.5, height: 7)).fill()

        image.isTemplate = true
        return image
    }
}
