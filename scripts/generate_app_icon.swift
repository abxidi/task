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

    let nodeX = 220 * scale
    let nodeSize = max(3, 78 * scale)
    let nodeRadius = max(1, 13 * scale)
    let rowCenters = [704, 512, 320].map { CGFloat($0) * scale }

    for centerY in rowCenters {
        roundedRect(
            NSRect(x: nodeX, y: centerY - nodeSize / 2, width: nodeSize, height: nodeSize),
            radius: nodeRadius,
            color: acid
        )
    }

    let lineX = 362 * scale
    let lineWidth = 440 * scale
    let lineHeight = max(2, 48 * scale)
    for centerY in rowCenters.dropFirst() {
        roundedRect(
            NSRect(x: lineX, y: centerY - lineHeight / 2, width: lineWidth, height: lineHeight),
            radius: lineHeight / 2,
            color: acid
        )
    }

    let check = NSBezierPath()
    check.move(to: NSPoint(x: 232 * scale, y: 710 * scale))
    check.line(to: NSPoint(x: 258 * scale, y: 684 * scale))
    check.line(to: NSPoint(x: 307 * scale, y: 742 * scale))
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.lineWidth = max(1.5, 30 * scale)
    graphite.setStroke()
    check.stroke()

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
