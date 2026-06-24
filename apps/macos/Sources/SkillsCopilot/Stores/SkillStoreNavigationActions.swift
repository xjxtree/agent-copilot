import Foundation

@MainActor
extension SkillStore {
    func openCleanupQueueItem(_ item: CleanupQueueItem) {
        if let skillID = item.skillID, skills.contains(where: { $0.id == skillID }) {
            selectedSkillID = skillID
        }
        switch item.kind {
        case .finding, .integrity, .conflict:
            selectedDetailSection = .findings
        case .analysis:
            selectedDetailSection = .analysis
        case .unknown:
            selectedDetailSection = .overview
        }
    }

    func openGuidedCleanupSafeLink(
        _ link: GuidedCleanupSafeActionDeepLink,
        step: GuidedCleanupFlowStep? = nil
    ) async {
        guard !link.canApply else {
            errorMessage = UIStrings.text("guidedCleanup.safeLink.applyBlocked", "Guided cleanup links cannot apply changes. Use the existing preview and explicit confirmation flow.")
            return
        }

        if let instanceID = (link.instanceIDs.first ?? step?.skill?.instanceID),
           skills.contains(where: { $0.id == instanceID }) {
            selectedSkillID = instanceID
        }

        if let section = detailSection(forGuidedCleanupLink: link) {
            selectedDetailSection = section
            if section == .taskCockpit {
                selectedSidebarSelection = nil
            } else if section.isAgentWorkspaceSurface {
                selectedSidebarSelection = nil
            } else if DetailSection.primaryWorkCases.contains(section) {
                selectedSidebarSelection = .work(section)
            } else if let selectedSkillID {
                selectedSidebarSelection = .skill(selectedSkillID)
            }
        }

        switch link.trigger {
        case "selectDetailSection", "openSafeBatchPreviewPanel":
            return
        case "buildTaskCockpit":
            selectedSidebarSelection = nil
            await buildTaskCockpit()
        case "loadSkillLifecycleTimeline":
            selectedDetailSection = .analysis
            if let selectedSkillID {
                selectedSidebarSelection = .skill(selectedSkillID)
            }
            await loadSkillLifecycleTimeline()
        case "planRemediation":
            selectedDetailSection = .analysis
            await planRemediation()
        case "previewRemediationDrafts":
            selectedDetailSection = .analysis
            await previewRemediationDrafts()
        case "previewRemediationImpact":
            selectedDetailSection = .analysis
            await previewRemediationImpact()
        case "reviewRemediationBatch":
            selectedDetailSection = .analysis
            await reviewRemediationBatch()
        case "recordGuidedStep":
            await recordGuidedCleanupStep(step)
        default:
            errorMessage = UIStrings.text("guidedCleanup.safeLink.unsupported", "This guided cleanup link points to an unsupported safe entry.")
        }
    }

    private func detailSection(forGuidedCleanupLink link: GuidedCleanupSafeActionDeepLink) -> DetailSection? {
        if let detailSection = link.detailSection {
            if detailSection == "skillMap" {
                return .analysis
            }
            if detailSection == "validationWorkbench" {
                return .taskCockpit
            }
            if let section = DetailSection(rawValue: detailSection) {
                if section == .cleanup || section == .conflicts {
                    return .findings
                }
                return section
            }
        }
        switch link.method {
        case "cleanup.listQueue", "batch.previewSkillToggles":
            return .findings
        case "skill.lifecycleTimeline":
            return .analysis
        case "task.buildCockpit":
            return .taskCockpit
        case "cleanup.recordGuidedStep":
            return .guidedCleanup
        case "remediation.plan", "remediation.previewDrafts", "remediation.previewImpact", "remediation.batchReview":
            return .analysis
        default:
            return nil
        }
    }
}
