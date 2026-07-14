import AppKit
import SwiftUI

enum PriorityMapFocusStyle {
    static let usesSystemFocusRing = false
}

struct PriorityMapKeyboardFocusView: NSViewRepresentable {
    let focusRequest: Int
    let onMove: (MoveCommandDirection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(focusRequest: focusRequest)
    }

    func makeNSView(context: Context) -> PriorityMapKeyView {
        PriorityMapKeyView(onMove: onMove)
    }

    func updateNSView(_ view: PriorityMapKeyView, context: Context) {
        view.onMove = onMove
        guard context.coordinator.focusRequest != focusRequest else { return }
        context.coordinator.focusRequest = focusRequest
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }

    final class Coordinator {
        var focusRequest: Int

        init(focusRequest: Int) {
            self.focusRequest = focusRequest
        }
    }
}

final class PriorityMapKeyView: NSView {
    var onMove: (MoveCommandDirection) -> Void

    init(onMove: @escaping (MoveCommandDirection) -> Void) {
        self.onMove = onMove
        super.init(frame: .zero)
        focusRingType = PriorityMapFocusStyle.usesSystemFocusRing ? .default : .none
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard let direction = Self.direction(for: event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        onMove(direction)
    }

    private static func direction(for keyCode: UInt16) -> MoveCommandDirection? {
        switch keyCode {
        case 123: .left
        case 124: .right
        case 125: .down
        case 126: .up
        default: nil
        }
    }
}
