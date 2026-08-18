import Foundation

enum SubtaskAttachmentLayout {
    static let usesCompactCountButton = true
    static let usesAttachmentPopover = true
    static let usesInlineThumbnailStrip = false
    static let gridColumnCount = 3
    static let maximumVisibleRows = 2
    static let thumbnailWidth: CGFloat = 72
    static let thumbnailHeight: CGFloat = 54
    static let previewMaximumDimension: CGFloat = 320
    static let previewMinimumDimension: CGFloat = 120
    static let preservesImageAspectRatio = true

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

enum SubtaskAttachmentInput {
    static let supportsPaste = true
    static let supportsDrop = true
    static let supportsFileSelection = true
    static let primaryInputMethod = "paste"

    static func isAvailable(forTaskTitle title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
