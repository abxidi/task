import AppKit
import Carbon
import Combine
import CoreGraphics

@MainActor
protocol GlobalShortcutRegistration: AnyObject {
    func unregister()
}

@MainActor
protocol GlobalShortcutRegistering: AnyObject {
    func register(
        _ shortcut: GlobalShortcutKeyCombination,
        action: @escaping @MainActor () -> Void
    ) -> GlobalShortcutRegistration?
}

@MainActor
final class GlobalShortcutManager: ObservableObject {
    private static let defaultsKey = "globalShortcutConfiguration"

    @Published private(set) var configuration: GlobalShortcutConfiguration
    @Published private(set) var activeConfiguration: GlobalShortcutConfiguration?
    @Published private(set) var hasCustomShortcutRegistrationError = false
    @Published private(set) var isInputMonitoringAuthorized = false

    private let defaults: UserDefaults
    private let registrar: GlobalShortcutRegistering
    private let activationHandler: @MainActor () -> Void
    private let inputMonitoringPermission: () -> Bool
    private var customRegistration: GlobalShortcutRegistration?
    private var globalEventMonitor: Any?
    private var doubleControlDetector = DoubleControlDetector()

    init(
        defaults: UserDefaults = .standard,
        registrar: GlobalShortcutRegistering? = nil,
        activationHandler: (@MainActor () -> Void)? = nil,
        inputMonitoringPermission: @escaping () -> Bool = CGPreflightListenEventAccess
    ) {
        self.defaults = defaults
        self.registrar = registrar ?? CarbonShortcutRegistrar()
        self.activationHandler = activationHandler ?? TaskWindowActivator.showMainWindow
        self.inputMonitoringPermission = inputMonitoringPermission
        configuration = Self.loadConfiguration(from: defaults) ?? .default
    }

    func start() {
        _ = apply(configuration)
    }

    func stop() {
        deactivateCurrentShortcut()
        activeConfiguration = nil
    }

    @discardableResult
    func apply(_ candidate: GlobalShortcutConfiguration) -> Bool {
        refreshInputMonitoringPermission()

        switch candidate.mode {
        case .disabled:
            deactivateCurrentShortcut()
            configuration = candidate
            activeConfiguration = nil
            hasCustomShortcutRegistrationError = false
            persist(candidate)
            return true

        case .doubleControl:
            guard isInputMonitoringAuthorized else {
                configuration = candidate
                hasCustomShortcutRegistrationError = false
                return false
            }

            deactivateCurrentShortcut()
            installDoubleControlMonitor()
            configuration = candidate
            activeConfiguration = candidate
            hasCustomShortcutRegistrationError = false
            persist(candidate)
            return true

        case .custom:
            guard let shortcut = candidate.customShortcut,
                  let registration = registrar.register(shortcut, action: { [weak self] in
                      self?.activationHandler()
                  })
            else {
                hasCustomShortcutRegistrationError = true
                return false
            }

            deactivateCurrentShortcut()
            customRegistration = registration
            configuration = candidate
            activeConfiguration = candidate
            hasCustomShortcutRegistrationError = false
            persist(candidate)
            return true
        }
    }

    func refreshInputMonitoringPermission() {
        let wasAuthorized = isInputMonitoringAuthorized
        isInputMonitoringAuthorized = inputMonitoringPermission()
        guard !wasAuthorized,
              isInputMonitoringAuthorized,
              configuration.mode == .doubleControl,
              activeConfiguration == nil
        else { return }
        _ = apply(configuration)
    }

    func handleDoubleControlEvent(_ event: DoubleControlDetector.Event, timestamp: TimeInterval) {
        guard activeConfiguration?.mode == .doubleControl,
              doubleControlDetector.handle(event, at: timestamp)
        else { return }
        activationHandler()
    }

    private func deactivateCurrentShortcut() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        customRegistration?.unregister()
        customRegistration = nil
        doubleControlDetector = DoubleControlDetector()
    }

    private func installDoubleControlMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            let detectorEvent: DoubleControlDetector.Event
            switch event.type {
            case .flagsChanged where event.keyCode == 59 || event.keyCode == 62:
                detectorEvent = event.modifierFlags.contains(.control) ? .controlDown : .controlUp
            case .flagsChanged, .keyDown:
                detectorEvent = .otherKey
            default:
                return
            }

            Task { @MainActor [weak self] in
                self?.handleDoubleControlEvent(detectorEvent, timestamp: event.timestamp)
            }
        }
    }

    private func persist(_ configuration: GlobalShortcutConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func loadConfiguration(from defaults: UserDefaults) -> GlobalShortcutConfiguration? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(GlobalShortcutConfiguration.self, from: data)
    }
}

@MainActor
private final class CarbonShortcutRegistrar: GlobalShortcutRegistering {
    private var eventHandler: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1
    private var actions: [UInt32: @MainActor () -> Void] = [:]

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(
        _ shortcut: GlobalShortcutKeyCombination,
        action: @escaping @MainActor () -> Void
    ) -> GlobalShortcutRegistration? {
        let identifier = nextIdentifier
        nextIdentifier &+= 1
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(for: shortcut.modifiers),
            EventHotKeyID(signature: 0x5441534B, id: identifier),
            GetEventDispatcherTarget(),
            0,
            &hotKey
        )
        guard status == noErr, let hotKey else { return nil }

        actions[identifier] = action
        return CarbonShortcutRegistration { [weak self] in
            UnregisterEventHotKey(hotKey)
            self?.actions[identifier] = nil
        }
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        let registrar = Unmanaged<CarbonShortcutRegistrar>.fromOpaque(userData).takeUnretainedValue()
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, let action = registrar.actions[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }
        action()
        return noErr
    }

    private func carbonModifiers(for modifiers: Set<GlobalShortcutModifier>) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }
}

@MainActor
private final class CarbonShortcutRegistration: GlobalShortcutRegistration {
    private var unregisterAction: (() -> Void)?

    init(unregister: @escaping () -> Void) {
        unregisterAction = unregister
    }

    func unregister() {
        unregisterAction?()
        unregisterAction = nil
    }
}
