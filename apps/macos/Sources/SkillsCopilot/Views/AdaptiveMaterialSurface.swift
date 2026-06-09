import SwiftUI

struct AdaptiveMaterialSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                            : AnyShapeStyle(.regularMaterial)
                    )
            }
            .overlay {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.separator, lineWidth: 1)
                }
            }
    }
}

extension View {
    func adaptiveMaterialSurface() -> some View {
        modifier(AdaptiveMaterialSurface())
    }
}
