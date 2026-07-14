import TaskDomain
import TaskPersistence

struct PriorityMapTaskStack: Identifiable {
    let coordinate: PriorityCoordinate
    let tasks: [TaskItem]

    var id: PriorityCoordinate { coordinate }
    var isStacked: Bool { tasks.count > 1 }
}

enum PriorityMapTaskStacking {
    static func stacks(for tasks: [TaskItem]) -> [PriorityMapTaskStack] {
        Dictionary(grouping: tasks) {
            PriorityCoordinate(uncheckedUrgency: $0.urgency, importance: $0.importance)
        }
        .map { coordinate, tasks in
            PriorityMapTaskStack(coordinate: coordinate, tasks: tasks)
        }
        .sorted {
            if $0.coordinate.importance != $1.coordinate.importance {
                return $0.coordinate.importance > $1.coordinate.importance
            }
            return $0.coordinate.urgency > $1.coordinate.urgency
        }
    }
}
