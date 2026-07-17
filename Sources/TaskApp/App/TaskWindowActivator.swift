import AppKit

@MainActor
final class TaskWindowActivator {
    private static let shared = TaskWindowActivator()

    private let mainWindow: @MainActor () -> NSWindow?
    private var openMainWindow: @MainActor () -> Void

    init(
        mainWindow: @escaping @MainActor () -> NSWindow? = TaskWindowActivator.existingMainWindow,
        openMainWindow: @escaping @MainActor () -> Void = {}
    ) {
        self.mainWindow = mainWindow
        self.openMainWindow = openMainWindow
    }

    static func configureMainWindowOpening(_ action: @escaping @MainActor () -> Void) {
        shared.openMainWindow = action
    }

    static func showMainWindow() {
        shared.showMainWindow()
    }

    func showMainWindow() {
        NSApp?.unhide(nil)
        NSApp?.activate(ignoringOtherApps: true)

        guard let window = mainWindow() else {
            openMainWindow()
            DispatchQueue.main.async { [weak self] in
                self?.mainWindow()?.makeKeyAndOrderFront(nil)
            }
            return
        }

        window.makeKeyAndOrderFront(nil)
    }

    private static func existingMainWindow() -> NSWindow? {
        guard let application = NSApp else { return nil }
        return application.keyWindow
            ?? application.mainWindow
            ?? application.windows.first(where: { $0.canBecomeKey })
    }
}
