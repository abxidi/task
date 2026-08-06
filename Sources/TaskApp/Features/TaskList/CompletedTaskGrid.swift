import SwiftUI
import TaskPersistence

enum CompletedTaskSort: CaseIterable, Identifiable {
    case completionTime
    case creationTime

    var id: Self { self }

    var title: String {
        switch self {
        case .completionTime: "完成时间最新"
        case .creationTime: "创建时间最新"
        }
    }
}

enum CompletedTaskPresentation {
    static let showsLanes = false
    static let cardMinimumHeight: CGFloat = 124
    static let showsTitleStrikethrough = false

    static func matches(_ task: TaskItem, query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let searchableText = [task.title, task.details] + task.tags.map(\.name)
        return searchableText.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    static func sortsByCompletionTime(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.completedAt != rhs.completedAt {
            return (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
        }
        return sortsByCreationTime(lhs, rhs)
    }

    static func sortsByCreationTime(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct CompletedTaskGrid: View {
    let tasks: [TaskItem]
    @Binding var searchText: String
    @Binding var sort: CompletedTaskSort
    let onOpenTask: (TaskItem) -> Void
    let onToggleTask: (TaskItem) -> Void
    let onDeleteTask: (TaskItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if tasks.isEmpty {
                ContentUnavailableView(
                    searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "还没有已完成任务"
                        : "没有匹配的已完成任务",
                    systemImage: "checkmark.circle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(tasks, id: \.id) { task in
                            CompletedTaskCard(
                                task: task,
                                onOpen: { onOpenTask(task) },
                                onToggleCompletion: { onToggleTask(task) },
                                onDelete: { onDeleteTask(task) }
                            )
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
                }
                .taskSubtleScrollIndicators()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            TextField("搜索已完成任务", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .accessibilityLabel("搜索已完成任务")

            Spacer(minLength: 12)

            Menu {
                Picker("排序", selection: $sort) {
                    ForEach(CompletedTaskSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TaskDesignTokens.muted)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 31)
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                            .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    )
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("已完成任务排序：\(sort.title)")
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
    }
}

private struct CompletedTaskCard: View {
    let task: TaskItem
    let onOpen: () -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onToggleCompletion) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(TaskDesignTokens.success)
                }
                .buttonStyle(.plain)
                .help("标记为未完成")
                .accessibilityLabel("标记为未完成")

                Button(action: onOpen) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TaskDesignTokens.ink)
                        .lineLimit(2)
                        .strikethrough(CompletedTaskPresentation.showsTitleStrikethrough)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开任务：\(task.title)")

                PriorityMarkerView(
                    coordinate: .init(uncheckedUrgency: task.urgency, importance: task.importance),
                    title: task.title,
                    isSelected: false,
                    isCompact: true
                )
            }

            if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(task.details)
                    .font(.system(size: 10))
                    .foregroundStyle(TaskDesignTokens.muted)
                    .lineLimit(3)
            }

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags.sorted { $0.name < $1.name }.prefix(2), id: \.id) { tag in
                        Text(tag.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .foregroundStyle(TaskDesignTokens.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(TaskDesignTokens.sidebar, in: RoundedRectangle(cornerRadius: 3))
                    }
                    if task.tags.count > 2 {
                        Text("+\(task.tags.count - 2)")
                            .font(.system(size: 9))
                            .foregroundStyle(TaskDesignTokens.quiet)
                    }
                }
            }

            HStack {
                Text(completionDateText)
                Spacer(minLength: 6)
                Text("创建于 \(task.createdAt.formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.system(size: 9))
            .foregroundStyle(TaskDesignTokens.quiet)
            .padding(.top, 2)

            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(TaskDesignTokens.quiet)
                .help("删除任务")
                .accessibilityLabel("删除任务")
            }
            .frame(height: 24)
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: CompletedTaskPresentation.cardMinimumHeight,
            alignment: .topLeading
        )
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TaskDesignTokens.panelRadius)
                .stroke(TaskDesignTokens.line, lineWidth: 1)
        )
    }

    private var completionDateText: String {
        guard let completedAt = task.completedAt else { return "完成时间未知" }
        return "完成于 \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
