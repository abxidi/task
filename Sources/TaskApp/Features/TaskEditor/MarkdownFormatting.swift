import Foundation

enum MarkdownCommand: CaseIterable {
    case bold
    case italic
    case heading
    case unorderedList
    case orderedList
    case taskList
    case link
    case image
    case table
    case quote
    case strikethrough
    case undo
    case redo
}

struct MarkdownEdit: Equatable {
    let text: String
    let selection: NSRange
}

enum MarkdownFormatting {
    static func apply(_ command: MarkdownCommand, to text: String, selection: NSRange) -> MarkdownEdit {
        switch command {
        case .bold:
            return wrap(text, selection: selection, opening: "**", closing: "**")
        case .italic:
            return wrap(text, selection: selection, opening: "*", closing: "*")
        case .strikethrough:
            return wrap(text, selection: selection, opening: "~~", closing: "~~")
        case .heading:
            return prefixLines(text, selection: selection, prefix: "# ")
        case .unorderedList:
            return prefixLines(text, selection: selection, prefix: "- ")
        case .orderedList:
            return prefixLines(text, selection: selection, prefix: "1. ")
        case .taskList:
            return prefixLines(text, selection: selection, prefix: "- [ ] ")
        case .quote:
            return prefixLines(text, selection: selection, prefix: "> ")
        case .link:
            return wrap(text, selection: selection, opening: "[", closing: "](https://)")
        case .image:
            return insert("![alt](https://)", into: text, selection: selection, caretOffset: 2)
        case .table:
            return insert("| 标题 | 标题 |\n| --- | --- |\n| 内容 | 内容 |", into: text, selection: selection)
        case .undo, .redo:
            return MarkdownEdit(text: text, selection: selection)
        }
    }

    private static func wrap(_ text: String, selection: NSRange, opening: String, closing: String) -> MarkdownEdit {
        let range = clamped(selection, in: text)
        let source = text as NSString
        let chosen = source.substring(with: range)
        let replacement = opening + chosen + closing
        let result = source.replacingCharacters(in: range, with: replacement)
        return MarkdownEdit(
            text: result,
            selection: NSRange(location: range.location + (opening as NSString).length, length: range.length)
        )
    }

    private static func prefixLines(_ text: String, selection: NSRange, prefix: String) -> MarkdownEdit {
        let source = text as NSString
        let range = source.lineRange(for: clamped(selection, in: text))
        let selectedLines = source.substring(with: range)
        let replacement = selectedLines
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + $0 }
            .joined(separator: "\n")
        let result = source.replacingCharacters(in: range, with: replacement)
        return MarkdownEdit(text: result, selection: NSRange(location: range.location, length: (replacement as NSString).length))
    }

    private static func insert(_ replacement: String, into text: String, selection: NSRange, caretOffset: Int? = nil) -> MarkdownEdit {
        let range = clamped(selection, in: text)
        let source = text as NSString
        let result = source.replacingCharacters(in: range, with: replacement)
        let offset = caretOffset ?? (replacement as NSString).length
        return MarkdownEdit(text: result, selection: NSRange(location: range.location + offset, length: 0))
    }

    private static func clamped(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(max(range.length, 0), length - location))
    }
}
