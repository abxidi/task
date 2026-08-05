import Foundation
import SwiftUI

enum SubtaskReorderPresentation {
    static let insertionIndicatorHeight: CGFloat = 2
    static let insertionIndicatorUsesSystemBlue = true
}

enum SubtaskReorderInsertionLocation: Equatable {
    case before(UUID)
    case after(UUID)
}

struct SubtaskReorderInsertionIndicator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .systemBlue))
            .frame(maxWidth: .infinity)
            .frame(height: SubtaskReorderPresentation.insertionIndicatorHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
