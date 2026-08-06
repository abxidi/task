enum AppRoute: String, CaseIterable, Identifiable {
    case priorityMap
    case taskList
    case focusPool
    case projectBoard
    case insights
    case settings

    var id: Self { self }

    static let workbenchNavigation: [Self] = [
        .focusPool,
        .taskList,
        .priorityMap,
        .projectBoard,
        .insights
    ]

    var sidebarTitle: String {
        switch self {
        case .priorityMap: "分布地图"
        case .taskList: "任务列表"
        case .focusPool: "正在做"
        case .projectBoard: "项目看板"
        case .insights: "数据洞察"
        case .settings: "设置"
        }
    }

    var sidebarSymbol: String {
        switch self {
        case .priorityMap: "square.grid.3x3"
        case .taskList: "checkmark.circle"
        case .focusPool: "scope"
        case .projectBoard: "rectangle.3.group"
        case .insights: "chart.xyaxis.line"
        case .settings: "gearshape"
        }
    }
}
