import SwiftUI

extension DisplayText {
    static func stateColor(_ value: String, enabled: Bool) -> Color {
        switch statusKind(value, enabled: enabled) {
        case .enabled:
            return .green
        case .disabled:
            return .secondary
        case .broken:
            return .red
        case .missing:
            return .orange
        case .shadowed:
            return .purple
        case .unknown:
            return .secondary
        }
    }
}
