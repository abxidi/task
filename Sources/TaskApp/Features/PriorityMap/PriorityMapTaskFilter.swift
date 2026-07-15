import TaskPersistence

enum PriorityMapScope: String, CaseIterable {
    case all = "全部"
    case work = "工作"
    case personal = "个人"
}

enum PriorityMapTaskFilter {
    static func tasks(
        from tasks: [TaskItem],
        scope: PriorityMapScope,
        selectedTagNames: Set<String>
    ) -> [TaskItem] {
        tasks.filter { task in
            let matchesScope: Bool
            switch scope {
            case .all: matchesScope = true
            case .work: matchesScope = task.project != nil
            case .personal: matchesScope = task.project == nil
            }
            let matchesTags = selectedTagNames.isEmpty || task.tags.contains { selectedTagNames.contains($0.name) }
            return matchesScope && matchesTags
        }
    }
}
