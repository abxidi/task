import SwiftUI
import TaskDomain

struct PriorityCoordinateEditor: View {
    @Binding var coordinate: PriorityCoordinate

    var body: some View {
        GeometryReader { proxy in
            let coordinateSquare = PriorityMapLayout.coordinateSquare(in: proxy.size)
            let plot = coordinateSquare.insetBy(dx: TaskDesignTokens.plotInset, dy: TaskDesignTokens.plotInset)

            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(TaskDesignTokens.raised)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(TaskDesignTokens.lineStrong, lineWidth: 1))

                RoundedRectangle(cornerRadius: 7)
                    .stroke(TaskDesignTokens.lineStrong, lineWidth: 1)
                    .frame(width: coordinateSquare.width, height: coordinateSquare.height)
                    .position(x: coordinateSquare.midX, y: coordinateSquare.midY)

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
