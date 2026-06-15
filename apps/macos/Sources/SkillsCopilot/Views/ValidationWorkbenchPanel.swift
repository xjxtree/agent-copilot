import SwiftUI

struct ValidationWorkbenchPanel: View {
    private let snapshot = ValidationWorkbenchModel.canonicalSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            summary
            evidence
            blockerRows
            noActionNotice
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppAccessibilityID.validationWorkbench)
        .accessibilityLabel(UIStrings.validationWorkbenchTitle)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(UIStrings.validationWorkbenchTitle, systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Label(UIStrings.readOnlyPreview, systemImage: "lock.shield")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(UIStrings.validationWorkbenchBoundary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(summaryCards) { card in
                SummaryChip(title: card.title, value: card.value, systemImage: card.systemImage)
                    .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier(AppAccessibilityID.validationWorkbenchSummary)
        .accessibilityLabel(UIStrings.validationWorkbenchSummaryTitle)
    }

    private var evidence: some View {
        ValidationWorkbenchSectionCard(
            title: UIStrings.validationWorkbenchEvidenceTitle,
            explanation: snapshot.summary.summaryText,
            rows: evidenceRows,
            systemImage: "camera.viewfinder",
            accessibilityID: AppAccessibilityID.validationWorkbenchEvidence
        )
    }

    private var blockerRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.validationWorkbenchBlockersTitle, systemImage: "exclamationmark.triangle")
                .font(.headline)

            ForEach(blockerSections) { section in
                ValidationWorkbenchSectionCard(
                    title: section.title,
                    explanation: section.explanation,
                    rows: section.rows,
                    systemImage: sectionImage(section.section),
                    accessibilityID: "\(AppAccessibilityID.validationWorkbenchBlockerRow).\(section.id)"
                )
            }
        }
    }

    private var noActionNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(UIStrings.validationWorkbenchNoActions, systemImage: "nosign")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(snapshot.summary.safety.notes, id: \.self) { note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
    }

    private var summaryCards: [ValidationWorkbenchSummaryCard] {
        [
            ValidationWorkbenchSummaryCard(
                id: "canonical-blockers",
                title: UIStrings.validationWorkbenchCanonicalBlockers,
                value: "\(snapshot.summary.canonicalBlockerCount)",
                systemImage: "number"
            ),
            ValidationWorkbenchSummaryCard(
                id: "required-evidence",
                title: UIStrings.validationWorkbenchRequiredEvidence,
                value: "\(snapshot.summary.requiredEvidence.count)",
                systemImage: "camera.viewfinder"
            ),
            ValidationWorkbenchSummaryCard(
                id: "fixture-role",
                title: UIStrings.validationWorkbenchFixtureSmoke,
                value: snapshot.summary.fixtureSmokeIsSubstitute ? UIStrings.llmEnabled : UIStrings.validationWorkbenchSupportingOnly,
                systemImage: "shippingbox"
            ),
            ValidationWorkbenchSummaryCard(
                id: "actions",
                title: UIStrings.validationWorkbenchRunnableActions,
                value: snapshot.summary.safety.allUnsafeCapabilitiesBlocked ? "0" : UIStrings.unknown,
                systemImage: "nosign"
            ),
        ]
    }

    private var evidenceRows: [ValidationWorkbenchRow] {
        snapshot.sections.first { $0.section == .evidenceStandards }?.rows ?? []
    }

    private var blockerSections: [ValidationWorkbenchSectionModel] {
        snapshot.sections.filter { $0.section != .evidenceStandards }
    }

    private func sectionImage(_ section: ValidationWorkbenchSection) -> String {
        switch section {
        case .sessionWindow:
            return "macwindow.badge.plus"
        case .permissions:
            return "record.circle"
        case .bundleFreshness:
            return "app.badge.checkmark"
        case .screenshotQuality:
            return "photo.badge.exclamationmark"
        case .computerUseToolLayer:
            return "wrench.adjustable"
        case .evidenceStandards:
            return "camera.viewfinder"
        }
    }
}

private struct ValidationWorkbenchSectionCard: View {
    let title: String
    let explanation: String
    let rows: [ValidationWorkbenchRow]
    let systemImage: String
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            ForEach(rows) { row in
                ValidationWorkbenchRowView(row: row)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveMaterialSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
    }
}

private struct ValidationWorkbenchRowView: View {
    let row: ValidationWorkbenchRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(row.title, systemImage: statusImage)
                    .font(.subheadline.bold())
                    .foregroundStyle(statusColor)
                Spacer(minLength: 8)
                if let code = row.blockerCode {
                    Text(code.rawValue)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.36), in: Capsule())
                        .textSelection(.enabled)
                }
            }

            Text(row.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 4) {
                Text(UIStrings.validationWorkbenchNextAction)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(row.nextAction)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            Text(row.evidenceRequirement)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(AppAccessibilityID.validationWorkbenchBlockerRow).\(row.id)")
    }

    private var statusImage: String {
        switch row.status {
        case .blocked:
            return "exclamationmark.octagon"
        case .required:
            return "checklist"
        case .supporting:
            return "info.circle"
        }
    }

    private var statusColor: Color {
        switch row.severity {
        case .blocker:
            return .orange
        case .warning:
            return .secondary
        case .info:
            return .secondary
        }
    }
}

private struct ValidationWorkbenchSummaryCard: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}
