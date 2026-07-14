import SwiftUI

/// The compact brand mark used in the app chrome.
///
/// Its geometry intentionally mirrors `scripts/generate_app_icon.swift` so the
/// sidebar mark and the installed macOS icon remain visually identical.
struct TaskLogoMark: View {
    var size: CGFloat = 28

    private let graphite = Color(hex: 0x20231F)
    private let acid = Color(hex: 0xD8FF5B)

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 1024

            let topBar = CGRect(
                x: 210 * scale,
                y: 246 * scale,
                width: 604 * scale,
                height: 150 * scale
            )
            let stem = CGRect(
                x: 417 * scale,
                y: 306 * scale,
                width: 190 * scale,
                height: 480 * scale
            )
            let radius = max(1, 30 * scale)

            context.fill(
                Path(roundedRect: topBar, cornerRadius: radius),
                with: .color(acid)
            )
            context.fill(
                Path(roundedRect: stem, cornerRadius: radius),
                with: .color(acid)
            )
        }
        .frame(width: size, height: size)
        .background(graphite, in: RoundedRectangle(cornerRadius: size * 0.25))
        .accessibilityHidden(true)
    }
}
