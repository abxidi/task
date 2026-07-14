import SwiftUI
import TaskDomain

struct PriorityStackMarkerView: View {
    let coordinate: PriorityCoordinate
    let count: Int
    let isSelected: Bool

    var body: some View {
        let style = try! UrgencyPalette.style(for: coordinate.urgency)

        ZStack(alignment: .topTrailing) {
            stackLayer(style: style, offset: CGSize(width: 6, height: -TaskDesignTokens.stackMarkerRearYOffset))
            stackLayer(style: style, offset: CGSize(width: 3, height: -2))

            Text(signed(coordinate.importance))
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(style.usesDarkText ? Color(hex: 0x241F1A) : .white)
                .frame(width: TaskDesignTokens.markerSelectedSize, height: TaskDesignTokens.markerSelectedSize)
                .background(Color(hex: style.hex), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white, lineWidth: 2)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(TaskDesignTokens.acid, lineWidth: 3)
                            .padding(-3)
                    }
                }

            Text("\(count)")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(TaskDesignTokens.ink)
                .padding(.horizontal, count > 9 ? 3 : 0)
                .frame(minWidth: 16, minHeight: 16)
                .background(TaskDesignTokens.acid, in: Capsule())
                .overlay(Capsule().stroke(TaskDesignTokens.raised, lineWidth: 2))
                .offset(x: 6, y: -6)
        }
        .frame(width: 40, height: 36)
        .accessibilityLabel("\(count) 个任务，紧急度 \(signed(coordinate.urgency))，重要度 \(signed(coordinate.importance))")
        .accessibilityHint("点击展开此坐标的任务")
        .help("\(count) 个任务\n点击展开")
    }

    private func stackLayer(style: UrgencyStyle, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Color(hex: style.hex).opacity(0.5))
            .frame(width: TaskDesignTokens.markerSelectedSize, height: TaskDesignTokens.markerSelectedSize)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(TaskDesignTokens.raised, lineWidth: 2)
            }
            .offset(offset)
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
