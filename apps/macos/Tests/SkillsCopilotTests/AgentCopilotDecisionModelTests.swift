@testable import SkillsCopilot

struct AgentCopilotDecisionModelTests {
    func run() throws {
        try decisionsSortByPriorityImpactEvidenceAndStableID()
        try evidenceRefsDropBlankValues()
    }

    private func decisionsSortByPriorityImpactEvidenceAndStableID() throws {
        let decisions = AgentCopilotDecisionModel.sorted([
            item(id: "watch", priority: .watch, impactScore: 999, evidenceRefs: ["cleanup.queue.items:0"]),
            item(id: "high-low-impact", priority: .high, impactScore: 1, evidenceRefs: ["provider.calls:4"]),
            item(id: "critical", priority: .critical, impactScore: 1, evidenceRefs: ["health.needs_triage:1"]),
            item(id: "high-more-evidence-b", priority: .high, impactScore: 10, evidenceRefs: ["a", "b"]),
            item(id: "high-more-evidence-a", priority: .high, impactScore: 10, evidenceRefs: ["a", "b"]),
            item(id: "high-less-evidence", priority: .high, impactScore: 10, evidenceRefs: ["a"]),
        ])

        try expectEqual(
            decisions.map(\.id),
            ["critical", "high-more-evidence-a", "high-more-evidence-b", "high-less-evidence", "high-low-impact", "watch"],
            "Agent Copilot decisions should sort by risk priority, impact, evidence density, then stable id."
        )
    }

    private func evidenceRefsDropBlankValues() throws {
        try expectEqual(
            AgentCopilotDecisionModel.refs(" health.needs_triage:3 ", nil, "", "   ", "task.evidence_refs:5"),
            ["health.needs_triage:3", "task.evidence_refs:5"],
            "Decision evidence refs should drop blank values and trim whitespace."
        )
    }

    private func item(
        id: String,
        priority: AgentCopilotDecisionPriority,
        impactScore: Int,
        evidenceRefs: [String]
    ) -> AgentCopilotDecisionItem {
        AgentCopilotDecisionItem(
            id: id,
            title: id,
            detail: id,
            status: id,
            systemImage: "circle",
            priority: priority,
            impactScore: impactScore,
            evidenceRefs: evidenceRefs,
            target: .review
        )
    }
}
