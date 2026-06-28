import SwiftUI

struct WorkflowSheetShell<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let systemImage: String
    var subtitle: String? = nil
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.title3.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Button {
                    onDismiss?()
                    dismiss()
                } label: {
                    Label(UIStrings.done, systemImage: "xmark")
                }
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18)
            .frame(height: CGFloat(UIOptimizationPresentation.workflowSheet.titlebarHeight))
            .background(.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WorkflowSheetSplitLayout<Primary: View, Secondary: View>: View {
    var primaryMinWidth: CGFloat = 560
    var secondaryWidth: CGFloat = CGFloat(UIOptimizationPresentation.workflowSheet.secondaryColumnWidth)
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let secondary: () -> Secondary

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            primary()
                .frame(minWidth: primaryMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
                .padding(.vertical, 14)

            secondary()
                .frame(width: secondaryWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

enum WorkflowSheetBannerStyle {
    case success
    case warning
    case error
    case info

    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .info:
            return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle"
        }
    }
}

struct WorkflowSheetInlineBanner: View {
    let message: String
    let style: WorkflowSheetBannerStyle

    var body: some View {
        Label(message, systemImage: style.systemImage)
            .font(.callout)
            .foregroundStyle(style.color)
            .textSelection(.enabled)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(style.color)
                    .frame(width: 3)
                    .clipShape(Capsule())
                    .padding(.vertical, 5)
            }
    }
}
