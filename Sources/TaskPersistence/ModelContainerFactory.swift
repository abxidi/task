import SwiftData

public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        // v3 is additive only: optional subtask focus fields preserve existing local task data.
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
