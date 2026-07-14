import SwiftUI
import TaskDomain
import TaskPersistence

struct PriorityMapView: View {
    let tasks: [TaskItem]
    @Binding var selection: TaskItem?
    let onMove: (TaskItem, PriorityCoordinate) -> Void
    var showSelectionLabel: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plot = CGRect(origin: .zero, size: .init(width: side, height: side))
                .insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(TaskDesignTokens.raised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    )

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
                    .position(x: plot.minX + 36, y: plot.minY + 14)
                zoneLabel("立即处理", color: TaskDesignTokens.zoneActFG, bg: TaskDesignTokens.zoneActBG)
                    .position(x: plot.maxX - 36, y: plot.minY + 14)
                zoneLabel("稍后处理", color: TaskDesignTokens.zoneDeferFG, bg: TaskDesignTokens.zoneDeferBG)
                    .position(x: plot.minX + 36, y: plot.maxY - 14)
                zoneLabel("适当委派", color: TaskDesignTokens.zoneDelegateFG, bg: TaskDesignTokens.zoneDelegateBG)
                    .position(x: plot.maxX - 36, y: plot.maxY - 14)

                Text("紧急度 −3 → +3")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .position(x: plot.midX, y: side - 8)

                Text("重要度 −3 → +3")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                    .rotationEffect(.degrees(-90))
                    .position(x: 10, y: plot.midY)

                ForEach(tasks) { task in
                    let coordinate = PriorityCoordinate(uncheckedUrgency: task.urgency, importance: task.importance)
                    let isSelected = selection?.id == task.id
                    ZStack {
                        PriorityMarkerView(coordinate: coordinate, title: task.title, isSelected: isSelected)
                        if isSelected && showSelectionLabel {
                            selectionLabel(for: task, coordinate: coordinate)
                                .offset(x: coordinate.urgency >= 2 ? -96 : 96, y: -28)
                        }
                    }
                    .position(point(for: coordinate, in: plot))
                    .gesture(dragGesture(for: task, plot: plot))
                    .onTapGesture { selection = task }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(minWidth: 360, minHeight: 360)
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
