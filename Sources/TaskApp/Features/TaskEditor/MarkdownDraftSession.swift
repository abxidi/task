import SwiftUI
import TaskPersistence

@MainActor
final class MarkdownDraftSession: ObservableObject {
    @Published var details: String

    private var openingDetails: String

    init(details: String) {
        self.details = details
        openingDetails = details
    }

    var isDirty: Bool {
        details != openingDetails
    }

    func cancel() {
        details = openingDetails
    }

    func save(using repository: TaskRepository, for item: TaskItem) throws {
        try repository.updateDetails(item, details: details)
        openingDetails = details
    }
}
