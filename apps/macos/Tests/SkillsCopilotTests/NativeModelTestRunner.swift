import Foundation

struct NativeModelTestFailure: Error, CustomStringConvertible {
    let description: String
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) throws {
    if actual != expected {
        throw NativeModelTestFailure(description: "\(label): \(actual) != \(expected)")
    }
}

func expectFalse(_ value: Bool, _ label: String) throws {
    if value {
        throw NativeModelTestFailure(description: "\(label): expected false")
    }
}

func expectNil<T>(_ value: T?, _ label: String) throws {
    if let value {
        throw NativeModelTestFailure(description: "\(label): expected nil, got \(value)")
    }
}

func expectContains(_ value: String?, _ expected: String, _ label: String) throws {
    guard let value, value.contains(expected) else {
        throw NativeModelTestFailure(description: "\(label): expected \(String(describing: value)) to contain \(expected)")
    }
}

func runAsyncTest(_ body: @escaping () async throws -> Void) throws {
    var result: Result<Void, Error>?
    Task {
        do {
            try await body()
            result = .success(())
        } catch {
            result = .failure(error)
        }
    }

    while result == nil {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }

    try result?.get()
}

@_cdecl("SkillsCopilotRunNativeModelTests")
public func runNativeModelTests() {
    do {
        try FindingDisplayModelTests().run()
        try RuleTuningModelTests().run()
        try CleanupQueueModelTests().run()
        try CrossAgentComparisonModelTests().run()
        try CrossAgentReadinessModelTests().run()
        try StaleDriftDetectionModelTests().run()
        try LocalKnowledgeIndexModelTests().run()
        try SimilarSkillGroupingModelTests().run()
        try CapabilityTaxonomyModelTests().run()
        try WorkspaceReadinessModelTests().run()
        try RemediationPlanModelTests().run()
        try RemediationPreviewDraftsModelTests().run()
        try RemediationImpactPreviewModelTests().run()
        try AIProviderModelTests().run()
        try LLMModelTests().run()
        try ScriptExecutionModelTests().run()
        try ToolGlobalModelTests().run()
        try AgentConfigTimelineModelTests().run()
        try LocalizationModelTests().run()
        try SkillListModelTests().run()
        try runAsyncTest {
            try await SkillStoreTests().run()
        }
        fputs("SkillsCopilotTests: native list/store model checks passed\n", stderr)
    } catch {
        fputs("SkillsCopilotTests: \(error)\n", stderr)
        exit(1)
    }
}
