enum AppRoute: String, CaseIterable, Identifiable {
    case priorityMap
    case taskList
    case projectBoard
    case insights
    case settings

    var id: Self { self }
}
