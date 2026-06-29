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
        try routingRegressionDecodesFlexiblePayload()
        try agentTraceImportDecodesFlexiblePayload()
        try routingAccuracyDashboardDecodesFlexiblePayload()
        try promptPreviewDecodesV242Payload()
        try promptPreviewDecodesServiceArrayScopePayload()
        try promptSendResultDecodesCopyOnlyAuditPayload()
        try promptSendResultDecodesServiceDraftOutput()
        try promptSendResultUsesAuditErrorMessage()
        try promptRunListDecodesPersistedCopyOnlyResult()
        try longTextReviewBlockDefaultsToMarkdown()
        try markdownRenderDocumentParsesModelOutputBlocks()
        try markdownRenderDocumentUnwrapsWholeMarkdownFence()
        try markdownRenderDocumentNormalizesCollapsedModelMarkdown()
        try markdownTableDisplayModelKeepsReadableColumns()
        try markdownWideTableDisplayModelUsesCardLayout()
        try markdownThreeColumnQualityTableUsesCardLayoutWhenCellsAreLong()
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
                  "title": "Review same-agent conflicts",
                  "detail": "Use the existing issue review flow before changing routing.",
                  "evidence_refs": ["conflict:fixture-conflict-id"]
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
        try expectEqual(result.suggestedImprovements, ["Use the existing issue review flow before changing routing."], "V2.43 suggestions should decode object details.")
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

    private func routingRegressionDecodesFlexiblePayload() throws {
        let baselineData = Data(
            """
            {
              "baseline_id": "baseline-1",
              "benchmark_count": 2,
              "average_score": 82,
              "matched_count": 1,
              "acceptable_count": 2,
              "summary": "Saved local routing baseline.",
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
        let baseline = try JSONDecoder().decode(RoutingRegressionBaselineResult.self, from: baselineData)
        try expectEqual(baseline.baselineID, "baseline-1", "Routing baseline should decode baseline id.")
        try expectEqual(baseline.benchmarkCount, 2, "Routing baseline should decode benchmark count.")
        try expectEqual(baseline.averageScore, 82, "Routing baseline should decode score.")
        try expectFalse(baseline.safety.providerRequestSent, "Routing baseline save must not send provider requests.")
        try expectFalse(baseline.safety.writeBackAllowed, "Routing baseline save must not allow write-back.")
        try expectFalse(baseline.safety.scriptExecutionAllowed, "Routing baseline save must not allow script execution.")
        try expectFalse(baseline.safety.configMutationAllowed, "Routing baseline save must not mutate config.")
        try expectFalse(baseline.safety.credentialAccessed, "Routing baseline save must not access credentials.")

        let detectionData = Data(
            """
            {
              "baseline_id": "baseline-1",
              "benchmark_count": 2,
              "regression_count": 1,
              "improved_count": 0,
              "unchanged_count": 1,
              "average_score_delta": -9,
              "match_status_changed_count": 1,
              "top_route_changed_count": 1,
              "regressions": [
                {
                  "benchmark_id": "bench-1",
                  "task": "Route a local audit task.",
                  "regression_type": "expected_to_acceptable",
                  "previous_match_status": "matched",
                  "current_match_status": "acceptable",
                  "previous_score": 88,
                  "current_score": 72,
                  "score_delta": -16,
                  "previous_top_route": {"instance_id":"beta","name":"Beta","agent":"claude-code","confidence_score":88,"band":"High"},
                  "current_top_route": {"instance_id":"alpha","name":"Alpha","agent":"claude-code","confidence_score":72,"band":"Medium"},
                  "top_route_changed": true,
                  "new_blockers": ["Expected route dropped below top rank."],
                  "new_gaps": ["Release-note examples still missing."],
                  "safety_flags": ["provider not sent"],
                  "evidence_references": [{"title":"Regression","detail":"Top route changed.","source":"task.detectRoutingRegression"}]
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
        let detection = try JSONDecoder().decode(RoutingRegressionDetectionResult.self, from: detectionData)
        try expectEqual(detection.regressionCount, 1, "Routing regression should decode regression count.")
        try expectEqual(detection.averageScoreDelta, -9, "Routing regression should decode score delta.")
        try expectEqual(detection.regressions.first?.currentTopRoute?.name, "Alpha", "Routing regression should decode current top route.")
        try expectEqual(detection.regressions.first?.newBlockers, ["Expected route dropped below top rank."], "Routing regression should decode new blockers.")
        try expectEqual(detection.regressions.first?.evidence.map(\.detail), ["Top route changed."], "Routing regression should decode evidence references.")
        try expectFalse(detection.safety.providerRequestSent, "Routing regression detection must not send provider requests.")
        try expectFalse(detection.safety.writeBackAllowed, "Routing regression detection must not allow write-back.")
        try expectFalse(detection.safety.scriptExecutionAllowed, "Routing regression detection must not allow script execution.")
        try expectFalse(detection.safety.configMutationAllowed, "Routing regression detection must not mutate config.")
        try expectFalse(detection.safety.snapshotCreated, "Routing regression detection must not create snapshots.")
        try expectFalse(detection.safety.credentialAccessed, "Routing regression detection must not access credentials.")
    }

    private func agentTraceImportDecodesFlexiblePayload() throws {
        let importData = Data(
            """
            {
              "record": {
                "import_id": "trace-1",
                "title": "Local routing trace",
                "task": "Route a local audit release note task.",
                "analysis": {
                  "outcome": "wrong_pick",
                  "detected_skills": [
                    {
                      "instance_id": "alpha",
                      "definition_id": "alpha-definition",
                      "skill_name": "Alpha",
                      "agent": "claude-code",
                      "scope": "agent-global",
                      "evidence_refs": ["skill:alpha"]
                    }
                  ],
                  "reasons": ["Detected route differs from expected skill."],
                  "evidence_refs": ["Alpha appeared in tool selection."]
                },
                "expected_skills": [{"name":"Beta","agent":"claude-code","instance_id":"beta"}],
                "excerpt": "User asked for <project-root> release notes. Assistant selected Alpha.",
                "redaction_summary": {
                  "status": "redacted-local-only",
                  "redacted_fields": ["path"],
                  "placeholders": ["<project-root>"]
                },
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
            }
            """.utf8
        )
        let importResult = try JSONDecoder().decode(AgentTraceImportResult.self, from: importData)
        try expectEqual(importResult.record?.id, "trace-1", "Trace import should decode nested import id.")
        try expectEqual(importResult.record?.outcome, "wrong_pick", "Trace import should decode outcome.")
        try expectEqual(importResult.record?.detectedSkills.map(\.name), ["Alpha"], "Trace import should decode detected skill names.")
        try expectEqual(importResult.record?.expectedSkills.first?.agent, "claude-code", "Trace import should decode expected skill refs.")
        try expectEqual(importResult.record?.redaction.placeholders, ["<project-root>"], "Trace import should decode redaction placeholders.")
        try expectEqual(importResult.record?.reasons, ["Detected route differs from expected skill."], "Trace import should decode reasons.")
        try expectEqual(importResult.record?.evidence.map(\.detail), ["Alpha appeared in tool selection."], "Trace import should decode nested analysis evidence references.")
        try expectFalse(importResult.record?.safety.providerRequestSent ?? true, "Trace import must not send provider requests.")
        try expectFalse(importResult.record?.safety.writeBackAllowed ?? true, "Trace import must not allow write-back.")
        try expectFalse(importResult.record?.safety.scriptExecutionAllowed ?? true, "Trace import must not allow script execution.")
        try expectFalse(importResult.record?.safety.configMutationAllowed ?? true, "Trace import must not mutate config.")
        try expectFalse(importResult.record?.safety.credentialAccessed ?? true, "Trace import must not access credentials.")

        let listData = Data(
            """
            {
              "records": [
                {
                  "trace_id": "trace-2",
                  "name": "Ambiguous route",
                  "match_status": "ambiguous",
                  "detected_skills": [{"name":"Alpha","agent":"claude-code"},{"name":"Beta","agent":"claude-code"}],
                  "expected_skill_names": "Beta",
                  "redaction": "redacted"
                }
              ]
            }
            """.utf8
        )
        let list = try JSONDecoder().decode(AgentTraceImportListResult.self, from: listData)
        try expectEqual(list.imports.first?.id, "trace-2", "Trace list should decode records alias.")
        try expectEqual(list.imports.first?.outcome, "ambiguous", "Trace list should decode match_status alias.")
        try expectEqual(list.imports.first?.expectedSkills.map(\.name), ["Beta"], "Trace list should decode expected skill name string.")
    }

    private func routingAccuracyDashboardDecodesFlexiblePayload() throws {
        let data = Data(
            """
            {
              "generated_by": "local-v2.49",
              "catalog_available": true,
              "filters": {
                "agent": "claude-code",
                "window_days": "30",
                "limit": 20,
                "include_history": true,
                "include_recent_evidence": true
              },
              "summary": {
                "hits": 7,
                "miss_count": "2",
                "wrong_picks": 1,
                "ambiguous": 1,
                "unknown_count": 0,
                "trace_count": 11,
                "benchmark_count": 5,
                "benchmark_matched_count": 4,
                "benchmark_gap_count": 3,
                "regression_count": 1,
                "missing_benchmark_count": 2,
                "gap_count": 3,
                "blocker_count": 1,
                "accuracy_rate": 0.636,
                "known_outcome_rate": 1.0,
                "summary": "Routing accuracy summary.",
                "average_confidence": 0.82,
                "hit_rate": "63.6%",
                "wrong_pick_rate": 0.091
              },
              "agent_rows": [
                {
                  "name": "claude-code",
                  "trace_count": 8,
                  "outcomes": {
                    "hit": 6,
                    "miss": 1,
                    "wrong_pick": 1,
                    "ambiguous": 0,
                    "unknown": 0
                  },
                  "accuracy_rate": 0.75,
                  "average_confidence": 82,
                  "benchmark_count": 3,
                  "benchmark_matched_count": 2,
                  "benchmark_gap_count": 1,
                  "gap_count": 2,
                  "regression_count": 1,
                  "recent_evidence_count": 4,
                  "notes": ["Codex benchmark missing."]
                }
              ],
              "history_rows": [
                {
                  "unix_day": 1781136000,
                  "trace_count": "4",
                  "outcomes": {"hit": 3, "miss": 0, "wrong_pick": 1, "ambiguous": 0, "unknown": 0},
                  "accuracy_rate": 0.75,
                  "regression_count": 1
                }
              ],
              "gap_issue_rows": [
                {"source": "trace", "severity": "warning", "agent": "openclaw", "title": "Missing trace coverage", "detail": "No OpenClaw traces.", "evidence_refs": ["trace:none"], "count": "2"},
                "No baseline for Codex"
              ],
              "recent_evidence_rows": [
                {"source": "trace.importLocal", "agent": "claude-code", "title": "Trace", "outcome": "hit", "detail": "Beta matched expected route.", "evidence_refs": ["trace-1"], "observed_at": 1781136000000}
              ],
              "blocker_notes": ["One expected route has no benchmark."],
              "prompt_request": {
                "enabled": false,
                "request_kind": "routing_accuracy",
                "summary": "Copy-only provider explanation unavailable by default.",
                "draft_copy_only": true
              },
              "safety_flags": {
                "provider_request_sent": false,
                "write_back_allowed": false,
                "script_execution_allowed": false,
                "config_mutation_allowed": false,
                "snapshot_created": false,
                "triage_mutation_allowed": false,
                "credential_accessed": false,
                "raw_prompt_persisted": false,
                "raw_response_persisted": false,
                "raw_trace_persisted": false,
                "cloud_sync_enabled": false,
                "telemetry_enabled": false,
                "raw_secret_returned": false,
                "notes": ["provider not sent"]
              }
            }
            """.utf8
        )

        let dashboard = try JSONDecoder().decode(RoutingAccuracyDashboard.self, from: data)

        try expectEqual(dashboard.generatedBy, "local-v2.49", "Routing accuracy should decode generator.")
        try expectEqual(dashboard.filters.agent, "claude-code", "Routing accuracy should decode filter agent.")
        try expectEqual(dashboard.filters.windowDays, 30, "Routing accuracy should decode numeric string window.")
        try expectEqual(dashboard.summary.hitCount, 7, "Routing accuracy should decode hit alias.")
        try expectEqual(dashboard.summary.missCount, 2, "Routing accuracy should decode miss string.")
        try expectEqual(dashboard.summary.wrongPickCount, 1, "Routing accuracy should decode wrong-pick alias.")
        try expectEqual(dashboard.summary.totalBenchmarks, 5, "Routing accuracy should decode benchmark count alias.")
        try expectEqual(dashboard.summary.benchmarkMatchedCount, 4, "Routing accuracy should decode benchmark matched count.")
        try expectEqual(dashboard.summary.benchmarkGapCount, 3, "Routing accuracy should decode benchmark gap count.")
        try expectEqual(dashboard.summary.missingBenchmarkCount, 2, "Routing accuracy should decode missing benchmark count.")
        try expectEqual(dashboard.summary.regressionCount, 1, "Routing accuracy should decode regression count.")
        try expectEqual(dashboard.summary.summaryText, "Routing accuracy summary.", "Routing accuracy should decode summary text.")
        try expectEqual(dashboard.summary.rateLabel(dashboard.summary.hitRate, count: dashboard.summary.hitCount), "63.6%", "Routing accuracy should format percent strings.")
        try expectEqual(dashboard.agents.first?.agent, "claude-code", "Routing accuracy should decode agent row name alias.")
        try expectEqual(dashboard.agents.first?.totalCount, 8, "Routing accuracy should decode agent total alias.")
        try expectEqual(dashboard.agents.first?.benchmarkMatchedCount, 2, "Routing accuracy should decode agent benchmark matched count.")
        try expectEqual(dashboard.history.first?.label, "1781136000", "Routing accuracy should decode history unix day.")
        try expectEqual(dashboard.gaps.map(\.title), ["Missing trace coverage", "No baseline for Codex"], "Routing accuracy should decode object and string gaps.")
        try expectEqual(dashboard.blockerNotes, ["One expected route has no benchmark."], "Routing accuracy should decode blocker notes.")
        try expectEqual(dashboard.recentEvidence.first?.source, "trace.importLocal", "Routing accuracy should decode recent evidence.")
        try expectEqual(dashboard.recentEvidence.first?.outcome, "hit", "Routing accuracy should decode evidence outcome.")
        try expectEqual(dashboard.promptRequest?.requestKind, "routing_accuracy", "Routing accuracy should decode prompt request.")
        try expectFalse(dashboard.safetyFlags.providerRequestSent, "Routing accuracy must not send provider requests.")
        try expectFalse(dashboard.safetyFlags.writeBackAllowed, "Routing accuracy must not allow writes.")
        try expectFalse(dashboard.safetyFlags.scriptExecutionAllowed, "Routing accuracy must not allow scripts.")
        try expectFalse(dashboard.safetyFlags.configMutationAllowed, "Routing accuracy must not mutate config.")
        try expectFalse(dashboard.safetyFlags.snapshotCreated, "Routing accuracy must not create snapshots.")
        try expectFalse(dashboard.safetyFlags.triageMutationAllowed, "Routing accuracy must not mutate triage.")
        try expectFalse(dashboard.safetyFlags.credentialAccessed, "Routing accuracy must not access credentials.")
        try expectFalse(dashboard.safetyFlags.rawPromptPersisted, "Routing accuracy must not persist raw prompts.")
        try expectFalse(dashboard.safetyFlags.rawResponsePersisted, "Routing accuracy must not persist raw responses.")
        try expectFalse(dashboard.safetyFlags.rawTracePersisted, "Routing accuracy must not persist raw traces.")
        try expectFalse(dashboard.safetyFlags.cloudSyncEnabled, "Routing accuracy must not sync cloud data.")
        try expectFalse(dashboard.safetyFlags.telemetryEnabled, "Routing accuracy must not emit telemetry.")
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

    private func promptSendResultUsesAuditErrorMessage() throws {
        let data = Data(
            """
            {
              "preview_id": "preview-timeout",
              "status": "failed",
              "draft_copy_only": true,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "write_back_allowed": false,
              "script_execution_allowed": false,
              "audit": {
                "status": "failed",
                "provider_type": "openai-compatible",
                "model": "deepseek-v4-flash",
                "destination_host": "llm.example.com",
                "redaction_status": "redacted-preview-confirmed-required",
                "raw_prompt_persisted": false,
                "raw_response_persisted": false,
                "estimated_input_tokens": 1325,
                "estimated_output_tokens": 650,
                "error_code": "network_error",
                "error_message": "timed out reading response"
              }
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(LLMPromptSendResult.self, from: data)

        try expectFalse(result.success, "Failed prompt send should not decode as success.")
        try expectEqual(result.message, "network_error: timed out reading response", "Prompt send should surface audit error details.")
        try expectEqual(result.audit?.errorCode, "network_error", "Prompt send should decode audit error code.")
        try expectEqual(result.audit?.errorMessage, "timed out reading response", "Prompt send should decode audit error message.")
    }

    private func promptSendResultDecodesServiceDraftOutput() throws {
        let data = Data(
            """
            {
              "preview_id": "preview-draft-output",
              "status": "succeeded",
              "output_text": "",
              "draft_output": "Copy-only provider analysis.",
              "draft_copy_only": true,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "write_back_allowed": false,
              "script_execution_allowed": false
            }
            """.utf8
        )

        let result = try JSONDecoder().decode(LLMPromptSendResult.self, from: data)

        try expectEqual(result.success, true, "Prompt send should decode service success status.")
        try expectEqual(
            result.outputText,
            "Copy-only provider analysis.",
            "Prompt send should expose service draft_output as visible copy-only output."
        )
        try expectEqual(result.draftCopyOnly, true, "Prompt send draft_output should remain copy-only.")
        try expectFalse(result.rawPromptPersisted, "Prompt send must not persist raw prompts.")
        try expectFalse(result.rawResponsePersisted, "Prompt send must not persist raw responses.")
    }

    private func promptRunListDecodesPersistedCopyOnlyResult() throws {
        let data = Data(
            """
            {
              "runs": [
                {
                  "run_id": "run-1",
                  "preview_id": "preview-1",
                  "confirmation_id": "confirm-1",
                  "action": "task_readiness",
                  "request_kind": "task_readiness",
                  "analysis_kind": null,
                  "scope": "single-skill",
                  "instance_id": "skill-1",
                  "instance_ids": ["skill-1"],
                  "task": "Review release readiness",
                  "provider": "openai-compatible",
                  "model": "gpt-5",
                  "destination_host": "llm.example.com",
                  "status": "succeeded",
                  "message": "Provider request completed.",
                  "error_code": null,
                  "error_message": null,
                  "duration_ms": 1234,
                  "input_tokens": 600,
                  "output_tokens": 120,
                  "estimated_cost_usd": 0.012,
                  "draft_output": "Copy-only persisted explanation.",
                  "draft_copy_only": true,
                  "raw_prompt_persisted": false,
                  "raw_response_persisted": false,
                  "raw_secret_returned": false,
                  "redaction": {
                    "status": "redacted",
                    "redacted_fields": ["local paths"],
                    "placeholders": ["<project-root>"]
                  },
                  "safety_flags": {
                    "provider_request_sent": true,
                    "write_back_allowed": false,
                    "script_execution_allowed": false,
                    "config_mutation_allowed": false,
                    "snapshot_created": false,
                    "triage_mutation_allowed": false,
                    "credential_accessed": false,
                    "raw_prompt_persisted": false,
                    "raw_response_persisted": false,
                    "raw_secret_returned": false,
                    "cloud_sync_enabled": false,
                    "telemetry_enabled": false
                  },
                  "created_at": 1781260000000,
                  "completed_at": 1781260001234
                }
              ],
              "provider_request_sent": false,
              "raw_prompt_persisted": false,
              "raw_response_persisted": false,
              "raw_secret_returned": false
            }
            """.utf8
        )

        let list = try JSONDecoder().decode(LLMPromptRunListResult.self, from: data)
        guard let run = list.runs.first else {
            throw NativeModelTestFailure(description: "Prompt run list should decode a run.")
        }
        let sendResult = run.sendResult

        try expectEqual(list.runs.count, 1, "Prompt run list should decode runs.")
        try expectEqual(run.requestKind, "task_readiness", "Prompt run should decode request kind.")
        try expectEqual(run.task, "Review release readiness", "Prompt run should decode redacted task text.")
        try expectEqual(sendResult.outputText, "Copy-only persisted explanation.", "Prompt run should hydrate copy-only output.")
        try expectFalse(sendResult.rawPromptPersisted, "Prompt run must not persist raw prompts.")
        try expectFalse(sendResult.rawResponsePersisted, "Prompt run must not persist raw responses.")
        try expectFalse(run.rawSecretReturned, "Prompt run must not return raw secrets.")
    }

    private func markdownRenderDocumentParsesModelOutputBlocks() throws {
        let document = MarkdownRenderDocument(
            text: """
            ## Result

            - First finding
            > Keep this copy-only.

            | Field | Value |
            | --- | --- |
            | Score | **High** |

            ```text
            raw-id
            ```
            """,
            maxBlocks: nil
        )

        try expectFalse(document.isTruncated, "Full Markdown details should not be truncated.")
        try expectEqual(
            document.blocks.contains { block in
                if case let .heading(level, value) = block {
                    return level == 2 && value == "Result"
                }
                return false
            },
            true,
            "Markdown renderer should parse model headings."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .bullet(value) = block {
                    return value == "First finding"
                }
                return false
            },
            true,
            "Markdown renderer should parse model bullet lists."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .quote(value) = block {
                    return value == "Keep this copy-only."
                }
                return false
            },
            true,
            "Markdown renderer should parse model block quotes."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .table(rows) = block {
                    return rows.first == ["Field", "Value"] && rows.last == ["Score", "**High**"]
                }
                return false
            },
            true,
            "Markdown renderer should parse model tables."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .code(value) = block {
                    return value == "raw-id"
                }
                return false
            },
            true,
            "Markdown renderer should parse model fenced code blocks."
        )
    }

    private func longTextReviewBlockDefaultsToMarkdown() throws {
        let isMarkdown: Bool
        if case .markdown = LongTextReviewPresentation.defaultRenderMode {
            isMarkdown = true
        } else {
            isMarkdown = false
        }
        try expectEqual(isMarkdown, true, "Model long-text previews should render Markdown by default.")
    }

    private func markdownRenderDocumentUnwrapsWholeMarkdownFence() throws {
        let output = """
        ```markdown
        ## 结论
        ce:compound 当前质量评分 51/100。

        | 组件 | 得分 | 关键问题 | 证据 |
        | --- | --- | --- | --- |
        | 权限元数据 | 5/20 | 权限元数据为空。 | finding:permissions |
        ```
        """

        let document = MarkdownRenderDocument(text: output, maxBlocks: nil)

        try expectEqual(
            MarkdownRenderDocument.renderableText(from: output).contains("```markdown"),
            false,
            "Whole-response Markdown fences should be removed before rendering provider output."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .heading(_, value) = block {
                    return value == "结论"
                }
                return false
            },
            true,
            "Unwrapped provider Markdown should render headings instead of one giant code block."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .table(rows) = block {
                    return rows.first == ["组件", "得分", "关键问题", "证据"]
                }
                return false
            },
            true,
            "Unwrapped provider Markdown tables should remain parseable for card fallback."
        )

        let code = """
        ```swift
        print("keep as code")
        ```
        """
        let codeDocument = MarkdownRenderDocument(text: code, maxBlocks: nil)
        try expectEqual(
            codeDocument.blocks.contains { block in
                if case let .code(value) = block {
                    return value.contains("print")
                }
                return false
            },
            true,
            "Real language code fences should stay code blocks."
        )
    }

    private func markdownRenderDocumentNormalizesCollapsedModelMarkdown() throws {
        let output = "# 技能质量评估草稿指导 ## 概述 技能 `ce:compound` 当前质量评分 **51 / 100**。 ## 组件分析 | 组件 | 得分 | 关键问题 | |------|------|----------| | 元数据完整性 | 25/25 | 本地名称、描述、frontmatter 和正文指导均符合预期，无扣分项。 | | 权限清晰度 | 5/20 | 权限元数据为空或不可用；未找到显式工具允许列表；网络访问意图未知。 | ## 证据说明 - **发现 `name.canonical-case`**：技能名称不是规范形式。 - **适配器诊断**：状态 verified。"

        let document = MarkdownRenderDocument(text: output, maxBlocks: nil)

        try expectEqual(
            document.blocks.contains { block in
                if case let .heading(level, value) = block {
                    return level == 1 && value == "技能质量评估草稿指导"
                }
                return false
            },
            true,
            "Collapsed model Markdown should recover the top-level heading."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .heading(level, value) = block {
                    return level == 2 && value == "组件分析"
                }
                return false
            },
            true,
            "Collapsed model Markdown should split inline section headings before tables."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .table(rows) = block {
                    return rows.count == 3
                        && rows.first == ["组件", "得分", "关键问题"]
                        && rows.dropFirst().contains(["权限清晰度", "5/20", "权限元数据为空或不可用；未找到显式工具允许列表；网络访问意图未知。"])
                        && !rows.contains(["------", "------", "----------"])
                }
                return false
            },
            true,
            "Collapsed model Markdown tables should recover row boundaries."
        )
        try expectEqual(
            document.blocks.contains { block in
                if case let .bullet(value) = block {
                    return value.contains("name.canonical-case")
                }
                return false
            },
            true,
            "Collapsed model Markdown should recover bullets after a table."
        )
    }

    private func markdownTableDisplayModelKeepsReadableColumns() throws {
        let rows = [
            ["Field", "Value"],
            ["Score", "**High**"],
            ["Reason", "Local evidence is clear."],
        ]

        let model = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: nil)

        try expectEqual(model.usesCardLayout, false, "Compact two-column AI output tables should keep the normal table layout.")
        try expectEqual(model.displayRows.count, rows.count, "Two-column AI output tables should preserve visible rows.")
        try expectFalse(
            model.columnWidth(at: 0) < MarkdownTableDisplayModel.minimumColumnWidth,
            "AI output table columns should keep a readable minimum width instead of collapsing into vertical text."
        )
    }

    private func markdownWideTableDisplayModelUsesCardLayout() throws {
        let rows = [
            ["组件", "得分", "关键问题", "元数据完整性", "权限清晰度", "风险发现"],
            ["整体", "51/100", "主要集中在权限声明缺失、风险发现未充分处理以及跨代理重复问题。", "25/25", "5/20", "4/25"],
            ["本地名称", "25/25", "描述、frontmatter 和文档导向符合预期。", "25/25", "5/20", "4/25"],
            ["权限元数据", "5/20", "权限元数据为空或不可用。", "25/25", "5/20", "4/25"],
            ["风险发现", "4/25", "存在 2 条相关发现，本地文本信号进一步降低风险得分。", "25/25", "5/20", "4/25"],
            ["适配器状态", "12/15", "适配器状态为 verified，读写、安装均正常。", "25/25", "5/20", "4/25"],
        ]

        let compact = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: 4)
        let full = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: nil)

        try expectEqual(compact.usesCardLayout, true, "Wide AI output tables should render as readable cards instead of a horizontal grid.")
        try expectEqual(compact.bodyRowCount, 5, "AI output table summaries should count body rows separately from the header.")
        try expectEqual(compact.displayCardRows.count, 3, "Compact AI output table cards should reserve one row for headers and show bounded body rows.")
        try expectEqual(compact.hiddenRowCount, 2, "Compact AI output tables should report hidden rows for the details sheet.")
        try expectEqual(compact.columnCount, 6, "Table layout should preserve all model-returned columns.")
        try expectEqual(full.displayCardRows.count, rows.count - 1, "Full AI output details should keep every table body row as cards.")
        try expectEqual(full.hiddenRowCount, 0, "Full AI output details should not hide rows.")
    }

    private func markdownThreeColumnQualityTableUsesCardLayoutWhenCellsAreLong() throws {
        let rows = [
            ["组件", "得分", "关键问题"],
            ["权限清晰度", "5/20", "权限元数据为空或不可用；未找到显式工具允许列表；网络访问意图未知。"],
            ["风险发现", "4/25", "存在 2 条相关发现，本地文本信号进一步降低了风险得分。"],
        ]

        let model = MarkdownTableDisplayModel(rows: rows, maxVisibleRows: nil)

        try expectEqual(model.usesCardLayout, true, "Three-column quality-score tables with long issue text should render as cards.")
        try expectEqual(model.displayCardRows.count, 2, "Quality-score table cards should include all body rows in details.")
    }

}
