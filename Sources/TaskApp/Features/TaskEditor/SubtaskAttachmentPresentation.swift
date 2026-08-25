import Foundation

enum SubtaskAttachmentLayout {
    static let usesCompactCountButton = true
    static let usesRoundedSquareCountBadge = true
    static let usesAttachmentPopover = true
    static let usesInlineThumbnailStrip = false
    static let countBadgeSize: CGFloat = 18
    static let countBadgeCornerRadius: CGFloat = 4
    static let gridColumnCount = 3
    static let maximumVisibleRows = 2
    static let thumbnailWidth: CGFloat = 72
    static let thumbnailHeight: CGFloat = 54

    static var visibleCapacity: Int {
        gridColumnCount * maximumVisibleRows
    }

    static func visibleCount(for total: Int) -> Int {
        min(max(0, total), visibleCapacity)
    }

    static func requiresInternalScrolling(for total: Int) -> Bool {
        total > visibleCapacity
    }
}

enum SubtaskImagePreviewLayout {
    static let minimumDimension: CGFloat = 240
    static let maximumDimension: CGFloat = 760
    static let preservesImageAspectRatio = true
    static let isCenteredInApplication = true
    static let dismissesOnOutsideTap = true

    static func panelSize(for availableSize: CGSize) -> CGSize {
        CGSize(
            width: min(maximumDimension + 80, max(520, availableSize.width - 96)),
            height: min(maximumDimension + 100, max(420, availableSize.height - 96))
        )
    }
}

enum SubtaskAttachmentInput {
    static let supportsPaste = true
    static let supportsDrop = true
    static let supportsFileSelection = true
    static let primaryInputMethod = "paste"

    static func isAvailable(forTaskTitle title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
