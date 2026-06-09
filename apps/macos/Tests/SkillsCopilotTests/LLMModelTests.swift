import Foundation
@testable import SkillsCopilot

struct LLMModelTests {
    func run() throws {
        try statusDecodesSnakeCasePayload()
        try statusDecodesRealServicePayload()
        try prepareResultDecodesEstimatePayload()
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
}
