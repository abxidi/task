import SwiftData
import SwiftUI
import TaskDomain
import TaskPersistence

struct TaskSettingsInspector: View {
    @Binding var draft: TaskDraft
    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("任务设置")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TaskDesignTokens.ink)
                Text("优先级位于其他管理属性上方。")
                    .font(.system(size: 8))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                PriorityCoordinateEditor(coordinate: $draft.coordinate)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.bottom, 8)

                settingRow("任务日期") {
                    Toggle("", isOn: Binding(
                        get: { draft.dueAt != nil },
                        set: { draft.dueAt = $0 ? (draft.dueAt ?? .now) : nil }
                    ))
                    .labelsHidden()
                    if draft.dueAt != nil {
                        DatePicker("", selection: Binding(
                            get: { draft.dueAt ?? .now },
                            set: { draft.dueAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    }
                }

                settingRow("提醒时间") {
                    Toggle("", isOn: Binding(
                        get: { draft.reminderAt != nil },
                        set: { draft.reminderAt = $0 ? (draft.reminderAt ?? .now) : nil }
                    ))
                    .labelsHidden()
                    if draft.reminderAt != nil {
                        DatePicker("", selection: Binding(
                            get: { draft.reminderAt ?? .now },
                            set: { draft.reminderAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                    }
                }

                settingRow("预计时长") {
                    TextField("分钟", value: $draft.estimatedMinutes, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 4))
                }

                settingRow("所属项目") {
                    Picker("", selection: $draft.projectID) {
                        Text("无项目").tag(Optional<UUID>.none)
                        ForEach(projects, id: \.id) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }

                if let project = projects.first(where: { $0.id == draft.projectID }) {
                    settingRow("看板列") {
                        Picker("", selection: $draft.boardColumnID) {
                            Text("未指定").tag(Optional<UUID>.none)
                            ForEach(project.boardColumns.sorted { $0.order < $1.order }, id: \.id) { column in
                                Text(column.name).tag(Optional(column.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 140)
                    }
                }

                settingRow("完成状态") {
                    Toggle("已完成", isOn: $draft.isCompleted)
                        .labelsHidden()
                    Text(draft.isCompleted ? "已完成" : "未完成")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 4))
                }

                settingRow("标签") {
                    TextField("逗号分隔", text: Binding(
                        get: { draft.tagNames.joined(separator: ", ") },
                        set: {
                            draft.tagNames = $0.split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 140)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 4))
                }

                Button("恢复默认设置") {
                    draft.coordinate = .init(uncheckedUrgency: 0, importance: 0)
                    draft.dueAt = nil
                    draft.reminderAt = nil
                    draft.estimatedMinutes = nil
                    draft.projectID = nil
                    draft.boardColumnID = nil
                    draft.isCompleted = false
                    draft.tagNames = []
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TaskDesignTokens.muted)
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(19)
        }
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(TaskDesignTokens.quiet)
            Spacer()
            content()
        }
        .frame(minHeight: 39)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: 0xDDDED6)).frame(height: 1)
        }
    }
}

struct PriorityCoordinateEditor: View {
    @Binding var coordinate: PriorityCoordinate

    var body: some View {
        GeometryReader { proxy in
            let coordinateSquare = PriorityMapLayout.coordinateSquare(in: proxy.size)
            let plot = coordinateSquare
                .insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(TaskDesignTokens.raised)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(TaskDesignTokens.lineStrong, lineWidth: 1))

                RoundedRectangle(cornerRadius: 7)
                    .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    .frame(width: coordinateSquare.width, height: coordinateSquare.height)
                    .position(x: coordinateSquare.midX, y: coordinateSquare.midY)

                // zone labels
                zone("重点规划", TaskDesignTokens.zonePlanFG, TaskDesignTokens.zonePlanBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .plan, in: coordinateSquare))
                zone("立即处理", TaskDesignTokens.zoneActFG, TaskDesignTokens.zoneActBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .actNow, in: coordinateSquare))
                zone("稍后处理", TaskDesignTokens.zoneDeferFG, TaskDesignTokens.zoneDeferBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .defer, in: coordinateSquare))
                zone("适当委派", TaskDesignTokens.zoneDelegateFG, TaskDesignTokens.zoneDelegateBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .delegate, in: coordinateSquare))

                Path { path in
                    path.move(to: CGPoint(x: plot.midX, y: plot.minY))
                    path.addLine(to: CGPoint(x: plot.midX, y: plot.maxY))
                    path.move(to: CGPoint(x: plot.minX, y: plot.midY))
                    path.addLine(to: CGPoint(x: plot.maxX, y: plot.midY))
                }
                .stroke(Color(hex: 0x858980), lineWidth: 1)

                PriorityMarkerView(coordinate: coordinate, title: "当前", isSelected: true)
                    .position(
                        x: plot.minX + CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.urgency)) * plot.width,
                        y: plot.maxY - CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.importance)) * plot.height
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = (value.location.x - plot.minX) / max(plot.width, 1)
                                let y = (plot.maxY - value.location.y) / max(plot.height, 1)
                                coordinate = .init(
                                    uncheckedUrgency: PriorityGridMath.value(at: Double(x)),
                                    importance: PriorityGridMath.value(at: Double(y))
                                )
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func zone(_ text: String, _ fg: Color, _ bg: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(bg, in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
    }
}
