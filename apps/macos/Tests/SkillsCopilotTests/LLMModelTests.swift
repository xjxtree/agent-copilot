import Foundation
@testable import SkillsCopilot

struct LLMModelTests {
    func run() throws {
        try statusDecodesSnakeCasePayload()
        try statusDecodesRealServicePayload()
        try prepareResultDecodesEstimatePayload()
        try skillAnalysisPrepareDecodesFlexiblePayload()
        try promptPreviewDecodesV242Payload()
        try promptSendResultDecodesCopyOnlyAuditPayload()
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

    private func promptPreviewDecodesV242Payload() throws {
        let data = Data(
            """
            {
              "preview_id": "preview-1",
              "request_kind": "skill_analysis",
              "analysis_kind": "risk",
              "scope": "selected",
              "prompt_scope": "Selected skill risk review",
              "provider": "openai-compatible",
              "model": "gpt-5",
              "destination_host": "llm.example.com",
              "included_fields": [{"name":"skill.name","label":"Skill name"}, "findings.summary"],
              "excluded_fields": [{"name":"api_key","reason":"credential"}],
              "redaction": {
                "status": "redacted",
                "summary": "Secrets and local paths removed.",
                "redacted_fields": ["api_key"],
                "placeholders": ["<project-root>"]
              },
              "estimate": {
                "input_tokens": 600,
                "output_tokens": 300,
                "total_tokens": 900,
                "estimated_cost_usd": 0.012
              },
              "confirmation_required": true,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "draft_copy_only": true,
              "redacted_prompt_preview": "Analyze Beta without paths."
            }
            """.utf8
        )

        let preview = try JSONDecoder().decode(LLMPromptPreview.self, from: data)

        try expectEqual(preview.previewID, "preview-1", "Prompt preview should decode preview id.")
        try expectEqual(preview.analysisKind, .risk, "Prompt preview should decode skill analysis kind.")
        try expectEqual(preview.promptScope, "Selected skill risk review", "Prompt preview should decode prompt scope.")
        try expectEqual(preview.destinationHost, "llm.example.com", "Prompt preview should decode destination host.")
        try expectEqual(preview.includedFields.count, 2, "Prompt preview should decode flexible included fields.")
        try expectEqual(preview.excludedFields.first?.reason, "credential", "Prompt preview should decode excluded field reason.")
        try expectEqual(preview.redaction.redactedFields, ["api_key"], "Prompt preview should decode redaction fields.")
        try expectEqual(preview.estimate?.totalTokens, 900, "Prompt preview should decode token estimate.")
        try expectFalse(preview.rawPromptPersisted, "Prompt preview should keep raw prompt persistence false.")
        try expectFalse(preview.rawResponsePersisted, "Prompt preview should keep raw response persistence false.")
        try expectEqual(preview.promptPreview, "Analyze Beta without paths.", "Prompt preview should decode redacted prompt text.")
    }

    private func promptSendResultDecodesCopyOnlyAuditPayload() throws {
        let data = Data(
            """
            {
              "preview_id": "preview-1",
              "status": "succeeded",
              "message": "Done.",
              "output_text": "Read-only recommendation.",
              "draft_copy_only": true,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "write_back_allowed": false,
              "script_execution_allowed": false,
              "audit_metadata": {
                "request_id": "audit-42",
                "status": "succeeded",
                "provider": "openai-compatible",
                "model": "gpt-5",
                "destination_host": "llm.example.com",
                "redaction_applied": true,
                "raw_prompt_persisted": false,
                "raw_response_persisted": false,
                "input_tokens": 600,
                "output_tokens": 120
              }
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(LLMPromptSendResult.self, from: data)

        try expectEqual(result.success, true, "Prompt send should decode succeeded status.")
        try expectEqual(result.outputText, "Read-only recommendation.", "Prompt send should decode copy-only output.")
        try expectEqual(result.draftCopyOnly, true, "Prompt send should remain copy-only.")
        try expectFalse(result.rawPromptPersisted, "Prompt send should keep raw prompt persistence false.")
        try expectFalse(result.rawResponsePersisted, "Prompt send should keep raw response persistence false.")
        try expectFalse(result.writeBackAllowed, "Prompt send must not allow write-back.")
        try expectFalse(result.scriptExecutionAllowed, "Prompt send must not allow script execution.")
        try expectEqual(result.audit?.auditID, "audit-42", "Prompt send should decode audit metadata.")
    }

}
