use super::{skill_manager_fixtures::skill_manager_dispatch_params, *};

#[test]
fn supported_methods_have_dispatch_coverage() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-dispatch-coverage-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    for method in supported_methods() {
        let response = host.handle(ServiceRequest {
            id: Some(format!("dispatch-{method}")),
            method: method.to_string(),
            params: dispatch_coverage_params(method),
        });
        if let Some(error) = response.error {
            assert_ne!(
                error.code, "unknown_method",
                "supported method {method} was not covered by dispatch"
            );
        }
    }

    let unknown = host.handle(ServiceRequest {
        id: Some("dispatch-unknown".to_string()),
        method: "service.notReal".to_string(),
        params: Value::Null,
    });
    assert!(!unknown.ok);
    let error = unknown.error.expect("unknown method error");
    assert_eq!(error.code, "unknown_method");
    assert!(error.message.contains("service.notReal"));

    let _ = fs::remove_dir_all(app_data_dir);
}

fn dispatch_coverage_params(method: &str) -> Value {
    match method {
        "catalog.getSkill" | "config.toggleSkill" => {
            json!({ "instance_id": "missing-skill", "on": false })
        }
        "evidence.previewMcpServers" => json!({
            "authorized_config_paths": ["/tmp/skills-copilot-fixture-mcp.json"],
            "limit": 4
        }),
        "skill.exportBundle" => {
            json!({ "source_path": "/tmp/skills-copilot-missing-skill/SKILL.md" })
        }
        "skill.install" => json!({
            "instance_id": "missing-skill",
            "target_agent": "codex",
            "target_scope": "agent-global",
            "confirmed": false
        }),
        "llm.prepareAction" => json!({ "kind": "recommend", "user_intent": "fixture" }),
        "llm.saveProviderProfile" => json!({
            "id": "dispatch-provider",
            "display_name": "Dispatch Provider",
            "provider_type": "openai-compatible",
            "base_url": "https://example.invalid/v1",
            "model": "dispatch-model",
            "enabled": false
        }),
        "llm.deleteProviderProfile" => json!({
            "profile_id": "dispatch-provider",
            "delete_credential": false
        }),
        "llm.testProviderConnection" => json!({
            "profile_id": "dispatch-provider",
            "confirmation_id": "dispatch-confirmation"
        }),
        "llm.previewPrompt" => json!({
            "action": "recommend",
            "user_intent": "fixture"
        }),
        "llm.confirmPromptAndSend" => json!({
            "preview_id": "prompt-preview-stale",
            "confirmation_id": "dispatch-confirmation",
            "request": {
                "action": "recommend",
                "user_intent": "fixture"
            }
        }),
        "llm.listPromptRuns" => json!({
            "limit": 4
        }),
        "llm.providerObservability" => json!({
            "limit": 4
        }),
        "llm.listModelTaskMatches" => json!({
            "limit": 4
        }),
        "llm.recordModelTaskMatch" => json!({
            "id": "dispatch-model-task-match",
            "title": "Dispatch model-task match",
            "task": "Fixture local release audit task",
            "task_kind": "task_readiness",
            "provider": "openai-compatible",
            "model": "dispatch-model",
            "match_status": "fit",
            "source_kind": "manual",
            "evidence_refs": ["dispatch:model-task"]
        }),
        "llm.deleteModelTaskMatch" => json!({
            "id": "dispatch-model-task-match"
        }),
        "llm.prepareSkillAnalysis" => {
            json!({ "instance_ids": ["missing-skill"], "analysis_kind": "overview" })
        }
        "analysis.scoreSkillQuality" => json!({ "instance_id": "missing-skill" }),
        "analysis.detectStaleDrift" => json!({ "limit": 4, "stale_days": 30 }),
        "knowledge.search" => json!({ "query": "fixture knowledge search", "limit": 4 }),
        "knowledge.buildCapabilityTaxonomy" => {
            json!({ "include_single_skill_domains": true, "limit": 4 })
        }
        "knowledge.buildLocalSkillMap" => json!({
            "task": "fixture local skill map",
            "limit": 4,
            "node_limit": 24,
            "edge_limit": 48,
            "cluster_limit": 8,
            "include_task_context": true
        }),
        "workspace.checkReadiness" => json!({
            "task": "fixture workspace readiness check",
            "expected_capabilities": ["Release & Validation", "Security & Privacy"],
            "limit": 4
        }),
        "remediation.plan" => json!({
            "task": "fixture remediation planning check",
            "focus_areas": ["finding", "gap", "ambiguity", "drift", "readiness"],
            "limit": 4
        }),
        "remediation.previewDrafts" => json!({
            "task": "fixture fix preview drafts check",
            "draft_types": ["permissions", "policy"],
            "limit": 4,
            "include_policy_drafts": true
        }),
        "remediation.previewImpact" => json!({
            "action": "review",
            "task": "fixture impact preview check",
            "limit": 4,
            "include_snapshot_plan": true,
            "include_rollback_plan": true,
            "include_risk_impact": true,
            "include_task_impact": true
        }),
        "remediation.batchReview" => json!({
            "task": "fixture batch review check",
            "group_by": ["risk", "rule", "agent", "workspace", "task"],
            "limit": 4
        }),
        "remediation.listHistory" => json!({
            "include_recurrence_rows": true,
            "limit": 4
        }),
        "remediation.recordHistory" => json!({
            "id": "dispatch-remediation-history",
            "title": "Dispatch remediation history",
            "decision": "reviewed",
            "status": "recorded",
            "source_method": "remediation.batchReview",
            "batch_review_item_ids": ["batch-risk-1"],
            "evidence_refs": ["finding:dispatch"]
        }),
        "remediation.deleteHistory" => json!({ "id": "dispatch-remediation-history" }),
        "cleanup.planGuidedFlow" => json!({
            "task": "fixture guided cleanup flow",
            "selected_skill_id": "missing-skill",
            "limit": 4,
            "include_recorded_steps": true
        }),
        "cleanup.recordGuidedStep" => json!({
            "id": "dispatch-guided-cleanup-step",
            "flow_step_id": "dispatch-guided-step",
            "title": "Dispatch guided cleanup step",
            "decision": "reviewed",
            "status": "recorded",
            "source_refs": ["dispatch-source"],
            "evidence_refs": ["dispatch-evidence"]
        }),
        "task.checkReadiness" => json!({ "task": "fixture task readiness check" }),
        "task.rankSkillRoutes" => json!({ "task": "fixture routing confidence check" }),
        "task.compareAgentReadiness" => json!({
            "task": "fixture cross-agent readiness check",
            "agents": ["claude-code", "codex"],
            "limit_per_agent": 2
        }),
        "task.buildCockpit" => json!({
            "task": "fixture task-first cockpit check",
            "limit": 4
        }),
        "task.listBenchmarks" => json!({}),
        "task.saveBenchmark" => json!({
            "id": "fixture-benchmark",
            "title": "Fixture benchmark",
            "task": "fixture task benchmark check",
            "expected_skill_refs": ["fixture-skill-id"]
        }),
        "task.deleteBenchmark" => json!({ "id": "fixture-benchmark" }),
        "task.evaluateBenchmarks" => json!({}),
        "task.saveRoutingBaseline" => json!({}),
        "task.detectRoutingRegression" => json!({}),
        "routing.accuracyDashboard" => json!({
            "window_days": 30,
            "include_history": true,
            "include_recent_evidence": true
        }),
        "skill.lifecycleTimeline" => json!({
            "agent": "codex",
            "selected_skill_id": "fixture-skill-id",
            "limit": 4
        }),
        "session.previewLocalSessions" => json!({
            "authorized_roots": ["/tmp/skills-copilot-fixture-sessions"],
            "limit": 4,
            "max_excerpt_chars": 800
        }),
        "session.reviewAgentSkillUse" => json!({
            "content": "Fixture session selected fixture-skill-id for local routing.",
            "title": "Fixture session skill review",
            "expected_skill_refs": ["fixture-skill-id"]
        }),
        "session.listSkillReviews" => json!({}),
        "session.deleteSkillReview" => json!({ "id": "fixture-session-review" }),
        "trace.importLocal" => json!({
            "content": "Fixture trace selected fixture-skill-id for local routing.",
            "title": "Fixture trace import",
            "expected_skill_refs": ["fixture-skill-id"]
        }),
        "trace.listImports" => json!({}),
        "trace.deleteImport" => json!({ "id": "fixture-trace-import-local" }),
        "evidence.piWritableHarness" => json!({ "run_label": "dispatch-fixture" }),
        "report.exportLocal" => json!({ "formats": ["json"] }),
        "script.previewExecution" => json!({
            "command": ["echo", "preview-only"],
            "initiated_by": "user"
        }),
        "script.execute" => json!({
            "command": ["echo", "blocked"],
            "confirmed": true
        }),
        method if method.starts_with("skillManager.") => skill_manager_dispatch_params(method),
        "config.readAgentConfig" => json!({ "agent": "codex" }),
        "config.saveClaudeSettings" => json!({ "content": "{}\n" }),
        "project.setContext" | "project.validateContext" => {
            json!({ "root_path": "/tmp/skills-copilot-missing-project" })
        }
        "snapshot.previewRollback" | "snapshot.rollback" => {
            json!({ "snapshot_id": "missing-snapshot" })
        }
        "catalog.setFindingTriage" => json!({
            "triage_key": "missing-finding-key",
            "status": "reviewed"
        }),
        "catalog.clearFindingTriage" => json!({ "triage_key": "missing-finding-key" }),
        "rules.setSeverityOverride" => json!({
            "rule_id": "body.too-long",
            "severity": "info"
        }),
        "rules.clearSeverityOverride" => json!({ "rule_id": "body.too-long" }),
        "rules.setSuppression" => json!({
            "rule_id": "body.too-long",
            "reason": "local false positive"
        }),
        "rules.clearSuppression" => json!({ "rule_id": "body.too-long" }),
        _ => Value::Null,
    }
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAppVersion {
    pub(super) protocol_version: u32,
    pub(super) version: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireServiceStatus {
    pub(super) protocol_version: u32,
    pub(super) version: String,
    pub(super) app_data_dir: String,
    pub(super) catalog_path: String,
    pub(super) user_home: String,
    pub(super) supported_methods: Vec<String>,
    pub(super) refresh: WireRefreshStatus,
    pub(super) project_context: WireProjectContextSummary,
    pub(super) llm: WireLlmStatus,
    pub(super) trace_imports: WireTraceImportStatus,
    #[serde(default)]
    pub(super) session_reviews: Option<WireAgentSessionSkillReviewStatus>,
    pub(super) script_execution: WireScriptExecutionStatus,
    pub(super) adapter_capabilities: Vec<WireAdapterCapabilityRecord>,
    #[serde(default)]
    pub(super) adapter_diagnostics: Option<Vec<WireAdapterDiagnosticsRecord>>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAppStateSnapshot {
    pub(super) status: WireServiceStatus,
    pub(super) skills: Vec<WireSkillRecord>,
    pub(super) findings: Vec<WireRuleFindingRecord>,
    pub(super) conflicts: Vec<WireConflictGroupRecord>,
    pub(super) analysis: WireCrossAgentAnalysisRecord,
    pub(super) health: SkillHealthSummary,
    pub(super) snapshots: Vec<WireConfigSnapshotRecord>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportStatus {
    pub(super) count: usize,
    pub(super) imports_path: String,
    pub(super) app_local_only: bool,
    pub(super) raw_trace_persistence_allowed: bool,
    pub(super) provider_request_allowed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewStatus {
    pub(super) count: usize,
    pub(super) reviews_path: String,
    pub(super) app_local_only: bool,
    pub(super) raw_trace_persistence_allowed: bool,
    pub(super) provider_request_allowed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCrossAgentAnalysisRecord {
    pub(super) summary: WireCrossAgentAnalysisSummary,
    pub(super) groups: Vec<WireCrossAgentAnalysisGroup>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCrossAgentAnalysisSummary {
    pub(super) total_groups: usize,
    pub(super) duplicate_name_groups: usize,
    pub(super) canonical_name_groups: usize,
    pub(super) path_overlap_groups: usize,
    pub(super) enabled_mismatch_groups: usize,
    pub(super) malformed_groups: usize,
    pub(super) precedence_groups: usize,
    pub(super) affected_skill_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCrossAgentAnalysisGroup {
    pub(super) id: String,
    pub(super) kind: String,
    pub(super) severity: String,
    pub(super) title: String,
    pub(super) canonical_name: Option<String>,
    pub(super) explanation: String,
    pub(super) instance_ids: Vec<String>,
    pub(super) winner_id: Option<String>,
    pub(super) agents: Vec<String>,
    pub(super) scopes: Vec<String>,
    pub(super) paths: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterCapabilityRecord {
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) status: String,
    pub(super) scan: WireAdapterFeatureCapability,
    pub(super) project_scan: WireAdapterFeatureCapability,
    pub(super) config_toggle: WireAdapterFeatureCapability,
    pub(super) config_snapshot: WireAdapterFeatureCapability,
    pub(super) install: WireAdapterFeatureCapability,
    pub(super) writable: WireAdapterFeatureCapability,
    pub(super) blockers: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterFeatureCapability {
    pub(super) supported: bool,
    pub(super) status: String,
    pub(super) reason: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticsRecord {
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) status: String,
    pub(super) roots: Vec<WireAdapterDiagnosticRootRecord>,
    pub(super) config: WireAdapterDiagnosticConfigSummary,
    pub(super) access: WireAdapterDiagnosticAccessSummary,
    pub(super) last_scan: WireAdapterDiagnosticLastScan,
    pub(super) blockers: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticRootRecord {
    pub(super) path: String,
    pub(super) scope: String,
    pub(super) source: String,
    pub(super) exists: bool,
    pub(super) status: String,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticConfigSummary {
    pub(super) status: String,
    pub(super) detected_count: usize,
    pub(super) paths: Vec<WireAdapterDiagnosticConfigPath>,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticConfigPath {
    pub(super) path: String,
    pub(super) detected: bool,
    pub(super) status: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticAccessSummary {
    pub(super) read_only: bool,
    pub(super) writable_supported: bool,
    pub(super) writable_status: String,
    pub(super) writable_reason: Option<String>,
    pub(super) install_supported: bool,
    pub(super) install_status: String,
    pub(super) install_reason: Option<String>,
    pub(super) read_only_reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAdapterDiagnosticLastScan {
    pub(super) status: String,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireMcpServerPreviewPath {
    pub(super) path: String,
    pub(super) status: String,
    pub(super) server_count: usize,
    pub(super) blocker: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireMcpServerPreviewRow {
    pub(super) id: String,
    pub(super) name: String,
    pub(super) source_path: String,
    pub(super) transport: String,
    pub(super) command: Option<String>,
    pub(super) args_count: usize,
    pub(super) env_key_count: usize,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireMcpServerPreviewResult {
    pub(super) generated_by: String,
    pub(super) authorized: bool,
    pub(super) authorization_required: bool,
    pub(super) evidence_available: bool,
    pub(super) evidence_insufficient: bool,
    pub(super) authorized_paths: Vec<WireMcpServerPreviewPath>,
    pub(super) count: usize,
    pub(super) server_rows: Vec<WireMcpServerPreviewRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) redaction_summary: WireAgentSessionSkillReviewRedactionSummary,
    pub(super) safety_flags: WireAgentSessionSkillReviewSafetyFlags,
    pub(super) read_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) credential_accessed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WirePiWritableHarnessReport {
    pub(super) harness: String,
    pub(super) production_writes_enabled: bool,
    pub(super) disposable_root: String,
    pub(super) report_path: String,
    pub(super) scenarios: Vec<WirePiWritableHarnessScenario>,
    pub(super) safety: WirePiWritableHarnessSafety,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WirePiWritableHarnessScenario {
    pub(super) name: String,
    pub(super) layer: String,
    pub(super) config_path: String,
    pub(super) skill_name: String,
    pub(super) initial_enabled: bool,
    pub(super) disabled_after_toggle: bool,
    pub(super) reenabled_after_toggle: bool,
    pub(super) rollback_restored: bool,
    pub(super) invalid_json_blocked: bool,
    pub(super) explicit_untrusted_blocked: bool,
    pub(super) writes_confined_to_disposable_root: bool,
    pub(super) snapshot_content: String,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WirePiWritableHarnessSafety {
    pub(super) disposable_only: bool,
    pub(super) production_writes_enabled: bool,
    pub(super) provider_request_sent: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) install_performed: bool,
    pub(super) production_config_mutated: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualityScoreResult {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) skill_name: String,
    pub(super) score: u8,
    pub(super) grade: String,
    pub(super) band: String,
    pub(super) generated_by: String,
    pub(super) components: Vec<WireSkillQualityScoreComponent>,
    pub(super) reasons: Vec<String>,
    pub(super) risk_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireSkillQualityEvidenceReference>,
    pub(super) suggested_improvements: Vec<WireSkillQualitySuggestion>,
    pub(super) prompt_request: WireSkillQualityPromptRequest,
    pub(super) safety_flags: WireSkillQualitySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualityScoreComponent {
    pub(super) id: String,
    pub(super) label: String,
    pub(super) score: u8,
    pub(super) max_score: u8,
    pub(super) summary: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualityEvidenceReference {
    pub(super) id: String,
    pub(super) source_type: String,
    pub(super) source_id: String,
    pub(super) label: String,
    pub(super) severity: Option<String>,
    pub(super) related_instance_id: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualitySuggestion {
    pub(super) priority: String,
    pub(super) title: String,
    pub(super) detail: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualityPromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillQualitySafetyFlags {
    pub(super) read_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftDetectionResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireStaleDriftFilters,
    pub(super) summary: WireStaleDriftSummary,
    pub(super) stale_drift_rows: Vec<WireStaleDriftRow>,
    pub(super) readiness_impact_rows: Vec<WireStaleDriftReadinessImpactRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftFilters {
    pub(super) agent: Option<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) limit: usize,
    pub(super) stale_days: u32,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftSummary {
    pub(super) scanned_skill_count: usize,
    pub(super) returned_row_count: usize,
    pub(super) stale_count: usize,
    pub(super) drift_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) medium_risk_count: usize,
    pub(super) low_risk_count: usize,
    pub(super) missing_history_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftRow {
    pub(super) rank: usize,
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) stale_drift_score: u8,
    pub(super) stale_drift_band: String,
    pub(super) drift_signals: WireStaleDriftSignals,
    pub(super) readiness_impact: Option<WireStaleDriftReadinessImpact>,
    pub(super) reasons: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftSignals {
    pub(super) fingerprint_drift: bool,
    pub(super) finding_drift: bool,
    pub(super) source_drift: bool,
    pub(super) modified_age_days: Option<i64>,
    pub(super) stale_by_mtime: bool,
    pub(super) missing_mtime: bool,
    pub(super) missing_previous_scan: bool,
    pub(super) related_finding_count: usize,
    pub(super) related_conflict_count: usize,
    pub(super) related_analysis_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftReadinessImpact {
    pub(super) impact_level: String,
    pub(super) readiness_risk_score: u8,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireStaleDriftReadinessImpactRow {
    pub(super) instance_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) impact_level: String,
    pub(super) stale_drift_score: u8,
    pub(super) notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) summary: WireKnowledgeSearchSummary,
    pub(super) filters: WireKnowledgeSearchFilters,
    pub(super) rows: Vec<WireKnowledgeSearchRow>,
    pub(super) facets: WireKnowledgeSearchFacets,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchSummary {
    pub(super) indexed_skill_count: usize,
    pub(super) matched_row_count: usize,
    pub(super) returned_row_count: usize,
    pub(super) enabled_count: usize,
    pub(super) disabled_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) stale_or_drift_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchFilters {
    pub(super) query: Option<String>,
    pub(super) normalized_terms: Vec<String>,
    pub(super) agent: Option<String>,
    pub(super) limit: usize,
    pub(super) risk: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) enabled: Option<bool>,
    pub(super) tool: Option<String>,
    pub(super) keyword: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchFacets {
    pub(super) agents: BTreeMap<String, usize>,
    pub(super) scopes: BTreeMap<String, usize>,
    pub(super) states: BTreeMap<String, usize>,
    pub(super) enabled: BTreeMap<String, usize>,
    pub(super) risks: BTreeMap<String, usize>,
    pub(super) tools: BTreeMap<String, usize>,
    pub(super) keywords: BTreeMap<String, usize>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchRow {
    pub(super) rank: usize,
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) source: WireKnowledgeSearchSource,
    pub(super) purpose_snippet: Option<String>,
    pub(super) description_snippet: Option<String>,
    pub(super) matched_fields: Vec<String>,
    pub(super) match_reasons: Vec<String>,
    pub(super) keywords: Vec<String>,
    pub(super) tools: Vec<String>,
    pub(super) rules: Vec<String>,
    pub(super) capability_tags: Vec<String>,
    pub(super) risk_tags: Vec<String>,
    pub(super) quality_context: Option<WireKnowledgeQualityContext>,
    pub(super) readiness_context: Option<WireKnowledgeReadinessContext>,
    pub(super) stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeSearchSource {
    pub(super) source_path: String,
    pub(super) display_path: String,
    pub(super) root_provenance: String,
    pub(super) fingerprint: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeQualityContext {
    pub(super) score: u8,
    pub(super) grade: String,
    pub(super) band: String,
    pub(super) reasons: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeReadinessContext {
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) risk_level: String,
    pub(super) risk_summary: String,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireKnowledgeStaleDriftContext {
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) fingerprint_drift: bool,
    pub(super) finding_drift: bool,
    pub(super) source_drift: bool,
    pub(super) stale_by_mtime: bool,
    pub(super) readiness_impact_level: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSimilarSkillGroupingResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireSimilarSkillGroupingFilters,
    pub(super) summary: WireSimilarSkillGroupingSummary,
    pub(super) groups: Vec<WireSimilarSkillGroup>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSimilarSkillGroupingFilters {
    pub(super) agent: Option<String>,
    pub(super) limit: usize,
    pub(super) min_score: u8,
    pub(super) include_singletons: bool,
    pub(super) candidate_instance_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSimilarSkillGroupingSummary {
    pub(super) indexed_skill_count: usize,
    pub(super) candidate_skill_count: usize,
    pub(super) matched_group_count: usize,
    pub(super) returned_group_count: usize,
    pub(super) duplicate_group_count: usize,
    pub(super) confusable_group_count: usize,
    pub(super) coverage_redundancy_group_count: usize,
    pub(super) routing_ambiguity_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSimilarSkillGroup {
    pub(super) group_id: String,
    pub(super) rank: usize,
    pub(super) group_type: String,
    pub(super) similarity_score: u8,
    pub(super) ambiguity_risk: String,
    pub(super) coverage_redundancy: String,
    pub(super) routing_ambiguity: String,
    pub(super) canonical_name: String,
    pub(super) canonical_key: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) why_grouped: Vec<String>,
    pub(super) shared_terms: Vec<String>,
    pub(super) shared_tools: Vec<String>,
    pub(super) shared_rules: Vec<String>,
    pub(super) shared_capability_tags: Vec<String>,
    pub(super) shared_risk_tags: Vec<String>,
    pub(super) shared_source_signals: Vec<String>,
    pub(super) members: Vec<WireSimilarSkillMember>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSimilarSkillMember {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) source: WireKnowledgeSearchSource,
    pub(super) quality_context: Option<WireKnowledgeQualityContext>,
    pub(super) readiness_context: Option<WireKnowledgeReadinessContext>,
    pub(super) stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
    pub(super) match_reasons: Vec<String>,
    pub(super) similarity_reasons: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityTaxonomyResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireCapabilityTaxonomyFilters,
    pub(super) summary: WireCapabilityTaxonomySummary,
    pub(super) domains: Vec<WireCapabilityDomainRow>,
    pub(super) coverage_rows: Vec<WireCapabilityCoverageRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityTaxonomyFilters {
    pub(super) agent: Option<String>,
    pub(super) limit: usize,
    pub(super) include_single_skill_domains: bool,
    pub(super) candidate_instance_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityTaxonomySummary {
    pub(super) indexed_skill_count: usize,
    pub(super) candidate_skill_count: usize,
    pub(super) domain_count: usize,
    pub(super) returned_domain_count: usize,
    pub(super) total_representative_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) workspace_count: usize,
    pub(super) duplicate_or_redundant_domain_count: usize,
    pub(super) routing_ambiguity_domain_count: usize,
    pub(super) gap_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityDomainRow {
    pub(super) domain_id: String,
    pub(super) rank: usize,
    pub(super) domain_key: String,
    pub(super) domain_name: String,
    pub(super) coverage_level: String,
    pub(super) coverage_score: u8,
    pub(super) skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) disabled_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) workspace_count: usize,
    pub(super) agents: BTreeMap<String, usize>,
    pub(super) workspaces: BTreeMap<String, usize>,
    pub(super) duplicate_or_redundant_count: usize,
    pub(super) routing_ambiguity_count: usize,
    pub(super) representative_skills: Vec<WireCapabilityRepresentativeSkill>,
    pub(super) capability_tags: Vec<String>,
    pub(super) risk_tags: Vec<String>,
    pub(super) tools: Vec<String>,
    pub(super) rules: Vec<String>,
    pub(super) keywords: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityCoverageRow {
    pub(super) domain_key: String,
    pub(super) domain_name: String,
    pub(super) coverage_level: String,
    pub(super) coverage_score: u8,
    pub(super) skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) workspace_count: usize,
    pub(super) agents: BTreeMap<String, usize>,
    pub(super) gaps: Vec<String>,
    pub(super) duplicates_redundancy: String,
    pub(super) routing_ambiguity: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCapabilityRepresentativeSkill {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) source: WireKnowledgeSearchSource,
    pub(super) quality_context: Option<WireKnowledgeQualityContext>,
    pub(super) stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
    pub(super) similarity_group_ids: Vec<String>,
    pub(super) match_reasons: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireLocalSkillMapFilters,
    pub(super) summary: WireLocalSkillMapSummary,
    pub(super) nodes: Vec<WireLocalSkillMapNode>,
    pub(super) edges: Vec<WireLocalSkillMapEdge>,
    pub(super) clusters: Vec<WireLocalSkillMapCluster>,
    pub(super) domains: Vec<WireLocalSkillMapDomain>,
    pub(super) risk_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapFilters {
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) limit: usize,
    pub(super) node_limit: usize,
    pub(super) edge_limit: usize,
    pub(super) cluster_limit: usize,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) include_task_context: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapSummary {
    pub(super) indexed_skill_count: usize,
    pub(super) candidate_skill_count: usize,
    pub(super) returned_node_count: usize,
    pub(super) returned_edge_count: usize,
    pub(super) cluster_count: usize,
    pub(super) returned_cluster_count: usize,
    pub(super) domain_count: usize,
    pub(super) skill_node_count: usize,
    pub(super) capability_node_count: usize,
    pub(super) similar_group_node_count: usize,
    pub(super) conflict_node_count: usize,
    pub(super) risk_node_count: usize,
    pub(super) task_coverage_edge_count: usize,
    pub(super) cross_agent_edge_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapNode {
    pub(super) id: String,
    pub(super) node_type: String,
    pub(super) rank: usize,
    pub(super) label: String,
    pub(super) summary: String,
    pub(super) weight: u8,
    pub(super) agent: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) enabled: Option<bool>,
    pub(super) state: Option<String>,
    pub(super) source: Option<WireKnowledgeSearchSource>,
    pub(super) risk_level: Option<String>,
    pub(super) tags: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapEdge {
    pub(super) id: String,
    pub(super) edge_type: String,
    pub(super) source: String,
    pub(super) target: String,
    pub(super) label: String,
    pub(super) weight: u8,
    pub(super) reasons: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapCluster {
    pub(super) id: String,
    pub(super) cluster_type: String,
    pub(super) label: String,
    pub(super) summary: String,
    pub(super) score: u8,
    pub(super) risk_level: String,
    pub(super) node_ids: Vec<String>,
    pub(super) edge_ids: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLocalSkillMapDomain {
    pub(super) domain_id: String,
    pub(super) domain_key: String,
    pub(super) domain_name: String,
    pub(super) coverage_level: String,
    pub(super) coverage_score: u8,
    pub(super) node_ids: Vec<String>,
    pub(super) skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireWorkspaceReadinessFilters,
    pub(super) summary: WireWorkspaceReadinessSummary,
    pub(super) readiness_rows: Vec<WireWorkspaceReadinessChecklistRow>,
    pub(super) checklist_rows: Vec<WireWorkspaceReadinessChecklistRow>,
    pub(super) agent_rows: Vec<WireWorkspaceReadinessAgentRow>,
    pub(super) capability_rows: Vec<WireWorkspaceReadinessCapabilityRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessFilters {
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) expected_capabilities: Vec<String>,
    pub(super) limit: usize,
    pub(super) candidate_instance_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessSummary {
    pub(super) workspace_available: bool,
    pub(super) project_available: bool,
    pub(super) visible_skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) domain_count: usize,
    pub(super) capability_count: usize,
    pub(super) ready_count: usize,
    pub(super) partial_count: usize,
    pub(super) blocked_count: usize,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessChecklistRow {
    pub(super) id: String,
    pub(super) category: String,
    pub(super) status: String,
    pub(super) score: u8,
    pub(super) title: String,
    pub(super) detail: String,
    pub(super) agent: Option<String>,
    pub(super) capability: Option<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessAgentRow {
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) status: String,
    pub(super) score: u8,
    pub(super) visible_skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) project_skill_count: usize,
    pub(super) best_candidate: Option<WireAgentReadinessBestCandidate>,
    pub(super) adapter_status: Option<String>,
    pub(super) writable_status: Option<String>,
    pub(super) install_status: Option<String>,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireWorkspaceReadinessCapabilityRow {
    pub(super) capability: String,
    pub(super) domain_key: String,
    pub(super) domain_name: String,
    pub(super) status: String,
    pub(super) coverage_level: String,
    pub(super) coverage_score: u8,
    pub(super) expected: bool,
    pub(super) skill_count: usize,
    pub(super) enabled_skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAggregationRuntimeMetadata {
    pub(super) status: String,
    pub(super) elapsed_ms: u64,
    pub(super) timeout_ms: u64,
    pub(super) timed_out: bool,
    pub(super) partial: bool,
    pub(super) fallback_used: bool,
    pub(super) limit: usize,
    pub(super) scanned_count: usize,
    pub(super) total_count: usize,
    pub(super) completed_stages: Vec<String>,
    pub(super) skipped_stages: Vec<String>,
    pub(super) blocker_codes: Vec<String>,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPlanResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireRemediationPlanFilters,
    pub(super) summary: WireRemediationPlanSummary,
    pub(super) plan_items: Vec<WireRemediationPlanItem>,
    pub(super) priority_rows: Vec<WireRemediationPriorityRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPlanFilters {
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) focus_areas: Vec<String>,
    pub(super) limit: usize,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) include_deferred: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPlanSummary {
    pub(super) total_item_count: usize,
    pub(super) returned_item_count: usize,
    pub(super) high_priority_count: usize,
    pub(super) medium_priority_count: usize,
    pub(super) low_priority_count: usize,
    pub(super) deferred_count: usize,
    pub(super) finding_item_count: usize,
    pub(super) gap_item_count: usize,
    pub(super) ambiguity_item_count: usize,
    pub(super) drift_item_count: usize,
    pub(super) readiness_item_count: usize,
    pub(super) policy_item_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPlanItem {
    pub(super) id: String,
    pub(super) rank: usize,
    pub(super) priority: String,
    pub(super) severity: String,
    pub(super) category: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) detail: String,
    pub(super) affected_agent: Option<String>,
    pub(super) affected_skill: Option<WireRemediationAffectedSkill>,
    pub(super) affected_capability: Option<String>,
    pub(super) affected_task: Option<String>,
    pub(super) affected_instance_ids: Vec<String>,
    pub(super) suggested_safe_next_action: String,
    pub(super) prerequisites: Vec<String>,
    pub(super) blockers: Vec<String>,
    pub(super) deferred: bool,
    pub(super) evidence_refs: Vec<String>,
    pub(super) side_effect_flags: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationAffectedSkill {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPriorityRow {
    pub(super) priority: String,
    pub(super) severity: String,
    pub(super) item_count: usize,
    pub(super) category_counts: BTreeMap<String, usize>,
    pub(super) top_item_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewDraftsResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireRemediationPreviewDraftsFilters,
    pub(super) summary: WireRemediationPreviewDraftsSummary,
    pub(super) draft_items: Vec<WireRemediationDraftItem>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewDraftsFilters {
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) skill_ids: Vec<String>,
    pub(super) finding_ids: Vec<String>,
    pub(super) draft_types: Vec<String>,
    pub(super) limit: usize,
    pub(super) include_policy_drafts: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewDraftsSummary {
    pub(super) total_draft_count: usize,
    pub(super) returned_draft_count: usize,
    pub(super) frontmatter_count: usize,
    pub(super) description_count: usize,
    pub(super) permissions_count: usize,
    pub(super) dependency_count: usize,
    pub(super) policy_count: usize,
    pub(super) high_confidence_count: usize,
    pub(super) medium_confidence_count: usize,
    pub(super) low_confidence_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationDraftItem {
    pub(super) id: String,
    pub(super) rank: usize,
    pub(super) title: String,
    pub(super) draft_type: String,
    pub(super) agent: Option<String>,
    pub(super) affected_skill: Option<WireRemediationAffectedSkill>,
    pub(super) finding_id: Option<String>,
    pub(super) rule_id: Option<String>,
    pub(super) current_text: Option<String>,
    pub(super) proposed_text: String,
    pub(super) patch_like_snippet: String,
    pub(super) rationale: String,
    pub(super) confidence: u8,
    pub(super) confidence_band: String,
    pub(super) copy_label: String,
    pub(super) edit_guidance: String,
    pub(super) evidence_refs: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) side_effect_flags: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewImpactResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireRemediationPreviewImpactFilters,
    pub(super) summary: WireRemediationPreviewImpactSummary,
    pub(super) impact_rows: Vec<WireRemediationImpactRow>,
    pub(super) task_impact_rows: Vec<WireRemediationTaskImpactRow>,
    pub(super) agent_impact_rows: Vec<WireRemediationAgentImpactRow>,
    pub(super) skill_impact_rows: Vec<WireRemediationSkillImpactRow>,
    pub(super) risk_delta_rows: Vec<WireRemediationRiskDeltaRow>,
    pub(super) snapshot_rollback_plan_rows: Vec<WireRemediationSnapshotRollbackPlanRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewImpactFilters {
    pub(super) action: String,
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) skill_ids: Vec<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) draft_ids: Vec<String>,
    pub(super) plan_item_ids: Vec<String>,
    pub(super) limit: usize,
    pub(super) include_snapshot_plan: bool,
    pub(super) include_rollback_plan: bool,
    pub(super) include_risk_impact: bool,
    pub(super) include_task_impact: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationPreviewImpactSummary {
    pub(super) total_impact_count: usize,
    pub(super) returned_impact_count: usize,
    pub(super) task_impact_count: usize,
    pub(super) agent_impact_count: usize,
    pub(super) skill_impact_count: usize,
    pub(super) risk_delta_count: usize,
    pub(super) snapshot_plan_count: usize,
    pub(super) rollback_plan_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationImpactRow {
    pub(super) id: String,
    pub(super) rank: usize,
    pub(super) area: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) action_intent: String,
    pub(super) expected_direction: String,
    pub(super) confidence: u8,
    pub(super) confidence_band: String,
    pub(super) affected_agent: Option<String>,
    pub(super) affected_skill: Option<WireRemediationAffectedSkill>,
    pub(super) affected_task: Option<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) blockers: Vec<String>,
    pub(super) side_effect_flags: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationTaskImpactRow {
    pub(super) task: String,
    pub(super) action_intent: String,
    pub(super) expected_direction: String,
    pub(super) readiness_score_before: Option<u8>,
    pub(super) readiness_score_after_estimate: Option<u8>,
    pub(super) routing_confidence_before: Option<u8>,
    pub(super) routing_confidence_after_estimate: Option<u8>,
    pub(super) notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationAgentImpactRow {
    pub(super) agent: String,
    pub(super) action_intent: String,
    pub(super) expected_direction: String,
    pub(super) impacted_skill_count: usize,
    pub(super) enabled_before_count: usize,
    pub(super) enabled_after_estimate_count: usize,
    pub(super) writable_status: Option<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationSkillImpactRow {
    pub(super) affected_skill: WireRemediationAffectedSkill,
    pub(super) action_intent: String,
    pub(super) expected_direction: String,
    pub(super) enabled_before: bool,
    pub(super) enabled_after_estimate: bool,
    pub(super) finding_count: usize,
    pub(super) conflict_count: usize,
    pub(super) analysis_count: usize,
    pub(super) notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationRiskDeltaRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) severity: String,
    pub(super) title: String,
    pub(super) current_risk: String,
    pub(super) expected_risk_after: String,
    pub(super) expected_direction: String,
    pub(super) affected_instance_ids: Vec<String>,
    pub(super) blockers: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationSnapshotRollbackPlanRow {
    pub(super) id: String,
    pub(super) agent: String,
    pub(super) instance_id: String,
    pub(super) skill_name: String,
    pub(super) action_intent: String,
    pub(super) snapshot_required: bool,
    pub(super) rollback_available: bool,
    pub(super) verified_writable: bool,
    pub(super) blocked_reason: Option<String>,
    pub(super) plan_only: bool,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationBatchReviewResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireRemediationBatchReviewFilters,
    pub(super) summary: WireRemediationBatchReviewSummary,
    pub(super) review_groups: Vec<WireRemediationBatchReviewGroup>,
    pub(super) review_items: Vec<WireRemediationBatchReviewItem>,
    pub(super) recommended_next_step_labels: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationBatchReviewFilters {
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) workspace_label: Option<String>,
    pub(super) rule_id: Option<String>,
    pub(super) severity: Option<String>,
    pub(super) status: Option<String>,
    pub(super) triage_status: Option<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) group_by: Vec<String>,
    pub(super) limit: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationBatchReviewSummary {
    pub(super) total_item_count: usize,
    pub(super) returned_item_count: usize,
    pub(super) group_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) medium_risk_count: usize,
    pub(super) low_risk_count: usize,
    pub(super) task_group_count: usize,
    pub(super) agent_group_count: usize,
    pub(super) workspace_group_count: usize,
    pub(super) rule_group_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationBatchReviewGroup {
    pub(super) id: String,
    pub(super) group_type: String,
    pub(super) label: String,
    pub(super) item_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) medium_risk_count: usize,
    pub(super) low_risk_count: usize,
    pub(super) top_item_ids: Vec<String>,
    pub(super) recommended_next_step_label: String,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationBatchReviewItem {
    pub(super) id: String,
    pub(super) rank: usize,
    pub(super) source: String,
    pub(super) source_id: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) risk: String,
    pub(super) severity: String,
    pub(super) status: String,
    pub(super) triage_status: Option<String>,
    pub(super) rule_id: Option<String>,
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) workspace: Option<String>,
    pub(super) affected_skill: Option<WireRemediationAffectedSkill>,
    pub(super) affected_instance_ids: Vec<String>,
    pub(super) recommended_next_step_label: String,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) side_effect_flags: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessResult {
    pub(super) task: String,
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) summary: String,
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireTaskReadinessFilters,
    pub(super) candidate_skills: Vec<WireTaskReadinessCandidate>,
    pub(super) missing_gap_notes: Vec<String>,
    pub(super) blocker_risk_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireTaskReadinessPromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireTaskReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessFilters {
    pub(super) agent: Option<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) limit: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessCandidate {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) quality_score: Option<u8>,
    pub(super) match_reasons: Vec<String>,
    pub(super) enabled_scope_risk_state: WireTaskReadinessState,
    pub(super) missing_gap_notes: Vec<String>,
    pub(super) blocker_risk_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessState {
    pub(super) enabled: bool,
    pub(super) scope: String,
    pub(super) state: String,
    pub(super) risk_level: String,
    pub(super) risk_summary: String,
    pub(super) writable_status: Option<String>,
    pub(super) adapter_status: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessEvidenceReference {
    pub(super) id: String,
    pub(super) source_type: String,
    pub(super) source_id: String,
    pub(super) label: String,
    pub(super) severity: Option<String>,
    pub(super) related_instance_id: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessPromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskReadinessSafetyFlags {
    pub(super) read_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillRouteRankingResult {
    pub(super) task: String,
    pub(super) overall_confidence_score: u8,
    pub(super) overall_confidence_band: String,
    pub(super) summary: String,
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireTaskReadinessFilters,
    pub(super) route_candidates: Vec<WireSkillRouteCandidate>,
    pub(super) ambiguity_warnings: Vec<String>,
    pub(super) likely_wrong_pick_risks: Vec<String>,
    pub(super) likely_miss_risks: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireRoutingConfidencePromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireRoutingConfidenceSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillRouteCandidate {
    pub(super) rank: usize,
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) confidence_score: u8,
    pub(super) confidence_band: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) quality_score: Option<u8>,
    pub(super) match_reasons: Vec<String>,
    pub(super) confidence_rationale: Vec<String>,
    pub(super) ambiguity_warnings: Vec<String>,
    pub(super) likely_wrong_pick_risks: Vec<String>,
    pub(super) likely_miss_risks: Vec<String>,
    pub(super) enabled_scope_risk_state: WireTaskReadinessState,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingConfidencePromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingConfidenceSafetyFlags {
    pub(super) read_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessComparisonResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireAgentReadinessComparisonFilters,
    pub(super) summary: WireAgentReadinessComparisonSummary,
    pub(super) agent_rows: Vec<WireAgentReadinessComparisonRow>,
    pub(super) recommended_agent: Option<WireAgentReadinessRecommendation>,
    pub(super) gap_issue_rows: Vec<WireAgentReadinessGapIssueRow>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessComparisonFilters {
    pub(super) agents: Vec<String>,
    pub(super) limit_per_agent: usize,
    pub(super) include_routing_accuracy: bool,
    pub(super) include_benchmarks: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessComparisonSummary {
    pub(super) agent_count: usize,
    pub(super) candidate_count: usize,
    pub(super) ready_agent_count: usize,
    pub(super) partial_agent_count: usize,
    pub(super) blocked_agent_count: usize,
    pub(super) gap_issue_count: usize,
    pub(super) recommended_agent: Option<String>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessComparisonRow {
    pub(super) rank: usize,
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) comparison_score: u8,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) candidate_count: usize,
    pub(super) best_candidate: Option<WireAgentReadinessBestCandidate>,
    pub(super) enabled_scope_risk_state: Option<WireTaskReadinessState>,
    pub(super) blocker_count: usize,
    pub(super) gap_count: usize,
    pub(super) reasons: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) routing_accuracy_context: Option<WireAgentReadinessAccuracyContext>,
    pub(super) benchmark_context: Option<WireAgentReadinessBenchmarkContext>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessBestCandidate {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) quality_score: Option<u8>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessAccuracyContext {
    pub(super) trace_count: usize,
    pub(super) accuracy_rate: f64,
    pub(super) benchmark_count: usize,
    pub(super) benchmark_gap_count: usize,
    pub(super) regression_count: usize,
    pub(super) recent_evidence_count: usize,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessBenchmarkContext {
    pub(super) evaluated_count: usize,
    pub(super) matched_count: usize,
    pub(super) gap_count: usize,
    pub(super) regression_count: usize,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessRecommendation {
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) comparison_score: u8,
    pub(super) readiness_score: u8,
    pub(super) routing_confidence_score: u8,
    pub(super) skill_name: Option<String>,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessGapIssueRow {
    pub(super) source: String,
    pub(super) severity: String,
    pub(super) agent: String,
    pub(super) title: String,
    pub(super) detail: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessPromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentReadinessSafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) partial: bool,
    pub(super) elapsed_ms: u64,
    pub(super) fallback_reason: Option<String>,
    pub(super) filters: WireTaskCockpitFilters,
    pub(super) summary: WireTaskCockpitSummary,
    pub(super) cockpit_sections: Vec<WireTaskCockpitSection>,
    pub(super) task_rows: Vec<WireTaskCockpitTaskRow>,
    pub(super) agent_route_rows: Vec<WireTaskCockpitAgentRouteRow>,
    pub(super) skill_candidate_rows: Vec<WireTaskCockpitSkillCandidateRow>,
    pub(super) readiness_rows: Vec<WireTaskCockpitReadinessRow>,
    pub(super) session_review_rows: Vec<WireTaskCockpitSessionReviewRow>,
    pub(super) provider_observability_rows: Vec<WireTaskCockpitProviderObservabilityRow>,
    pub(super) remediation_next_steps: Vec<WireTaskCockpitRemediationNextStep>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) aggregation: WireAggregationRuntimeMetadata,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitFilters {
    pub(super) task: String,
    pub(super) agent: Option<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) limit: usize,
    pub(super) include_session_review: bool,
    pub(super) include_provider_observability: bool,
    pub(super) include_remediation_context: bool,
    pub(super) timeout_ms: u64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitSummary {
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) candidate_count: usize,
    pub(super) agent_count: usize,
    pub(super) session_review_count: usize,
    pub(super) provider_observability_row_count: usize,
    pub(super) remediation_next_step_count: usize,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) recommended_agent: Option<String>,
    pub(super) top_skill_name: Option<String>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitSection {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) status: String,
    pub(super) score: Option<u8>,
    pub(super) row_count: usize,
    pub(super) summary: String,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitTaskRow {
    pub(super) id: String,
    pub(super) task: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) recommended_agent: Option<String>,
    pub(super) top_skill_name: Option<String>,
    pub(super) candidate_count: usize,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitAgentRouteRow {
    pub(super) rank: usize,
    pub(super) agent: String,
    pub(super) display_name: String,
    pub(super) comparison_score: u8,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) best_skill_name: Option<String>,
    pub(super) blocker_count: usize,
    pub(super) gap_count: usize,
    pub(super) reasons: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitSkillCandidateRow {
    pub(super) rank: usize,
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
    pub(super) routing_confidence_score: u8,
    pub(super) routing_confidence_band: String,
    pub(super) quality_score: Option<u8>,
    pub(super) match_reasons: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitReadinessRow {
    pub(super) id: String,
    pub(super) row_type: String,
    pub(super) label: String,
    pub(super) status: String,
    pub(super) score: Option<u8>,
    pub(super) summary: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitSessionReviewRow {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) outcome: String,
    pub(super) summary: String,
    pub(super) detected_skill_count: usize,
    pub(super) expected_skill_signal_count: usize,
    pub(super) reviewed_at: i64,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitProviderObservabilityRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) status: String,
    pub(super) provider: Option<String>,
    pub(super) model: Option<String>,
    pub(super) action: Option<String>,
    pub(super) count: usize,
    pub(super) message: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskCockpitRemediationNextStep {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) priority: String,
    pub(super) title: String,
    pub(super) suggested_safe_next_action: String,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleTimelineResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireSkillLifecycleTimelineFilters,
    pub(super) summary: WireSkillLifecycleTimelineSummary,
    pub(super) timeline_rows: Vec<WireSkillLifecycleTimelineRow>,
    pub(super) skill_rows: Vec<WireSkillLifecycleSkillRow>,
    pub(super) agent_rows: Vec<WireSkillLifecycleAgentRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleTimelineFilters {
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) selected_skill_id: Option<String>,
    pub(super) selected_skill_name: Option<String>,
    pub(super) selected_skill_agent: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) current_cwd: Option<String>,
    pub(super) workspace: Option<String>,
    pub(super) limit: usize,
    pub(super) include_prompt_runs: bool,
    pub(super) include_session_reviews: bool,
    pub(super) include_remediation_history: bool,
    pub(super) include_stale_drift: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleTimelineSummary {
    pub(super) total_event_count: usize,
    pub(super) skill_count: usize,
    pub(super) agent_count: usize,
    pub(super) finding_event_count: usize,
    pub(super) drift_event_count: usize,
    pub(super) remediation_event_count: usize,
    pub(super) prompt_event_count: usize,
    pub(super) session_review_event_count: usize,
    pub(super) first_event_at: Option<i64>,
    pub(super) latest_event_at: Option<i64>,
    pub(super) selected_skill_name: Option<String>,
    pub(super) selected_agent: Option<String>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleTimelineRow {
    pub(super) id: String,
    pub(super) occurred_at: Option<i64>,
    pub(super) event_type: String,
    pub(super) lifecycle_stage: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) agent: Option<String>,
    pub(super) skill_name: Option<String>,
    pub(super) instance_id: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) source: String,
    pub(super) severity: Option<String>,
    pub(super) status: Option<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleSkillRow {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) state: String,
    pub(super) event_count: usize,
    pub(super) finding_event_count: usize,
    pub(super) drift_event_count: usize,
    pub(super) remediation_event_count: usize,
    pub(super) prompt_event_count: usize,
    pub(super) session_review_event_count: usize,
    pub(super) first_event_at: Option<i64>,
    pub(super) latest_event_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillLifecycleAgentRow {
    pub(super) agent: String,
    pub(super) skill_count: usize,
    pub(super) event_count: usize,
    pub(super) finding_event_count: usize,
    pub(super) drift_event_count: usize,
    pub(super) remediation_event_count: usize,
    pub(super) prompt_event_count: usize,
    pub(super) session_review_event_count: usize,
    pub(super) first_event_at: Option<i64>,
    pub(super) latest_event_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireAgentReadinessSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkRecord {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) task: String,
    pub(super) expected_skill_refs: Vec<String>,
    pub(super) expected_skill_names: Vec<String>,
    pub(super) acceptable_agents: Vec<String>,
    pub(super) acceptable_scopes: Vec<String>,
    pub(super) success_criteria: Vec<String>,
    pub(super) created_at: i64,
    pub(super) updated_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkListResult {
    pub(super) benchmarks: Vec<WireTaskBenchmarkRecord>,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSaveTaskBenchmarkResult {
    pub(super) benchmark: WireTaskBenchmarkRecord,
    pub(super) created: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) agent_config_mutated: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireDeleteTaskBenchmarkResult {
    pub(super) benchmark_id: String,
    pub(super) deleted: bool,
    pub(super) remaining_count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) agent_config_mutated: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkEvaluationResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) evaluated_count: usize,
    pub(super) summary: String,
    pub(super) benchmark_results: Vec<WireTaskBenchmarkEvaluationItem>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) prompt_request: WireTaskBenchmarkPromptRequest,
    pub(super) safety_flags: WireTaskBenchmarkSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkEvaluationItem {
    pub(super) benchmark_id: String,
    pub(super) title: String,
    pub(super) task: String,
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) expected_match_status: String,
    pub(super) expected_match_reasons: Vec<String>,
    pub(super) top_route: Option<WireTaskBenchmarkRouteSummary>,
    pub(super) route_confidence_score: u8,
    pub(super) route_confidence_band: String,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireTaskBenchmarkSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkRouteSummary {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) confidence_score: u8,
    pub(super) confidence_band: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkPromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTaskBenchmarkSafetyFlags {
    pub(super) read_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSaveRoutingBaselineResult {
    pub(super) generated_by: String,
    pub(super) baseline: WireRoutingRegressionBaseline,
    pub(super) benchmark_count: usize,
    pub(super) app_local_only: bool,
    pub(super) baseline_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionDetectionResult {
    pub(super) generated_by: String,
    pub(super) status: String,
    pub(super) baseline_available: bool,
    pub(super) catalog_available: bool,
    pub(super) baseline_evaluated_count: usize,
    pub(super) current_evaluated_count: usize,
    pub(super) regression_count: usize,
    pub(super) missing_benchmark_count: usize,
    pub(super) summary: String,
    pub(super) items: Vec<WireRoutingRegressionItem>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) baseline: Option<WireRoutingRegressionBaseline>,
    pub(super) current_evaluation: WireTaskBenchmarkEvaluationResult,
    pub(super) safety_flags: WireTaskBenchmarkSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionItem {
    pub(super) benchmark_id: String,
    pub(super) title: String,
    pub(super) status: String,
    pub(super) regression: bool,
    pub(super) reasons: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) score_delta: Option<i16>,
    pub(super) confidence_delta: Option<i16>,
    pub(super) baseline: Option<WireRoutingRegressionComparisonFields>,
    pub(super) current: Option<WireRoutingRegressionComparisonFields>,
    pub(super) safety_flags: WireTaskBenchmarkSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionBaseline {
    pub(super) schema_version: u32,
    pub(super) generated_by: String,
    pub(super) generated_at: i64,
    pub(super) catalog_available: bool,
    pub(super) evaluated_count: usize,
    pub(super) benchmark_results: Vec<WireRoutingRegressionBaselineItem>,
    pub(super) safety_flags: WireTaskBenchmarkSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionBaselineItem {
    pub(super) benchmark_id: String,
    pub(super) title: String,
    pub(super) task: String,
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) expected_match_status: String,
    pub(super) top_route: Option<WireRoutingRegressionRouteSnapshot>,
    pub(super) route_confidence_score: u8,
    pub(super) route_confidence_band: String,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionRouteSnapshot {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) confidence_score: u8,
    pub(super) confidence_band: String,
    pub(super) readiness_score: u8,
    pub(super) readiness_band: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingRegressionComparisonFields {
    pub(super) task: String,
    pub(super) expected_match_status: String,
    pub(super) score: u8,
    pub(super) band: String,
    pub(super) top_route: Option<WireRoutingRegressionRouteSnapshot>,
    pub(super) route_confidence_score: u8,
    pub(super) route_confidence_band: String,
    pub(super) gap_count: usize,
    pub(super) blocker_count: usize,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyDashboardResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireRoutingAccuracyDashboardFilters,
    pub(super) summary: WireRoutingAccuracyDashboardSummary,
    pub(super) agent_rows: Vec<WireRoutingAccuracyAgentRow>,
    pub(super) history_rows: Vec<WireRoutingAccuracyHistoryRow>,
    pub(super) gap_issue_rows: Vec<WireRoutingAccuracyIssueRow>,
    pub(super) recent_evidence_rows: Vec<WireRoutingAccuracyEvidenceRow>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) prompt_request: WireRoutingAccuracyPromptRequest,
    pub(super) safety_flags: WireRoutingAccuracySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyDashboardFilters {
    pub(super) agent: Option<String>,
    pub(super) window_days: u32,
    pub(super) limit: usize,
    pub(super) include_history: bool,
    pub(super) include_recent_evidence: bool,
    pub(super) window_start_millis: i64,
    pub(super) window_end_millis: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyDashboardSummary {
    pub(super) trace_count: usize,
    pub(super) hit_count: usize,
    pub(super) miss_count: usize,
    pub(super) wrong_pick_count: usize,
    pub(super) ambiguous_count: usize,
    pub(super) unknown_count: usize,
    pub(super) benchmark_count: usize,
    pub(super) benchmark_matched_count: usize,
    pub(super) benchmark_gap_count: usize,
    pub(super) regression_count: usize,
    pub(super) missing_benchmark_count: usize,
    pub(super) accuracy_rate: f64,
    pub(super) known_outcome_rate: f64,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyOutcomeCounts {
    pub(super) hit: usize,
    pub(super) miss: usize,
    pub(super) wrong_pick: usize,
    pub(super) ambiguous: usize,
    pub(super) unknown: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyAgentRow {
    pub(super) agent: String,
    pub(super) trace_count: usize,
    pub(super) outcomes: WireRoutingAccuracyOutcomeCounts,
    pub(super) accuracy_rate: f64,
    pub(super) benchmark_count: usize,
    pub(super) benchmark_matched_count: usize,
    pub(super) benchmark_gap_count: usize,
    pub(super) regression_count: usize,
    pub(super) recent_evidence_count: usize,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyHistoryRow {
    pub(super) unix_day: i64,
    pub(super) trace_count: usize,
    pub(super) outcomes: WireRoutingAccuracyOutcomeCounts,
    pub(super) accuracy_rate: f64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyIssueRow {
    pub(super) source: String,
    pub(super) severity: String,
    pub(super) agent: Option<String>,
    pub(super) title: String,
    pub(super) detail: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyEvidenceRow {
    pub(super) source: String,
    pub(super) agent: Option<String>,
    pub(super) title: String,
    pub(super) outcome: Option<String>,
    pub(super) detail: String,
    pub(super) evidence_refs: Vec<String>,
    pub(super) observed_at: Option<i64>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracyPromptRequest {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) action: String,
    pub(super) request: LlmPreviewPromptParams,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRoutingAccuracySafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewRecord {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) source_kind: String,
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) trace_import_ids: Vec<String>,
    pub(super) missing_trace_import_ids: Vec<String>,
    pub(super) expected_skill_refs: Vec<String>,
    pub(super) expected_skill_names: Vec<String>,
    pub(super) excerpt: String,
    pub(super) excerpt_char_count: usize,
    pub(super) content_hash: String,
    pub(super) redaction_summary: WireAgentSessionSkillReviewRedactionSummary,
    pub(super) reviewed_at: i64,
    pub(super) analysis: WireAgentSessionSkillReviewAnalysis,
    pub(super) safety_flags: WireAgentSessionSkillReviewSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewAnalysis {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) outcome: String,
    pub(super) summary: String,
    pub(super) reasons: Vec<String>,
    pub(super) detected_skills: Vec<WireTraceDetectedSkill>,
    pub(super) expected_skill_signals: Vec<WireAgentSessionExpectedSkillSignal>,
    pub(super) referenced_traces: Vec<WireAgentSessionReferencedTrace>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionExpectedSkillSignal {
    pub(super) kind: String,
    pub(super) value: String,
    pub(super) matched: bool,
    pub(super) matched_instance_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionReferencedTrace {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) outcome: String,
    pub(super) imported_at: i64,
    pub(super) detected_skill_count: usize,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewRedactionSummary {
    pub(super) status: String,
    pub(super) redacted_value_count: usize,
    pub(super) redacted_fields: Vec<String>,
    pub(super) placeholders: Vec<String>,
    pub(super) raw_trace_persisted: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewSafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[rustfmt::skip]
pub(super) struct WireLocalSessionPreviewRoot { pub(super) root: String, pub(super) status: String, pub(super) candidate_count: usize, pub(super) blocker: Option<String> }

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[rustfmt::skip]
pub(super) struct WireLocalSessionContentItem { pub(super) id: String, pub(super) kind: String, pub(super) title: String, pub(super) text: String, pub(super) char_count: usize, pub(super) timestamp: Option<i64>, pub(super) evidence_refs: Vec<String> }

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[rustfmt::skip]
pub(super) struct WireLocalSessionPreviewRow {
    pub(super) id: String, pub(super) title: String, pub(super) source_kind: String,
    pub(super) agent: Option<String>, pub(super) redacted_path: String, pub(super) modified_at: Option<i64>,
    pub(super) started_at: Option<i64>, pub(super) ended_at: Option<i64>, pub(super) excerpt: String,
    pub(super) excerpt_char_count: usize, pub(super) user_message_count: usize,
    pub(super) total_message_count: usize, pub(super) tool_call_count: usize,
    pub(super) skill_call_count: usize, pub(super) content_hash: String,
    pub(super) evidence_refs: Vec<String>, pub(super) content_items: Vec<WireLocalSessionContentItem>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[rustfmt::skip]
pub(super) struct WireLocalSessionSkillUsageRow {
    pub(super) skill_id: String, pub(super) skill_name: String,
    pub(super) agent: String, pub(super) call_count: usize,
    pub(super) session_count: usize, pub(super) latest_modified_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[rustfmt::skip]
pub(super) struct WireLocalSessionPreviewResult {
    pub(super) generated_by: String, pub(super) authorized: bool,
    pub(super) authorization_required: bool, pub(super) roots: Vec<WireLocalSessionPreviewRoot>,
    pub(super) count: usize, pub(super) total_candidate_count: usize,
    pub(super) user_message_count: usize, pub(super) total_message_count: usize,
    pub(super) tool_call_count: usize, pub(super) skill_call_count: usize,
    pub(super) skill_usage_rows: Vec<WireLocalSessionSkillUsageRow>,
    pub(super) session_rows: Vec<WireLocalSessionPreviewRow>, pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) redaction_summary: WireAgentSessionSkillReviewRedactionSummary,
    pub(super) safety_flags: WireAgentSessionSkillReviewSafetyFlags, pub(super) read_only: bool,
    pub(super) provider_request_sent: bool, pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool, pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool, pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool, pub(super) raw_trace_persisted: bool,
}
#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewResult {
    pub(super) generated_by: String,
    pub(super) review: WireAgentSessionSkillReviewRecord,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) review_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewListResult {
    pub(super) generated_by: String,
    pub(super) count: usize,
    pub(super) total_count: usize,
    pub(super) reviews: Vec<WireAgentSessionSkillReviewRecord>,
    pub(super) app_local_only: bool,
    pub(super) review_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) safety_flags: WireAgentSessionSkillReviewSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentSessionSkillReviewDeleteResult {
    pub(super) review_id: String,
    pub(super) deleted: bool,
    pub(super) remaining_count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportRecord {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) source_kind: String,
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) expected_skill_refs: Vec<String>,
    pub(super) expected_skill_names: Vec<String>,
    pub(super) excerpt: String,
    pub(super) excerpt_char_count: usize,
    pub(super) redaction_summary: WireTraceImportRedactionSummary,
    pub(super) content_hash: String,
    pub(super) imported_at: i64,
    pub(super) analysis: WireTraceImportAnalysis,
    pub(super) safety_flags: WireTraceImportSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportRedactionSummary {
    pub(super) status: String,
    pub(super) redacted_value_count: usize,
    pub(super) redacted_fields: Vec<String>,
    pub(super) placeholders: Vec<String>,
    pub(super) raw_trace_persisted: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportAnalysis {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) outcome: String,
    pub(super) reasons: Vec<String>,
    pub(super) detected_skills: Vec<WireTraceDetectedSkill>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceDetectedSkill {
    pub(super) instance_id: String,
    pub(super) definition_id: String,
    pub(super) skill_name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) evidence_refs: Vec<String>,
    pub(super) match_terms: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportSafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportLocalResult {
    pub(super) generated_by: String,
    pub(super) import: WireTraceImportRecord,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) import_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceImportListResult {
    pub(super) imports: Vec<WireTraceImportRecord>,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTraceDeleteImportResult {
    pub(super) import_id: String,
    pub(super) deleted: bool,
    pub(super) remaining_count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryRecord {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) decision: String,
    pub(super) status: String,
    pub(super) source_kind: String,
    pub(super) source_method: Option<String>,
    pub(super) source_item_refs: Vec<String>,
    pub(super) batch_review_item_ids: Vec<String>,
    pub(super) agent: Option<String>,
    pub(super) workspace: Option<String>,
    pub(super) task: Option<String>,
    pub(super) rule_ids: Vec<String>,
    pub(super) risk_levels: Vec<String>,
    pub(super) recurrence_key: Option<String>,
    pub(super) recurrence_count_marker: Option<u32>,
    pub(super) reopened: bool,
    pub(super) reopened_from_ids: Vec<String>,
    pub(super) readiness_improvement_notes: Vec<String>,
    pub(super) routing_improvement_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) notes: Option<String>,
    pub(super) redaction_summary: WireRemediationHistoryRedactionSummary,
    pub(super) created_at: i64,
    pub(super) updated_at: i64,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryRedactionSummary {
    pub(super) status: String,
    pub(super) redacted_value_count: usize,
    pub(super) redacted_fields: Vec<String>,
    pub(super) placeholders: Vec<String>,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistorySafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) rollback_performed: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryListResult {
    pub(super) generated_by: String,
    pub(super) filters: WireRemediationHistoryFilters,
    pub(super) summary: WireRemediationHistorySummary,
    pub(super) records: Vec<WireRemediationHistoryRecord>,
    pub(super) recurrence_rows: Vec<WireRemediationHistoryRecurrenceRow>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) app_local_only: bool,
    pub(super) history_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryRecordResult {
    pub(super) generated_by: String,
    pub(super) record: WireRemediationHistoryRecord,
    pub(super) created: bool,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) history_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) rollback_performed: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryDeleteResult {
    pub(super) history_id: String,
    pub(super) deleted: bool,
    pub(super) remaining_count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) rollback_performed: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryFilters {
    pub(super) agent: Option<String>,
    pub(super) status: Option<String>,
    pub(super) decision: Option<String>,
    pub(super) source_item_ref: Option<String>,
    pub(super) recurrence_key: Option<String>,
    pub(super) limit: usize,
    pub(super) include_recurrence_rows: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistorySummary {
    pub(super) total_count: usize,
    pub(super) returned_count: usize,
    pub(super) decision_counts: BTreeMap<String, usize>,
    pub(super) status_counts: BTreeMap<String, usize>,
    pub(super) reopened_count: usize,
    pub(super) recurrence_group_count: usize,
    pub(super) blocker_count: usize,
    pub(super) readiness_improvement_count: usize,
    pub(super) routing_improvement_count: usize,
    pub(super) latest_recorded_at: Option<i64>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRemediationHistoryRecurrenceRow {
    pub(super) recurrence_key: String,
    pub(super) record_count: usize,
    pub(super) reopened_count: usize,
    pub(super) latest_status: String,
    pub(super) latest_decision: String,
    pub(super) latest_recorded_at: i64,
    pub(super) source_item_refs: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScanResult {
    pub(super) scanned_count: usize,
    pub(super) skills: Vec<WireSkillRecord>,
    pub(super) activity: WireRefreshActivity,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRefreshStatus {
    pub(super) scan_progress: String,
    pub(super) watcher_state: String,
    pub(super) watcher_detail: String,
    pub(super) recovery_actions: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmStatus {
    pub(super) enabled: bool,
    pub(super) configured: bool,
    pub(super) provider: Option<String>,
    pub(super) model: Option<String>,
    pub(super) reason: String,
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) credentials_storage: String,
    pub(super) credential_persistence_allowed: bool,
    pub(super) provider_profile_count: usize,
    pub(super) default_profile_id: Option<String>,
    pub(super) profiles_path: String,
    pub(super) call_metadata_path: String,
    pub(super) raw_prompt_persistence_allowed: bool,
    pub(super) raw_response_persistence_allowed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireListProviderProfilesResult {
    pub(super) profiles: Vec<WireProviderProfileRecord>,
    pub(super) default_profile_id: Option<String>,
    pub(super) credential_storage: String,
    pub(super) credential_persistence_allowed: bool,
    pub(super) raw_secrets_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSaveProviderProfileResult {
    pub(super) profile: WireProviderProfileRecord,
    pub(super) credential_status: WireProviderCredentialStatus,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireDeleteProviderProfileResult {
    pub(super) deleted_profile_id: String,
    pub(super) profile_deleted: bool,
    pub(super) credential_deleted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireTestProviderConnectionResult {
    pub(super) profile_id: String,
    pub(super) provider_type: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) status: String,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) duration_ms: u128,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) budget: WireProviderBudgetStatus,
    pub(super) audit: WireProviderCallMetadata,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProviderProfileRecord {
    pub(super) id: String,
    pub(super) display_name: String,
    pub(super) provider_type: String,
    pub(super) base_url: String,
    pub(super) model: String,
    pub(super) enabled: bool,
    pub(super) api_version: Option<String>,
    pub(super) organization: Option<String>,
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) credential_reference: WireProviderCredentialReference,
    pub(super) credential_status: WireProviderCredentialStatus,
    pub(super) created_at: i64,
    pub(super) updated_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProviderCredentialReference {
    pub(super) storage: String,
    pub(super) service: String,
    pub(super) account: String,
    pub(super) secret_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProviderCredentialStatus {
    pub(super) state: String,
    pub(super) reason: String,
    pub(super) secret_available: bool,
    pub(super) fallback_available: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProviderBudgetStatus {
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) estimated_test_tokens: u32,
    pub(super) estimated_test_cost_usd: f64,
    pub(super) state: String,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProviderCallMetadata {
    pub(super) timestamp: i64,
    pub(super) action_type: String,
    pub(super) profile_id: String,
    pub(super) provider_type: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) status: String,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) duration_ms: u128,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) confirmation_id: String,
    pub(super) redaction_status: String,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionStatus {
    pub(super) enabled: bool,
    pub(super) default_enabled: bool,
    pub(super) reason: String,
    pub(super) audit_scope: String,
    pub(super) audit_path: String,
    pub(super) llm_initiation_allowed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPrepareActionResult {
    pub(super) action: String,
    pub(super) allowed: bool,
    pub(super) reason: String,
    pub(super) disabled_reason: Option<String>,
    pub(super) requires_confirmation: bool,
    pub(super) write_back_allowed: bool,
    pub(super) draft_requires_user_copy: bool,
    pub(super) provider: Option<String>,
    pub(super) model: Option<String>,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) credentials_storage: String,
    pub(super) credential_persistence_allowed: bool,
    pub(super) prompt_scope: Vec<String>,
    pub(super) privacy_notes: Vec<String>,
    pub(super) confirmation: WireLlmConfirmationRequirement,
    pub(super) review_preview: WireLlmReviewPreview,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPrepareSkillAnalysisResult {
    pub(super) enabled: bool,
    pub(super) disabled_reason: String,
    pub(super) analysis_kind: String,
    pub(super) selected_skill_count: usize,
    pub(super) included_skill_count: usize,
    pub(super) excluded_missing_count: usize,
    pub(super) included_skills: Vec<WireLlmSkillAnalysisIncludedSkill>,
    pub(super) prompt_draft: String,
    pub(super) summary_draft: String,
    pub(super) safety_flags: WireLlmSkillAnalysisSafetyFlags,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) provider_request_sent: bool,
    pub(super) generated_by: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPreviewPromptResult {
    pub(super) preview_id: String,
    pub(super) status: String,
    pub(super) allowed: bool,
    pub(super) reason: String,
    pub(super) action: String,
    pub(super) profile_id: Option<String>,
    pub(super) provider: Option<String>,
    pub(super) model: Option<String>,
    pub(super) destination_host: Option<String>,
    pub(super) prompt_scope: Vec<String>,
    pub(super) included_fields: Vec<String>,
    pub(super) excluded_fields: Vec<String>,
    pub(super) redaction: WireLlmPromptRedactionSummary,
    pub(super) prompt_preview: String,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) requires_confirmation: bool,
    pub(super) confirmation: WireLlmConfirmationRequirement,
    pub(super) write_back_allowed: bool,
    pub(super) draft_requires_user_copy: bool,
    pub(super) provider_request_sent: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPromptRedactionSummary {
    pub(super) status: String,
    pub(super) redacted_value_count: usize,
    pub(super) redacted_fields: Vec<String>,
    pub(super) placeholders: Vec<String>,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmConfirmPromptAndSendResult {
    pub(super) preview_id: String,
    pub(super) confirmation_id: String,
    pub(super) status: String,
    pub(super) action: String,
    pub(super) profile_id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) draft_output: Option<String>,
    pub(super) draft_requires_user_copy: bool,
    pub(super) write_back_allowed: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) audit: WireProviderCallMetadata,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPromptRunListResult {
    pub(super) generated_by: String,
    pub(super) count: usize,
    pub(super) runs: Vec<WireLlmPromptRunRecord>,
    pub(super) app_local_only: bool,
    pub(super) runs_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) safety_flags: WireLlmPromptRunSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPromptRunRecord {
    pub(super) id: String,
    pub(super) preview_id: String,
    pub(super) confirmation_id: String,
    pub(super) action: String,
    pub(super) request_kind: String,
    pub(super) analysis_kind: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) instance_id: Option<String>,
    pub(super) instance_ids: Vec<String>,
    pub(super) definition_id: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) profile_id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) status: String,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) duration_ms: u64,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) draft_output: Option<String>,
    pub(super) draft_requires_user_copy: bool,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) redaction_summary: WireLlmPromptRunRedactionSummary,
    pub(super) created_at: i64,
    pub(super) completed_at: i64,
    pub(super) safety_flags: WireLlmPromptRunSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPromptRunRedactionSummary {
    pub(super) status: String,
    pub(super) redacted_value_count: usize,
    pub(super) redacted_fields: Vec<String>,
    pub(super) placeholders: Vec<String>,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) raw_secret_returned: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmPromptRunSafetyFlags {
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) draft_copy_only: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityResult {
    pub(super) generated_by: String,
    pub(super) status: String,
    pub(super) summary: WireLlmProviderObservabilitySummary,
    pub(super) call_rows: Vec<WireLlmProviderObservabilityCallRow>,
    pub(super) history_rows: Vec<WireLlmProviderObservabilityHistoryRow>,
    pub(super) grouping_rows: Vec<WireLlmProviderObservabilityGroupingRow>,
    #[serde(default)]
    pub(super) model_task_history_rows: Vec<WireModelTaskMatchEvidenceRow>,
    pub(super) status_rows: Vec<WireLlmProviderObservabilityStatusRow>,
    pub(super) budget_usage_hints: Vec<WireLlmProviderObservabilityBudgetUsageHint>,
    pub(super) retention_recommendations:
        Vec<WireLlmProviderObservabilityRetentionRecommendationRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireLlmProviderObservabilityEvidenceReference>,
    pub(super) prompt_metadata: WireLlmProviderObservabilityPromptMetadata,
    pub(super) safety_flags: WireLlmProviderObservabilitySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilitySummary {
    pub(super) total_prompt_run_count: usize,
    pub(super) total_call_metadata_count: usize,
    pub(super) returned_prompt_run_count: usize,
    pub(super) returned_call_row_count: usize,
    pub(super) provider_profile_count: usize,
    pub(super) enabled_profile_count: usize,
    pub(super) grouping_count: usize,
    pub(super) observed_provider_request_row_count: usize,
    pub(super) observed_credential_access_row_count: usize,
    pub(super) succeeded_count: usize,
    pub(super) failed_count: usize,
    pub(super) estimated_input_tokens: u64,
    pub(super) estimated_output_tokens: u64,
    pub(super) estimated_total_tokens: u64,
    pub(super) estimated_cost_usd: f64,
    pub(super) latest_activity_at: Option<i64>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityCallRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) timestamp: i64,
    pub(super) action_type: String,
    pub(super) profile_id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) status: String,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) duration_ms: u128,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) recorded_provider_request_sent: bool,
    pub(super) recorded_credential_accessed: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) redaction_status: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityHistoryRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) prompt_run_id: String,
    pub(super) created_at: i64,
    pub(super) completed_at: i64,
    pub(super) action: String,
    pub(super) request_kind: String,
    pub(super) analysis_kind: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) instance_id: Option<String>,
    pub(super) instance_ids: Vec<String>,
    pub(super) definition_id: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) task: Option<String>,
    pub(super) profile_id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) status: String,
    pub(super) error_code: Option<String>,
    pub(super) error_message: Option<String>,
    pub(super) duration_ms: u64,
    pub(super) estimated_input_tokens: u32,
    pub(super) estimated_output_tokens: u32,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) draft_output_available: bool,
    pub(super) draft_requires_user_copy: bool,
    pub(super) recorded_provider_request_sent: bool,
    pub(super) recorded_credential_accessed: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) redaction_status: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityGroupingRow {
    pub(super) id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) profile_ids: Vec<String>,
    pub(super) prompt_run_count: usize,
    pub(super) call_metadata_count: usize,
    pub(super) recorded_provider_request_count: usize,
    pub(super) recorded_credential_access_count: usize,
    pub(super) succeeded_count: usize,
    pub(super) failed_count: usize,
    pub(super) estimated_total_tokens: u64,
    pub(super) estimated_cost_usd: f64,
    pub(super) latest_activity_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityStatusRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) status: String,
    pub(super) severity: String,
    pub(super) message: String,
    pub(super) count: usize,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityBudgetUsageHint {
    pub(super) id: String,
    pub(super) profile_id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: String,
    pub(super) enabled: bool,
    pub(super) single_request_token_limit: u32,
    pub(super) monthly_budget_usd: f64,
    pub(super) observed_prompt_run_count: usize,
    pub(super) observed_call_metadata_count: usize,
    pub(super) observed_estimated_total_tokens: u64,
    pub(super) observed_estimated_cost_usd: f64,
    pub(super) budget_state: String,
    pub(super) reason: String,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityRetentionRecommendationRow {
    pub(super) id: String,
    pub(super) source_file: String,
    pub(super) current_record_count: usize,
    pub(super) recommendation: String,
    pub(super) cleanup_action_available: bool,
    pub(super) write_action_available: bool,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityEvidenceReference {
    pub(super) id: String,
    pub(super) kind: String,
    pub(super) label: String,
    pub(super) source: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilityPromptMetadata {
    pub(super) available: bool,
    pub(super) preview_method: String,
    pub(super) confirm_method: String,
    pub(super) provider_request_sent: bool,
    pub(super) copy_only: bool,
    pub(super) note: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmProviderObservabilitySafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) draft_copy_only: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) unredacted_paths_returned: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchListResult {
    pub(super) generated_by: String,
    pub(super) status: String,
    pub(super) summary: WireModelTaskMatchSummary,
    pub(super) records: Vec<WireModelTaskMatchRecord>,
    pub(super) model_rows: Vec<WireModelTaskMatchModelRow>,
    pub(super) task_rows: Vec<WireModelTaskMatchTaskRow>,
    pub(super) recent_evidence_rows: Vec<WireModelTaskMatchEvidenceRow>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireLlmProviderObservabilityEvidenceReference>,
    pub(super) app_local_only: bool,
    pub(super) history_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) safety_flags: WireModelTaskMatchSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchRecordResult {
    pub(super) generated_by: String,
    pub(super) record: WireModelTaskMatchRecord,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) history_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchDeleteResult {
    pub(super) record_id: String,
    pub(super) deleted: bool,
    pub(super) remaining_count: usize,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutated: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchRecord {
    pub(super) id: String,
    pub(super) title: String,
    pub(super) task: String,
    pub(super) task_kind: String,
    pub(super) agent: Option<String>,
    pub(super) profile_id: Option<String>,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: Option<String>,
    pub(super) match_status: String,
    pub(super) confidence_score: Option<u8>,
    pub(super) latency_ms: Option<u64>,
    pub(super) estimated_total_tokens: Option<u32>,
    pub(super) estimated_cost_usd: Option<f64>,
    pub(super) source_kind: String,
    pub(super) prompt_run_ids: Vec<String>,
    pub(super) session_review_ids: Vec<String>,
    pub(super) trace_import_ids: Vec<String>,
    pub(super) benchmark_ids: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) outcome_notes: Vec<String>,
    pub(super) created_at: i64,
    pub(super) updated_at: i64,
    pub(super) redaction_summary: WireLlmPromptRunRedactionSummary,
    pub(super) safety_flags: WireModelTaskMatchSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchSummary {
    pub(super) stored_record_count: usize,
    pub(super) prompt_run_count: usize,
    pub(super) returned_record_count: usize,
    pub(super) returned_prompt_run_count: usize,
    pub(super) model_count: usize,
    pub(super) task_kind_count: usize,
    pub(super) fit_count: usize,
    pub(super) partial_fit_count: usize,
    pub(super) mismatch_count: usize,
    pub(super) unknown_count: usize,
    pub(super) estimated_total_tokens: u64,
    pub(super) estimated_cost_usd: f64,
    pub(super) latest_activity_at: Option<i64>,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchModelRow {
    pub(super) id: String,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: Option<String>,
    pub(super) stored_record_count: usize,
    pub(super) prompt_run_count: usize,
    pub(super) fit_count: usize,
    pub(super) partial_fit_count: usize,
    pub(super) mismatch_count: usize,
    pub(super) unknown_count: usize,
    pub(super) estimated_total_tokens: u64,
    pub(super) estimated_cost_usd: f64,
    pub(super) latest_activity_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchTaskRow {
    pub(super) id: String,
    pub(super) task_kind: String,
    pub(super) status: String,
    pub(super) stored_record_count: usize,
    pub(super) prompt_run_count: usize,
    pub(super) fit_count: usize,
    pub(super) partial_fit_count: usize,
    pub(super) mismatch_count: usize,
    pub(super) unknown_count: usize,
    pub(super) estimated_total_tokens: u64,
    pub(super) estimated_cost_usd: f64,
    pub(super) latest_activity_at: Option<i64>,
    pub(super) evidence_refs: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchEvidenceRow {
    pub(super) id: String,
    pub(super) source: String,
    pub(super) source_kind: String,
    pub(super) title: String,
    pub(super) task: Option<String>,
    pub(super) task_kind: String,
    pub(super) agent: Option<String>,
    pub(super) provider: String,
    pub(super) model: String,
    pub(super) destination_host: Option<String>,
    pub(super) match_status: String,
    pub(super) confidence_score: Option<u8>,
    pub(super) status: String,
    pub(super) created_at: i64,
    pub(super) updated_at: Option<i64>,
    pub(super) latency_ms: Option<u64>,
    pub(super) estimated_total_tokens: u32,
    pub(super) estimated_cost_usd: f64,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) outcome_notes: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) redaction_status: String,
    pub(super) safety_flags: WireModelTaskMatchSafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireModelTaskMatchSafetyFlags {
    pub(super) read_only: bool,
    pub(super) app_local_only: bool,
    pub(super) provider_request_sent: bool,
    pub(super) credential_accessed: bool,
    pub(super) draft_copy_only: bool,
    pub(super) write_back_allowed: bool,
    pub(super) write_actions_available: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) execution_actions_available: bool,
    pub(super) config_mutation_allowed: bool,
    pub(super) snapshot_created: bool,
    pub(super) triage_mutation_allowed: bool,
    pub(super) raw_secret_returned: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) unredacted_paths_returned: bool,
    pub(super) cloud_sync_performed: bool,
    pub(super) telemetry_emitted: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmSkillAnalysisIncludedSkill {
    pub(super) instance_id: String,
    pub(super) name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) enabled: bool,
    pub(super) disabled_reason: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmSkillAnalysisSafetyFlags {
    pub(super) write_back_enabled: bool,
    pub(super) script_execution_enabled: bool,
    pub(super) credential_storage_enabled: bool,
    pub(super) confirmation_required: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCleanupQueue {
    pub(super) summary: WireCleanupQueueSummary,
    pub(super) items: Vec<WireCleanupQueueItem>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCleanupQueueSummary {
    pub(super) total_count: usize,
    pub(super) counts_by_kind: BTreeMap<String, usize>,
    pub(super) counts_by_priority: BTreeMap<String, usize>,
    pub(super) read_only: bool,
    pub(super) writes_allowed: bool,
    pub(super) provider_request_sent: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireCleanupQueueItem {
    pub(super) id: String,
    pub(super) kind: String,
    pub(super) severity: String,
    pub(super) priority: String,
    pub(super) agent: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) skill_id: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) skill_name: Option<String>,
    pub(super) title: String,
    pub(super) detail: String,
    pub(super) recommended_next_action_label: String,
    pub(super) source_id: String,
    pub(super) read_only: bool,
    pub(super) writes_allowed: bool,
    pub(super) provider_request_sent: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupFlowResult {
    pub(super) generated_by: String,
    pub(super) catalog_available: bool,
    pub(super) filters: WireGuidedCleanupFlowFilters,
    pub(super) summary: WireGuidedCleanupFlowSummary,
    pub(super) flow_steps: Vec<WireGuidedCleanupFlowStep>,
    pub(super) issue_groups: Vec<WireGuidedCleanupIssueGroup>,
    pub(super) safe_next_actions: Vec<WireGuidedCleanupSafeNextAction>,
    pub(super) recorded_steps: Vec<WireGuidedCleanupStepRecord>,
    pub(super) gap_notes: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) evidence_references: Vec<WireTaskReadinessEvidenceReference>,
    pub(super) prompt_request: WireAgentReadinessPromptRequest,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupFlowFilters {
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) selected_skill_id: Option<String>,
    pub(super) selected_skill_name: Option<String>,
    pub(super) selected_skill_agent: Option<String>,
    pub(super) project_root: Option<String>,
    pub(super) current_cwd: Option<String>,
    pub(super) workspace: Option<String>,
    pub(super) candidate_instance_ids: Vec<String>,
    pub(super) limit: usize,
    pub(super) include_recorded_steps: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupFlowSummary {
    pub(super) total_step_count: usize,
    pub(super) returned_step_count: usize,
    pub(super) issue_group_count: usize,
    pub(super) safe_next_action_count: usize,
    pub(super) recorded_step_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) medium_risk_count: usize,
    pub(super) low_risk_count: usize,
    pub(super) blocker_count: usize,
    pub(super) summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupFlowStep {
    pub(super) id: String,
    pub(super) rank: usize,
    pub(super) step_type: String,
    pub(super) phase: String,
    pub(super) title: String,
    pub(super) summary: String,
    pub(super) status: String,
    pub(super) risk: String,
    pub(super) source_method: String,
    pub(super) source_id: String,
    pub(super) agent: Option<String>,
    pub(super) skill_name: Option<String>,
    pub(super) instance_id: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) recommended_action_label: String,
    pub(super) safe_entry_method: String,
    pub(super) existing_safe_method: Option<String>,
    pub(super) safe_action_deep_link: WireGuidedCleanupSafeActionDeepLink,
    pub(super) requires_explicit_confirmation: bool,
    pub(super) evidence_refs: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) gap_notes: Vec<String>,
    pub(super) side_effect_flags: Vec<String>,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupIssueGroup {
    pub(super) id: String,
    pub(super) group_type: String,
    pub(super) label: String,
    pub(super) step_count: usize,
    pub(super) high_risk_count: usize,
    pub(super) medium_risk_count: usize,
    pub(super) low_risk_count: usize,
    pub(super) step_ids: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) blocker_notes: Vec<String>,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupSafeNextAction {
    pub(super) id: String,
    pub(super) label: String,
    pub(super) entry_method: String,
    pub(super) description: String,
    pub(super) requires_preview: bool,
    pub(super) requires_confirmation: bool,
    pub(super) copy_only: bool,
    pub(super) deep_link: WireGuidedCleanupSafeActionDeepLink,
    pub(super) related_step_ids: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupSafeActionDeepLink {
    pub(super) label: String,
    pub(super) target: String,
    pub(super) detail_section: String,
    pub(super) method: String,
    pub(super) trigger: String,
    pub(super) preview_only: bool,
    pub(super) requires_confirmation: bool,
    pub(super) copy_only: bool,
    pub(super) can_apply: bool,
    pub(super) instance_ids: Vec<String>,
    pub(super) related_step_ids: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupStepRecord {
    pub(super) id: String,
    pub(super) flow_step_id: String,
    pub(super) title: String,
    pub(super) decision: String,
    pub(super) status: String,
    pub(super) note: Option<String>,
    pub(super) task: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) instance_id: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) skill_name: Option<String>,
    pub(super) source_refs: Vec<String>,
    pub(super) evidence_refs: Vec<String>,
    pub(super) redaction_summary: WireRemediationHistoryRedactionSummary,
    pub(super) created_at: i64,
    pub(super) updated_at: i64,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireGuidedCleanupRecordStepResult {
    pub(super) generated_by: String,
    pub(super) record: WireGuidedCleanupStepRecord,
    pub(super) created: bool,
    pub(super) count: usize,
    pub(super) app_local_only: bool,
    pub(super) record_file: String,
    pub(super) provider_request_sent: bool,
    pub(super) skill_files_mutated: bool,
    pub(super) agent_config_mutated: bool,
    pub(super) snapshot_created: bool,
    pub(super) rollback_performed: bool,
    pub(super) triage_mutated: bool,
    pub(super) script_executed: bool,
    pub(super) credential_accessed: bool,
    pub(super) raw_prompt_persisted: bool,
    pub(super) raw_response_persisted: bool,
    pub(super) raw_trace_persisted: bool,
    pub(super) safety_flags: WireRemediationHistorySafetyFlags,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireReportExportLocalResult {
    pub(super) export_id: String,
    pub(super) generated_at: i64,
    pub(super) output_dir: String,
    pub(super) files: Vec<WireReportExportedFile>,
    pub(super) catalog_available: bool,
    pub(super) summary: WireReportExportSummary,
    pub(super) sections: Vec<WireReportExportSection>,
    pub(super) redaction: WireReportExportRedaction,
    pub(super) read_only: bool,
    pub(super) writes_allowed: bool,
    pub(super) provider_request_sent: bool,
    pub(super) script_execution_allowed: bool,
    pub(super) credential_accessed: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireReportExportedFile {
    pub(super) format: String,
    pub(super) path: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireReportExportSection {
    pub(super) name: String,
    pub(super) count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireReportExportSummary {
    pub(super) skill_count: usize,
    pub(super) finding_count: usize,
    pub(super) open_finding_count: usize,
    pub(super) triage_count: usize,
    pub(super) cleanup_item_count: usize,
    pub(super) comparison_group_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireReportExportRedaction {
    pub(super) enabled: bool,
    pub(super) placeholders: Vec<String>,
    pub(super) path_policy: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmConfirmationRequirement {
    pub(super) required: bool,
    pub(super) message: String,
    pub(super) display_fields: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmReviewPreview {
    pub(super) status: String,
    pub(super) generated_by: String,
    pub(super) provider_request_sent: bool,
    pub(super) write_actions_available: bool,
    pub(super) execution_actions_available: bool,
    pub(super) purpose: String,
    pub(super) risk: WireLlmReviewRisk,
    pub(super) finding_explanations: Vec<WireLlmReviewFindingExplanation>,
    pub(super) cross_agent_fit: WireLlmReviewCrossAgentFit,
    pub(super) redaction: WireLlmReviewRedaction,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmReviewRisk {
    pub(super) level: String,
    pub(super) summary: String,
    pub(super) signals: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmReviewFindingExplanation {
    pub(super) rule_id: String,
    pub(super) severity: String,
    pub(super) explanation: String,
    pub(super) suggested_next_step: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmReviewCrossAgentFit {
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) comparable_instance_count: usize,
    pub(super) summary: String,
    pub(super) notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireLlmReviewRedaction {
    pub(super) skill_body_returned: bool,
    pub(super) paths_returned: bool,
    pub(super) credentials_returned: bool,
    pub(super) included_fields: Vec<String>,
    pub(super) excluded_fields: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionPreviewRecord {
    pub(super) skill_instance_id: Option<String>,
    pub(super) initiated_by: String,
    pub(super) initiator_allowed: bool,
    pub(super) cwd: WireScriptExecutionCwdScope,
    pub(super) env: WireScriptExecutionEnvScope,
    pub(super) network: WireScriptExecutionNetworkScope,
    pub(super) files: WireScriptExecutionFilesScope,
    pub(super) command_preview: WireScriptExecutionCommandPreview,
    pub(super) risks: Vec<String>,
    pub(super) confirmation: WireScriptExecutionConfirmation,
    pub(super) execution_allowed: bool,
    pub(super) disabled_reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionCwdScope {
    pub(super) requested: Option<String>,
    pub(super) effective: String,
    pub(super) source: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionEnvScope {
    pub(super) inherit_parent: bool,
    pub(super) provided_keys: Vec<String>,
    pub(super) redacted_keys: Vec<String>,
    pub(super) value_policy: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionNetworkScope {
    pub(super) requested: String,
    pub(super) allowed: bool,
    pub(super) reason: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionFilesScope {
    pub(super) requested: Vec<String>,
    pub(super) read_allowed: bool,
    pub(super) write_allowed: bool,
    pub(super) allowed_roots: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionCommandPreview {
    pub(super) argv: Vec<String>,
    pub(super) display: String,
    pub(super) shell: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionConfirmation {
    pub(super) required: bool,
    pub(super) confirmed: bool,
    pub(super) fields: Vec<String>,
    pub(super) message: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireScriptExecutionAttemptRecord {
    pub(super) id: String,
    pub(super) created_at: i64,
    pub(super) status: String,
    pub(super) outcome: String,
    pub(super) reason: String,
    pub(super) spawned_process: bool,
    pub(super) audit_path: String,
    pub(super) preview: WireScriptExecutionPreviewRecord,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProjectContextSummary {
    pub(super) source: String,
    pub(super) active: Option<WireProjectContext>,
    pub(super) recent_count: usize,
    pub(super) validation_error: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProjectContextState {
    pub(super) active: Option<WireProjectContext>,
    pub(super) recent: Vec<WireProjectContext>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireProjectContext {
    pub(super) id: String,
    pub(super) name: String,
    pub(super) root_path: String,
    pub(super) current_cwd: String,
    pub(super) last_used_at: i64,
    pub(super) is_active: bool,
    pub(super) validation_error: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRefreshActivity {
    pub(super) operation: String,
    pub(super) status: String,
    pub(super) started_at: i64,
    pub(super) finished_at: i64,
    pub(super) scanned_count: usize,
    pub(super) skill_count: usize,
    pub(super) finding_count: usize,
    pub(super) conflict_count: usize,
    pub(super) snapshot_count: usize,
    pub(super) roots: Vec<String>,
    pub(super) log_entries: Vec<WireRefreshLogEntry>,
    pub(super) recovery_actions: Vec<String>,
    pub(super) agent_summaries: Option<Vec<WireAgentRefreshSummary>>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRefreshLogEntry {
    pub(super) level: String,
    pub(super) message: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireAgentRefreshSummary {
    pub(super) agent: String,
    pub(super) display_label: String,
    pub(super) status: String,
    pub(super) scanned_count: usize,
    pub(super) catalog_count: usize,
    pub(super) broken_count: usize,
    pub(super) roots_considered: Vec<String>,
    pub(super) roots_scanned: Vec<String>,
    pub(super) roots_skipped: Vec<String>,
    #[serde(default)]
    pub(super) config_detected: bool,
    #[serde(default)]
    pub(super) config_paths: Vec<String>,
    #[serde(default)]
    pub(super) writable_status: String,
    #[serde(default)]
    pub(super) writable_reason: Option<String>,
    #[serde(default)]
    pub(super) read_only_reason: String,
    #[serde(default)]
    pub(super) blockers: Vec<String>,
    pub(super) recovery_actions: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillRecord {
    pub(super) id: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) path: PathBuf,
    pub(super) display_path: PathBuf,
    pub(super) definition_id: String,
    pub(super) name: String,
    pub(super) state: String,
    pub(super) enabled: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireBatchTogglePreviewRecord {
    pub(super) preview_token: String,
    pub(super) target_enabled: bool,
    pub(super) requested_count: usize,
    pub(super) writable_count: usize,
    pub(super) skipped_count: usize,
    pub(super) writes_allowed: bool,
    pub(super) affected_items: Vec<WireBatchToggleAffectedItem>,
    pub(super) skipped_items: Vec<WireBatchToggleSkippedItem>,
    pub(super) capability_labels: Vec<String>,
    pub(super) snapshot_rollback_notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireBatchToggleApplyRecord {
    pub(super) preview_token: String,
    pub(super) target_enabled: bool,
    pub(super) requested_count: usize,
    pub(super) writable_count: usize,
    pub(super) skipped_count: usize,
    pub(super) applied_count: usize,
    pub(super) writes_allowed: bool,
    pub(super) affected_items: Vec<WireBatchToggleAffectedItem>,
    pub(super) skipped_items: Vec<WireBatchToggleSkippedItem>,
    pub(super) capability_labels: Vec<String>,
    pub(super) snapshot_rollback_notes: Vec<String>,
    pub(super) updated_records: Vec<WireSkillRecord>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireBatchToggleAffectedItem {
    pub(super) instance_id: String,
    pub(super) name: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) current_enabled: bool,
    pub(super) target_enabled: bool,
    pub(super) config_scope: String,
    pub(super) config_target: String,
    pub(super) capability_label: String,
    pub(super) snapshot_plan: String,
    pub(super) rollback_plan: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireBatchToggleSkippedItem {
    pub(super) instance_id: String,
    pub(super) name: Option<String>,
    pub(super) agent: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) reason: String,
    pub(super) capability_label: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillDetailRecord {
    pub(super) id: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) path: PathBuf,
    pub(super) display_path: PathBuf,
    pub(super) definition_id: String,
    pub(super) name: String,
    pub(super) description: String,
    pub(super) state: String,
    pub(super) enabled: bool,
    pub(super) frontmatter_raw: String,
    pub(super) body: String,
    pub(super) permissions: Value,
    pub(super) fingerprint: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireExportedSkillBundle {
    pub(super) manifest_path: PathBuf,
    pub(super) bundle_path: PathBuf,
    pub(super) fingerprint: String,
    pub(super) metadata: WireExportedSkillMetadata,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireExportedSkillMetadata {
    pub(super) name: String,
    pub(super) description: String,
    pub(super) skill_path: String,
    pub(super) source_agent: String,
    pub(super) source_scope: String,
    pub(super) version: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRuleFindingRecord {
    pub(super) id: String,
    pub(super) triage_key: String,
    pub(super) triage_context: String,
    pub(super) instance_id: Option<String>,
    pub(super) definition_id: Option<String>,
    pub(super) rule_id: String,
    pub(super) severity: String,
    pub(super) effective_severity: String,
    pub(super) severity_override: Option<String>,
    pub(super) message: String,
    pub(super) suggestion: Option<String>,
    pub(super) created_at: i64,
    pub(super) suppressed: bool,
    pub(super) suppression_reason: Option<String>,
    pub(super) suppression_note: Option<String>,
    pub(super) rule_tuning_updated_at: Option<i64>,
    pub(super) triage_status: String,
    pub(super) triage_note: Option<String>,
    pub(super) triage_updated_at: Option<i64>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireFindingTriageRecord {
    pub(super) triage_key: String,
    pub(super) triage_context: String,
    pub(super) status: String,
    pub(super) note: Option<String>,
    pub(super) updated_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireRuleTuningRecord {
    pub(super) rule_id: String,
    pub(super) agent: Option<String>,
    pub(super) scope: Option<String>,
    pub(super) severity_override: Option<String>,
    pub(super) suppression_reason: Option<String>,
    pub(super) suppression_note: Option<String>,
    pub(super) updated_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireConflictGroupRecord {
    pub(super) id: String,
    pub(super) definition_id: String,
    pub(super) reason: String,
    pub(super) winner_id: Option<String>,
    pub(super) instance_ids: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireToolGlobalImportResult {
    pub(super) imported: WireSkillRecord,
    pub(super) instance_id: String,
    pub(super) source_path: String,
    pub(super) staging_path: String,
    pub(super) findings: Vec<WireRuleFindingRecord>,
    pub(super) audit: WireToolGlobalImportAudit,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireToolGlobalImportAudit {
    pub(super) status: String,
    pub(super) read_only_preview: bool,
    pub(super) finding_count: usize,
    pub(super) error_count: usize,
    pub(super) warn_count: usize,
    pub(super) info_count: usize,
    pub(super) conflict_count: usize,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireConfigDocumentRecord {
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) target: String,
    pub(super) format: String,
    pub(super) content: String,
    pub(super) exists: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillInstallPreviewRecord {
    pub(super) source_instance_id: String,
    pub(super) source_path: String,
    pub(super) target_agent: String,
    pub(super) target_scope: String,
    pub(super) target_path: String,
    pub(super) files: Vec<WireSkillInstallFilePreview>,
    pub(super) risks: Vec<String>,
    pub(super) confirmation: WireSkillInstallConfirmation,
    pub(super) wrote: bool,
    pub(super) snapshot_id: Option<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillInstallFilePreview {
    pub(super) source: String,
    pub(super) target: String,
    pub(super) kind: String,
    pub(super) will_write: bool,
    pub(super) target_exists: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillInstallConfirmation {
    pub(super) required: bool,
    pub(super) confirmed: bool,
    pub(super) fields: Vec<String>,
    pub(super) message: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireConfigSnapshotRecord {
    pub(super) id: String,
    pub(super) agent: String,
    pub(super) scope: String,
    pub(super) target: String,
    pub(super) content: String,
    pub(super) reason: String,
    pub(super) created_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSkillEventRecord {
    pub(super) id: i64,
    pub(super) instance_id: String,
    pub(super) kind: String,
    pub(super) payload: Value,
    pub(super) occurred_at: i64,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct WireSnapshotRollbackPreviewRecord {
    pub(super) snapshot: WireConfigSnapshotRecord,
    pub(super) current_content: String,
    pub(super) current_read_error: Option<String>,
    pub(super) changed: bool,
    pub(super) redacted: Option<bool>,
    pub(super) rollback_supported: Option<bool>,
}
