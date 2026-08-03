import SwiftData

public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        // v2 is additive only: optional startAt and new owned attachment/focus entities.
        // SwiftData can apply its lightweight migration without removing existing task data.
        let schema = Schema([
            TaskItem.self,
            Subtask.self,
            SubtaskAttachment.self,
            FocusEntry.self,
            Project.self,
            BoardColumn.self,
            Tag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
