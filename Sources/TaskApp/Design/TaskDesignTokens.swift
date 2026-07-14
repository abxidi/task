import AppKit
import SwiftUI

enum TaskDesignTokens {
    // Surfaces (light calibration from UI spec)
    static let canvas = Color(hex: 0xF7F7F3)
    static let sidebar = Color(hex: 0xE9E9E4)
    static let panel = Color(hex: 0xFBFBF8)
    static let raised = Color(hex: 0xFFFFFF)
    static let settingsPanel = Color(hex: 0xF1F1EC)
    static let sheetFoot = Color(hex: 0xF5F5F1)

    // Text
    static let ink = Color(hex: 0x20231F)
    static let muted = Color(hex: 0x62665D)
    static let quiet = Color(hex: 0x8A8D84)

    // Lines / accent
    static let line = Color(hex: 0xDADBD3)
    static let lineStrong = Color(hex: 0xCFD0C7)
    static let acid = Color(hex: 0xD8FF5B)
    static let danger = Color(hex: 0xD73D43)
    static let success = Color(hex: 0x23856A)

    // Zone labels
    static let zoneActBG = Color(hex: 0xFFE7E7)
    static let zoneActFG = Color(hex: 0xBD2830)
    static let zonePlanBG = Color(hex: 0xEDF5DF)
    static let zonePlanFG = Color(hex: 0x5F7E34)
    static let zoneDelegateBG = Color(hex: 0xE8F4F1)
    static let zoneDelegateFG = Color(hex: 0x297963)
    static let zoneDeferBG = Color(hex: 0xEFEFEB)
    static let zoneDeferFG = Color(hex: 0x7A7E75)

    // Project palette
    static let projectCoral = Color(hex: 0xF07446)
    static let projectGreen = Color(hex: 0x269276)
    static let projectCobalt = Color(hex: 0x4778D9)
    static let projectMagenta = Color(hex: 0xC85D8C)
    static let projectPurple = Color(hex: 0x7B6FA8)
    static let projectGraphite = Color(hex: 0x555B54)

    static let panelRadius: CGFloat = 6
    static let controlRadius: CGFloat = 5
    static let markerSize: CGFloat = 24
    static let markerHoverSize: CGFloat = 26
    static let markerSelectedSize: CGFloat = 28
    static let plotInset: CGFloat = 24
    static let sidebarWidth: CGFloat = 205
    static let inspectorWidth: CGFloat = 292
    static let navRowHeight: CGFloat = 34
    static let metricHeight: CGFloat = 66

    static var pageTitleFont: Font {
        .system(size: 26, weight: .semibold)
    }

    static var sheetTitleFont: Font {
        .system(size: 30, weight: .semibold)
    }

    static var inspectorTitleFont: Font {
        .system(size: 18, weight: .semibold)
    }
}

enum TaskButtonStyle {
    case primary
    case secondary
}

struct TaskChromeButton: View {
    let title: String
    var systemImage: String? = nil
    var style: TaskButtonStyle = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .frame(minHeight: 31)
            .foregroundStyle(style == .primary ? TaskDesignTokens.acid : TaskDesignTokens.muted)
            .background(
                style == .primary ? TaskDesignTokens.ink : TaskDesignTokens.raised,
                in: RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskDesignTokens.controlRadius)
                    .stroke(style == .primary ? TaskDesignTokens.ink : TaskDesignTokens.lineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var primaryActionTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryActionTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TaskDesignTokens.quiet)
                Text(title)
                    .font(TaskDesignTokens.pageTitleFont)
                    .foregroundStyle(TaskDesignTokens.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            HStack(spacing: 7) {
                if let secondaryActionTitle, let secondaryAction {
                    TaskChromeButton(title: secondaryActionTitle, action: secondaryAction)
                }
                if let primaryActionTitle, let primaryAction {
                    TaskChromeButton(title: primaryActionTitle, systemImage: "plus", style: .primary, action: primaryAction)
                }
            }
        }
    }
}
