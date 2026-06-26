use super::dispatch_fixtures::*;
use super::*;

#[test]
pub(super) fn service_protocol_fixtures_decode() {
    let fixtures_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .join("fixtures/service-protocol");
    let mut request_methods = Vec::new();
    let mut response_methods = Vec::new();
    for entry in fs::read_dir(fixtures_dir).expect("read fixtures") {
        let path = entry.expect("fixture entry").path();
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        if name.ends_with(".request.json") {
            let content = fs::read_to_string(&path).expect("read request fixture");
            let request =
                serde_json::from_str::<ServiceRequest>(&content).unwrap_or_else(|error| {
                    panic!("request fixture {} failed: {error}", path.display())
                });
            request_methods.push(request.method);
        }
        if name.ends_with(".response.json") {
            let content = fs::read_to_string(&path).expect("read response fixture");
            let response =
                serde_json::from_str::<ServiceResponse>(&content).unwrap_or_else(|error| {
                    panic!("response fixture {} failed: {error}", path.display())
                });
            let method = fixture_method_from_name(name, ".response.json");
            if name.contains(".error.response.json") {
                assert!(
                    !response.ok,
                    "error response fixture {} is ok",
                    path.display()
                );
                assert!(
                    response.error.is_some(),
                    "error response fixture {} missing error",
                    path.display()
                );
            } else {
                assert!(response.ok, "response fixture {} is not ok", path.display());
                let result = response.result.unwrap_or_else(|| {
                    panic!("response fixture {} missing result", path.display())
                });
                decode_response_fixture(method, &result, &path);
            }
            response_methods.push(method.to_string());
        }
    }
    for (request_fixture, response_fixture) in inline_service_protocol_fixtures() {
        let request = serde_json::from_value::<ServiceRequest>(request_fixture)
            .expect("inline request fixture should decode");
        let method = request.method.clone();
        request_methods.push(method.clone());
        let response = serde_json::from_value::<ServiceResponse>(response_fixture)
            .expect("inline response fixture should decode");
        assert!(
            response.ok,
            "inline response fixture for {method} is not ok"
        );
        let result = response
            .result
            .unwrap_or_else(|| panic!("inline response fixture for {method} missing result"));
        let path = PathBuf::from(format!("<inline:{method}.response.json>"));
        decode_response_fixture(&method, &result, &path);
        response_methods.push(method);
    }

    let supported = supported_methods();
    for method in &supported {
        assert!(
            request_methods.iter().any(|fixture| fixture == method),
            "missing request fixture for {method}"
        );
        assert!(
            response_methods.iter().any(|fixture| fixture == method),
            "missing response fixture for {method}"
        );
    }
    for method in request_methods.iter().chain(response_methods.iter()) {
        assert!(
            supported.iter().any(|supported| supported == method),
            "fixture covers unsupported method {method}"
        );
    }
}

pub(super) fn inline_service_protocol_fixtures() -> Vec<(Value, Value)> {
    let safety_flags = agent_session_review_safety_flags();
    let redaction_summary = agent_session_review_redaction_summary_default();
    let detected = TraceDetectedSkill {
        instance_id: "fixture-skill-id".to_string(),
        definition_id: "fixture-definition-id".to_string(),
        skill_name: "fixture-skill".to_string(),
        agent: "claude-code".to_string(),
        scope: "agent-global".to_string(),
        evidence_refs: vec!["skill:fixture-skill-id".to_string()],
        match_terms: vec!["fixture-skill-id".to_string()],
    };
    let review = AgentSessionSkillReviewRecord {
        id: "agent-session-review-fixture".to_string(),
        title: "Agent session review fixture".to_string(),
        source_kind: "agent-session-transcript".to_string(),
        agent: Some("claude-code".to_string()),
        task: Some("fixture task".to_string()),
        trace_import_ids: vec!["trace-import-fixture".to_string()],
        missing_trace_import_ids: Vec::new(),
        expected_skill_refs: vec!["fixture-skill-id".to_string()],
        expected_skill_names: vec!["fixture-skill".to_string()],
        excerpt: "Assistant selected fixture-skill-id.".to_string(),
        excerpt_char_count: 36,
        content_hash: "fixture-content-hash".to_string(),
        redaction_summary,
        reviewed_at: 1,
        analysis: AgentSessionSkillReviewAnalysis {
            generated_by: "deterministic-service".to_string(),
            catalog_available: true,
            outcome: "hit".to_string(),
            summary: "Session skill-use review outcome is hit.".to_string(),
            reasons: vec!["Detected expected local catalog skill.".to_string()],
            detected_skills: vec![detected],
            expected_skill_signals: vec![AgentSessionExpectedSkillSignal {
                kind: "skill_ref".to_string(),
                value: "fixture-skill-id".to_string(),
                matched: true,
                matched_instance_ids: vec!["fixture-skill-id".to_string()],
            }],
            referenced_traces: vec![AgentSessionReferencedTrace {
                id: "trace-import-fixture".to_string(),
                title: "Trace import fixture".to_string(),
                outcome: "hit".to_string(),
                imported_at: 1,
                detected_skill_count: 1,
                evidence_refs: vec!["skill:fixture-skill-id".to_string()],
            }],
            evidence_refs: vec![
                "skill:fixture-skill-id".to_string(),
                "trace-import:trace-import-fixture".to_string(),
            ],
        },
        safety_flags,
    };
    let review_response = ServiceResponse {
        id: Some("inline-session-review".to_string()),
        ok: true,
        result: Some(
            serde_json::to_value(AgentSessionSkillReviewResult {
                generated_by: "local-v2.62",
                review: review.clone(),
                count: 1,
                app_local_only: true,
                review_file: "agent-session-reviews.json",
                provider_request_sent: false,
                skill_files_mutated: false,
                agent_config_mutated: false,
                snapshot_created: false,
                triage_mutated: false,
                raw_prompt_persisted: false,
                raw_response_persisted: false,
                raw_trace_persisted: false,
            })
            .expect("serialize inline session review result"),
        ),
        error: None,
    };
    let list_response = ServiceResponse {
        id: Some("inline-session-list".to_string()),
        ok: true,
        result: Some(
            serde_json::to_value(AgentSessionSkillReviewListResult {
                generated_by: "local-v2.62",
                count: 1,
                total_count: 1,
                reviews: vec![review],
                app_local_only: true,
                review_file: "agent-session-reviews.json",
                provider_request_sent: false,
                raw_prompt_persisted: false,
                raw_response_persisted: false,
                raw_trace_persisted: false,
                safety_flags,
            })
            .expect("serialize inline session review list result"),
        ),
        error: None,
    };
    let delete_response = ServiceResponse {
        id: Some("inline-session-delete".to_string()),
        ok: true,
        result: Some(
            serde_json::to_value(AgentSessionSkillReviewDeleteResult {
                review_id: "agent-session-review-fixture".to_string(),
                deleted: true,
                remaining_count: 0,
                app_local_only: true,
                provider_request_sent: false,
                skill_files_mutated: false,
                agent_config_mutated: false,
                snapshot_created: false,
                triage_mutated: false,
                raw_prompt_persisted: false,
                raw_response_persisted: false,
                raw_trace_persisted: false,
            })
            .expect("serialize inline session review delete result"),
        ),
        error: None,
    };

    vec![
        (
            json!({
                "id": "inline-session-review",
                "method": "session.reviewAgentSkillUse",
                "params": {
                    "content": "Assistant selected fixture-skill-id.",
                    "expected_skill_refs": ["fixture-skill-id"]
                }
            }),
            serde_json::to_value(review_response)
                .expect("serialize inline session review response"),
        ),
        (
            json!({
                "id": "inline-session-list",
                "method": "session.listSkillReviews",
                "params": { "limit": 5 }
            }),
            serde_json::to_value(list_response)
                .expect("serialize inline session review list response"),
        ),
        (
            json!({
                "id": "inline-session-delete",
                "method": "session.deleteSkillReview",
                "params": { "id": "agent-session-review-fixture" }
            }),
            serde_json::to_value(delete_response)
                .expect("serialize inline session review delete response"),
        ),
    ]
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerToolRecord {
    id: String,
    display_name: String,
    status: String,
    executable: Option<String>,
    operations: Vec<String>,
    default_agents: Vec<String>,
    notes: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerCommandPreview {
    tool_id: String,
    operation: String,
    command: Vec<String>,
    cwd: String,
    env: Vec<WireSkillManagerEnvPreview>,
    requires_confirmation: bool,
    confirmed: bool,
    network_required: bool,
    network_allowed: bool,
    will_run: bool,
    preview_token: String,
    summary: String,
    risks: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerEnvPreview {
    key: String,
    value: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerCommandOutput {
    status: String,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerSearchRecord {
    preview: WireSkillManagerCommandPreview,
    output: Option<WireSkillManagerCommandOutput>,
    results: Vec<WireSkillManagerSearchResult>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerSearchResult {
    name: String,
    source: Option<String>,
    description: Option<String>,
    raw: Value,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerInstalledListRecord {
    preview: WireSkillManagerCommandPreview,
    output: WireSkillManagerCommandOutput,
    installed: Vec<WireSkillManagerInstalledRecord>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerInstalledRecord {
    name: String,
    source: Option<String>,
    agents: Vec<String>,
    scope: Option<String>,
    path: Option<String>,
    raw: Value,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerMutationRecord {
    preview: WireSkillManagerCommandPreview,
    output: Option<WireSkillManagerCommandOutput>,
    applied: bool,
    scanned_count: usize,
    updated_skills: Vec<WireSkillRecord>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerLocalCreateRecord {
    preview: WireSkillManagerCommandPreview,
    output: Option<WireSkillManagerCommandOutput>,
    imported: Option<WireSkillRecord>,
    instance_id: Option<String>,
    source_path: String,
    applied: bool,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerLocalDeleteRecord {
    instance_id: String,
    skill_name: String,
    path: String,
    app_owned: bool,
    physical_delete_allowed: bool,
    blocked_by_references: Vec<WireSkillManagerReferenceRecord>,
    confirmed: bool,
    deleted: bool,
    summary: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WireSkillManagerReferenceRecord {
    instance_id: String,
    name: String,
    agent: String,
    scope: String,
    path: String,
}

pub(super) fn decode_response_fixture(method: &str, result: &Value, path: &Path) {
    match method {
        "app.version" => {
            let version: WireAppVersion = decode_fixture_result(method, result, path);
            assert_eq!(version.protocol_version, SERVICE_PROTOCOL_VERSION);
            assert!(!version.version.is_empty());
        }
        "app.stateSnapshot" => {
            let snapshot: WireAppStateSnapshot = decode_fixture_result(method, result, path);
            assert_supported_methods(method, &snapshot.status.supported_methods);
            assert_eq!(
                snapshot.analysis.summary.total_groups,
                snapshot.analysis.groups.len()
            );
            assert_findings_cover_v28_contract(
                &snapshot.findings,
                &["frontmatter.required-fields"],
                method,
            );
        }
        "service.status" => {
            let status: WireServiceStatus = decode_fixture_result(method, result, path);
            assert_eq!(status.protocol_version, SERVICE_PROTOCOL_VERSION);
            assert_supported_methods(method, &status.supported_methods);
            assert!(!status.script_execution.enabled);
            assert!(!status.script_execution.llm_initiation_allowed);
        }
        "adapter.listCapabilities" => {
            let _: Vec<WireAdapterCapabilityRecord> = decode_fixture_result(method, result, path);
        }
        "adapter.listDiagnostics" => {
            let diagnostics: Vec<WireAdapterDiagnosticsRecord> =
                decode_fixture_result(method, result, path);
            assert!(diagnostics.iter().any(|diagnostic| {
                diagnostic.agent == "hermes"
                    && diagnostic.status == "guarded"
                    && diagnostic.config.status == "not-detected"
                    && diagnostic.access.writable_status == "guarded-v2.97"
            }));
        }
        "evidence.previewMcpServers" => {
            let preview: WireMcpServerPreviewResult = decode_fixture_result(method, result, path);
            assert_eq!(preview.generated_by, "local-v2.87");
            assert!(preview.authorized);
            assert!(!preview.authorization_required);
            assert!(preview.evidence_available);
            assert!(!preview.evidence_insufficient);
            assert_eq!(preview.count, preview.server_rows.len());
            assert!(preview.read_only);
            assert!(!preview.provider_request_sent);
            assert!(!preview.skill_files_mutated);
            assert!(!preview.agent_config_mutated);
            assert!(!preview.snapshot_created);
            assert!(!preview.triage_mutated);
            assert!(!preview.raw_prompt_persisted);
            assert!(!preview.raw_response_persisted);
            assert!(!preview.raw_trace_persisted);
            assert!(!preview.credential_accessed);
            assert_agent_session_review_safety(&preview.safety_flags);
            assert!(!preview.redaction_summary.raw_trace_persisted);
            for row in &preview.server_rows {
                assert!(!row.evidence_refs.is_empty());
                assert!(!row.source_path.is_empty());
            }
        }
        "evidence.piWritableHarness" => {
            let report: WirePiWritableHarnessReport = decode_fixture_result(method, result, path);
            assert!(!report.production_writes_enabled);
            assert!(!report.safety.production_writes_enabled);
            assert!(report.safety.disposable_only);
            assert!(!report.safety.provider_request_sent);
            assert!(!report.safety.script_execution_allowed);
            assert!(!report.safety.credential_accessed);
            assert!(!report.safety.install_performed);
            assert!(!report.safety.production_config_mutated);
            assert!(!report.scenarios.is_empty());
            assert!(report.scenarios.iter().all(|scenario| {
                scenario.initial_enabled
                    && scenario.disabled_after_toggle
                    && scenario.reenabled_after_toggle
                    && scenario.rollback_restored
                    && scenario.invalid_json_blocked
                    && scenario.writes_confined_to_disposable_root
            }));
        }
        "analysis.scoreSkillQuality" => {
            let score: WireSkillQualityScoreResult = decode_fixture_result(method, result, path);
            assert!(score.score <= 100);
            assert!(!score.components.is_empty());
            assert!(!score.evidence_references.is_empty());
            assert!(score.prompt_request.available);
            assert_eq!(score.prompt_request.action, "quality_score");
            assert_eq!(score.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                score.prompt_request.request.action,
                LlmPromptActionKind::QualityScore
            );
            assert!(score.safety_flags.read_only);
            assert!(!score.safety_flags.provider_request_sent);
            assert!(!score.safety_flags.write_back_allowed);
            assert!(!score.safety_flags.script_execution_allowed);
            assert!(!score.safety_flags.config_mutation_allowed);
            assert!(!score.safety_flags.snapshot_created);
            assert!(!score.safety_flags.triage_mutation_allowed);
            assert!(!score.safety_flags.credential_accessed);
            assert!(!score.safety_flags.raw_secret_returned);
            assert!(!score.safety_flags.raw_prompt_persisted);
            assert!(!score.safety_flags.raw_response_persisted);
        }
        "analysis.detectStaleDrift" => {
            let detection: WireStaleDriftDetectionResult =
                decode_fixture_result(method, result, path);
            assert_eq!(detection.generated_by, "deterministic-service");
            assert!(detection.catalog_available);
            assert_eq!(
                detection.summary.returned_row_count,
                detection.stale_drift_rows.len()
            );
            assert!(!detection.stale_drift_rows.is_empty());
            assert!(detection
                .stale_drift_rows
                .iter()
                .all(|row| row.stale_drift_score <= 100));
            assert_eq!(detection.prompt_request.action, "stale_drift_detection");
            assert_eq!(detection.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                detection.prompt_request.request.action,
                LlmPromptActionKind::StaleDriftDetection
            );
            assert_agent_readiness_safety_flags(&detection.safety_flags);
            for row in &detection.stale_drift_rows {
                assert_agent_readiness_safety_flags(&row.safety_flags);
            }
        }
        "knowledge.search" => {
            let search: WireKnowledgeSearchResult = decode_fixture_result(method, result, path);
            assert_eq!(search.generated_by, "deterministic-service");
            assert!(search.catalog_available);
            assert_eq!(search.summary.returned_row_count, search.rows.len());
            assert!(!search.rows.is_empty());
            assert!(!search.rows[0].instance_id.is_empty());
            assert!(!search.rows[0].matched_fields.is_empty());
            assert_eq!(search.prompt_request.action, "knowledge_search");
            assert_eq!(search.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                search.prompt_request.request.action,
                LlmPromptActionKind::KnowledgeSearch
            );
            assert_agent_readiness_safety_flags(&search.safety_flags);
            for row in &search.rows {
                assert_agent_readiness_safety_flags(&row.safety_flags);
            }
        }
        "knowledge.groupSimilarSkills" => {
            let grouping: WireSimilarSkillGroupingResult =
                decode_fixture_result(method, result, path);
            assert_eq!(grouping.generated_by, "deterministic-service");
            assert!(grouping.catalog_available);
            assert_eq!(grouping.summary.returned_group_count, grouping.groups.len());
            assert!(!grouping.groups.is_empty());
            assert!(!grouping.groups[0].members.is_empty());
            assert!(grouping.groups[0].similarity_score <= 100);
            assert_eq!(grouping.prompt_request.action, "similar_skill_grouping");
            assert_eq!(grouping.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                grouping.prompt_request.request.action,
                LlmPromptActionKind::SimilarSkillGrouping
            );
            assert_agent_readiness_safety_flags(&grouping.safety_flags);
            for group in &grouping.groups {
                assert_agent_readiness_safety_flags(&group.safety_flags);
            }
        }
        "knowledge.buildCapabilityTaxonomy" => {
            let taxonomy: WireCapabilityTaxonomyResult =
                decode_fixture_result(method, result, path);
            assert_eq!(taxonomy.generated_by, "deterministic-service");
            assert!(taxonomy.catalog_available);
            assert_eq!(
                taxonomy.summary.returned_domain_count,
                taxonomy.domains.len()
            );
            assert_eq!(taxonomy.coverage_rows.len(), taxonomy.domains.len());
            assert!(!taxonomy.domains.is_empty());
            assert!(!taxonomy.domains[0].representative_skills.is_empty());
            assert!(taxonomy.domains[0].coverage_score <= 100);
            assert_eq!(taxonomy.prompt_request.action, "capability_taxonomy");
            assert_eq!(taxonomy.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                taxonomy.prompt_request.request.action,
                LlmPromptActionKind::CapabilityTaxonomy
            );
            assert_agent_readiness_safety_flags(&taxonomy.safety_flags);
            for domain in &taxonomy.domains {
                assert_agent_readiness_safety_flags(&domain.safety_flags);
            }
        }
        "knowledge.buildLocalSkillMap" => {
            let skill_map: WireLocalSkillMapResult = decode_fixture_result(method, result, path);
            assert_eq!(skill_map.generated_by, "deterministic-service");
            assert!(skill_map.catalog_available);
            assert_eq!(skill_map.summary.returned_node_count, skill_map.nodes.len());
            assert_eq!(skill_map.summary.returned_edge_count, skill_map.edges.len());
            assert_eq!(
                skill_map.summary.returned_cluster_count,
                skill_map.clusters.len()
            );
            assert!(!skill_map.nodes.is_empty());
            assert!(!skill_map.edges.is_empty());
            assert!(skill_map.nodes.iter().any(|node| node.node_type == "skill"));
            assert!(skill_map
                .nodes
                .iter()
                .any(|node| node.node_type == "capability"));
            assert!(skill_map
                .edges
                .iter()
                .any(|edge| edge.edge_type == "skill_capability"));
            assert_eq!(skill_map.prompt_request.action, "local_skill_map");
            assert_eq!(skill_map.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                skill_map.prompt_request.request.action,
                LlmPromptActionKind::LocalSkillMap
            );
            assert_agent_readiness_safety_flags(&skill_map.safety_flags);
            for node in &skill_map.nodes {
                assert_agent_readiness_safety_flags(&node.safety_flags);
            }
            for edge in &skill_map.edges {
                assert_agent_readiness_safety_flags(&edge.safety_flags);
            }
            for cluster in &skill_map.clusters {
                assert_agent_readiness_safety_flags(&cluster.safety_flags);
            }
        }
        "workspace.checkReadiness" => {
            let readiness: WireWorkspaceReadinessResult =
                decode_fixture_result(method, result, path);
            assert_eq!(readiness.generated_by, "deterministic-service");
            assert!(readiness.catalog_available);
            assert_eq!(
                readiness.readiness_rows.len(),
                readiness.checklist_rows.len()
            );
            assert!(!readiness.readiness_rows.is_empty());
            assert!(!readiness.agent_rows.is_empty());
            assert!(!readiness.capability_rows.is_empty());
            assert!(readiness.readiness_rows.iter().all(|row| row.score <= 100));
            assert_eq!(readiness.prompt_request.action, "workspace_readiness");
            assert_eq!(readiness.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                readiness.prompt_request.request.action,
                LlmPromptActionKind::WorkspaceReadiness
            );
            assert_agent_readiness_safety_flags(&readiness.safety_flags);
        }
        "remediation.plan" => {
            let plan: WireRemediationPlanResult = decode_fixture_result(method, result, path);
            assert_eq!(plan.generated_by, "deterministic-service");
            assert!(plan.catalog_available);
            assert_eq!(plan.summary.returned_item_count, plan.plan_items.len());
            assert!(!plan.plan_items.is_empty());
            assert!(!plan.priority_rows.is_empty());
            assert_eq!(plan.prompt_request.action, "remediation_plan");
            assert_eq!(plan.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                plan.prompt_request.request.action,
                LlmPromptActionKind::RemediationPlan
            );
            assert_agent_readiness_safety_flags(&plan.safety_flags);
            for item in &plan.plan_items {
                assert!(item.rank > 0);
                assert_agent_readiness_safety_flags(&item.safety_flags);
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "provider_request_sent=false"));
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "write_back_allowed=false"));
            }
        }
        "remediation.previewDrafts" => {
            let drafts: WireRemediationPreviewDraftsResult =
                decode_fixture_result(method, result, path);
            assert_eq!(drafts.generated_by, "local-v2.57");
            assert!(drafts.catalog_available);
            assert_eq!(
                drafts.summary.returned_draft_count,
                drafts.draft_items.len()
            );
            assert!(!drafts.draft_items.is_empty());
            assert_eq!(drafts.prompt_request.action, "remediation_preview_drafts");
            assert_eq!(drafts.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                drafts.prompt_request.request.action,
                LlmPromptActionKind::RemediationPreviewDrafts
            );
            assert_agent_readiness_safety_flags(&drafts.safety_flags);
            for item in &drafts.draft_items {
                assert!(item.rank > 0);
                assert!(!item.proposed_text.is_empty());
                assert!(item.patch_like_snippet.contains("Copy-only"));
                assert_agent_readiness_safety_flags(&item.safety_flags);
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "provider_request_sent=false"));
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "write_back_allowed=false"));
            }
        }
        "remediation.previewImpact" => {
            let impact: WireRemediationPreviewImpactResult =
                decode_fixture_result(method, result, path);
            assert_eq!(impact.generated_by, "local-v2.58");
            assert!(impact.catalog_available);
            assert_eq!(
                impact.summary.returned_impact_count,
                impact.impact_rows.len()
            );
            assert!(!impact.impact_rows.is_empty());
            assert!(!impact.skill_impact_rows.is_empty());
            assert!(!impact.agent_impact_rows.is_empty());
            assert_eq!(impact.prompt_request.action, "remediation_preview_impact");
            assert_eq!(impact.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                impact.prompt_request.request.action,
                LlmPromptActionKind::RemediationPreviewImpact
            );
            assert_agent_readiness_safety_flags(&impact.safety_flags);
            for row in &impact.impact_rows {
                assert!(row.rank > 0);
                assert_agent_readiness_safety_flags(&row.safety_flags);
                assert!(row
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "provider_request_sent=false"));
                assert!(row
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "snapshot_created=false"));
            }
            assert!(impact
                .snapshot_rollback_plan_rows
                .iter()
                .all(|row| row.plan_only));
        }
        "remediation.batchReview" => {
            let review: WireRemediationBatchReviewResult =
                decode_fixture_result(method, result, path);
            assert_eq!(review.generated_by, "local-v2.59");
            assert!(review.catalog_available);
            assert_eq!(
                review.summary.returned_item_count,
                review.review_items.len()
            );
            assert_eq!(review.summary.group_count, review.review_groups.len());
            assert!(!review.review_items.is_empty());
            assert!(!review.review_groups.is_empty());
            assert_eq!(review.prompt_request.action, "remediation_batch_review");
            assert_eq!(review.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                review.prompt_request.request.action,
                LlmPromptActionKind::RemediationBatchReview
            );
            assert_agent_readiness_safety_flags(&review.safety_flags);
            for item in &review.review_items {
                assert!(item.rank > 0);
                assert_agent_readiness_safety_flags(&item.safety_flags);
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "provider_request_sent=false"));
                assert!(item
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "write_back_allowed=false"));
            }
        }
        "remediation.listHistory" => {
            let history: WireRemediationHistoryListResult =
                decode_fixture_result(method, result, path);
            assert_eq!(history.generated_by, "local-v2.60");
            assert_eq!(history.summary.returned_count, history.records.len());
            assert!(history.app_local_only);
            assert!(!history.provider_request_sent);
            assert!(!history.raw_prompt_persisted);
            assert!(!history.raw_response_persisted);
            assert!(!history.raw_trace_persisted);
            assert_remediation_history_safety(&history.safety_flags);
            for record in &history.records {
                assert_remediation_history_safety(&record.safety_flags);
            }
        }
        "remediation.recordHistory" => {
            let result: WireRemediationHistoryRecordResult =
                decode_fixture_result(method, result, path);
            assert_eq!(result.generated_by, "local-v2.60");
            assert!(result.app_local_only);
            assert!(!result.provider_request_sent);
            assert!(!result.skill_files_mutated);
            assert!(!result.agent_config_mutated);
            assert!(!result.snapshot_created);
            assert!(!result.rollback_performed);
            assert!(!result.triage_mutated);
            assert!(!result.raw_prompt_persisted);
            assert!(!result.raw_response_persisted);
            assert!(!result.raw_trace_persisted);
            assert_remediation_history_safety(&result.record.safety_flags);
        }
        "remediation.deleteHistory" => {
            let result: WireRemediationHistoryDeleteResult =
                decode_fixture_result(method, result, path);
            assert!(result.app_local_only);
            assert!(!result.provider_request_sent);
            assert!(!result.skill_files_mutated);
            assert!(!result.agent_config_mutated);
            assert!(!result.snapshot_created);
            assert!(!result.rollback_performed);
            assert!(!result.triage_mutated);
            assert!(!result.raw_prompt_persisted);
            assert!(!result.raw_response_persisted);
            assert!(!result.raw_trace_persisted);
        }
        "task.checkReadiness" => {
            let readiness: WireTaskReadinessResult = decode_fixture_result(method, result, path);
            assert!(readiness.score <= 100);
            assert!(readiness.catalog_available);
            assert!(!readiness.candidate_skills.is_empty());
            assert!(readiness.prompt_request.available);
            assert_eq!(readiness.prompt_request.action, "task_readiness");
            assert_eq!(readiness.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                readiness.prompt_request.request.action,
                LlmPromptActionKind::TaskReadiness
            );
            assert!(readiness.safety_flags.read_only);
            assert!(!readiness.safety_flags.provider_request_sent);
            assert!(!readiness.safety_flags.write_back_allowed);
            assert!(!readiness.safety_flags.script_execution_allowed);
            assert!(!readiness.safety_flags.config_mutation_allowed);
            assert!(!readiness.safety_flags.snapshot_created);
            assert!(!readiness.safety_flags.triage_mutation_allowed);
            assert!(!readiness.safety_flags.credential_accessed);
            assert!(!readiness.safety_flags.raw_secret_returned);
            assert!(!readiness.safety_flags.raw_prompt_persisted);
            assert!(!readiness.safety_flags.raw_response_persisted);
        }
        "task.rankSkillRoutes" => {
            let ranking: WireSkillRouteRankingResult = decode_fixture_result(method, result, path);
            assert!(ranking.overall_confidence_score <= 100);
            assert!(ranking.catalog_available);
            assert!(!ranking.route_candidates.is_empty());
            assert!(ranking.prompt_request.available);
            assert_eq!(ranking.prompt_request.action, "routing_confidence");
            assert_eq!(ranking.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                ranking.prompt_request.request.action,
                LlmPromptActionKind::RoutingConfidence
            );
            assert!(ranking.safety_flags.read_only);
            assert!(!ranking.safety_flags.provider_request_sent);
            assert!(!ranking.safety_flags.write_back_allowed);
            assert!(!ranking.safety_flags.script_execution_allowed);
            assert!(!ranking.safety_flags.config_mutation_allowed);
            assert!(!ranking.safety_flags.snapshot_created);
            assert!(!ranking.safety_flags.triage_mutation_allowed);
            assert!(!ranking.safety_flags.credential_accessed);
            assert!(!ranking.safety_flags.raw_secret_returned);
            assert!(!ranking.safety_flags.raw_prompt_persisted);
            assert!(!ranking.safety_flags.raw_response_persisted);
        }
        "task.compareAgentReadiness" => {
            let comparison: WireAgentReadinessComparisonResult =
                decode_fixture_result(method, result, path);
            assert_eq!(comparison.generated_by, "deterministic-service");
            assert!(comparison.catalog_available);
            assert_eq!(comparison.summary.agent_count, comparison.agent_rows.len());
            assert!(comparison.summary.candidate_count >= comparison.agent_rows.len());
            assert!(!comparison.agent_rows.is_empty());
            assert!(comparison.recommended_agent.is_some());
            assert_eq!(comparison.prompt_request.action, "task_readiness");
            assert_eq!(
                comparison.prompt_request.preview_method,
                "llm.previewPrompt"
            );
            assert_eq!(
                comparison.prompt_request.request.action,
                LlmPromptActionKind::TaskReadiness
            );
            assert!(comparison.safety_flags.read_only);
            assert!(comparison.safety_flags.app_local_only);
            assert!(!comparison.safety_flags.provider_request_sent);
            assert!(!comparison.safety_flags.write_back_allowed);
            assert!(!comparison.safety_flags.write_actions_available);
            assert!(!comparison.safety_flags.skill_files_mutated);
            assert!(!comparison.safety_flags.agent_config_mutated);
            assert!(!comparison.safety_flags.script_execution_allowed);
            assert!(!comparison.safety_flags.execution_actions_available);
            assert!(!comparison.safety_flags.config_mutation_allowed);
            assert!(!comparison.safety_flags.snapshot_created);
            assert!(!comparison.safety_flags.triage_mutation_allowed);
            assert!(!comparison.safety_flags.credential_accessed);
            assert!(!comparison.safety_flags.raw_secret_returned);
            assert!(!comparison.safety_flags.raw_prompt_persisted);
            assert!(!comparison.safety_flags.raw_response_persisted);
            assert!(!comparison.safety_flags.raw_trace_persisted);
            assert!(!comparison.safety_flags.cloud_sync_performed);
            assert!(!comparison.safety_flags.telemetry_emitted);
        }
        "task.buildCockpit" => {
            let cockpit: WireTaskCockpitResult = decode_fixture_result(method, result, path);
            assert_eq!(cockpit.generated_by, "local-v2.73");
            assert_eq!(
                cockpit.summary.candidate_count,
                cockpit.skill_candidate_rows.len()
            );
            assert_eq!(cockpit.summary.agent_count, cockpit.agent_route_rows.len());
            assert_eq!(
                cockpit.summary.session_review_count,
                cockpit.session_review_rows.len()
            );
            assert_eq!(
                cockpit.summary.provider_observability_row_count,
                cockpit.provider_observability_rows.len()
            );
            assert_eq!(
                cockpit.summary.remediation_next_step_count,
                cockpit.remediation_next_steps.len()
            );
            assert_eq!(cockpit.prompt_request.action, "task_cockpit");
            assert_eq!(
                cockpit.prompt_request.request.action,
                LlmPromptActionKind::TaskCockpit
            );
            assert_agent_readiness_safety_flags(&cockpit.safety_flags);
            for section in &cockpit.cockpit_sections {
                assert_agent_readiness_safety_flags(&section.safety_flags);
            }
        }
        "skill.lifecycleTimeline" => {
            let timeline: WireSkillLifecycleTimelineResult =
                decode_fixture_result(method, result, path);
            assert_eq!(timeline.generated_by, "local-v2.66");
            assert_eq!(
                timeline.summary.total_event_count,
                timeline.timeline_rows.len()
            );
            assert_eq!(timeline.summary.skill_count, timeline.skill_rows.len());
            assert_eq!(timeline.summary.agent_count, timeline.agent_rows.len());
            assert_eq!(timeline.prompt_request.action, "skill_lifecycle_timeline");
            assert_eq!(
                timeline.prompt_request.request.action,
                LlmPromptActionKind::SkillLifecycleTimeline
            );
            assert_agent_readiness_safety_flags(&timeline.safety_flags);
            for row in &timeline.timeline_rows {
                assert_agent_readiness_safety_flags(&row.safety_flags);
            }
            for row in &timeline.skill_rows {
                assert_agent_readiness_safety_flags(&row.safety_flags);
            }
            for row in &timeline.agent_rows {
                assert_agent_readiness_safety_flags(&row.safety_flags);
            }
        }
        "session.previewLocalSessions" => {
            let preview: WireLocalSessionPreviewResult =
                decode_fixture_result(method, result, path);
            assert_eq!(preview.generated_by, "local-v2.98");
            assert!(preview.read_only);
            assert!(!preview.provider_request_sent);
            assert!(!preview.skill_files_mutated);
            assert!(!preview.agent_config_mutated);
            assert!(!preview.snapshot_created);
            assert!(!preview.triage_mutated);
            assert!(!preview.raw_prompt_persisted);
            assert!(!preview.raw_response_persisted);
            assert!(!preview.raw_trace_persisted);
            assert_eq!(preview.count, preview.session_rows.len());
            assert_eq!(
                preview.user_message_count,
                preview
                    .session_rows
                    .iter()
                    .map(|row| row.user_message_count)
                    .sum::<usize>()
            );
            assert_eq!(
                preview.total_message_count,
                preview
                    .session_rows
                    .iter()
                    .map(|row| row.total_message_count)
                    .sum::<usize>()
            );
            assert_eq!(
                preview.tool_call_count,
                preview
                    .session_rows
                    .iter()
                    .map(|row| row.tool_call_count)
                    .sum::<usize>()
            );
            assert_eq!(
                preview.skill_call_count,
                preview
                    .session_rows
                    .iter()
                    .map(|row| row.skill_call_count)
                    .sum::<usize>()
            );
            assert_agent_session_review_safety(&preview.safety_flags);
            assert!(!preview.redaction_summary.raw_trace_persisted);
            for row in &preview.skill_usage_rows {
                assert!(row.call_count >= row.session_count);
                assert!(!row.skill_name.is_empty());
                assert!(!row.evidence_refs.is_empty());
            }
            for row in &preview.session_rows {
                assert_eq!(row.source_kind, "authorized-local-session");
                assert!(!row.excerpt.is_empty());
                assert!(!row.evidence_refs.is_empty());
                assert!(!row.content_items.is_empty());
                assert!(row
                    .content_items
                    .iter()
                    .any(|item| item.kind == "skill_call"));
            }
        }
        "task.listBenchmarks" => {
            let benchmarks: WireTaskBenchmarkListResult =
                decode_fixture_result(method, result, path);
            assert_eq!(benchmarks.count, benchmarks.benchmarks.len());
            assert!(benchmarks.app_local_only);
            assert!(!benchmarks.provider_request_sent);
            assert!(!benchmarks.raw_prompt_persisted);
            assert!(!benchmarks.raw_response_persisted);
        }
        "task.saveBenchmark" => {
            let saved: WireSaveTaskBenchmarkResult = decode_fixture_result(method, result, path);
            assert!(!saved.benchmark.id.is_empty());
            assert!(saved.app_local_only);
            assert!(!saved.provider_request_sent);
            assert!(!saved.agent_config_mutated);
        }
        "task.deleteBenchmark" => {
            let deleted: WireDeleteTaskBenchmarkResult =
                decode_fixture_result(method, result, path);
            assert!(!deleted.benchmark_id.is_empty());
            assert!(deleted.app_local_only);
            assert!(!deleted.provider_request_sent);
            assert!(!deleted.agent_config_mutated);
        }
        "task.evaluateBenchmarks" => {
            let evaluation: WireTaskBenchmarkEvaluationResult =
                decode_fixture_result(method, result, path);
            assert_eq!(
                evaluation.evaluated_count,
                evaluation.benchmark_results.len()
            );
            assert!(evaluation.safety_flags.read_only);
            assert!(!evaluation.safety_flags.provider_request_sent);
            assert!(!evaluation.safety_flags.write_back_allowed);
            assert!(!evaluation.safety_flags.script_execution_allowed);
            assert!(!evaluation.safety_flags.config_mutation_allowed);
            assert!(!evaluation.safety_flags.snapshot_created);
            assert!(!evaluation.safety_flags.triage_mutation_allowed);
            assert!(!evaluation.safety_flags.credential_accessed);
            assert!(!evaluation.safety_flags.raw_secret_returned);
            assert!(!evaluation.safety_flags.raw_prompt_persisted);
            assert!(!evaluation.safety_flags.raw_response_persisted);
            assert_eq!(
                evaluation.prompt_request.request.action,
                LlmPromptActionKind::RoutingConfidence
            );
            for item in &evaluation.benchmark_results {
                assert!(item.score <= 100);
                assert!(item.safety_flags.read_only);
                assert!(!item.safety_flags.provider_request_sent);
                assert!(!item.safety_flags.write_back_allowed);
                assert!(!item.safety_flags.script_execution_allowed);
                assert!(!item.safety_flags.config_mutation_allowed);
                assert!(!item.safety_flags.snapshot_created);
                assert!(!item.safety_flags.triage_mutation_allowed);
                assert!(!item.safety_flags.credential_accessed);
                assert!(!item.safety_flags.raw_prompt_persisted);
                assert!(!item.safety_flags.raw_response_persisted);
            }
        }
        "task.saveRoutingBaseline" => {
            let saved: WireSaveRoutingBaselineResult = decode_fixture_result(method, result, path);
            assert_eq!(saved.benchmark_count, saved.baseline.evaluated_count);
            assert!(saved.app_local_only);
            assert_eq!(saved.baseline_file, "task-routing-baseline.json");
            assert!(!saved.provider_request_sent);
            assert!(!saved.agent_config_mutated);
            assert!(!saved.skill_files_mutated);
            assert!(!saved.raw_prompt_persisted);
            assert!(!saved.raw_response_persisted);
            assert!(saved.baseline.safety_flags.read_only);
            assert!(!saved.baseline.safety_flags.provider_request_sent);
        }
        "task.detectRoutingRegression" => {
            let detection: WireRoutingRegressionDetectionResult =
                decode_fixture_result(method, result, path);
            assert!(detection.safety_flags.read_only);
            assert!(!detection.safety_flags.provider_request_sent);
            assert!(!detection.safety_flags.write_back_allowed);
            assert!(!detection.safety_flags.script_execution_allowed);
            assert!(!detection.safety_flags.config_mutation_allowed);
            assert!(!detection.safety_flags.snapshot_created);
            assert!(!detection.safety_flags.triage_mutation_allowed);
            assert!(!detection.safety_flags.credential_accessed);
            assert!(!detection.safety_flags.raw_secret_returned);
            assert!(!detection.safety_flags.raw_prompt_persisted);
            assert!(!detection.safety_flags.raw_response_persisted);
            assert_eq!(
                detection.current_evaluation.evaluated_count,
                detection.current_evaluation.benchmark_results.len()
            );
            for item in &detection.items {
                assert!(item.safety_flags.read_only);
                assert!(!item.safety_flags.provider_request_sent);
                assert!(!item.safety_flags.write_back_allowed);
                assert!(!item.safety_flags.script_execution_allowed);
                assert!(!item.safety_flags.config_mutation_allowed);
                assert!(!item.safety_flags.snapshot_created);
                assert!(!item.safety_flags.triage_mutation_allowed);
                assert!(!item.safety_flags.credential_accessed);
                assert!(!item.safety_flags.raw_prompt_persisted);
                assert!(!item.safety_flags.raw_response_persisted);
            }
        }
        "routing.accuracyDashboard" => {
            let dashboard: WireRoutingAccuracyDashboardResult =
                decode_fixture_result(method, result, path);
            assert_eq!(dashboard.generated_by, "deterministic-service");
            assert!(dashboard.summary.accuracy_rate <= 1.0);
            assert!(dashboard.summary.known_outcome_rate <= 1.0);
            assert_eq!(dashboard.prompt_request.preview_method, "llm.previewPrompt");
            assert_eq!(
                dashboard.prompt_request.confirm_method,
                "llm.confirmPromptAndSend"
            );
            assert_eq!(dashboard.prompt_request.action, "routing_confidence");
            assert_eq!(
                dashboard.prompt_request.request.action,
                LlmPromptActionKind::RoutingConfidence
            );
            assert!(dashboard.safety_flags.read_only);
            assert!(dashboard.safety_flags.app_local_only);
            assert!(!dashboard.safety_flags.provider_request_sent);
            assert!(!dashboard.safety_flags.write_back_allowed);
            assert!(!dashboard.safety_flags.write_actions_available);
            assert!(!dashboard.safety_flags.skill_files_mutated);
            assert!(!dashboard.safety_flags.agent_config_mutated);
            assert!(!dashboard.safety_flags.script_execution_allowed);
            assert!(!dashboard.safety_flags.execution_actions_available);
            assert!(!dashboard.safety_flags.config_mutation_allowed);
            assert!(!dashboard.safety_flags.snapshot_created);
            assert!(!dashboard.safety_flags.triage_mutation_allowed);
            assert!(!dashboard.safety_flags.credential_accessed);
            assert!(!dashboard.safety_flags.raw_secret_returned);
            assert!(!dashboard.safety_flags.raw_prompt_persisted);
            assert!(!dashboard.safety_flags.raw_response_persisted);
            assert!(!dashboard.safety_flags.raw_trace_persisted);
            assert!(!dashboard.safety_flags.cloud_sync_performed);
            assert!(!dashboard.safety_flags.telemetry_emitted);
        }
        "session.reviewAgentSkillUse" => {
            let review: WireAgentSessionSkillReviewResult =
                decode_fixture_result(method, result, path);
            assert_eq!(review.generated_by, "local-v2.62");
            assert!(review.app_local_only);
            assert_eq!(review.review_file, "agent-session-reviews.json");
            assert!(!review.provider_request_sent);
            assert!(!review.skill_files_mutated);
            assert!(!review.agent_config_mutated);
            assert!(!review.snapshot_created);
            assert!(!review.triage_mutated);
            assert!(!review.raw_prompt_persisted);
            assert!(!review.raw_response_persisted);
            assert!(!review.raw_trace_persisted);
            assert_agent_session_review_safety(&review.review.safety_flags);
            assert!(!review.review.analysis.outcome.is_empty());
            assert!(!review.review.redaction_summary.raw_trace_persisted);
        }
        "session.listSkillReviews" => {
            let reviews: WireAgentSessionSkillReviewListResult =
                decode_fixture_result(method, result, path);
            assert_eq!(reviews.generated_by, "local-v2.62");
            assert_eq!(reviews.count, reviews.reviews.len());
            assert!(reviews.total_count >= reviews.count);
            assert!(reviews.app_local_only);
            assert_eq!(reviews.review_file, "agent-session-reviews.json");
            assert!(!reviews.provider_request_sent);
            assert!(!reviews.raw_prompt_persisted);
            assert!(!reviews.raw_response_persisted);
            assert!(!reviews.raw_trace_persisted);
            assert_agent_session_review_safety(&reviews.safety_flags);
            for review in &reviews.reviews {
                assert_agent_session_review_safety(&review.safety_flags);
                assert!(!review.redaction_summary.raw_trace_persisted);
            }
        }
        "session.deleteSkillReview" => {
            let deleted: WireAgentSessionSkillReviewDeleteResult =
                decode_fixture_result(method, result, path);
            assert!(!deleted.review_id.is_empty());
            assert!(deleted.app_local_only);
            assert!(!deleted.provider_request_sent);
            assert!(!deleted.skill_files_mutated);
            assert!(!deleted.agent_config_mutated);
            assert!(!deleted.snapshot_created);
            assert!(!deleted.triage_mutated);
            assert!(!deleted.raw_prompt_persisted);
            assert!(!deleted.raw_response_persisted);
            assert!(!deleted.raw_trace_persisted);
        }
        "trace.importLocal" => {
            let imported: WireTraceImportLocalResult = decode_fixture_result(method, result, path);
            assert_eq!(imported.generated_by, "deterministic-service");
            assert!(imported.app_local_only);
            assert_eq!(imported.import_file, "trace-imports.json");
            assert!(!imported.provider_request_sent);
            assert!(!imported.raw_trace_persisted);
            assert_trace_import_safety(&imported.import.safety_flags);
            assert!(!imported.import.excerpt.is_empty());
            assert!(!imported.import.redaction_summary.raw_trace_persisted);
            assert!(!imported.import.analysis.outcome.is_empty());
        }
        "trace.listImports" => {
            let imports: WireTraceImportListResult = decode_fixture_result(method, result, path);
            assert_eq!(imports.count, imports.imports.len());
            assert!(imports.app_local_only);
            assert!(!imports.provider_request_sent);
            assert!(!imports.raw_trace_persisted);
            for import in &imports.imports {
                assert_trace_import_safety(&import.safety_flags);
                assert!(!import.redaction_summary.raw_trace_persisted);
            }
        }
        "trace.deleteImport" => {
            let deleted: WireTraceDeleteImportResult = decode_fixture_result(method, result, path);
            assert!(!deleted.import_id.is_empty());
            assert!(deleted.app_local_only);
            assert!(!deleted.provider_request_sent);
            assert!(!deleted.raw_trace_persisted);
        }
        "llm.status" => {
            let status: WireLlmStatus = decode_fixture_result(method, result, path);
            assert!(!status.enabled);
            assert!(!status.configured);
            assert!(!status.credential_persistence_allowed);
        }
        "llm.listProviderProfiles" => {
            let profiles: WireListProviderProfilesResult =
                decode_fixture_result(method, result, path);
            assert!(!profiles.raw_secrets_returned);
        }
        "llm.saveProviderProfile" => {
            let saved: WireSaveProviderProfileResult = decode_fixture_result(method, result, path);
            assert!(!saved.raw_secret_returned);
        }
        "llm.deleteProviderProfile" => {
            let deleted: WireDeleteProviderProfileResult =
                decode_fixture_result(method, result, path);
            assert!(!deleted.raw_secret_returned);
        }
        "llm.testProviderConnection" => {
            let tested: WireTestProviderConnectionResult =
                decode_fixture_result(method, result, path);
            assert!(!tested.raw_prompt_persisted);
            assert!(!tested.raw_response_persisted);
            assert!(!tested.raw_secret_returned);
        }
        "llm.previewPrompt" => {
            let preview: WireLlmPreviewPromptResult = decode_fixture_result(method, result, path);
            assert!(preview.requires_confirmation);
            assert!(!preview.provider_request_sent);
            assert!(!preview.write_back_allowed);
            assert!(preview.draft_requires_user_copy);
            assert!(!preview.raw_secret_returned);
            assert!(!preview.raw_prompt_persisted);
            assert!(!preview.raw_response_persisted);
            assert!(!preview.redaction.raw_prompt_persisted);
            assert!(!preview.redaction.raw_response_persisted);
            assert!(!preview.redaction.raw_secret_returned);
        }
        "llm.confirmPromptAndSend" => {
            let confirmed: WireLlmConfirmPromptAndSendResult =
                decode_fixture_result(method, result, path);
            assert!(!confirmed.write_back_allowed);
            assert!(!confirmed.script_execution_allowed);
            assert!(!confirmed.config_mutation_allowed);
            assert!(!confirmed.snapshot_created);
            assert!(!confirmed.triage_mutation_allowed);
            assert!(!confirmed.raw_secret_returned);
            assert!(!confirmed.raw_prompt_persisted);
            assert!(!confirmed.raw_response_persisted);
        }
        "llm.listPromptRuns" => {
            let runs: WireLlmPromptRunListResult = decode_fixture_result(method, result, path);
            assert_eq!(runs.generated_by, "local-v2.61");
            assert_eq!(runs.count, runs.runs.len());
            assert!(runs.app_local_only);
            assert!(!runs.provider_request_sent);
            assert!(!runs.raw_prompt_persisted);
            assert!(!runs.raw_response_persisted);
            assert!(!runs.raw_secret_returned);
            assert!(runs.safety_flags.app_local_only);
            assert!(!runs.safety_flags.raw_prompt_persisted);
            assert!(!runs.safety_flags.raw_response_persisted);
            assert!(!runs.safety_flags.raw_secret_returned);
            for run in &runs.runs {
                assert!(run.safety_flags.app_local_only);
                assert!(!run.safety_flags.write_back_allowed);
                assert!(!run.safety_flags.script_execution_allowed);
                assert!(!run.safety_flags.raw_prompt_persisted);
                assert!(!run.safety_flags.raw_response_persisted);
                assert!(!run.redaction_summary.raw_prompt_persisted);
                assert!(!run.redaction_summary.raw_response_persisted);
            }
        }
        "llm.providerObservability" => {
            let observability: WireLlmProviderObservabilityResult =
                decode_fixture_result(method, result, path);
            assert_eq!(observability.generated_by, "local-v2.64");
            assert!(matches!(observability.status.as_str(), "ready" | "partial"));
            assert_eq!(
                observability.summary.returned_prompt_run_count,
                observability.history_rows.len()
            );
            assert_eq!(
                observability.summary.returned_call_row_count,
                observability.call_rows.len()
            );
            assert!(observability.prompt_metadata.copy_only);
            assert!(!observability.prompt_metadata.provider_request_sent);
            assert_provider_observability_safety(&observability.safety_flags);
            for row in &observability.history_rows {
                assert!(!row.raw_prompt_persisted);
                assert!(!row.raw_response_persisted);
                assert!(!row.evidence_refs.is_empty());
            }
            for row in &observability.call_rows {
                assert!(!row.raw_prompt_persisted);
                assert!(!row.raw_response_persisted);
                assert!(!row.evidence_refs.is_empty());
            }
            for recommendation in &observability.retention_recommendations {
                assert!(!recommendation.cleanup_action_available);
                assert!(!recommendation.write_action_available);
            }
            for row in &observability.model_task_history_rows {
                assert_model_task_match_safety(&row.safety_flags);
            }
        }
        "llm.listModelTaskMatches" => {
            let history: WireModelTaskMatchListResult = decode_fixture_result(method, result, path);
            assert_eq!(history.generated_by, "local-v2.91");
            assert_eq!(history.history_file, "model-task-matches.json");
            assert!(history.app_local_only);
            assert!(!history.provider_request_sent);
            assert!(!history.credential_accessed);
            assert!(!history.raw_prompt_persisted);
            assert!(!history.raw_response_persisted);
            assert!(!history.raw_trace_persisted);
            assert_model_task_match_safety(&history.safety_flags);
            assert_eq!(history.summary.returned_record_count, history.records.len());
            for record in &history.records {
                assert_model_task_match_safety(&record.safety_flags);
                assert!(!record.redaction_summary.raw_prompt_persisted);
                assert!(!record.redaction_summary.raw_response_persisted);
                assert!(!record.redaction_summary.raw_trace_persisted);
            }
            for row in &history.recent_evidence_rows {
                assert_model_task_match_safety(&row.safety_flags);
            }
        }
        "llm.recordModelTaskMatch" => {
            let recorded: WireModelTaskMatchRecordResult =
                decode_fixture_result(method, result, path);
            assert_eq!(recorded.generated_by, "local-v2.91");
            assert_eq!(recorded.history_file, "model-task-matches.json");
            assert!(recorded.app_local_only);
            assert!(!recorded.provider_request_sent);
            assert!(!recorded.skill_files_mutated);
            assert!(!recorded.agent_config_mutated);
            assert!(!recorded.snapshot_created);
            assert!(!recorded.triage_mutated);
            assert!(!recorded.raw_prompt_persisted);
            assert!(!recorded.raw_response_persisted);
            assert!(!recorded.raw_trace_persisted);
            assert_model_task_match_safety(&recorded.record.safety_flags);
        }
        "llm.deleteModelTaskMatch" => {
            let deleted: WireModelTaskMatchDeleteResult =
                decode_fixture_result(method, result, path);
            assert!(deleted.app_local_only);
            assert!(!deleted.provider_request_sent);
            assert!(!deleted.skill_files_mutated);
            assert!(!deleted.agent_config_mutated);
            assert!(!deleted.snapshot_created);
            assert!(!deleted.triage_mutated);
            assert!(!deleted.raw_prompt_persisted);
            assert!(!deleted.raw_response_persisted);
            assert!(!deleted.raw_trace_persisted);
        }
        "llm.prepareAction" => {
            let prepare: WireLlmPrepareActionResult = decode_fixture_result(method, result, path);
            assert!(!prepare.write_back_allowed);
            assert!(prepare.draft_requires_user_copy);
            assert!(prepare.confirmation.required);
        }
        "llm.prepareSkillAnalysis" => {
            let prepare: WireLlmPrepareSkillAnalysisResult =
                decode_fixture_result(method, result, path);
            assert!(!prepare.enabled);
            assert!(!prepare.provider_request_sent);
            assert!(!prepare.safety_flags.write_back_enabled);
            assert!(!prepare.safety_flags.script_execution_enabled);
            assert!(!prepare.safety_flags.credential_storage_enabled);
            assert!(prepare.safety_flags.confirmation_required);
            assert_eq!(
                prepare.selected_skill_count,
                prepare.included_skill_count + prepare.excluded_missing_count
            );
        }
        "cleanup.listQueue" => {
            let queue: WireCleanupQueue = decode_fixture_result(method, result, path);
            assert_eq!(queue.summary.total_count, queue.items.len());
            assert!(queue.summary.read_only);
            assert!(!queue.summary.writes_allowed);
            assert!(!queue.summary.provider_request_sent);
            assert!(queue.items.iter().all(|item| item.read_only));
            assert!(queue.items.iter().all(|item| !item.writes_allowed));
            assert!(queue.items.iter().all(|item| !item.provider_request_sent));
        }
        "cleanup.planGuidedFlow" => {
            let flow: WireGuidedCleanupFlowResult = decode_fixture_result(method, result, path);
            assert_eq!(flow.generated_by, "local-v2.67");
            assert!(flow.catalog_available);
            assert_eq!(flow.summary.returned_step_count, flow.flow_steps.len());
            assert_eq!(flow.summary.issue_group_count, flow.issue_groups.len());
            assert_eq!(
                flow.summary.safe_next_action_count,
                flow.safe_next_actions.len()
            );
            assert!(!flow.flow_steps.is_empty());
            assert!(!flow.issue_groups.is_empty());
            assert!(!flow.safe_next_actions.is_empty());
            assert_eq!(flow.prompt_request.action, "guided_cleanup_flow");
            assert_eq!(
                flow.prompt_request.request.action,
                LlmPromptActionKind::GuidedCleanupFlow
            );
            assert_remediation_history_safety(&flow.safety_flags);
            for step in &flow.flow_steps {
                assert!(step.rank > 0);
                assert_remediation_history_safety(&step.safety_flags);
                assert_remediation_history_safety(&step.safe_action_deep_link.safety_flags);
                assert!(!step.safe_action_deep_link.can_apply);
                assert!(!matches!(
                    step.safe_action_deep_link.method.as_str(),
                    "batch.applySkillToggles"
                        | "config.toggleSkill"
                        | "script.execute"
                        | "llm.confirmPromptAndSend"
                ));
                assert!(step
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "provider_request_sent=false"));
                assert!(step
                    .side_effect_flags
                    .iter()
                    .any(|flag| flag == "skill_files_mutated=false"));
            }
            for group in &flow.issue_groups {
                assert_remediation_history_safety(&group.safety_flags);
            }
            for action in &flow.safe_next_actions {
                assert_remediation_history_safety(&action.safety_flags);
                assert_remediation_history_safety(&action.deep_link.safety_flags);
                assert!(!action.deep_link.can_apply);
                assert!(!matches!(
                    action.deep_link.method.as_str(),
                    "batch.applySkillToggles"
                        | "config.toggleSkill"
                        | "script.execute"
                        | "llm.confirmPromptAndSend"
                ));
            }
            for record in &flow.recorded_steps {
                assert_remediation_history_safety(&record.safety_flags);
            }
        }
        "cleanup.recordGuidedStep" => {
            let result: WireGuidedCleanupRecordStepResult =
                decode_fixture_result(method, result, path);
            assert_eq!(result.generated_by, "local-v2.67");
            assert!(result.app_local_only);
            assert!(!result.provider_request_sent);
            assert!(!result.skill_files_mutated);
            assert!(!result.agent_config_mutated);
            assert!(!result.snapshot_created);
            assert!(!result.rollback_performed);
            assert!(!result.triage_mutated);
            assert!(!result.script_executed);
            assert!(!result.credential_accessed);
            assert!(!result.raw_prompt_persisted);
            assert!(!result.raw_response_persisted);
            assert!(!result.raw_trace_persisted);
            assert_remediation_history_safety(&result.safety_flags);
            assert_remediation_history_safety(&result.record.safety_flags);
        }
        "rules.listTuning" => {
            let _: Vec<WireRuleTuningRecord> = decode_fixture_result(method, result, path);
        }
        "rules.setSeverityOverride" | "rules.setSuppression" => {
            let tuning: WireRuleTuningRecord = decode_fixture_result(method, result, path);
            assert!(!tuning.rule_id.is_empty());
            assert!(tuning.severity_override.is_some() || tuning.suppression_reason.is_some());
        }
        "rules.clearSeverityOverride" | "rules.clearSuppression" => {
            let _: bool = decode_fixture_result(method, result, path);
        }
        "batch.previewSkillToggles" => {
            let preview: WireBatchTogglePreviewRecord = decode_fixture_result(method, result, path);
            assert_eq!(
                preview.requested_count,
                preview.writable_count + preview.skipped_count
            );
            assert_eq!(preview.writable_count, preview.affected_items.len());
            assert_eq!(preview.skipped_count, preview.skipped_items.len());
            assert_eq!(preview.writes_allowed, preview.writable_count > 0);
            assert!(!preview.preview_token.is_empty());
            assert!(!preview.capability_labels.is_empty());
            assert!(!preview.snapshot_rollback_notes.is_empty());
        }
        "batch.applySkillToggles" => {
            let applied: WireBatchToggleApplyRecord = decode_fixture_result(method, result, path);
            assert_eq!(
                applied.requested_count,
                applied.writable_count + applied.skipped_count
            );
            assert_eq!(applied.applied_count, applied.updated_records.len());
            assert!(applied.writes_allowed);
            assert!(!applied.preview_token.is_empty());
            assert!(!applied.snapshot_rollback_notes.is_empty());
        }
        "script.previewExecution" => {
            let preview: WireScriptExecutionPreviewRecord =
                decode_fixture_result(method, result, path);
            assert!(!preview.execution_allowed);
            assert!(preview.confirmation.required);
            assert!(!preview.command_preview.argv.is_empty());
        }
        "script.execute" => {
            let attempt: WireScriptExecutionAttemptRecord =
                decode_fixture_result(method, result, path);
            assert_eq!(attempt.status, "blocked");
            assert!(!attempt.spawned_process);
            assert!(!attempt.preview.execution_allowed);
        }
        "skillManager.listTools" => {
            let tools: Vec<WireSkillManagerToolRecord> =
                decode_fixture_result(method, result, path);
            let npx = tools
                .iter()
                .find(|tool| tool.id == "npx-skills")
                .expect("npx skills tool fixture");
            assert_skill_manager_agents(&npx.default_agents);
            assert!(npx
                .operations
                .iter()
                .any(|operation| operation == "applyInstall"));
        }
        "skillManager.search" => {
            let search: WireSkillManagerSearchRecord = decode_fixture_result(method, result, path);
            assert_eq!(search.preview.operation, "search");
            assert!(!search.preview.requires_confirmation);
            assert!(search.preview.network_required);
            assert!(!search.preview.will_run);
        }
        "skillManager.listInstalled" => {
            let installed: WireSkillManagerInstalledListRecord =
                decode_fixture_result(method, result, path);
            assert_eq!(installed.preview.operation, "listInstalled");
            assert!(installed.preview.command.iter().any(|arg| arg == "--json"));
            assert!(!installed.installed.is_empty());
        }
        "skillManager.previewInstall"
        | "skillManager.applyInstall"
        | "skillManager.previewRemove"
        | "skillManager.applyRemove"
        | "skillManager.previewUpdate"
        | "skillManager.applyUpdate" => {
            let mutation: WireSkillManagerMutationRecord =
                decode_fixture_result(method, result, path);
            assert!(mutation.preview.command.iter().any(|arg| arg == "skills"));
            assert!(!mutation.preview.command.iter().any(|arg| arg == "*"));
            assert!(!mutation.preview.preview_token.is_empty());
            assert_eq!(mutation.applied, method.contains(".apply"));
            if method.contains("preview") {
                assert!(mutation.output.is_none());
                assert!(!mutation.preview.confirmed);
            }
            if method.contains("apply") {
                assert!(mutation.output.is_some());
                assert!(mutation.preview.confirmed);
            }
            if method.ends_with("Install") && method.contains("preview") {
                assert_eq!(
                    mutation
                        .preview
                        .command
                        .iter()
                        .filter(|arg| arg.as_str() == "--agent")
                        .count(),
                    6
                );
                assert!(!mutation.preview.command.iter().any(|arg| arg == "--copy"));
            }
        }
        "skillManager.previewLocalCreate" | "skillManager.applyLocalCreate" => {
            let create: WireSkillManagerLocalCreateRecord =
                decode_fixture_result(method, result, path);
            assert_eq!(create.preview.operation, "localCreate");
            assert!(create.source_path.contains("local-skill-library"));
            assert_eq!(create.applied, method.contains(".apply"));
            if create.applied {
                assert_eq!(
                    create.imported.as_ref().expect("imported skill").agent,
                    "tool-global"
                );
            }
        }
        "skillManager.deleteLocal" => {
            let delete: WireSkillManagerLocalDeleteRecord =
                decode_fixture_result(method, result, path);
            assert!(delete.app_owned);
            assert!(!delete.deleted);
            assert!(!delete.blocked_by_references.is_empty());
        }
        "project.getContext" | "project.setContext" | "project.clearContext" => {
            let _: ProjectContextState = decode_fixture_result(method, result, path);
            let state: WireProjectContextState = decode_fixture_result(method, result, path);
            assert!(
                state.active.is_some() || !state.recent.is_empty(),
                "{method} fixture should cover active or recent context state"
            );
        }
        "project.validateContext" => {
            let _: ProjectContext = decode_fixture_result(method, result, path);
            let context: WireProjectContext = decode_fixture_result(method, result, path);
            assert!(!context.root_path.is_empty());
        }
        "catalog.scanClaude" | "catalog.scanAll" => {
            let scan: WireScanResult = decode_fixture_result(method, result, path);
            assert_eq!(scan.activity.operation, method);
            assert_eq!(scan.scanned_count, scan.activity.scanned_count);
            if method == "catalog.scanAll" {
                let agents = scan
                    .activity
                    .agent_summaries
                    .as_ref()
                    .expect("scanAll fixture should include agent summaries");
                for agent in ["claude-code", "codex", "opencode"] {
                    assert!(
                        agents.iter().any(|summary| summary.agent == agent),
                        "scanAll fixture missing {agent} summary"
                    );
                    assert!(
                        scan.skills.iter().any(|skill| skill.agent == agent),
                        "scanAll fixture missing {agent} skill"
                    );
                }
            }
        }
        "catalog.listSkills" => {
            let _: Vec<WireSkillRecord> = decode_fixture_result(method, result, path);
        }
        "catalog.getSkill" => {
            let skill: WireSkillDetailRecord = decode_fixture_result(method, result, path);
            assert_v28_permissions_payload(&skill.permissions, method);
        }
        "catalog.analysis" => {
            let analysis: WireCrossAgentAnalysisRecord =
                decode_fixture_result(method, result, path);
            assert_eq!(analysis.summary.total_groups, analysis.groups.len());
        }
        "comparison.listCrossAgent" => {
            let comparison: CrossAgentComparisonRecord =
                decode_fixture_result(method, result, path);
            assert_eq!(comparison.summary.total_groups, comparison.groups.len());
            assert!(!comparison.suggested_next_steps.is_empty());
        }
        "report.exportLocal" => {
            let export: WireReportExportLocalResult = decode_fixture_result(method, result, path);
            assert!(export.redaction.enabled);
            assert!(export.read_only);
            assert!(!export.writes_allowed);
            assert!(!export.provider_request_sent);
            assert!(!export.script_execution_allowed);
            assert!(!export.credential_accessed);
            assert!(!export.files.is_empty());
            assert!(export
                .files
                .iter()
                .all(|file| file.path.starts_with("<app-data-dir>/")));
        }
        "catalog.listFindings" => {
            let findings: Vec<WireRuleFindingRecord> = decode_fixture_result(method, result, path);
            assert_findings_cover_v28_contract(
                &findings,
                &[
                    "frontmatter.required-fields",
                    "path.outside-workspace",
                    "fingerprint.changed",
                ],
                method,
            );
        }
        "catalog.listFindingTriage" | "catalog.setFindingTriage" => {
            let _: serde_json::Value = result.clone();
            if method == "catalog.listFindingTriage" {
                let _: Vec<WireFindingTriageRecord> = decode_fixture_result(method, result, path);
            } else {
                let _: WireFindingTriageRecord = decode_fixture_result(method, result, path);
            }
        }
        "catalog.clearFindingTriage" => {
            let _: bool = decode_fixture_result(method, result, path);
        }
        "catalog.listConflicts" => {
            let _: Vec<WireConflictGroupRecord> = decode_fixture_result(method, result, path);
        }
        "catalog.importSkill" => {
            let import: WireToolGlobalImportResult = decode_fixture_result(method, result, path);
            assert_eq!(import.imported.agent, "tool-global");
            assert_eq!(import.imported.scope, "tool-global");
            assert!(import.audit.read_only_preview);
            assert_eq!(import.instance_id, import.imported.id);
        }
        "config.toggleSkill" => {
            let _: WireSkillRecord = decode_fixture_result(method, result, path);
        }
        "skill.exportBundle" => {
            let export: WireExportedSkillBundle = decode_fixture_result(method, result, path);
            assert_eq!(export.metadata.skill_path, "skill/SKILL.md");
            assert!(!export.fingerprint.is_empty());
        }
        "skill.install" => {
            let install: WireSkillInstallPreviewRecord =
                decode_fixture_result(method, result, path);
            assert!(install.confirmation.required);
            assert!(!install.files.is_empty());
        }
        "skill.listEvents" => {
            let _: Vec<WireSkillEventRecord> = decode_fixture_result(method, result, path);
        }
        "config.readAgentConfig" => {
            let _: Vec<WireConfigDocumentRecord> = decode_fixture_result(method, result, path);
        }
        "config.readClaudeSettings" | "config.saveClaudeSettings" => {
            let _: WireConfigDocumentRecord = decode_fixture_result(method, result, path);
        }
        "snapshot.list" | "snapshot.listAgentConfig" => {
            let _: Vec<WireConfigSnapshotRecord> = decode_fixture_result(method, result, path);
        }
        "snapshot.previewRollback" => {
            let _: WireSnapshotRollbackPreviewRecord = decode_fixture_result(method, result, path);
        }
        "snapshot.rollback" => {
            let _: usize = decode_fixture_result(method, result, path);
        }
        _ => panic!("no typed response decoder for fixture method {method}"),
    }
}

pub(super) fn fixture_method_from_name<'a>(name: &'a str, suffix: &str) -> &'a str {
    let stem = name
        .strip_suffix(suffix)
        .unwrap_or_else(|| panic!("fixture {name} missing suffix {suffix}"));
    supported_methods()
        .into_iter()
        .filter(|method| stem == *method || stem.starts_with(&format!("{method}.")))
        .max_by_key(|method| method.len())
        .unwrap_or(stem)
}

pub(super) fn decode_fixture_result<T: DeserializeOwned>(
    method: &str,
    result: &Value,
    path: &Path,
) -> T {
    serde_json::from_value::<T>(result.clone()).unwrap_or_else(|error| {
        panic!(
            "response fixture {} result for {method} failed typed decode: {error}",
            path.display()
        )
    })
}

pub(super) fn assert_supported_methods(method: &str, actual: &[String]) {
    let expected: Vec<String> = supported_methods()
        .into_iter()
        .map(ToOwned::to_owned)
        .collect();
    let missing = expected
        .iter()
        .filter(|method| !actual.iter().any(|actual| actual == *method))
        .collect::<Vec<_>>();
    let only_v262_inline_missing = !missing.is_empty()
        && missing.iter().all(|method| {
            matches!(
                method.as_str(),
                "session.reviewAgentSkillUse"
                    | "session.listSkillReviews"
                    | "session.deleteSkillReview"
            )
        })
        && actual
            .iter()
            .all(|method| expected.iter().any(|expected| expected == method));
    if only_v262_inline_missing {
        return;
    }
    assert_eq!(actual, expected, "{method} supported_methods drifted");
}

pub(super) fn assert_skill_manager_agents(actual: &[String]) {
    assert_eq!(
        actual,
        vec![
            "claude-code",
            "pi",
            "opencode",
            "codex",
            "hermes-agent",
            "openclaw"
        ]
        .into_iter()
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>()
    );
}

pub(super) fn assert_trace_import_safety(flags: &WireTraceImportSafetyFlags) {
    assert!(flags.read_only);
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.write_back_allowed);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.credential_accessed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_agent_session_review_safety(flags: &WireAgentSessionSkillReviewSafetyFlags) {
    assert!(flags.read_only);
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.write_back_allowed);
    assert!(!flags.write_actions_available);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.execution_actions_available);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.credential_accessed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_provider_observability_safety(
    flags: &WireLlmProviderObservabilitySafetyFlags,
) {
    assert!(flags.read_only);
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.credential_accessed);
    assert!(flags.draft_copy_only);
    assert!(!flags.write_back_allowed);
    assert!(!flags.write_actions_available);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.execution_actions_available);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.unredacted_paths_returned);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_model_task_match_safety(flags: &WireModelTaskMatchSafetyFlags) {
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.credential_accessed);
    assert!(flags.draft_copy_only);
    assert!(!flags.write_back_allowed);
    assert!(!flags.write_actions_available);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.execution_actions_available);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.unredacted_paths_returned);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_remediation_history_safety(flags: &WireRemediationHistorySafetyFlags) {
    assert!(flags.read_only);
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.write_back_allowed);
    assert!(!flags.write_actions_available);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.execution_actions_available);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.rollback_performed);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.credential_accessed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_routing_accuracy_dashboard_safety(result: &Value) {
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/app_local_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    for path in [
        "/safety_flags/provider_request_sent",
        "/safety_flags/write_back_allowed",
        "/safety_flags/write_actions_available",
        "/safety_flags/skill_files_mutated",
        "/safety_flags/agent_config_mutated",
        "/safety_flags/script_execution_allowed",
        "/safety_flags/execution_actions_available",
        "/safety_flags/config_mutation_allowed",
        "/safety_flags/snapshot_created",
        "/safety_flags/triage_mutation_allowed",
        "/safety_flags/credential_accessed",
        "/safety_flags/raw_secret_returned",
        "/safety_flags/raw_prompt_persisted",
        "/safety_flags/raw_response_persisted",
        "/safety_flags/raw_trace_persisted",
        "/safety_flags/cloud_sync_performed",
        "/safety_flags/telemetry_emitted",
    ] {
        assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(false));
    }
}

pub(super) fn assert_guided_cleanup_safety(result: &Value) {
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/app_local_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    for path in [
        "/safety_flags/provider_request_sent",
        "/safety_flags/write_back_allowed",
        "/safety_flags/write_actions_available",
        "/safety_flags/skill_files_mutated",
        "/safety_flags/agent_config_mutated",
        "/safety_flags/script_execution_allowed",
        "/safety_flags/execution_actions_available",
        "/safety_flags/config_mutation_allowed",
        "/safety_flags/snapshot_created",
        "/safety_flags/rollback_performed",
        "/safety_flags/triage_mutation_allowed",
        "/safety_flags/credential_accessed",
        "/safety_flags/raw_secret_returned",
        "/safety_flags/raw_prompt_persisted",
        "/safety_flags/raw_response_persisted",
        "/safety_flags/raw_trace_persisted",
        "/safety_flags/cloud_sync_performed",
        "/safety_flags/telemetry_emitted",
    ] {
        assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(false));
    }
}

pub(super) fn assert_agent_readiness_safety(result: &Value) {
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/app_local_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    for path in [
        "/safety_flags/provider_request_sent",
        "/safety_flags/write_back_allowed",
        "/safety_flags/write_actions_available",
        "/safety_flags/skill_files_mutated",
        "/safety_flags/agent_config_mutated",
        "/safety_flags/script_execution_allowed",
        "/safety_flags/execution_actions_available",
        "/safety_flags/config_mutation_allowed",
        "/safety_flags/snapshot_created",
        "/safety_flags/triage_mutation_allowed",
        "/safety_flags/credential_accessed",
        "/safety_flags/raw_secret_returned",
        "/safety_flags/raw_prompt_persisted",
        "/safety_flags/raw_response_persisted",
        "/safety_flags/raw_trace_persisted",
        "/safety_flags/cloud_sync_performed",
        "/safety_flags/telemetry_emitted",
    ] {
        assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(false));
    }
}

pub(super) fn assert_agent_readiness_safety_flags(flags: &WireAgentReadinessSafetyFlags) {
    assert!(flags.read_only);
    assert!(flags.app_local_only);
    assert!(!flags.provider_request_sent);
    assert!(!flags.write_back_allowed);
    assert!(!flags.write_actions_available);
    assert!(!flags.skill_files_mutated);
    assert!(!flags.agent_config_mutated);
    assert!(!flags.script_execution_allowed);
    assert!(!flags.execution_actions_available);
    assert!(!flags.config_mutation_allowed);
    assert!(!flags.snapshot_created);
    assert!(!flags.triage_mutation_allowed);
    assert!(!flags.credential_accessed);
    assert!(!flags.raw_secret_returned);
    assert!(!flags.raw_prompt_persisted);
    assert!(!flags.raw_response_persisted);
    assert!(!flags.raw_trace_persisted);
    assert!(!flags.cloud_sync_performed);
    assert!(!flags.telemetry_emitted);
}

pub(super) fn assert_findings_cover_v28_contract(
    findings: &[WireRuleFindingRecord],
    expected_rule_ids: &[&str],
    method: &str,
) {
    for rule_id in expected_rule_ids {
        let finding = findings
            .iter()
            .find(|finding| finding.rule_id == *rule_id)
            .unwrap_or_else(|| panic!("{method} fixture missing V2.8 rule id {rule_id}"));
        assert!(
            finding
                .suggestion
                .as_deref()
                .is_some_and(|suggestion| !suggestion.is_empty()),
            "{method} fixture rule {rule_id} should include suggestion text"
        );
    }
}

pub(super) fn assert_v28_permissions_payload(permissions: &Value, method: &str) {
    let Some(object) = permissions.as_object() else {
        panic!("{method} fixture permissions should be an object");
    };
    for key in ["raw", "normalized", "unknown_safe"] {
        assert!(
            object.contains_key(key),
            "{method} fixture permissions missing {key} payload"
        );
    }
    assert_eq!(
        permissions
            .get("normalized")
            .and_then(|payload| payload.get("network"))
            .and_then(Value::as_str),
        Some("unknown"),
        "{method} fixture should preserve unknown normalized network state"
    );
    assert_eq!(
        permissions
            .get("unknown_safe")
            .and_then(|payload| payload.get("network"))
            .and_then(Value::as_str),
        Some("none"),
        "{method} fixture should include unknown-safe network fallback"
    );
}

#[test]
pub(super) fn skill_detail_contract_accepts_legacy_and_v28_permission_payloads() {
    let base = serde_json::json!({
        "id": "skill-instance-id",
        "agent": "claude-code",
        "scope": "agent-global",
        "path": "/tmp/skills-copilot-home/.claude/skills/demo/SKILL.md",
        "display_path": "/tmp/skills-copilot-home/.claude/skills/demo/SKILL.md",
        "definition_id": "definition-id",
        "name": "demo",
        "description": "Fixture skill",
        "state": "loaded",
        "enabled": true,
        "frontmatter_raw": "name: demo\ndescription: Fixture skill\n",
        "body": "Fixture body.",
        "fingerprint": "fixture-fingerprint"
    });

    for permissions in [
        serde_json::json!({}),
        serde_json::json!({
            "tools": ["Read"],
            "files": [],
            "network": "none",
            "exec": false,
            "requires_human": false
        }),
        serde_json::json!({
            "raw": {
                "allowed-tools": "Read",
                "network": "unexpected-network-mode"
            },
            "normalized": {
                "tools": ["Read"],
                "files": [],
                "network": "unknown",
                "exec": false,
                "requires_human": true
            },
            "unknown_safe": {
                "tools": [],
                "files": [],
                "network": "none",
                "exec": false,
                "requires_human": true
            }
        }),
    ] {
        let mut payload = base.clone();
        payload["permissions"] = permissions;
        let _: WireSkillDetailRecord = serde_json::from_value(payload)
            .expect("skill detail fixture should decode permissions payload variant");
    }
}
