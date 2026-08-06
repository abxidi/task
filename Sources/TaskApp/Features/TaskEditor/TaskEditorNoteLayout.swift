import AppKit

enum TaskEditorNoteLayout {
    static let font = NSFont.systemFont(ofSize: 15)
    static let minimumHeight: CGFloat = 32
    static let lineHeight: CGFloat = 20
    static let maximumVisibleLines = 5
    static let maximumHeight = minimumHeight + CGFloat(maximumVisibleLines - 1) * lineHeight

    static func height(forLineCount lineCount: Int) -> CGFloat {
        let visibleLines = min(max(1, lineCount), maximumVisibleLines)
        return minimumHeight + CGFloat(visibleLines - 1) * lineHeight
    }

    static func requiresInternalScrolling(forLineCount lineCount: Int) -> Bool {
        lineCount > maximumVisibleLines
    }
}

enum TaskEditorNoteLineCounter {
    static func count(in text: String, width: CGFloat) -> Int {
        let storage = NSTextStorage(
            string: text,
            attributes: [.font: TaskEditorNoteLayout.font]
        )
        let manager = NSLayoutManager()
        let container = NSTextContainer(
            size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)

        let glyphRange = manager.glyphRange(for: container)
        var lineCount = 0
        manager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            lineCount += 1
        }
        return max(1, lineCount)
    }
}
