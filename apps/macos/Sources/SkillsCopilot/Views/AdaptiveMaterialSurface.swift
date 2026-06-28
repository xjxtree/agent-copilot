import SwiftUI

struct AdaptiveMaterialSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: CGFloat(UIOptimizationPresentation.materialCornerRadius))
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                            : AnyShapeStyle(.regularMaterial)
                    )
            }
            .overlay {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: CGFloat(UIOptimizationPresentation.materialCornerRadius))
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
