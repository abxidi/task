import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

enum FocusStatePresentation {
    static func title(for state: TaskFocusState) -> String {
        switch state {
        case .focused: "专注"
        case .paused: "暂停"
        case .blocked: "阻塞"
        case .waiting: "等待"
        }
    }

    static func symbol(for state: TaskFocusState) -> String {
        switch state {
        case .focused: "scope"
        case .paused: "pause.circle"
        case .blocked: "exclamationmark.triangle"
        case .waiting: "hourglass"
        }
    }
}

struct FocusPoolScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.updatedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \FocusEntry.updatedAt, order: .reverse) private var entries: [FocusEntry]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 26)
                .padding(.top, 25)
                .padding(.bottom, 16)

            if entries.isEmpty {
                ContentUnavailableView(
                    "暂无正在做事项",
                    systemImage: "scope"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries, id: \.id) { entry in
                            FocusEntryRow(
                                entry: entry,
                                onRemove: { remove(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(TaskDesignTokens.canvas)
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("工作台")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Text("正在做")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(TaskDesignTokens.ink)
            }

            Spacer()

            Menu {
                if availableTasks.isEmpty {
                    Text("没有可加入的任务")
                } else {
                    ForEach(availableTasks, id: \.id) { task in
                        Button(task.title) {
                            add(task)
                        }
                    }
                }
            } label: {
                Label("加入任务", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .frame(minHeight: 30)
            }
            .menuStyle(.borderlessButton)
            .disabled(availableTasks.isEmpty)
            .help("将已有任务加入正在做")
        }
    }

    private var availableTasks: [TaskItem] {
        tasks.filter { $0.focusEntry == nil }
    }

    private func add(_ task: TaskItem) {
        do {
            _ = try FocusRepository(context: modelContext).upsert(task: task, state: .focused, note: "")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ entry: FocusEntry) {
        do {
            try FocusRepository(context: modelContext).remove(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FocusEntryRow: View {
    @Environment(\.modelContext) private var modelContext
    let entry: FocusEntry
    let onRemove: () -> Void
    @State private var state: TaskFocusState
    @State private var note: String
    @State private var errorMessage: String?

    init(entry: FocusEntry, onRemove: @escaping () -> Void) {
        self.entry = entry
        self.onRemove = onRemove
        _state = State(initialValue: entry.state)
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PriorityMarkerView(
                coordinate: .init(uncheckedUrgency: entry.task?.urgency ?? 0, importance: entry.task?.importance ?? 0),
                title: entry.task?.title ?? "任务",
                isSelected: false,
                isCompact: true
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: FocusStatePresentation.symbol(for: state))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.quiet)
                    Text(entry.task?.title ?? "已删除任务")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TaskDesignTokens.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .help("移出正在做")
                    .accessibilityLabel("移出正在做")
                }

                Picker("当前状态", selection: $state) {
                    ForEach(TaskFocusState.allCases, id: \.self) { option in
                        Text(FocusStatePresentation.title(for: option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .onChange(of: state) { _, _ in
                    persist()
                }

                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 12))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: note) { _, _ in
                        persist()
                    }
                    .accessibilityLabel("正在做备注")
            }
        }
        .padding(12)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
        .alert("无法保存正在做状态", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func persist() {
        guard let task = entry.task else { return }
        do {
            _ = try FocusRepository(context: modelContext).upsert(task: task, state: state, note: note)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
