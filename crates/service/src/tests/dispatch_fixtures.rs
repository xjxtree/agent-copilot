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
        assert!(
            error.message.contains("service.notReal"),
            "unknown method error should name the method"
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    fn dispatch_coverage_params(method: &str) -> Value {
        match method {
            "catalog.getSkill" | "config.toggleSkill" => {
                json!({ "instance_id": "missing-skill", "on": false })
            }
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
    struct WireAppVersion {
        protocol_version: u32,
        version: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireServiceStatus {
        protocol_version: u32,
        version: String,
        app_data_dir: String,
        catalog_path: String,
        user_home: String,
        supported_methods: Vec<String>,
        refresh: WireRefreshStatus,
        project_context: WireProjectContextSummary,
        llm: WireLlmStatus,
        trace_imports: WireTraceImportStatus,
        #[serde(default)]
        session_reviews: Option<WireAgentSessionSkillReviewStatus>,
        script_execution: WireScriptExecutionStatus,
        adapter_capabilities: Vec<WireAdapterCapabilityRecord>,
        #[serde(default)]
        adapter_diagnostics: Option<Vec<WireAdapterDiagnosticsRecord>>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAppStateSnapshot {
        status: WireServiceStatus,
        skills: Vec<WireSkillRecord>,
        findings: Vec<WireRuleFindingRecord>,
        conflicts: Vec<WireConflictGroupRecord>,
        analysis: WireCrossAgentAnalysisRecord,
        health: SkillHealthSummary,
        snapshots: Vec<WireConfigSnapshotRecord>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportStatus {
        count: usize,
        imports_path: String,
        app_local_only: bool,
        raw_trace_persistence_allowed: bool,
        provider_request_allowed: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewStatus {
        count: usize,
        reviews_path: String,
        app_local_only: bool,
        raw_trace_persistence_allowed: bool,
        provider_request_allowed: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCrossAgentAnalysisRecord {
        summary: WireCrossAgentAnalysisSummary,
        groups: Vec<WireCrossAgentAnalysisGroup>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCrossAgentAnalysisSummary {
        total_groups: usize,
        duplicate_name_groups: usize,
        canonical_name_groups: usize,
        path_overlap_groups: usize,
        enabled_mismatch_groups: usize,
        malformed_groups: usize,
        precedence_groups: usize,
        affected_skill_count: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCrossAgentAnalysisGroup {
        id: String,
        kind: String,
        severity: String,
        title: String,
        canonical_name: Option<String>,
        explanation: String,
        instance_ids: Vec<String>,
        winner_id: Option<String>,
        agents: Vec<String>,
        scopes: Vec<String>,
        paths: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterCapabilityRecord {
        agent: String,
        display_name: String,
        status: String,
        scan: WireAdapterFeatureCapability,
        project_scan: WireAdapterFeatureCapability,
        config_toggle: WireAdapterFeatureCapability,
        config_snapshot: WireAdapterFeatureCapability,
        install: WireAdapterFeatureCapability,
        writable: WireAdapterFeatureCapability,
        blockers: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterFeatureCapability {
        supported: bool,
        status: String,
        reason: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticsRecord {
        agent: String,
        display_name: String,
        status: String,
        roots: Vec<WireAdapterDiagnosticRootRecord>,
        config: WireAdapterDiagnosticConfigSummary,
        access: WireAdapterDiagnosticAccessSummary,
        last_scan: WireAdapterDiagnosticLastScan,
        blockers: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticRootRecord {
        path: String,
        scope: String,
        source: String,
        exists: bool,
        status: String,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticConfigSummary {
        status: String,
        detected_count: usize,
        paths: Vec<WireAdapterDiagnosticConfigPath>,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticConfigPath {
        path: String,
        detected: bool,
        status: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticAccessSummary {
        read_only: bool,
        writable_supported: bool,
        writable_status: String,
        writable_reason: Option<String>,
        install_supported: bool,
        install_status: String,
        install_reason: Option<String>,
        read_only_reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAdapterDiagnosticLastScan {
        status: String,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WirePiWritableHarnessReport {
        harness: String,
        production_writes_enabled: bool,
        disposable_root: String,
        report_path: String,
        scenarios: Vec<WirePiWritableHarnessScenario>,
        safety: WirePiWritableHarnessSafety,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WirePiWritableHarnessScenario {
        name: String,
        layer: String,
        config_path: String,
        skill_name: String,
        initial_enabled: bool,
        disabled_after_toggle: bool,
        reenabled_after_toggle: bool,
        rollback_restored: bool,
        invalid_json_blocked: bool,
        trust_gate_blocked: bool,
        writes_confined_to_disposable_root: bool,
        snapshot_content: String,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WirePiWritableHarnessSafety {
        disposable_only: bool,
        production_writes_enabled: bool,
        provider_request_sent: bool,
        script_execution_allowed: bool,
        credential_accessed: bool,
        install_performed: bool,
        production_config_mutated: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualityScoreResult {
        instance_id: String,
        definition_id: String,
        agent: String,
        scope: String,
        skill_name: String,
        score: u8,
        grade: String,
        band: String,
        generated_by: String,
        components: Vec<WireSkillQualityScoreComponent>,
        reasons: Vec<String>,
        risk_notes: Vec<String>,
        evidence_references: Vec<WireSkillQualityEvidenceReference>,
        suggested_improvements: Vec<WireSkillQualitySuggestion>,
        prompt_request: WireSkillQualityPromptRequest,
        safety_flags: WireSkillQualitySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualityScoreComponent {
        id: String,
        label: String,
        score: u8,
        max_score: u8,
        summary: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualityEvidenceReference {
        id: String,
        source_type: String,
        source_id: String,
        label: String,
        severity: Option<String>,
        related_instance_id: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualitySuggestion {
        priority: String,
        title: String,
        detail: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualityPromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillQualitySafetyFlags {
        read_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftDetectionResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireStaleDriftFilters,
        summary: WireStaleDriftSummary,
        stale_drift_rows: Vec<WireStaleDriftRow>,
        readiness_impact_rows: Vec<WireStaleDriftReadinessImpactRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftFilters {
        agent: Option<String>,
        candidate_instance_ids: Vec<String>,
        limit: usize,
        stale_days: u32,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftSummary {
        scanned_skill_count: usize,
        returned_row_count: usize,
        stale_count: usize,
        drift_count: usize,
        high_risk_count: usize,
        medium_risk_count: usize,
        low_risk_count: usize,
        missing_history_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftRow {
        rank: usize,
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        stale_drift_score: u8,
        stale_drift_band: String,
        drift_signals: WireStaleDriftSignals,
        readiness_impact: Option<WireStaleDriftReadinessImpact>,
        reasons: Vec<String>,
        gap_notes: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftSignals {
        fingerprint_drift: bool,
        finding_drift: bool,
        source_drift: bool,
        modified_age_days: Option<i64>,
        stale_by_mtime: bool,
        missing_mtime: bool,
        missing_previous_scan: bool,
        related_finding_count: usize,
        related_conflict_count: usize,
        related_analysis_count: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftReadinessImpact {
        impact_level: String,
        readiness_risk_score: u8,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireStaleDriftReadinessImpactRow {
        instance_id: String,
        skill_name: String,
        agent: String,
        impact_level: String,
        stale_drift_score: u8,
        notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchResult {
        generated_by: String,
        catalog_available: bool,
        summary: WireKnowledgeSearchSummary,
        filters: WireKnowledgeSearchFilters,
        rows: Vec<WireKnowledgeSearchRow>,
        facets: WireKnowledgeSearchFacets,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchSummary {
        indexed_skill_count: usize,
        matched_row_count: usize,
        returned_row_count: usize,
        enabled_count: usize,
        disabled_count: usize,
        high_risk_count: usize,
        stale_or_drift_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchFilters {
        query: Option<String>,
        normalized_terms: Vec<String>,
        agent: Option<String>,
        limit: usize,
        risk: Option<String>,
        scope: Option<String>,
        enabled: Option<bool>,
        tool: Option<String>,
        keyword: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchFacets {
        agents: BTreeMap<String, usize>,
        scopes: BTreeMap<String, usize>,
        states: BTreeMap<String, usize>,
        enabled: BTreeMap<String, usize>,
        risks: BTreeMap<String, usize>,
        tools: BTreeMap<String, usize>,
        keywords: BTreeMap<String, usize>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchRow {
        rank: usize,
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        source: WireKnowledgeSearchSource,
        purpose_snippet: Option<String>,
        description_snippet: Option<String>,
        matched_fields: Vec<String>,
        match_reasons: Vec<String>,
        keywords: Vec<String>,
        tools: Vec<String>,
        rules: Vec<String>,
        capability_tags: Vec<String>,
        risk_tags: Vec<String>,
        quality_context: Option<WireKnowledgeQualityContext>,
        readiness_context: Option<WireKnowledgeReadinessContext>,
        stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeSearchSource {
        source_path: String,
        display_path: String,
        root_provenance: String,
        fingerprint: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeQualityContext {
        score: u8,
        grade: String,
        band: String,
        reasons: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeReadinessContext {
        score: u8,
        band: String,
        risk_level: String,
        risk_summary: String,
        gap_count: usize,
        blocker_count: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireKnowledgeStaleDriftContext {
        score: u8,
        band: String,
        fingerprint_drift: bool,
        finding_drift: bool,
        source_drift: bool,
        stale_by_mtime: bool,
        readiness_impact_level: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSimilarSkillGroupingResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireSimilarSkillGroupingFilters,
        summary: WireSimilarSkillGroupingSummary,
        groups: Vec<WireSimilarSkillGroup>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSimilarSkillGroupingFilters {
        agent: Option<String>,
        limit: usize,
        min_score: u8,
        include_singletons: bool,
        candidate_instance_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSimilarSkillGroupingSummary {
        indexed_skill_count: usize,
        candidate_skill_count: usize,
        matched_group_count: usize,
        returned_group_count: usize,
        duplicate_group_count: usize,
        confusable_group_count: usize,
        coverage_redundancy_group_count: usize,
        routing_ambiguity_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSimilarSkillGroup {
        group_id: String,
        rank: usize,
        group_type: String,
        similarity_score: u8,
        ambiguity_risk: String,
        coverage_redundancy: String,
        routing_ambiguity: String,
        canonical_name: String,
        canonical_key: String,
        title: String,
        summary: String,
        why_grouped: Vec<String>,
        shared_terms: Vec<String>,
        shared_tools: Vec<String>,
        shared_rules: Vec<String>,
        shared_capability_tags: Vec<String>,
        shared_risk_tags: Vec<String>,
        shared_source_signals: Vec<String>,
        members: Vec<WireSimilarSkillMember>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSimilarSkillMember {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        source: WireKnowledgeSearchSource,
        quality_context: Option<WireKnowledgeQualityContext>,
        readiness_context: Option<WireKnowledgeReadinessContext>,
        stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
        match_reasons: Vec<String>,
        similarity_reasons: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityTaxonomyResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireCapabilityTaxonomyFilters,
        summary: WireCapabilityTaxonomySummary,
        domains: Vec<WireCapabilityDomainRow>,
        coverage_rows: Vec<WireCapabilityCoverageRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityTaxonomyFilters {
        agent: Option<String>,
        limit: usize,
        include_single_skill_domains: bool,
        candidate_instance_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityTaxonomySummary {
        indexed_skill_count: usize,
        candidate_skill_count: usize,
        domain_count: usize,
        returned_domain_count: usize,
        total_representative_skill_count: usize,
        agent_count: usize,
        workspace_count: usize,
        duplicate_or_redundant_domain_count: usize,
        routing_ambiguity_domain_count: usize,
        gap_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityDomainRow {
        domain_id: String,
        rank: usize,
        domain_key: String,
        domain_name: String,
        coverage_level: String,
        coverage_score: u8,
        skill_count: usize,
        enabled_skill_count: usize,
        disabled_skill_count: usize,
        agent_count: usize,
        workspace_count: usize,
        agents: BTreeMap<String, usize>,
        workspaces: BTreeMap<String, usize>,
        duplicate_or_redundant_count: usize,
        routing_ambiguity_count: usize,
        representative_skills: Vec<WireCapabilityRepresentativeSkill>,
        capability_tags: Vec<String>,
        risk_tags: Vec<String>,
        tools: Vec<String>,
        rules: Vec<String>,
        keywords: Vec<String>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityCoverageRow {
        domain_key: String,
        domain_name: String,
        coverage_level: String,
        coverage_score: u8,
        skill_count: usize,
        enabled_skill_count: usize,
        agent_count: usize,
        workspace_count: usize,
        agents: BTreeMap<String, usize>,
        gaps: Vec<String>,
        duplicates_redundancy: String,
        routing_ambiguity: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCapabilityRepresentativeSkill {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        source: WireKnowledgeSearchSource,
        quality_context: Option<WireKnowledgeQualityContext>,
        stale_drift_context: Option<WireKnowledgeStaleDriftContext>,
        similarity_group_ids: Vec<String>,
        match_reasons: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireLocalSkillMapFilters,
        summary: WireLocalSkillMapSummary,
        nodes: Vec<WireLocalSkillMapNode>,
        edges: Vec<WireLocalSkillMapEdge>,
        clusters: Vec<WireLocalSkillMapCluster>,
        domains: Vec<WireLocalSkillMapDomain>,
        risk_notes: Vec<String>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapFilters {
        agent: Option<String>,
        task: Option<String>,
        limit: usize,
        node_limit: usize,
        edge_limit: usize,
        cluster_limit: usize,
        candidate_instance_ids: Vec<String>,
        include_task_context: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapSummary {
        indexed_skill_count: usize,
        candidate_skill_count: usize,
        returned_node_count: usize,
        returned_edge_count: usize,
        cluster_count: usize,
        returned_cluster_count: usize,
        domain_count: usize,
        skill_node_count: usize,
        capability_node_count: usize,
        similar_group_node_count: usize,
        conflict_node_count: usize,
        risk_node_count: usize,
        task_coverage_edge_count: usize,
        cross_agent_edge_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapNode {
        id: String,
        node_type: String,
        rank: usize,
        label: String,
        summary: String,
        weight: u8,
        agent: Option<String>,
        scope: Option<String>,
        enabled: Option<bool>,
        state: Option<String>,
        source: Option<WireKnowledgeSearchSource>,
        risk_level: Option<String>,
        tags: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapEdge {
        id: String,
        edge_type: String,
        source: String,
        target: String,
        label: String,
        weight: u8,
        reasons: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapCluster {
        id: String,
        cluster_type: String,
        label: String,
        summary: String,
        score: u8,
        risk_level: String,
        node_ids: Vec<String>,
        edge_ids: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLocalSkillMapDomain {
        domain_id: String,
        domain_key: String,
        domain_name: String,
        coverage_level: String,
        coverage_score: u8,
        node_ids: Vec<String>,
        skill_count: usize,
        enabled_skill_count: usize,
        agent_count: usize,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireWorkspaceReadinessFilters,
        summary: WireWorkspaceReadinessSummary,
        readiness_rows: Vec<WireWorkspaceReadinessChecklistRow>,
        checklist_rows: Vec<WireWorkspaceReadinessChecklistRow>,
        agent_rows: Vec<WireWorkspaceReadinessAgentRow>,
        capability_rows: Vec<WireWorkspaceReadinessCapabilityRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessFilters {
        agent: Option<String>,
        task: Option<String>,
        project_root: Option<String>,
        expected_capabilities: Vec<String>,
        limit: usize,
        candidate_instance_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessSummary {
        workspace_available: bool,
        project_available: bool,
        visible_skill_count: usize,
        enabled_skill_count: usize,
        agent_count: usize,
        domain_count: usize,
        capability_count: usize,
        ready_count: usize,
        partial_count: usize,
        blocked_count: usize,
        gap_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessChecklistRow {
        id: String,
        category: String,
        status: String,
        score: u8,
        title: String,
        detail: String,
        agent: Option<String>,
        capability: Option<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessAgentRow {
        agent: String,
        display_name: String,
        status: String,
        score: u8,
        visible_skill_count: usize,
        enabled_skill_count: usize,
        project_skill_count: usize,
        best_candidate: Option<WireAgentReadinessBestCandidate>,
        adapter_status: Option<String>,
        writable_status: Option<String>,
        install_status: Option<String>,
        gap_count: usize,
        blocker_count: usize,
        notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireWorkspaceReadinessCapabilityRow {
        capability: String,
        domain_key: String,
        domain_name: String,
        status: String,
        coverage_level: String,
        coverage_score: u8,
        expected: bool,
        skill_count: usize,
        enabled_skill_count: usize,
        agent_count: usize,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAggregationRuntimeMetadata {
        status: String,
        elapsed_ms: u64,
        timeout_ms: u64,
        timed_out: bool,
        partial: bool,
        fallback_used: bool,
        limit: usize,
        scanned_count: usize,
        total_count: usize,
        completed_stages: Vec<String>,
        skipped_stages: Vec<String>,
        blocker_codes: Vec<String>,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPlanResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireRemediationPlanFilters,
        summary: WireRemediationPlanSummary,
        plan_items: Vec<WireRemediationPlanItem>,
        priority_rows: Vec<WireRemediationPriorityRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPlanFilters {
        agent: Option<String>,
        task: Option<String>,
        project_root: Option<String>,
        focus_areas: Vec<String>,
        limit: usize,
        candidate_instance_ids: Vec<String>,
        include_deferred: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPlanSummary {
        total_item_count: usize,
        returned_item_count: usize,
        high_priority_count: usize,
        medium_priority_count: usize,
        low_priority_count: usize,
        deferred_count: usize,
        finding_item_count: usize,
        gap_item_count: usize,
        ambiguity_item_count: usize,
        drift_item_count: usize,
        readiness_item_count: usize,
        policy_item_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPlanItem {
        id: String,
        rank: usize,
        priority: String,
        severity: String,
        category: String,
        title: String,
        summary: String,
        detail: String,
        affected_agent: Option<String>,
        affected_skill: Option<WireRemediationAffectedSkill>,
        affected_capability: Option<String>,
        affected_task: Option<String>,
        affected_instance_ids: Vec<String>,
        suggested_safe_next_action: String,
        prerequisites: Vec<String>,
        blockers: Vec<String>,
        deferred: bool,
        evidence_refs: Vec<String>,
        side_effect_flags: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationAffectedSkill {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPriorityRow {
        priority: String,
        severity: String,
        item_count: usize,
        category_counts: BTreeMap<String, usize>,
        top_item_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewDraftsResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireRemediationPreviewDraftsFilters,
        summary: WireRemediationPreviewDraftsSummary,
        draft_items: Vec<WireRemediationDraftItem>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewDraftsFilters {
        agent: Option<String>,
        task: Option<String>,
        skill_ids: Vec<String>,
        finding_ids: Vec<String>,
        draft_types: Vec<String>,
        limit: usize,
        include_policy_drafts: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewDraftsSummary {
        total_draft_count: usize,
        returned_draft_count: usize,
        frontmatter_count: usize,
        description_count: usize,
        permissions_count: usize,
        dependency_count: usize,
        policy_count: usize,
        high_confidence_count: usize,
        medium_confidence_count: usize,
        low_confidence_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationDraftItem {
        id: String,
        rank: usize,
        title: String,
        draft_type: String,
        agent: Option<String>,
        affected_skill: Option<WireRemediationAffectedSkill>,
        finding_id: Option<String>,
        rule_id: Option<String>,
        current_text: Option<String>,
        proposed_text: String,
        patch_like_snippet: String,
        rationale: String,
        confidence: u8,
        confidence_band: String,
        copy_label: String,
        edit_guidance: String,
        evidence_refs: Vec<String>,
        blocker_notes: Vec<String>,
        side_effect_flags: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewImpactResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireRemediationPreviewImpactFilters,
        summary: WireRemediationPreviewImpactSummary,
        impact_rows: Vec<WireRemediationImpactRow>,
        task_impact_rows: Vec<WireRemediationTaskImpactRow>,
        agent_impact_rows: Vec<WireRemediationAgentImpactRow>,
        skill_impact_rows: Vec<WireRemediationSkillImpactRow>,
        risk_delta_rows: Vec<WireRemediationRiskDeltaRow>,
        snapshot_rollback_plan_rows: Vec<WireRemediationSnapshotRollbackPlanRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewImpactFilters {
        action: String,
        task: Option<String>,
        agent: Option<String>,
        project_root: Option<String>,
        skill_ids: Vec<String>,
        candidate_instance_ids: Vec<String>,
        draft_ids: Vec<String>,
        plan_item_ids: Vec<String>,
        limit: usize,
        include_snapshot_plan: bool,
        include_rollback_plan: bool,
        include_risk_impact: bool,
        include_task_impact: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationPreviewImpactSummary {
        total_impact_count: usize,
        returned_impact_count: usize,
        task_impact_count: usize,
        agent_impact_count: usize,
        skill_impact_count: usize,
        risk_delta_count: usize,
        snapshot_plan_count: usize,
        rollback_plan_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationImpactRow {
        id: String,
        rank: usize,
        area: String,
        title: String,
        summary: String,
        action_intent: String,
        expected_direction: String,
        confidence: u8,
        confidence_band: String,
        affected_agent: Option<String>,
        affected_skill: Option<WireRemediationAffectedSkill>,
        affected_task: Option<String>,
        evidence_refs: Vec<String>,
        blockers: Vec<String>,
        side_effect_flags: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationTaskImpactRow {
        task: String,
        action_intent: String,
        expected_direction: String,
        readiness_score_before: Option<u8>,
        readiness_score_after_estimate: Option<u8>,
        routing_confidence_before: Option<u8>,
        routing_confidence_after_estimate: Option<u8>,
        notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationAgentImpactRow {
        agent: String,
        action_intent: String,
        expected_direction: String,
        impacted_skill_count: usize,
        enabled_before_count: usize,
        enabled_after_estimate_count: usize,
        writable_status: Option<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationSkillImpactRow {
        affected_skill: WireRemediationAffectedSkill,
        action_intent: String,
        expected_direction: String,
        enabled_before: bool,
        enabled_after_estimate: bool,
        finding_count: usize,
        conflict_count: usize,
        analysis_count: usize,
        notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationRiskDeltaRow {
        id: String,
        source: String,
        severity: String,
        title: String,
        current_risk: String,
        expected_risk_after: String,
        expected_direction: String,
        affected_instance_ids: Vec<String>,
        blockers: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationSnapshotRollbackPlanRow {
        id: String,
        agent: String,
        instance_id: String,
        skill_name: String,
        action_intent: String,
        snapshot_required: bool,
        rollback_available: bool,
        verified_writable: bool,
        blocked_reason: Option<String>,
        plan_only: bool,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationBatchReviewResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireRemediationBatchReviewFilters,
        summary: WireRemediationBatchReviewSummary,
        review_groups: Vec<WireRemediationBatchReviewGroup>,
        review_items: Vec<WireRemediationBatchReviewItem>,
        recommended_next_step_labels: Vec<String>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationBatchReviewFilters {
        task: Option<String>,
        agent: Option<String>,
        project_root: Option<String>,
        workspace_label: Option<String>,
        rule_id: Option<String>,
        severity: Option<String>,
        status: Option<String>,
        triage_status: Option<String>,
        candidate_instance_ids: Vec<String>,
        group_by: Vec<String>,
        limit: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationBatchReviewSummary {
        total_item_count: usize,
        returned_item_count: usize,
        group_count: usize,
        high_risk_count: usize,
        medium_risk_count: usize,
        low_risk_count: usize,
        task_group_count: usize,
        agent_group_count: usize,
        workspace_group_count: usize,
        rule_group_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationBatchReviewGroup {
        id: String,
        group_type: String,
        label: String,
        item_count: usize,
        high_risk_count: usize,
        medium_risk_count: usize,
        low_risk_count: usize,
        top_item_ids: Vec<String>,
        recommended_next_step_label: String,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationBatchReviewItem {
        id: String,
        rank: usize,
        source: String,
        source_id: String,
        title: String,
        summary: String,
        risk: String,
        severity: String,
        status: String,
        triage_status: Option<String>,
        rule_id: Option<String>,
        task: Option<String>,
        agent: Option<String>,
        workspace: Option<String>,
        affected_skill: Option<WireRemediationAffectedSkill>,
        affected_instance_ids: Vec<String>,
        recommended_next_step_label: String,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        evidence_refs: Vec<String>,
        side_effect_flags: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessResult {
        task: String,
        score: u8,
        band: String,
        summary: String,
        generated_by: String,
        catalog_available: bool,
        filters: WireTaskReadinessFilters,
        candidate_skills: Vec<WireTaskReadinessCandidate>,
        missing_gap_notes: Vec<String>,
        blocker_risk_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireTaskReadinessPromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireTaskReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessFilters {
        agent: Option<String>,
        candidate_instance_ids: Vec<String>,
        limit: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessCandidate {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        score: u8,
        band: String,
        quality_score: Option<u8>,
        match_reasons: Vec<String>,
        enabled_scope_risk_state: WireTaskReadinessState,
        missing_gap_notes: Vec<String>,
        blocker_risk_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessState {
        enabled: bool,
        scope: String,
        state: String,
        risk_level: String,
        risk_summary: String,
        writable_status: Option<String>,
        adapter_status: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessEvidenceReference {
        id: String,
        source_type: String,
        source_id: String,
        label: String,
        severity: Option<String>,
        related_instance_id: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessPromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskReadinessSafetyFlags {
        read_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillRouteRankingResult {
        task: String,
        overall_confidence_score: u8,
        overall_confidence_band: String,
        summary: String,
        generated_by: String,
        catalog_available: bool,
        filters: WireTaskReadinessFilters,
        route_candidates: Vec<WireSkillRouteCandidate>,
        ambiguity_warnings: Vec<String>,
        likely_wrong_pick_risks: Vec<String>,
        likely_miss_risks: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireRoutingConfidencePromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireRoutingConfidenceSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillRouteCandidate {
        rank: usize,
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        confidence_score: u8,
        confidence_band: String,
        readiness_score: u8,
        readiness_band: String,
        quality_score: Option<u8>,
        match_reasons: Vec<String>,
        confidence_rationale: Vec<String>,
        ambiguity_warnings: Vec<String>,
        likely_wrong_pick_risks: Vec<String>,
        likely_miss_risks: Vec<String>,
        enabled_scope_risk_state: WireTaskReadinessState,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingConfidencePromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingConfidenceSafetyFlags {
        read_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessComparisonResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireAgentReadinessComparisonFilters,
        summary: WireAgentReadinessComparisonSummary,
        agent_rows: Vec<WireAgentReadinessComparisonRow>,
        recommended_agent: Option<WireAgentReadinessRecommendation>,
        gap_issue_rows: Vec<WireAgentReadinessGapIssueRow>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessComparisonFilters {
        agents: Vec<String>,
        limit_per_agent: usize,
        include_routing_accuracy: bool,
        include_benchmarks: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessComparisonSummary {
        agent_count: usize,
        candidate_count: usize,
        ready_agent_count: usize,
        partial_agent_count: usize,
        blocked_agent_count: usize,
        gap_issue_count: usize,
        recommended_agent: Option<String>,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessComparisonRow {
        rank: usize,
        agent: String,
        display_name: String,
        comparison_score: u8,
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        candidate_count: usize,
        best_candidate: Option<WireAgentReadinessBestCandidate>,
        enabled_scope_risk_state: Option<WireTaskReadinessState>,
        blocker_count: usize,
        gap_count: usize,
        reasons: Vec<String>,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        routing_accuracy_context: Option<WireAgentReadinessAccuracyContext>,
        benchmark_context: Option<WireAgentReadinessBenchmarkContext>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessBestCandidate {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        scope: String,
        enabled: bool,
        state: String,
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        quality_score: Option<u8>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessAccuracyContext {
        trace_count: usize,
        accuracy_rate: f64,
        benchmark_count: usize,
        benchmark_gap_count: usize,
        regression_count: usize,
        recent_evidence_count: usize,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessBenchmarkContext {
        evaluated_count: usize,
        matched_count: usize,
        gap_count: usize,
        regression_count: usize,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessRecommendation {
        agent: String,
        display_name: String,
        comparison_score: u8,
        readiness_score: u8,
        routing_confidence_score: u8,
        skill_name: Option<String>,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessGapIssueRow {
        source: String,
        severity: String,
        agent: String,
        title: String,
        detail: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessPromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentReadinessSafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitResult {
        generated_by: String,
        catalog_available: bool,
        partial: bool,
        elapsed_ms: u64,
        fallback_reason: Option<String>,
        filters: WireTaskCockpitFilters,
        summary: WireTaskCockpitSummary,
        cockpit_sections: Vec<WireTaskCockpitSection>,
        task_rows: Vec<WireTaskCockpitTaskRow>,
        agent_route_rows: Vec<WireTaskCockpitAgentRouteRow>,
        skill_candidate_rows: Vec<WireTaskCockpitSkillCandidateRow>,
        readiness_rows: Vec<WireTaskCockpitReadinessRow>,
        session_review_rows: Vec<WireTaskCockpitSessionReviewRow>,
        provider_observability_rows: Vec<WireTaskCockpitProviderObservabilityRow>,
        remediation_next_steps: Vec<WireTaskCockpitRemediationNextStep>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        aggregation: WireAggregationRuntimeMetadata,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitFilters {
        task: String,
        agent: Option<String>,
        candidate_instance_ids: Vec<String>,
        limit: usize,
        include_session_review: bool,
        include_provider_observability: bool,
        include_remediation_context: bool,
        timeout_ms: u64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitSummary {
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        candidate_count: usize,
        agent_count: usize,
        session_review_count: usize,
        provider_observability_row_count: usize,
        remediation_next_step_count: usize,
        gap_count: usize,
        blocker_count: usize,
        recommended_agent: Option<String>,
        top_skill_name: Option<String>,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitSection {
        id: String,
        title: String,
        status: String,
        score: Option<u8>,
        row_count: usize,
        summary: String,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitTaskRow {
        id: String,
        task: String,
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        recommended_agent: Option<String>,
        top_skill_name: Option<String>,
        candidate_count: usize,
        gap_count: usize,
        blocker_count: usize,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitAgentRouteRow {
        rank: usize,
        agent: String,
        display_name: String,
        comparison_score: u8,
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        best_skill_name: Option<String>,
        blocker_count: usize,
        gap_count: usize,
        reasons: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitSkillCandidateRow {
        rank: usize,
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        readiness_score: u8,
        readiness_band: String,
        routing_confidence_score: u8,
        routing_confidence_band: String,
        quality_score: Option<u8>,
        match_reasons: Vec<String>,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitReadinessRow {
        id: String,
        row_type: String,
        label: String,
        status: String,
        score: Option<u8>,
        summary: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitSessionReviewRow {
        id: String,
        title: String,
        agent: Option<String>,
        task: Option<String>,
        outcome: String,
        summary: String,
        detected_skill_count: usize,
        expected_skill_signal_count: usize,
        reviewed_at: i64,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitProviderObservabilityRow {
        id: String,
        source: String,
        status: String,
        provider: Option<String>,
        model: Option<String>,
        action: Option<String>,
        count: usize,
        message: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskCockpitRemediationNextStep {
        id: String,
        source: String,
        priority: String,
        title: String,
        suggested_safe_next_action: String,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleTimelineResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireSkillLifecycleTimelineFilters,
        summary: WireSkillLifecycleTimelineSummary,
        timeline_rows: Vec<WireSkillLifecycleTimelineRow>,
        skill_rows: Vec<WireSkillLifecycleSkillRow>,
        agent_rows: Vec<WireSkillLifecycleAgentRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleTimelineFilters {
        task: Option<String>,
        agent: Option<String>,
        selected_skill_id: Option<String>,
        selected_skill_name: Option<String>,
        selected_skill_agent: Option<String>,
        definition_id: Option<String>,
        project_root: Option<String>,
        current_cwd: Option<String>,
        workspace: Option<String>,
        limit: usize,
        include_prompt_runs: bool,
        include_session_reviews: bool,
        include_remediation_history: bool,
        include_stale_drift: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleTimelineSummary {
        total_event_count: usize,
        skill_count: usize,
        agent_count: usize,
        finding_event_count: usize,
        drift_event_count: usize,
        remediation_event_count: usize,
        prompt_event_count: usize,
        session_review_event_count: usize,
        first_event_at: Option<i64>,
        latest_event_at: Option<i64>,
        selected_skill_name: Option<String>,
        selected_agent: Option<String>,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleTimelineRow {
        id: String,
        occurred_at: Option<i64>,
        event_type: String,
        lifecycle_stage: String,
        title: String,
        summary: String,
        agent: Option<String>,
        skill_name: Option<String>,
        instance_id: Option<String>,
        definition_id: Option<String>,
        source: String,
        severity: Option<String>,
        status: Option<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleSkillRow {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        enabled: bool,
        state: String,
        event_count: usize,
        finding_event_count: usize,
        drift_event_count: usize,
        remediation_event_count: usize,
        prompt_event_count: usize,
        session_review_event_count: usize,
        first_event_at: Option<i64>,
        latest_event_at: Option<i64>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillLifecycleAgentRow {
        agent: String,
        skill_count: usize,
        event_count: usize,
        finding_event_count: usize,
        drift_event_count: usize,
        remediation_event_count: usize,
        prompt_event_count: usize,
        session_review_event_count: usize,
        first_event_at: Option<i64>,
        latest_event_at: Option<i64>,
        evidence_refs: Vec<String>,
        safety_flags: WireAgentReadinessSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkRecord {
        id: String,
        title: String,
        task: String,
        expected_skill_refs: Vec<String>,
        expected_skill_names: Vec<String>,
        acceptable_agents: Vec<String>,
        acceptable_scopes: Vec<String>,
        success_criteria: Vec<String>,
        created_at: i64,
        updated_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkListResult {
        benchmarks: Vec<WireTaskBenchmarkRecord>,
        count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSaveTaskBenchmarkResult {
        benchmark: WireTaskBenchmarkRecord,
        created: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        agent_config_mutated: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireDeleteTaskBenchmarkResult {
        benchmark_id: String,
        deleted: bool,
        remaining_count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        agent_config_mutated: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkEvaluationResult {
        generated_by: String,
        catalog_available: bool,
        evaluated_count: usize,
        summary: String,
        benchmark_results: Vec<WireTaskBenchmarkEvaluationItem>,
        blocker_notes: Vec<String>,
        prompt_request: WireTaskBenchmarkPromptRequest,
        safety_flags: WireTaskBenchmarkSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkEvaluationItem {
        benchmark_id: String,
        title: String,
        task: String,
        score: u8,
        band: String,
        expected_match_status: String,
        expected_match_reasons: Vec<String>,
        top_route: Option<WireTaskBenchmarkRouteSummary>,
        route_confidence_score: u8,
        route_confidence_band: String,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireTaskBenchmarkSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkRouteSummary {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        confidence_score: u8,
        confidence_band: String,
        readiness_score: u8,
        readiness_band: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkPromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTaskBenchmarkSafetyFlags {
        read_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSaveRoutingBaselineResult {
        generated_by: String,
        baseline: WireRoutingRegressionBaseline,
        benchmark_count: usize,
        app_local_only: bool,
        baseline_file: String,
        provider_request_sent: bool,
        agent_config_mutated: bool,
        skill_files_mutated: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionDetectionResult {
        generated_by: String,
        status: String,
        baseline_available: bool,
        catalog_available: bool,
        baseline_evaluated_count: usize,
        current_evaluated_count: usize,
        regression_count: usize,
        missing_benchmark_count: usize,
        summary: String,
        items: Vec<WireRoutingRegressionItem>,
        blocker_notes: Vec<String>,
        baseline: Option<WireRoutingRegressionBaseline>,
        current_evaluation: WireTaskBenchmarkEvaluationResult,
        safety_flags: WireTaskBenchmarkSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionItem {
        benchmark_id: String,
        title: String,
        status: String,
        regression: bool,
        reasons: Vec<String>,
        evidence_refs: Vec<String>,
        score_delta: Option<i16>,
        confidence_delta: Option<i16>,
        baseline: Option<WireRoutingRegressionComparisonFields>,
        current: Option<WireRoutingRegressionComparisonFields>,
        safety_flags: WireTaskBenchmarkSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionBaseline {
        schema_version: u32,
        generated_by: String,
        generated_at: i64,
        catalog_available: bool,
        evaluated_count: usize,
        benchmark_results: Vec<WireRoutingRegressionBaselineItem>,
        safety_flags: WireTaskBenchmarkSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionBaselineItem {
        benchmark_id: String,
        title: String,
        task: String,
        score: u8,
        band: String,
        expected_match_status: String,
        top_route: Option<WireRoutingRegressionRouteSnapshot>,
        route_confidence_score: u8,
        route_confidence_band: String,
        gap_count: usize,
        blocker_count: usize,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionRouteSnapshot {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        confidence_score: u8,
        confidence_band: String,
        readiness_score: u8,
        readiness_band: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingRegressionComparisonFields {
        task: String,
        expected_match_status: String,
        score: u8,
        band: String,
        top_route: Option<WireRoutingRegressionRouteSnapshot>,
        route_confidence_score: u8,
        route_confidence_band: String,
        gap_count: usize,
        blocker_count: usize,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyDashboardResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireRoutingAccuracyDashboardFilters,
        summary: WireRoutingAccuracyDashboardSummary,
        agent_rows: Vec<WireRoutingAccuracyAgentRow>,
        history_rows: Vec<WireRoutingAccuracyHistoryRow>,
        gap_issue_rows: Vec<WireRoutingAccuracyIssueRow>,
        recent_evidence_rows: Vec<WireRoutingAccuracyEvidenceRow>,
        blocker_notes: Vec<String>,
        prompt_request: WireRoutingAccuracyPromptRequest,
        safety_flags: WireRoutingAccuracySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyDashboardFilters {
        agent: Option<String>,
        window_days: u32,
        limit: usize,
        include_history: bool,
        include_recent_evidence: bool,
        window_start_millis: i64,
        window_end_millis: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyDashboardSummary {
        trace_count: usize,
        hit_count: usize,
        miss_count: usize,
        wrong_pick_count: usize,
        ambiguous_count: usize,
        unknown_count: usize,
        benchmark_count: usize,
        benchmark_matched_count: usize,
        benchmark_gap_count: usize,
        regression_count: usize,
        missing_benchmark_count: usize,
        accuracy_rate: f64,
        known_outcome_rate: f64,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyOutcomeCounts {
        hit: usize,
        miss: usize,
        wrong_pick: usize,
        ambiguous: usize,
        unknown: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyAgentRow {
        agent: String,
        trace_count: usize,
        outcomes: WireRoutingAccuracyOutcomeCounts,
        accuracy_rate: f64,
        benchmark_count: usize,
        benchmark_matched_count: usize,
        benchmark_gap_count: usize,
        regression_count: usize,
        recent_evidence_count: usize,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyHistoryRow {
        unix_day: i64,
        trace_count: usize,
        outcomes: WireRoutingAccuracyOutcomeCounts,
        accuracy_rate: f64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyIssueRow {
        source: String,
        severity: String,
        agent: Option<String>,
        title: String,
        detail: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyEvidenceRow {
        source: String,
        agent: Option<String>,
        title: String,
        outcome: Option<String>,
        detail: String,
        evidence_refs: Vec<String>,
        observed_at: Option<i64>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracyPromptRequest {
        available: bool,
        preview_method: String,
        confirm_method: String,
        action: String,
        request: LlmPreviewPromptParams,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRoutingAccuracySafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewRecord {
        id: String,
        title: String,
        source_kind: String,
        agent: Option<String>,
        task: Option<String>,
        trace_import_ids: Vec<String>,
        missing_trace_import_ids: Vec<String>,
        expected_skill_refs: Vec<String>,
        expected_skill_names: Vec<String>,
        excerpt: String,
        excerpt_char_count: usize,
        content_hash: String,
        redaction_summary: WireAgentSessionSkillReviewRedactionSummary,
        reviewed_at: i64,
        analysis: WireAgentSessionSkillReviewAnalysis,
        safety_flags: WireAgentSessionSkillReviewSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewAnalysis {
        generated_by: String,
        catalog_available: bool,
        outcome: String,
        summary: String,
        reasons: Vec<String>,
        detected_skills: Vec<WireTraceDetectedSkill>,
        expected_skill_signals: Vec<WireAgentSessionExpectedSkillSignal>,
        referenced_traces: Vec<WireAgentSessionReferencedTrace>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionExpectedSkillSignal {
        kind: String,
        value: String,
        matched: bool,
        matched_instance_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionReferencedTrace {
        id: String,
        title: String,
        outcome: String,
        imported_at: i64,
        detected_skill_count: usize,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewRedactionSummary {
        status: String,
        redacted_value_count: usize,
        redacted_fields: Vec<String>,
        placeholders: Vec<String>,
        raw_trace_persisted: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewSafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewResult {
        generated_by: String,
        review: WireAgentSessionSkillReviewRecord,
        count: usize,
        app_local_only: bool,
        review_file: String,
        provider_request_sent: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        snapshot_created: bool,
        triage_mutated: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewListResult {
        generated_by: String,
        count: usize,
        total_count: usize,
        reviews: Vec<WireAgentSessionSkillReviewRecord>,
        app_local_only: bool,
        review_file: String,
        provider_request_sent: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        safety_flags: WireAgentSessionSkillReviewSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentSessionSkillReviewDeleteResult {
        review_id: String,
        deleted: bool,
        remaining_count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        snapshot_created: bool,
        triage_mutated: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportRecord {
        id: String,
        title: String,
        source_kind: String,
        agent: Option<String>,
        task: Option<String>,
        expected_skill_refs: Vec<String>,
        expected_skill_names: Vec<String>,
        excerpt: String,
        excerpt_char_count: usize,
        redaction_summary: WireTraceImportRedactionSummary,
        content_hash: String,
        imported_at: i64,
        analysis: WireTraceImportAnalysis,
        safety_flags: WireTraceImportSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportRedactionSummary {
        status: String,
        redacted_value_count: usize,
        redacted_fields: Vec<String>,
        placeholders: Vec<String>,
        raw_trace_persisted: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportAnalysis {
        generated_by: String,
        catalog_available: bool,
        outcome: String,
        reasons: Vec<String>,
        detected_skills: Vec<WireTraceDetectedSkill>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceDetectedSkill {
        instance_id: String,
        definition_id: String,
        skill_name: String,
        agent: String,
        scope: String,
        evidence_refs: Vec<String>,
        match_terms: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportSafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_trace_persisted: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportLocalResult {
        generated_by: String,
        import: WireTraceImportRecord,
        count: usize,
        app_local_only: bool,
        import_file: String,
        provider_request_sent: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceImportListResult {
        imports: Vec<WireTraceImportRecord>,
        count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTraceDeleteImportResult {
        import_id: String,
        deleted: bool,
        remaining_count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryRecord {
        id: String,
        title: String,
        decision: String,
        status: String,
        source_kind: String,
        source_method: Option<String>,
        source_item_refs: Vec<String>,
        batch_review_item_ids: Vec<String>,
        agent: Option<String>,
        workspace: Option<String>,
        task: Option<String>,
        rule_ids: Vec<String>,
        risk_levels: Vec<String>,
        recurrence_key: Option<String>,
        recurrence_count_marker: Option<u32>,
        reopened: bool,
        reopened_from_ids: Vec<String>,
        readiness_improvement_notes: Vec<String>,
        routing_improvement_notes: Vec<String>,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        evidence_refs: Vec<String>,
        notes: Option<String>,
        redaction_summary: WireRemediationHistoryRedactionSummary,
        created_at: i64,
        updated_at: i64,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryRedactionSummary {
        status: String,
        redacted_value_count: usize,
        redacted_fields: Vec<String>,
        placeholders: Vec<String>,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistorySafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        rollback_performed: bool,
        triage_mutation_allowed: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryListResult {
        generated_by: String,
        filters: WireRemediationHistoryFilters,
        summary: WireRemediationHistorySummary,
        records: Vec<WireRemediationHistoryRecord>,
        recurrence_rows: Vec<WireRemediationHistoryRecurrenceRow>,
        blocker_notes: Vec<String>,
        app_local_only: bool,
        history_file: String,
        provider_request_sent: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryRecordResult {
        generated_by: String,
        record: WireRemediationHistoryRecord,
        created: bool,
        count: usize,
        app_local_only: bool,
        history_file: String,
        provider_request_sent: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        snapshot_created: bool,
        rollback_performed: bool,
        triage_mutated: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryDeleteResult {
        history_id: String,
        deleted: bool,
        remaining_count: usize,
        app_local_only: bool,
        provider_request_sent: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        snapshot_created: bool,
        rollback_performed: bool,
        triage_mutated: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryFilters {
        agent: Option<String>,
        status: Option<String>,
        decision: Option<String>,
        source_item_ref: Option<String>,
        recurrence_key: Option<String>,
        limit: usize,
        include_recurrence_rows: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistorySummary {
        total_count: usize,
        returned_count: usize,
        decision_counts: BTreeMap<String, usize>,
        status_counts: BTreeMap<String, usize>,
        reopened_count: usize,
        recurrence_group_count: usize,
        blocker_count: usize,
        readiness_improvement_count: usize,
        routing_improvement_count: usize,
        latest_recorded_at: Option<i64>,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRemediationHistoryRecurrenceRow {
        recurrence_key: String,
        record_count: usize,
        reopened_count: usize,
        latest_status: String,
        latest_decision: String,
        latest_recorded_at: i64,
        source_item_refs: Vec<String>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScanResult {
        scanned_count: usize,
        skills: Vec<WireSkillRecord>,
        activity: WireRefreshActivity,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRefreshStatus {
        scan_progress: String,
        watcher_state: String,
        watcher_detail: String,
        recovery_actions: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmStatus {
        enabled: bool,
        configured: bool,
        provider: Option<String>,
        model: Option<String>,
        reason: String,
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        credentials_storage: String,
        credential_persistence_allowed: bool,
        provider_profile_count: usize,
        default_profile_id: Option<String>,
        profiles_path: String,
        call_metadata_path: String,
        raw_prompt_persistence_allowed: bool,
        raw_response_persistence_allowed: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireListProviderProfilesResult {
        profiles: Vec<WireProviderProfileRecord>,
        default_profile_id: Option<String>,
        credential_storage: String,
        credential_persistence_allowed: bool,
        raw_secrets_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSaveProviderProfileResult {
        profile: WireProviderProfileRecord,
        credential_status: WireProviderCredentialStatus,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireDeleteProviderProfileResult {
        deleted_profile_id: String,
        profile_deleted: bool,
        credential_deleted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireTestProviderConnectionResult {
        profile_id: String,
        provider_type: String,
        model: String,
        destination_host: String,
        status: String,
        provider_request_sent: bool,
        credential_accessed: bool,
        duration_ms: u128,
        error_code: Option<String>,
        error_message: Option<String>,
        budget: WireProviderBudgetStatus,
        audit: WireProviderCallMetadata,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProviderProfileRecord {
        id: String,
        display_name: String,
        provider_type: String,
        base_url: String,
        model: String,
        enabled: bool,
        api_version: Option<String>,
        organization: Option<String>,
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        credential_reference: WireProviderCredentialReference,
        credential_status: WireProviderCredentialStatus,
        created_at: i64,
        updated_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProviderCredentialReference {
        storage: String,
        service: String,
        account: String,
        secret_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProviderCredentialStatus {
        state: String,
        reason: String,
        secret_available: bool,
        fallback_available: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProviderBudgetStatus {
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        estimated_test_tokens: u32,
        estimated_test_cost_usd: f64,
        state: String,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProviderCallMetadata {
        timestamp: i64,
        action_type: String,
        profile_id: String,
        provider_type: String,
        model: String,
        destination_host: String,
        status: String,
        error_code: Option<String>,
        error_message: Option<String>,
        duration_ms: u128,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_cost_usd: f64,
        confirmation_id: String,
        redaction_status: String,
        provider_request_sent: bool,
        credential_accessed: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionStatus {
        enabled: bool,
        default_enabled: bool,
        reason: String,
        audit_scope: String,
        audit_path: String,
        llm_initiation_allowed: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPrepareActionResult {
        action: String,
        allowed: bool,
        reason: String,
        disabled_reason: Option<String>,
        requires_confirmation: bool,
        write_back_allowed: bool,
        draft_requires_user_copy: bool,
        provider: Option<String>,
        model: Option<String>,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        estimated_cost_usd: f64,
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        credentials_storage: String,
        credential_persistence_allowed: bool,
        prompt_scope: Vec<String>,
        privacy_notes: Vec<String>,
        confirmation: WireLlmConfirmationRequirement,
        review_preview: WireLlmReviewPreview,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPrepareSkillAnalysisResult {
        enabled: bool,
        disabled_reason: String,
        analysis_kind: String,
        selected_skill_count: usize,
        included_skill_count: usize,
        excluded_missing_count: usize,
        included_skills: Vec<WireLlmSkillAnalysisIncludedSkill>,
        prompt_draft: String,
        summary_draft: String,
        safety_flags: WireLlmSkillAnalysisSafetyFlags,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        provider_request_sent: bool,
        generated_by: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPreviewPromptResult {
        preview_id: String,
        status: String,
        allowed: bool,
        reason: String,
        action: String,
        profile_id: Option<String>,
        provider: Option<String>,
        model: Option<String>,
        destination_host: Option<String>,
        prompt_scope: Vec<String>,
        included_fields: Vec<String>,
        excluded_fields: Vec<String>,
        redaction: WireLlmPromptRedactionSummary,
        prompt_preview: String,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        estimated_cost_usd: f64,
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        requires_confirmation: bool,
        confirmation: WireLlmConfirmationRequirement,
        write_back_allowed: bool,
        draft_requires_user_copy: bool,
        provider_request_sent: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPromptRedactionSummary {
        status: String,
        redacted_value_count: usize,
        redacted_fields: Vec<String>,
        placeholders: Vec<String>,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmConfirmPromptAndSendResult {
        preview_id: String,
        confirmation_id: String,
        status: String,
        action: String,
        profile_id: String,
        provider: String,
        model: String,
        destination_host: String,
        provider_request_sent: bool,
        credential_accessed: bool,
        draft_output: Option<String>,
        draft_requires_user_copy: bool,
        write_back_allowed: bool,
        script_execution_allowed: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        audit: WireProviderCallMetadata,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPromptRunListResult {
        generated_by: String,
        count: usize,
        runs: Vec<WireLlmPromptRunRecord>,
        app_local_only: bool,
        runs_file: String,
        provider_request_sent: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_secret_returned: bool,
        safety_flags: WireLlmPromptRunSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPromptRunRecord {
        id: String,
        preview_id: String,
        confirmation_id: String,
        action: String,
        request_kind: String,
        analysis_kind: Option<String>,
        scope: Option<String>,
        instance_id: Option<String>,
        instance_ids: Vec<String>,
        definition_id: Option<String>,
        agent: Option<String>,
        task: Option<String>,
        profile_id: String,
        provider: String,
        model: String,
        destination_host: String,
        status: String,
        error_code: Option<String>,
        error_message: Option<String>,
        duration_ms: u64,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        estimated_cost_usd: f64,
        draft_output: Option<String>,
        draft_requires_user_copy: bool,
        provider_request_sent: bool,
        credential_accessed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        redaction_summary: WireLlmPromptRunRedactionSummary,
        created_at: i64,
        completed_at: i64,
        safety_flags: WireLlmPromptRunSafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPromptRunRedactionSummary {
        status: String,
        redacted_value_count: usize,
        redacted_fields: Vec<String>,
        placeholders: Vec<String>,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        raw_secret_returned: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmPromptRunSafetyFlags {
        app_local_only: bool,
        provider_request_sent: bool,
        credential_accessed: bool,
        draft_copy_only: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityResult {
        generated_by: String,
        status: String,
        summary: WireLlmProviderObservabilitySummary,
        call_rows: Vec<WireLlmProviderObservabilityCallRow>,
        history_rows: Vec<WireLlmProviderObservabilityHistoryRow>,
        grouping_rows: Vec<WireLlmProviderObservabilityGroupingRow>,
        status_rows: Vec<WireLlmProviderObservabilityStatusRow>,
        budget_usage_hints: Vec<WireLlmProviderObservabilityBudgetUsageHint>,
        retention_recommendations: Vec<WireLlmProviderObservabilityRetentionRecommendationRow>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireLlmProviderObservabilityEvidenceReference>,
        prompt_metadata: WireLlmProviderObservabilityPromptMetadata,
        safety_flags: WireLlmProviderObservabilitySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilitySummary {
        total_prompt_run_count: usize,
        total_call_metadata_count: usize,
        returned_prompt_run_count: usize,
        returned_call_row_count: usize,
        provider_profile_count: usize,
        enabled_profile_count: usize,
        grouping_count: usize,
        observed_provider_request_row_count: usize,
        observed_credential_access_row_count: usize,
        succeeded_count: usize,
        failed_count: usize,
        estimated_input_tokens: u64,
        estimated_output_tokens: u64,
        estimated_total_tokens: u64,
        estimated_cost_usd: f64,
        latest_activity_at: Option<i64>,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityCallRow {
        id: String,
        source: String,
        timestamp: i64,
        action_type: String,
        profile_id: String,
        provider: String,
        model: String,
        destination_host: String,
        status: String,
        error_code: Option<String>,
        error_message: Option<String>,
        duration_ms: u128,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        estimated_cost_usd: f64,
        recorded_provider_request_sent: bool,
        recorded_credential_accessed: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        redaction_status: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityHistoryRow {
        id: String,
        source: String,
        prompt_run_id: String,
        created_at: i64,
        completed_at: i64,
        action: String,
        request_kind: String,
        analysis_kind: Option<String>,
        scope: Option<String>,
        instance_id: Option<String>,
        instance_ids: Vec<String>,
        definition_id: Option<String>,
        agent: Option<String>,
        task: Option<String>,
        profile_id: String,
        provider: String,
        model: String,
        destination_host: String,
        status: String,
        error_code: Option<String>,
        error_message: Option<String>,
        duration_ms: u64,
        estimated_input_tokens: u32,
        estimated_output_tokens: u32,
        estimated_total_tokens: u32,
        estimated_cost_usd: f64,
        draft_output_available: bool,
        draft_requires_user_copy: bool,
        recorded_provider_request_sent: bool,
        recorded_credential_accessed: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        redaction_status: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityGroupingRow {
        id: String,
        provider: String,
        model: String,
        destination_host: String,
        profile_ids: Vec<String>,
        prompt_run_count: usize,
        call_metadata_count: usize,
        recorded_provider_request_count: usize,
        recorded_credential_access_count: usize,
        succeeded_count: usize,
        failed_count: usize,
        estimated_total_tokens: u64,
        estimated_cost_usd: f64,
        latest_activity_at: Option<i64>,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityStatusRow {
        id: String,
        source: String,
        status: String,
        severity: String,
        message: String,
        count: usize,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityBudgetUsageHint {
        id: String,
        profile_id: String,
        provider: String,
        model: String,
        destination_host: String,
        enabled: bool,
        single_request_token_limit: u32,
        monthly_budget_usd: f64,
        observed_prompt_run_count: usize,
        observed_call_metadata_count: usize,
        observed_estimated_total_tokens: u64,
        observed_estimated_cost_usd: f64,
        budget_state: String,
        reason: String,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityRetentionRecommendationRow {
        id: String,
        source_file: String,
        current_record_count: usize,
        recommendation: String,
        cleanup_action_available: bool,
        write_action_available: bool,
        evidence_refs: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityEvidenceReference {
        id: String,
        kind: String,
        label: String,
        source: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilityPromptMetadata {
        available: bool,
        preview_method: String,
        confirm_method: String,
        provider_request_sent: bool,
        copy_only: bool,
        note: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmProviderObservabilitySafetyFlags {
        read_only: bool,
        app_local_only: bool,
        provider_request_sent: bool,
        credential_accessed: bool,
        draft_copy_only: bool,
        write_back_allowed: bool,
        write_actions_available: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        script_execution_allowed: bool,
        execution_actions_available: bool,
        config_mutation_allowed: bool,
        snapshot_created: bool,
        triage_mutation_allowed: bool,
        raw_secret_returned: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        unredacted_paths_returned: bool,
        cloud_sync_performed: bool,
        telemetry_emitted: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmSkillAnalysisIncludedSkill {
        instance_id: String,
        name: String,
        agent: String,
        scope: String,
        enabled: bool,
        disabled_reason: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmSkillAnalysisSafetyFlags {
        write_back_enabled: bool,
        script_execution_enabled: bool,
        credential_storage_enabled: bool,
        confirmation_required: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCleanupQueue {
        summary: WireCleanupQueueSummary,
        items: Vec<WireCleanupQueueItem>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCleanupQueueSummary {
        total_count: usize,
        counts_by_kind: BTreeMap<String, usize>,
        counts_by_priority: BTreeMap<String, usize>,
        read_only: bool,
        writes_allowed: bool,
        provider_request_sent: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireCleanupQueueItem {
        id: String,
        kind: String,
        severity: String,
        priority: String,
        agent: Option<String>,
        scope: Option<String>,
        skill_id: Option<String>,
        definition_id: Option<String>,
        skill_name: Option<String>,
        title: String,
        detail: String,
        recommended_next_action_label: String,
        source_id: String,
        read_only: bool,
        writes_allowed: bool,
        provider_request_sent: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupFlowResult {
        generated_by: String,
        catalog_available: bool,
        filters: WireGuidedCleanupFlowFilters,
        summary: WireGuidedCleanupFlowSummary,
        flow_steps: Vec<WireGuidedCleanupFlowStep>,
        issue_groups: Vec<WireGuidedCleanupIssueGroup>,
        safe_next_actions: Vec<WireGuidedCleanupSafeNextAction>,
        recorded_steps: Vec<WireGuidedCleanupStepRecord>,
        gap_notes: Vec<String>,
        blocker_notes: Vec<String>,
        evidence_references: Vec<WireTaskReadinessEvidenceReference>,
        prompt_request: WireAgentReadinessPromptRequest,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupFlowFilters {
        task: Option<String>,
        agent: Option<String>,
        selected_skill_id: Option<String>,
        selected_skill_name: Option<String>,
        selected_skill_agent: Option<String>,
        project_root: Option<String>,
        current_cwd: Option<String>,
        workspace: Option<String>,
        candidate_instance_ids: Vec<String>,
        limit: usize,
        include_recorded_steps: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupFlowSummary {
        total_step_count: usize,
        returned_step_count: usize,
        issue_group_count: usize,
        safe_next_action_count: usize,
        recorded_step_count: usize,
        high_risk_count: usize,
        medium_risk_count: usize,
        low_risk_count: usize,
        blocker_count: usize,
        summary: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupFlowStep {
        id: String,
        rank: usize,
        step_type: String,
        phase: String,
        title: String,
        summary: String,
        status: String,
        risk: String,
        source_method: String,
        source_id: String,
        agent: Option<String>,
        skill_name: Option<String>,
        instance_id: Option<String>,
        definition_id: Option<String>,
        recommended_action_label: String,
        safe_entry_method: String,
        existing_safe_method: Option<String>,
        safe_action_deep_link: WireGuidedCleanupSafeActionDeepLink,
        requires_explicit_confirmation: bool,
        evidence_refs: Vec<String>,
        blocker_notes: Vec<String>,
        gap_notes: Vec<String>,
        side_effect_flags: Vec<String>,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupIssueGroup {
        id: String,
        group_type: String,
        label: String,
        step_count: usize,
        high_risk_count: usize,
        medium_risk_count: usize,
        low_risk_count: usize,
        step_ids: Vec<String>,
        evidence_refs: Vec<String>,
        blocker_notes: Vec<String>,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupSafeNextAction {
        id: String,
        label: String,
        entry_method: String,
        description: String,
        requires_preview: bool,
        requires_confirmation: bool,
        copy_only: bool,
        deep_link: WireGuidedCleanupSafeActionDeepLink,
        related_step_ids: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupSafeActionDeepLink {
        label: String,
        target: String,
        detail_section: String,
        method: String,
        trigger: String,
        preview_only: bool,
        requires_confirmation: bool,
        copy_only: bool,
        can_apply: bool,
        instance_ids: Vec<String>,
        related_step_ids: Vec<String>,
        evidence_refs: Vec<String>,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupStepRecord {
        id: String,
        flow_step_id: String,
        title: String,
        decision: String,
        status: String,
        note: Option<String>,
        task: Option<String>,
        agent: Option<String>,
        instance_id: Option<String>,
        definition_id: Option<String>,
        skill_name: Option<String>,
        source_refs: Vec<String>,
        evidence_refs: Vec<String>,
        redaction_summary: WireRemediationHistoryRedactionSummary,
        created_at: i64,
        updated_at: i64,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireGuidedCleanupRecordStepResult {
        generated_by: String,
        record: WireGuidedCleanupStepRecord,
        created: bool,
        count: usize,
        app_local_only: bool,
        record_file: String,
        provider_request_sent: bool,
        skill_files_mutated: bool,
        agent_config_mutated: bool,
        snapshot_created: bool,
        rollback_performed: bool,
        triage_mutated: bool,
        script_executed: bool,
        credential_accessed: bool,
        raw_prompt_persisted: bool,
        raw_response_persisted: bool,
        raw_trace_persisted: bool,
        safety_flags: WireRemediationHistorySafetyFlags,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireReportExportLocalResult {
        export_id: String,
        generated_at: i64,
        output_dir: String,
        files: Vec<WireReportExportedFile>,
        catalog_available: bool,
        summary: WireReportExportSummary,
        redaction: WireReportExportRedaction,
        read_only: bool,
        writes_allowed: bool,
        provider_request_sent: bool,
        script_execution_allowed: bool,
        credential_accessed: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireReportExportedFile {
        format: String,
        path: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireReportExportSummary {
        skill_count: usize,
        finding_count: usize,
        open_finding_count: usize,
        triage_count: usize,
        cleanup_item_count: usize,
        comparison_group_count: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireReportExportRedaction {
        enabled: bool,
        placeholders: Vec<String>,
        path_policy: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmConfirmationRequirement {
        required: bool,
        message: String,
        display_fields: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmReviewPreview {
        status: String,
        generated_by: String,
        provider_request_sent: bool,
        write_actions_available: bool,
        execution_actions_available: bool,
        purpose: String,
        risk: WireLlmReviewRisk,
        finding_explanations: Vec<WireLlmReviewFindingExplanation>,
        cross_agent_fit: WireLlmReviewCrossAgentFit,
        redaction: WireLlmReviewRedaction,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmReviewRisk {
        level: String,
        summary: String,
        signals: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmReviewFindingExplanation {
        rule_id: String,
        severity: String,
        explanation: String,
        suggested_next_step: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmReviewCrossAgentFit {
        agent: String,
        scope: String,
        comparable_instance_count: usize,
        summary: String,
        notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireLlmReviewRedaction {
        skill_body_returned: bool,
        paths_returned: bool,
        credentials_returned: bool,
        included_fields: Vec<String>,
        excluded_fields: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionPreviewRecord {
        skill_instance_id: Option<String>,
        initiated_by: String,
        initiator_allowed: bool,
        cwd: WireScriptExecutionCwdScope,
        env: WireScriptExecutionEnvScope,
        network: WireScriptExecutionNetworkScope,
        files: WireScriptExecutionFilesScope,
        command_preview: WireScriptExecutionCommandPreview,
        risks: Vec<String>,
        confirmation: WireScriptExecutionConfirmation,
        execution_allowed: bool,
        disabled_reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionCwdScope {
        requested: Option<String>,
        effective: String,
        source: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionEnvScope {
        inherit_parent: bool,
        provided_keys: Vec<String>,
        redacted_keys: Vec<String>,
        value_policy: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionNetworkScope {
        requested: String,
        allowed: bool,
        reason: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionFilesScope {
        requested: Vec<String>,
        read_allowed: bool,
        write_allowed: bool,
        allowed_roots: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionCommandPreview {
        argv: Vec<String>,
        display: String,
        shell: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionConfirmation {
        required: bool,
        confirmed: bool,
        fields: Vec<String>,
        message: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireScriptExecutionAttemptRecord {
        id: String,
        created_at: i64,
        status: String,
        outcome: String,
        reason: String,
        spawned_process: bool,
        audit_path: String,
        preview: WireScriptExecutionPreviewRecord,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProjectContextSummary {
        source: String,
        active: Option<WireProjectContext>,
        recent_count: usize,
        validation_error: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProjectContextState {
        active: Option<WireProjectContext>,
        recent: Vec<WireProjectContext>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireProjectContext {
        id: String,
        name: String,
        root_path: String,
        current_cwd: String,
        last_used_at: i64,
        is_active: bool,
        validation_error: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRefreshActivity {
        operation: String,
        status: String,
        started_at: i64,
        finished_at: i64,
        scanned_count: usize,
        skill_count: usize,
        finding_count: usize,
        conflict_count: usize,
        snapshot_count: usize,
        roots: Vec<String>,
        log_entries: Vec<WireRefreshLogEntry>,
        recovery_actions: Vec<String>,
        agent_summaries: Option<Vec<WireAgentRefreshSummary>>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRefreshLogEntry {
        level: String,
        message: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireAgentRefreshSummary {
        agent: String,
        display_label: String,
        status: String,
        scanned_count: usize,
        catalog_count: usize,
        broken_count: usize,
        roots_considered: Vec<String>,
        roots_scanned: Vec<String>,
        roots_skipped: Vec<String>,
        #[serde(default)]
        config_detected: bool,
        #[serde(default)]
        config_paths: Vec<String>,
        #[serde(default)]
        writable_status: String,
        #[serde(default)]
        writable_reason: Option<String>,
        #[serde(default)]
        read_only_reason: String,
        #[serde(default)]
        blockers: Vec<String>,
        recovery_actions: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillRecord {
        id: String,
        agent: String,
        scope: String,
        path: PathBuf,
        display_path: PathBuf,
        definition_id: String,
        name: String,
        state: String,
        enabled: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireBatchTogglePreviewRecord {
        preview_token: String,
        target_enabled: bool,
        requested_count: usize,
        writable_count: usize,
        skipped_count: usize,
        writes_allowed: bool,
        affected_items: Vec<WireBatchToggleAffectedItem>,
        skipped_items: Vec<WireBatchToggleSkippedItem>,
        capability_labels: Vec<String>,
        snapshot_rollback_notes: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireBatchToggleApplyRecord {
        preview_token: String,
        target_enabled: bool,
        requested_count: usize,
        writable_count: usize,
        skipped_count: usize,
        applied_count: usize,
        writes_allowed: bool,
        affected_items: Vec<WireBatchToggleAffectedItem>,
        skipped_items: Vec<WireBatchToggleSkippedItem>,
        capability_labels: Vec<String>,
        snapshot_rollback_notes: Vec<String>,
        updated_records: Vec<WireSkillRecord>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireBatchToggleAffectedItem {
        instance_id: String,
        name: String,
        agent: String,
        scope: String,
        current_enabled: bool,
        target_enabled: bool,
        config_scope: String,
        config_target: String,
        capability_label: String,
        snapshot_plan: String,
        rollback_plan: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireBatchToggleSkippedItem {
        instance_id: String,
        name: Option<String>,
        agent: Option<String>,
        scope: Option<String>,
        reason: String,
        capability_label: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillDetailRecord {
        id: String,
        agent: String,
        scope: String,
        path: PathBuf,
        display_path: PathBuf,
        definition_id: String,
        name: String,
        description: String,
        state: String,
        enabled: bool,
        frontmatter_raw: String,
        body: String,
        permissions: Value,
        fingerprint: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireExportedSkillBundle {
        manifest_path: PathBuf,
        bundle_path: PathBuf,
        fingerprint: String,
        metadata: WireExportedSkillMetadata,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireExportedSkillMetadata {
        name: String,
        description: String,
        skill_path: String,
        source_agent: String,
        source_scope: String,
        version: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRuleFindingRecord {
        id: String,
        triage_key: String,
        triage_context: String,
        instance_id: Option<String>,
        definition_id: Option<String>,
        rule_id: String,
        severity: String,
        effective_severity: String,
        severity_override: Option<String>,
        message: String,
        suggestion: Option<String>,
        created_at: i64,
        suppressed: bool,
        suppression_reason: Option<String>,
        suppression_note: Option<String>,
        rule_tuning_updated_at: Option<i64>,
        triage_status: String,
        triage_note: Option<String>,
        triage_updated_at: Option<i64>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireFindingTriageRecord {
        triage_key: String,
        triage_context: String,
        status: String,
        note: Option<String>,
        updated_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireRuleTuningRecord {
        rule_id: String,
        agent: Option<String>,
        scope: Option<String>,
        severity_override: Option<String>,
        suppression_reason: Option<String>,
        suppression_note: Option<String>,
        updated_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireConflictGroupRecord {
        id: String,
        definition_id: String,
        reason: String,
        winner_id: Option<String>,
        instance_ids: Vec<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireToolGlobalImportResult {
        imported: WireSkillRecord,
        instance_id: String,
        source_path: String,
        staging_path: String,
        findings: Vec<WireRuleFindingRecord>,
        audit: WireToolGlobalImportAudit,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireToolGlobalImportAudit {
        status: String,
        read_only_preview: bool,
        finding_count: usize,
        error_count: usize,
        warn_count: usize,
        info_count: usize,
        conflict_count: usize,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireConfigDocumentRecord {
        agent: String,
        scope: String,
        target: String,
        format: String,
        content: String,
        exists: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillInstallPreviewRecord {
        source_instance_id: String,
        source_path: String,
        target_agent: String,
        target_scope: String,
        target_path: String,
        files: Vec<WireSkillInstallFilePreview>,
        risks: Vec<String>,
        confirmation: WireSkillInstallConfirmation,
        wrote: bool,
        snapshot_id: Option<String>,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillInstallFilePreview {
        source: String,
        target: String,
        kind: String,
        will_write: bool,
        target_exists: bool,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillInstallConfirmation {
        required: bool,
        confirmed: bool,
        fields: Vec<String>,
        message: String,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireConfigSnapshotRecord {
        id: String,
        agent: String,
        scope: String,
        target: String,
        content: String,
        reason: String,
        created_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSkillEventRecord {
        id: i64,
        instance_id: String,
        kind: String,
        payload: Value,
        occurred_at: i64,
    }

    #[allow(dead_code)]
    #[derive(Debug, Deserialize)]
    #[serde(deny_unknown_fields)]
    struct WireSnapshotRollbackPreviewRecord {
        snapshot: WireConfigSnapshotRecord,
        current_content: String,
        current_read_error: Option<String>,
        changed: bool,
        redacted: Option<bool>,
        rollback_supported: Option<bool>,
    }
