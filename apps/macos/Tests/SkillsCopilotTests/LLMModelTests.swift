import Foundation
@testable import SkillsCopilot

struct LLMModelTests {
    func run() throws {
        try statusDecodesSnakeCasePayload()
        try statusDecodesRealServicePayload()
        try prepareResultDecodesEstimatePayload()
        try skillAnalysisPrepareDecodesFlexiblePayload()
    }

    private struct ServiceEnvelope<ResultPayload: Decodable>: Decodable {
        let id: String?
        let ok: Bool
        let result: ResultPayload?
    }

    private func statusDecodesSnakeCasePayload() throws {
        let data = Data(
            """
            {
              "enabled": true,
              "provider": "openai",
              "model": "gpt-5",
              "disabled_reason": null,
              "supported_actions": ["analyze", "recommend", "explain_conflict", "draft_frontmatter"]
            }
            """.utf8
        )

        let status = try JSONDecoder().decode(LLMStatus.self, from: data)

        try expectEqual(status.enabled, true, "LLM status should decode enabled.")
        try expectEqual(status.provider, "openai", "LLM status should decode provider.")
        try expectEqual(status.model, "gpt-5", "LLM status should decode model.")
        try expectEqual(status.supportedActions, LLMAction.allCases, "LLM status should decode supported actions.")
    }

    private func statusDecodesRealServicePayload() throws {
        let data = Data(
            """
            {
              "id": "fixture-llm-status",
              "ok": true,
              "result": {
                "enabled": false,
                "configured": false,
                "provider": null,
                "model": null,
                "reason": "LLM actions are disabled by default; no local provider is configured.",
                "single_request_token_limit": 8000,
                "monthly_budget_usd": 0.0,
                "credentials_storage": "none",
                "credential_persistence_allowed": false
              }
            }
            """.utf8
        )

        let envelope = try JSONDecoder().decode(ServiceEnvelope<LLMStatus>.self, from: data)
        guard let status = envelope.result else {
            throw NativeModelTestFailure(description: "LLM status service envelope should include a result.")
        }

        try expectEqual(envelope.ok, true, "LLM status service envelope should decode ok.")
        try expectEqual(status.enabled, false, "Real service LLM status should decode enabled.")
        try expectEqual(status.provider, nil, "Real service LLM status should decode provider.")
        try expectEqual(status.model, nil, "Real service LLM status should decode model.")
        try expectEqual(
            status.disabledReason,
            "LLM actions are disabled by default; no local provider is configured.",
            "Real service LLM status should decode reason as disabled reason."
        )
        try expectEqual(
            status.supportedActions,
            LLMAction.allCases,
            "Real service LLM status should default supported actions when omitted."
        )
    }

    private func prepareResultDecodesEstimatePayload() throws {
        let data = Data(
            """
            {
              "action": "draft_frontmatter",
              "allowed": true,
              "disabled_reason": null,
              "provider": "anthropic",
              "model": "claude-sonnet-4",
              "estimated_input_tokens": 320,
              "estimated_output_tokens": 180,
              "estimated_total_tokens": 500,
              "estimated_cost_usd": 0.0125,
              "requires_confirmation": true
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(LLMPrepareResult.self, from: data)

        try expectEqual(result.action, .draftFrontmatter, "LLM prepare result should decode action.")
        try expectEqual(result.enabled, true, "LLM prepare result should decode enabled.")
        try expectEqual(result.provider, "anthropic", "LLM prepare result should decode provider.")
        try expectEqual(result.model, "claude-sonnet-4", "LLM prepare result should decode model.")
        try expectEqual(result.estimate?.inputTokens, 320, "LLM prepare result should decode input tokens.")
        try expectEqual(result.estimate?.outputTokens, 180, "LLM prepare result should decode output tokens.")
        try expectEqual(result.estimate?.totalTokens, 500, "LLM prepare result should decode total tokens.")
        try expectEqual(result.estimate?.estimatedCostUSD, 0.0125, "LLM prepare result should decode estimated cost.")
        try expectEqual(result.confirmationRequired, true, "LLM prepare result should decode confirmation requirement.")
    }

    private func skillAnalysisPrepareDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "enabled": false,
              "reason": "Disabled by default.",
              "analysis_kind": "risk",
              "selected_skill_count": 2,
              "included_skills": [
                {"instance_id":"beta","name":"Beta","agent":"claude-code"},
                {"instance_id":"gamma","name":"Gamma","agent":"codex"}
              ],
              "excluded_count": 1,
              "missing_count": 0,
              "prompt_preview": "Review risk only.",
              "summary_draft": "Risk preview draft.",
              "write_back_enabled": false,
              "script_execution_enabled": false,
              "credential_storage_enabled": false,
              "confirmation_required": true
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(LLMSkillAnalysisPrepareResult.self, from: data)

        try expectEqual(result.enabled, false, "Skill analysis prepare should decode disabled default.")
        try expectEqual(result.disabledReason, "Disabled by default.", "Skill analysis prepare should decode reason fallback.")
        try expectEqual(result.analysisKind, .risk, "Skill analysis prepare should decode analysis kind.")
        try expectEqual(result.selectedSkillCount, 2, "Skill analysis prepare should decode selected skill count.")
        try expectEqual(result.includedSkills.map(\.name), ["Beta", "Gamma"], "Skill analysis prepare should decode included skill names.")
        try expectEqual(result.excludedCount, 1, "Skill analysis prepare should decode excluded count.")
        try expectEqual(result.promptDraft, "Review risk only.", "Skill analysis prepare should decode prompt preview fallback.")
        try expectEqual(result.summaryDraft, "Risk preview draft.", "Skill analysis prepare should decode summary draft.")
        try expectFalse(result.safety.writeBackEnabled, "Skill analysis prepare should keep write-back disabled.")
        try expectFalse(result.safety.scriptExecutionEnabled, "Skill analysis prepare should keep script execution disabled.")
        try expectFalse(result.safety.credentialStorageEnabled, "Skill analysis prepare should keep credential storage disabled.")
        try expectEqual(result.safety.confirmationRequired, true, "Skill analysis prepare should require confirmation.")
    }

}
