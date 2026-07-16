import AppKit

@MainActor
enum TaskWindowActivator {
    static func showMainWindow() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        let window = NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.canBecomeKey })
        window?.makeKeyAndOrderFront(nil)
    }
}
