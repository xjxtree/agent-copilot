import Foundation

@MainActor
extension SkillStore {
    var selectedTaskBenchmarkInput: String {
        let trimmedBenchmark = taskBenchmarkText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBenchmark.isEmpty {
            return trimmedBenchmark
        }
        let trimmedRouting = routingConfidenceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRouting.isEmpty {
            return trimmedRouting
        }
        return taskReadinessText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedCrossAgentReadinessInput: String {
        let trimmedCrossAgent = crossAgentReadinessText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCrossAgent.isEmpty {
            return trimmedCrossAgent
        }
        return selectedTaskBenchmarkInput
    }

    var selectedTaskCockpitInput: String {
        let trimmedCockpit = taskCockpitText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCockpit.isEmpty {
            return taskCockpitText
        }
        return selectedCrossAgentReadinessInput
    }

    func isDeletingTaskBenchmark(_ benchmark: TaskBenchmarkRecord) -> Bool {
        deletingTaskBenchmarkIDs.contains(benchmark.id)
    }

    var latestTraceImportRecord: AgentTraceImportRecord? {
        traceImportResult?.record ?? traceImportList.imports.first
    }

    func isDeletingTraceImport(_ record: AgentTraceImportRecord) -> Bool {
        deletingTraceImportIDs.contains(record.id)
    }

    var latestAgentSessionSkillReview: AgentSessionSkillReviewRecord? {
        agentSessionSkillReviewResult?.review ?? agentSessionSkillReviewList.reviews.first
    }

    func isDeletingAgentSessionSkillReview(_ record: AgentSessionSkillReviewRecord) -> Bool {
        deletingAgentSessionSkillReviewIDs.contains(record.id)
    }

    func scriptExecutionPreview(for skill: SkillRecord) -> ScriptExecutionPreview? {
        scriptExecutionPreviews[skill.id]
    }

    func isPreviewingScriptExecution(for skill: SkillRecord) -> Bool {
        previewingScriptExecutionSkillIDs.contains(skill.id)
    }
}
