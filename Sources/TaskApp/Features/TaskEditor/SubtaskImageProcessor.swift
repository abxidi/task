import AppKit
import Foundation

enum SubtaskImageProcessingLimits {
    static let maximumImageDimension: CGFloat = 1_600
    static let thumbnailDimension: CGFloat = 240
    static let maximumImageDataBytes = 2_000_000
}

struct ProcessedSubtaskImage {
    let imageData: Data
    let thumbnailData: Data
}

enum SubtaskImageProcessor {
    static func process(_ image: NSImage) throws -> ProcessedSubtaskImage {
        let imageData = try encodedImage(
            image,
            maximumDimension: SubtaskImageProcessingLimits.maximumImageDimension,
            maximumBytes: SubtaskImageProcessingLimits.maximumImageDataBytes
        )
        let thumbnailData = try encodedImage(
            image,
            maximumDimension: SubtaskImageProcessingLimits.thumbnailDimension,
            maximumBytes: SubtaskImageProcessingLimits.maximumImageDataBytes
        )
        return ProcessedSubtaskImage(imageData: imageData, thumbnailData: thumbnailData)
    }

    private static func encodedImage(
        _ image: NSImage,
        maximumDimension: CGFloat,
        maximumBytes: Int
    ) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw SubtaskImageProcessingError.invalidImage
        }

        var targetSize = scaledSize(for: image.size, maximumDimension: maximumDimension)
        for _ in 0..<5 {
            guard let bitmap = bitmap(for: image, size: targetSize) else {
                throw SubtaskImageProcessingError.invalidImage
            }
            for compression in [0.82, 0.68, 0.54, 0.40] {
                guard let data = bitmap.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: compression]
                ) else {
                    continue
                }
                if data.count <= maximumBytes {
                    return data
                }
            }
            targetSize = NSSize(width: max(1, targetSize.width * 0.8), height: max(1, targetSize.height * 0.8))
        }
        throw SubtaskImageProcessingError.imageTooLarge
    }

    private static func scaledSize(for size: NSSize, maximumDimension: CGFloat) -> NSSize {
        let largestDimension = max(size.width, size.height)
        guard largestDimension > maximumDimension else { return size }
        let scale = maximumDimension / largestDimension
        return NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    private static func bitmap(for image: NSImage, size: NSSize) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(size.width.rounded())),
            pixelsHigh: max(1, Int(size.height.rounded())),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: .alphaFirst,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}

enum SubtaskImageProcessingError: LocalizedError {
    case invalidImage
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取这张图片"
        case .imageTooLarge:
            "图片处理后仍然过大"
        }
    }
}
