// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Task",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TaskDomain", targets: ["TaskDomain"]),
        .library(name: "TaskPersistence", targets: ["TaskPersistence"]),
        .library(name: "TaskAI", targets: ["TaskAI"]),
        .library(name: "TaskNotifications", targets: ["TaskNotifications"]),
        .executable(name: "TaskApp", targets: ["TaskApp"]),
    ],
    targets: [
        .target(name: "TaskDomain"),
        .target(name: "TaskPersistence", dependencies: ["TaskDomain", "TaskAI"]),
        .target(name: "TaskAI", dependencies: ["TaskDomain"]),
        .target(name: "TaskNotifications", dependencies: ["TaskDomain"]),
        .executableTarget(
            name: "TaskApp",
            dependencies: ["TaskDomain", "TaskPersistence", "TaskAI", "TaskNotifications"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TaskDomainTests", dependencies: ["TaskDomain"]),
        .testTarget(name: "TaskPersistenceTests", dependencies: ["TaskPersistence", "TaskDomain", "TaskAI"]),
        .testTarget(name: "TaskAITests", dependencies: ["TaskAI", "TaskDomain"]),
        .testTarget(name: "TaskNotificationsTests", dependencies: ["TaskNotifications", "TaskDomain"]),
    ]
)
