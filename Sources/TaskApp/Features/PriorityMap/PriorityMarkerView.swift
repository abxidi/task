import SwiftUI
import TaskDomain

struct PriorityMarkerView: View {
    let coordinate: PriorityCoordinate
    let title: String
    let isSelected: Bool
    var isCompact: Bool = false

    var body: some View {
        let style = try! UrgencyPalette.style(for: coordinate.urgency)
        let size: CGFloat = {
            if isCompact { return 22 }
            return isSelected ? TaskDesignTokens.markerSelectedSize : TaskDesignTokens.markerSize
        }()

        Text(signedImportance)
            .font(.system(size: isCompact ? 8 : 10, weight: .heavy, design: .rounded))
            .foregroundStyle(style.usesDarkText ? Color(hex: 0x241F1A) : .white)
            .frame(width: size, height: size)
            .background(Color(hex: style.hex), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.18), radius: isSelected ? 6 : 4, y: 3)
            .overlay {
                if isSelected && !isCompact {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(TaskDesignTokens.acid, lineWidth: 3)
                        .padding(-3)
                }
            }
            .accessibilityLabel("\(title)，紧急度 \(signed(coordinate.urgency))，重要度 \(signed(coordinate.importance))，\(coordinate.quadrant.accessibilityName)")
            .help("\(title)\n紧急度 \(signed(coordinate.urgency)) · 重要度 \(signed(coordinate.importance))")
    }

    private var signedImportance: String {
        signed(coordinate.importance)
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

extension PriorityQuadrant {
    var accessibilityName: String {
        switch self {
        case .actNow: "立即处理"
        case .plan: "重点规划"
        case .delegate: "适当委派"
        case .defer: "稍后处理"
        case .undecided: "待判断"
        }
    }

    var displayName: String { accessibilityName }
}
