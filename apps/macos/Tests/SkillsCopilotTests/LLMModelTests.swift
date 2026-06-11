import Foundation
@testable import SkillsCopilot

struct LLMModelTests {
    func run() throws {
        try statusDecodesSnakeCasePayload()
        try statusDecodesRealServicePayload()
        try prepareResultDecodesEstimatePayload()
        try skillAnalysisPrepareDecodesFlexiblePayload()
        try skillQualityScoreDecodesFlexiblePayload()
        try skillQualityScoreDecodesV243ServicePayload()
        try taskReadinessDecodesFlexiblePayload()
        try routingConfidenceDecodesFlexiblePayload()
        try taskBenchmarkDecodesFlexiblePayload()
        try promptPreviewDecodesV242Payload()
        try promptPreviewDecodesServiceArrayScopePayload()
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

    private func promptPreviewDecodesServiceArrayScopePayload() throws {
        let data = Data(
            """
            {
              "preview_id": "prompt-preview-quality",
              "status": "blocked",
              "allowed": false,
              "reason": "No enabled provider profile is configured; no provider request can be sent.",
              "action": "quality_score",
              "provider": null,
              "model": null,
              "destination_host": null,
              "prompt_scope": [
                "operation metadata",
                "deterministic quality score",
                "safety flags"
              ],
              "included_fields": ["skill id", "quality score"],
              "excluded_fields": ["raw skill body", "provider API key"],
              "redaction": {
                "status": "redacted-preview-confirmed-required",
                "redacted_fields": ["local paths"],
                "placeholders": ["$HOME", "<redacted>"]
              },
              "prompt_preview": "Quality score evidence with redacted local paths.",
              "estimated_input_tokens": 480,
              "estimated_output_tokens": 650,
              "estimated_total_tokens": 1130,
              "estimated_cost_usd": 0.0,
              "requires_confirmation": true,
              "draft_requires_user_copy": true,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false
            }
            """.utf8
        )

        let preview = try JSONDecoder().decode(LLMPromptPreview.self, from: data)

        try expectEqual(preview.previewID, "prompt-preview-quality", "Prompt preview should decode service preview id.")
        try expectEqual(preview.enabled, false, "Blocked preview should not be sendable.")
        try expectContains(preview.promptScope, "deterministic quality score", "Prompt scope should decode array labels.")
        try expectEqual(preview.includedFields.map(\.name), ["skill id", "quality score"], "Prompt preview should decode string field arrays.")
        try expectEqual(preview.estimate?.totalTokens, 1130, "Prompt preview should decode top-level token estimates.")
        try expectFalse(preview.rawPromptPersisted, "Prompt preview must not persist raw prompt.")
        try expectFalse(preview.rawResponsePersisted, "Prompt preview must not persist raw response.")
    }

    private func skillQualityScoreDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "instance_id": "beta",
              "quality_score": "82",
              "grade": "Good",
              "summary": "Metadata is clear, but permissions need sharper boundaries.",
              "component_scores": [
                {
                  "key": "metadata",
                  "label": "Metadata completeness",
                  "score": 90,
                  "max_score": 100,
                  "summary": "Name and description are present.",
                  "evidence": ["description present"]
                },
                {
                  "name": "Permission clarity",
                  "value": 68,
                  "status": "needs_review",
                  "reason": "Network intent is vague."
                }
              ],
              "evidence": [
                {"title":"Findings","detail":"One permission warning","source":"permissions.network-declared"},
                "No same-agent conflict"
              ],
              "risks": ["Network permission is undeclared."],
              "suggestions": ["Declare network needs explicitly."],
              "provider_request_sent": false,
              "write_back_allowed": false,
              "script_execution_allowed": false,
              "execution_actions_available": false,
              "config_mutation_allowed": false,
              "snapshot_created": false,
              "triage_mutation_allowed": false,
              "credential_accessed": false
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(SkillQualityScoreResult.self, from: data)

        try expectEqual(result.skillID, "beta", "Quality score should decode selected skill id.")
        try expectEqual(result.score, 82, "Quality score should decode string score.")
        try expectEqual(result.displayBand, "Good", "Quality score should prefer explicit grade.")
        try expectEqual(result.components.count, 2, "Quality score should decode component scores.")
        try expectEqual(result.components[1].label, "Permission clarity", "Quality components should tolerate name fallback.")
        try expectEqual(result.components[1].score, 68, "Quality components should decode value fallback.")
        try expectEqual(result.evidence.map(\.detail), ["One permission warning", "No same-agent conflict"], "Quality evidence should decode object and string forms.")
        try expectEqual(result.riskNotes, ["Network permission is undeclared."], "Quality score should decode risk notes.")
        try expectEqual(result.suggestedImprovements, ["Declare network needs explicitly."], "Quality score should decode suggestions.")
        try expectFalse(result.safety.providerRequestSent, "Quality score must report provider request as not sent for local scoring.")
        try expectFalse(result.safety.writeBackAllowed, "Quality score must not enable write-back.")
        try expectFalse(result.safety.scriptExecutionAllowed, "Quality score must not enable script execution.")
        try expectFalse(result.safety.configMutationAllowed, "Quality score must not enable config mutation.")
        try expectFalse(result.safety.credentialAccessed, "Quality score must not access credentials.")
    }

    private func skillQualityScoreDecodesV243ServicePayload() throws {
        let data = Data(
            """
            {
              "instance_id": "fixture-skill-id",
              "definition_id": "fixture-definition-id",
              "agent": "codex",
              "score": 78,
              "grade": "B",
              "band": "good",
              "components": [
                {
                  "id": "adapter_state",
                  "label": "Adapter state",
                  "score": 10,
                  "max_score": 15,
                  "summary": "Adapter diagnostic status is blocked.",
                  "evidence_refs": ["adapter_diagnostics:codex"]
                }
              ],
              "evidence_references": [
                {
                  "id": "adapter_diagnostics:codex",
                  "source_type": "adapter_diagnostics",
                  "source_id": "codex",
                  "label": "Codex adapter diagnostics: status=blocked",
                  "related_instance_id": "fixture-skill-id"
                }
              ],
              "suggested_improvements": [
                {
                  "priority": "medium",
                  "title": "Compare cross-agent overlap",
                  "detail": "Use read-only comparison before changing routing.",
                  "evidence_refs": ["analysis:fixture-analysis-id"]
                }
              ],
              "safety_flags": {
                "read_only": true,
                "provider_request_sent": false,
                "write_back_allowed": false,
                "script_execution_allowed": false,
                "config_mutation_allowed": false,
                "snapshot_created": false,
                "triage_mutation_allowed": false,
                "credential_accessed": false,
                "raw_secret_returned": false
              }
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(SkillQualityScoreResult.self, from: data)

        try expectEqual(result.skillID, "fixture-skill-id", "V2.43 payload should decode instance id.")
        try expectEqual(result.displayBand, "B", "V2.43 payload should prefer grade.")
        try expectEqual(result.components.first?.evidence, ["adapter_diagnostics:codex"], "V2.43 components should decode evidence refs.")
        try expectEqual(result.evidence.first?.detail, "Codex adapter diagnostics: status=blocked", "V2.43 evidence references should decode labels.")
        try expectEqual(result.evidence.first?.source, "codex", "V2.43 evidence references should decode source ids.")
        try expectEqual(result.suggestedImprovements, ["Use read-only comparison before changing routing."], "V2.43 suggestions should decode object details.")
        try expectFalse(result.safety.providerRequestSent, "V2.43 local score must not send provider requests.")
        try expectFalse(result.safety.configMutationAllowed, "V2.43 local score must not mutate config.")
        try expectFalse(result.safety.rawSecretReturned, "V2.43 local score must not return secrets.")
    }

    private func taskReadinessDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "task_text": "Summarize a local audit report.",
              "readiness_score": "76",
              "readiness_band": "Partial",
              "summary": "Beta can inspect catalog evidence but lacks report export wording.",
              "candidate_skills": [
                {"instance_id":"beta","name":"Beta","agent":"claude-code","score":76,"band":"Partial","rationale":"Closest local audit fit.","evidence":["description match"]},
                "Fallback skill"
              ],
              "missing_capabilities": ["Report export examples"],
              "blockers": ["No configured provider for optional explanation"],
              "risk_notes": ["Permission declaration is incomplete."],
              "evidence": [
                {"title":"Metadata","detail":"Description mentions local audit.","source":"catalog"},
                "No same-agent conflict"
              ],
              "safety_flags": {
                "provider_request_sent": false,
                "write_back_allowed": false,
                "write_actions_available": false,
                "script_execution_allowed": false,
                "execution_actions_available": false,
                "config_mutation_allowed": false,
                "snapshot_created": false,
                "triage_mutation_allowed": false,
                "credential_accessed": false,
                "raw_secret_returned": false
              }
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(TaskReadinessResult.self, from: data)

        try expectEqual(result.taskText, "Summarize a local audit report.", "Task readiness should decode task text.")
        try expectEqual(result.score, 76, "Task readiness should decode flexible score.")
        try expectEqual(result.band, "Partial", "Task readiness should decode band.")
        try expectEqual(result.candidateSkills.map(\.name), ["Beta", "Fallback skill"], "Task readiness should decode object and string candidates.")
        try expectEqual(result.gaps, ["Report export examples"], "Task readiness should decode missing capability aliases.")
        try expectEqual(result.blockers, ["No configured provider for optional explanation"], "Task readiness should decode blockers.")
        try expectEqual(result.evidence.map(\.detail), ["Description mentions local audit.", "No same-agent conflict"], "Task readiness should decode evidence.")
        try expectFalse(result.safety.providerRequestSent, "Local task readiness must not send provider requests.")
        try expectFalse(result.safety.writeBackAllowed, "Task readiness must not allow write-back.")
        try expectFalse(result.safety.scriptExecutionAllowed, "Task readiness must not allow script execution.")
        try expectFalse(result.safety.configMutationAllowed, "Task readiness must not mutate config.")
        try expectFalse(result.safety.credentialAccessed, "Task readiness must not access credentials.")
    }

    private func routingConfidenceDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "task": "Pick a skill for local audit routing.",
              "overall_confidence_score": "88",
              "overall_confidence_band": "High",
              "summary": "Beta is the best local audit route; Gamma is a plausible cross-agent fallback.",
              "route_candidates": [
                {
                  "instance_id": "beta",
                  "skill_name": "Beta",
                  "agent": "claude-code",
                  "score": 88,
                  "confidence_band": "High",
                  "summary": "Strong metadata and local evidence match.",
                  "confidence_rationale": ["Description mentions local audit", "No same-agent runtime conflict"],
                  "ambiguity_warnings": ["Gamma has similar audit wording"],
                  "likely_miss_risks": ["Could miss report-export specialization"],
                  "evidence_references": [{"title":"Metadata","detail":"Description match.","source":"catalog"}]
                },
                "Fallback route"
              ],
              "warnings": ["Duplicate audit wording across agents"],
              "likely_miss_risks": ["A disabled skill may be more specific."],
              "evidence_references": [
                {"title":"Comparison","detail":"Cross-agent duplicate name reviewed.","source":"analysis"}
              ],
              "safety_flags": {
                "provider_request_sent": false,
                "write_back_allowed": false,
                "write_actions_available": false,
                "script_execution_allowed": false,
                "execution_actions_available": false,
                "config_mutation_allowed": false,
                "snapshot_created": false,
                "triage_mutation_allowed": false,
                "credential_accessed": false,
                "raw_secret_returned": false
              }
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(SkillRoutingConfidenceResult.self, from: data)

        try expectEqual(result.taskText, "Pick a skill for local audit routing.", "Routing confidence should decode canonical task.")
        try expectEqual(result.score, 88, "Routing confidence should decode flexible confidence score.")
        try expectEqual(result.band, "High", "Routing confidence should decode confidence band.")
        try expectEqual(result.routes.map(\.name), ["Beta", "Fallback route"], "Routing confidence should decode object and string routes.")
        try expectEqual(result.routes.first?.matchReasons, ["Description mentions local audit", "No same-agent runtime conflict"], "Routing confidence should decode match reasons.")
        try expectEqual(result.routes.first?.ambiguityWarnings, ["Gamma has similar audit wording"], "Routing confidence should decode per-route ambiguity warnings.")
        try expectEqual(result.routes.first?.wrongPickRisks, ["Could miss report-export specialization"], "Routing confidence should decode wrong-pick risks.")
        try expectEqual(result.ambiguityWarnings, ["Duplicate audit wording across agents"], "Routing confidence should decode top-level warnings aliases.")
        try expectEqual(result.wrongPickRisks, ["A disabled skill may be more specific."], "Routing confidence should decode miss explanation aliases.")
        try expectEqual(result.evidence.map(\.detail), ["Cross-agent duplicate name reviewed."], "Routing confidence should decode evidence references.")
        try expectFalse(result.safety.providerRequestSent, "Local routing confidence must not send provider requests.")
        try expectFalse(result.safety.writeBackAllowed, "Routing confidence must not allow write-back.")
        try expectFalse(result.safety.scriptExecutionAllowed, "Routing confidence must not allow script execution.")
        try expectFalse(result.safety.configMutationAllowed, "Routing confidence must not mutate config.")
        try expectFalse(result.safety.credentialAccessed, "Routing confidence must not access credentials.")
    }

    private func taskBenchmarkDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "benchmarks": [
                {
                  "benchmark_id": "bench-1",
                  "task_text": "Route a local audit release note task.",
                  "expected_skill": {"instance_id":"beta","name":"Beta","agent":"claude-code"},
                  "acceptable_instance_ids": ["beta", "alpha"]
                }
              ]
            }
            """.utf8
        )
        let list = try JSONDecoder().decode(TaskBenchmarkListResult.self, from: data)
        try expectEqual(list.benchmarks.count, 1, "Benchmark list should decode object payload.")
        try expectEqual(list.benchmarks.first?.id, "bench-1", "Benchmark should decode benchmark id alias.")
        try expectEqual(list.benchmarks.first?.expectedSkill?.name, "Beta", "Benchmark should decode expected skill.")
        try expectEqual(list.benchmarks.first?.acceptableSkills.map(\.instanceID), ["beta", "alpha"], "Benchmark should decode acceptable instance aliases.")

        let evaluationData = Data(
            """
            {
              "evaluated_count": 1,
              "matched_count": 1,
              "acceptable_count": 1,
              "average_score": "88",
              "evaluations": [
                {
                  "benchmark_id": "bench-1",
                  "task": "Route a local audit release note task.",
                  "match_status": "matched",
                  "top_route": {
                    "instance_id": "beta",
                    "name": "Beta",
                    "agent": "claude-code",
                    "confidence_score": 88,
                    "band": "High",
                    "match_reasons": ["Description matches local audit."]
                  },
                  "expected_covered": true,
                  "acceptable_covered": true,
                  "blockers": [],
                  "missing_capabilities": ["No release-note examples."],
                  "safety_flags": ["provider not sent"],
                  "evidence_references": [{"title":"Routing","detail":"Beta ranked first.","source":"local"}]
                }
              ],
              "safety_flags": {
                "provider_request_sent": false,
                "write_back_allowed": false,
                "write_actions_available": false,
                "script_execution_allowed": false,
                "execution_actions_available": false,
                "config_mutation_allowed": false,
                "snapshot_created": false,
                "triage_mutation_allowed": false,
                "credential_accessed": false,
                "raw_secret_returned": false
              }
            }
            """.utf8
        )
        let evaluation = try JSONDecoder().decode(TaskBenchmarkEvaluationResult.self, from: evaluationData)
        try expectEqual(evaluation.evaluatedCount, 1, "Benchmark evaluation should decode count.")
        try expectEqual(evaluation.averageScore, 88, "Benchmark evaluation should decode average score.")
        try expectEqual(evaluation.evaluations.first?.topRoute?.name, "Beta", "Benchmark evaluation should decode top route.")
        try expectEqual(evaluation.evaluations.first?.gaps, ["No release-note examples."], "Benchmark evaluation should decode gap aliases.")
        try expectEqual(evaluation.evaluations.first?.safetyFlags, ["provider not sent"], "Benchmark evaluation should decode safety flag notes.")
        try expectEqual(evaluation.evaluations.first?.evidence.map(\.detail), ["Beta ranked first."], "Benchmark evaluation should decode evidence references.")
        try expectFalse(evaluation.safety.providerRequestSent, "Local benchmark evaluation must not send provider requests.")
        try expectFalse(evaluation.safety.writeBackAllowed, "Benchmark evaluation must not allow write-back.")
        try expectFalse(evaluation.safety.scriptExecutionAllowed, "Benchmark evaluation must not allow script execution.")
        try expectFalse(evaluation.safety.configMutationAllowed, "Benchmark evaluation must not mutate config.")
        try expectFalse(evaluation.safety.credentialAccessed, "Benchmark evaluation must not access credentials.")
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
