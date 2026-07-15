import SwiftUI
import TaskDomain
import TaskPersistence

enum PriorityMapLayout {
    static let zoneLabelBand: CGFloat = 30

    static func coordinateSquare(in canvasSize: CGSize) -> CGRect {
        let availableHeight = max(0, canvasSize.height - zoneLabelBand * 2)
        let side = min(canvasSize.width, availableHeight)
        return CGRect(
            x: (canvasSize.width - side) / 2,
            y: zoneLabelBand + (availableHeight - side) / 2,
            width: side,
            height: side
        )
    }

    static func zoneLabelPosition(for quadrant: PriorityQuadrant, in square: CGRect) -> CGPoint {
        let horizontalInset: CGFloat = 36
        switch quadrant {
        case .plan:
            return CGPoint(x: square.minX + horizontalInset, y: square.minY - zoneLabelBand / 2)
        case .actNow:
            return CGPoint(x: square.maxX - horizontalInset, y: square.minY - zoneLabelBand / 2)
        case .defer:
            return CGPoint(x: square.minX + horizontalInset, y: square.maxY + zoneLabelBand / 2)
        case .delegate:
            return CGPoint(x: square.maxX - horizontalInset, y: square.maxY + zoneLabelBand / 2)
        case .undecided:
            return CGPoint(x: square.midX, y: square.midY)
        }
    }
}

struct PriorityMapView: View {
    let tasks: [TaskItem]
    @Binding var selection: TaskItem?
    let onMove: (TaskItem, PriorityCoordinate) -> Void
    var onInteraction: () -> Void = {}
    var showSelectionLabel: Bool = true
    @State private var expandedStack: PriorityMapTaskStack?

    var body: some View {
        GeometryReader { proxy in
            let coordinateSquare = PriorityMapLayout.coordinateSquare(in: proxy.size)
            let plot = coordinateSquare
                .insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(TaskDesignTokens.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 7)
                    .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    .frame(width: coordinateSquare.width, height: coordinateSquare.height)
                    .position(x: coordinateSquare.midX, y: coordinateSquare.midY)

                PriorityGridShape(plot: plot)
                    .stroke(Color(hex: 0xE9EAE4), lineWidth: 0.5)

                // Center axes
                Path { path in
                    path.move(to: CGPoint(x: plot.midX, y: plot.minY))
                    path.addLine(to: CGPoint(x: plot.midX, y: plot.maxY))
                    path.move(to: CGPoint(x: plot.minX, y: plot.midY))
                    path.addLine(to: CGPoint(x: plot.maxX, y: plot.midY))
                }
                .stroke(Color(hex: 0x858980), lineWidth: 1)

                zoneLabel("重点规划", color: TaskDesignTokens.zonePlanFG, bg: TaskDesignTokens.zonePlanBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .plan, in: coordinateSquare))
                zoneLabel("立即处理", color: TaskDesignTokens.zoneActFG, bg: TaskDesignTokens.zoneActBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .actNow, in: coordinateSquare))
                zoneLabel("稍后处理", color: TaskDesignTokens.zoneDeferFG, bg: TaskDesignTokens.zoneDeferBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .defer, in: coordinateSquare))
                zoneLabel("适当委派", color: TaskDesignTokens.zoneDelegateFG, bg: TaskDesignTokens.zoneDelegateBG)
                    .position(PriorityMapLayout.zoneLabelPosition(for: .delegate, in: coordinateSquare))

                Text("紧急度 −3 → +3")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .position(x: coordinateSquare.midX, y: proxy.size.height - 6)

                Text("重要度 −3 → +3")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .rotationEffect(.degrees(-90))
                    .position(x: max(8, coordinateSquare.minX - 14), y: coordinateSquare.midY)

                ForEach(PriorityMapTaskStacking.stacks(for: tasks)) { stack in
                    stackMarker(stack, plot: plot)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func zoneLabel(_ text: String, color: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(bg, in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stackMarker(_ stack: PriorityMapTaskStack, plot: CGRect) -> some View {
        let selectedTask = stack.tasks.first { $0.id == selection?.id }

        if stack.isStacked {
            Button {
                expandedStack = stack
                onInteraction()
            } label: {
                ZStack {
                    PriorityStackMarkerView(
                        coordinate: stack.coordinate,
                        count: stack.tasks.count,
                        isSelected: selectedTask != nil
                    )
                    if let selectedTask, showSelectionLabel {
                        selectionLabel(for: selectedTask, coordinate: stack.coordinate)
                            .offset(x: stack.coordinate.urgency >= 2 ? -96 : 96, y: -30)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: Binding(
                    get: { expandedStack?.id == stack.id },
                    set: { if !$0 { expandedStack = nil } }
                ),
                arrowEdge: .top
            ) {
                PriorityMapStackPopover(tasks: stack.tasks) { task in
                    selection = task
                    expandedStack = nil
                    onInteraction()
                }
            }
            .position(point(for: stack.coordinate, in: plot))
        } else if let task = stack.tasks.first {
            let isSelected = selection?.id == task.id
            ZStack {
                PriorityMarkerView(coordinate: stack.coordinate, title: task.title, isSelected: isSelected)
                if isSelected && showSelectionLabel {
                    selectionLabel(for: task, coordinate: stack.coordinate)
                        .offset(x: stack.coordinate.urgency >= 2 ? -96 : 96, y: -28)
                }
            }
            .position(point(for: stack.coordinate, in: plot))
            .gesture(dragGesture(for: task, plot: plot))
            .onTapGesture {
                selection = task
                onInteraction()
            }
        }
    }

    private func selectionLabel(for task: TaskItem, coordinate: PriorityCoordinate) -> some View {
        HStack(spacing: 8) {
            Text(task.title)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
            Text("\(signed(coordinate.urgency)) / \(signed(coordinate.importance))")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(TaskDesignTokens.quiet)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TaskDesignTokens.raised, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(TaskDesignTokens.lineStrong, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .frame(minWidth: 160, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func point(for coordinate: PriorityCoordinate, in plot: CGRect) -> CGPoint {
        CGPoint(
            x: plot.minX + CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.urgency)) * plot.width,
            y: plot.maxY - CGFloat(PriorityGridMath.normalizedPosition(for: coordinate.importance)) * plot.height
        )
    }

    private func dragGesture(for task: TaskItem, plot: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onInteraction()
                selection = task
                let x = (value.location.x - plot.minX) / max(plot.width, 1)
                let y = (plot.maxY - value.location.y) / max(plot.height, 1)
                onMove(task, .init(
                    uncheckedUrgency: PriorityGridMath.value(at: Double(x)),
                    importance: PriorityGridMath.value(at: Double(y))
                ))
            }
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct PriorityMapStackPopover: View {
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("此点位的任务")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TaskDesignTokens.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            ForEach(tasks) { task in
                Button {
                    onSelect(task)
                } label: {
                    HStack(spacing: 9) {
                        PriorityMarkerView(
                            coordinate: PriorityCoordinate(uncheckedUrgency: task.urgency, importance: task.importance),
                            title: task.title,
                            isSelected: false,
                            isCompact: true
                        )
                        Text(task.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(TaskDesignTokens.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let dueAt = task.dueAt {
                            Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 9))
                                .foregroundStyle(TaskDesignTokens.quiet)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 250)
        .background(TaskDesignTokens.panel)
    }
}

private struct PriorityGridShape: Shape {
    let plot: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for value in -3...3 where value != 0 {
            let position = PriorityGridMath.normalizedPosition(for: value)
            let x = plot.minX + CGFloat(position) * plot.width
            let y = plot.maxY - CGFloat(position) * plot.height
            path.move(to: CGPoint(x: x, y: plot.minY))
            path.addLine(to: CGPoint(x: x, y: plot.maxY))
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        return path
    }
}
