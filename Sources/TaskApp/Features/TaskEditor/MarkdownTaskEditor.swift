import SwiftData
import SwiftUI
import TaskPersistence

struct MarkdownTaskEditor: View {
    @ObservedObject var session: MarkdownDraftSession
    let task: () -> TaskItem?
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                TextEditor(text: $session.details)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(18)
                Divider()
                MarkdownPreview(markdown: session.details)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(TaskDesignTokens.panel)
        .alert("保存正文失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onExitCommand(perform: cancel)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(MarkdownCommand.allCases, id: \.self) { command in
                Button { apply(command) } label: { Image(systemName: icon(for: command)).frame(width: 24, height: 28) }
                    .buttonStyle(.plain).help(label(for: command)).accessibilityLabel(label(for: command))
            }
            Spacer()
        }
        .padding(.horizontal, 14).frame(height: 44).overlay(alignment: .bottom) { Divider() }
    }

    private var footer: some View {
        HStack {
            Text("字数：\(session.details.count)").font(.caption).foregroundStyle(TaskDesignTokens.quiet)
            Spacer()
            Button("取消", action: cancel)
            Button("确认", action: save).keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }.padding(.horizontal, 18).frame(height: 52).overlay(alignment: .top) { Divider() }
    }

    private func apply(_ command: MarkdownCommand) {
        guard command != .undo, command != .redo else { return }
        session.details = MarkdownFormatting.apply(command, to: session.details, selection: NSRange(location: session.details.utf16.count, length: 0)).text
    }
    private func save() { guard let item = task() else { return }; do { try session.save(using: TaskRepository(context: modelContext), for: item); onSave(session.details) } catch { errorMessage = error.localizedDescription } }
    private func cancel() { session.cancel(); onCancel() }
    private func icon(for command: MarkdownCommand) -> String { switch command { case .bold: "bold"; case .italic: "italic"; case .heading: "textformat.size"; case .unorderedList: "list.bullet"; case .orderedList: "list.number"; case .taskList: "checklist"; case .link: "link"; case .image: "photo"; case .table: "tablecells"; case .quote: "quote.opening"; case .strikethrough: "strikethrough"; case .undo: "arrow.uturn.backward"; case .redo: "arrow.uturn.forward" } }
    private func label(for command: MarkdownCommand) -> String { String(describing: command) }
}

private struct MarkdownPreview: View {
    let markdown: String
    var body: some View { ScrollView { Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)).frame(maxWidth: .infinity, alignment: .leading) } }
}

enum MarkdownEditorLayout { static let usesExplicitSave = true; static let paneCount = 2 }
