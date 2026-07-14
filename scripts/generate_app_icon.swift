import AppKit
import Foundation

private let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/TaskApp/Resources/Assets.xcassets/AppIcon.appiconset")

private let outputs: [(name: String, size: Int)] = [
    ("icon_16.png", 16),
    ("icon_16@2x.png", 32),
    ("icon_32.png", 32),
    ("icon_32@2x.png", 64),
    ("icon_64.png", 64),
    ("icon_128.png", 128),
    ("icon_128@2x.png", 256),
    ("icon_256.png", 256),
    ("icon_256@2x.png", 512),
    ("icon_512.png", 512),
    ("icon_512@2x.png", 1024),
    ("icon_1024.png", 1024),
]

private let graphite = NSColor(srgbRed: 32 / 255, green: 35 / 255, blue: 31 / 255, alpha: 1)
private let acid = NSColor(srgbRed: 216 / 255, green: 255 / 255, blue: 91 / 255, alpha: 1)

private func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func makeIcon(size: Int) throws -> Data {
    let dimension = CGFloat(size)
    let scale = dimension / 1024
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    bitmap.size = NSSize(width: dimension, height: dimension)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    graphite.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: dimension, height: dimension)).fill()

    let topBar = NSRect(
        x: 210 * scale,
        y: 628 * scale,
        width: 604 * scale,
        height: max(3, 150 * scale)
    )
    let stem = NSRect(
        x: 417 * scale,
        y: 238 * scale,
        width: max(3, 190 * scale),
        height: 480 * scale
    )
    roundedRect(topBar, radius: max(1, 30 * scale), color: acid)
    roundedRect(stem, radius: max(1, 30 * scale), color: acid)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

for output in outputs {
    let data = try makeIcon(size: output.size)
    try data.write(to: outputDirectory.appendingPathComponent(output.name), options: .atomic)
}
