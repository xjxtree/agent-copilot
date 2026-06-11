use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use skills_copilot_catalog::{
    Catalog, ConfigSnapshotRecord, ConflictGroupRecord, FindingTriageRecord, RuleFindingRecord,
    RuleTuningRecord, SkillDetailRecord, SkillEventRecord, SkillRecord,
};
use skills_copilot_commands::{
    analyze_catalog, apply_skill_toggles, clear_finding_triage, clear_rule_severity_override,
    clear_rule_suppression, empty_cross_agent_comparison, export_skill_bundle,
    export_staging_skill_bundle, get_skill, import_github_skill_to_tool_global_deferred,
    import_local_skill_to_tool_global, install_skill_from_tool_global, list_adapter_capabilities,
    list_adapter_diagnostics, list_agent_config_snapshots, list_conflicts,
    list_cross_agent_comparisons, list_finding_triage, list_findings, list_rule_tuning,
    list_skill_events, list_snapshots, preview_script_execution, preview_skill_toggles,
    preview_snapshot_rollback, read_claude_settings, record_blocked_script_execution,
    rollback_snapshot, run_pi_writable_evidence_harness, save_claude_settings,
    scan_all_catalog_report, scan_claude_to_catalog, set_finding_triage,
    set_rule_severity_override, set_rule_suppression, skill_health_summary, toggle_skill,
    AdapterCapabilityRecord, AdapterDiagnosticsRecord, AgentCatalogScanReport,
    BatchToggleApplyRecord, BatchTogglePreviewRecord, ConfigDocumentRecord,
    CrossAgentAnalysisGroup, CrossAgentAnalysisRecord, CrossAgentComparisonRecord,
    ExportedSkillBundle, PiWritableHarnessReport, ScriptExecutionAttemptRecord,
    ScriptExecutionPreviewRecord, ScriptExecutionRequest, SkillHealthSummary,
    SkillInstallPreviewRecord, SnapshotRollbackPreviewRecord, ToolGlobalImportResult,
    SCRIPT_EXECUTION_DISABLED_REASON,
};
use skills_copilot_core::{AdapterContext, AdapterRoot, AgentId, RootSource, Scope, SkillInstance};
use thiserror::Error;

mod project_context;
mod provider;

use project_context::{
    clear_project_context, context_from_paths, load_project_context_state, project_context_summary,
    set_project_context, stored_active_adapter_paths, validate_project_context_for_response,
    ProjectContext, ProjectContextParams, ProjectContextState, ProjectContextSummary,
};
use provider::{
    default_monthly_budget_usd, default_token_limit, delete_provider_profile,
    estimate_prompt_cost_usd, list_provider_profiles, provider_call_metadata_path,
    provider_profiles_path, save_provider_profile, send_provider_prompt, test_provider_connection,
    DeleteProviderProfileParams, ListProviderProfilesResult, ProviderCallMetadata, ProviderError,
    ProviderProfileRecord, SaveProviderProfileParams, SendProviderPromptParams,
    TestProviderConnectionParams,
};

const DEFAULT_BUNDLE_ID: &str = "dev.skills-copilot.native";
const SERVICE_PROTOCOL_VERSION: u32 = 1;
const SUPPORTED_METHODS: &[&str] = &[
    "app.version",
    "app.stateSnapshot",
    "service.status",
    "adapter.listCapabilities",
    "adapter.listDiagnostics",
    "evidence.piWritableHarness",
    "analysis.scoreSkillQuality",
    "analysis.detectStaleDrift",
    "knowledge.search",
    "knowledge.groupSimilarSkills",
    "task.checkReadiness",
    "task.rankSkillRoutes",
    "task.compareAgentReadiness",
    "task.listBenchmarks",
    "task.saveBenchmark",
    "task.deleteBenchmark",
    "task.evaluateBenchmarks",
    "task.saveRoutingBaseline",
    "task.detectRoutingRegression",
    "routing.accuracyDashboard",
    "trace.importLocal",
    "trace.listImports",
    "trace.deleteImport",
    "llm.status",
    "llm.listProviderProfiles",
    "llm.saveProviderProfile",
    "llm.deleteProviderProfile",
    "llm.testProviderConnection",
    "llm.previewPrompt",
    "llm.confirmPromptAndSend",
    "llm.prepareAction",
    "llm.prepareSkillAnalysis",
    "cleanup.listQueue",
    "comparison.listCrossAgent",
    "report.exportLocal",
    "rules.listTuning",
    "rules.setSeverityOverride",
    "rules.clearSeverityOverride",
    "rules.setSuppression",
    "rules.clearSuppression",
    "batch.previewSkillToggles",
    "batch.applySkillToggles",
    "script.previewExecution",
    "script.execute",
    "project.getContext",
    "project.setContext",
    "project.clearContext",
    "project.validateContext",
    "catalog.listSkills",
    "catalog.getSkill",
    "catalog.analysis",
    "catalog.listFindings",
    "catalog.listFindingTriage",
    "catalog.setFindingTriage",
    "catalog.clearFindingTriage",
    "catalog.listConflicts",
    "catalog.importSkill",
    "catalog.scanClaude",
    "catalog.scanAll",
    "skill.exportBundle",
    "skill.install",
    "skill.listEvents",
    "config.toggleSkill",
    "config.readClaudeSettings",
    "config.saveClaudeSettings",
    "snapshot.list",
    "snapshot.listAgentConfig",
    "snapshot.previewRollback",
    "snapshot.rollback",
];

#[derive(Debug, Clone, Deserialize)]
pub struct ServiceRequest {
    pub id: Option<String>,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceResponse {
    pub id: Option<String>,
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ServiceErrorRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServiceErrorRecord {
    pub code: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ServiceStatus {
    pub protocol_version: u32,
    pub version: &'static str,
    pub app_data_dir: String,
    pub catalog_path: String,
    pub user_home: String,
    pub supported_methods: Vec<&'static str>,
    pub refresh: RefreshStatus,
    pub project_context: ProjectContextSummary,
    pub adapter_capabilities: Vec<AdapterCapabilityRecord>,
    pub adapter_diagnostics: Vec<AdapterDiagnosticsRecord>,
    pub llm: LlmStatus,
    pub trace_imports: TraceImportStatus,
    pub script_execution: ScriptExecutionStatus,
}

#[derive(Debug, Clone, Serialize)]
pub struct AppVersion {
    pub protocol_version: u32,
    pub version: &'static str,
}

#[derive(Debug, Clone, Serialize)]
pub struct AppStateSnapshot {
    pub status: ServiceStatus,
    pub skills: Vec<SkillRecord>,
    pub findings: Vec<RuleFindingRecord>,
    pub conflicts: Vec<ConflictGroupRecord>,
    pub analysis: CrossAgentAnalysisRecord,
    pub health: SkillHealthSummary,
    pub snapshots: Vec<ConfigSnapshotRecord>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ScanResult {
    pub scanned_count: usize,
    pub skills: Vec<SkillRecord>,
    pub activity: RefreshActivity,
}

#[derive(Debug, Clone, Serialize)]
pub struct RefreshStatus {
    pub scan_progress: &'static str,
    pub watcher_state: &'static str,
    pub watcher_detail: &'static str,
    pub recovery_actions: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RefreshActivity {
    pub operation: &'static str,
    pub status: &'static str,
    pub started_at: i64,
    pub finished_at: i64,
    pub scanned_count: usize,
    pub skill_count: usize,
    pub finding_count: usize,
    pub conflict_count: usize,
    pub snapshot_count: usize,
    pub roots: Vec<String>,
    pub log_entries: Vec<RefreshLogEntry>,
    pub recovery_actions: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub agent_summaries: Option<Vec<AgentRefreshSummary>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RefreshLogEntry {
    pub level: &'static str,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentRefreshSummary {
    pub agent: String,
    pub display_label: String,
    pub status: &'static str,
    pub scanned_count: usize,
    pub catalog_count: usize,
    pub broken_count: usize,
    pub roots_considered: Vec<String>,
    pub roots_scanned: Vec<String>,
    pub roots_skipped: Vec<String>,
    pub config_detected: bool,
    pub config_paths: Vec<String>,
    pub writable_status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub writable_reason: Option<String>,
    pub read_only_reason: String,
    pub blockers: Vec<String>,
    pub recovery_actions: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LlmStatus {
    pub enabled: bool,
    pub configured: bool,
    pub provider: Option<String>,
    pub model: Option<String>,
    pub reason: String,
    pub single_request_token_limit: u32,
    pub monthly_budget_usd: f64,
    pub credentials_storage: String,
    pub credential_persistence_allowed: bool,
    pub provider_profile_count: usize,
    pub default_profile_id: Option<String>,
    pub profiles_path: String,
    pub call_metadata_path: String,
    pub raw_prompt_persistence_allowed: bool,
    pub raw_response_persistence_allowed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptExecutionStatus {
    pub enabled: bool,
    pub default_enabled: bool,
    pub reason: String,
    pub audit_scope: String,
    pub audit_path: String,
    pub llm_initiation_allowed: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TraceImportStatus {
    pub count: usize,
    pub imports_path: String,
    pub app_local_only: bool,
    pub raw_trace_persistence_allowed: bool,
    pub provider_request_allowed: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct CleanupListQueueParams {
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueue {
    pub summary: CleanupQueueSummary,
    pub items: Vec<CleanupQueueItem>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueueSummary {
    pub total_count: usize,
    pub counts_by_kind: BTreeMap<String, usize>,
    pub counts_by_priority: BTreeMap<String, usize>,
    pub read_only: bool,
    pub writes_allowed: bool,
    pub provider_request_sent: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueueItem {
    pub id: String,
    pub kind: String,
    pub severity: String,
    pub priority: String,
    pub agent: Option<String>,
    pub scope: Option<String>,
    pub skill_id: Option<String>,
    pub definition_id: Option<String>,
    pub skill_name: Option<String>,
    pub title: String,
    pub detail: String,
    pub recommended_next_action_label: String,
    pub source_id: String,
    pub read_only: bool,
    pub writes_allowed: bool,
    pub provider_request_sent: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ListCrossAgentComparisonParams {
    #[serde(default)]
    pub selected_instance_id: Option<String>,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub query: Option<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ReportExportLocalParams {
    #[serde(default)]
    pub formats: Vec<ReportExportFormat>,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReportExportFormat {
    Json,
    Markdown,
}

impl ReportExportFormat {
    fn extension(self) -> &'static str {
        match self {
            Self::Json => "json",
            Self::Markdown => "md",
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::Json => "json",
            Self::Markdown => "markdown",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct ReportExportLocalResult {
    pub export_id: String,
    pub generated_at: i64,
    pub output_dir: String,
    pub files: Vec<ReportExportedFile>,
    pub catalog_available: bool,
    pub summary: ReportExportSummary,
    pub redaction: ReportExportRedaction,
    pub read_only: bool,
    pub writes_allowed: bool,
    pub provider_request_sent: bool,
    pub script_execution_allowed: bool,
    pub credential_accessed: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReportExportedFile {
    pub format: &'static str,
    pub path: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReportExportSummary {
    pub skill_count: usize,
    pub finding_count: usize,
    pub open_finding_count: usize,
    pub triage_count: usize,
    pub cleanup_item_count: usize,
    pub comparison_group_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct ReportExportRedaction {
    pub enabled: bool,
    pub placeholders: Vec<&'static str>,
    pub path_policy: &'static str,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ScoreSkillQualityParams {
    #[serde(alias = "skill_instance_id")]
    pub instance_id: String,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub definition_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualityScoreResult {
    pub instance_id: String,
    pub definition_id: String,
    pub agent: String,
    pub scope: String,
    pub skill_name: String,
    pub score: u8,
    pub grade: &'static str,
    pub band: &'static str,
    pub generated_by: &'static str,
    pub components: Vec<SkillQualityScoreComponent>,
    pub reasons: Vec<String>,
    pub risk_notes: Vec<String>,
    pub evidence_references: Vec<SkillQualityEvidenceReference>,
    pub suggested_improvements: Vec<SkillQualitySuggestion>,
    pub prompt_request: SkillQualityPromptRequest,
    pub safety_flags: SkillQualitySafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualityScoreComponent {
    pub id: &'static str,
    pub label: &'static str,
    pub score: u8,
    pub max_score: u8,
    pub summary: String,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualityEvidenceReference {
    pub id: String,
    pub source_type: &'static str,
    pub source_id: String,
    pub label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub severity: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub related_instance_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualitySuggestion {
    pub priority: &'static str,
    pub title: String,
    pub detail: String,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualityPromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillQualitySafetyFlags {
    pub read_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TaskReadinessParams {
    #[serde(alias = "user_intent", alias = "task_text")]
    pub task: String,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default, alias = "instance_ids")]
    pub candidate_instance_ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessResult {
    pub task: String,
    pub score: u8,
    pub band: &'static str,
    pub summary: String,
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: TaskReadinessFilters,
    pub candidate_skills: Vec<TaskReadinessCandidate>,
    pub missing_gap_notes: Vec<String>,
    pub blocker_risk_notes: Vec<String>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: TaskReadinessPromptRequest,
    pub safety_flags: TaskReadinessSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessFilters {
    pub agent: Option<String>,
    pub candidate_instance_ids: Vec<String>,
    pub limit: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessCandidate {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub score: u8,
    pub band: &'static str,
    pub quality_score: Option<u8>,
    pub match_reasons: Vec<String>,
    pub enabled_scope_risk_state: TaskReadinessState,
    pub missing_gap_notes: Vec<String>,
    pub blocker_risk_notes: Vec<String>,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessState {
    pub enabled: bool,
    pub scope: String,
    pub state: String,
    pub risk_level: &'static str,
    pub risk_summary: String,
    pub writable_status: Option<String>,
    pub adapter_status: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessEvidenceReference {
    pub id: String,
    pub source_type: &'static str,
    pub source_id: String,
    pub label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub severity: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub related_instance_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessPromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskReadinessSafetyFlags {
    pub read_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RankSkillRoutesParams {
    #[serde(alias = "user_intent", alias = "task_text")]
    pub task: String,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default, alias = "instance_ids")]
    pub candidate_instance_ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillRouteRankingResult {
    pub task: String,
    pub overall_confidence_score: u8,
    pub overall_confidence_band: &'static str,
    pub summary: String,
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: TaskReadinessFilters,
    pub route_candidates: Vec<SkillRouteCandidate>,
    pub ambiguity_warnings: Vec<String>,
    pub likely_wrong_pick_risks: Vec<String>,
    pub likely_miss_risks: Vec<String>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: RoutingConfidencePromptRequest,
    pub safety_flags: RoutingConfidenceSafetyFlags,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CompareAgentReadinessParams {
    #[serde(alias = "user_intent", alias = "task_text")]
    pub task: String,
    #[serde(default, alias = "target_agents")]
    pub agents: Vec<String>,
    #[serde(default)]
    pub limit_per_agent: Option<usize>,
    #[serde(default)]
    pub include_routing_accuracy: bool,
    #[serde(default)]
    pub include_benchmarks: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessComparisonResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: AgentReadinessComparisonFilters,
    pub summary: AgentReadinessComparisonSummary,
    pub agent_rows: Vec<AgentReadinessComparisonRow>,
    pub recommended_agent: Option<AgentReadinessRecommendation>,
    pub gap_issue_rows: Vec<AgentReadinessGapIssueRow>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: AgentReadinessPromptRequest,
    pub safety_flags: AgentReadinessSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessComparisonFilters {
    pub agents: Vec<String>,
    pub limit_per_agent: usize,
    pub include_routing_accuracy: bool,
    pub include_benchmarks: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessComparisonSummary {
    pub agent_count: usize,
    pub candidate_count: usize,
    pub ready_agent_count: usize,
    pub partial_agent_count: usize,
    pub blocked_agent_count: usize,
    pub gap_issue_count: usize,
    pub recommended_agent: Option<String>,
    pub summary: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessComparisonRow {
    pub rank: usize,
    pub agent: String,
    pub display_name: String,
    pub comparison_score: u8,
    pub readiness_score: u8,
    pub readiness_band: &'static str,
    pub routing_confidence_score: u8,
    pub routing_confidence_band: &'static str,
    pub candidate_count: usize,
    pub best_candidate: Option<AgentReadinessBestCandidate>,
    pub enabled_scope_risk_state: Option<TaskReadinessState>,
    pub blocker_count: usize,
    pub gap_count: usize,
    pub reasons: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub gap_notes: Vec<String>,
    pub routing_accuracy_context: Option<AgentReadinessAccuracyContext>,
    pub benchmark_context: Option<AgentReadinessBenchmarkContext>,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessBestCandidate {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub readiness_score: u8,
    pub readiness_band: &'static str,
    pub routing_confidence_score: u8,
    pub routing_confidence_band: &'static str,
    pub quality_score: Option<u8>,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AgentReadinessAccuracyContext {
    pub trace_count: usize,
    pub accuracy_rate: f64,
    pub benchmark_count: usize,
    pub benchmark_gap_count: usize,
    pub regression_count: usize,
    pub recent_evidence_count: usize,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AgentReadinessBenchmarkContext {
    pub evaluated_count: usize,
    pub matched_count: usize,
    pub gap_count: usize,
    pub regression_count: usize,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessRecommendation {
    pub agent: String,
    pub display_name: String,
    pub comparison_score: u8,
    pub readiness_score: u8,
    pub routing_confidence_score: u8,
    pub skill_name: Option<String>,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessGapIssueRow {
    pub source: &'static str,
    pub severity: &'static str,
    pub agent: String,
    pub title: String,
    pub detail: String,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AgentReadinessPromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct AgentReadinessSafetyFlags {
    pub read_only: bool,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub write_actions_available: bool,
    pub skill_files_mutated: bool,
    pub agent_config_mutated: bool,
    pub script_execution_allowed: bool,
    pub execution_actions_available: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
    pub raw_trace_persisted: bool,
    pub cloud_sync_performed: bool,
    pub telemetry_emitted: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct KnowledgeSearchParams {
    #[serde(default)]
    pub query: Option<String>,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub limit: Option<usize>,
    #[serde(default)]
    pub risk: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
    #[serde(default)]
    pub enabled: Option<bool>,
    #[serde(default)]
    pub tool: Option<String>,
    #[serde(default)]
    pub keyword: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeSearchResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub summary: KnowledgeSearchSummary,
    pub filters: KnowledgeSearchFilters,
    pub rows: Vec<KnowledgeSearchRow>,
    pub facets: KnowledgeSearchFacets,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: KnowledgeSearchPromptRequest,
    pub safety_flags: KnowledgeSearchSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeSearchSummary {
    pub indexed_skill_count: usize,
    pub matched_row_count: usize,
    pub returned_row_count: usize,
    pub enabled_count: usize,
    pub disabled_count: usize,
    pub high_risk_count: usize,
    pub stale_or_drift_count: usize,
    pub summary: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeSearchFilters {
    pub query: Option<String>,
    pub normalized_terms: Vec<String>,
    pub agent: Option<String>,
    pub limit: usize,
    pub risk: Option<String>,
    pub scope: Option<String>,
    pub enabled: Option<bool>,
    pub tool: Option<String>,
    pub keyword: Option<String>,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct KnowledgeSearchFacets {
    pub agents: BTreeMap<String, usize>,
    pub scopes: BTreeMap<String, usize>,
    pub states: BTreeMap<String, usize>,
    pub enabled: BTreeMap<String, usize>,
    pub risks: BTreeMap<String, usize>,
    pub tools: BTreeMap<String, usize>,
    pub keywords: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeSearchRow {
    pub rank: usize,
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub source: KnowledgeSearchSource,
    pub purpose_snippet: Option<String>,
    pub description_snippet: Option<String>,
    pub matched_fields: Vec<String>,
    pub match_reasons: Vec<String>,
    pub keywords: Vec<String>,
    pub tools: Vec<String>,
    pub rules: Vec<String>,
    pub capability_tags: Vec<String>,
    pub risk_tags: Vec<String>,
    pub quality_context: Option<KnowledgeQualityContext>,
    pub readiness_context: Option<KnowledgeReadinessContext>,
    pub stale_drift_context: Option<KnowledgeStaleDriftContext>,
    pub evidence_refs: Vec<String>,
    pub safety_flags: KnowledgeSearchSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeSearchSource {
    pub source_path: String,
    pub display_path: String,
    pub root_provenance: String,
    pub fingerprint: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeQualityContext {
    pub score: u8,
    pub grade: &'static str,
    pub band: &'static str,
    pub reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeReadinessContext {
    pub score: u8,
    pub band: &'static str,
    pub risk_level: &'static str,
    pub risk_summary: String,
    pub gap_count: usize,
    pub blocker_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct KnowledgeStaleDriftContext {
    pub score: u8,
    pub band: &'static str,
    pub fingerprint_drift: bool,
    pub finding_drift: bool,
    pub source_drift: bool,
    pub stale_by_mtime: bool,
    pub readiness_impact_level: Option<&'static str>,
}

pub type KnowledgeSearchPromptRequest = AgentReadinessPromptRequest;
pub type KnowledgeSearchSafetyFlags = AgentReadinessSafetyFlags;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SimilarSkillGroupingParams {
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub limit: Option<usize>,
    #[serde(default)]
    pub min_score: Option<f64>,
    #[serde(default)]
    pub include_singletons: bool,
    #[serde(default)]
    pub candidate_instance_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SimilarSkillGroupingResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: SimilarSkillGroupingFilters,
    pub summary: SimilarSkillGroupingSummary,
    pub groups: Vec<SimilarSkillGroup>,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: SimilarSkillGroupingPromptRequest,
    pub safety_flags: SimilarSkillGroupingSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct SimilarSkillGroupingFilters {
    pub agent: Option<String>,
    pub limit: usize,
    pub min_score: u8,
    pub include_singletons: bool,
    pub candidate_instance_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SimilarSkillGroupingSummary {
    pub indexed_skill_count: usize,
    pub candidate_skill_count: usize,
    pub matched_group_count: usize,
    pub returned_group_count: usize,
    pub duplicate_group_count: usize,
    pub confusable_group_count: usize,
    pub coverage_redundancy_group_count: usize,
    pub routing_ambiguity_count: usize,
    pub summary: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct SimilarSkillGroup {
    pub group_id: String,
    pub rank: usize,
    pub group_type: &'static str,
    pub similarity_score: u8,
    pub ambiguity_risk: &'static str,
    pub coverage_redundancy: &'static str,
    pub routing_ambiguity: &'static str,
    pub canonical_name: String,
    pub canonical_key: String,
    pub title: String,
    pub summary: String,
    pub why_grouped: Vec<String>,
    pub shared_terms: Vec<String>,
    pub shared_tools: Vec<String>,
    pub shared_rules: Vec<String>,
    pub shared_capability_tags: Vec<String>,
    pub shared_risk_tags: Vec<String>,
    pub shared_source_signals: Vec<String>,
    pub members: Vec<SimilarSkillMember>,
    pub evidence_refs: Vec<String>,
    pub safety_flags: SimilarSkillGroupingSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct SimilarSkillMember {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub source: KnowledgeSearchSource,
    pub quality_context: Option<KnowledgeQualityContext>,
    pub readiness_context: Option<KnowledgeReadinessContext>,
    pub stale_drift_context: Option<KnowledgeStaleDriftContext>,
    pub match_reasons: Vec<String>,
    pub similarity_reasons: Vec<String>,
    pub evidence_refs: Vec<String>,
}

pub type SimilarSkillGroupingPromptRequest = AgentReadinessPromptRequest;
pub type SimilarSkillGroupingSafetyFlags = AgentReadinessSafetyFlags;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct DetectStaleDriftParams {
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default, alias = "instance_ids")]
    pub candidate_instance_ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
    #[serde(default)]
    pub stale_days: Option<u32>,
    #[serde(default)]
    pub thresholds: StaleDriftThresholds,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct StaleDriftThresholds {
    #[serde(default)]
    pub stale_days: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftDetectionResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: StaleDriftFilters,
    pub summary: StaleDriftSummary,
    pub stale_drift_rows: Vec<StaleDriftRow>,
    pub readiness_impact_rows: Vec<StaleDriftReadinessImpactRow>,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_references: Vec<TaskReadinessEvidenceReference>,
    pub prompt_request: StaleDriftPromptRequest,
    pub safety_flags: StaleDriftSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftFilters {
    pub agent: Option<String>,
    pub candidate_instance_ids: Vec<String>,
    pub limit: usize,
    pub stale_days: u32,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftSummary {
    pub scanned_skill_count: usize,
    pub returned_row_count: usize,
    pub stale_count: usize,
    pub drift_count: usize,
    pub high_risk_count: usize,
    pub medium_risk_count: usize,
    pub low_risk_count: usize,
    pub missing_history_count: usize,
    pub summary: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftRow {
    pub rank: usize,
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub stale_drift_score: u8,
    pub stale_drift_band: &'static str,
    pub drift_signals: StaleDriftSignals,
    pub readiness_impact: Option<StaleDriftReadinessImpact>,
    pub reasons: Vec<String>,
    pub gap_notes: Vec<String>,
    pub evidence_refs: Vec<String>,
    pub safety_flags: StaleDriftSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftSignals {
    pub fingerprint_drift: bool,
    pub finding_drift: bool,
    pub source_drift: bool,
    pub modified_age_days: Option<i64>,
    pub stale_by_mtime: bool,
    pub missing_mtime: bool,
    pub missing_previous_scan: bool,
    pub related_finding_count: usize,
    pub related_conflict_count: usize,
    pub related_analysis_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftReadinessImpact {
    pub impact_level: &'static str,
    pub readiness_risk_score: u8,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct StaleDriftReadinessImpactRow {
    pub instance_id: String,
    pub skill_name: String,
    pub agent: String,
    pub impact_level: &'static str,
    pub stale_drift_score: u8,
    pub notes: Vec<String>,
    pub evidence_refs: Vec<String>,
}

pub type StaleDriftPromptRequest = AgentReadinessPromptRequest;
pub type StaleDriftSafetyFlags = AgentReadinessSafetyFlags;

#[derive(Debug, Clone, Serialize)]
pub struct SkillRouteCandidate {
    pub rank: usize,
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub state: String,
    pub confidence_score: u8,
    pub confidence_band: &'static str,
    pub readiness_score: u8,
    pub readiness_band: &'static str,
    pub quality_score: Option<u8>,
    pub match_reasons: Vec<String>,
    pub confidence_rationale: Vec<String>,
    pub ambiguity_warnings: Vec<String>,
    pub likely_wrong_pick_risks: Vec<String>,
    pub likely_miss_risks: Vec<String>,
    pub enabled_scope_risk_state: TaskReadinessState,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingConfidencePromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingConfidenceSafetyFlags {
    pub read_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskBenchmarkRecord {
    pub id: String,
    pub title: String,
    #[serde(alias = "task_text", alias = "user_intent")]
    pub task: String,
    #[serde(default)]
    pub expected_skill_refs: Vec<String>,
    #[serde(default)]
    pub expected_skill_names: Vec<String>,
    #[serde(default)]
    pub acceptable_agents: Vec<String>,
    #[serde(default)]
    pub acceptable_scopes: Vec<String>,
    #[serde(default)]
    pub success_criteria: Vec<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ListTaskBenchmarksParams {
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SaveTaskBenchmarkParams {
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default, alias = "name")]
    pub title: Option<String>,
    #[serde(alias = "task_text", alias = "user_intent")]
    pub task: String,
    #[serde(default)]
    pub expected_skill_refs: Vec<String>,
    #[serde(default)]
    pub expected_skill_names: Vec<String>,
    #[serde(default)]
    pub acceptable_agents: Vec<String>,
    #[serde(default)]
    pub acceptable_scopes: Vec<String>,
    #[serde(default)]
    pub success_criteria: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DeleteTaskBenchmarkParams {
    #[serde(alias = "benchmark_id")]
    pub id: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct EvaluateTaskBenchmarksParams {
    #[serde(default, alias = "benchmark_ids")]
    pub ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskBenchmarkListResult {
    pub benchmarks: Vec<TaskBenchmarkRecord>,
    pub count: usize,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct SaveTaskBenchmarkResult {
    pub benchmark: TaskBenchmarkRecord,
    pub created: bool,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub agent_config_mutated: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct DeleteTaskBenchmarkResult {
    pub benchmark_id: String,
    pub deleted: bool,
    pub remaining_count: usize,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub agent_config_mutated: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskBenchmarkEvaluationResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub evaluated_count: usize,
    pub summary: String,
    pub benchmark_results: Vec<TaskBenchmarkEvaluationItem>,
    pub blocker_notes: Vec<String>,
    pub prompt_request: TaskBenchmarkPromptRequest,
    pub safety_flags: TaskBenchmarkSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskBenchmarkEvaluationItem {
    pub benchmark_id: String,
    pub title: String,
    pub task: String,
    pub score: u8,
    pub band: &'static str,
    pub expected_match_status: &'static str,
    pub expected_match_reasons: Vec<String>,
    pub top_route: Option<TaskBenchmarkRouteSummary>,
    pub route_confidence_score: u8,
    pub route_confidence_band: &'static str,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_refs: Vec<String>,
    pub safety_flags: TaskBenchmarkSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskBenchmarkRouteSummary {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub confidence_score: u8,
    pub confidence_band: &'static str,
    pub readiness_score: u8,
    pub readiness_band: &'static str,
}

#[derive(Debug, Clone, Serialize)]
pub struct TaskBenchmarkPromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct TaskBenchmarkSafetyFlags {
    pub read_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SaveRoutingBaselineParams {
    #[serde(default, alias = "benchmark_ids")]
    pub ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct DetectRoutingRegressionParams {
    #[serde(default, alias = "benchmark_ids")]
    pub ids: Vec<String>,
    #[serde(default)]
    pub limit: Option<usize>,
    #[serde(default)]
    pub score_drop_threshold: Option<u8>,
    #[serde(default)]
    pub confidence_drop_threshold: Option<u8>,
}

#[derive(Debug, Clone, Serialize)]
pub struct SaveRoutingBaselineResult {
    pub generated_by: &'static str,
    pub baseline: RoutingRegressionBaseline,
    pub benchmark_count: usize,
    pub app_local_only: bool,
    pub baseline_file: &'static str,
    pub provider_request_sent: bool,
    pub agent_config_mutated: bool,
    pub skill_files_mutated: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingRegressionDetectionResult {
    pub generated_by: &'static str,
    pub status: &'static str,
    pub baseline_available: bool,
    pub catalog_available: bool,
    pub baseline_evaluated_count: usize,
    pub current_evaluated_count: usize,
    pub regression_count: usize,
    pub missing_benchmark_count: usize,
    pub summary: String,
    pub items: Vec<RoutingRegressionItem>,
    pub blocker_notes: Vec<String>,
    pub baseline: Option<RoutingRegressionBaseline>,
    pub current_evaluation: TaskBenchmarkEvaluationResult,
    pub safety_flags: TaskBenchmarkSafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingRegressionItem {
    pub benchmark_id: String,
    pub title: String,
    pub status: &'static str,
    pub regression: bool,
    pub reasons: Vec<String>,
    pub evidence_refs: Vec<String>,
    pub score_delta: Option<i16>,
    pub confidence_delta: Option<i16>,
    pub baseline: Option<RoutingRegressionComparisonFields>,
    pub current: Option<RoutingRegressionComparisonFields>,
    pub safety_flags: TaskBenchmarkSafetyFlags,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoutingRegressionBaseline {
    pub schema_version: u32,
    pub generated_by: String,
    pub generated_at: i64,
    pub catalog_available: bool,
    pub evaluated_count: usize,
    pub benchmark_results: Vec<RoutingRegressionBaselineItem>,
    pub safety_flags: TaskBenchmarkSafetyFlags,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoutingRegressionBaselineItem {
    pub benchmark_id: String,
    pub title: String,
    pub task: String,
    pub score: u8,
    pub band: String,
    pub expected_match_status: String,
    pub top_route: Option<RoutingRegressionRouteSnapshot>,
    pub route_confidence_score: u8,
    pub route_confidence_band: String,
    pub gap_count: usize,
    pub blocker_count: usize,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RoutingRegressionRouteSnapshot {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub confidence_score: u8,
    pub confidence_band: String,
    pub readiness_score: u8,
    pub readiness_band: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingRegressionComparisonFields {
    pub task: String,
    pub expected_match_status: String,
    pub score: u8,
    pub band: String,
    pub top_route: Option<RoutingRegressionRouteSnapshot>,
    pub route_confidence_score: u8,
    pub route_confidence_band: String,
    pub gap_count: usize,
    pub blocker_count: usize,
    pub gap_notes: Vec<String>,
    pub blocker_notes: Vec<String>,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RoutingAccuracyDashboardParams {
    #[serde(default, alias = "target_agent")]
    pub agent: Option<String>,
    #[serde(default, alias = "days")]
    pub window_days: Option<u32>,
    #[serde(default)]
    pub limit: Option<usize>,
    #[serde(default)]
    pub include_history: bool,
    #[serde(default)]
    pub include_recent_evidence: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyDashboardResult {
    pub generated_by: &'static str,
    pub catalog_available: bool,
    pub filters: RoutingAccuracyDashboardFilters,
    pub summary: RoutingAccuracyDashboardSummary,
    pub agent_rows: Vec<RoutingAccuracyAgentRow>,
    pub history_rows: Vec<RoutingAccuracyHistoryRow>,
    pub gap_issue_rows: Vec<RoutingAccuracyIssueRow>,
    pub recent_evidence_rows: Vec<RoutingAccuracyEvidenceRow>,
    pub blocker_notes: Vec<String>,
    pub prompt_request: RoutingAccuracyPromptRequest,
    pub safety_flags: RoutingAccuracySafetyFlags,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyDashboardFilters {
    pub agent: Option<String>,
    pub window_days: u32,
    pub limit: usize,
    pub include_history: bool,
    pub include_recent_evidence: bool,
    pub window_start_millis: i64,
    pub window_end_millis: i64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct RoutingAccuracyDashboardSummary {
    pub trace_count: usize,
    pub hit_count: usize,
    pub miss_count: usize,
    pub wrong_pick_count: usize,
    pub ambiguous_count: usize,
    pub unknown_count: usize,
    pub benchmark_count: usize,
    pub benchmark_matched_count: usize,
    pub benchmark_gap_count: usize,
    pub regression_count: usize,
    pub missing_benchmark_count: usize,
    pub accuracy_rate: f64,
    pub known_outcome_rate: f64,
    pub summary: String,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct RoutingAccuracyOutcomeCounts {
    pub hit: usize,
    pub miss: usize,
    pub wrong_pick: usize,
    pub ambiguous: usize,
    pub unknown: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyAgentRow {
    pub agent: String,
    pub trace_count: usize,
    pub outcomes: RoutingAccuracyOutcomeCounts,
    pub accuracy_rate: f64,
    pub benchmark_count: usize,
    pub benchmark_matched_count: usize,
    pub benchmark_gap_count: usize,
    pub regression_count: usize,
    pub recent_evidence_count: usize,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyHistoryRow {
    pub unix_day: i64,
    pub trace_count: usize,
    pub outcomes: RoutingAccuracyOutcomeCounts,
    pub accuracy_rate: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyIssueRow {
    pub source: &'static str,
    pub severity: &'static str,
    pub agent: Option<String>,
    pub title: String,
    pub detail: String,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyEvidenceRow {
    pub source: &'static str,
    pub agent: Option<String>,
    pub title: String,
    pub outcome: Option<String>,
    pub detail: String,
    pub evidence_refs: Vec<String>,
    pub observed_at: Option<i64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RoutingAccuracyPromptRequest {
    pub available: bool,
    pub preview_method: &'static str,
    pub confirm_method: &'static str,
    pub action: &'static str,
    pub request: LlmPreviewPromptParams,
    pub note: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct RoutingAccuracySafetyFlags {
    pub read_only: bool,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub write_actions_available: bool,
    pub skill_files_mutated: bool,
    pub agent_config_mutated: bool,
    pub script_execution_allowed: bool,
    pub execution_actions_available: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
    pub raw_trace_persisted: bool,
    pub cloud_sync_performed: bool,
    pub telemetry_emitted: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceImportRecord {
    pub id: String,
    pub title: String,
    pub source_kind: String,
    pub agent: Option<String>,
    pub task: Option<String>,
    pub expected_skill_refs: Vec<String>,
    pub expected_skill_names: Vec<String>,
    pub excerpt: String,
    pub excerpt_char_count: usize,
    #[serde(default = "trace_import_redaction_summary_default")]
    pub redaction_summary: TraceImportRedactionSummary,
    pub content_hash: String,
    pub imported_at: i64,
    pub analysis: TraceImportAnalysis,
    pub safety_flags: TraceImportSafetyFlags,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceImportRedactionSummary {
    pub status: String,
    pub redacted_value_count: usize,
    pub redacted_fields: Vec<String>,
    pub placeholders: Vec<String>,
    pub raw_trace_persisted: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
    pub raw_secret_returned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceImportAnalysis {
    pub generated_by: String,
    pub catalog_available: bool,
    pub outcome: String,
    pub reasons: Vec<String>,
    pub detected_skills: Vec<TraceDetectedSkill>,
    pub evidence_refs: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceDetectedSkill {
    pub instance_id: String,
    pub definition_id: String,
    pub skill_name: String,
    pub agent: String,
    pub scope: String,
    pub evidence_refs: Vec<String>,
    pub match_terms: Vec<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct TraceImportSafetyFlags {
    pub read_only: bool,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub write_back_allowed: bool,
    pub skill_files_mutated: bool,
    pub agent_config_mutated: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub credential_accessed: bool,
    pub raw_secret_returned: bool,
    pub raw_trace_persisted: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
    pub cloud_sync_performed: bool,
    pub telemetry_emitted: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TraceImportLocalParams {
    #[serde(default, alias = "trace_text", alias = "transcript")]
    pub content: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub source_kind: Option<String>,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub task: Option<String>,
    #[serde(default)]
    pub expected_skill_refs: Vec<String>,
    #[serde(default)]
    pub expected_skill_names: Vec<String>,
    #[serde(default)]
    pub max_excerpt_chars: Option<usize>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct TraceListImportsParams {
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TraceDeleteImportParams {
    #[serde(alias = "import_id")]
    pub id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct TraceImportLocalResult {
    pub generated_by: &'static str,
    pub import: TraceImportRecord,
    pub count: usize,
    pub app_local_only: bool,
    pub import_file: &'static str,
    pub provider_request_sent: bool,
    pub raw_trace_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TraceImportListResult {
    pub imports: Vec<TraceImportRecord>,
    pub count: usize,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub raw_trace_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct TraceDeleteImportResult {
    pub import_id: String,
    pub deleted: bool,
    pub remaining_count: usize,
    pub app_local_only: bool,
    pub provider_request_sent: bool,
    pub raw_trace_persisted: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LlmPrepareActionParams {
    pub kind: LlmActionKind,
    #[serde(default, alias = "instance_id")]
    pub skill_instance_id: Option<String>,
    #[serde(default)]
    pub user_intent: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LlmPrepareSkillAnalysisParams {
    #[serde(default)]
    pub instance_ids: Vec<String>,
    pub analysis_kind: LlmSkillAnalysisKind,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct LlmPreviewPromptParams {
    #[serde(alias = "kind")]
    pub action: LlmPromptActionKind,
    #[serde(default)]
    pub profile_id: Option<String>,
    #[serde(default, alias = "instance_id")]
    pub skill_instance_id: Option<String>,
    #[serde(default)]
    pub instance_ids: Vec<String>,
    #[serde(default)]
    pub analysis_kind: Option<LlmSkillAnalysisKind>,
    #[serde(default)]
    pub user_intent: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LlmConfirmPromptAndSendParams {
    pub preview_id: String,
    pub confirmation_id: String,
    pub request: LlmPreviewPromptParams,
    #[serde(default)]
    pub timeout_ms: Option<u64>,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmSkillAnalysisKind {
    Overview,
    Risk,
    Cleanup,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmPromptActionKind {
    Analyze,
    Recommend,
    ExplainConflict,
    DraftFrontmatter,
    SkillAnalysis,
    QualityScore,
    StaleDriftDetection,
    KnowledgeSearch,
    SimilarSkillGrouping,
    TaskReadiness,
    RoutingConfidence,
}

impl LlmPromptActionKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Analyze => "analyze",
            Self::Recommend => "recommend",
            Self::ExplainConflict => "explain_conflict",
            Self::DraftFrontmatter => "draft_frontmatter",
            Self::SkillAnalysis => "skill_analysis",
            Self::QualityScore => "quality_score",
            Self::StaleDriftDetection => "stale_drift_detection",
            Self::KnowledgeSearch => "knowledge_search",
            Self::SimilarSkillGrouping => "similar_skill_grouping",
            Self::TaskReadiness => "task_readiness",
            Self::RoutingConfidence => "routing_confidence",
        }
    }
}

impl LlmSkillAnalysisKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Overview => "overview",
            Self::Risk => "risk",
            Self::Cleanup => "cleanup",
        }
    }

    fn output_token_estimate(self) -> u32 {
        match self {
            Self::Overview => 650,
            Self::Risk => 800,
            Self::Cleanup => 700,
        }
    }
}

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmActionKind {
    Analyze,
    Recommend,
    ExplainConflict,
    DraftFrontmatter,
}

impl LlmActionKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::Analyze => "analyze",
            Self::Recommend => "recommend",
            Self::ExplainConflict => "explain_conflict",
            Self::DraftFrontmatter => "draft_frontmatter",
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmPrepareActionResult {
    pub action: &'static str,
    pub allowed: bool,
    pub reason: String,
    pub disabled_reason: Option<String>,
    pub requires_confirmation: bool,
    pub write_back_allowed: bool,
    pub draft_requires_user_copy: bool,
    pub provider: Option<String>,
    pub model: Option<String>,
    pub estimated_input_tokens: u32,
    pub estimated_output_tokens: u32,
    pub estimated_total_tokens: u32,
    pub estimated_cost_usd: f64,
    pub single_request_token_limit: u32,
    pub monthly_budget_usd: f64,
    pub credentials_storage: String,
    pub credential_persistence_allowed: bool,
    pub prompt_scope: Vec<String>,
    pub privacy_notes: Vec<String>,
    pub confirmation: LlmConfirmationRequirement,
    pub review_preview: LlmReviewPreview,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmPrepareSkillAnalysisResult {
    pub enabled: bool,
    pub disabled_reason: String,
    pub analysis_kind: &'static str,
    pub selected_skill_count: usize,
    pub included_skill_count: usize,
    pub excluded_missing_count: usize,
    pub included_skills: Vec<LlmSkillAnalysisIncludedSkill>,
    pub prompt_draft: String,
    pub summary_draft: String,
    pub safety_flags: LlmSkillAnalysisSafetyFlags,
    pub estimated_input_tokens: u32,
    pub estimated_output_tokens: u32,
    pub estimated_total_tokens: u32,
    pub provider_request_sent: bool,
    pub generated_by: &'static str,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmPreviewPromptResult {
    pub preview_id: String,
    pub status: String,
    pub allowed: bool,
    pub reason: String,
    pub action: &'static str,
    pub profile_id: Option<String>,
    pub provider: Option<String>,
    pub model: Option<String>,
    pub destination_host: Option<String>,
    pub prompt_scope: Vec<String>,
    pub included_fields: Vec<String>,
    pub excluded_fields: Vec<String>,
    pub redaction: LlmPromptRedactionSummary,
    pub prompt_preview: String,
    pub estimated_input_tokens: u32,
    pub estimated_output_tokens: u32,
    pub estimated_total_tokens: u32,
    pub estimated_cost_usd: f64,
    pub single_request_token_limit: u32,
    pub monthly_budget_usd: f64,
    pub requires_confirmation: bool,
    pub confirmation: LlmConfirmationRequirement,
    pub write_back_allowed: bool,
    pub draft_requires_user_copy: bool,
    pub provider_request_sent: bool,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmPromptRedactionSummary {
    pub status: String,
    pub redacted_value_count: usize,
    pub redacted_fields: Vec<String>,
    pub placeholders: Vec<&'static str>,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
    pub raw_secret_returned: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmConfirmPromptAndSendResult {
    pub preview_id: String,
    pub confirmation_id: String,
    pub status: String,
    pub action: &'static str,
    pub profile_id: String,
    pub provider: String,
    pub model: String,
    pub destination_host: String,
    pub provider_request_sent: bool,
    pub credential_accessed: bool,
    pub draft_output: Option<String>,
    pub draft_requires_user_copy: bool,
    pub write_back_allowed: bool,
    pub script_execution_allowed: bool,
    pub config_mutation_allowed: bool,
    pub snapshot_created: bool,
    pub triage_mutation_allowed: bool,
    pub audit: ProviderCallMetadata,
    pub raw_secret_returned: bool,
    pub raw_prompt_persisted: bool,
    pub raw_response_persisted: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmSkillAnalysisIncludedSkill {
    pub instance_id: String,
    pub name: String,
    pub agent: String,
    pub scope: String,
    pub enabled: bool,
    pub disabled_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmSkillAnalysisSafetyFlags {
    pub write_back_enabled: bool,
    pub script_execution_enabled: bool,
    pub credential_storage_enabled: bool,
    pub confirmation_required: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmConfirmationRequirement {
    pub required: bool,
    pub message: String,
    pub display_fields: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmReviewPreview {
    pub status: &'static str,
    pub generated_by: &'static str,
    pub provider_request_sent: bool,
    pub write_actions_available: bool,
    pub execution_actions_available: bool,
    pub purpose: String,
    pub risk: LlmReviewRisk,
    pub finding_explanations: Vec<LlmReviewFindingExplanation>,
    pub cross_agent_fit: LlmReviewCrossAgentFit,
    pub redaction: LlmReviewRedaction,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmReviewRisk {
    pub level: &'static str,
    pub summary: String,
    pub signals: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmReviewFindingExplanation {
    pub rule_id: String,
    pub severity: String,
    pub explanation: String,
    pub suggested_next_step: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmReviewCrossAgentFit {
    pub agent: String,
    pub scope: String,
    pub comparable_instance_count: usize,
    pub summary: String,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LlmReviewRedaction {
    pub skill_body_returned: bool,
    pub paths_returned: bool,
    pub credentials_returned: bool,
    pub included_fields: Vec<&'static str>,
    pub excluded_fields: Vec<&'static str>,
}

impl LlmReviewPreview {
    fn unavailable() -> Self {
        Self {
            status: "unavailable",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose: "No catalog record was available for offline AI review preparation."
                .to_string(),
            risk: LlmReviewRisk {
                level: "unknown",
                summary:
                    "Risk was not assessed because the selected catalog record was unavailable."
                        .to_string(),
                signals: Vec::new(),
            },
            finding_explanations: Vec::new(),
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: "unknown".to_string(),
                scope: "unknown".to_string(),
                comparable_instance_count: 0,
                summary: "Cross-agent fit was not assessed.".to_string(),
                notes: Vec::new(),
            },
            redaction: llm_review_redaction(),
        }
    }
}

#[derive(Debug, Clone, Copy)]
struct ScanActivityCounts {
    scanned_count: usize,
    skill_count: usize,
    finding_count: usize,
    conflict_count: usize,
    snapshot_count: usize,
}

#[derive(Debug, Clone, Deserialize)]
pub struct GetSkillParams {
    pub instance_id: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ListSkillEventsParams {
    pub instance_id: String,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SetFindingTriageParams {
    pub triage_key: String,
    pub status: String,
    #[serde(default)]
    pub note: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ClearFindingTriageParams {
    pub triage_key: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RuleTuningScopeParams {
    pub rule_id: String,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SetSeverityOverrideParams {
    pub rule_id: String,
    pub severity: String,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SetSuppressionParams {
    pub rule_id: String,
    pub reason: String,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ToggleSkillParams {
    pub instance_id: String,
    pub on: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct BatchPreviewSkillTogglesParams {
    pub instance_ids: Vec<String>,
    #[serde(alias = "on", alias = "enabled")]
    pub target_enabled: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct BatchApplySkillTogglesParams {
    pub instance_ids: Vec<String>,
    #[serde(alias = "on", alias = "enabled")]
    pub target_enabled: bool,
    pub preview_token: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct PiWritableHarnessParams {
    #[serde(default)]
    pub run_label: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct InstallSkillParams {
    pub instance_id: String,
    pub target_agent: String,
    pub target_scope: String,
    #[serde(default)]
    pub project_path: Option<PathBuf>,
    #[serde(default)]
    pub confirmed: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SnapshotParams {
    pub snapshot_id: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ListAgentConfigSnapshotsParams {
    pub agent: String,
    #[serde(default)]
    pub scope: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SaveClaudeSettingsParams {
    pub content: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ExportSkillBundleParams {
    #[serde(default)]
    pub instance_id: Option<String>,
    #[serde(default)]
    pub source_path: Option<PathBuf>,
    #[serde(default)]
    pub output_dir: Option<PathBuf>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ImportSkillParams {
    #[serde(default)]
    pub source_path: Option<String>,
    #[serde(default)]
    pub github_url: Option<String>,
}

#[derive(Debug, Error)]
pub enum ServiceError {
    #[error("invalid request: {0}")]
    InvalidRequest(String),
    #[error("unknown method: {0}")]
    UnknownMethod(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("catalog error: {0}")]
    Catalog(#[from] skills_copilot_catalog::CatalogError),
    #[error("command error: {0}")]
    Command(#[from] skills_copilot_commands::CommandError),
    #[error("provider error: {0}")]
    Provider(#[from] ProviderError),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("skill instance not found: {0}")]
    SkillNotFound(String),
    #[error("confirmation required: {0}")]
    ConfirmationRequired(String),
}

impl ServiceError {
    fn code(&self) -> &'static str {
        match self {
            Self::InvalidRequest(_) => "invalid_request",
            Self::UnknownMethod(_) => "unknown_method",
            Self::Io(_) => "io_error",
            Self::Catalog(_) => "catalog_error",
            Self::Command(_) => "command_error",
            Self::Provider(_) => "provider_error",
            Self::Json(_) => "json_error",
            Self::SkillNotFound(_) => "skill_not_found",
            Self::ConfirmationRequired(_) => "confirmation_required",
        }
    }
}

#[derive(Debug, Clone)]
pub struct ServiceHost {
    pub app_data_dir: PathBuf,
    pub adapter_ctx: AdapterContext,
}

impl ServiceHost {
    pub fn from_env() -> Result<Self, ServiceError> {
        let user_home = env::var_os("SKILLS_COPILOT_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(PathBuf::from))
            .ok_or_else(|| ServiceError::InvalidRequest("HOME is not set".to_string()))?;
        let app_data_dir = env::var_os("SKILLS_COPILOT_APP_DATA_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| default_app_data_dir(&user_home));
        let project_cwd = env::var_os("SKILLS_COPILOT_PROJECT_CWD").map(PathBuf::from);
        let project_root = env::var_os("SKILLS_COPILOT_PROJECT_ROOT")
            .map(PathBuf::from)
            .or_else(|| project_cwd.as_deref().map(infer_project_root));
        let adapter_ctx = AdapterContext {
            user_home,
            project_root: project_root.clone(),
            project_cwd: project_cwd.or(project_root),
            extra_roots: extra_claude_roots_from_env(),
        };
        Ok(Self {
            app_data_dir,
            adapter_ctx,
        })
    }

    pub fn handle(&self, request: ServiceRequest) -> ServiceResponse {
        let id = request.id.clone();
        match self.handle_result(request) {
            Ok(result) => ServiceResponse {
                id,
                ok: true,
                result: Some(result),
                error: None,
            },
            Err(error) => ServiceResponse {
                id,
                ok: false,
                result: None,
                error: Some(ServiceErrorRecord {
                    code: error.code().to_string(),
                    message: error.to_string(),
                }),
            },
        }
    }

    fn handle_result(&self, request: ServiceRequest) -> Result<Value, ServiceError> {
        match request.method.as_str() {
            "app.version" => serde_json::to_value(self.app_version()).map_err(Into::into),
            "app.stateSnapshot" => {
                serde_json::to_value(self.app_state_snapshot()?).map_err(Into::into)
            }
            "service.status" => serde_json::to_value(self.status()).map_err(Into::into),
            "adapter.listCapabilities" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                serde_json::to_value(list_adapter_capabilities(&adapter_ctx)).map_err(Into::into)
            }
            "adapter.listDiagnostics" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                serde_json::to_value(list_adapter_diagnostics(&adapter_ctx)).map_err(Into::into)
            }
            "evidence.piWritableHarness" => {
                let params: PiWritableHarnessParams = if request.params.is_null() {
                    PiWritableHarnessParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                let report: PiWritableHarnessReport =
                    run_pi_writable_evidence_harness(&self.pi_writable_harness_root(params))?;
                serde_json::to_value(report).map_err(Into::into)
            }
            "analysis.scoreSkillQuality" => {
                let params: ScoreSkillQualityParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.score_skill_quality(params)?).map_err(Into::into)
            }
            "analysis.detectStaleDrift" => {
                let params: DetectStaleDriftParams = if request.params.is_null() {
                    DetectStaleDriftParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.detect_stale_drift(params)?).map_err(Into::into)
            }
            "knowledge.search" => {
                let params: KnowledgeSearchParams = if request.params.is_null() {
                    KnowledgeSearchParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.search_knowledge(params)?).map_err(Into::into)
            }
            "knowledge.groupSimilarSkills" => {
                let params: SimilarSkillGroupingParams = if request.params.is_null() {
                    SimilarSkillGroupingParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.group_similar_skills(params)?).map_err(Into::into)
            }
            "task.checkReadiness" => {
                let params: TaskReadinessParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.check_task_readiness(params)?).map_err(Into::into)
            }
            "task.rankSkillRoutes" => {
                let params: RankSkillRoutesParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.rank_skill_routes(params)?).map_err(Into::into)
            }
            "task.compareAgentReadiness" => {
                let params: CompareAgentReadinessParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.compare_agent_readiness(params)?).map_err(Into::into)
            }
            "task.listBenchmarks" => {
                let params: ListTaskBenchmarksParams = if request.params.is_null() {
                    ListTaskBenchmarksParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_task_benchmarks(params)?).map_err(Into::into)
            }
            "task.saveBenchmark" => {
                let params: SaveTaskBenchmarkParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.save_task_benchmark(params)?).map_err(Into::into)
            }
            "task.deleteBenchmark" => {
                let params: DeleteTaskBenchmarkParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_task_benchmark(params)?).map_err(Into::into)
            }
            "task.evaluateBenchmarks" => {
                let params: EvaluateTaskBenchmarksParams = if request.params.is_null() {
                    EvaluateTaskBenchmarksParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.evaluate_task_benchmarks(params)?).map_err(Into::into)
            }
            "task.saveRoutingBaseline" => {
                let params: SaveRoutingBaselineParams = if request.params.is_null() {
                    SaveRoutingBaselineParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.save_routing_baseline(params)?).map_err(Into::into)
            }
            "task.detectRoutingRegression" => {
                let params: DetectRoutingRegressionParams = if request.params.is_null() {
                    DetectRoutingRegressionParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.detect_routing_regression(params)?).map_err(Into::into)
            }
            "routing.accuracyDashboard" => {
                let params: RoutingAccuracyDashboardParams = if request.params.is_null() {
                    RoutingAccuracyDashboardParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.routing_accuracy_dashboard(params)?).map_err(Into::into)
            }
            "trace.importLocal" => {
                let params: TraceImportLocalParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.import_local_trace(params)?).map_err(Into::into)
            }
            "trace.listImports" => {
                let params: TraceListImportsParams = if request.params.is_null() {
                    TraceListImportsParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_trace_imports(params)?).map_err(Into::into)
            }
            "trace.deleteImport" => {
                let params: TraceDeleteImportParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_trace_import(params)?).map_err(Into::into)
            }
            "llm.status" => serde_json::to_value(self.llm_status()).map_err(Into::into),
            "llm.listProviderProfiles" => {
                serde_json::to_value(self.list_llm_provider_profiles()?).map_err(Into::into)
            }
            "llm.saveProviderProfile" => {
                let params: SaveProviderProfileParams = serde_json::from_value(request.params)?;
                serde_json::to_value(save_provider_profile(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.deleteProviderProfile" => {
                let params: DeleteProviderProfileParams = serde_json::from_value(request.params)?;
                serde_json::to_value(delete_provider_profile(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.testProviderConnection" => {
                let params: TestProviderConnectionParams = serde_json::from_value(request.params)?;
                serde_json::to_value(test_provider_connection(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.previewPrompt" => {
                let params: LlmPreviewPromptParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.preview_llm_prompt(params)?).map_err(Into::into)
            }
            "llm.confirmPromptAndSend" => {
                let params: LlmConfirmPromptAndSendParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.confirm_llm_prompt_and_send(params)?).map_err(Into::into)
            }
            "llm.prepareAction" => {
                let params: LlmPrepareActionParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.prepare_llm_action(params)?).map_err(Into::into)
            }
            "llm.prepareSkillAnalysis" => {
                let params: LlmPrepareSkillAnalysisParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.prepare_llm_skill_analysis(params)?).map_err(Into::into)
            }
            "cleanup.listQueue" => {
                let params: CleanupListQueueParams = if request.params.is_null() {
                    CleanupListQueueParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.cleanup_list_queue(params)?).map_err(Into::into)
            }
            "comparison.listCrossAgent" => {
                let params: ListCrossAgentComparisonParams = if request.params.is_null() {
                    ListCrossAgentComparisonParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                let Some(catalog) = self.open_existing_catalog_read_only()? else {
                    return serde_json::to_value(empty_cross_agent_comparison(
                        params.selected_instance_id.as_deref(),
                    ))
                    .map_err(Into::into);
                };
                let adapter_ctx = self.effective_adapter_ctx()?;
                let comparisons: CrossAgentComparisonRecord = list_cross_agent_comparisons(
                    &catalog,
                    &adapter_ctx,
                    params.selected_instance_id.as_deref(),
                    params.agent.as_deref(),
                    params.query.as_deref(),
                    params.limit,
                )?;
                serde_json::to_value(comparisons).map_err(Into::into)
            }
            "report.exportLocal" => {
                let params: ReportExportLocalParams = if request.params.is_null() {
                    ReportExportLocalParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.export_local_report(params)?).map_err(Into::into)
            }
            "rules.listTuning" => {
                let catalog = self.open_catalog()?;
                let tuning: Vec<RuleTuningRecord> = list_rule_tuning(&catalog)?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.setSeverityOverride" => {
                let params: SetSeverityOverrideParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let tuning: RuleTuningRecord = set_rule_severity_override(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                    &params.severity,
                )?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.clearSeverityOverride" => {
                let params: RuleTuningScopeParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_rule_severity_override(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                )?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "rules.setSuppression" => {
                let params: SetSuppressionParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let tuning: RuleTuningRecord = set_rule_suppression(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                    &params.reason,
                    params.note.as_deref(),
                )?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.clearSuppression" => {
                let params: RuleTuningScopeParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_rule_suppression(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                )?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "batch.previewSkillToggles" => {
                let params: BatchPreviewSkillTogglesParams =
                    serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let preview: BatchTogglePreviewRecord = preview_skill_toggles(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_ids,
                    params.target_enabled,
                )?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "batch.applySkillToggles" => {
                let params: BatchApplySkillTogglesParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let applied: BatchToggleApplyRecord = apply_skill_toggles(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_ids,
                    params.target_enabled,
                    &params.preview_token,
                )?;
                serde_json::to_value(applied).map_err(Into::into)
            }
            "script.previewExecution" => {
                let params: ScriptExecutionRequest = serde_json::from_value(request.params)?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let preview: ScriptExecutionPreviewRecord =
                    preview_script_execution(&adapter_ctx, &params)?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "script.execute" => {
                let params: ScriptExecutionRequest = serde_json::from_value(request.params)?;
                if !params.confirmed {
                    return Err(ServiceError::ConfirmationRequired(
                        "script.execute requires confirmed=true on each request; use script.previewExecution to inspect the command, cwd, env, network, files, risks, and confirmation fields before confirming.".to_string(),
                    ));
                }
                let adapter_ctx = self.effective_adapter_ctx()?;
                let attempt: ScriptExecutionAttemptRecord = record_blocked_script_execution(
                    &adapter_ctx,
                    &self.script_execution_audit_path(),
                    &params,
                )?;
                serde_json::to_value(attempt).map_err(Into::into)
            }
            "project.getContext" => {
                let state: ProjectContextState = load_project_context_state(&self.app_data_dir)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.setContext" => {
                let params: ProjectContextParams = serde_json::from_value(request.params)?;
                let state: ProjectContextState = set_project_context(&self.app_data_dir, params)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.clearContext" => {
                let state: ProjectContextState = clear_project_context(&self.app_data_dir)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.validateContext" => {
                let params: ProjectContextParams = serde_json::from_value(request.params)?;
                let context: ProjectContext = validate_project_context_for_response(params);
                serde_json::to_value(context).map_err(Into::into)
            }
            "catalog.listSkills" => {
                let catalog = self.open_catalog()?;
                serde_json::to_value(self.list_visible_skill_records(&catalog)?).map_err(Into::into)
            }
            "catalog.getSkill" => {
                let params: GetSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let detail: SkillDetailRecord = get_skill(&catalog, &params.instance_id)?;
                serde_json::to_value(detail).map_err(Into::into)
            }
            "catalog.analysis" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let analysis: CrossAgentAnalysisRecord = analyze_catalog(&catalog, &adapter_ctx)?;
                serde_json::to_value(analysis).map_err(Into::into)
            }
            "skill.listEvents" => {
                let params: ListSkillEventsParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let events: Vec<SkillEventRecord> =
                    list_skill_events(&catalog, &params.instance_id, params.limit)?;
                serde_json::to_value(events).map_err(Into::into)
            }
            "catalog.listFindings" => {
                let catalog = self.open_catalog()?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                serde_json::to_value(findings).map_err(Into::into)
            }
            "catalog.listFindingTriage" => {
                let catalog = self.open_catalog()?;
                let triage: Vec<FindingTriageRecord> = list_finding_triage(&catalog)?;
                serde_json::to_value(triage).map_err(Into::into)
            }
            "catalog.setFindingTriage" => {
                let params: SetFindingTriageParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let triage: FindingTriageRecord = set_finding_triage(
                    &catalog,
                    &params.triage_key,
                    &params.status,
                    params.note.as_deref(),
                )?;
                serde_json::to_value(triage).map_err(Into::into)
            }
            "catalog.clearFindingTriage" => {
                let params: ClearFindingTriageParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_finding_triage(&catalog, &params.triage_key)?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "catalog.listConflicts" => {
                let catalog = self.open_catalog()?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                serde_json::to_value(conflicts).map_err(Into::into)
            }
            "catalog.importSkill" => {
                let params: ImportSkillParams = serde_json::from_value(request.params)?;
                if let Some(github_url) = params.github_url.as_deref() {
                    import_github_skill_to_tool_global_deferred(github_url)?;
                }
                let source_path = params.source_path.ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "catalog.importSkill requires source_path for local imports".to_string(),
                    )
                })?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let result: ToolGlobalImportResult = import_local_skill_to_tool_global(
                    &catalog,
                    &adapter_ctx,
                    &self.tool_global_staging_root(),
                    Path::new(&source_path),
                )?;
                serde_json::to_value(result).map_err(Into::into)
            }
            "catalog.scanClaude" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let started_at = unix_timestamp_millis();
                let scanned_count = scan_claude_to_catalog(&adapter_ctx, &catalog)?;
                let skills = self.list_visible_skill_records(&catalog)?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                let activity = self.scan_activity(
                    "catalog.scanClaude",
                    "Claude Code",
                    self.claude_root_paths(),
                    started_at,
                    ScanActivityCounts {
                        scanned_count,
                        skill_count: skills.len(),
                        finding_count: findings.len(),
                        conflict_count: conflicts.len(),
                        snapshot_count: snapshots.len(),
                    },
                    None,
                );
                serde_json::to_value(ScanResult {
                    scanned_count,
                    skills,
                    activity,
                })
                .map_err(Into::into)
            }
            "catalog.scanAll" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let started_at = unix_timestamp_millis();
                let scan_report = scan_all_catalog_report(&adapter_ctx, &catalog)?;
                let scanned_count = scan_report.scanned_count;
                let skills = self.list_visible_skill_records(&catalog)?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
                let agent_summaries = self.agent_refresh_summaries(
                    &scan_report.agents,
                    &skills,
                    &adapter_diagnostics,
                );
                let roots = scan_report
                    .agents
                    .iter()
                    .flat_map(|agent| agent.roots_considered.iter().cloned())
                    .collect();
                let scan_label = scan_all_label(&scan_report.agents);
                let activity = self.scan_activity(
                    "catalog.scanAll",
                    &scan_label,
                    roots,
                    started_at,
                    ScanActivityCounts {
                        scanned_count,
                        skill_count: skills.len(),
                        finding_count: findings.len(),
                        conflict_count: conflicts.len(),
                        snapshot_count: snapshots.len(),
                    },
                    Some(agent_summaries),
                );
                serde_json::to_value(ScanResult {
                    scanned_count,
                    skills,
                    activity,
                })
                .map_err(Into::into)
            }
            "skill.exportBundle" => {
                let params: ExportSkillBundleParams = serde_json::from_value(request.params)?;
                let output_dir = params
                    .output_dir
                    .unwrap_or_else(|| self.app_data_dir.join("exports"));
                let exported: ExportedSkillBundle =
                    match (params.instance_id.as_deref(), params.source_path.as_deref()) {
                        (Some(instance_id), None) => {
                            let catalog = self.open_catalog()?;
                            export_skill_bundle(&catalog, instance_id, &output_dir)?
                        }
                        (None, Some(source_path)) => {
                            export_staging_skill_bundle(source_path, &output_dir)?
                        }
                        _ => {
                            return Err(ServiceError::InvalidRequest(
                            "skill.exportBundle requires exactly one of instance_id or source_path"
                                .to_string(),
                        ));
                        }
                    };
                serde_json::to_value(exported).map_err(Into::into)
            }
            "config.toggleSkill" => {
                let params: ToggleSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let record: SkillRecord =
                    toggle_skill(&catalog, &adapter_ctx, &params.instance_id, params.on)?;
                serde_json::to_value(record).map_err(Into::into)
            }
            "skill.install" => {
                let params: InstallSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let target_agent = parse_agent_param(&params.target_agent)?;
                let target_scope = parse_scope_param(&params.target_scope)?;
                let preview: SkillInstallPreviewRecord = install_skill_from_tool_global(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_id,
                    target_agent,
                    target_scope,
                    params.project_path.as_deref(),
                    params.confirmed,
                )?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "config.readClaudeSettings" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                let document: ConfigDocumentRecord = read_claude_settings(&adapter_ctx)?;
                serde_json::to_value(document).map_err(Into::into)
            }
            "config.saveClaudeSettings" => {
                let params: SaveClaudeSettingsParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let document: ConfigDocumentRecord =
                    save_claude_settings(&catalog, &adapter_ctx, &params.content)?;
                serde_json::to_value(document).map_err(Into::into)
            }
            "snapshot.list" => {
                let catalog = self.open_catalog()?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                serde_json::to_value(snapshots).map_err(Into::into)
            }
            "snapshot.listAgentConfig" => {
                let params: ListAgentConfigSnapshotsParams =
                    serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let scope = params.scope.as_deref().filter(|scope| !scope.is_empty());
                let snapshots: Vec<ConfigSnapshotRecord> =
                    list_agent_config_snapshots(&catalog, &params.agent, scope)?;
                serde_json::to_value(snapshots).map_err(Into::into)
            }
            "snapshot.previewRollback" => {
                let params: SnapshotParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let preview: SnapshotRollbackPreviewRecord =
                    preview_snapshot_rollback(&catalog, &params.snapshot_id)?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "snapshot.rollback" => {
                let params: SnapshotParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let scanned_count = rollback_snapshot(&catalog, &adapter_ctx, &params.snapshot_id)?;
                serde_json::to_value(scanned_count).map_err(Into::into)
            }
            method => Err(ServiceError::UnknownMethod(method.to_string())),
        }
    }

    pub fn app_version(&self) -> AppVersion {
        AppVersion {
            protocol_version: SERVICE_PROTOCOL_VERSION,
            version: skills_copilot_commands::app_version(),
        }
    }

    pub fn app_state_snapshot(&self) -> Result<AppStateSnapshot, ServiceError> {
        let catalog = self.open_catalog()?;
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let health = skill_health_summary(&catalog, &adapter_ctx)?;
        Ok(AppStateSnapshot {
            status: self.status(),
            skills,
            findings,
            conflicts,
            analysis,
            health,
            snapshots: list_snapshots(&catalog)?,
        })
    }

    pub fn cleanup_list_queue(
        &self,
        params: CleanupListQueueParams,
    ) -> Result<CleanupQueue, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(cleanup_queue_response(Vec::new(), params.limit));
        };
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let mut items = Vec::new();

        let skill_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        let skills_by_definition = skills.iter().fold(
            BTreeMap::<&str, Vec<&SkillRecord>>::new(),
            |mut by_definition, skill| {
                by_definition
                    .entry(skill.definition_id.as_str())
                    .or_default()
                    .push(skill);
                by_definition
            },
        );

        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if matches!(skill.state.as_str(), "broken" | "missing") {
                let severity = if skill.state == "missing" {
                    "error"
                } else {
                    "critical"
                };
                items.push(CleanupQueueItem {
                    id: format!("cleanup:integrity:{}:{}", skill.state, skill.id),
                    kind: "integrity".to_string(),
                    severity: severity.to_string(),
                    priority: priority_for(severity).to_string(),
                    agent: Some(skill.agent.clone()),
                    scope: Some(skill.scope.clone()),
                    skill_id: Some(skill.id.clone()),
                    definition_id: Some(skill.definition_id.clone()),
                    skill_name: Some(skill.name.clone()),
                    title: format!("{} skill record: {}", skill.state, skill.name),
                    detail: "This catalog row is not currently loaded cleanly. Inspect the source and rescan before relying on it.".to_string(),
                    recommended_next_action_label: "Inspect skill details".to_string(),
                    source_id: skill.id.clone(),
                    read_only: true,
                    writes_allowed: false,
                    provider_request_sent: false,
                });
            }
        }

        for conflict in &conflicts {
            let members = conflict
                .instance_ids
                .iter()
                .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                .collect::<Vec<_>>();
            if let Some(agent) = agent_filter {
                let matching_member_count =
                    members.iter().filter(|skill| skill.agent == agent).count();
                if matching_member_count < 2 {
                    continue;
                }
            }
            let first = members.first().copied();
            items.push(CleanupQueueItem {
                id: format!("cleanup:conflict:{}", conflict.id),
                kind: "conflict".to_string(),
                severity: "error".to_string(),
                priority: "high".to_string(),
                agent: first.map(|skill| skill.agent.clone()),
                scope: first.map(|skill| skill.scope.clone()),
                skill_id: conflict
                    .winner_id
                    .clone()
                    .or_else(|| first.map(|skill| skill.id.clone())),
                definition_id: Some(conflict.definition_id.clone()),
                skill_name: first.map(|skill| skill.name.clone()),
                title: format!("Same-agent conflict: {}", conflict.reason),
                detail: format!(
                    "{} skill records share a runtime conflict for definition {}.",
                    conflict.instance_ids.len(),
                    conflict.definition_id
                ),
                recommended_next_action_label: "Review conflict details".to_string(),
                source_id: conflict.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        for finding in &findings {
            if finding.triage_status == "ignored" || finding.suppressed {
                continue;
            }
            let skill = finding
                .instance_id
                .as_deref()
                .and_then(|instance_id| skill_by_id.get(instance_id).copied())
                .or_else(|| {
                    finding
                        .definition_id
                        .as_deref()
                        .and_then(|definition_id| skills_by_definition.get(definition_id))
                        .and_then(|skills| skills.first().copied())
                });
            if !agent_matches(agent_filter, skill.map(|skill| skill.agent.as_str())) {
                continue;
            }
            items.push(CleanupQueueItem {
                id: format!("cleanup:finding:{}", finding.id),
                kind: "finding".to_string(),
                severity: finding.effective_severity.clone(),
                priority: priority_for(&finding.effective_severity).to_string(),
                agent: skill.map(|skill| skill.agent.clone()),
                scope: skill.map(|skill| skill.scope.clone()),
                skill_id: finding
                    .instance_id
                    .clone()
                    .or_else(|| skill.map(|skill| skill.id.clone())),
                definition_id: finding.definition_id.clone(),
                skill_name: skill.map(|skill| skill.name.clone()),
                title: format!("{} finding: {}", finding.rule_id, finding.message),
                detail: finding.suggestion.clone().unwrap_or_else(|| {
                    "Review this rule finding before relying on the skill.".to_string()
                }),
                recommended_next_action_label: "Review finding".to_string(),
                source_id: finding.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        for group in &analysis.groups {
            if let Some(agent) = agent_filter {
                if !group.agents.iter().any(|group_agent| group_agent == agent) {
                    continue;
                }
            }
            let first = group
                .instance_ids
                .iter()
                .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                .find(|skill| agent_matches(agent_filter, Some(skill.agent.as_str())))
                .or_else(|| {
                    group
                        .instance_ids
                        .iter()
                        .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                        .next()
                });
            items.push(CleanupQueueItem {
                id: format!("cleanup:analysis:{}", group.id),
                kind: "analysis".to_string(),
                severity: group.severity.clone(),
                priority: priority_for(&group.severity).to_string(),
                agent: first.map(|skill| skill.agent.clone()),
                scope: first.map(|skill| skill.scope.clone()),
                skill_id: first.map(|skill| skill.id.clone()),
                definition_id: None,
                skill_name: group
                    .canonical_name
                    .clone()
                    .or_else(|| first.map(|skill| skill.name.clone())),
                title: group.title.clone(),
                detail: group.explanation.clone(),
                recommended_next_action_label: "Inspect analysis insight".to_string(),
                source_id: group.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        Ok(cleanup_queue_response(items, params.limit))
    }

    pub fn export_local_report(
        &self,
        params: ReportExportLocalParams,
    ) -> Result<ReportExportLocalResult, ServiceError> {
        let generated_at = unix_timestamp_millis();
        let export_id = format!("local-report-{generated_at}");
        let output_dir = self.app_data_dir.join("report-exports").join(&export_id);
        fs::create_dir_all(&output_dir)?;

        let formats = report_export_formats(params.formats);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let catalog = self.open_existing_catalog_read_only()?;
        let catalog_available = catalog.is_some();

        let (skills, findings, triage, conflicts, health, analysis, cleanup, comparison) =
            if let Some(catalog) = catalog.as_ref() {
                let skills = self.list_visible_skill_records(catalog)?;
                let findings = list_findings(catalog)?;
                let triage = list_finding_triage(catalog)?;
                let conflicts = list_conflicts(catalog)?;
                let health = serde_json::to_value(skill_health_summary(catalog, &adapter_ctx)?)?;
                let analysis = serde_json::to_value(analyze_catalog(catalog, &adapter_ctx)?)?;
                let cleanup = self.cleanup_list_queue(CleanupListQueueParams::default())?;
                let comparison = list_cross_agent_comparisons(
                    catalog,
                    &adapter_ctx,
                    None,
                    None,
                    None,
                    Some(50),
                )?;
                (
                    serde_json::to_value(skills)?,
                    serde_json::to_value(findings)?,
                    serde_json::to_value(triage)?,
                    serde_json::to_value(conflicts)?,
                    health,
                    analysis,
                    serde_json::to_value(cleanup)?,
                    serde_json::to_value(comparison)?,
                )
            } else {
                (
                    Value::Array(Vec::new()),
                    Value::Array(Vec::new()),
                    Value::Array(Vec::new()),
                    Value::Array(Vec::new()),
                    empty_health_summary_json(),
                    serde_json::to_value(empty_cross_agent_analysis_json())?,
                    serde_json::to_value(cleanup_queue_response(Vec::new(), None))?,
                    serde_json::to_value(empty_cross_agent_comparison(None))?,
                )
            };

        let summary = report_export_summary(&skills, &findings, &triage, &cleanup, &comparison);
        let mut report = json!({
            "schema_version": 1,
            "export_id": export_id,
            "generated_at": generated_at,
            "catalog_available": catalog_available,
            "safety": {
                "read_only": true,
                "writes_allowed": false,
                "provider_request_sent": false,
                "script_execution_allowed": false,
                "credential_accessed": false,
                "scope": "local-redacted-report-export"
            },
            "redaction": report_export_redaction(),
            "summary": summary.clone(),
            "agent_coverage": {
                "status": self.status(),
                "skills": skills
            },
            "health": health,
            "findings": {
                "open_groups": findings,
                "triage": triage,
                "conflicts": conflicts
            },
            "cleanup_queue": cleanup,
            "cross_agent": {
                "analysis": analysis,
                "comparison": comparison
            }
        });
        redact_report_value(&mut report, &self.redaction_roots(&adapter_ctx));

        let mut files = Vec::new();
        for format in formats {
            let path = output_dir.join(format!("report.{}", format.extension()));
            match format {
                ReportExportFormat::Json => {
                    let content = serde_json::to_string_pretty(&report)?;
                    fs::write(&path, content)?;
                }
                ReportExportFormat::Markdown => {
                    fs::write(&path, render_report_markdown(&report))?;
                }
            }
            files.push(ReportExportedFile {
                format: format.label(),
                path: redact_path_string(&path, &self.redaction_roots(&adapter_ctx)),
            });
        }

        Ok(ReportExportLocalResult {
            export_id,
            generated_at,
            output_dir: redact_path_string(&output_dir, &self.redaction_roots(&adapter_ctx)),
            files,
            catalog_available,
            summary,
            redaction: report_export_redaction(),
            read_only: true,
            writes_allowed: false,
            provider_request_sent: false,
            script_execution_allowed: false,
            credential_accessed: false,
        })
    }

    fn list_visible_skill_records(
        &self,
        catalog: &Catalog,
    ) -> Result<Vec<SkillRecord>, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills =
            catalog.list_skill_records_for_project_context(adapter_ctx.project_root.as_deref())?;
        Ok(skills
            .into_iter()
            .filter(|skill| !is_pi_plain_markdown_catalog_noise(skill))
            .collect())
    }

    pub fn status(&self) -> ServiceStatus {
        let adapter_ctx = self.status_adapter_ctx();
        ServiceStatus {
            protocol_version: SERVICE_PROTOCOL_VERSION,
            version: skills_copilot_commands::app_version(),
            app_data_dir: display_path(&self.app_data_dir),
            catalog_path: display_path(&self.catalog_path()),
            user_home: display_path(&adapter_ctx.user_home),
            supported_methods: supported_methods(),
            refresh: RefreshStatus {
                scan_progress: "summary-only",
                watcher_state: "manual-refresh",
                watcher_detail: "The current stdio sidecar reports completed refresh summaries; native automatic watcher events are not running in this process.",
                recovery_actions: vec!["Retry the last refresh", "Run Scan to rebuild the agent catalog"],
            },
            project_context: project_context_summary(&self.app_data_dir, self.env_project_context()),
            adapter_capabilities: list_adapter_capabilities(&adapter_ctx),
            adapter_diagnostics: list_adapter_diagnostics(&adapter_ctx),
            llm: self.llm_status(),
            trace_imports: self.trace_import_status(),
            script_execution: self.script_execution_status(),
        }
    }

    fn pi_writable_harness_root(&self, params: PiWritableHarnessParams) -> PathBuf {
        let label = params
            .run_label
            .as_deref()
            .map(sanitize_harness_label)
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| format!("run-{}", unix_timestamp_millis()));
        self.app_data_dir
            .join("evidence")
            .join("pi-writable-harness")
            .join(label)
    }

    pub fn llm_status(&self) -> LlmStatus {
        let profiles = self.list_llm_provider_profiles().ok();
        let default_profile = profiles.as_ref().and_then(|profiles| {
            profiles
                .default_profile_id
                .as_ref()
                .and_then(|default_id| {
                    profiles
                        .profiles
                        .iter()
                        .find(|profile| profile.id == *default_id)
                })
                .or_else(|| profiles.profiles.iter().find(|profile| profile.enabled))
        });
        let configured = default_profile
            .is_some_and(|profile| profile.enabled && profile.credential_status.secret_available);
        let profile_count = profiles
            .as_ref()
            .map(|profiles| profiles.profiles.len())
            .unwrap_or(0);
        let reason = match default_profile {
            Some(profile) if configured => {
                format!(
                    "Provider profile `{}` is configured; provider calls remain user-triggered and confirmation-gated.",
                    profile.id
                )
            }
            Some(profile) if !profile.enabled => {
                format!("Provider profile `{}` exists but is disabled.", profile.id)
            }
            Some(profile) => format!(
                "Provider profile `{}` exists but its API key is unavailable from the OS credential store.",
                profile.id
            ),
            None if profile_count > 0 => {
                "Provider profiles exist, but none is enabled as the default provider.".to_string()
            }
            None => "LLM actions are disabled by default; no local provider is configured."
                .to_string(),
        };
        LlmStatus {
            enabled: configured,
            configured,
            provider: default_profile.map(|profile| profile.provider_type.as_str().to_string()),
            model: default_profile.map(|profile| profile.model.clone()),
            reason,
            single_request_token_limit: default_profile
                .map(|profile| profile.single_request_token_limit)
                .unwrap_or_else(default_token_limit),
            monthly_budget_usd: default_profile
                .map(|profile| profile.monthly_budget_usd)
                .unwrap_or_else(default_monthly_budget_usd),
            credentials_storage: if profile_count == 0 {
                "none".to_string()
            } else {
                "keychain".to_string()
            },
            credential_persistence_allowed: profile_count > 0,
            provider_profile_count: profile_count,
            default_profile_id: default_profile.map(|profile| profile.id.clone()),
            profiles_path: display_path(&provider_profiles_path(&self.app_data_dir)),
            call_metadata_path: display_path(&provider_call_metadata_path(&self.app_data_dir)),
            raw_prompt_persistence_allowed: false,
            raw_response_persistence_allowed: false,
        }
    }

    pub fn trace_import_status(&self) -> TraceImportStatus {
        TraceImportStatus {
            count: self
                .load_trace_imports()
                .map(|imports| imports.len())
                .unwrap_or_default(),
            imports_path: display_path(&self.trace_imports_path()),
            app_local_only: true,
            raw_trace_persistence_allowed: false,
            provider_request_allowed: false,
        }
    }

    fn list_llm_provider_profiles(&self) -> Result<ListProviderProfilesResult, ServiceError> {
        list_provider_profiles(&self.app_data_dir).map_err(Into::into)
    }

    pub fn preview_llm_prompt(
        &self,
        params: LlmPreviewPromptParams,
    ) -> Result<LlmPreviewPromptResult, ServiceError> {
        let profile = self.resolve_llm_prompt_profile(params.profile_id.as_deref())?;
        let built = self.build_llm_prompt(&params)?;
        let provider = profile
            .as_ref()
            .map(|profile| profile.provider_type.as_str().to_string());
        let model = profile.as_ref().map(|profile| profile.model.clone());
        let profile_id = profile.as_ref().map(|profile| profile.id.clone());
        let destination_host = profile
            .as_ref()
            .map(|profile| destination_host_for_url(&profile.base_url));
        let single_request_token_limit = profile
            .as_ref()
            .map(|profile| profile.single_request_token_limit)
            .unwrap_or_else(default_token_limit);
        let monthly_budget_usd = profile
            .as_ref()
            .map(|profile| profile.monthly_budget_usd)
            .unwrap_or_else(default_monthly_budget_usd);
        let estimated_input_tokens = estimate_tokens(&[&built.prompt_preview]);
        let estimated_output_tokens = built.estimated_output_tokens;
        let estimated_total_tokens = estimated_input_tokens.saturating_add(estimated_output_tokens);
        let estimated_cost_usd = profile
            .as_ref()
            .map(|profile| estimate_prompt_cost_usd(profile.provider_type, estimated_total_tokens))
            .unwrap_or(0.0);
        let (allowed, reason) = match profile.as_ref() {
            None => (
                false,
                "No enabled provider profile is configured; no provider request can be sent."
                    .to_string(),
            ),
            Some(profile) if !profile.enabled => (
                false,
                format!("Provider profile `{}` is disabled.", profile.id),
            ),
            Some(profile) if profile.monthly_budget_usd <= 0.0 => (
                false,
                "Monthly provider budget is 0; provider requests are disabled.".to_string(),
            ),
            Some(profile) if profile.single_request_token_limit < estimated_total_tokens => (
                false,
                "Single request token limit is lower than the redacted prompt estimate."
                    .to_string(),
            ),
            Some(_) => (
                true,
                "Redacted prompt preview is ready for explicit confirmation.".to_string(),
            ),
        };
        let preview_id = llm_preview_id(
            &params,
            profile.as_ref(),
            &built.prompt_preview,
            estimated_input_tokens,
            estimated_output_tokens,
        );

        Ok(LlmPreviewPromptResult {
            preview_id,
            status: if allowed { "ready" } else { "blocked" }.to_string(),
            allowed,
            reason,
            action: params.action.as_str(),
            profile_id,
            provider,
            model,
            destination_host,
            prompt_scope: built.prompt_scope,
            included_fields: built.included_fields,
            excluded_fields: built.excluded_fields,
            redaction: built.redaction,
            prompt_preview: built.prompt_preview,
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            estimated_cost_usd,
            single_request_token_limit,
            monthly_budget_usd,
            requires_confirmation: true,
            confirmation: LlmConfirmationRequirement {
                required: true,
                message:
                    "Confirm to send only this redacted prompt to the displayed provider endpoint."
                        .to_string(),
                display_fields: vec![
                    "preview_id",
                    "provider",
                    "model",
                    "destination_host",
                    "prompt_scope",
                    "included_fields",
                    "excluded_fields",
                    "redaction",
                    "estimated_total_tokens",
                    "estimated_cost_usd",
                ],
            },
            write_back_allowed: false,
            draft_requires_user_copy: true,
            provider_request_sent: false,
            raw_secret_returned: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn confirm_llm_prompt_and_send(
        &self,
        params: LlmConfirmPromptAndSendParams,
    ) -> Result<LlmConfirmPromptAndSendResult, ServiceError> {
        if params.confirmation_id.trim().is_empty() {
            return Err(ServiceError::ConfirmationRequired(
                "llm.confirmPromptAndSend requires an explicit confirmation_id".to_string(),
            ));
        }
        let preview = self.preview_llm_prompt(params.request.clone())?;
        if preview.preview_id != params.preview_id {
            return Err(ServiceError::InvalidRequest(
                "preview_id does not match the current redacted prompt preview".to_string(),
            ));
        }
        let profile_id = preview.profile_id.clone().ok_or_else(|| {
            ServiceError::InvalidRequest(
                "No provider profile is available for the confirmed prompt.".to_string(),
            )
        })?;
        let send = send_provider_prompt(
            &self.app_data_dir,
            SendProviderPromptParams {
                profile_id: profile_id.clone(),
                confirmation_id: params.confirmation_id.clone(),
                action_type: llm_prompt_action_type(&params.request),
                prompt: preview.prompt_preview.clone(),
                estimated_input_tokens: preview.estimated_input_tokens,
                estimated_output_tokens: preview.estimated_output_tokens,
                estimated_cost_usd: preview.estimated_cost_usd,
                redaction_status: preview.redaction.status.clone(),
                timeout_ms: params.timeout_ms,
            },
        )?;

        Ok(LlmConfirmPromptAndSendResult {
            preview_id: params.preview_id,
            confirmation_id: params.confirmation_id,
            status: send.status,
            action: params.request.action.as_str(),
            profile_id,
            provider: send.provider_type.as_str().to_string(),
            model: send.model,
            destination_host: send.destination_host,
            provider_request_sent: send.provider_request_sent,
            credential_accessed: send.credential_accessed,
            draft_output: send.output_text,
            draft_requires_user_copy: true,
            write_back_allowed: false,
            script_execution_allowed: false,
            config_mutation_allowed: false,
            snapshot_created: false,
            triage_mutation_allowed: false,
            audit: send.audit,
            raw_secret_returned: send.raw_secret_returned,
            raw_prompt_persisted: send.raw_prompt_persisted,
            raw_response_persisted: send.raw_response_persisted,
        })
    }

    pub fn score_skill_quality(
        &self,
        params: ScoreSkillQualityParams,
    ) -> Result<SkillQualityScoreResult, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Err(ServiceError::SkillNotFound(params.instance_id));
        };
        let skill = catalog
            .get_skill_detail(&params.instance_id)?
            .ok_or_else(|| ServiceError::SkillNotFound(params.instance_id.clone()))?;
        if let Some(agent) = params.agent.as_deref().filter(|agent| !agent.is_empty()) {
            if agent != skill.agent {
                return Err(ServiceError::InvalidRequest(format!(
                    "analysis.scoreSkillQuality agent `{agent}` does not match skill agent `{}`",
                    skill.agent
                )));
            }
        }
        if let Some(definition_id) = params
            .definition_id
            .as_deref()
            .filter(|definition_id| !definition_id.is_empty())
        {
            if definition_id != skill.definition_id {
                return Err(ServiceError::InvalidRequest(format!(
                    "analysis.scoreSkillQuality definition_id `{definition_id}` does not match skill definition `{}`",
                    skill.definition_id
                )));
            }
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let findings = catalog
            .list_rule_findings()?
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect::<Vec<_>>();
        let conflicts = catalog
            .list_conflict_groups()?
            .into_iter()
            .filter(|conflict| {
                conflict.definition_id == skill.definition_id
                    || conflict
                        .instance_ids
                        .iter()
                        .any(|instance_id| instance_id == &skill.id)
            })
            .collect::<Vec<_>>();
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let related_analysis = analysis
            .groups
            .into_iter()
            .filter(|group| {
                group
                    .instance_ids
                    .iter()
                    .any(|instance_id| instance_id == &skill.id)
            })
            .collect::<Vec<_>>();
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx)
            .into_iter()
            .find(|diagnostic| diagnostic.agent == skill.agent);

        let mut evidence = Vec::new();
        let skill_evidence_id = push_quality_evidence(
            &mut evidence,
            "skill",
            &skill.id,
            format!(
                "Catalog metadata for `{}` ({}, {})",
                redact_for_llm_preview(&skill.name),
                redact_for_llm_preview(&skill.agent),
                redact_for_llm_preview(&skill.scope)
            ),
            None,
            Some(skill.id.clone()),
        );
        let definition_evidence_id = push_quality_evidence(
            &mut evidence,
            "definition",
            &skill.definition_id,
            format!(
                "Definition identity `{}`",
                redact_for_llm_preview(&skill.definition_id)
            ),
            None,
            Some(skill.id.clone()),
        );

        let mut components = Vec::new();
        let mut reasons = Vec::new();
        let mut risk_notes = Vec::new();
        let mut suggestions = Vec::new();

        let (metadata_score, metadata_summary, metadata_suggestions) =
            quality_metadata_component(&skill);
        reasons.push(metadata_summary.clone());
        suggestions.extend(metadata_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "metadata_completeness",
            label: "Metadata completeness",
            score: metadata_score,
            max_score: 25,
            summary: metadata_summary,
            evidence_refs: vec![skill_evidence_id.clone(), definition_evidence_id],
        });

        let (permission_score, permission_summary, permission_risks, permission_suggestions) =
            quality_permission_component(&skill);
        reasons.push(permission_summary.clone());
        risk_notes.extend(permission_risks);
        suggestions.extend(permission_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "permission_clarity",
            label: "Permission clarity",
            score: permission_score,
            max_score: 20,
            summary: permission_summary,
            evidence_refs: vec![skill_evidence_id.clone()],
        });

        let mut finding_refs = Vec::new();
        for finding in &findings {
            let evidence_id = push_quality_evidence(
                &mut evidence,
                "finding",
                &finding.id,
                format!(
                    "{} finding `{}`: {}",
                    redact_for_llm_preview(&finding.effective_severity),
                    redact_for_llm_preview(&finding.rule_id),
                    redact_for_llm_preview(&finding.message)
                ),
                Some(finding.effective_severity.clone()),
                finding.instance_id.clone(),
            );
            finding_refs.push(evidence_id.clone());
            if let Some(suggestion) = finding.suggestion.as_deref() {
                suggestions.push(SkillQualitySuggestion {
                    priority: quality_priority_for_severity(&finding.effective_severity),
                    title: format!("Address `{}`", redact_for_llm_preview(&finding.rule_id)),
                    detail: redact_for_llm_preview(suggestion),
                    evidence_refs: vec![evidence_id],
                });
            }
        }
        let (risk_score, risk_summary, finding_risks, body_suggestions) =
            quality_risk_component(&skill, &findings);
        reasons.push(risk_summary.clone());
        risk_notes.extend(finding_risks);
        suggestions.extend(body_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "risk_findings",
            label: "Findings and risky signals",
            score: risk_score,
            max_score: 25,
            summary: risk_summary,
            evidence_refs: quality_refs_or_skill(&finding_refs, &skill_evidence_id),
        });

        let mut conflict_refs = Vec::new();
        for conflict in &conflicts {
            let evidence_id = push_quality_evidence(
                &mut evidence,
                "conflict",
                &conflict.id,
                format!(
                    "Same-agent conflict `{}` covers {} instance(s)",
                    redact_for_llm_preview(&conflict.reason),
                    conflict.instance_ids.len()
                ),
                Some("warning".to_string()),
                Some(skill.id.clone()),
            );
            conflict_refs.push(evidence_id);
        }
        for group in &related_analysis {
            let evidence_id = push_quality_evidence(
                &mut evidence,
                "analysis",
                &group.id,
                format!(
                    "{} analysis `{}`: {}",
                    redact_for_llm_preview(&group.severity),
                    redact_for_llm_preview(&group.kind),
                    redact_for_llm_preview(&group.title)
                ),
                Some(group.severity.clone()),
                Some(skill.id.clone()),
            );
            conflict_refs.push(evidence_id);
        }
        let (conflict_score, conflict_summary, conflict_suggestions) =
            quality_conflict_component(&conflicts, &related_analysis);
        reasons.push(conflict_summary.clone());
        suggestions.extend(conflict_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "conflict_and_overlap",
            label: "Conflicts and overlap",
            score: conflict_score,
            max_score: 15,
            summary: conflict_summary,
            evidence_refs: quality_refs_or_skill(&conflict_refs, &skill_evidence_id),
        });

        let adapter_evidence_id = adapter_diagnostics.as_ref().map(|diagnostic| {
            push_quality_evidence(
                &mut evidence,
                "adapter_diagnostics",
                diagnostic.agent,
                format!(
                    "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                    diagnostic.display_name,
                    diagnostic.status,
                    diagnostic.access.writable_status,
                    diagnostic.access.install_status
                ),
                None,
                Some(skill.id.clone()),
            )
        });
        let (adapter_score, adapter_summary, adapter_suggestions) =
            quality_adapter_component(&skill, adapter_diagnostics.as_ref());
        reasons.push(adapter_summary.clone());
        suggestions.extend(adapter_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "adapter_state",
            label: "Adapter state",
            score: adapter_score,
            max_score: 15,
            summary: adapter_summary,
            evidence_refs: adapter_evidence_id
                .map(|evidence_id| vec![evidence_id])
                .unwrap_or_else(|| vec![skill_evidence_id]),
        });

        let score = components
            .iter()
            .map(|component| u16::from(component.score))
            .sum::<u16>()
            .min(100) as u8;
        let (grade, band) = quality_grade_and_band(score);
        dedupe_quality_suggestions(&mut suggestions);
        suggestions.truncate(8);
        if risk_notes.is_empty() {
            risk_notes.push(
                "No high-risk local rule findings or execution/network/body signals were associated with this skill."
                    .to_string(),
            );
        }

        Ok(SkillQualityScoreResult {
            instance_id: skill.id.clone(),
            definition_id: skill.definition_id,
            agent: skill.agent,
            scope: skill.scope,
            skill_name: redact_for_llm_preview(&skill.name),
            score,
            grade,
            band,
            generated_by: "deterministic-service",
            components,
            reasons,
            risk_notes,
            evidence_references: evidence,
            suggested_improvements: suggestions,
            prompt_request: SkillQualityPromptRequest {
                available: true,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "quality_score",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::QualityScore,
                    profile_id: None,
                    skill_instance_id: Some(params.instance_id),
                    instance_ids: Vec::new(),
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain this deterministic local quality score using only the included redacted evidence."
                            .to_string(),
                    ),
                },
                note: "Optional provider-backed reasoning must be requested through prompt preview and explicit confirmation; this scoring method never sends provider traffic."
                    .to_string(),
            },
            safety_flags: skill_quality_safety_flags(),
        })
    }

    pub fn detect_stale_drift(
        &self,
        params: DetectStaleDriftParams,
    ) -> Result<StaleDriftDetectionResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "analysis.detectStaleDrift limit must be greater than zero".to_string(),
            ));
        }
        let stale_days = params
            .thresholds
            .stale_days
            .or(params.stale_days)
            .unwrap_or(90);
        if stale_days == 0 {
            return Err(ServiceError::InvalidRequest(
                "analysis.detectStaleDrift stale_days must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let limit = params.limit.unwrap_or(20).clamp(1, 100);
        let filters = StaleDriftFilters {
            agent: params.agent.clone(),
            candidate_instance_ids: params.candidate_instance_ids.clone(),
            limit,
            stale_days,
        };
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_stale_drift_result(filters, false));
        };

        let skills = catalog
            .list_skill_instances_for_project_context(adapter_ctx.project_root.as_deref())?;
        let skills = skills
            .into_iter()
            .filter(|skill| !is_pi_plain_markdown_instance_noise(skill))
            .collect::<Vec<_>>();
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let requested_ids = params
            .candidate_instance_ids
            .iter()
            .filter(|id| !id.trim().is_empty())
            .map(|id| id.as_str())
            .collect::<Vec<_>>();

        let mut gap_notes = Vec::new();
        let visible_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        for requested_id in &requested_ids {
            if !visible_by_id.contains_key(requested_id) {
                gap_notes.push(format!(
                    "Requested candidate `{}` is not visible in the current catalog/project scope.",
                    redact_for_llm_preview(requested_id)
                ));
            }
        }

        let now_ms = unix_timestamp_millis();
        let mut evidence = Vec::new();
        let mut rows = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if !requested_ids.is_empty() && !requested_ids.contains(&skill.id.as_str()) {
                continue;
            }
            let related_findings = findings
                .iter()
                .filter(|finding| {
                    finding.instance_id.as_deref() == Some(skill.id.as_str())
                        || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_conflicts = conflicts
                .iter()
                .filter(|conflict| {
                    conflict.definition_id == skill.definition_id
                        || conflict
                            .instance_ids
                            .iter()
                            .any(|instance_id| instance_id == &skill.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_analysis = analysis
                .groups
                .iter()
                .filter(|group| {
                    group
                        .instance_ids
                        .iter()
                        .any(|instance_id| instance_id == &skill.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == skill.agent.as_str());
            rows.push(stale_drift_row(
                skill,
                StaleDriftRowSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    stale_days,
                    now_ms,
                },
                &mut evidence,
            ));
        }

        rows.sort_by(|left, right| {
            right
                .stale_drift_score
                .cmp(&left.stale_drift_score)
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        rows.truncate(limit);
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        let readiness_impact_rows = rows
            .iter()
            .filter_map(stale_drift_readiness_impact_row)
            .collect::<Vec<_>>();
        if rows.is_empty() {
            gap_notes.push(
                "No visible skill rows matched the stale/drift detection filters.".to_string(),
            );
        }
        if rows
            .iter()
            .any(|row| row.drift_signals.missing_previous_scan)
        {
            gap_notes.push(
                "Some rows lack explicit previous-scan comparison evidence; drift is limited to current catalog findings, conflicts, and analysis groups."
                    .to_string(),
            );
        }
        if rows.iter().any(|row| row.drift_signals.missing_mtime) {
            gap_notes.push(
                "Some rows lack catalog mtime evidence; staleness age could not be derived without reading source files."
                    .to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let blocker_notes = stale_drift_blocker_notes(&rows);
        let summary = stale_drift_summary(skills.len(), &rows);
        let prompt_instance_ids = rows
            .iter()
            .take(8)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();

        Ok(StaleDriftDetectionResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            summary,
            stale_drift_rows: rows,
            readiness_impact_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: StaleDriftPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "stale_drift_detection",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::StaleDriftDetection,
                    profile_id: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic stale/drift signals using only local catalog evidence."
                            .to_string(),
                    ),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; analysis.detectStaleDrift never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces stale/drift rows."
                        .to_string()
                },
            },
            safety_flags: stale_drift_safety_flags(),
        })
    }

    pub fn search_knowledge(
        &self,
        params: KnowledgeSearchParams,
    ) -> Result<KnowledgeSearchResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "knowledge.search limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let filters = knowledge_search_filters(&params);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_knowledge_search_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let roots = self.redaction_roots(&adapter_ctx);
        let agent_filter = filters.agent.as_deref().filter(|agent| !agent.is_empty());
        let readiness_by_id = if filters.query.is_some() {
            let readiness = self.check_task_readiness(TaskReadinessParams {
                task: filters.query.clone().unwrap_or_default(),
                agent: filters.agent.clone(),
                candidate_instance_ids: Vec::new(),
                limit: Some(100),
            })?;
            readiness
                .candidate_skills
                .into_iter()
                .map(|candidate| (candidate.instance_id.clone(), candidate))
                .collect::<BTreeMap<_, _>>()
        } else {
            BTreeMap::new()
        };
        let stale_by_id = self
            .detect_stale_drift(DetectStaleDriftParams {
                agent: filters.agent.clone(),
                candidate_instance_ids: Vec::new(),
                limit: Some(100),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?
            .stale_drift_rows
            .into_iter()
            .map(|row| (row.instance_id.clone(), row))
            .collect::<BTreeMap<_, _>>();

        let mut gap_notes = Vec::new();
        let mut evidence = Vec::new();
        let mut rows = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = knowledge_related_findings(&findings, &detail);
            let related_conflicts = knowledge_related_conflicts(&conflicts, &detail);
            let related_analysis = knowledge_related_analysis(&analysis.groups, &detail);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let readiness = readiness_by_id.get(&detail.id);
            let stale = stale_by_id.get(&detail.id);
            let Some(row) = knowledge_search_row(
                &detail,
                KnowledgeSearchRowSignals {
                    query_terms: &filters.normalized_terms,
                    filters: &filters,
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                    readiness,
                    stale,
                    redaction_roots: &roots,
                },
                &mut evidence,
            ) else {
                continue;
            };
            rows.push(row);
        }

        let matched_row_count = rows.len();
        rows.sort_by(|left, right| {
            knowledge_row_rank_score(right)
                .cmp(&knowledge_row_rank_score(left))
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        rows.truncate(filters.limit);
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        if rows.is_empty() {
            gap_notes.push(
                "No visible local skill evidence matched the knowledge search filters.".to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let facets = knowledge_search_facets(&rows);
        let blocker_notes = knowledge_search_blocker_notes(&rows);
        let prompt_instance_ids = rows
            .iter()
            .take(8)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = knowledge_search_summary(skills.len(), matched_row_count, &rows);

        Ok(KnowledgeSearchResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            summary,
            filters: filters.clone(),
            rows,
            facets,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: KnowledgeSearchPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "knowledge_search",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::KnowledgeSearch,
                    profile_id: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.query.clone().or_else(|| {
                        Some("Explain deterministic local knowledge search results.".to_string())
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.search never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces knowledge rows."
                        .to_string()
                },
            },
            safety_flags: knowledge_search_safety_flags(),
        })
    }

    pub fn group_similar_skills(
        &self,
        params: SimilarSkillGroupingParams,
    ) -> Result<SimilarSkillGroupingResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "knowledge.groupSimilarSkills limit must be greater than zero".to_string(),
            ));
        }

        let filters = similar_skill_grouping_filters(&params);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_similar_skill_grouping_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let roots = self.redaction_roots(&adapter_ctx);
        let agent_filter = filters.agent.as_deref().filter(|agent| !agent.is_empty());
        let candidate_ids = filters
            .candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let stale_by_id = self
            .detect_stale_drift(DetectStaleDriftParams {
                agent: filters.agent.clone(),
                candidate_instance_ids: filters.candidate_instance_ids.clone(),
                limit: Some(100),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?
            .stale_drift_rows
            .into_iter()
            .map(|row| (row.instance_id.clone(), row))
            .collect::<BTreeMap<_, _>>();

        let mut gap_notes = Vec::new();
        let mut evidence = Vec::new();
        let mut candidates = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if !candidate_ids.is_empty() && !candidate_ids.contains(&skill.id) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = knowledge_related_findings(&findings, &detail);
            let related_conflicts = knowledge_related_conflicts(&conflicts, &detail);
            let related_analysis = knowledge_related_analysis(&analysis.groups, &detail);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let stale = stale_by_id.get(&detail.id);
            candidates.push(similar_skill_candidate(
                &detail,
                SimilarSkillCandidateSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                    stale,
                    redaction_roots: &roots,
                },
                &mut evidence,
            ));
        }

        let candidate_skill_count = candidates.len();
        let mut groups =
            similar_skill_groups_from_candidates(candidates, filters.min_score, &mut evidence);
        if !filters.include_singletons {
            groups.retain(|group| group.members.len() > 1);
        }
        let matched_group_count = groups.len();
        groups.sort_by(|left, right| {
            right
                .similarity_score
                .cmp(&left.similarity_score)
                .then_with(|| right.members.len().cmp(&left.members.len()))
                .then_with(|| left.canonical_key.cmp(&right.canonical_key))
                .then_with(|| left.group_id.cmp(&right.group_id))
        });
        groups.truncate(filters.limit);
        for (index, group) in groups.iter_mut().enumerate() {
            group.rank = index + 1;
        }

        if candidate_skill_count == 0 {
            gap_notes.push(
                "No visible local skill evidence matched the similar-grouping filters.".to_string(),
            );
        } else if groups.is_empty() {
            gap_notes.push(
                "No deterministic similarity group met the selected score threshold.".to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let blocker_notes = similar_skill_grouping_blocker_notes(&groups);
        let prompt_instance_ids = groups
            .iter()
            .flat_map(|group| {
                group
                    .members
                    .iter()
                    .map(|member| member.instance_id.clone())
            })
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = similar_skill_grouping_summary(
            skills.len(),
            candidate_skill_count,
            matched_group_count,
            &groups,
        );

        Ok(SimilarSkillGroupingResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            groups,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: SimilarSkillGroupingPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "similar_skill_grouping",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::SimilarSkillGrouping,
                    profile_id: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic similar skill grouping using only local catalog evidence."
                            .to_string(),
                    ),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.groupSimilarSkills never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces similar-skill groups."
                        .to_string()
                },
            },
            safety_flags: similar_skill_grouping_safety_flags(),
        })
    }

    pub fn check_task_readiness(
        &self,
        params: TaskReadinessParams,
    ) -> Result<TaskReadinessResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.checkReadiness requires a non-empty task".to_string(),
            ));
        }
        let adapter_ctx = self.effective_adapter_ctx()?;
        let task = redact_string(
            &redact_for_llm_preview(task),
            &self.redaction_roots(&adapter_ctx),
        );
        let limit = params.limit.unwrap_or(8).clamp(1, 20);
        let filters = TaskReadinessFilters {
            agent: params.agent.clone(),
            candidate_instance_ids: params.candidate_instance_ids.clone(),
            limit,
        };
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_task_readiness_result(task, filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let requested_ids = params
            .candidate_instance_ids
            .iter()
            .filter(|id| !id.trim().is_empty())
            .map(|id| id.as_str())
            .collect::<Vec<_>>();
        let task_terms = task_readiness_terms(&task);

        let mut missing_gap_notes = Vec::new();
        let visible_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        for requested_id in &requested_ids {
            if !visible_by_id.contains_key(requested_id) {
                missing_gap_notes.push(format!(
                    "Requested candidate `{}` is not visible in the current catalog/project scope.",
                    redact_for_llm_preview(requested_id)
                ));
            }
        }

        let mut evidence = Vec::new();
        let mut candidates = Vec::new();
        for skill in skills {
            if let Some(agent) = agent_filter {
                if skill.agent != agent {
                    continue;
                }
            }
            if !requested_ids.is_empty() && !requested_ids.contains(&skill.id.as_str()) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                missing_gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = findings
                .iter()
                .filter(|finding| {
                    finding.instance_id.as_deref() == Some(detail.id.as_str())
                        || finding.definition_id.as_deref() == Some(detail.definition_id.as_str())
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_conflicts = conflicts
                .iter()
                .filter(|conflict| {
                    conflict.definition_id == detail.definition_id
                        || conflict
                            .instance_ids
                            .iter()
                            .any(|instance_id| instance_id == &detail.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_analysis = analysis
                .groups
                .iter()
                .filter(|group| {
                    group
                        .instance_ids
                        .iter()
                        .any(|instance_id| instance_id == &detail.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let candidate = task_readiness_candidate(
                &task_terms,
                &detail,
                TaskReadinessCandidateSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                },
                &mut evidence,
            );
            candidates.push(candidate);
        }

        candidates.sort_by(|left, right| {
            right
                .score
                .cmp(&left.score)
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        candidates.truncate(limit);

        if candidates.is_empty() {
            if agent_filter.is_some() {
                missing_gap_notes.push(
                    "No visible skill candidates matched the requested agent/filter scope."
                        .to_string(),
                );
            } else {
                missing_gap_notes.push(
                    "No visible skill candidates matched the task in the current catalog."
                        .to_string(),
                );
            }
        }

        let blocker_risk_notes = task_readiness_blocker_notes(&candidates);
        let score = task_readiness_overall_score(&candidates);
        let band = task_readiness_band(score);
        let summary = task_readiness_summary(score, band, &candidates, &missing_gap_notes);
        let prompt_instance_ids = candidates
            .iter()
            .take(8)
            .map(|candidate| candidate.instance_id.clone())
            .collect::<Vec<_>>();

        Ok(TaskReadinessResult {
            task: task.clone(),
            score,
            band,
            summary,
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            candidate_skills: candidates,
            missing_gap_notes,
            blocker_risk_notes,
            evidence_references: evidence,
            prompt_request: TaskReadinessPromptRequest {
                available: true,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "task_readiness",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::TaskReadiness,
                    profile_id: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(task.clone()),
                },
                note: "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.checkReadiness never sends provider traffic."
                    .to_string(),
            },
            safety_flags: task_readiness_safety_flags(),
        })
    }

    pub fn rank_skill_routes(
        &self,
        params: RankSkillRoutesParams,
    ) -> Result<SkillRouteRankingResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.rankSkillRoutes requires a non-empty task".to_string(),
            ));
        }
        let readiness = self.check_task_readiness(TaskReadinessParams {
            task: task.to_string(),
            agent: params.agent,
            candidate_instance_ids: params.candidate_instance_ids,
            limit: params.limit,
        })?;
        Ok(skill_route_ranking_from_readiness(readiness))
    }

    pub fn compare_agent_readiness(
        &self,
        params: CompareAgentReadinessParams,
    ) -> Result<AgentReadinessComparisonResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.compareAgentReadiness requires a non-empty task".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let task = redact_string(
            &redact_for_llm_preview(task),
            &self.redaction_roots(&adapter_ctx),
        );
        let limit_per_agent = params.limit_per_agent.unwrap_or(3).clamp(1, 10);
        let requested_agents = normalize_agent_filter_list(params.agents);
        let filters = AgentReadinessComparisonFilters {
            agents: requested_agents.clone(),
            limit_per_agent,
            include_routing_accuracy: params.include_routing_accuracy,
            include_benchmarks: params.include_benchmarks,
        };

        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_agent_readiness_comparison(
                task,
                filters,
                false,
                "No local catalog is available; cross-agent readiness comparison has no candidate evidence.",
            ));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let agents =
            agent_readiness_agents_for_comparison(&skills, &adapter_ctx, &requested_agents);
        if agents.is_empty() {
            return Ok(empty_agent_readiness_comparison(
                task,
                filters,
                true,
                "No supported agent skills matched the selected filters in the current catalog.",
            ));
        }

        let accuracy_by_agent = if params.include_routing_accuracy {
            Some(agent_readiness_accuracy_context(
                self.routing_accuracy_dashboard(RoutingAccuracyDashboardParams {
                    agent: None,
                    window_days: Some(30),
                    limit: Some(100),
                    include_history: false,
                    include_recent_evidence: true,
                })?,
            ))
        } else {
            None
        };
        let benchmark_by_agent = if params.include_benchmarks {
            Some(agent_readiness_benchmark_context(
                self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
                    ids: Vec::new(),
                    limit: None,
                })?,
            ))
        } else {
            None
        };

        let mut evidence_by_id = BTreeMap::new();
        let mut rows = Vec::new();
        let mut gap_issue_rows = Vec::new();
        for agent in agents {
            let readiness = self.check_task_readiness(TaskReadinessParams {
                task: task.clone(),
                agent: Some(agent.clone()),
                candidate_instance_ids: Vec::new(),
                limit: Some(limit_per_agent),
            })?;
            let ranking = skill_route_ranking_from_readiness(readiness.clone());
            for evidence in readiness.evidence_references.iter().cloned() {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert(evidence);
            }
            let accuracy_context = accuracy_by_agent
                .as_ref()
                .and_then(|by_agent| by_agent.get(&agent).cloned());
            let benchmark_context = benchmark_by_agent
                .as_ref()
                .and_then(|by_agent| by_agent.get(&agent).cloned());
            let row = agent_readiness_row_from_results(
                &agent,
                &readiness,
                &ranking,
                accuracy_context,
                benchmark_context,
            );
            gap_issue_rows.extend(agent_readiness_gap_issue_rows(&row));
            rows.push(row);
        }

        rows.sort_by(|left, right| {
            right
                .comparison_score
                .cmp(&left.comparison_score)
                .then_with(|| right.readiness_score.cmp(&left.readiness_score))
                .then_with(|| {
                    right
                        .routing_confidence_score
                        .cmp(&left.routing_confidence_score)
                })
                .then_with(|| left.agent.cmp(&right.agent))
        });
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        let recommended_agent = rows
            .iter()
            .find(|row| row.candidate_count > 0 && row.comparison_score > 0)
            .map(agent_readiness_recommendation);
        let prompt_instance_ids = rows
            .iter()
            .filter_map(|row| row.best_candidate.as_ref())
            .take(8)
            .map(|candidate| candidate.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = agent_readiness_summary(&rows, &gap_issue_rows, &recommended_agent);
        let evidence_references = evidence_by_id.into_values().collect::<Vec<_>>();

        Ok(AgentReadinessComparisonResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            summary,
            agent_rows: rows,
            recommended_agent,
            gap_issue_rows,
            evidence_references,
            prompt_request: AgentReadinessPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "task_readiness",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::TaskReadiness,
                    profile_id: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(task),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.compareAgentReadiness never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces cross-agent candidates."
                        .to_string()
                },
            },
            safety_flags: agent_readiness_safety_flags(),
        })
    }

    pub fn list_task_benchmarks(
        &self,
        params: ListTaskBenchmarksParams,
    ) -> Result<TaskBenchmarkListResult, ServiceError> {
        let mut benchmarks = self.load_task_benchmarks()?;
        if let Some(limit) = params.limit {
            benchmarks.truncate(limit);
        }
        Ok(TaskBenchmarkListResult {
            count: benchmarks.len(),
            benchmarks,
            app_local_only: true,
            provider_request_sent: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn save_task_benchmark(
        &self,
        params: SaveTaskBenchmarkParams,
    ) -> Result<SaveTaskBenchmarkResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.saveBenchmark requires a non-empty task".to_string(),
            ));
        }
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .map(ToOwned::to_owned)
            .unwrap_or_else(|| task.chars().take(72).collect::<String>());
        let id = params
            .id
            .as_deref()
            .map(str::trim)
            .filter(|id| !id.is_empty())
            .map(sanitize_benchmark_id)
            .unwrap_or_else(|| generated_benchmark_id(&title, task));
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.saveBenchmark requires a benchmark id containing letters, numbers, '-' or '_'"
                    .to_string(),
            ));
        }

        let mut benchmarks = self.load_task_benchmarks()?;
        let now = unix_timestamp_millis();
        let existing_index = benchmarks.iter().position(|benchmark| benchmark.id == id);
        let created_at = existing_index
            .and_then(|index| benchmarks.get(index).map(|benchmark| benchmark.created_at))
            .unwrap_or(now);
        let benchmark = TaskBenchmarkRecord {
            id: id.clone(),
            title,
            task: task.to_string(),
            expected_skill_refs: normalize_string_list(params.expected_skill_refs),
            expected_skill_names: normalize_string_list(params.expected_skill_names),
            acceptable_agents: normalize_string_list(params.acceptable_agents),
            acceptable_scopes: normalize_string_list(params.acceptable_scopes),
            success_criteria: normalize_string_list(params.success_criteria),
            created_at,
            updated_at: now,
        };
        let created = if let Some(index) = existing_index {
            benchmarks[index] = benchmark.clone();
            false
        } else {
            benchmarks.push(benchmark.clone());
            true
        };
        self.save_task_benchmarks(&benchmarks)?;
        Ok(SaveTaskBenchmarkResult {
            benchmark,
            created,
            app_local_only: true,
            provider_request_sent: false,
            agent_config_mutated: false,
        })
    }

    pub fn delete_task_benchmark(
        &self,
        params: DeleteTaskBenchmarkParams,
    ) -> Result<DeleteTaskBenchmarkResult, ServiceError> {
        let id = sanitize_benchmark_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.deleteBenchmark requires a benchmark id".to_string(),
            ));
        }
        let mut benchmarks = self.load_task_benchmarks()?;
        let before = benchmarks.len();
        benchmarks.retain(|benchmark| benchmark.id != id);
        let deleted = benchmarks.len() != before;
        if deleted {
            self.save_task_benchmarks(&benchmarks)?;
        }
        Ok(DeleteTaskBenchmarkResult {
            benchmark_id: id,
            deleted,
            remaining_count: benchmarks.len(),
            app_local_only: true,
            provider_request_sent: false,
            agent_config_mutated: false,
        })
    }

    pub fn evaluate_task_benchmarks(
        &self,
        params: EvaluateTaskBenchmarksParams,
    ) -> Result<TaskBenchmarkEvaluationResult, ServiceError> {
        let requested_ids = params
            .ids
            .iter()
            .map(|id| sanitize_benchmark_id(id.trim()))
            .filter(|id| !id.is_empty())
            .collect::<Vec<_>>();
        let mut benchmarks = self.load_task_benchmarks()?;
        if !requested_ids.is_empty() {
            benchmarks.retain(|benchmark| requested_ids.contains(&benchmark.id));
        }
        if let Some(limit) = params.limit {
            benchmarks.truncate(limit);
        }

        let mut benchmark_results = Vec::new();
        let mut catalog_available = self.catalog_path().exists();
        for benchmark in &benchmarks {
            let ranking = self.rank_skill_routes(RankSkillRoutesParams {
                task: benchmark.task.clone(),
                agent: None,
                candidate_instance_ids: Vec::new(),
                limit: Some(8),
            })?;
            catalog_available &= ranking.catalog_available;
            benchmark_results.push(task_benchmark_evaluation_item(benchmark, ranking));
        }
        if benchmarks.is_empty() {
            catalog_available = self.catalog_path().exists();
        }

        let blocker_notes = task_benchmark_blocker_notes(&benchmark_results, catalog_available);
        let prompt_request = task_benchmark_prompt_request(&benchmark_results);
        Ok(TaskBenchmarkEvaluationResult {
            generated_by: "deterministic-service",
            catalog_available,
            evaluated_count: benchmark_results.len(),
            summary: task_benchmark_summary(&benchmark_results, catalog_available),
            benchmark_results,
            blocker_notes,
            prompt_request,
            safety_flags: task_benchmark_safety_flags(),
        })
    }

    pub fn save_routing_baseline(
        &self,
        params: SaveRoutingBaselineParams,
    ) -> Result<SaveRoutingBaselineResult, ServiceError> {
        let evaluation = self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
            ids: params.ids,
            limit: params.limit,
        })?;
        let baseline = routing_regression_baseline_from_evaluation(evaluation);
        self.save_routing_regression_baseline(&baseline)?;
        Ok(SaveRoutingBaselineResult {
            benchmark_count: baseline.evaluated_count,
            baseline,
            generated_by: "deterministic-service",
            app_local_only: true,
            baseline_file: "task-routing-baseline.json",
            provider_request_sent: false,
            agent_config_mutated: false,
            skill_files_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn detect_routing_regression(
        &self,
        params: DetectRoutingRegressionParams,
    ) -> Result<RoutingRegressionDetectionResult, ServiceError> {
        let current_evaluation = self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
            ids: params.ids,
            limit: params.limit,
        })?;
        let baseline = self.load_routing_regression_baseline()?;
        let Some(baseline) = baseline else {
            let blocker_notes = vec![
                "No app-local routing baseline is saved; run task.saveRoutingBaseline before regression detection."
                    .to_string(),
            ];
            return Ok(RoutingRegressionDetectionResult {
                generated_by: "deterministic-service",
                status: "baseline_missing",
                baseline_available: false,
                catalog_available: current_evaluation.catalog_available,
                baseline_evaluated_count: 0,
                current_evaluated_count: current_evaluation.evaluated_count,
                regression_count: 0,
                missing_benchmark_count: 0,
                summary: format!(
                    "No app-local routing baseline was available; evaluated {} current benchmark(s) without writing a baseline.",
                    current_evaluation.evaluated_count
                ),
                items: Vec::new(),
                blocker_notes,
                baseline: None,
                current_evaluation,
                safety_flags: task_benchmark_safety_flags(),
            });
        };

        let comparison = routing_regression_compare(
            &baseline,
            &current_evaluation,
            params.score_drop_threshold.unwrap_or(10),
            params.confidence_drop_threshold.unwrap_or(10),
        );
        let regression_count = comparison.iter().filter(|item| item.regression).count();
        let missing_benchmark_count = comparison
            .iter()
            .filter(|item| item.status == "missing_current_benchmark")
            .count();
        let mut blocker_notes = current_evaluation.blocker_notes.clone();
        if !current_evaluation.catalog_available {
            blocker_notes.push(
                "No local catalog is available; routing regression detection cannot verify current routes."
                    .to_string(),
            );
        }
        if baseline.benchmark_results.is_empty() {
            blocker_notes.push("Saved routing baseline contains no benchmark results.".to_string());
        }
        blocker_notes.sort();
        blocker_notes.dedup();
        let status = routing_regression_status(
            regression_count,
            missing_benchmark_count,
            current_evaluation.catalog_available,
        );
        Ok(RoutingRegressionDetectionResult {
            generated_by: "deterministic-service",
            status,
            baseline_available: true,
            catalog_available: current_evaluation.catalog_available,
            baseline_evaluated_count: baseline.evaluated_count,
            current_evaluated_count: current_evaluation.evaluated_count,
            regression_count,
            missing_benchmark_count,
            summary: routing_regression_summary(
                regression_count,
                missing_benchmark_count,
                comparison.len(),
                current_evaluation.catalog_available,
            ),
            items: comparison,
            blocker_notes,
            baseline: Some(baseline),
            current_evaluation,
            safety_flags: task_benchmark_safety_flags(),
        })
    }

    pub fn routing_accuracy_dashboard(
        &self,
        params: RoutingAccuracyDashboardParams,
    ) -> Result<RoutingAccuracyDashboardResult, ServiceError> {
        let now = unix_timestamp_millis();
        let window_days = params.window_days.unwrap_or(30).clamp(1, 365);
        let limit = params.limit.unwrap_or(25).clamp(1, 250);
        let window_start_millis = now.saturating_sub(i64::from(window_days) * 86_400_000);
        let agent_filter = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(str::to_string);

        let imports_file_available = self.trace_imports_path().exists();
        let benchmark_file_available = self.task_benchmarks_path().exists();
        let baseline_file_available = self.routing_regression_baseline_path().exists();
        let mut imports = self.load_trace_imports()?;
        imports.retain(|import| {
            import.imported_at >= window_start_millis
                && import.imported_at <= now
                && routing_accuracy_agent_matches_import(&agent_filter, import)
        });

        let detection = self.detect_routing_regression(DetectRoutingRegressionParams {
            ids: Vec::new(),
            limit: None,
            score_drop_threshold: None,
            confidence_drop_threshold: None,
        })?;

        let mut summary = RoutingAccuracyDashboardSummary::default();
        let mut agent_rows: BTreeMap<String, RoutingAccuracyAgentAggregate> = BTreeMap::new();
        let mut history_rows: BTreeMap<i64, RoutingAccuracyOutcomeCounts> = BTreeMap::new();
        let mut gap_issue_rows = Vec::new();
        let mut recent_evidence_rows = Vec::new();

        for import in &imports {
            let outcome = routing_accuracy_normalize_outcome(&import.analysis.outcome);
            routing_accuracy_increment_summary(&mut summary, outcome);
            let agent = routing_accuracy_trace_agent(import);
            agent_rows
                .entry(agent.clone())
                .or_default()
                .record_trace(outcome);
            if params.include_history {
                let unix_day = import.imported_at.div_euclid(86_400_000);
                routing_accuracy_increment_counts(
                    history_rows.entry(unix_day).or_default(),
                    outcome,
                );
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "trace.importLocal",
                    agent: Some(agent),
                    title: import.title.clone(),
                    outcome: Some(outcome.to_string()),
                    detail: routing_accuracy_trace_detail(import),
                    evidence_refs: import.analysis.evidence_refs.clone(),
                    observed_at: Some(import.imported_at),
                });
            }
        }

        let benchmark_results = &detection.current_evaluation.benchmark_results;
        for item in benchmark_results
            .iter()
            .filter(|item| routing_accuracy_agent_matches_benchmark(&agent_filter, item))
        {
            summary.benchmark_count += 1;
            if matches!(
                item.expected_match_status,
                "expected_match" | "acceptable_match"
            ) {
                summary.benchmark_matched_count += 1;
            } else {
                summary.benchmark_gap_count += 1;
            }
            let agent = routing_accuracy_benchmark_agent(item);
            let agent_row = agent_rows.entry(agent.clone()).or_default();
            agent_row.benchmark_count += 1;
            if matches!(
                item.expected_match_status,
                "expected_match" | "acceptable_match"
            ) {
                agent_row.benchmark_matched_count += 1;
            } else {
                agent_row.benchmark_gap_count += 1;
            }
            if item.expected_match_status != "expected_match"
                || !item.gap_notes.is_empty()
                || !item.blocker_notes.is_empty()
            {
                gap_issue_rows.push(RoutingAccuracyIssueRow {
                    source: "task.evaluateBenchmarks",
                    severity: routing_accuracy_benchmark_severity(item),
                    agent: Some(agent.clone()),
                    title: item.title.clone(),
                    detail: routing_accuracy_benchmark_issue_detail(item),
                    evidence_refs: item.evidence_refs.clone(),
                });
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "task.evaluateBenchmarks",
                    agent: Some(agent),
                    title: item.title.clone(),
                    outcome: Some(item.expected_match_status.to_string()),
                    detail: format!(
                        "Benchmark score {}/100 with route confidence {}/100.",
                        item.score, item.route_confidence_score
                    ),
                    evidence_refs: item.evidence_refs.clone(),
                    observed_at: None,
                });
            }
        }

        for item in detection
            .items
            .iter()
            .filter(|item| routing_accuracy_agent_matches_regression(&agent_filter, item))
        {
            if item.regression {
                summary.regression_count += 1;
                let agent = routing_accuracy_regression_agent(item);
                let agent_key = agent.clone().unwrap_or_else(|| "unknown".to_string());
                agent_rows.entry(agent_key).or_default().regression_count += 1;
                gap_issue_rows.push(RoutingAccuracyIssueRow {
                    source: "task.detectRoutingRegression",
                    severity: "critical",
                    agent,
                    title: item.title.clone(),
                    detail: item.reasons.join(" "),
                    evidence_refs: item.evidence_refs.clone(),
                });
            }
            if item.status == "missing_current_benchmark" {
                summary.missing_benchmark_count += 1;
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "task.detectRoutingRegression",
                    agent: routing_accuracy_regression_agent(item),
                    title: item.title.clone(),
                    outcome: Some(item.status.to_string()),
                    detail: routing_accuracy_regression_detail(item),
                    evidence_refs: item.evidence_refs.clone(),
                    observed_at: None,
                });
            }
        }

        summary.trace_count = imports.len();
        summary.accuracy_rate = routing_accuracy_rate(
            summary.hit_count,
            summary.hit_count
                + summary.miss_count
                + summary.wrong_pick_count
                + summary.ambiguous_count,
        );
        summary.known_outcome_rate = routing_accuracy_rate(
            summary.hit_count
                + summary.miss_count
                + summary.wrong_pick_count
                + summary.ambiguous_count,
            summary.trace_count,
        );
        summary.summary = routing_accuracy_summary_text(&summary, detection.catalog_available);

        let mut blocker_notes = detection.blocker_notes.clone();
        if !detection.catalog_available {
            blocker_notes.push(
                "No local catalog is available; dashboard metrics are limited to app-local trace metadata and saved benchmark records."
                    .to_string(),
            );
        }
        if !imports_file_available {
            blocker_notes.push("No app-local trace imports are saved.".to_string());
        }
        if !benchmark_file_available {
            blocker_notes.push("No app-local task benchmarks are saved.".to_string());
        }
        if !baseline_file_available {
            blocker_notes.push(
                "No app-local routing regression baseline is saved; regression evidence is unavailable."
                    .to_string(),
            );
        }
        if imports.is_empty() && benchmark_results.is_empty() {
            blocker_notes
                .push("No routing accuracy evidence matched the current filters.".to_string());
        }
        blocker_notes.sort();
        blocker_notes.dedup();

        gap_issue_rows.sort_by(|left, right| {
            routing_accuracy_severity_rank(left.severity)
                .cmp(&routing_accuracy_severity_rank(right.severity))
                .then_with(|| left.source.cmp(right.source))
                .then_with(|| left.title.cmp(&right.title))
        });
        gap_issue_rows.truncate(limit);
        recent_evidence_rows.sort_by(|left, right| {
            right
                .observed_at
                .cmp(&left.observed_at)
                .then_with(|| left.source.cmp(right.source))
                .then_with(|| left.title.cmp(&right.title))
        });
        recent_evidence_rows.truncate(limit);

        let agent_rows = agent_rows
            .into_iter()
            .map(|(agent, aggregate)| aggregate.into_row(agent))
            .collect::<Vec<_>>();
        let history_rows = if params.include_history {
            history_rows
                .into_iter()
                .map(|(unix_day, outcomes)| {
                    let known =
                        outcomes.hit + outcomes.miss + outcomes.wrong_pick + outcomes.ambiguous;
                    RoutingAccuracyHistoryRow {
                        unix_day,
                        trace_count: known + outcomes.unknown,
                        accuracy_rate: routing_accuracy_rate(outcomes.hit, known),
                        outcomes,
                    }
                })
                .collect()
        } else {
            Vec::new()
        };

        Ok(RoutingAccuracyDashboardResult {
            generated_by: "deterministic-service",
            catalog_available: detection.catalog_available,
            filters: RoutingAccuracyDashboardFilters {
                agent: agent_filter,
                window_days,
                limit,
                include_history: params.include_history,
                include_recent_evidence: params.include_recent_evidence,
                window_start_millis,
                window_end_millis: now,
            },
            summary,
            agent_rows,
            history_rows,
            gap_issue_rows,
            recent_evidence_rows,
            blocker_notes,
            prompt_request: routing_accuracy_prompt_request(&imports, benchmark_results),
            safety_flags: routing_accuracy_safety_flags(),
        })
    }

    pub fn import_local_trace(
        &self,
        params: TraceImportLocalParams,
    ) -> Result<TraceImportLocalResult, ServiceError> {
        let content = params.content.trim();
        if content.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "trace.importLocal requires non-empty trace content".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let redaction_roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&redaction_roots);
        let max_excerpt_chars = params.max_excerpt_chars.unwrap_or(800).clamp(80, 4_000);
        let excerpt = truncate_chars(&redactor.redact(content), max_excerpt_chars);
        let excerpt_char_count = excerpt.chars().count();
        let expected_skill_refs =
            redact_normalized_string_list(params.expected_skill_refs, &redaction_roots);
        let expected_skill_names =
            redact_normalized_string_list(params.expected_skill_names, &redaction_roots);
        let task = params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| redactor.redact(task));
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .map(|title| redactor.redact(title))
            .or_else(|| task.clone())
            .unwrap_or_else(|| "Imported local trace".to_string());
        let source_kind = params
            .source_kind
            .as_deref()
            .map(str::trim)
            .filter(|source_kind| !source_kind.is_empty())
            .map(|source_kind| redactor.redact(source_kind))
            .unwrap_or_else(|| "local-transcript".to_string());
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(|agent| redactor.redact(agent));
        let redaction_summary = trace_import_redaction_summary_from(redactor.summary());
        let content_hash = trace_content_hash(content);
        let imported_at = unix_timestamp_millis();
        let analysis = self.analyze_imported_trace(
            content,
            &expected_skill_refs,
            &expected_skill_names,
            agent.as_deref(),
        )?;
        let record = TraceImportRecord {
            id: generated_trace_import_id(&title, &content_hash, imported_at),
            title,
            source_kind,
            agent,
            task,
            expected_skill_refs,
            expected_skill_names,
            excerpt,
            excerpt_char_count,
            redaction_summary,
            content_hash,
            imported_at,
            analysis,
            safety_flags: trace_import_safety_flags(),
        };

        let mut imports = self.load_trace_imports()?;
        imports.push(record.clone());
        self.save_trace_imports(&imports)?;
        Ok(TraceImportLocalResult {
            generated_by: "deterministic-service",
            import: record,
            count: imports.len(),
            app_local_only: true,
            import_file: "trace-imports.json",
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }

    pub fn list_trace_imports(
        &self,
        params: TraceListImportsParams,
    ) -> Result<TraceImportListResult, ServiceError> {
        let mut imports = self.load_trace_imports()?;
        if let Some(limit) = params.limit {
            imports.truncate(limit);
        }
        Ok(TraceImportListResult {
            count: imports.len(),
            imports,
            app_local_only: true,
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }

    pub fn delete_trace_import(
        &self,
        params: TraceDeleteImportParams,
    ) -> Result<TraceDeleteImportResult, ServiceError> {
        let id = sanitize_trace_import_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "trace.deleteImport requires an import id".to_string(),
            ));
        }
        let mut imports = self.load_trace_imports()?;
        let before = imports.len();
        imports.retain(|record| record.id != id);
        let deleted = imports.len() != before;
        if deleted {
            self.save_trace_imports(&imports)?;
        }
        Ok(TraceDeleteImportResult {
            import_id: id,
            deleted,
            remaining_count: imports.len(),
            app_local_only: true,
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }

    pub fn script_execution_status(&self) -> ScriptExecutionStatus {
        ScriptExecutionStatus {
            enabled: false,
            default_enabled: false,
            reason: SCRIPT_EXECUTION_DISABLED_REASON.to_string(),
            audit_scope: "app-data/session-local".to_string(),
            audit_path: display_path(&self.script_execution_audit_path()),
            llm_initiation_allowed: false,
        }
    }

    fn resolve_llm_prompt_profile(
        &self,
        requested_profile_id: Option<&str>,
    ) -> Result<Option<ProviderProfileRecord>, ServiceError> {
        let profiles = list_provider_profiles(&self.app_data_dir)?;
        if let Some(profile_id) = requested_profile_id.filter(|id| !id.trim().is_empty()) {
            return profiles
                .profiles
                .into_iter()
                .find(|profile| profile.id == profile_id)
                .map(Some)
                .ok_or_else(|| ProviderError::ProfileNotFound(profile_id.to_string()).into());
        }
        Ok(profiles
            .default_profile_id
            .as_deref()
            .and_then(|default_id| {
                profiles
                    .profiles
                    .iter()
                    .find(|profile| profile.id == default_id)
            })
            .or_else(|| profiles.profiles.iter().find(|profile| profile.enabled))
            .cloned())
    }

    fn build_llm_prompt(
        &self,
        params: &LlmPreviewPromptParams,
    ) -> Result<BuiltLlmPrompt, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&roots);
        let mut prompt_scope = vec![
            "operation metadata".to_string(),
            "safety boundaries".to_string(),
        ];
        let mut included_fields = vec![
            "action kind".to_string(),
            "draft-only safety instructions".to_string(),
        ];
        let mut excluded_fields = vec![
            "source paths".to_string(),
            "credential values".to_string(),
            "provider API key".to_string(),
            "agent config mutation instructions".to_string(),
            "script execution instructions".to_string(),
        ];
        let mut sections = vec![
            "You are assisting with AI agent skill governance.".to_string(),
            format!("Action: {}", params.action.as_str()),
            "Return draft-only analysis. Do not write files, mutate agent config, execute scripts, change triage, create snapshots, call tools, or request secrets.".to_string(),
        ];
        if let Some(intent) = params
            .user_intent
            .as_deref()
            .filter(|intent| !intent.trim().is_empty())
        {
            prompt_scope.push("user intent".to_string());
            included_fields.push("redacted user intent".to_string());
            sections.push(format!("User intent: {}", redactor.redact(intent)));
        }

        match params.action {
            LlmPromptActionKind::Analyze | LlmPromptActionKind::DraftFrontmatter => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(format!(
                        "llm.previewPrompt {} requires skill_instance_id",
                        params.action.as_str()
                    ))
                })?;
                let skill = self.get_llm_skill_detail(instance_id)?;
                prompt_scope.extend([
                    "selected skill metadata".to_string(),
                    "selected skill redacted frontmatter".to_string(),
                    "selected skill redacted body".to_string(),
                    "related finding summaries".to_string(),
                ]);
                included_fields.extend([
                    "skill id".to_string(),
                    "skill name".to_string(),
                    "agent".to_string(),
                    "scope".to_string(),
                    "enabled state".to_string(),
                    "redacted description".to_string(),
                    "redacted frontmatter".to_string(),
                    "redacted skill body".to_string(),
                    "rule finding ids and messages".to_string(),
                ]);
                sections.push(self.render_skill_prompt_section(&skill, &mut redactor)?);
            }
            LlmPromptActionKind::Recommend => {
                prompt_scope.extend([
                    "user intent".to_string(),
                    "catalog recommendation constraints".to_string(),
                ]);
                included_fields.push("recommendation constraints".to_string());
                excluded_fields.push("raw skill bodies".to_string());
                sections.push(
                    "Recommendation constraints: use current catalog evidence only when available; ask for clarification instead of inventing unavailable skills."
                        .to_string(),
                );
            }
            LlmPromptActionKind::ExplainConflict => {
                prompt_scope.extend([
                    "current conflict summaries".to_string(),
                    "current rule finding summaries".to_string(),
                ]);
                included_fields.extend([
                    "conflict ids".to_string(),
                    "definition ids".to_string(),
                    "rule ids".to_string(),
                    "finding severities".to_string(),
                ]);
                excluded_fields.push("raw skill bodies".to_string());
                let summary = self.llm_conflict_summary()?;
                sections.push(format!(
                    "Conflict and finding summary:\n{}",
                    redactor.redact(&summary)
                ));
            }
            LlmPromptActionKind::SkillAnalysis => {
                let analysis_kind = params
                    .analysis_kind
                    .unwrap_or(LlmSkillAnalysisKind::Overview);
                prompt_scope.extend([
                    "selected skill metadata".to_string(),
                    "selected skill redacted frontmatter".to_string(),
                    "selected skill redacted body".to_string(),
                    "related finding summaries".to_string(),
                    "missing selection count".to_string(),
                ]);
                included_fields.extend([
                    "analysis kind".to_string(),
                    "selected skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "redacted descriptions".to_string(),
                    "redacted frontmatter".to_string(),
                    "redacted skill bodies".to_string(),
                    "rule finding ids and messages".to_string(),
                ]);
                sections.push(format!("Analysis kind: {}", analysis_kind.as_str()));
                sections.push(self.render_skill_analysis_prompt_sections(params, &mut redactor)?);
            }
            LlmPromptActionKind::QualityScore => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt quality_score requires skill_instance_id".to_string(),
                    )
                })?;
                let score = self.score_skill_quality(ScoreSkillQualityParams {
                    instance_id: instance_id.to_string(),
                    agent: None,
                    definition_id: None,
                })?;
                prompt_scope.extend([
                    "deterministic quality score".to_string(),
                    "score components".to_string(),
                    "evidence reference summaries".to_string(),
                    "suggested improvements".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "skill id".to_string(),
                    "skill name".to_string(),
                    "agent".to_string(),
                    "scope".to_string(),
                    "quality score".to_string(),
                    "quality grade and band".to_string(),
                    "component scores and summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "suggested improvement titles and details".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                ]);
                sections.push(render_quality_score_prompt_section(&score, &mut redactor));
            }
            LlmPromptActionKind::StaleDriftDetection => {
                let detection = self.detect_stale_drift(DetectStaleDriftParams {
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                    stale_days: None,
                    thresholds: StaleDriftThresholds::default(),
                })?;
                prompt_scope.extend([
                    "deterministic stale and drift signals".to_string(),
                    "skill identity summaries".to_string(),
                    "readiness impact notes".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "stale/drift scores and bands".to_string(),
                    "fingerprint, finding, source, and mtime-derived signals".to_string(),
                    "readiness impact summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_stale_drift_prompt_section(&detection, &mut redactor));
            }
            LlmPromptActionKind::KnowledgeSearch => {
                let result = self.search_knowledge(KnowledgeSearchParams {
                    query: params.user_intent.clone(),
                    agent: None,
                    limit: Some(8),
                    risk: None,
                    scope: None,
                    enabled: None,
                    tool: None,
                    keyword: None,
                })?;
                prompt_scope.extend([
                    "deterministic local knowledge rows".to_string(),
                    "search filters and facets".to_string(),
                    "quality/readiness/stale-drift context".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted search query".to_string(),
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "matched fields and match reasons".to_string(),
                    "keywords, tools, rules, capability tags, and risk tags".to_string(),
                    "quality/readiness/stale-drift summaries".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response artifacts".to_string(),
                ]);
                sections.push(render_knowledge_search_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::SimilarSkillGrouping => {
                let result = self.group_similar_skills(SimilarSkillGroupingParams {
                    agent: None,
                    limit: Some(8),
                    min_score: None,
                    include_singletons: false,
                    candidate_instance_ids: params.instance_ids.clone(),
                })?;
                prompt_scope.extend([
                    "deterministic similar skill groups".to_string(),
                    "group similarity and ambiguity signals".to_string(),
                    "member quality and stale-drift context".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "group ids and group types".to_string(),
                    "canonical names and keys".to_string(),
                    "similarity, ambiguity, redundancy, and routing ambiguity bands".to_string(),
                    "shared terms, tools, rules, capability, risk, and source signals".to_string(),
                    "member skill names, agents, scopes, enabled states, and local contexts"
                        .to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_similar_skill_grouping_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::TaskReadiness => {
                let task = params.user_intent.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt task_readiness requires user_intent/task".to_string(),
                    )
                })?;
                let readiness = self.check_task_readiness(TaskReadinessParams {
                    task: task.to_string(),
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                })?;
                prompt_scope.extend([
                    "deterministic task readiness score".to_string(),
                    "candidate skill summaries".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task intent".to_string(),
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "readiness scores and bands".to_string(),
                    "quality score summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                ]);
                sections.push(render_task_readiness_prompt_section(
                    &readiness,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RoutingConfidence => {
                let task = params.user_intent.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt routing_confidence requires user_intent/task"
                            .to_string(),
                    )
                })?;
                let ranking = self.rank_skill_routes(RankSkillRoutesParams {
                    task: task.to_string(),
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                })?;
                prompt_scope.extend([
                    "deterministic routing confidence score".to_string(),
                    "ordered route candidates".to_string(),
                    "confidence rationale".to_string(),
                    "ambiguity and wrong-pick risks".to_string(),
                    "miss risks".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task intent".to_string(),
                    "ranked candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "routing confidence scores and bands".to_string(),
                    "readiness and quality score summaries".to_string(),
                    "ambiguity, wrong-pick, and miss risks".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                ]);
                sections.push(render_routing_confidence_prompt_section(
                    &ranking,
                    &mut redactor,
                ));
            }
        }

        sections.push("Required output: concise draft guidance with evidence notes, uncertainty, and safe next steps. Mark all suggestions copy-only.".to_string());
        let estimated_output_tokens = match params.action {
            LlmPromptActionKind::Analyze => 700,
            LlmPromptActionKind::Recommend => 500,
            LlmPromptActionKind::ExplainConflict => 650,
            LlmPromptActionKind::DraftFrontmatter => 450,
            LlmPromptActionKind::SkillAnalysis => params
                .analysis_kind
                .unwrap_or(LlmSkillAnalysisKind::Overview)
                .output_token_estimate(),
            LlmPromptActionKind::QualityScore => 650,
            LlmPromptActionKind::StaleDriftDetection => 750,
            LlmPromptActionKind::KnowledgeSearch => 750,
            LlmPromptActionKind::SimilarSkillGrouping => 850,
            LlmPromptActionKind::TaskReadiness => 750,
            LlmPromptActionKind::RoutingConfidence => 850,
        };
        let prompt_preview = sections.join("\n\n");
        let redaction = redactor.summary();

        Ok(BuiltLlmPrompt {
            prompt_preview,
            prompt_scope,
            included_fields,
            excluded_fields,
            redaction,
            estimated_output_tokens,
        })
    }

    fn render_skill_prompt_section(
        &self,
        skill: &SkillDetailRecord,
        redactor: &mut PromptRedactor<'_>,
    ) -> Result<String, ServiceError> {
        let findings = self.llm_findings_for_skill(skill)?;
        let finding_lines = if findings.is_empty() {
            "none".to_string()
        } else {
            findings
                .iter()
                .take(12)
                .map(|finding| {
                    format!(
                        "- {} severity={} message={} suggestion={}",
                        redactor.redact(&finding.rule_id),
                        redactor.redact(&finding.severity),
                        redactor.redact(&finding.message),
                        finding
                            .suggestion
                            .as_deref()
                            .map(|suggestion| redactor.redact(suggestion))
                            .unwrap_or_else(|| "none".to_string())
                    )
                })
                .collect::<Vec<_>>()
                .join("\n")
        };
        Ok(format!(
            "Selected skill:\n- id: {}\n- name: {}\n- agent: {}\n- scope: {}\n- enabled: {}\n- description: {}\n\nRedacted frontmatter:\n{}\n\nRedacted body:\n{}\n\nRelated findings:\n{}",
            redactor.redact(&skill.id),
            redactor.redact(&skill.name),
            redactor.redact(&skill.agent),
            redactor.redact(&skill.scope),
            skill.enabled,
            redactor.redact(&skill.description),
            redactor.redact(&skill.frontmatter_raw),
            redactor.redact(&skill.body),
            finding_lines
        ))
    }

    fn render_skill_analysis_prompt_sections(
        &self,
        params: &LlmPreviewPromptParams,
        redactor: &mut PromptRedactor<'_>,
    ) -> Result<String, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(format!(
                "Selected skill count: {}\nIncluded skills: 0\nMissing or excluded selections: {}",
                params.instance_ids.len(),
                params.instance_ids.len()
            ));
        };
        let mut sections = Vec::new();
        let mut included_count = 0usize;
        for instance_id in &params.instance_ids {
            let Some(skill) = catalog.get_skill_detail(instance_id)? else {
                continue;
            };
            included_count += 1;
            sections.push(self.render_skill_prompt_section(&skill, redactor)?);
        }
        let missing_count = params.instance_ids.len().saturating_sub(included_count);
        let mut header = format!(
            "Selected skill count: {}\nIncluded skills: {included_count}\nMissing or excluded selections: {missing_count}",
            params.instance_ids.len()
        );
        if sections.is_empty() {
            header.push_str("\nNo selected skill details were available.");
            Ok(header)
        } else {
            Ok(format!("{header}\n\n{}", sections.join("\n\n---\n\n")))
        }
    }

    fn llm_findings_for_skill(
        &self,
        skill: &SkillDetailRecord,
    ) -> Result<Vec<RuleFindingRecord>, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(Vec::new());
        };
        Ok(catalog
            .list_rule_findings()?
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect())
    }

    pub fn prepare_llm_action(
        &self,
        params: LlmPrepareActionParams,
    ) -> Result<LlmPrepareActionResult, ServiceError> {
        let status = self.llm_status();
        let action = params.kind;
        let mut prompt_scope = vec!["operation metadata".to_string()];
        let (estimated_input_tokens, review_preview) = match action {
            LlmActionKind::Analyze | LlmActionKind::DraftFrontmatter => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(format!(
                        "llm.prepareAction {} requires skill_instance_id",
                        action.as_str()
                    ))
                })?;
                let skill = self.get_llm_skill_detail(instance_id)?;
                prompt_scope.extend([
                    "selected skill name".to_string(),
                    "selected skill description".to_string(),
                    "selected skill frontmatter".to_string(),
                    "selected skill body".to_string(),
                ]);
                let review_preview = self.llm_skill_review_preview(&skill)?;
                (
                    estimate_tokens(&[
                        action.as_str(),
                        &skill.name,
                        &skill.description,
                        &skill.frontmatter_raw,
                        &skill.body,
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    review_preview,
                )
            }
            LlmActionKind::Recommend => {
                prompt_scope.extend([
                    "user intent".to_string(),
                    "catalog recommendation constraints".to_string(),
                ]);
                (
                    estimate_tokens(&[
                        action.as_str(),
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    self.llm_recommendation_review_preview(params.user_intent.as_deref()),
                )
            }
            LlmActionKind::ExplainConflict => {
                prompt_scope.extend([
                    "current conflict summaries".to_string(),
                    "current rule finding summaries".to_string(),
                ]);
                let summary = self.llm_conflict_summary()?;
                (
                    estimate_tokens(&[
                        action.as_str(),
                        &summary,
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    self.llm_conflict_review_preview(&summary),
                )
            }
        };
        let estimated_output_tokens = match action {
            LlmActionKind::Analyze => 700,
            LlmActionKind::Recommend => 500,
            LlmActionKind::ExplainConflict => 650,
            LlmActionKind::DraftFrontmatter => 450,
        };
        let estimated_total_tokens = estimated_input_tokens
            .saturating_add(estimated_output_tokens)
            .min(status.single_request_token_limit);
        let reason = status.reason.clone();

        Ok(LlmPrepareActionResult {
            action: action.as_str(),
            allowed: status.enabled && status.configured,
            reason: reason.clone(),
            disabled_reason: Some(reason.clone()),
            requires_confirmation: true,
            write_back_allowed: false,
            draft_requires_user_copy: true,
            provider: status.provider.clone(),
            model: status.model.clone(),
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            estimated_cost_usd: 0.0,
            single_request_token_limit: status.single_request_token_limit,
            monthly_budget_usd: status.monthly_budget_usd,
            credentials_storage: status.credentials_storage.clone(),
            credential_persistence_allowed: status.credential_persistence_allowed,
            prompt_scope,
            privacy_notes: vec![
                "No credentials are read, logged, stored in SQLite, or written to the project directory.".to_string(),
                "This method does not execute a provider request and performs no network I/O.".to_string(),
                "Any future LLM output must remain a draft; writes require explicit user copy or a separate non-LLM write action.".to_string(),
            ],
            confirmation: LlmConfirmationRequirement {
                required: true,
                message: "User confirmation is required before any future LLM provider request."
                    .to_string(),
                display_fields: vec![
                    "provider",
                    "model",
                    "estimated_total_tokens",
                    "estimated_cost_usd",
                    "prompt_scope",
                ],
            },
            review_preview,
        })
    }

    pub fn prepare_llm_skill_analysis(
        &self,
        params: LlmPrepareSkillAnalysisParams,
    ) -> Result<LlmPrepareSkillAnalysisResult, ServiceError> {
        let status = self.llm_status();
        let selected_skill_count = params.instance_ids.len();
        let mut included_skills = Vec::new();
        let mut estimate_parts = vec![params.analysis_kind.as_str().to_string()];
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            let disabled_reason = status.reason.clone();
            let prompt_draft = skill_analysis_prompt_draft(
                params.analysis_kind,
                selected_skill_count,
                &included_skills,
                selected_skill_count,
            );
            let summary_draft = skill_analysis_summary_draft(
                params.analysis_kind,
                selected_skill_count,
                &included_skills,
                selected_skill_count,
            );
            let estimated_input_tokens = estimate_tokens(&[&prompt_draft, &summary_draft]);
            let estimated_output_tokens = params.analysis_kind.output_token_estimate();
            let estimated_total_tokens = estimated_input_tokens
                .saturating_add(estimated_output_tokens)
                .min(status.single_request_token_limit);
            return Ok(LlmPrepareSkillAnalysisResult {
                enabled: false,
                disabled_reason,
                analysis_kind: params.analysis_kind.as_str(),
                selected_skill_count,
                included_skill_count: 0,
                excluded_missing_count: selected_skill_count,
                included_skills,
                prompt_draft,
                summary_draft,
                safety_flags: llm_skill_analysis_safety_flags(),
                estimated_input_tokens,
                estimated_output_tokens,
                estimated_total_tokens,
                provider_request_sent: false,
                generated_by: "deterministic-service",
            });
        };

        for instance_id in &params.instance_ids {
            let Some(detail) = catalog.get_skill_detail(instance_id)? else {
                continue;
            };
            estimate_parts.extend([
                detail.name.clone(),
                detail.agent.clone(),
                detail.scope.clone(),
                detail.description.clone(),
                detail.frontmatter_raw.clone(),
                detail.body.clone(),
            ]);
            included_skills.push(LlmSkillAnalysisIncludedSkill {
                instance_id: detail.id,
                name: detail.name,
                agent: detail.agent,
                scope: detail.scope,
                enabled: detail.enabled,
                disabled_reason: if detail.enabled {
                    None
                } else {
                    Some("Skill is disabled in the current catalog state.".to_string())
                },
            });
        }

        let excluded_missing_count = selected_skill_count.saturating_sub(included_skills.len());
        let prompt_draft = skill_analysis_prompt_draft(
            params.analysis_kind,
            selected_skill_count,
            &included_skills,
            excluded_missing_count,
        );
        let summary_draft = skill_analysis_summary_draft(
            params.analysis_kind,
            selected_skill_count,
            &included_skills,
            excluded_missing_count,
        );
        estimate_parts.extend([prompt_draft.clone(), summary_draft.clone()]);
        let estimate_refs = estimate_parts
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>();
        let estimated_input_tokens = estimate_tokens(&estimate_refs);
        let estimated_output_tokens = params.analysis_kind.output_token_estimate();
        let estimated_total_tokens = estimated_input_tokens
            .saturating_add(estimated_output_tokens)
            .min(status.single_request_token_limit);

        Ok(LlmPrepareSkillAnalysisResult {
            enabled: false,
            disabled_reason: status.reason,
            analysis_kind: params.analysis_kind.as_str(),
            selected_skill_count,
            included_skill_count: included_skills.len(),
            excluded_missing_count,
            included_skills,
            prompt_draft,
            summary_draft,
            safety_flags: llm_skill_analysis_safety_flags(),
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            provider_request_sent: false,
            generated_by: "deterministic-service",
        })
    }

    fn llm_skill_review_preview(
        &self,
        skill: &SkillDetailRecord,
    ) -> Result<LlmReviewPreview, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(LlmReviewPreview::unavailable());
        };
        let findings = catalog.list_rule_findings()?;
        let related_findings: Vec<RuleFindingRecord> = findings
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect();
        let records = catalog.list_skill_records()?;
        let comparable_instance_count = records
            .iter()
            .filter(|record| record.definition_id == skill.definition_id && record.id != skill.id)
            .count();
        let finding_explanations = related_findings
            .iter()
            .take(8)
            .map(|finding| LlmReviewFindingExplanation {
                rule_id: finding.rule_id.clone(),
                severity: finding.severity.clone(),
                explanation: redact_for_llm_preview(&finding.message),
                suggested_next_step: finding.suggestion.as_deref().map(redact_for_llm_preview),
            })
            .collect::<Vec<_>>();
        let risk = llm_review_risk(&related_findings, &skill.frontmatter_raw, &skill.body);
        let description = redact_for_llm_preview(&skill.description);
        let purpose = if description.is_empty() {
            format!(
                "Offline review preview for `{}`. No body text is returned; purpose is inferred from catalog name and metadata only.",
                redact_for_llm_preview(&skill.name)
            )
        } else {
            format!(
                "{} Offline review only; no provider request was sent and skill body content is not returned.",
                description
            )
        };
        let cross_summary = if comparable_instance_count == 0 {
            "No other cataloged agent instance shares this definition id in the current catalog."
                .to_string()
        } else {
            format!(
                "{comparable_instance_count} other cataloged instance(s) share this definition id; review adapter-specific permissions and enablement before copying behavior across agents."
            )
        };
        Ok(LlmReviewPreview {
            status: "offline-preview",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose,
            risk,
            finding_explanations,
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: skill.agent.clone(),
                scope: skill.scope.clone(),
                comparable_instance_count,
                summary: cross_summary,
                notes: vec![
                    "Cross-agent fit is advisory and read-only; this response cannot install, import, toggle, or edit skills.".to_string(),
                    "Adapter compatibility is based only on current catalog metadata, not provider-generated recommendations.".to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        })
    }

    fn llm_recommendation_review_preview(&self, user_intent: Option<&str>) -> LlmReviewPreview {
        let intent = redact_for_llm_preview(user_intent.unwrap_or_default());
        let purpose = if intent.is_empty() {
            "Prepared an offline recommendation preflight without reading skill bodies or calling a provider.".to_string()
        } else {
            format!(
                "Prepared an offline recommendation preflight for the supplied intent: {intent}"
            )
        };
        LlmReviewPreview {
            status: "prepared-unavailable",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose,
            risk: LlmReviewRisk {
                level: "unknown",
                summary: "No selected skill was reviewed, so risk is not assessed.".to_string(),
                signals: vec![
                    "Recommendation prepare does not read arbitrary skill files or return catalog paths."
                        .to_string(),
                ],
            },
            finding_explanations: Vec::new(),
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: "catalog".to_string(),
                scope: "read-only-preflight".to_string(),
                comparable_instance_count: 0,
                summary:
                    "Cross-agent fit requires a selected catalog skill or current analysis groups."
                        .to_string(),
                notes: vec![
                    "No provider request was sent and no recommendation output was generated."
                        .to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        }
    }

    fn llm_conflict_review_preview(&self, summary: &str) -> LlmReviewPreview {
        LlmReviewPreview {
            status: "offline-preview",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose: "Prepared an offline conflict/finding explanation from catalog summaries only."
                .to_string(),
            risk: LlmReviewRisk {
                level: if summary.contains("severity=error") || summary.contains("severity=critical")
                {
                    "high"
                } else if summary.contains("finding rule=") {
                    "medium"
                } else {
                    "low"
                },
                summary: redact_for_llm_preview(summary),
                signals: vec![
                    "Conflict explain prepare uses rule ids, severity labels, definition ids, and counts; it does not return skill body text."
                        .to_string(),
                ],
            },
            finding_explanations: Vec::new(),
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: "catalog".to_string(),
                scope: "conflict-summary".to_string(),
                comparable_instance_count: 0,
                summary: "Cross-agent fit is represented by current conflict groups and definition ids only."
                    .to_string(),
                notes: vec![
                    "Resolve conflicts through existing explicit user actions; no Apply/Write path exists in this preview."
                        .to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        }
    }

    fn get_llm_skill_detail(&self, instance_id: &str) -> Result<SkillDetailRecord, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Err(ServiceError::SkillNotFound(instance_id.to_string()));
        };
        catalog
            .get_skill_detail(instance_id)?
            .ok_or_else(|| ServiceError::SkillNotFound(instance_id.to_string()))
    }

    fn llm_conflict_summary(&self) -> Result<String, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(
                "No catalog is available; no conflicts or findings were loaded.".to_string(),
            );
        };
        let conflicts = catalog.list_conflict_groups()?;
        let findings = catalog.list_rule_findings()?;
        let mut lines = Vec::new();
        for conflict in conflicts.iter().take(20) {
            lines.push(format!(
                "conflict reason={} definition_id={} instances={}",
                conflict.reason,
                conflict.definition_id,
                conflict.instance_ids.len()
            ));
        }
        for finding in findings.iter().take(20) {
            lines.push(format!(
                "finding rule={} severity={} has_instance={} has_suggestion={}",
                finding.rule_id,
                finding.severity,
                finding.instance_id.is_some(),
                finding.suggestion.is_some()
            ));
        }
        if lines.is_empty() {
            Ok("No current conflicts or findings were loaded.".to_string())
        } else {
            Ok(lines.join("\n"))
        }
    }

    fn open_catalog(&self) -> Result<Catalog, ServiceError> {
        fs::create_dir_all(&self.app_data_dir)?;
        let catalog = Catalog::open(&self.catalog_path())?;
        catalog.init()?;
        Ok(catalog)
    }

    fn open_existing_catalog_read_only(&self) -> Result<Option<Catalog>, ServiceError> {
        let catalog_path = self.catalog_path();
        if !catalog_path.exists() {
            return Ok(None);
        }
        Ok(Some(Catalog::open_read_only(&catalog_path)?))
    }

    fn catalog_path(&self) -> PathBuf {
        self.app_data_dir.join("catalog.sqlite")
    }

    fn script_execution_audit_path(&self) -> PathBuf {
        self.app_data_dir
            .join("audit")
            .join("script-execution.jsonl")
    }

    fn task_benchmarks_path(&self) -> PathBuf {
        self.app_data_dir.join("task-benchmarks.json")
    }

    fn routing_regression_baseline_path(&self) -> PathBuf {
        self.app_data_dir.join("task-routing-baseline.json")
    }

    fn trace_imports_path(&self) -> PathBuf {
        self.app_data_dir.join("trace-imports.json")
    }

    fn load_task_benchmarks(&self) -> Result<Vec<TaskBenchmarkRecord>, ServiceError> {
        let path = self.task_benchmarks_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut benchmarks: Vec<TaskBenchmarkRecord> = serde_json::from_str(&content)?;
        benchmarks.sort_by(|left, right| {
            left.title
                .cmp(&right.title)
                .then_with(|| left.id.cmp(&right.id))
        });
        Ok(benchmarks)
    }

    fn save_task_benchmarks(&self, benchmarks: &[TaskBenchmarkRecord]) -> Result<(), ServiceError> {
        fs::create_dir_all(&self.app_data_dir)?;
        let path = self.task_benchmarks_path();
        let content = serde_json::to_string_pretty(benchmarks)?;
        fs::write(path, content)?;
        Ok(())
    }

    fn load_routing_regression_baseline(
        &self,
    ) -> Result<Option<RoutingRegressionBaseline>, ServiceError> {
        let path = self.routing_regression_baseline_path();
        if !path.exists() {
            return Ok(None);
        }
        let content = fs::read_to_string(path)?;
        let baseline: RoutingRegressionBaseline = serde_json::from_str(&content)?;
        Ok(Some(baseline))
    }

    fn save_routing_regression_baseline(
        &self,
        baseline: &RoutingRegressionBaseline,
    ) -> Result<(), ServiceError> {
        fs::create_dir_all(&self.app_data_dir)?;
        let path = self.routing_regression_baseline_path();
        let content = serde_json::to_string_pretty(baseline)?;
        fs::write(path, content)?;
        Ok(())
    }

    fn load_trace_imports(&self) -> Result<Vec<TraceImportRecord>, ServiceError> {
        let path = self.trace_imports_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut imports: Vec<TraceImportRecord> = serde_json::from_str(&content)?;
        imports.sort_by(|left, right| {
            right
                .imported_at
                .cmp(&left.imported_at)
                .then_with(|| left.title.cmp(&right.title))
                .then_with(|| left.id.cmp(&right.id))
        });
        Ok(imports)
    }

    fn save_trace_imports(&self, imports: &[TraceImportRecord]) -> Result<(), ServiceError> {
        fs::create_dir_all(&self.app_data_dir)?;
        let path = self.trace_imports_path();
        let mut sorted = imports.to_vec();
        sorted.sort_by(|left, right| {
            right
                .imported_at
                .cmp(&left.imported_at)
                .then_with(|| left.title.cmp(&right.title))
                .then_with(|| left.id.cmp(&right.id))
        });
        let content = serde_json::to_string_pretty(&sorted)?;
        fs::write(path, content)?;
        Ok(())
    }

    fn trace_redaction_roots(&self, adapter_ctx: &AdapterContext) -> Vec<(String, &'static str)> {
        let mut roots = self.redaction_roots(adapter_ctx);
        roots.push((env::temp_dir().to_string_lossy().to_string(), "<temp-dir>"));
        roots.sort_by_key(|right| std::cmp::Reverse(right.0.len()));
        roots.dedup_by(|left, right| left.0 == right.0);
        roots
    }

    fn analyze_imported_trace(
        &self,
        content: &str,
        expected_skill_refs: &[String],
        expected_skill_names: &[String],
        agent_filter: Option<&str>,
    ) -> Result<TraceImportAnalysis, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            let mut reasons = vec![
                "No local catalog is available; imported trace was stored as redacted app-local metadata only."
                    .to_string(),
            ];
            if !expected_skill_refs.is_empty() || !expected_skill_names.is_empty() {
                reasons.push(
                    "Expected skill refs/names were provided but could not be checked without catalog evidence."
                        .to_string(),
                );
            }
            return Ok(TraceImportAnalysis {
                generated_by: "deterministic-service".to_string(),
                catalog_available: false,
                outcome: "unknown".to_string(),
                reasons,
                detected_skills: Vec::new(),
                evidence_refs: Vec::new(),
            });
        };

        let content_lower = content.to_ascii_lowercase();
        let expected_refs = expected_skill_refs
            .iter()
            .map(|value| value.to_ascii_lowercase())
            .collect::<Vec<_>>();
        let expected_names = expected_skill_names
            .iter()
            .map(|value| value.to_ascii_lowercase())
            .collect::<Vec<_>>();
        let mut detected = Vec::new();
        for skill in self.list_visible_skill_records(&catalog)? {
            if agent_filter.is_some_and(|agent| !agent.is_empty() && skill.agent != agent) {
                continue;
            }
            let mut match_terms = Vec::new();
            for term in [
                skill.id.as_str(),
                skill.definition_id.as_str(),
                skill.name.as_str(),
            ] {
                let normalized = term.trim();
                if normalized.len() < 3 {
                    continue;
                }
                let normalized_lower = normalized.to_ascii_lowercase();
                if content_lower.contains(&normalized_lower)
                    && !match_terms.iter().any(|item| item == normalized)
                {
                    match_terms.push(normalized.to_string());
                }
            }
            if !match_terms.is_empty() {
                detected.push(TraceDetectedSkill {
                    instance_id: skill.id.clone(),
                    definition_id: skill.definition_id.clone(),
                    skill_name: skill.name.clone(),
                    agent: skill.agent.clone(),
                    scope: skill.scope.clone(),
                    evidence_refs: vec![format!("skill:{}", skill.id)],
                    match_terms,
                });
            }
        }
        detected.sort_by(|left, right| {
            left.agent
                .cmp(&right.agent)
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });

        let expected_present = !expected_refs.is_empty() || !expected_names.is_empty();
        let matching_expected = detected
            .iter()
            .filter(|skill| {
                expected_refs.iter().any(|expected| {
                    expected == &skill.instance_id.to_ascii_lowercase()
                        || expected == &skill.definition_id.to_ascii_lowercase()
                }) || expected_names
                    .iter()
                    .any(|expected| expected == &skill.skill_name.to_ascii_lowercase())
            })
            .count();
        let unexpected_detected = detected.len().saturating_sub(matching_expected);
        let outcome = if !expected_present {
            if detected.len() > 1 {
                "ambiguous"
            } else {
                "unknown"
            }
        } else if detected.is_empty() {
            "miss"
        } else if matching_expected == 0 {
            "wrong_pick"
        } else if unexpected_detected > 0 {
            "ambiguous"
        } else {
            "hit"
        };
        let reasons = trace_outcome_reasons(
            outcome,
            detected.len(),
            matching_expected,
            unexpected_detected,
            expected_present,
            agent_filter,
        );
        let mut evidence_refs = detected
            .iter()
            .flat_map(|skill| skill.evidence_refs.clone())
            .collect::<Vec<_>>();
        evidence_refs.sort();
        evidence_refs.dedup();
        Ok(TraceImportAnalysis {
            generated_by: "deterministic-service".to_string(),
            catalog_available: true,
            outcome: outcome.to_string(),
            reasons,
            detected_skills: detected,
            evidence_refs,
        })
    }

    fn tool_global_staging_root(&self) -> PathBuf {
        self.app_data_dir.join("tool-global")
    }

    fn redaction_roots(&self, adapter_ctx: &AdapterContext) -> Vec<(String, &'static str)> {
        let mut roots = vec![
            (
                self.app_data_dir.to_string_lossy().to_string(),
                "<app-data-dir>",
            ),
            (adapter_ctx.user_home.to_string_lossy().to_string(), "$HOME"),
        ];
        if let Some(project_root) = adapter_ctx.project_root.as_ref() {
            roots.push((project_root.to_string_lossy().to_string(), "<project-root>"));
        }
        if let Some(project_cwd) = adapter_ctx.project_cwd.as_ref() {
            roots.push((project_cwd.to_string_lossy().to_string(), "<project-cwd>"));
        }
        roots.sort_by_key(|right| std::cmp::Reverse(right.0.len()));
        roots.dedup_by(|left, right| left.0 == right.0);
        roots
    }

    fn effective_adapter_ctx(&self) -> Result<AdapterContext, ServiceError> {
        if self.has_env_project_context() {
            return Ok(self.adapter_ctx.clone());
        }

        let Some((root_path, current_cwd)) = stored_active_adapter_paths(&self.app_data_dir)?
        else {
            return Ok(self.adapter_ctx.clone());
        };

        let mut ctx = self.adapter_ctx.clone();
        ctx.project_root = Some(root_path);
        ctx.project_cwd = Some(current_cwd);
        Ok(ctx)
    }

    fn has_env_project_context(&self) -> bool {
        self.adapter_ctx.project_root.is_some() || self.adapter_ctx.project_cwd.is_some()
    }

    fn env_project_context(&self) -> Option<ProjectContext> {
        let root = self.adapter_ctx.project_root.as_ref()?;
        let cwd = self.adapter_ctx.project_cwd.as_deref().unwrap_or(root);
        Some(context_from_paths(root, cwd, true))
    }

    fn status_adapter_ctx(&self) -> AdapterContext {
        self.effective_adapter_ctx()
            .unwrap_or_else(|_| self.adapter_ctx.clone())
    }

    fn scan_activity(
        &self,
        operation: &'static str,
        scan_label: &str,
        roots: Vec<PathBuf>,
        started_at: i64,
        counts: ScanActivityCounts,
        agent_summaries: Option<Vec<AgentRefreshSummary>>,
    ) -> RefreshActivity {
        let roots_count = roots.len();
        let mut log_entries = vec![
            RefreshLogEntry {
                level: "info",
                message: format!("Queued {scan_label} scan across {roots_count} root(s)."),
            },
            RefreshLogEntry {
                level: "info",
                message: format!(
                    "Catalog refresh completed with {} skill(s), {} finding(s), and {} conflict group(s).",
                    counts.skill_count, counts.finding_count, counts.conflict_count
                ),
            },
        ];
        if counts.scanned_count == 0 {
            log_entries.push(RefreshLogEntry {
                level: "warning",
                message: format!(
                    "No skills were discovered for {scan_label}. Check the configured roots, then retry Scan."
                ),
            });
        }
        if let Some(summaries) = &agent_summaries {
            log_entries.extend(summaries.iter().map(|summary| {
                let level = if summary.roots_scanned.is_empty() {
                    "warning"
                } else {
                    "info"
                };
                let skipped_detail = skipped_roots_detail(&summary.roots_skipped);
                RefreshLogEntry {
                    level,
                    message: format!(
                        "{} discovered {} skill(s); catalog now has {} skill(s), {} broken, across {} scanned root(s) and {} skipped root(s){}.",
                        summary.display_label,
                        summary.scanned_count,
                        summary.catalog_count,
                        summary.broken_count,
                        summary.roots_scanned.len(),
                        summary.roots_skipped.len(),
                        skipped_detail
                    ),
                }
            }));
        }

        RefreshActivity {
            operation,
            status: "completed",
            started_at,
            finished_at: unix_timestamp_millis(),
            scanned_count: counts.scanned_count,
            skill_count: counts.skill_count,
            finding_count: counts.finding_count,
            conflict_count: counts.conflict_count,
            snapshot_count: counts.snapshot_count,
            roots: roots.into_iter().map(|path| display_path(&path)).collect(),
            log_entries,
            recovery_actions: vec![
                "Retry Scan if the catalog looks stale.".to_string(),
                "Use Reload to re-read the current catalog without touching agent files."
                    .to_string(),
            ],
            agent_summaries,
        }
    }

    fn agent_refresh_summaries(
        &self,
        agent_reports: &[AgentCatalogScanReport],
        skills: &[SkillRecord],
        adapter_diagnostics: &[AdapterDiagnosticsRecord],
    ) -> Vec<AgentRefreshSummary> {
        agent_reports
            .iter()
            .map(|agent_report| {
                let agent = agent_report.agent.as_str();
                let diagnostics = adapter_diagnostics
                    .iter()
                    .find(|diagnostics| diagnostics.agent == agent);
                let catalog_count = skills.iter().filter(|skill| skill.agent == agent).count();
                let broken_count = skills
                    .iter()
                    .filter(|skill| skill.agent == agent && skill.state == "broken")
                    .count();
                let recovery_actions = if agent_report.scanned_roots.is_empty() {
                    vec![format!(
                        "Create a {} skills root or check skipped-root permissions, then retry Scan.",
                        agent_report.display_name
                    )]
                } else {
                    Vec::new()
                };
                AgentRefreshSummary {
                    agent: agent.to_string(),
                    display_label: agent_report.display_name.to_string(),
                    status: if agent_report.scanned_roots.is_empty() {
                        "completed-no-roots-scanned"
                    } else {
                        "completed"
                    },
                    scanned_count: agent_report.scanned_count,
                    catalog_count,
                    broken_count,
                    roots_considered: agent_report
                        .roots_considered
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    roots_scanned: agent_report
                        .scanned_roots
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    roots_skipped: agent_report
                        .skipped_roots
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    config_detected: diagnostics
                        .is_some_and(|diagnostics| diagnostics.config.detected_count > 0),
                    config_paths: diagnostics
                        .map(|diagnostics| {
                            diagnostics
                                .config
                                .paths
                                .iter()
                                .map(|path| path.path.clone())
                                .collect()
                        })
                        .unwrap_or_default(),
                    writable_status: diagnostics
                        .map(|diagnostics| diagnostics.access.writable_status.to_string())
                        .unwrap_or_else(|| "unknown".to_string()),
                    writable_reason: diagnostics
                        .and_then(|diagnostics| diagnostics.access.writable_reason)
                        .map(str::to_string),
                    read_only_reason: diagnostics
                        .map(|diagnostics| diagnostics.access.read_only_reason.clone())
                        .unwrap_or_else(|| "Adapter diagnostics were unavailable.".to_string()),
                    blockers: diagnostics
                        .map(|diagnostics| {
                            diagnostics
                                .blockers
                                .iter()
                                .map(|blocker| (*blocker).to_string())
                                .collect()
                        })
                        .unwrap_or_default(),
                    recovery_actions,
                }
            })
            .collect()
    }

    fn claude_root_paths(&self) -> Vec<PathBuf> {
        let mut roots = vec![self.adapter_ctx.user_home.join(".claude").join("skills")];
        roots.extend(
            self.adapter_ctx
                .extra_roots
                .iter()
                .map(|root| root.path.clone()),
        );
        roots
    }
}

fn scan_all_label(agent_reports: &[AgentCatalogScanReport]) -> String {
    let labels: Vec<&str> = agent_reports
        .iter()
        .map(|report| report.display_name)
        .collect();
    display_label_list(&labels).unwrap_or_else(|| "supported agents".to_string())
}

fn display_label_list(labels: &[&str]) -> Option<String> {
    match labels {
        [] => None,
        [one] => Some((*one).to_string()),
        [first, second] => Some(format!("{first} and {second}")),
        _ => {
            let mut label = labels[..labels.len() - 1].join(", ");
            label.push_str(", and ");
            label.push_str(labels[labels.len() - 1]);
            Some(label)
        }
    }
}

fn skipped_roots_detail(roots_skipped: &[String]) -> String {
    if roots_skipped.is_empty() {
        return String::new();
    }
    let mut detail = format!("; root-error skipped-root path(s): {}", roots_skipped[0]);
    if roots_skipped.len() > 1 {
        detail.push_str(&format!(" (+{} more)", roots_skipped.len() - 1));
    }
    detail
}

pub fn handle_request_json(input: &str) -> String {
    let response = match serde_json::from_str::<ServiceRequest>(input) {
        Ok(request) => match ServiceHost::from_env() {
            Ok(host) => host.handle(request),
            Err(error) => ServiceResponse {
                id: None,
                ok: false,
                result: None,
                error: Some(ServiceErrorRecord {
                    code: error.code().to_string(),
                    message: error.to_string(),
                }),
            },
        },
        Err(error) => ServiceResponse {
            id: None,
            ok: false,
            result: None,
            error: Some(ServiceErrorRecord {
                code: "parse_error".to_string(),
                message: error.to_string(),
            }),
        },
    };
    serde_json::to_string(&response).unwrap_or_else(|error| {
        json!({
            "id": null,
            "ok": false,
            "error": {
                "code": "serialize_error",
                "message": error.to_string()
            }
        })
        .to_string()
    })
}

fn default_app_data_dir(user_home: &Path) -> PathBuf {
    if cfg!(target_os = "macos") {
        user_home
            .join("Library")
            .join("Application Support")
            .join(DEFAULT_BUNDLE_ID)
    } else {
        user_home.join(".skills-copilot").join(DEFAULT_BUNDLE_ID)
    }
}

fn infer_project_root(cwd: &Path) -> PathBuf {
    let mut current = Some(cwd);
    while let Some(dir) = current {
        if dir.join(".git").exists() {
            return dir.to_path_buf();
        }
        current = dir.parent();
    }
    cwd.to_path_buf()
}

fn extra_claude_roots_from_env() -> Vec<AdapterRoot> {
    let Some(raw) = env::var_os("SKILLS_COPILOT_CLAUDE_EXTRA_ROOTS") else {
        return Vec::new();
    };
    env::split_paths(&raw)
        .map(|path| AdapterRoot {
            scope: Scope::AgentGlobal,
            path,
            source: RootSource::Extra,
        })
        .collect()
}

fn display_path(path: &Path) -> String {
    path.to_string_lossy().to_string()
}

fn report_export_formats(mut formats: Vec<ReportExportFormat>) -> Vec<ReportExportFormat> {
    if formats.is_empty() {
        formats = vec![ReportExportFormat::Json, ReportExportFormat::Markdown];
    }
    let mut seen = Vec::new();
    formats
        .into_iter()
        .filter(|format| {
            if seen.contains(format) {
                false
            } else {
                seen.push(*format);
                true
            }
        })
        .collect()
}

fn report_export_redaction() -> ReportExportRedaction {
    ReportExportRedaction {
        enabled: true,
        placeholders: vec!["$HOME", "<project-root>", "<project-cwd>", "<app-data-dir>"],
        path_policy:
            "Local home, app data, and active project path prefixes are replaced before writing report files.",
    }
}

fn report_export_summary(
    skills: &Value,
    findings: &Value,
    triage: &Value,
    cleanup: &Value,
    comparison: &Value,
) -> ReportExportSummary {
    let finding_items = findings.as_array().map(Vec::len).unwrap_or_default();
    ReportExportSummary {
        skill_count: skills.as_array().map(Vec::len).unwrap_or_default(),
        finding_count: finding_items,
        open_finding_count: findings
            .as_array()
            .map(|items| {
                items
                    .iter()
                    .filter(|finding| {
                        finding
                            .get("triage_status")
                            .and_then(Value::as_str)
                            .is_none_or(|status| status == "open")
                            && !finding
                                .get("suppressed")
                                .and_then(Value::as_bool)
                                .unwrap_or(false)
                    })
                    .count()
            })
            .unwrap_or_default(),
        triage_count: triage.as_array().map(Vec::len).unwrap_or_default(),
        cleanup_item_count: cleanup
            .get("items")
            .and_then(Value::as_array)
            .map(Vec::len)
            .unwrap_or_default(),
        comparison_group_count: comparison
            .get("groups")
            .and_then(Value::as_array)
            .map(Vec::len)
            .unwrap_or_default(),
    }
}

fn empty_health_summary_json() -> Value {
    json!({
        "total_count": 0,
        "enabled_count": 0,
        "disabled_count": 0,
        "broken_count": 0,
        "missing_count": 0,
        "malformed_count": 0,
        "finding_count": 0,
        "conflict_count": 0,
        "risky_script_count": 0,
        "risky_permission_count": 0,
        "findings_by_severity": {
            "error_count": 0,
            "warning_count": 0,
            "info_count": 0
        },
        "analysis_groups": {
            "total_count": 0,
            "error_count": 0,
            "warning_count": 0,
            "info_count": 0,
            "duplicate_name_count": 0,
            "canonical_name_count": 0,
            "path_overlap_count": 0,
            "enabled_mismatch_count": 0,
            "malformed_count": 0,
            "precedence_count": 0
        },
        "agent_summaries": []
    })
}

fn empty_cross_agent_analysis_json() -> Value {
    json!({
        "summary": {
            "total_groups": 0,
            "duplicate_name_groups": 0,
            "canonical_name_groups": 0,
            "path_overlap_groups": 0,
            "enabled_mismatch_groups": 0,
            "malformed_groups": 0,
            "precedence_groups": 0,
            "affected_skill_count": 0
        },
        "groups": []
    })
}

fn redact_report_value(value: &mut Value, roots: &[(String, &'static str)]) {
    match value {
        Value::String(text) => {
            *text = redact_string(text, roots);
        }
        Value::Array(items) => {
            for item in items {
                redact_report_value(item, roots);
            }
        }
        Value::Object(object) => {
            for item in object.values_mut() {
                redact_report_value(item, roots);
            }
        }
        Value::Null | Value::Bool(_) | Value::Number(_) => {}
    }
}

fn redact_path_string(path: &Path, roots: &[(String, &'static str)]) -> String {
    redact_string(&path.to_string_lossy(), roots)
}

fn redact_string(value: &str, roots: &[(String, &'static str)]) -> String {
    let mut redacted = value.to_string();
    for (root, placeholder) in roots {
        if !root.is_empty() {
            redacted = redacted.replace(root, placeholder);
        }
    }
    redacted
}

fn render_report_markdown(report: &Value) -> String {
    let summary = report.get("summary").unwrap_or(&Value::Null);
    let safety = report.get("safety").unwrap_or(&Value::Null);
    let health = report.get("health").unwrap_or(&Value::Null);
    let cleanup = report.get("cleanup_queue").unwrap_or(&Value::Null);
    let comparison = report
        .pointer("/cross_agent/comparison/summary")
        .unwrap_or(&Value::Null);
    let mut markdown = String::new();
    markdown.push_str("# Skills Copilot Local Report\n\n");
    markdown.push_str(&format!(
        "- Export ID: {}\n",
        report_string(report, "/export_id")
    ));
    markdown.push_str(&format!(
        "- Generated at: {}\n",
        report_string(report, "/generated_at")
    ));
    markdown.push_str(&format!(
        "- Catalog available: {}\n\n",
        report_string(report, "/catalog_available")
    ));
    markdown.push_str("## Safety\n\n");
    markdown.push_str(&format!(
        "- Read-only: {}\n- Writes allowed: {}\n- Provider request sent: {}\n- Script execution allowed: {}\n- Credential accessed: {}\n\n",
        json_field_string(safety, "read_only"),
        json_field_string(safety, "writes_allowed"),
        json_field_string(safety, "provider_request_sent"),
        json_field_string(safety, "script_execution_allowed"),
        json_field_string(safety, "credential_accessed")
    ));
    markdown.push_str("## Summary\n\n");
    for key in [
        "skill_count",
        "finding_count",
        "open_finding_count",
        "triage_count",
        "cleanup_item_count",
        "comparison_group_count",
    ] {
        markdown.push_str(&format!("- {}: {}\n", key, json_field_string(summary, key)));
    }
    markdown.push_str("\n## Health\n\n");
    for key in [
        "total_count",
        "enabled_count",
        "disabled_count",
        "broken_count",
        "missing_count",
        "finding_count",
        "conflict_count",
    ] {
        markdown.push_str(&format!("- {}: {}\n", key, json_field_string(health, key)));
    }
    markdown.push_str("\n## Cleanup Queue\n\n");
    markdown.push_str(&format!(
        "- Total items: {}\n- Read-only: {}\n- Writes allowed: {}\n\n",
        report_string(cleanup, "/summary/total_count"),
        report_string(cleanup, "/summary/read_only"),
        report_string(cleanup, "/summary/writes_allowed")
    ));
    markdown.push_str("## Cross-agent Comparison\n\n");
    markdown.push_str(&format!(
        "- Total groups: {}\n- Returned groups: {}\n- Compared skill count: {}\n\n",
        json_field_string(comparison, "total_groups"),
        json_field_string(comparison, "returned_groups"),
        json_field_string(comparison, "compared_skill_count")
    ));
    markdown.push_str("## Redaction\n\n");
    markdown.push_str("- Path prefixes are replaced with `$HOME`, `<project-root>`, `<project-cwd>`, or `<app-data-dir>` before report files are written.\n");
    markdown
}

fn report_string(value: &Value, pointer: &str) -> String {
    value
        .pointer(pointer)
        .map(value_to_markdown_string)
        .unwrap_or_else(|| "n/a".to_string())
}

fn json_field_string(value: &Value, field: &str) -> String {
    value
        .get(field)
        .map(value_to_markdown_string)
        .unwrap_or_else(|| "n/a".to_string())
}

fn value_to_markdown_string(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Number(number) => number.to_string(),
        Value::Bool(flag) => flag.to_string(),
        Value::Null => "null".to_string(),
        Value::Array(items) => format!("{} item(s)", items.len()),
        Value::Object(object) => format!("{} field(s)", object.len()),
    }
}

fn is_pi_plain_markdown_catalog_noise(skill: &SkillRecord) -> bool {
    skill.agent == AgentId::Pi.as_str()
        && skill
            .path
            .extension()
            .and_then(|extension| extension.to_str())
            == Some("md")
        && skill.path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md")
}

fn is_pi_plain_markdown_instance_noise(skill: &SkillInstance) -> bool {
    skill.agent == AgentId::Pi
        && skill
            .path
            .extension()
            .and_then(|extension| extension.to_str())
            == Some("md")
        && skill.path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md")
}

fn unix_timestamp_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| i64::try_from(duration.as_millis()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

fn estimate_tokens(parts: &[&str]) -> u32 {
    let chars = parts.iter().map(|part| part.chars().count()).sum::<usize>();
    let estimated = chars.div_ceil(4).saturating_add(120);
    u32::try_from(estimated).unwrap_or(u32::MAX)
}

#[derive(Debug, Clone)]
struct BuiltLlmPrompt {
    prompt_preview: String,
    prompt_scope: Vec<String>,
    included_fields: Vec<String>,
    excluded_fields: Vec<String>,
    redaction: LlmPromptRedactionSummary,
    estimated_output_tokens: u32,
}

struct PromptRedactor<'a> {
    roots: &'a [(String, &'static str)],
    redacted_value_count: usize,
    redacted_fields: BTreeMap<String, ()>,
}

impl<'a> PromptRedactor<'a> {
    fn new(roots: &'a [(String, &'static str)]) -> Self {
        Self {
            roots,
            redacted_value_count: 0,
            redacted_fields: BTreeMap::new(),
        }
    }

    fn redact(&mut self, value: &str) -> String {
        let (path_redacted, path_count) = redact_with_count(value, self.roots);
        if path_count > 0 {
            self.redacted_value_count += path_count;
            self.redacted_fields.insert("local paths".to_string(), ());
        }
        let mut token_count = 0usize;
        let mut redact_next_token = false;
        let redacted = path_redacted
            .split_whitespace()
            .map(|token| {
                let trimmed = token.trim_matches(|ch: char| {
                    matches!(ch, '"' | '\'' | ',' | ';' | ')' | '(' | '[' | ']')
                });
                let lower = trimmed.to_lowercase();
                if redact_next_token {
                    redact_next_token = lower == "bearer";
                    token_count += 1;
                    "<redacted>"
                } else if lower.contains("key")
                    || lower.contains("token")
                    || lower.contains("secret")
                    || lower.contains("credential")
                    || lower.contains("password")
                    || lower == "authorization:"
                    || lower == "bearer"
                {
                    redact_next_token = !trimmed.contains('=');
                    token_count += 1;
                    "<redacted>"
                } else if lower.starts_with("http://") || lower.starts_with("https://") {
                    token_count += 1;
                    "<redacted-url>"
                } else {
                    token
                }
            })
            .collect::<Vec<_>>()
            .join(" ");
        if token_count > 0 {
            self.redacted_value_count += token_count;
            self.redacted_fields
                .insert("secret-like tokens and private URLs".to_string(), ());
        }
        redacted
    }

    fn summary(self) -> LlmPromptRedactionSummary {
        LlmPromptRedactionSummary {
            status: "redacted-preview-confirmed-required".to_string(),
            redacted_value_count: self.redacted_value_count,
            redacted_fields: self.redacted_fields.into_keys().collect(),
            placeholders: vec![
                "$HOME",
                "<project-root>",
                "<project-cwd>",
                "<app-data-dir>",
                "<redacted>",
                "<redacted-url>",
            ],
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_secret_returned: false,
        }
    }
}

fn redact_with_count(value: &str, roots: &[(String, &'static str)]) -> (String, usize) {
    let mut redacted = value.to_string();
    let mut count = 0usize;
    for (root, placeholder) in roots {
        if !root.is_empty() && redacted.contains(root) {
            count += redacted.matches(root).count();
            redacted = redacted.replace(root, placeholder);
        }
    }
    (redacted, count)
}

fn llm_preview_id(
    params: &LlmPreviewPromptParams,
    profile: Option<&ProviderProfileRecord>,
    prompt_preview: &str,
    estimated_input_tokens: u32,
    estimated_output_tokens: u32,
) -> String {
    let profile_fingerprint = profile
        .map(|profile| {
            format!(
                "{}\x1f{}\x1f{}\x1f{}",
                profile.id,
                profile.provider_type.as_str(),
                profile.base_url,
                profile.model
            )
        })
        .unwrap_or_else(|| "no-profile".to_string());
    let source = serde_json::json!({
        "version": "v2.42",
        "profile": profile_fingerprint,
        "action": params.action.as_str(),
        "skill_instance_id": params.skill_instance_id,
        "instance_ids": params.instance_ids,
        "analysis_kind": params.analysis_kind.map(|kind| kind.as_str()),
        "user_intent": params.user_intent.as_deref(),
        "prompt": prompt_preview,
        "estimated_input_tokens": estimated_input_tokens,
        "estimated_output_tokens": estimated_output_tokens
    });
    let digest = Sha256::digest(source.to_string().as_bytes());
    format!("prompt-preview-{digest:x}")
}

fn llm_prompt_action_type(params: &LlmPreviewPromptParams) -> String {
    match params.action {
        LlmPromptActionKind::SkillAnalysis => format!(
            "skill_analysis:{}",
            params
                .analysis_kind
                .unwrap_or(LlmSkillAnalysisKind::Overview)
                .as_str()
        ),
        other => other.as_str().to_string(),
    }
}

fn destination_host_for_url(base_url: &str) -> String {
    let without_scheme = base_url
        .strip_prefix("https://")
        .or_else(|| base_url.strip_prefix("http://"))
        .unwrap_or(base_url);
    without_scheme
        .split('/')
        .next()
        .unwrap_or("<unknown>")
        .to_string()
}

fn llm_review_risk(
    findings: &[RuleFindingRecord],
    frontmatter_raw: &str,
    body: &str,
) -> LlmReviewRisk {
    let highest = findings
        .iter()
        .map(|finding| finding.severity.as_str())
        .max_by_key(|severity| severity_rank(severity))
        .unwrap_or("none");
    let level = match highest {
        "critical" | "error" => "high",
        "warning" | "warn" => "medium",
        _ if findings.is_empty() => "low",
        _ => "medium",
    };
    let mut signals = findings
        .iter()
        .take(8)
        .map(|finding| {
            format!(
                "{} finding from rule {}",
                redact_for_llm_preview(&finding.severity),
                redact_for_llm_preview(&finding.rule_id)
            )
        })
        .collect::<Vec<_>>();
    let combined = format!("{frontmatter_raw}\n{body}").to_lowercase();
    if combined.contains("exec") || combined.contains("command") || combined.contains("#!") {
        signals.push(
            "Skill text contains execution-related terms; scripts remain non-executable by this service."
                .to_string(),
        );
    }
    if combined.contains("network") || combined.contains("http") || combined.contains("api") {
        signals.push(
            "Skill text contains network/API-related terms; this preview performs no network I/O."
                .to_string(),
        );
    }
    if signals.is_empty() {
        signals.push("No current rule findings are associated with this skill.".to_string());
    }
    LlmReviewRisk {
        level,
        summary: format!(
            "Offline risk preview is {level}; based on {} related finding(s) and redacted local metadata only.",
            findings.len()
        ),
        signals,
    }
}

fn severity_rank(severity: &str) -> u8 {
    match severity {
        "critical" => 5,
        "error" => 4,
        "warning" | "warn" => 3,
        "info" => 2,
        _ => 1,
    }
}

fn llm_review_redaction() -> LlmReviewRedaction {
    LlmReviewRedaction {
        skill_body_returned: false,
        paths_returned: false,
        credentials_returned: false,
        included_fields: vec![
            "skill name",
            "skill description",
            "agent",
            "scope",
            "definition id match counts",
            "rule finding ids",
            "rule finding severities",
            "redacted rule messages",
        ],
        excluded_fields: vec![
            "skill body",
            "raw frontmatter",
            "source paths",
            "credential values",
            "provider prompts",
            "provider responses",
        ],
    }
}

fn skill_quality_safety_flags() -> SkillQualitySafetyFlags {
    SkillQualitySafetyFlags {
        read_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
    }
}

fn stale_drift_safety_flags() -> StaleDriftSafetyFlags {
    agent_readiness_safety_flags()
}

fn empty_stale_drift_result(
    filters: StaleDriftFilters,
    catalog_available: bool,
) -> StaleDriftDetectionResult {
    StaleDriftDetectionResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters,
        summary: StaleDriftSummary {
            scanned_skill_count: 0,
            returned_row_count: 0,
            stale_count: 0,
            drift_count: 0,
            high_risk_count: 0,
            medium_risk_count: 0,
            low_risk_count: 0,
            missing_history_count: 0,
            summary:
                "No local catalog is available, so stale/drift detection has no skill evidence."
                    .to_string(),
        },
        stale_drift_rows: Vec::new(),
        readiness_impact_rows: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on stale/drift detection for skill governance."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: StaleDriftPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "stale_drift_detection",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::StaleDriftDetection,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic stale/drift signals using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: stale_drift_safety_flags(),
    }
}

struct StaleDriftRowSignals<'a> {
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    stale_days: u32,
    now_ms: i64,
}

fn stale_drift_row(
    skill: &SkillInstance,
    signals: StaleDriftRowSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> StaleDriftRow {
    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog metadata for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(skill.agent.as_str()),
            redact_for_llm_preview(skill.scope.as_str()),
            skill.enabled,
            redact_for_llm_preview(skill.state.as_str())
        ),
        None,
        Some(skill.id.clone()),
    );
    let modified_age_days = stale_drift_modified_age_days(skill.mtime, signals.now_ms);
    let stale_by_mtime = modified_age_days
        .map(|age| age >= i64::from(signals.stale_days))
        .unwrap_or(false);
    let missing_mtime = skill.mtime <= 0;
    let fingerprint_drift = signals.findings.iter().any(|finding| {
        finding.rule_id == "fingerprint.changed"
            && !finding.suppressed
            && finding.triage_status != "ignored"
    });
    let finding_drift = signals.findings.iter().any(|finding| {
        !finding.suppressed
            && finding.triage_status != "ignored"
            && matches!(
                finding.effective_severity.as_str(),
                "critical" | "error" | "warn" | "warning"
            )
    });
    let source_drift = signals.conflicts.iter().any(|conflict| {
        conflict.reason.contains("drift")
            || conflict.reason.contains("shadow")
            || conflict.reason.contains("collision")
    }) || signals.analysis_groups.iter().any(|group| {
        matches!(
            group.kind.as_str(),
            "source_path_overlap"
                | "enabled_mismatch"
                | "duplicate_name"
                | "canonical_name"
                | "precedence"
                | "malformed"
        )
    });
    let missing_previous_scan = !fingerprint_drift
        && skill.first_seen == skill.last_seen
        && signals
            .findings
            .iter()
            .all(|finding| finding.rule_id != "fingerprint.changed");

    let mut reasons = Vec::new();
    let mut gap_notes = Vec::new();
    let mut evidence_refs = vec![skill_ref];
    if fingerprint_drift {
        reasons.push(
            "Current local findings include explicit fingerprint drift evidence.".to_string(),
        );
    } else {
        gap_notes.push(
            "No explicit previous-scan fingerprint drift finding is available for this skill."
                .to_string(),
        );
    }
    if finding_drift {
        reasons.push(format!(
            "{} open warning/error finding(s) may indicate behavior or metadata drift.",
            signals
                .findings
                .iter()
                .filter(|finding| {
                    !finding.suppressed
                        && finding.triage_status != "ignored"
                        && matches!(
                            finding.effective_severity.as_str(),
                            "critical" | "error" | "warn" | "warning"
                        )
                })
                .count()
        ));
    }
    if source_drift {
        reasons.push(
            "Current conflicts or cross-agent analysis indicate source/identity drift.".to_string(),
        );
    }
    if stale_by_mtime {
        if let Some(age) = modified_age_days {
            reasons.push(format!(
                "Catalog mtime is {age} day(s) old, meeting the {} day stale threshold.",
                signals.stale_days
            ));
        }
    } else if let Some(age) = modified_age_days {
        reasons.push(format!(
            "Catalog mtime age is {age} day(s), below the {} day stale threshold.",
            signals.stale_days
        ));
    } else {
        gap_notes
            .push("Catalog mtime is unavailable, so staleness age is not derived.".to_string());
    }
    if missing_previous_scan {
        gap_notes.push(
            "Previous-scan comparison history is limited; drift is inferred only from current local evidence."
                .to_string(),
        );
    }

    for finding in signals.findings {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        );
        evidence_refs.push(evidence_id);
    }
    for conflict in signals.conflicts {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    for group in signals.analysis_groups {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    if let Some(diagnostic) = signals.diagnostic {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "adapter_diagnostics",
            diagnostic.agent,
            format!(
                "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                redact_for_llm_preview(diagnostic.display_name),
                redact_for_llm_preview(diagnostic.status),
                redact_for_llm_preview(diagnostic.access.writable_status),
                redact_for_llm_preview(diagnostic.access.install_status)
            ),
            None,
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    reasons.sort();
    reasons.dedup();
    gap_notes.sort();
    gap_notes.dedup();

    let drift_signals = StaleDriftSignals {
        fingerprint_drift,
        finding_drift,
        source_drift,
        modified_age_days,
        stale_by_mtime,
        missing_mtime,
        missing_previous_scan,
        related_finding_count: signals.findings.len(),
        related_conflict_count: signals.conflicts.len(),
        related_analysis_count: signals.analysis_groups.len(),
    };
    let score = stale_drift_score(&drift_signals, skill);
    let readiness_impact = stale_drift_readiness_impact(score, &drift_signals, skill);

    StaleDriftRow {
        rank: 0,
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.as_str().to_string(),
        scope: skill.scope.as_str().to_string(),
        enabled: skill.enabled,
        state: skill.state.as_str().to_string(),
        stale_drift_score: score,
        stale_drift_band: stale_drift_band(score),
        drift_signals,
        readiness_impact,
        reasons,
        gap_notes,
        evidence_refs,
        safety_flags: stale_drift_safety_flags(),
    }
}

fn stale_drift_modified_age_days(mtime: i64, now_ms: i64) -> Option<i64> {
    if mtime <= 0 || now_ms <= 0 || mtime > now_ms {
        return None;
    }
    Some((now_ms - mtime) / 86_400_000)
}

fn stale_drift_score(signals: &StaleDriftSignals, skill: &SkillInstance) -> u8 {
    let mut score = 0i16;
    if signals.fingerprint_drift {
        score += 35;
    }
    if signals.finding_drift {
        score += 20;
    }
    if signals.source_drift {
        score += 25;
    }
    if signals.stale_by_mtime {
        score += 20;
    } else if signals.missing_mtime {
        score += 6;
    }
    if !skill.enabled {
        score += 4;
    }
    if skill.state.as_str() != "loaded" {
        score += 10;
    }
    if signals.missing_previous_scan {
        score += 4;
    }
    score.clamp(0, 100) as u8
}

fn stale_drift_band(score: u8) -> &'static str {
    match score {
        80..=100 => "high",
        45..=79 => "medium",
        1..=44 => "low",
        _ => "clear",
    }
}

fn stale_drift_readiness_impact(
    score: u8,
    signals: &StaleDriftSignals,
    skill: &SkillInstance,
) -> Option<StaleDriftReadinessImpact> {
    let mut notes = Vec::new();
    if signals.fingerprint_drift {
        notes.push(
            "Fingerprint drift should be reviewed before treating this skill as a stable routing target."
                .to_string(),
        );
    }
    if signals.source_drift {
        notes.push("Source or identity drift may make cross-agent routing ambiguous.".to_string());
    }
    if signals.finding_drift {
        notes.push(
            "Open warning/error findings can reduce deterministic task readiness.".to_string(),
        );
    }
    if signals.stale_by_mtime {
        notes.push("Stale mtime may indicate skill instructions have not kept pace with current task expectations.".to_string());
    }
    if !skill.enabled || skill.state.as_str() != "loaded" {
        notes.push(
            "Disabled or non-loaded state can block readiness regardless of match quality."
                .to_string(),
        );
    }
    if notes.is_empty() {
        return None;
    }
    Some(StaleDriftReadinessImpact {
        impact_level: stale_drift_band(score),
        readiness_risk_score: score,
        notes,
    })
}

fn stale_drift_readiness_impact_row(row: &StaleDriftRow) -> Option<StaleDriftReadinessImpactRow> {
    row.readiness_impact
        .as_ref()
        .map(|impact| StaleDriftReadinessImpactRow {
            instance_id: row.instance_id.clone(),
            skill_name: row.skill_name.clone(),
            agent: row.agent.clone(),
            impact_level: impact.impact_level,
            stale_drift_score: row.stale_drift_score,
            notes: impact.notes.clone(),
            evidence_refs: row.evidence_refs.clone(),
        })
}

fn stale_drift_summary(scanned_skill_count: usize, rows: &[StaleDriftRow]) -> StaleDriftSummary {
    let stale_count = rows
        .iter()
        .filter(|row| row.drift_signals.stale_by_mtime)
        .count();
    let drift_count = rows
        .iter()
        .filter(|row| {
            row.drift_signals.fingerprint_drift
                || row.drift_signals.finding_drift
                || row.drift_signals.source_drift
        })
        .count();
    let high_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "high")
        .count();
    let medium_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "medium")
        .count();
    let low_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "low")
        .count();
    let missing_history_count = rows
        .iter()
        .filter(|row| row.drift_signals.missing_previous_scan || row.drift_signals.missing_mtime)
        .count();
    let summary = if rows.is_empty() {
        "No visible skills matched the stale/drift detection filters.".to_string()
    } else {
        format!(
            "Detected {stale_count} stale skill row(s), {drift_count} drift row(s), and {high_risk_count} high-risk row(s) from deterministic local catalog evidence."
        )
    };
    StaleDriftSummary {
        scanned_skill_count,
        returned_row_count: rows.len(),
        stale_count,
        drift_count,
        high_risk_count,
        medium_risk_count,
        low_risk_count,
        missing_history_count,
        summary,
    }
}

fn stale_drift_blocker_notes(rows: &[StaleDriftRow]) -> Vec<String> {
    let mut notes = Vec::new();
    if rows.iter().any(|row| row.drift_signals.fingerprint_drift) {
        notes.push(
            "Fingerprint drift evidence is present; review before relying on affected skills for routing."
                .to_string(),
        );
    }
    if rows.iter().any(|row| row.drift_signals.source_drift) {
        notes.push(
            "Source or identity drift evidence is present; cross-agent routing may be ambiguous."
                .to_string(),
        );
    }
    if rows.iter().any(|row| row.stale_drift_band == "high") {
        notes.push(
            "High stale/drift risk is based on local evidence only and does not enable writes or automatic cleanup."
                .to_string(),
        );
    }
    notes
}

fn knowledge_search_safety_flags() -> KnowledgeSearchSafetyFlags {
    agent_readiness_safety_flags()
}

fn knowledge_search_filters(params: &KnowledgeSearchParams) -> KnowledgeSearchFilters {
    let query = params
        .query
        .as_deref()
        .map(str::trim)
        .filter(|query| !query.is_empty())
        .map(redact_for_llm_preview);
    let mut normalized_terms = query
        .as_deref()
        .map(task_readiness_terms)
        .unwrap_or_default();
    if let Some(keyword) = params.keyword.as_deref().map(str::trim) {
        if !keyword.is_empty() {
            normalized_terms.extend(task_readiness_terms(keyword));
        }
    }
    normalized_terms.sort();
    normalized_terms.dedup();
    KnowledgeSearchFilters {
        query,
        normalized_terms,
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        limit: params.limit.unwrap_or(25).clamp(1, 100),
        risk: params
            .risk
            .as_deref()
            .map(normalize_filter_value)
            .filter(|risk| !risk.is_empty()),
        scope: params
            .scope
            .as_deref()
            .map(normalize_filter_value)
            .filter(|scope| !scope.is_empty()),
        enabled: params.enabled,
        tool: params
            .tool
            .as_deref()
            .map(normalize_filter_value)
            .filter(|tool| !tool.is_empty()),
        keyword: params
            .keyword
            .as_deref()
            .map(normalize_filter_value)
            .filter(|keyword| !keyword.is_empty()),
    }
}

fn normalize_filter_value(value: &str) -> String {
    value.trim().to_ascii_lowercase().replace(['_', ' '], "-")
}

fn empty_knowledge_search_result(
    filters: KnowledgeSearchFilters,
    catalog_available: bool,
) -> KnowledgeSearchResult {
    KnowledgeSearchResult {
        generated_by: "deterministic-service",
        catalog_available,
        summary: KnowledgeSearchSummary {
            indexed_skill_count: 0,
            matched_row_count: 0,
            returned_row_count: 0,
            enabled_count: 0,
            disabled_count: 0,
            high_risk_count: 0,
            stale_or_drift_count: 0,
            summary: "No local catalog is available, so knowledge search has no skill evidence."
                .to_string(),
        },
        filters,
        rows: Vec::new(),
        facets: KnowledgeSearchFacets::default(),
        gap_notes: vec![
            "Run a local scan before relying on knowledge search for skill discovery.".to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: KnowledgeSearchPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "knowledge_search",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::KnowledgeSearch,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic local knowledge search results.".to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: knowledge_search_safety_flags(),
    }
}

struct KnowledgeSearchRowSignals<'a> {
    query_terms: &'a [String],
    filters: &'a KnowledgeSearchFilters,
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    quality: Option<&'a SkillQualityScoreResult>,
    readiness: Option<&'a TaskReadinessCandidate>,
    stale: Option<&'a StaleDriftRow>,
    redaction_roots: &'a [(String, &'static str)],
}

fn knowledge_search_row(
    skill: &SkillDetailRecord,
    signals: KnowledgeSearchRowSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> Option<KnowledgeSearchRow> {
    if let Some(scope) = signals.filters.scope.as_deref() {
        if normalize_filter_value(&skill.scope) != scope {
            return None;
        }
    }
    if let Some(enabled) = signals.filters.enabled {
        if skill.enabled != enabled {
            return None;
        }
    }

    let tools = knowledge_tools(&skill.permissions);
    if let Some(tool) = signals.filters.tool.as_deref() {
        if !tools
            .iter()
            .any(|candidate| normalize_filter_value(candidate) == tool)
        {
            return None;
        }
    }

    let keywords = knowledge_keywords(skill, &tools, signals.findings);
    if let Some(keyword) = signals.filters.keyword.as_deref() {
        if !keywords
            .iter()
            .any(|candidate| normalize_filter_value(candidate).contains(keyword))
        {
            return None;
        }
    }

    let risk_level = signals
        .readiness
        .map(|readiness| readiness.enabled_scope_risk_state.risk_level)
        .unwrap_or_else(|| {
            task_readiness_risk_level(
                signals.findings,
                signals.conflicts,
                signals.analysis_groups,
                skill,
            )
        });
    if let Some(risk) = signals.filters.risk.as_deref() {
        if risk_level != risk
            && !signals.findings.iter().any(|finding| {
                normalize_filter_value(&finding.effective_severity) == risk
                    || normalize_filter_value(&finding.rule_id).contains(risk)
            })
        {
            return None;
        }
    }

    let (matched_fields, matched_terms) =
        knowledge_match_terms(skill, &tools, &keywords, signals.query_terms);
    if !signals.query_terms.is_empty() && matched_terms.is_empty() {
        return None;
    }

    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog knowledge row for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(&skill.agent),
            redact_for_llm_preview(&skill.scope),
            skill.enabled,
            redact_for_llm_preview(&skill.state)
        ),
        None,
        Some(skill.id.clone()),
    );
    let mut evidence_refs = vec![skill_ref];
    for finding in signals.findings {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        ));
    }
    for conflict in signals.conflicts {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        ));
    }
    for group in signals.analysis_groups {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        ));
    }
    if let Some(diagnostic) = signals.diagnostic {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "adapter_diagnostics",
            diagnostic.agent,
            format!(
                "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                redact_for_llm_preview(diagnostic.display_name),
                redact_for_llm_preview(diagnostic.status),
                redact_for_llm_preview(diagnostic.access.writable_status),
                redact_for_llm_preview(diagnostic.access.install_status)
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(quality) = signals.quality {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "quality_score",
            &skill.id,
            format!(
                "V2.43 quality score {} / 100 ({})",
                quality.score, quality.band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(stale) = signals.stale {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "stale_drift",
            &skill.id,
            format!(
                "V2.51 stale/drift score {} / 100 ({})",
                stale.stale_drift_score, stale.stale_drift_band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    evidence_refs.sort();
    evidence_refs.dedup();

    let mut match_reasons = Vec::new();
    if matched_terms.is_empty() {
        match_reasons.push(
            "Listed from local catalog evidence without a lexical query constraint.".to_string(),
        );
    } else {
        match_reasons.push(format!(
            "Matched query term(s): {}.",
            matched_terms
                .iter()
                .take(8)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !skill.description.trim().is_empty() {
        match_reasons.push(format!(
            "Description evidence: {}",
            redact_for_llm_preview(&knowledge_snippet(&skill.description, signals.query_terms))
        ));
    }
    if let Some(readiness) = signals.readiness {
        match_reasons.push(format!(
            "Task readiness context is {} ({}/100) with risk {}.",
            readiness.band, readiness.score, readiness.enabled_scope_risk_state.risk_level
        ));
    }
    if let Some(stale) = signals.stale {
        match_reasons.push(format!(
            "Stale/drift context is {} ({}/100).",
            stale.stale_drift_band, stale.stale_drift_score
        ));
    }

    let rules = signals
        .findings
        .iter()
        .map(|finding| finding.rule_id.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let capability_tags = knowledge_capability_tags(skill, signals.diagnostic);
    let risk_tags = knowledge_risk_tags(risk_level, signals.findings, signals.stale);

    Some(KnowledgeSearchRow {
        rank: 0,
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.clone(),
        scope: skill.scope.clone(),
        enabled: skill.enabled,
        state: skill.state.clone(),
        source: KnowledgeSearchSource {
            source_path: redact_path_string(&skill.path, signals.redaction_roots),
            display_path: redact_path_string(&skill.display_path, signals.redaction_roots),
            root_provenance: knowledge_root_provenance(skill),
            fingerprint: redact_for_llm_preview(&skill.fingerprint),
        },
        purpose_snippet: knowledge_optional_snippet(&skill.body, signals.query_terms),
        description_snippet: knowledge_optional_snippet(&skill.description, signals.query_terms),
        matched_fields,
        match_reasons,
        keywords,
        tools,
        rules,
        capability_tags,
        risk_tags,
        quality_context: signals.quality.map(|quality| KnowledgeQualityContext {
            score: quality.score,
            grade: quality.grade,
            band: quality.band,
            reasons: quality.reasons.iter().take(3).cloned().collect(),
        }),
        readiness_context: signals
            .readiness
            .map(|readiness| KnowledgeReadinessContext {
                score: readiness.score,
                band: readiness.band,
                risk_level: readiness.enabled_scope_risk_state.risk_level,
                risk_summary: readiness.enabled_scope_risk_state.risk_summary.clone(),
                gap_count: readiness.missing_gap_notes.len(),
                blocker_count: readiness.blocker_risk_notes.len(),
            }),
        stale_drift_context: signals.stale.map(|stale| KnowledgeStaleDriftContext {
            score: stale.stale_drift_score,
            band: stale.stale_drift_band,
            fingerprint_drift: stale.drift_signals.fingerprint_drift,
            finding_drift: stale.drift_signals.finding_drift,
            source_drift: stale.drift_signals.source_drift,
            stale_by_mtime: stale.drift_signals.stale_by_mtime,
            readiness_impact_level: stale
                .readiness_impact
                .as_ref()
                .map(|impact| impact.impact_level),
        }),
        evidence_refs,
        safety_flags: knowledge_search_safety_flags(),
    })
}

fn knowledge_related_findings(
    findings: &[RuleFindingRecord],
    skill: &SkillDetailRecord,
) -> Vec<RuleFindingRecord> {
    findings
        .iter()
        .filter(|finding| {
            finding.instance_id.as_deref() == Some(skill.id.as_str())
                || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
        })
        .cloned()
        .collect()
}

fn knowledge_related_conflicts(
    conflicts: &[ConflictGroupRecord],
    skill: &SkillDetailRecord,
) -> Vec<ConflictGroupRecord> {
    conflicts
        .iter()
        .filter(|conflict| {
            conflict.definition_id == skill.definition_id
                || conflict
                    .instance_ids
                    .iter()
                    .any(|instance_id| instance_id == &skill.id)
        })
        .cloned()
        .collect()
}

fn knowledge_related_analysis(
    groups: &[CrossAgentAnalysisGroup],
    skill: &SkillDetailRecord,
) -> Vec<CrossAgentAnalysisGroup> {
    groups
        .iter()
        .filter(|group| {
            group
                .instance_ids
                .iter()
                .any(|instance_id| instance_id == &skill.id)
        })
        .cloned()
        .collect()
}

fn knowledge_tools(permissions: &Value) -> Vec<String> {
    let normalized = permissions.get("normalized").unwrap_or(permissions);
    let mut tools = normalized
        .get("tools")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::trim)
        .filter(|tool| !tool.is_empty())
        .map(redact_for_llm_preview)
        .collect::<Vec<_>>();
    tools.sort();
    tools.dedup();
    tools
}

fn knowledge_keywords(
    skill: &SkillDetailRecord,
    tools: &[String],
    findings: &[RuleFindingRecord],
) -> Vec<String> {
    let mut terms = BTreeSet::new();
    for value in [
        skill.name.as_str(),
        skill.description.as_str(),
        skill.frontmatter_raw.as_str(),
        skill.body.as_str(),
    ] {
        for term in task_readiness_terms(value).into_iter().take(20) {
            terms.insert(term);
        }
    }
    for tool in tools {
        terms.insert(tool.to_ascii_lowercase());
    }
    for finding in findings {
        terms.insert(finding.rule_id.clone());
    }
    terms.into_iter().take(30).collect()
}

fn knowledge_match_terms(
    skill: &SkillDetailRecord,
    tools: &[String],
    keywords: &[String],
    query_terms: &[String],
) -> (Vec<String>, Vec<String>) {
    let fields = [
        ("name", skill.name.as_str()),
        ("description", skill.description.as_str()),
        ("frontmatter", skill.frontmatter_raw.as_str()),
        ("body", skill.body.as_str()),
        ("agent", skill.agent.as_str()),
        ("scope", skill.scope.as_str()),
    ];
    let tools_joined = tools.join(" ");
    let keywords_joined = keywords.join(" ");
    let derived_fields = [
        ("tools", tools_joined.as_str()),
        ("keywords", keywords_joined.as_str()),
    ];
    let mut matched_fields = BTreeSet::new();
    let mut matched_terms = BTreeSet::new();
    for term in query_terms {
        for (field, value) in fields.iter().chain(derived_fields.iter()) {
            if value.to_ascii_lowercase().contains(term) {
                matched_fields.insert((*field).to_string());
                matched_terms.insert(term.clone());
            }
        }
    }
    (
        matched_fields.into_iter().collect(),
        matched_terms.into_iter().collect(),
    )
}

fn knowledge_optional_snippet(value: &str, query_terms: &[String]) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(knowledge_snippet(trimmed, query_terms))
    }
}

fn knowledge_snippet(value: &str, query_terms: &[String]) -> String {
    let compact = value.split_whitespace().collect::<Vec<_>>().join(" ");
    let start = query_terms
        .iter()
        .filter_map(|term| compact.to_ascii_lowercase().find(term))
        .min()
        .unwrap_or(0);
    let start = start.saturating_sub(40);
    let mut snippet = compact.chars().skip(start).take(180).collect::<String>();
    if start > 0 {
        snippet.insert_str(0, "...");
    }
    if compact.chars().count() > start + snippet.chars().count() {
        snippet.push_str("...");
    }
    redact_for_llm_preview(&snippet)
}

fn knowledge_capability_tags(
    skill: &SkillDetailRecord,
    diagnostic: Option<&AdapterDiagnosticsRecord>,
) -> Vec<String> {
    let mut tags = BTreeSet::new();
    tags.insert(skill.agent.clone());
    tags.insert(skill.scope.clone());
    tags.insert(if skill.enabled { "enabled" } else { "disabled" }.to_string());
    tags.insert(skill.state.clone());
    tags.insert("local-catalog".to_string());
    tags.insert("read-only".to_string());
    if let Some(diagnostic) = diagnostic {
        tags.insert(format!("adapter-{}", diagnostic.status));
        tags.insert(format!("writable-{}", diagnostic.access.writable_status));
        tags.insert(format!("install-{}", diagnostic.access.install_status));
    }
    tags.into_iter().collect()
}

fn knowledge_risk_tags(
    risk_level: &'static str,
    findings: &[RuleFindingRecord],
    stale: Option<&StaleDriftRow>,
) -> Vec<String> {
    let mut tags = BTreeSet::new();
    tags.insert(format!("risk-{risk_level}"));
    for finding in findings {
        tags.insert(format!("severity-{}", finding.effective_severity));
        tags.insert(format!("rule-{}", finding.rule_id));
    }
    if let Some(stale) = stale {
        tags.insert(format!("stale-drift-{}", stale.stale_drift_band));
        if stale.drift_signals.fingerprint_drift {
            tags.insert("fingerprint-drift".to_string());
        }
        if stale.drift_signals.source_drift {
            tags.insert("source-drift".to_string());
        }
        if stale.drift_signals.stale_by_mtime {
            tags.insert("mtime-stale".to_string());
        }
    }
    tags.into_iter().collect()
}

fn knowledge_root_provenance(skill: &SkillDetailRecord) -> String {
    if skill.scope == Scope::AgentProject.as_str() {
        "project-scope catalog evidence".to_string()
    } else if skill.scope == Scope::ToolGlobal.as_str() {
        "tool-global catalog evidence".to_string()
    } else {
        "agent-scope catalog evidence".to_string()
    }
}

fn knowledge_row_rank_score(row: &KnowledgeSearchRow) -> i16 {
    let mut score = 0i16;
    score += (row.matched_fields.len() as i16 * 12).min(48);
    if let Some(readiness) = &row.readiness_context {
        score += i16::from(readiness.score) / 4;
    }
    if let Some(quality) = &row.quality_context {
        score += i16::from(quality.score) / 5;
    }
    if row.enabled {
        score += 8;
    }
    if row.state == "loaded" {
        score += 5;
    }
    if let Some(stale) = &row.stale_drift_context {
        score -= i16::from(stale.score) / 8;
    }
    score
}

fn knowledge_search_facets(rows: &[KnowledgeSearchRow]) -> KnowledgeSearchFacets {
    let mut facets = KnowledgeSearchFacets::default();
    for row in rows {
        *facets.agents.entry(row.agent.clone()).or_insert(0) += 1;
        *facets.scopes.entry(row.scope.clone()).or_insert(0) += 1;
        *facets.states.entry(row.state.clone()).or_insert(0) += 1;
        *facets
            .enabled
            .entry(if row.enabled { "true" } else { "false" }.to_string())
            .or_insert(0) += 1;
        if let Some(readiness) = &row.readiness_context {
            *facets
                .risks
                .entry(readiness.risk_level.to_string())
                .or_insert(0) += 1;
        } else if let Some(tag) = row
            .risk_tags
            .iter()
            .find_map(|tag| tag.strip_prefix("risk-").map(ToOwned::to_owned))
        {
            *facets.risks.entry(tag).or_insert(0) += 1;
        }
        for tool in row.tools.iter().take(12) {
            *facets.tools.entry(tool.clone()).or_insert(0) += 1;
        }
        for keyword in row.keywords.iter().take(12) {
            *facets.keywords.entry(keyword.clone()).or_insert(0) += 1;
        }
    }
    facets
}

fn knowledge_search_blocker_notes(rows: &[KnowledgeSearchRow]) -> Vec<String> {
    let mut notes = Vec::new();
    if rows.iter().any(|row| !row.enabled || row.state != "loaded") {
        notes.push(
            "Some matched knowledge rows are disabled or not loaded; discovery does not make them ready routing targets."
                .to_string(),
        );
    }
    if rows.iter().any(|row| {
        row.risk_tags
            .iter()
            .any(|tag| tag == "risk-high" || tag == "risk-blocked")
    }) {
        notes.push(
            "High or blocked risk rows are included for inspection only; no write or execution action is enabled."
                .to_string(),
        );
    }
    if rows.iter().any(|row| {
        row.stale_drift_context
            .as_ref()
            .is_some_and(|context| context.score > 0)
    }) {
        notes.push(
            "Stale/drift context comes from current local catalog evidence and does not create an index artifact."
                .to_string(),
        );
    }
    if notes.is_empty() {
        notes.push(
            "Knowledge search used local catalog evidence only and found no matched-row blockers."
                .to_string(),
        );
    }
    notes
}

fn knowledge_search_summary(
    indexed_skill_count: usize,
    matched_row_count: usize,
    rows: &[KnowledgeSearchRow],
) -> KnowledgeSearchSummary {
    let enabled_count = rows.iter().filter(|row| row.enabled).count();
    let disabled_count = rows.len().saturating_sub(enabled_count);
    let high_risk_count = rows
        .iter()
        .filter(|row| {
            row.risk_tags
                .iter()
                .any(|tag| tag == "risk-high" || tag == "risk-blocked")
        })
        .count();
    let stale_or_drift_count = rows
        .iter()
        .filter(|row| {
            row.stale_drift_context
                .as_ref()
                .is_some_and(|context| context.score > 0)
        })
        .count();
    let summary = if rows.is_empty() {
        "No local knowledge rows matched the selected search filters.".to_string()
    } else {
        format!(
            "Returned {} of {} matched local knowledge row(s) from {} indexed visible skill(s); {} row(s) are enabled and {} row(s) carry high/blocking risk.",
            rows.len(),
            matched_row_count,
            indexed_skill_count,
            enabled_count,
            high_risk_count
        )
    };
    KnowledgeSearchSummary {
        indexed_skill_count,
        matched_row_count,
        returned_row_count: rows.len(),
        enabled_count,
        disabled_count,
        high_risk_count,
        stale_or_drift_count,
        summary,
    }
}

fn similar_skill_grouping_safety_flags() -> SimilarSkillGroupingSafetyFlags {
    agent_readiness_safety_flags()
}

fn similar_skill_grouping_filters(
    params: &SimilarSkillGroupingParams,
) -> SimilarSkillGroupingFilters {
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();
    let min_score = params.min_score.unwrap_or(45.0).clamp(0.0, 100.0).round() as u8;
    SimilarSkillGroupingFilters {
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        limit: params.limit.unwrap_or(25).clamp(1, 100),
        min_score,
        include_singletons: params.include_singletons,
        candidate_instance_ids,
    }
}

fn empty_similar_skill_grouping_result(
    filters: SimilarSkillGroupingFilters,
    catalog_available: bool,
) -> SimilarSkillGroupingResult {
    SimilarSkillGroupingResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters,
        summary: SimilarSkillGroupingSummary {
            indexed_skill_count: 0,
            candidate_skill_count: 0,
            matched_group_count: 0,
            returned_group_count: 0,
            duplicate_group_count: 0,
            confusable_group_count: 0,
            coverage_redundancy_group_count: 0,
            routing_ambiguity_count: 0,
            summary: "No local catalog is available, so similar skill grouping has no skill evidence."
                .to_string(),
        },
        groups: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on similar skill grouping for dedupe or routing review."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: SimilarSkillGroupingPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "similar_skill_grouping",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::SimilarSkillGrouping,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic similar skill grouping using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: similar_skill_grouping_safety_flags(),
    }
}

struct SimilarSkillCandidateSignals<'a> {
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    quality: Option<&'a SkillQualityScoreResult>,
    stale: Option<&'a StaleDriftRow>,
    redaction_roots: &'a [(String, &'static str)],
}

#[derive(Debug, Clone)]
struct SimilarSkillCandidate {
    detail: SkillDetailRecord,
    member: SimilarSkillMember,
    canonical_key: String,
    terms: Vec<String>,
    tools: Vec<String>,
    rules: Vec<String>,
    capability_tags: Vec<String>,
    risk_tags: Vec<String>,
    source_signals: Vec<String>,
}

#[derive(Debug, Clone)]
struct SimilarSkillPair {
    left: usize,
    right: usize,
    score: u8,
    group_type: &'static str,
    coverage_redundancy: &'static str,
    routing_ambiguity: &'static str,
    ambiguity_risk: &'static str,
    why_grouped: Vec<String>,
    shared_terms: Vec<String>,
    shared_tools: Vec<String>,
    shared_rules: Vec<String>,
    shared_capability_tags: Vec<String>,
    shared_risk_tags: Vec<String>,
    shared_source_signals: Vec<String>,
}

fn similar_skill_candidate(
    skill: &SkillDetailRecord,
    signals: SimilarSkillCandidateSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> SimilarSkillCandidate {
    let tools = knowledge_tools(&skill.permissions);
    let keywords = knowledge_keywords(skill, &tools, signals.findings);
    let rules = signals
        .findings
        .iter()
        .map(|finding| finding.rule_id.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let risk_level = task_readiness_risk_level(
        signals.findings,
        signals.conflicts,
        signals.analysis_groups,
        skill,
    );
    let capability_tags = knowledge_capability_tags(skill, signals.diagnostic);
    let risk_tags = knowledge_risk_tags(risk_level, signals.findings, signals.stale);
    let mut source_signals = BTreeSet::new();
    source_signals.insert(knowledge_root_provenance(skill));
    source_signals.insert(format!(
        "source-path:{}",
        redact_path_string(&skill.display_path, signals.redaction_roots)
    ));
    source_signals.insert(format!(
        "fingerprint:{}",
        redact_for_llm_preview(&skill.fingerprint)
    ));
    let parent = Path::new(&skill.display_path)
        .parent()
        .map(|path| redact_path_string(path, signals.redaction_roots));
    if let Some(parent) = parent {
        source_signals.insert(format!("source-root:{parent}"));
    }

    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog similar-skill member for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(&skill.agent),
            redact_for_llm_preview(&skill.scope),
            skill.enabled,
            redact_for_llm_preview(&skill.state)
        ),
        None,
        Some(skill.id.clone()),
    );
    let mut evidence_refs = vec![skill_ref];
    for finding in signals.findings {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        ));
    }
    for conflict in signals.conflicts {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        ));
    }
    for group in signals.analysis_groups {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        ));
    }
    if let Some(quality) = signals.quality {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "quality_score",
            &skill.id,
            format!(
                "V2.43 quality score {} / 100 ({})",
                quality.score, quality.band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(stale) = signals.stale {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "stale_drift",
            &skill.id,
            format!(
                "V2.51 stale/drift score {} / 100 ({})",
                stale.stale_drift_score, stale.stale_drift_band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    evidence_refs.sort();
    evidence_refs.dedup();

    let canonical_key = normalize_similarity_key(&skill.name);
    let match_reasons = vec![
        format!(
            "Local catalog member has canonical key `{}` and {} derived keyword(s).",
            redact_for_llm_preview(&canonical_key),
            keywords.len()
        ),
        format!(
            "Risk context is `{}`; risk affects ambiguity notes but never creates write actions.",
            risk_level
        ),
    ];

    SimilarSkillCandidate {
        detail: skill.clone(),
        member: SimilarSkillMember {
            instance_id: skill.id.clone(),
            definition_id: skill.definition_id.clone(),
            skill_name: redact_for_llm_preview(&skill.name),
            agent: skill.agent.clone(),
            scope: skill.scope.clone(),
            enabled: skill.enabled,
            state: skill.state.clone(),
            source: KnowledgeSearchSource {
                source_path: redact_path_string(&skill.path, signals.redaction_roots),
                display_path: redact_path_string(&skill.display_path, signals.redaction_roots),
                root_provenance: knowledge_root_provenance(skill),
                fingerprint: redact_for_llm_preview(&skill.fingerprint),
            },
            quality_context: signals.quality.map(|quality| KnowledgeQualityContext {
                score: quality.score,
                grade: quality.grade,
                band: quality.band,
                reasons: quality.reasons.iter().take(3).cloned().collect(),
            }),
            readiness_context: None,
            stale_drift_context: signals.stale.map(|stale| KnowledgeStaleDriftContext {
                score: stale.stale_drift_score,
                band: stale.stale_drift_band,
                fingerprint_drift: stale.drift_signals.fingerprint_drift,
                finding_drift: stale.drift_signals.finding_drift,
                source_drift: stale.drift_signals.source_drift,
                stale_by_mtime: stale.drift_signals.stale_by_mtime,
                readiness_impact_level: stale
                    .readiness_impact
                    .as_ref()
                    .map(|impact| impact.impact_level),
            }),
            match_reasons,
            similarity_reasons: Vec::new(),
            evidence_refs,
        },
        canonical_key,
        terms: keywords,
        tools,
        rules,
        capability_tags,
        risk_tags,
        source_signals: source_signals.into_iter().collect(),
    }
}

fn similar_skill_groups_from_candidates(
    candidates: Vec<SimilarSkillCandidate>,
    min_score: u8,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> Vec<SimilarSkillGroup> {
    let mut pairs = Vec::new();
    for left in 0..candidates.len() {
        for right in (left + 1)..candidates.len() {
            let pair = similar_skill_pair(&candidates[left], &candidates[right], left, right);
            if pair.score >= min_score {
                pairs.push(pair);
            }
        }
    }

    let mut adjacency = vec![Vec::<usize>::new(); candidates.len()];
    for pair in &pairs {
        adjacency[pair.left].push(pair.right);
        adjacency[pair.right].push(pair.left);
    }

    let mut seen = vec![false; candidates.len()];
    let mut components = Vec::new();
    for index in 0..candidates.len() {
        if seen[index] {
            continue;
        }
        let mut stack = vec![index];
        let mut component = Vec::new();
        seen[index] = true;
        while let Some(current) = stack.pop() {
            component.push(current);
            for next in &adjacency[current] {
                if !seen[*next] {
                    seen[*next] = true;
                    stack.push(*next);
                }
            }
        }
        component.sort();
        components.push(component);
    }

    let mut groups = Vec::new();
    for component in components {
        let related_pairs = pairs
            .iter()
            .filter(|pair| component.contains(&pair.left) && component.contains(&pair.right))
            .cloned()
            .collect::<Vec<_>>();
        if component.len() > 1 && related_pairs.is_empty() {
            continue;
        }
        groups.push(similar_skill_group_from_component(
            &candidates,
            &component,
            &related_pairs,
            evidence,
        ));
    }
    groups
}

fn similar_skill_pair(
    left: &SimilarSkillCandidate,
    right: &SimilarSkillCandidate,
    left_index: usize,
    right_index: usize,
) -> SimilarSkillPair {
    let shared_terms = sorted_intersection(&left.terms, &right.terms, 12);
    let shared_tools = sorted_intersection(&left.tools, &right.tools, 12);
    let shared_rules = sorted_intersection(&left.rules, &right.rules, 12);
    let shared_capability_tags =
        sorted_intersection(&left.capability_tags, &right.capability_tags, 12);
    let shared_risk_tags = sorted_intersection(&left.risk_tags, &right.risk_tags, 12);
    let shared_source_signals = sorted_intersection(&left.source_signals, &right.source_signals, 8);
    let same_definition = left.detail.definition_id == right.detail.definition_id;
    let same_canonical = left.canonical_key == right.canonical_key;
    let same_agent = left.detail.agent == right.detail.agent;
    let same_fingerprint = left.detail.fingerprint == right.detail.fingerprint;
    let same_source_path = left.detail.display_path == right.detail.display_path;

    let mut score = 0u16;
    let mut why_grouped = Vec::new();
    if same_definition {
        score += 35;
        why_grouped
            .push("Shared catalog definition id indicates same local skill identity.".to_string());
    }
    if same_canonical {
        score += 30;
        why_grouped
            .push("Same canonical skill name/key creates high duplicate likelihood.".to_string());
    }
    if same_source_path {
        score += 25;
        why_grouped.push("Shared source path is treated as source overlap evidence.".to_string());
    } else if shared_source_signals
        .iter()
        .any(|signal| signal.starts_with("source-root:"))
    {
        score += 10;
        why_grouped.push("Shared source root suggests overlapping provenance.".to_string());
    }
    if same_fingerprint {
        score += 20;
        why_grouped.push(
            "Shared content fingerprint indicates near-identical catalog evidence.".to_string(),
        );
    }
    if !shared_tools.is_empty() {
        score += (shared_tools.len() as u16 * 8).min(24);
        why_grouped.push(format!(
            "Shared tool coverage: {}.",
            shared_tools
                .iter()
                .take(6)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_rules.is_empty() {
        score += (shared_rules.len() as u16 * 6).min(18);
        why_grouped.push(format!(
            "Shared rule/finding signals: {}.",
            shared_rules
                .iter()
                .take(6)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_terms.is_empty() {
        score += (shared_terms.len() as u16 * 4).min(20);
        why_grouped.push(format!(
            "Shared purpose/keyword terms: {}.",
            shared_terms
                .iter()
                .take(8)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_capability_tags.is_empty() {
        score += (shared_capability_tags.len() as u16 * 3).min(12);
    }
    if !shared_risk_tags.is_empty() {
        score += (shared_risk_tags.len() as u16 * 2).min(8);
    }
    if same_agent {
        score += 5;
    }

    let score = score.min(100) as u8;
    let coverage_redundancy = if same_canonical || shared_tools.len() >= 3 || score >= 80 {
        "high"
    } else if shared_tools.len() >= 2 || shared_terms.len() >= 4 || score >= 55 {
        "medium"
    } else {
        "low"
    };
    let routing_ambiguity = if same_canonical && left.detail.enabled && right.detail.enabled {
        "high"
    } else if shared_terms.len() >= 5 && shared_tools.len() >= 2 {
        "medium"
    } else {
        "low"
    };
    let ambiguity_risk = if routing_ambiguity == "high"
        || left.detail.state != "loaded"
        || right.detail.state != "loaded"
        || !left.detail.enabled
        || !right.detail.enabled
        || shared_risk_tags
            .iter()
            .any(|tag| tag == "risk-high" || tag == "risk-blocked")
    {
        "high"
    } else if routing_ambiguity == "medium" || coverage_redundancy == "medium" {
        "medium"
    } else {
        "low"
    };
    let group_type = if same_canonical || same_definition || same_fingerprint {
        "duplicate"
    } else if same_source_path || shared_source_signals.len() > 1 {
        "source_overlap"
    } else if coverage_redundancy == "high" {
        "coverage_redundancy"
    } else if routing_ambiguity != "low" || ambiguity_risk == "high" {
        "confusable"
    } else {
        "similar"
    };

    SimilarSkillPair {
        left: left_index,
        right: right_index,
        score,
        group_type,
        coverage_redundancy,
        routing_ambiguity,
        ambiguity_risk,
        why_grouped,
        shared_terms,
        shared_tools,
        shared_rules,
        shared_capability_tags,
        shared_risk_tags,
        shared_source_signals,
    }
}

fn similar_skill_group_from_component(
    candidates: &[SimilarSkillCandidate],
    component: &[usize],
    pairs: &[SimilarSkillPair],
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> SimilarSkillGroup {
    let best_pair = pairs.iter().max_by(|left, right| {
        left.score
            .cmp(&right.score)
            .then_with(|| left.group_type.cmp(right.group_type))
    });
    let mut members = component
        .iter()
        .map(|index| candidates[*index].member.clone())
        .collect::<Vec<_>>();
    let reasons_by_member = similar_skill_member_reasons(component, pairs);
    for (member_index, member) in members.iter_mut().enumerate() {
        if let Some(reasons) = reasons_by_member.get(&member_index) {
            member.similarity_reasons = reasons.clone();
        } else {
            member.similarity_reasons.push(
                "Singleton retained by include_singletons without a peer above threshold."
                    .to_string(),
            );
        }
    }
    members.sort_by(|left, right| {
        left.agent
            .cmp(&right.agent)
            .then_with(|| left.skill_name.cmp(&right.skill_name))
            .then_with(|| left.instance_id.cmp(&right.instance_id))
    });

    let canonical_name = members
        .iter()
        .map(|member| member.skill_name.clone())
        .min()
        .unwrap_or_else(|| "unknown-skill".to_string());
    let canonical_key = normalize_similarity_key(&canonical_name);
    let member_ids = members
        .iter()
        .map(|member| member.instance_id.clone())
        .collect::<Vec<_>>();
    let group_id = stable_similar_group_id(&member_ids);
    let mut evidence_refs = members
        .iter()
        .flat_map(|member| member.evidence_refs.clone())
        .collect::<Vec<_>>();
    let group_ref = push_task_readiness_evidence(
        evidence,
        "similar_skill_group",
        &group_id,
        format!(
            "Similar skill group `{}` with {} member(s) and score {}",
            redact_for_llm_preview(&canonical_key),
            members.len(),
            best_pair.map(|pair| pair.score).unwrap_or(0)
        ),
        None,
        members.first().map(|member| member.instance_id.clone()),
    );
    evidence_refs.push(group_ref);
    evidence_refs.sort();
    evidence_refs.dedup();

    let shared_terms = union_pair_values(pairs, |pair| &pair.shared_terms);
    let shared_tools = union_pair_values(pairs, |pair| &pair.shared_tools);
    let shared_rules = union_pair_values(pairs, |pair| &pair.shared_rules);
    let shared_capability_tags = union_pair_values(pairs, |pair| &pair.shared_capability_tags);
    let shared_risk_tags = union_pair_values(pairs, |pair| &pair.shared_risk_tags);
    let shared_source_signals = union_pair_values(pairs, |pair| &pair.shared_source_signals);
    let mut why_grouped = pairs
        .iter()
        .flat_map(|pair| pair.why_grouped.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    if why_grouped.is_empty() {
        why_grouped
            .push("Singleton retained for review; no peer met the selected threshold.".to_string());
    }
    why_grouped.truncate(8);

    let group_type = best_pair.map(|pair| pair.group_type).unwrap_or("similar");
    let similarity_score = best_pair.map(|pair| pair.score).unwrap_or(0);
    let ambiguity_risk = max_band(pairs.iter().map(|pair| pair.ambiguity_risk)).unwrap_or("low");
    let coverage_redundancy =
        max_band(pairs.iter().map(|pair| pair.coverage_redundancy)).unwrap_or("low");
    let routing_ambiguity =
        max_band(pairs.iter().map(|pair| pair.routing_ambiguity)).unwrap_or("low");
    let title = format!(
        "{}: {} member(s), {} similarity",
        canonical_name,
        members.len(),
        similarity_score
    );
    let summary = format!(
        "{} local skill member(s) grouped as {}. Coverage redundancy is {}; routing ambiguity is {}; ambiguity risk is {}.",
        members.len(),
        group_type,
        coverage_redundancy,
        routing_ambiguity,
        ambiguity_risk
    );

    SimilarSkillGroup {
        group_id,
        rank: 0,
        group_type,
        similarity_score,
        ambiguity_risk,
        coverage_redundancy,
        routing_ambiguity,
        canonical_name,
        canonical_key,
        title,
        summary,
        why_grouped,
        shared_terms,
        shared_tools,
        shared_rules,
        shared_capability_tags,
        shared_risk_tags,
        shared_source_signals,
        members,
        evidence_refs,
        safety_flags: similar_skill_grouping_safety_flags(),
    }
}

fn similar_skill_member_reasons(
    component: &[usize],
    pairs: &[SimilarSkillPair],
) -> BTreeMap<usize, Vec<String>> {
    let component_position = component
        .iter()
        .enumerate()
        .map(|(position, original)| (*original, position))
        .collect::<BTreeMap<_, _>>();
    let mut reasons: BTreeMap<usize, BTreeSet<String>> = BTreeMap::new();
    for pair in pairs {
        let reason = format!(
            "Paired above threshold with score {} via {} evidence.",
            pair.score, pair.group_type
        );
        if let Some(position) = component_position.get(&pair.left) {
            reasons.entry(*position).or_default().insert(reason.clone());
        }
        if let Some(position) = component_position.get(&pair.right) {
            reasons.entry(*position).or_default().insert(reason);
        }
    }
    reasons
        .into_iter()
        .map(|(key, value)| (key, value.into_iter().collect()))
        .collect()
}

fn similar_skill_grouping_blocker_notes(groups: &[SimilarSkillGroup]) -> Vec<String> {
    let mut notes = Vec::new();
    if groups.iter().any(|group| group.routing_ambiguity == "high") {
        notes.push(
            "High routing ambiguity means humans should inspect candidates before selecting a route; no automatic rerouting is performed."
                .to_string(),
        );
    }
    if groups
        .iter()
        .any(|group| group.coverage_redundancy == "high")
    {
        notes.push(
            "High coverage redundancy is advisory only and does not disable, merge, or delete skills."
                .to_string(),
        );
    }
    if groups.iter().any(|group| {
        group
            .members
            .iter()
            .any(|member| !member.enabled || member.state != "loaded")
    }) {
        notes.push(
            "Disabled or non-loaded members are included for confusability review but are not made routable."
                .to_string(),
        );
    }
    if groups.iter().any(|group| group.ambiguity_risk == "high") {
        notes.push(
            "High ambiguity risk is derived from local state, risk, stale/drift, and overlap signals only."
                .to_string(),
        );
    }
    if notes.is_empty() {
        notes.push(
            "Similar skill grouping used local catalog evidence only and found no returned-group blockers."
                .to_string(),
        );
    }
    notes
}

fn similar_skill_grouping_summary(
    indexed_skill_count: usize,
    candidate_skill_count: usize,
    matched_group_count: usize,
    groups: &[SimilarSkillGroup],
) -> SimilarSkillGroupingSummary {
    let duplicate_group_count = groups
        .iter()
        .filter(|group| group.group_type == "duplicate")
        .count();
    let confusable_group_count = groups
        .iter()
        .filter(|group| group.group_type == "confusable")
        .count();
    let coverage_redundancy_group_count = groups
        .iter()
        .filter(|group| group.coverage_redundancy == "high")
        .count();
    let routing_ambiguity_count = groups
        .iter()
        .filter(|group| group.routing_ambiguity != "low")
        .count();
    let summary = if groups.is_empty() {
        "No deterministic similar skill groups matched the selected filters.".to_string()
    } else {
        format!(
            "Returned {} of {} similar skill group(s) from {} candidate skill(s) across {} indexed visible skill(s); {} duplicate group(s), {} high coverage redundancy group(s), and {} routing ambiguity group(s).",
            groups.len(),
            matched_group_count,
            candidate_skill_count,
            indexed_skill_count,
            duplicate_group_count,
            coverage_redundancy_group_count,
            routing_ambiguity_count
        )
    };
    SimilarSkillGroupingSummary {
        indexed_skill_count,
        candidate_skill_count,
        matched_group_count,
        returned_group_count: groups.len(),
        duplicate_group_count,
        confusable_group_count,
        coverage_redundancy_group_count,
        routing_ambiguity_count,
        summary,
    }
}

fn normalize_similarity_key(value: &str) -> String {
    task_readiness_terms(value).join("-")
}

fn sorted_intersection(left: &[String], right: &[String], limit: usize) -> Vec<String> {
    let right = right.iter().collect::<BTreeSet<_>>();
    left.iter()
        .filter(|value| right.contains(value))
        .cloned()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .take(limit)
        .collect()
}

fn union_pair_values<'a>(
    pairs: &'a [SimilarSkillPair],
    values: impl Fn(&'a SimilarSkillPair) -> &'a Vec<String>,
) -> Vec<String> {
    pairs
        .iter()
        .flat_map(values)
        .cloned()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .take(16)
        .collect()
}

fn max_band<'a>(bands: impl Iterator<Item = &'a str>) -> Option<&'static str> {
    let mut max = None;
    let mut score = 0u8;
    for band in bands {
        let band_score = match band {
            "high" => 3,
            "medium" => 2,
            _ => 1,
        };
        if band_score > score {
            score = band_score;
            max = Some(match band_score {
                3 => "high",
                2 => "medium",
                _ => "low",
            });
        }
    }
    max
}

fn stable_similar_group_id(member_ids: &[String]) -> String {
    let mut sorted = member_ids.to_vec();
    sorted.sort();
    let mut hasher = Sha256::new();
    for id in &sorted {
        hasher.update(id.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("similar-group-{:x}", digest)[..26].to_string()
}

fn task_readiness_safety_flags() -> TaskReadinessSafetyFlags {
    TaskReadinessSafetyFlags {
        read_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
    }
}

fn empty_task_readiness_result(
    task: String,
    filters: TaskReadinessFilters,
    catalog_available: bool,
) -> TaskReadinessResult {
    TaskReadinessResult {
        task: task.clone(),
        score: 0,
        band: "blocked",
        summary:
            "No local catalog is available, so task readiness cannot identify candidate skills."
                .to_string(),
        generated_by: "deterministic-service",
        catalog_available,
        filters,
        candidate_skills: Vec::new(),
        missing_gap_notes: vec![
            "Run a local scan before relying on task readiness for routing decisions.".to_string(),
        ],
        blocker_risk_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: TaskReadinessPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "task_readiness",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::TaskReadiness,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(task),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: task_readiness_safety_flags(),
    }
}

fn task_readiness_terms(task: &str) -> Vec<String> {
    let mut seen = BTreeMap::new();
    task.split(|ch: char| !ch.is_ascii_alphanumeric())
        .map(str::trim)
        .filter(|term| term.len() >= 3)
        .map(|term| term.to_ascii_lowercase())
        .filter(|term| {
            !matches!(
                term.as_str(),
                "the"
                    | "and"
                    | "for"
                    | "with"
                    | "from"
                    | "that"
                    | "this"
                    | "into"
                    | "using"
                    | "need"
                    | "task"
            )
        })
        .filter(|term| {
            if let std::collections::btree_map::Entry::Vacant(entry) = seen.entry(term.clone()) {
                entry.insert(());
                true
            } else {
                false
            }
        })
        .collect()
}

struct TaskReadinessCandidateSignals<'a> {
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    quality: Option<&'a SkillQualityScoreResult>,
}

fn task_readiness_candidate(
    task_terms: &[String],
    skill: &SkillDetailRecord,
    signals: TaskReadinessCandidateSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> TaskReadinessCandidate {
    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog metadata for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(&skill.agent),
            redact_for_llm_preview(&skill.scope),
            skill.enabled,
            redact_for_llm_preview(&skill.state)
        ),
        None,
        Some(skill.id.clone()),
    );
    let quality_ref = signals.quality.map(|score| {
        push_task_readiness_evidence(
            evidence,
            "quality_score",
            &skill.id,
            format!("V2.43 quality score {} / 100 ({})", score.score, score.band),
            None,
            Some(skill.id.clone()),
        )
    });

    let searchable = format!(
        "{} {} {} {}",
        skill.name, skill.description, skill.frontmatter_raw, skill.body
    )
    .to_ascii_lowercase();
    let matched_terms = task_terms
        .iter()
        .filter(|term| searchable.contains(term.as_str()))
        .cloned()
        .collect::<Vec<_>>();
    let mut match_reasons = Vec::new();
    if matched_terms.is_empty() {
        match_reasons.push(
            "No direct lexical overlap with the task was found in local metadata/body evidence."
                .to_string(),
        );
    } else {
        match_reasons.push(format!(
            "Matched task term(s): {}.",
            matched_terms
                .iter()
                .take(8)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if skill.description.trim().is_empty() {
        match_reasons
            .push("Description is empty, limiting deterministic task-fit evidence.".to_string());
    } else {
        match_reasons.push(format!(
            "Description evidence: {}",
            redact_for_llm_preview(&skill.description)
        ));
    }

    let mut missing_gap_notes = Vec::new();
    let mut blocker_risk_notes = Vec::new();
    if !skill.enabled {
        blocker_risk_notes.push("Skill is disabled and will not be a ready routing target until reviewed through the existing toggle flow.".to_string());
    }
    if skill.state != "loaded" {
        blocker_risk_notes.push(format!(
            "Skill state is `{}` instead of loaded.",
            redact_for_llm_preview(&skill.state)
        ));
    }
    if skill.scope == Scope::AgentProject.as_str() {
        match_reasons
            .push("Project-scoped skill is visible in the current project context.".to_string());
    }
    if matched_terms.is_empty() {
        missing_gap_notes.push(
            "Task wording did not clearly map to this skill; consider improving description keywords if it should route here."
                .to_string(),
        );
    }

    let mut risk_refs = Vec::new();
    for finding in signals.findings {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        );
        risk_refs.push(evidence_id);
        if matches!(
            finding.effective_severity.as_str(),
            "critical" | "error" | "warning" | "warn"
        ) {
            blocker_risk_notes.push(format!(
                "{} finding `{}` affects readiness.",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id)
            ));
        }
    }
    for conflict in signals.conflicts {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        );
        risk_refs.push(evidence_id);
        blocker_risk_notes
            .push("Same-agent conflict may make runtime selection ambiguous.".to_string());
    }
    for group in signals.analysis_groups {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        );
        risk_refs.push(evidence_id);
        if group.kind == "enabled_mismatch" || group.kind == "duplicate_name" {
            blocker_risk_notes.push(format!(
                "Cross-agent analysis `{}` may affect routing clarity.",
                redact_for_llm_preview(&group.kind)
            ));
        }
    }

    let diagnostic_ref = signals.diagnostic.map(|diagnostic| {
        push_task_readiness_evidence(
            evidence,
            "adapter_diagnostics",
            diagnostic.agent,
            format!(
                "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                diagnostic.display_name,
                diagnostic.status,
                diagnostic.access.writable_status,
                diagnostic.access.install_status
            ),
            None,
            Some(skill.id.clone()),
        )
    });

    let risk_level = task_readiness_risk_level(
        signals.findings,
        signals.conflicts,
        signals.analysis_groups,
        skill,
    );
    let risk_summary = task_readiness_risk_summary(
        risk_level,
        signals.findings,
        signals.conflicts,
        signals.analysis_groups,
    );
    let mut score = (matched_terms.len() as i16 * 12).min(40);
    score += signals
        .quality
        .map(|quality| i16::from(quality.score) / 4)
        .unwrap_or(0);
    if skill.enabled {
        score += 15;
    }
    if skill.state == "loaded" {
        score += 10;
    }
    if !skill.description.trim().is_empty() {
        score += 5;
    }
    score -= task_readiness_risk_deduction(
        signals.findings,
        signals.conflicts,
        signals.analysis_groups,
        skill,
    );
    let score = score.clamp(0, 100) as u8;
    let mut evidence_refs = vec![skill_ref];
    if let Some(quality_ref) = quality_ref {
        evidence_refs.push(quality_ref);
    }
    evidence_refs.extend(risk_refs);
    if let Some(diagnostic_ref) = diagnostic_ref {
        evidence_refs.push(diagnostic_ref);
    }

    TaskReadinessCandidate {
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.clone(),
        scope: skill.scope.clone(),
        enabled: skill.enabled,
        state: skill.state.clone(),
        score,
        band: task_readiness_band(score),
        quality_score: signals.quality.map(|quality| quality.score),
        match_reasons,
        enabled_scope_risk_state: TaskReadinessState {
            enabled: skill.enabled,
            scope: skill.scope.clone(),
            state: skill.state.clone(),
            risk_level,
            risk_summary,
            writable_status: signals
                .diagnostic
                .map(|diagnostic| diagnostic.access.writable_status.to_string()),
            adapter_status: signals
                .diagnostic
                .map(|diagnostic| diagnostic.status.to_string()),
        },
        missing_gap_notes,
        blocker_risk_notes,
        evidence_refs,
    }
}

fn task_readiness_risk_level(
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
    skill: &SkillDetailRecord,
) -> &'static str {
    if !skill.enabled || skill.state != "loaded" {
        return "blocked";
    }
    if findings
        .iter()
        .any(|finding| matches!(finding.effective_severity.as_str(), "critical" | "error"))
        || !conflicts.is_empty()
    {
        return "high";
    }
    if findings
        .iter()
        .any(|finding| matches!(finding.effective_severity.as_str(), "warning" | "warn"))
        || !analysis_groups.is_empty()
    {
        return "medium";
    }
    "low"
}

fn task_readiness_risk_summary(
    risk_level: &'static str,
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
) -> String {
    if risk_level == "low" {
        return "No high-risk local findings, same-agent conflicts, or cross-agent ambiguity were associated with this candidate.".to_string();
    }
    format!(
        "Risk level {risk_level}: {} finding(s), {} same-agent conflict(s), and {} cross-agent analysis group(s) are associated with this candidate.",
        findings.len(),
        conflicts.len(),
        analysis_groups.len()
    )
}

fn task_readiness_risk_deduction(
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
    skill: &SkillDetailRecord,
) -> i16 {
    let mut deduction = 0i16;
    if !skill.enabled {
        deduction += 25;
    }
    if skill.state != "loaded" {
        deduction += 30;
    }
    for finding in findings {
        deduction += match finding.effective_severity.as_str() {
            "critical" => 25,
            "error" => 18,
            "warning" | "warn" => 10,
            "info" => 3,
            _ => 1,
        };
    }
    deduction += (conflicts.len() as i16 * 18).min(30);
    deduction += (analysis_groups.len() as i16 * 6).min(18);
    deduction
}

fn task_readiness_overall_score(candidates: &[TaskReadinessCandidate]) -> u8 {
    let Some(best) = candidates.first() else {
        return 0;
    };
    let secondary = candidates
        .get(1)
        .map(|candidate| candidate.score)
        .unwrap_or(0);
    ((u16::from(best.score) * 3 + u16::from(secondary)) / 4).min(100) as u8
}

fn task_readiness_band(score: u8) -> &'static str {
    match score {
        80..=100 => "ready",
        60..=79 => "mostly_ready",
        35..=59 => "partial",
        1..=34 => "weak",
        _ => "blocked",
    }
}

fn task_readiness_summary(
    score: u8,
    band: &'static str,
    candidates: &[TaskReadinessCandidate],
    missing_gap_notes: &[String],
) -> String {
    match candidates.first() {
        Some(best) => format!(
            "Task readiness is {band} ({score}/100). Top local candidate is `{}` for {} with score {} and risk {}.",
            best.skill_name,
            best.agent,
            best.score,
            best.enabled_scope_risk_state.risk_level
        ),
        None if missing_gap_notes.is_empty() => {
            "Task readiness is blocked because no local candidate evidence was available."
                .to_string()
        }
        None => format!(
            "Task readiness is blocked because no local candidate evidence was available. {}",
            missing_gap_notes.join(" ")
        ),
    }
}

fn task_readiness_blocker_notes(candidates: &[TaskReadinessCandidate]) -> Vec<String> {
    let mut notes = candidates
        .iter()
        .flat_map(|candidate| candidate.blocker_risk_notes.iter().cloned())
        .collect::<Vec<_>>();
    if notes.is_empty() {
        notes.push(
            "No candidate-level blockers were found in local catalog/rule/conflict/analysis evidence."
                .to_string(),
        );
    }
    notes.sort();
    notes.dedup();
    notes.truncate(10);
    notes
}

fn routing_confidence_safety_flags() -> RoutingConfidenceSafetyFlags {
    RoutingConfidenceSafetyFlags {
        read_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
    }
}

fn agent_readiness_safety_flags() -> AgentReadinessSafetyFlags {
    AgentReadinessSafetyFlags {
        read_only: true,
        app_local_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        write_actions_available: false,
        skill_files_mutated: false,
        agent_config_mutated: false,
        script_execution_allowed: false,
        execution_actions_available: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        raw_trace_persisted: false,
        cloud_sync_performed: false,
        telemetry_emitted: false,
    }
}

fn empty_agent_readiness_comparison(
    task: String,
    filters: AgentReadinessComparisonFilters,
    catalog_available: bool,
    note: &str,
) -> AgentReadinessComparisonResult {
    AgentReadinessComparisonResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters,
        summary: AgentReadinessComparisonSummary {
            agent_count: 0,
            candidate_count: 0,
            ready_agent_count: 0,
            partial_agent_count: 0,
            blocked_agent_count: 0,
            gap_issue_count: 1,
            recommended_agent: None,
            summary: note.to_string(),
        },
        agent_rows: Vec::new(),
        recommended_agent: None,
        gap_issue_rows: vec![AgentReadinessGapIssueRow {
            source: "task.compareAgentReadiness",
            severity: "high",
            agent: "all".to_string(),
            title: "No cross-agent readiness candidates".to_string(),
            detail: note.to_string(),
            evidence_refs: Vec::new(),
        }],
        evidence_references: Vec::new(),
        prompt_request: AgentReadinessPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "task_readiness",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::TaskReadiness,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(task),
            },
            note: "Prompt preview is unavailable until local catalog evidence produces cross-agent candidates."
                .to_string(),
        },
        safety_flags: agent_readiness_safety_flags(),
    }
}

fn normalize_agent_filter_list(agents: Vec<String>) -> Vec<String> {
    let mut normalized = agents
        .into_iter()
        .filter_map(|agent| normalize_agent_label(&agent))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    normalized.sort_by_key(|agent| agent_readiness_agent_order(agent));
    normalized
}

fn normalize_agent_label(agent: &str) -> Option<String> {
    let normalized = agent.trim().to_ascii_lowercase().replace(['_', ' '], "-");
    let canonical = match normalized.as_str() {
        "" => return None,
        "claude" | "claude-code" | "claudecode" => "claude-code",
        "codex" => "codex",
        "opencode" | "open-code" => "opencode",
        "pi" => "pi",
        "hermes" => "hermes",
        "openclaw" | "open-claw" => "openclaw",
        other => other,
    };
    Some(canonical.to_string())
}

fn agent_readiness_agents_for_comparison(
    skills: &[SkillRecord],
    adapter_ctx: &AdapterContext,
    requested_agents: &[String],
) -> Vec<String> {
    if !requested_agents.is_empty() {
        return requested_agents.to_vec();
    }
    let mut agents = skills
        .iter()
        .filter_map(|skill| normalize_agent_label(&skill.agent))
        .filter(|agent| agent != "tool-global")
        .collect::<BTreeSet<_>>();
    for diagnostic in list_adapter_diagnostics(adapter_ctx) {
        let present = diagnostic.config.detected_count > 0
            || diagnostic.roots.iter().any(|root| root.exists)
            || skills.iter().any(|skill| skill.agent == diagnostic.agent);
        if present {
            agents.insert(diagnostic.agent.to_string());
        }
    }
    let mut agents = agents.into_iter().collect::<Vec<_>>();
    agents.sort_by_key(|agent| agent_readiness_agent_order(agent));
    agents
}

fn agent_readiness_agent_order(agent: &str) -> usize {
    match agent {
        "claude-code" => 0,
        "codex" => 1,
        "opencode" => 2,
        "pi" => 3,
        "hermes" => 4,
        "openclaw" => 5,
        _ => 99,
    }
}

fn agent_readiness_display_name(agent: &str) -> String {
    match agent {
        "claude-code" => "Claude Code",
        "codex" => "Codex",
        "opencode" => "opencode",
        "pi" => "Pi",
        "hermes" => "Hermes",
        "openclaw" => "OpenClaw",
        other => other,
    }
    .to_string()
}

fn agent_readiness_row_from_results(
    agent: &str,
    readiness: &TaskReadinessResult,
    ranking: &SkillRouteRankingResult,
    accuracy_context: Option<AgentReadinessAccuracyContext>,
    benchmark_context: Option<AgentReadinessBenchmarkContext>,
) -> AgentReadinessComparisonRow {
    let best_route = ranking.route_candidates.first();
    let best_candidate = best_route.map(|route| AgentReadinessBestCandidate {
        instance_id: route.instance_id.clone(),
        definition_id: route.definition_id.clone(),
        skill_name: route.skill_name.clone(),
        scope: route.scope.clone(),
        enabled: route.enabled,
        state: route.state.clone(),
        readiness_score: route.readiness_score,
        readiness_band: route.readiness_band,
        routing_confidence_score: route.confidence_score,
        routing_confidence_band: route.confidence_band,
        quality_score: route.quality_score,
    });
    let blocker_count = readiness
        .candidate_skills
        .iter()
        .map(|candidate| candidate.blocker_risk_notes.len())
        .sum::<usize>();
    let gap_count = readiness.missing_gap_notes.len()
        + readiness
            .candidate_skills
            .iter()
            .map(|candidate| candidate.missing_gap_notes.len())
            .sum::<usize>();
    let mut reasons = Vec::new();
    if let Some(route) = best_route {
        reasons.extend(route.match_reasons.iter().take(3).cloned());
        reasons.extend(route.confidence_rationale.iter().take(2).cloned());
    } else {
        reasons.push("No visible route candidate for this agent matched the task.".to_string());
    }
    let mut blocker_notes = readiness
        .candidate_skills
        .iter()
        .flat_map(|candidate| candidate.blocker_risk_notes.iter().cloned())
        .collect::<Vec<_>>();
    if blocker_notes.is_empty() && readiness.candidate_skills.is_empty() {
        blocker_notes.push("No candidate evidence was available for this agent.".to_string());
    }
    blocker_notes.sort();
    blocker_notes.dedup();
    blocker_notes.truncate(6);
    let mut gap_notes = readiness.missing_gap_notes.clone();
    gap_notes.extend(
        readiness
            .candidate_skills
            .iter()
            .flat_map(|candidate| candidate.missing_gap_notes.iter().cloned()),
    );
    gap_notes.sort();
    gap_notes.dedup();
    gap_notes.truncate(6);
    let routing_confidence_score = ranking.overall_confidence_score;
    let comparison_score = agent_readiness_comparison_score(
        readiness.score,
        routing_confidence_score,
        accuracy_context.as_ref(),
        benchmark_context.as_ref(),
    );
    AgentReadinessComparisonRow {
        rank: 0,
        agent: agent.to_string(),
        display_name: agent_readiness_display_name(agent),
        comparison_score,
        readiness_score: readiness.score,
        readiness_band: readiness.band,
        routing_confidence_score,
        routing_confidence_band: ranking.overall_confidence_band,
        candidate_count: readiness.candidate_skills.len(),
        best_candidate,
        enabled_scope_risk_state: best_route.map(|route| route.enabled_scope_risk_state.clone()),
        blocker_count,
        gap_count,
        reasons,
        blocker_notes,
        gap_notes,
        routing_accuracy_context: accuracy_context,
        benchmark_context,
        evidence_refs: best_route
            .map(|route| route.evidence_refs.clone())
            .unwrap_or_default(),
    }
}

fn agent_readiness_comparison_score(
    readiness_score: u8,
    routing_confidence_score: u8,
    accuracy_context: Option<&AgentReadinessAccuracyContext>,
    benchmark_context: Option<&AgentReadinessBenchmarkContext>,
) -> u8 {
    let mut score =
        ((u16::from(readiness_score) * 3 + u16::from(routing_confidence_score) * 2) / 5) as i16;
    if let Some(context) = accuracy_context {
        score -= (context.regression_count as i16 * 6).min(18);
        score -= (context.benchmark_gap_count as i16 * 4).min(12);
        if context.trace_count > 0 && context.accuracy_rate >= 0.8 {
            score += 3;
        }
    }
    if let Some(context) = benchmark_context {
        score -= (context.gap_count as i16 * 4).min(12);
        score -= (context.regression_count as i16 * 6).min(18);
        if context.evaluated_count > 0 && context.gap_count == 0 {
            score += 2;
        }
    }
    score.clamp(0, 100) as u8
}

fn agent_readiness_gap_issue_rows(
    row: &AgentReadinessComparisonRow,
) -> Vec<AgentReadinessGapIssueRow> {
    let mut issues = Vec::new();
    if row.candidate_count == 0 {
        issues.push(AgentReadinessGapIssueRow {
            source: "task.checkReadiness",
            severity: "high",
            agent: row.agent.clone(),
            title: "No candidate skill for agent".to_string(),
            detail: "No visible skill candidate matched the task for this agent.".to_string(),
            evidence_refs: Vec::new(),
        });
    }
    for note in &row.gap_notes {
        issues.push(AgentReadinessGapIssueRow {
            source: "task.checkReadiness",
            severity: "medium",
            agent: row.agent.clone(),
            title: "Readiness gap".to_string(),
            detail: note.clone(),
            evidence_refs: row.evidence_refs.clone(),
        });
    }
    for note in &row.blocker_notes {
        issues.push(AgentReadinessGapIssueRow {
            source: "task.checkReadiness",
            severity: "high",
            agent: row.agent.clone(),
            title: "Readiness blocker or risk".to_string(),
            detail: note.clone(),
            evidence_refs: row.evidence_refs.clone(),
        });
    }
    if let Some(context) = &row.routing_accuracy_context {
        if context.benchmark_gap_count > 0 || context.regression_count > 0 {
            issues.push(AgentReadinessGapIssueRow {
                source: "routing.accuracyDashboard",
                severity: if context.regression_count > 0 {
                    "critical"
                } else {
                    "medium"
                },
                agent: row.agent.clone(),
                title: "Routing accuracy context requires review".to_string(),
                detail: format!(
                    "{} benchmark gap(s) and {} regression(s) are associated with this agent.",
                    context.benchmark_gap_count, context.regression_count
                ),
                evidence_refs: row.evidence_refs.clone(),
            });
        }
    }
    if let Some(context) = &row.benchmark_context {
        if context.gap_count > 0 || context.regression_count > 0 {
            issues.push(AgentReadinessGapIssueRow {
                source: "task.evaluateBenchmarks",
                severity: if context.regression_count > 0 {
                    "critical"
                } else {
                    "medium"
                },
                agent: row.agent.clone(),
                title: "Benchmark context requires review".to_string(),
                detail: format!(
                    "{} benchmark gap(s) and {} regression(s) are associated with this agent.",
                    context.gap_count, context.regression_count
                ),
                evidence_refs: row.evidence_refs.clone(),
            });
        }
    }
    issues
}

fn agent_readiness_recommendation(
    row: &AgentReadinessComparisonRow,
) -> AgentReadinessRecommendation {
    AgentReadinessRecommendation {
        agent: row.agent.clone(),
        display_name: row.display_name.clone(),
        comparison_score: row.comparison_score,
        readiness_score: row.readiness_score,
        routing_confidence_score: row.routing_confidence_score,
        skill_name: row
            .best_candidate
            .as_ref()
            .map(|candidate| candidate.skill_name.clone()),
        reason: match &row.best_candidate {
            Some(candidate) => format!(
                "{} has the strongest local readiness/routing score for `{}` with risk {}.",
                row.display_name,
                candidate.skill_name,
                row.enabled_scope_risk_state
                    .as_ref()
                    .map(|state| state.risk_level)
                    .unwrap_or("unknown")
            ),
            None => format!(
                "{} is ranked highest, but no concrete candidate was available.",
                row.display_name
            ),
        },
    }
}

fn agent_readiness_summary(
    rows: &[AgentReadinessComparisonRow],
    gap_issue_rows: &[AgentReadinessGapIssueRow],
    recommended_agent: &Option<AgentReadinessRecommendation>,
) -> AgentReadinessComparisonSummary {
    let candidate_count = rows.iter().map(|row| row.candidate_count).sum();
    let ready_agent_count = rows
        .iter()
        .filter(|row| matches!(row.readiness_band, "ready" | "mostly_ready"))
        .count();
    let blocked_agent_count = rows
        .iter()
        .filter(|row| row.candidate_count == 0 || row.readiness_band == "blocked")
        .count();
    let partial_agent_count = rows
        .len()
        .saturating_sub(ready_agent_count + blocked_agent_count);
    let summary = if let Some(recommended) = recommended_agent {
        format!(
            "Compared {} agent(s) and {} candidate skill(s); recommended {} with comparison score {}/100.",
            rows.len(),
            candidate_count,
            recommended.display_name,
            recommended.comparison_score
        )
    } else if rows.is_empty() {
        "No agent readiness rows were available for the selected filters.".to_string()
    } else {
        format!(
            "Compared {} agent(s), but no agent produced a usable candidate for recommendation.",
            rows.len()
        )
    };
    AgentReadinessComparisonSummary {
        agent_count: rows.len(),
        candidate_count,
        ready_agent_count,
        partial_agent_count,
        blocked_agent_count,
        gap_issue_count: gap_issue_rows.len(),
        recommended_agent: recommended_agent
            .as_ref()
            .map(|recommendation| recommendation.agent.clone()),
        summary,
    }
}

fn agent_readiness_accuracy_context(
    dashboard: RoutingAccuracyDashboardResult,
) -> BTreeMap<String, AgentReadinessAccuracyContext> {
    dashboard
        .agent_rows
        .into_iter()
        .map(|row| {
            (
                row.agent,
                AgentReadinessAccuracyContext {
                    trace_count: row.trace_count,
                    accuracy_rate: row.accuracy_rate,
                    benchmark_count: row.benchmark_count,
                    benchmark_gap_count: row.benchmark_gap_count,
                    regression_count: row.regression_count,
                    recent_evidence_count: row.recent_evidence_count,
                    notes: row.notes,
                },
            )
        })
        .collect()
}

fn agent_readiness_benchmark_context(
    evaluation: TaskBenchmarkEvaluationResult,
) -> BTreeMap<String, AgentReadinessBenchmarkContext> {
    let mut by_agent: BTreeMap<String, AgentReadinessBenchmarkContext> = BTreeMap::new();
    for item in evaluation.benchmark_results {
        let Some(route) = item.top_route else {
            continue;
        };
        let context = by_agent.entry(route.agent).or_default();
        context.evaluated_count += 1;
        if matches!(
            item.expected_match_status,
            "expected_match" | "acceptable_match"
        ) {
            context.matched_count += 1;
        } else {
            context.gap_count += 1;
        }
        context.notes.extend(item.gap_notes);
        context.notes.extend(item.blocker_notes);
    }
    for context in by_agent.values_mut() {
        context.notes.sort();
        context.notes.dedup();
        context.notes.truncate(6);
    }
    by_agent
}

fn task_benchmark_safety_flags() -> TaskBenchmarkSafetyFlags {
    TaskBenchmarkSafetyFlags {
        read_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
    }
}

fn trace_import_safety_flags() -> TraceImportSafetyFlags {
    TraceImportSafetyFlags {
        read_only: true,
        app_local_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        skill_files_mutated: false,
        agent_config_mutated: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_trace_persisted: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        cloud_sync_performed: false,
        telemetry_emitted: false,
    }
}

#[derive(Debug, Clone, Default)]
struct RoutingAccuracyAgentAggregate {
    outcomes: RoutingAccuracyOutcomeCounts,
    benchmark_count: usize,
    benchmark_matched_count: usize,
    benchmark_gap_count: usize,
    regression_count: usize,
    recent_evidence_count: usize,
    notes: Vec<String>,
}

impl RoutingAccuracyAgentAggregate {
    fn record_trace(&mut self, outcome: &'static str) {
        routing_accuracy_increment_counts(&mut self.outcomes, outcome);
        self.recent_evidence_count += 1;
    }

    fn into_row(mut self, agent: String) -> RoutingAccuracyAgentRow {
        let known = self.outcomes.hit
            + self.outcomes.miss
            + self.outcomes.wrong_pick
            + self.outcomes.ambiguous;
        let trace_count = known + self.outcomes.unknown;
        let accuracy_rate = routing_accuracy_rate(self.outcomes.hit, known);
        if self.benchmark_gap_count > 0 {
            self.notes.push(format!(
                "{} benchmark gap(s) require review.",
                self.benchmark_gap_count
            ));
        }
        if self.regression_count > 0 {
            self.notes.push(format!(
                "{} routing regression(s) detected.",
                self.regression_count
            ));
        }
        self.notes.sort();
        self.notes.dedup();
        RoutingAccuracyAgentRow {
            agent,
            trace_count,
            outcomes: self.outcomes,
            accuracy_rate,
            benchmark_count: self.benchmark_count,
            benchmark_matched_count: self.benchmark_matched_count,
            benchmark_gap_count: self.benchmark_gap_count,
            regression_count: self.regression_count,
            recent_evidence_count: self.recent_evidence_count,
            notes: self.notes,
        }
    }
}

fn routing_accuracy_safety_flags() -> RoutingAccuracySafetyFlags {
    RoutingAccuracySafetyFlags {
        read_only: true,
        app_local_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        write_actions_available: false,
        skill_files_mutated: false,
        agent_config_mutated: false,
        script_execution_allowed: false,
        execution_actions_available: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        raw_trace_persisted: false,
        cloud_sync_performed: false,
        telemetry_emitted: false,
    }
}

fn routing_accuracy_normalize_outcome(outcome: &str) -> &'static str {
    match outcome {
        "hit" => "hit",
        "miss" => "miss",
        "wrong_pick" => "wrong_pick",
        "ambiguous" => "ambiguous",
        _ => "unknown",
    }
}

fn routing_accuracy_increment_summary(
    summary: &mut RoutingAccuracyDashboardSummary,
    outcome: &'static str,
) {
    match outcome {
        "hit" => summary.hit_count += 1,
        "miss" => summary.miss_count += 1,
        "wrong_pick" => summary.wrong_pick_count += 1,
        "ambiguous" => summary.ambiguous_count += 1,
        _ => summary.unknown_count += 1,
    }
}

fn routing_accuracy_increment_counts(
    counts: &mut RoutingAccuracyOutcomeCounts,
    outcome: &'static str,
) {
    match outcome {
        "hit" => counts.hit += 1,
        "miss" => counts.miss += 1,
        "wrong_pick" => counts.wrong_pick += 1,
        "ambiguous" => counts.ambiguous += 1,
        _ => counts.unknown += 1,
    }
}

fn routing_accuracy_rate(numerator: usize, denominator: usize) -> f64 {
    if denominator == 0 {
        return 0.0;
    }
    ((numerator as f64 / denominator as f64) * 10_000.0).round() / 10_000.0
}

fn routing_accuracy_agent_matches(candidate: &str, agent_filter: &Option<String>) -> bool {
    match agent_filter.as_deref() {
        Some(filter) => candidate.eq_ignore_ascii_case(filter),
        None => true,
    }
}

fn routing_accuracy_agent_matches_import(
    agent_filter: &Option<String>,
    import: &TraceImportRecord,
) -> bool {
    import
        .agent
        .as_deref()
        .is_some_and(|agent| routing_accuracy_agent_matches(agent, agent_filter))
        || import
            .analysis
            .detected_skills
            .iter()
            .any(|skill| routing_accuracy_agent_matches(&skill.agent, agent_filter))
        || agent_filter.is_none()
}

fn routing_accuracy_agent_matches_benchmark(
    agent_filter: &Option<String>,
    item: &TaskBenchmarkEvaluationItem,
) -> bool {
    item.top_route
        .as_ref()
        .is_some_and(|route| routing_accuracy_agent_matches(&route.agent, agent_filter))
        || agent_filter.is_none()
}

fn routing_accuracy_agent_matches_regression(
    agent_filter: &Option<String>,
    item: &RoutingRegressionItem,
) -> bool {
    routing_accuracy_regression_agent(item)
        .as_deref()
        .is_some_and(|agent| routing_accuracy_agent_matches(agent, agent_filter))
        || agent_filter.is_none()
}

fn routing_accuracy_trace_agent(import: &TraceImportRecord) -> String {
    import
        .agent
        .clone()
        .or_else(|| {
            import
                .analysis
                .detected_skills
                .first()
                .map(|skill| skill.agent.clone())
        })
        .unwrap_or_else(|| "unknown".to_string())
}

fn routing_accuracy_benchmark_agent(item: &TaskBenchmarkEvaluationItem) -> String {
    item.top_route
        .as_ref()
        .map(|route| route.agent.clone())
        .unwrap_or_else(|| "unknown".to_string())
}

fn routing_accuracy_regression_agent(item: &RoutingRegressionItem) -> Option<String> {
    item.current
        .as_ref()
        .and_then(|current| current.top_route.as_ref())
        .map(|route| route.agent.clone())
        .or_else(|| {
            item.baseline
                .as_ref()
                .and_then(|baseline| baseline.top_route.as_ref())
                .map(|route| route.agent.clone())
        })
}

fn routing_accuracy_trace_detail(import: &TraceImportRecord) -> String {
    let detected = import.analysis.detected_skills.len();
    if let Some(task) = &import.task {
        format!(
            "Trace outcome {} for `{}` with {} detected skill(s).",
            import.analysis.outcome, task, detected
        )
    } else {
        format!(
            "Trace outcome {} with {} detected skill(s).",
            import.analysis.outcome, detected
        )
    }
}

fn routing_accuracy_benchmark_severity(item: &TaskBenchmarkEvaluationItem) -> &'static str {
    match item.expected_match_status {
        "blocked_no_route" | "mismatch" => "high",
        "acceptable_match" | "no_expectation" => "medium",
        _ if !item.blocker_notes.is_empty() => "high",
        _ if !item.gap_notes.is_empty() => "medium",
        _ => "low",
    }
}

fn routing_accuracy_benchmark_issue_detail(item: &TaskBenchmarkEvaluationItem) -> String {
    let mut parts = vec![format!(
        "Benchmark status {} with score {}/100.",
        item.expected_match_status, item.score
    )];
    parts.extend(item.blocker_notes.clone());
    parts.extend(item.gap_notes.clone());
    parts.join(" ")
}

fn routing_accuracy_regression_detail(item: &RoutingRegressionItem) -> String {
    let mut parts = Vec::new();
    if let Some(delta) = item.score_delta {
        parts.push(format!("score delta {delta}"));
    }
    if let Some(delta) = item.confidence_delta {
        parts.push(format!("confidence delta {delta}"));
    }
    if parts.is_empty() {
        item.reasons.join(" ")
    } else {
        parts.join(", ")
    }
}

fn routing_accuracy_summary_text(
    summary: &RoutingAccuracyDashboardSummary,
    catalog_available: bool,
) -> String {
    if summary.trace_count == 0 && summary.benchmark_count == 0 {
        if catalog_available {
            return "No routing accuracy evidence matched the selected filters.".to_string();
        }
        return "No routing accuracy evidence matched the selected filters, and no local catalog is available.".to_string();
    }
    format!(
        "Reviewed {} trace import(s), {} benchmark(s), and {} regression(s); hit rate {:.0}% across known trace outcomes.",
        summary.trace_count,
        summary.benchmark_count,
        summary.regression_count,
        summary.accuracy_rate * 100.0
    )
}

fn routing_accuracy_severity_rank(severity: &str) -> u8 {
    match severity {
        "critical" => 0,
        "high" => 1,
        "medium" => 2,
        "low" => 3,
        _ => 4,
    }
}

fn routing_accuracy_prompt_request(
    imports: &[TraceImportRecord],
    benchmark_results: &[TaskBenchmarkEvaluationItem],
) -> RoutingAccuracyPromptRequest {
    let benchmark_route = benchmark_results.iter().find_map(|item| {
        item.top_route
            .as_ref()
            .map(|route| (item.task.clone(), route))
    });
    let (available, instance_ids, task, note) = if let Some((task, route)) = benchmark_route {
        (
            true,
            vec![route.instance_id.clone()],
            Some(task),
            "Optional provider-backed dashboard explanation must be requested through prompt preview and explicit confirmation; routing.accuracyDashboard never sends provider traffic.".to_string(),
        )
    } else if let Some(import) = imports
        .iter()
        .find(|import| import.task.is_some() && !import.analysis.detected_skills.is_empty())
    {
        (
            true,
            import
                .analysis
                .detected_skills
                .iter()
                .map(|skill| skill.instance_id.clone())
                .collect(),
            import.task.clone(),
            "Optional provider-backed dashboard explanation must be requested through prompt preview and explicit confirmation; routing.accuracyDashboard never sends provider traffic.".to_string(),
        )
    } else {
        (
            false,
            Vec::new(),
            None,
            "Prompt preview is unavailable until local routing evidence includes a task and route candidate.".to_string(),
        )
    };
    RoutingAccuracyPromptRequest {
        available,
        preview_method: "llm.previewPrompt",
        confirm_method: "llm.confirmPromptAndSend",
        action: "routing_confidence",
        request: LlmPreviewPromptParams {
            action: LlmPromptActionKind::RoutingConfidence,
            profile_id: None,
            skill_instance_id: None,
            instance_ids,
            analysis_kind: None,
            user_intent: task,
        },
        note,
    }
}

fn trace_import_redaction_summary_from(
    summary: LlmPromptRedactionSummary,
) -> TraceImportRedactionSummary {
    TraceImportRedactionSummary {
        status: "redacted-local-only".to_string(),
        redacted_value_count: summary.redacted_value_count,
        redacted_fields: summary.redacted_fields,
        placeholders: summary
            .placeholders
            .into_iter()
            .map(str::to_string)
            .collect(),
        raw_trace_persisted: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        raw_secret_returned: false,
    }
}

fn trace_import_redaction_summary_default() -> TraceImportRedactionSummary {
    TraceImportRedactionSummary {
        status: "redacted-local-only".to_string(),
        redacted_value_count: 0,
        redacted_fields: Vec::new(),
        placeholders: vec![
            "$HOME".to_string(),
            "<project-root>".to_string(),
            "<project-cwd>".to_string(),
            "<app-data-dir>".to_string(),
            "<redacted>".to_string(),
            "<redacted-url>".to_string(),
        ],
        raw_trace_persisted: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        raw_secret_returned: false,
    }
}

fn trace_content_hash(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    let digest = hasher.finalize();
    hex_prefix(&digest, 16)
}

fn generated_trace_import_id(title: &str, content_hash: &str, imported_at: i64) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(content_hash.as_bytes());
    hasher.update(b"\0");
    hasher.update(imported_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("trace-import-{}", hex_prefix(&digest, 12))
}

fn sanitize_trace_import_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

fn redact_normalized_string_list(
    values: Vec<String>,
    roots: &[(String, &'static str)],
) -> Vec<String> {
    let mut redactor = PromptRedactor::new(roots);
    normalize_string_list(
        values
            .into_iter()
            .map(|value| redactor.redact(&value))
            .collect(),
    )
}

fn truncate_chars(value: &str, max_chars: usize) -> String {
    let mut truncated = value.chars().take(max_chars).collect::<String>();
    if value.chars().count() > max_chars {
        truncated.push_str("...");
    }
    truncated
}

fn trace_outcome_reasons(
    outcome: &str,
    detected_count: usize,
    matching_expected: usize,
    unexpected_detected: usize,
    expected_present: bool,
    agent_filter: Option<&str>,
) -> Vec<String> {
    let mut reasons = Vec::new();
    match outcome {
        "hit" => reasons.push(format!(
            "Detected {} skill reference(s) and all matched expected skill refs/names.",
            detected_count
        )),
        "miss" => reasons.push(
            "Expected skill refs/names were provided, but no matching local catalog skill was detected in the trace."
                .to_string(),
        ),
        "wrong_pick" => reasons.push(format!(
            "Detected {} local catalog skill reference(s), but none matched expected skill refs/names.",
            detected_count
        )),
        "ambiguous" => {
            if matching_expected > 0 {
                reasons.push(format!(
                    "Detected {} expected skill reference(s) plus {} other local catalog skill reference(s).",
                    matching_expected, unexpected_detected
                ));
            } else {
                reasons.push(format!(
                    "Detected {} local catalog skill reference(s), so the trace is ambiguous without expected skill refs/names.",
                    detected_count
                ));
            }
        }
        _ => {
            if expected_present {
                reasons.push(
                    "Local catalog evidence was insufficient to classify the imported trace."
                        .to_string(),
                );
            } else {
                reasons.push(
                    "No expected skill refs/names were provided; routing accuracy cannot be classified deterministically."
                        .to_string(),
                );
            }
        }
    }
    if let Some(agent) = agent_filter.filter(|agent| !agent.is_empty()) {
        reasons.push(format!("Detection was filtered to agent `{}`.", agent));
    }
    reasons
}

fn task_benchmark_evaluation_item(
    benchmark: &TaskBenchmarkRecord,
    ranking: SkillRouteRankingResult,
) -> TaskBenchmarkEvaluationItem {
    let top_route = ranking.route_candidates.first();
    let (expected_match_status, expected_match_reasons) =
        task_benchmark_match_status(benchmark, top_route);
    let route_confidence_score = top_route
        .map(|candidate| candidate.confidence_score)
        .unwrap_or(ranking.overall_confidence_score);
    let route_confidence_band = top_route
        .map(|candidate| candidate.confidence_band)
        .unwrap_or(ranking.overall_confidence_band);
    let score = task_benchmark_score(route_confidence_score, expected_match_status);
    let mut gap_notes = ranking.likely_miss_risks.clone();
    if gap_notes.is_empty() {
        gap_notes.push(
            "No benchmark-level miss risk was detected from local routing evidence.".to_string(),
        );
    }
    let mut blocker_notes = ranking.likely_wrong_pick_risks.clone();
    blocker_notes.extend(ranking.ambiguity_warnings.clone());
    if blocker_notes.is_empty() {
        blocker_notes.push(
            "No benchmark-level blocker was detected from local routing evidence.".to_string(),
        );
    }
    let evidence_refs = top_route
        .map(|candidate| candidate.evidence_refs.clone())
        .unwrap_or_default();
    TaskBenchmarkEvaluationItem {
        benchmark_id: benchmark.id.clone(),
        title: benchmark.title.clone(),
        task: ranking.task,
        score,
        band: task_benchmark_band(score),
        expected_match_status,
        expected_match_reasons,
        top_route: top_route.map(task_benchmark_route_summary),
        route_confidence_score,
        route_confidence_band,
        gap_notes,
        blocker_notes,
        evidence_refs,
        safety_flags: task_benchmark_safety_flags(),
    }
}

fn task_benchmark_match_status(
    benchmark: &TaskBenchmarkRecord,
    top_route: Option<&SkillRouteCandidate>,
) -> (&'static str, Vec<String>) {
    let Some(route) = top_route else {
        return (
            "blocked_no_route",
            vec!["No local route candidate was available for this benchmark.".to_string()],
        );
    };
    let expected_refs = benchmark
        .expected_skill_refs
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let expected_names = benchmark
        .expected_skill_names
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let acceptable_agents = benchmark
        .acceptable_agents
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let acceptable_scopes = benchmark
        .acceptable_scopes
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();

    let route_refs = [
        route.instance_id.to_ascii_lowercase(),
        route.definition_id.to_ascii_lowercase(),
    ];
    if expected_refs
        .iter()
        .any(|expected| route_refs.iter().any(|actual| actual == expected))
    {
        return (
            "expected_match",
            vec![format!(
                "Top route `{}` matched an expected skill reference.",
                route.skill_name
            )],
        );
    }
    if expected_names
        .iter()
        .any(|expected| expected == &route.skill_name.to_ascii_lowercase())
    {
        return (
            "expected_match",
            vec![format!(
                "Top route `{}` matched an expected skill name.",
                route.skill_name
            )],
        );
    }

    let agent_ok = acceptable_agents.is_empty()
        || acceptable_agents
            .iter()
            .any(|agent| agent == &route.agent.to_ascii_lowercase());
    let scope_ok = acceptable_scopes.is_empty()
        || acceptable_scopes
            .iter()
            .any(|scope| scope == &route.scope.to_ascii_lowercase());
    if (agent_ok && scope_ok) && (!acceptable_agents.is_empty() || !acceptable_scopes.is_empty()) {
        return (
            "acceptable_match",
            vec![format!(
                "Top route `{}` matched acceptable agent/scope constraints.",
                route.skill_name
            )],
        );
    }
    if expected_refs.is_empty()
        && expected_names.is_empty()
        && acceptable_agents.is_empty()
        && acceptable_scopes.is_empty()
    {
        return (
            "no_expectation",
            vec![
                "Benchmark has no expected skill refs/names or acceptable agent/scope constraints."
                    .to_string(),
            ],
        );
    }

    (
        "mismatch",
        vec![format!(
            "Top route `{}` ({}, {}) did not match benchmark expectations.",
            route.skill_name, route.agent, route.scope
        )],
    )
}

fn task_benchmark_route_summary(candidate: &SkillRouteCandidate) -> TaskBenchmarkRouteSummary {
    TaskBenchmarkRouteSummary {
        instance_id: candidate.instance_id.clone(),
        definition_id: candidate.definition_id.clone(),
        skill_name: candidate.skill_name.clone(),
        agent: candidate.agent.clone(),
        scope: candidate.scope.clone(),
        confidence_score: candidate.confidence_score,
        confidence_band: candidate.confidence_band,
        readiness_score: candidate.readiness_score,
        readiness_band: candidate.readiness_band,
    }
}

fn task_benchmark_score(route_confidence_score: u8, expected_match_status: &str) -> u8 {
    match expected_match_status {
        "expected_match" => route_confidence_score,
        "acceptable_match" => route_confidence_score.saturating_sub(8),
        "no_expectation" => route_confidence_score.min(60),
        "mismatch" => route_confidence_score / 2,
        _ => 0,
    }
}

fn task_benchmark_band(score: u8) -> &'static str {
    match score {
        80..=100 => "pass",
        60..=79 => "mostly_pass",
        35..=59 => "partial",
        1..=34 => "fail",
        _ => "blocked",
    }
}

fn task_benchmark_summary(
    results: &[TaskBenchmarkEvaluationItem],
    catalog_available: bool,
) -> String {
    if results.is_empty() {
        if catalog_available {
            return "No task benchmarks are saved in app-local storage.".to_string();
        }
        return "No task benchmarks were evaluated and no local catalog is available.".to_string();
    }
    let passing = results
        .iter()
        .filter(|result| {
            matches!(
                result.expected_match_status,
                "expected_match" | "acceptable_match"
            )
        })
        .count();
    let average = results
        .iter()
        .map(|result| u16::from(result.score))
        .sum::<u16>()
        / u16::try_from(results.len()).unwrap_or(1);
    format!(
        "Evaluated {} app-local task benchmark(s); {} matched expected or acceptable routes with average score {}/100.",
        results.len(),
        passing,
        average
    )
}

fn task_benchmark_blocker_notes(
    results: &[TaskBenchmarkEvaluationItem],
    catalog_available: bool,
) -> Vec<String> {
    let mut notes = Vec::new();
    if !catalog_available {
        notes.push(
            "No local catalog is available; run a local scan before relying on benchmark results."
                .to_string(),
        );
    }
    if results.is_empty() {
        notes.push("No app-local benchmarks were selected for evaluation.".to_string());
    }
    notes.extend(
        results
            .iter()
            .filter(|result| result.expected_match_status != "expected_match")
            .map(|result| {
                format!(
                    "Benchmark `{}` status is {}.",
                    result.title, result.expected_match_status
                )
            }),
    );
    notes.sort();
    notes.dedup();
    notes
}

fn task_benchmark_prompt_request(
    results: &[TaskBenchmarkEvaluationItem],
) -> TaskBenchmarkPromptRequest {
    let first = results.iter().find(|result| result.top_route.is_some());
    let (available, instance_ids, task, note) = match first {
        Some(result) => (
            true,
            result
                .top_route
                .as_ref()
                .map(|route| vec![route.instance_id.clone()])
                .unwrap_or_default(),
            Some(result.task.clone()),
            "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.evaluateBenchmarks never sends provider traffic.".to_string(),
        ),
        None => (
            false,
            Vec::new(),
            None,
            "Prompt preview is unavailable until local benchmark evaluation produces a route candidate.".to_string(),
        ),
    };
    TaskBenchmarkPromptRequest {
        available,
        preview_method: "llm.previewPrompt",
        confirm_method: "llm.confirmPromptAndSend",
        action: "routing_confidence",
        request: LlmPreviewPromptParams {
            action: LlmPromptActionKind::RoutingConfidence,
            profile_id: None,
            skill_instance_id: None,
            instance_ids,
            analysis_kind: None,
            user_intent: task,
        },
        note,
    }
}

fn routing_regression_baseline_from_evaluation(
    evaluation: TaskBenchmarkEvaluationResult,
) -> RoutingRegressionBaseline {
    RoutingRegressionBaseline {
        schema_version: 1,
        generated_by: "deterministic-service".to_string(),
        generated_at: unix_timestamp_millis(),
        catalog_available: evaluation.catalog_available,
        evaluated_count: evaluation.evaluated_count,
        benchmark_results: evaluation
            .benchmark_results
            .iter()
            .map(routing_regression_baseline_item)
            .collect(),
        safety_flags: task_benchmark_safety_flags(),
    }
}

fn routing_regression_baseline_item(
    item: &TaskBenchmarkEvaluationItem,
) -> RoutingRegressionBaselineItem {
    RoutingRegressionBaselineItem {
        benchmark_id: item.benchmark_id.clone(),
        title: item.title.clone(),
        task: item.task.clone(),
        score: item.score,
        band: item.band.to_string(),
        expected_match_status: item.expected_match_status.to_string(),
        top_route: item
            .top_route
            .as_ref()
            .map(routing_regression_route_snapshot),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.to_string(),
        gap_count: item.gap_notes.len(),
        blocker_count: item.blocker_notes.len(),
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

fn routing_regression_route_snapshot(
    route: &TaskBenchmarkRouteSummary,
) -> RoutingRegressionRouteSnapshot {
    RoutingRegressionRouteSnapshot {
        instance_id: route.instance_id.clone(),
        definition_id: route.definition_id.clone(),
        skill_name: route.skill_name.clone(),
        agent: route.agent.clone(),
        scope: route.scope.clone(),
        confidence_score: route.confidence_score,
        confidence_band: route.confidence_band.to_string(),
        readiness_score: route.readiness_score,
        readiness_band: route.readiness_band.to_string(),
    }
}

fn routing_regression_compare(
    baseline: &RoutingRegressionBaseline,
    current: &TaskBenchmarkEvaluationResult,
    score_drop_threshold: u8,
    confidence_drop_threshold: u8,
) -> Vec<RoutingRegressionItem> {
    let current_by_id = current
        .benchmark_results
        .iter()
        .map(|item| (item.benchmark_id.as_str(), item))
        .collect::<BTreeMap<_, _>>();
    let baseline_by_id = baseline
        .benchmark_results
        .iter()
        .map(|item| (item.benchmark_id.as_str(), item))
        .collect::<BTreeMap<_, _>>();

    let mut items = Vec::new();
    for baseline_item in &baseline.benchmark_results {
        let current_item = current_by_id
            .get(baseline_item.benchmark_id.as_str())
            .copied();
        items.push(routing_regression_compare_item(
            Some(baseline_item),
            current_item,
            score_drop_threshold,
            confidence_drop_threshold,
        ));
    }
    for current_item in &current.benchmark_results {
        if !baseline_by_id.contains_key(current_item.benchmark_id.as_str()) {
            items.push(routing_regression_compare_item(
                None,
                Some(current_item),
                score_drop_threshold,
                confidence_drop_threshold,
            ));
        }
    }
    items.sort_by(|left, right| {
        left.title
            .cmp(&right.title)
            .then_with(|| left.benchmark_id.cmp(&right.benchmark_id))
    });
    items
}

fn routing_regression_compare_item(
    baseline: Option<&RoutingRegressionBaselineItem>,
    current: Option<&TaskBenchmarkEvaluationItem>,
    score_drop_threshold: u8,
    confidence_drop_threshold: u8,
) -> RoutingRegressionItem {
    let benchmark_id = baseline
        .map(|item| item.benchmark_id.clone())
        .or_else(|| current.map(|item| item.benchmark_id.clone()))
        .unwrap_or_default();
    let title = baseline
        .map(|item| item.title.clone())
        .or_else(|| current.map(|item| item.title.clone()))
        .unwrap_or_else(|| benchmark_id.clone());
    let mut reasons = Vec::new();
    let mut evidence_refs = Vec::new();
    let mut regression = false;

    let status = match (baseline, current) {
        (Some(baseline), Some(current)) => {
            evidence_refs.extend(baseline.evidence_refs.clone());
            evidence_refs.extend(current.evidence_refs.clone());
            let score_drop = i16::from(baseline.score) - i16::from(current.score);
            if score_drop > i16::from(score_drop_threshold) {
                regression = true;
                reasons.push(format!(
                    "Benchmark score dropped by {} point(s), above the configured threshold of {}.",
                    score_drop, score_drop_threshold
                ));
            }
            let confidence_drop = i16::from(baseline.route_confidence_score)
                - i16::from(current.route_confidence_score);
            if confidence_drop > i16::from(confidence_drop_threshold) {
                regression = true;
                reasons.push(format!(
                    "Route confidence dropped by {} point(s), above the configured threshold of {}.",
                    confidence_drop, confidence_drop_threshold
                ));
            }
            if routing_match_rank(current.expected_match_status)
                < routing_match_rank(&baseline.expected_match_status)
            {
                regression = true;
                reasons.push(format!(
                    "Expected match status worsened from {} to {}.",
                    baseline.expected_match_status, current.expected_match_status
                ));
            }
            let current_route = current
                .top_route
                .as_ref()
                .map(routing_regression_route_snapshot);
            if baseline.top_route != current_route {
                regression = true;
                reasons.push(routing_route_change_reason(
                    baseline.top_route.as_ref(),
                    current_route.as_ref(),
                ));
            }
            if current.gap_notes.len() > baseline.gap_count {
                regression = true;
                reasons.push(format!(
                    "Gap note count increased from {} to {}.",
                    baseline.gap_count,
                    current.gap_notes.len()
                ));
            }
            if current.blocker_notes.len() > baseline.blocker_count {
                regression = true;
                reasons.push(format!(
                    "Blocker note count increased from {} to {}.",
                    baseline.blocker_count,
                    current.blocker_notes.len()
                ));
            }
            if regression {
                "regression"
            } else {
                reasons.push(
                    "Current routing result matches the saved baseline within configured thresholds."
                        .to_string(),
                );
                "unchanged"
            }
        }
        (Some(baseline), None) => {
            regression = true;
            evidence_refs.extend(baseline.evidence_refs.clone());
            reasons.push(
                "Benchmark existed in the saved baseline but was not present in the current evaluation."
                    .to_string(),
            );
            "missing_current_benchmark"
        }
        (None, Some(current)) => {
            evidence_refs.extend(current.evidence_refs.clone());
            reasons.push(
                "Benchmark is present in the current evaluation but has no saved baseline."
                    .to_string(),
            );
            "new_current_benchmark"
        }
        (None, None) => "unchanged",
    };
    evidence_refs.sort();
    evidence_refs.dedup();

    RoutingRegressionItem {
        benchmark_id,
        title,
        status,
        regression,
        reasons,
        evidence_refs,
        score_delta: match (baseline, current) {
            (Some(baseline), Some(current)) => {
                Some(i16::from(current.score) - i16::from(baseline.score))
            }
            _ => None,
        },
        confidence_delta: match (baseline, current) {
            (Some(baseline), Some(current)) => Some(
                i16::from(current.route_confidence_score)
                    - i16::from(baseline.route_confidence_score),
            ),
            _ => None,
        },
        baseline: baseline.map(routing_regression_baseline_fields),
        current: current.map(routing_regression_current_fields),
        safety_flags: task_benchmark_safety_flags(),
    }
}

fn routing_regression_baseline_fields(
    item: &RoutingRegressionBaselineItem,
) -> RoutingRegressionComparisonFields {
    RoutingRegressionComparisonFields {
        task: item.task.clone(),
        expected_match_status: item.expected_match_status.clone(),
        score: item.score,
        band: item.band.clone(),
        top_route: item.top_route.clone(),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.clone(),
        gap_count: item.gap_count,
        blocker_count: item.blocker_count,
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

fn routing_regression_current_fields(
    item: &TaskBenchmarkEvaluationItem,
) -> RoutingRegressionComparisonFields {
    RoutingRegressionComparisonFields {
        task: item.task.clone(),
        expected_match_status: item.expected_match_status.to_string(),
        score: item.score,
        band: item.band.to_string(),
        top_route: item
            .top_route
            .as_ref()
            .map(routing_regression_route_snapshot),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.to_string(),
        gap_count: item.gap_notes.len(),
        blocker_count: item.blocker_notes.len(),
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

fn routing_match_rank(status: &str) -> u8 {
    match status {
        "expected_match" => 4,
        "acceptable_match" => 3,
        "no_expectation" => 2,
        "mismatch" => 1,
        "blocked_no_route" => 0,
        _ => 0,
    }
}

fn routing_route_change_reason(
    baseline: Option<&RoutingRegressionRouteSnapshot>,
    current: Option<&RoutingRegressionRouteSnapshot>,
) -> String {
    match (baseline, current) {
        (Some(baseline), Some(current)) => format!(
            "Top route changed from `{}` ({}, {}) to `{}` ({}, {}).",
            baseline.skill_name,
            baseline.agent,
            baseline.scope,
            current.skill_name,
            current.agent,
            current.scope
        ),
        (Some(baseline), None) => format!(
            "Top route `{}` ({}, {}) is no longer available.",
            baseline.skill_name, baseline.agent, baseline.scope
        ),
        (None, Some(current)) => format!(
            "Top route `{}` ({}, {}) is newly available.",
            current.skill_name, current.agent, current.scope
        ),
        (None, None) => "Top route availability changed.".to_string(),
    }
}

fn routing_regression_status(
    regression_count: usize,
    missing_benchmark_count: usize,
    catalog_available: bool,
) -> &'static str {
    if !catalog_available {
        return "catalog_missing";
    }
    if regression_count > 0 {
        return "regressions_detected";
    }
    if missing_benchmark_count > 0 {
        return "missing_benchmarks";
    }
    "no_regressions"
}

fn routing_regression_summary(
    regression_count: usize,
    missing_benchmark_count: usize,
    compared_count: usize,
    catalog_available: bool,
) -> String {
    if !catalog_available {
        return format!(
            "Compared {} benchmark(s), but no local catalog is available; {} regression item(s) require attention.",
            compared_count, regression_count
        );
    }
    if regression_count == 0 {
        return format!(
            "Compared {} benchmark(s) against the saved app-local baseline; no routing regressions were detected.",
            compared_count
        );
    }
    format!(
        "Compared {} benchmark(s) against the saved app-local baseline; detected {} routing regression(s) and {} missing benchmark(s).",
        compared_count, regression_count, missing_benchmark_count
    )
}

fn skill_route_ranking_from_readiness(readiness: TaskReadinessResult) -> SkillRouteRankingResult {
    let top_score = readiness
        .candidate_skills
        .first()
        .map(|candidate| candidate.score)
        .unwrap_or(0);
    let mut route_candidates = Vec::new();
    for (index, candidate) in readiness.candidate_skills.iter().enumerate() {
        let next_score = readiness
            .candidate_skills
            .get(index + 1)
            .map(|candidate| candidate.score);
        let confidence_score = route_confidence_score(candidate, index, top_score, next_score);
        let confidence_band = routing_confidence_band(confidence_score);
        let confidence_rationale =
            route_confidence_rationale(candidate, index, confidence_score, next_score);
        let ambiguity_warnings =
            route_candidate_ambiguity_warnings(candidate, index, top_score, next_score);
        let likely_wrong_pick_risks =
            route_candidate_wrong_pick_risks(candidate, index, next_score, &ambiguity_warnings);
        let likely_miss_risks = route_candidate_miss_risks(candidate);
        route_candidates.push(SkillRouteCandidate {
            rank: index + 1,
            instance_id: candidate.instance_id.clone(),
            definition_id: candidate.definition_id.clone(),
            skill_name: candidate.skill_name.clone(),
            agent: candidate.agent.clone(),
            scope: candidate.scope.clone(),
            enabled: candidate.enabled,
            state: candidate.state.clone(),
            confidence_score,
            confidence_band,
            readiness_score: candidate.score,
            readiness_band: candidate.band,
            quality_score: candidate.quality_score,
            match_reasons: candidate.match_reasons.clone(),
            confidence_rationale,
            ambiguity_warnings,
            likely_wrong_pick_risks,
            likely_miss_risks,
            enabled_scope_risk_state: candidate.enabled_scope_risk_state.clone(),
            evidence_refs: candidate.evidence_refs.clone(),
        });
    }

    let ambiguity_warnings = routing_ambiguity_warnings(&route_candidates);
    let likely_wrong_pick_risks = routing_wrong_pick_risks(&route_candidates);
    let likely_miss_risks = routing_miss_risks(&route_candidates, &readiness);
    let overall_confidence_score = routing_overall_confidence_score(&route_candidates);
    let overall_confidence_band = routing_confidence_band(overall_confidence_score);
    let prompt_instance_ids = route_candidates
        .iter()
        .take(8)
        .map(|candidate| candidate.instance_id.clone())
        .collect::<Vec<_>>();
    let prompt_available = readiness.catalog_available && !route_candidates.is_empty();

    SkillRouteRankingResult {
        task: readiness.task.clone(),
        overall_confidence_score,
        overall_confidence_band,
        summary: routing_confidence_summary(
            overall_confidence_score,
            overall_confidence_band,
            &route_candidates,
            &ambiguity_warnings,
            &likely_miss_risks,
        ),
        generated_by: "deterministic-service",
        catalog_available: readiness.catalog_available,
        filters: readiness.filters,
        route_candidates,
        ambiguity_warnings,
        likely_wrong_pick_risks,
        likely_miss_risks,
        evidence_references: readiness.evidence_references,
        prompt_request: RoutingConfidencePromptRequest {
            available: prompt_available,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "routing_confidence",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RoutingConfidence,
                profile_id: None,
                skill_instance_id: None,
                instance_ids: prompt_instance_ids,
                analysis_kind: None,
                user_intent: Some(readiness.task),
            },
            note: if prompt_available {
                "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.rankSkillRoutes never sends provider traffic."
                    .to_string()
            } else {
                "Prompt preview is unavailable until local catalog evidence produces route candidates."
                    .to_string()
            },
        },
        safety_flags: routing_confidence_safety_flags(),
    }
}

fn route_confidence_score(
    candidate: &TaskReadinessCandidate,
    index: usize,
    top_score: u8,
    next_score: Option<u8>,
) -> u8 {
    let quality_component = candidate.quality_score.unwrap_or(50) as i16 / 10;
    let mut score = candidate.score as i16 + quality_component - 5;
    if index == 0 {
        let margin = candidate.score.saturating_sub(next_score.unwrap_or(0));
        score += match margin {
            20..=u8::MAX => 8,
            10..=19 => 4,
            6..=9 => 0,
            1..=5 => -8,
            0 => -12,
        };
    } else {
        let gap = top_score.saturating_sub(candidate.score);
        score -= (index as i16 * 5).min(20);
        if gap <= 5 {
            score += 4;
        }
    }
    score -= match candidate.enabled_scope_risk_state.risk_level {
        "blocked" => 18,
        "high" => 12,
        "medium" => 6,
        _ => 0,
    };
    if !candidate.enabled {
        score -= 12;
    }
    if candidate.state != "loaded" {
        score -= 12;
    }
    score.clamp(0, 100) as u8
}

fn routing_confidence_band(score: u8) -> &'static str {
    match score {
        80..=100 => "high",
        60..=79 => "medium",
        35..=59 => "low",
        1..=34 => "weak",
        _ => "blocked",
    }
}

fn route_confidence_rationale(
    candidate: &TaskReadinessCandidate,
    index: usize,
    confidence_score: u8,
    next_score: Option<u8>,
) -> Vec<String> {
    let mut rationale = vec![format!(
        "Rank {} combines readiness score {} ({}) with local quality score {} and risk level {}.",
        index + 1,
        candidate.score,
        candidate.band,
        candidate
            .quality_score
            .map(|score| score.to_string())
            .unwrap_or_else(|| "n/a".to_string()),
        candidate.enabled_scope_risk_state.risk_level
    )];
    if index == 0 {
        match next_score {
            Some(next) => rationale.push(format!(
                "Top route leads the next visible candidate by {} readiness point(s).",
                candidate.score.saturating_sub(next)
            )),
            None => rationale.push("Only one visible route candidate was ranked.".to_string()),
        }
    }
    if confidence_score < candidate.score {
        rationale.push(
            "Confidence is below readiness because ambiguity, risk, or enablement state reduces selection certainty."
                .to_string(),
        );
    }
    rationale
}

fn route_candidate_ambiguity_warnings(
    candidate: &TaskReadinessCandidate,
    index: usize,
    top_score: u8,
    next_score: Option<u8>,
) -> Vec<String> {
    let mut warnings = Vec::new();
    if index == 0 {
        if let Some(next) = next_score {
            let margin = candidate.score.saturating_sub(next);
            if margin <= 8 {
                warnings.push(format!(
                    "Top route is separated from the next candidate by only {margin} readiness point(s)."
                ));
            }
        }
    } else if top_score.saturating_sub(candidate.score) <= 8 {
        warnings.push(
            "This candidate is close enough to the top route to create deterministic routing ambiguity."
                .to_string(),
        );
    }
    if candidate
        .blocker_risk_notes
        .iter()
        .any(|note| note.contains("conflict") || note.contains("duplicate_name"))
    {
        warnings.push(
            "Conflict or duplicate-name evidence may make runtime route selection ambiguous."
                .to_string(),
        );
    }
    warnings
}

fn route_candidate_wrong_pick_risks(
    candidate: &TaskReadinessCandidate,
    index: usize,
    next_score: Option<u8>,
    ambiguity_warnings: &[String],
) -> Vec<String> {
    let mut risks = Vec::new();
    if index == 0 && !ambiguity_warnings.is_empty() {
        risks.push("The top local route has close or overlapping alternatives.".to_string());
    }
    if index == 0 && next_score.is_some_and(|score| candidate.score.saturating_sub(score) <= 5) {
        risks.push(
            "A small score margin means wording changes could pick a different skill.".to_string(),
        );
    }
    if candidate.enabled_scope_risk_state.risk_level == "high" {
        risks.push(
            "High local risk evidence could make this route a poor default pick.".to_string(),
        );
    }
    if candidate
        .match_reasons
        .iter()
        .any(|reason| reason.contains("No direct lexical overlap"))
    {
        risks.push("Task fit is weak, so selecting this skill may be a wrong pick.".to_string());
    }
    risks
}

fn route_candidate_miss_risks(candidate: &TaskReadinessCandidate) -> Vec<String> {
    let mut risks = candidate.missing_gap_notes.clone();
    if !candidate.enabled {
        risks.push("Disabled state means this skill may be missed by runtime routing.".to_string());
    }
    if candidate.state != "loaded" {
        risks.push(format!(
            "State `{}` means this skill may be unavailable when routing.",
            redact_for_llm_preview(&candidate.state)
        ));
    }
    risks
}

fn routing_overall_confidence_score(candidates: &[SkillRouteCandidate]) -> u8 {
    let Some(best) = candidates.first() else {
        return 0;
    };
    let second = candidates
        .get(1)
        .map(|candidate| candidate.confidence_score)
        .unwrap_or(0);
    let margin_bonus = best.confidence_score.saturating_sub(second).min(15) / 3;
    ((u16::from(best.confidence_score) * 4 + u16::from(second)) / 5)
        .saturating_add(u16::from(margin_bonus))
        .min(100) as u8
}

fn routing_ambiguity_warnings(candidates: &[SkillRouteCandidate]) -> Vec<String> {
    let mut warnings = candidates
        .iter()
        .flat_map(|candidate| candidate.ambiguity_warnings.iter().cloned())
        .collect::<Vec<_>>();
    if let (Some(first), Some(second)) = (candidates.first(), candidates.get(1)) {
        let margin = first
            .confidence_score
            .saturating_sub(second.confidence_score);
        if margin <= 8 {
            warnings.push(format!(
                "Top two route candidates are within {margin} confidence point(s)."
            ));
        }
    }
    warnings.sort();
    warnings.dedup();
    warnings.truncate(10);
    warnings
}

fn routing_wrong_pick_risks(candidates: &[SkillRouteCandidate]) -> Vec<String> {
    let mut risks = candidates
        .iter()
        .flat_map(|candidate| candidate.likely_wrong_pick_risks.iter().cloned())
        .collect::<Vec<_>>();
    if risks.is_empty() && !candidates.is_empty() {
        risks.push(
            "No likely wrong-pick risk was detected beyond normal lexical matching uncertainty."
                .to_string(),
        );
    }
    risks.sort();
    risks.dedup();
    risks.truncate(10);
    risks
}

fn routing_miss_risks(
    candidates: &[SkillRouteCandidate],
    readiness: &TaskReadinessResult,
) -> Vec<String> {
    let mut risks = candidates
        .iter()
        .flat_map(|candidate| candidate.likely_miss_risks.iter().cloned())
        .collect::<Vec<_>>();
    risks.extend(readiness.missing_gap_notes.iter().cloned());
    if candidates.is_empty() {
        risks.push("No route candidates were available from local catalog evidence.".to_string());
    } else if candidates
        .iter()
        .all(|candidate| candidate.confidence_score < 60)
    {
        risks.push(
            "All visible route candidates have low confidence, so the task may miss the intended skill."
                .to_string(),
        );
    }
    risks.sort();
    risks.dedup();
    risks.truncate(10);
    risks
}

fn routing_confidence_summary(
    score: u8,
    band: &'static str,
    candidates: &[SkillRouteCandidate],
    ambiguity_warnings: &[String],
    miss_risks: &[String],
) -> String {
    match candidates.first() {
        Some(best) => format!(
            "Routing confidence is {band} ({score}/100). Top route is #{} `{}` for {} with confidence {} and {} ambiguity warning(s).",
            best.rank,
            best.skill_name,
            best.agent,
            best.confidence_score,
            ambiguity_warnings.len()
        ),
        None if miss_risks.is_empty() => {
            "Routing confidence is blocked because no local route candidates were available."
                .to_string()
        }
        None => format!(
            "Routing confidence is blocked because no local route candidates were available. {}",
            miss_risks.join(" ")
        ),
    }
}

fn push_task_readiness_evidence(
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
    source_type: &'static str,
    source_id: &str,
    label: String,
    severity: Option<String>,
    related_instance_id: Option<String>,
) -> String {
    let id = format!("{source_type}:{source_id}");
    evidence.push(TaskReadinessEvidenceReference {
        id: id.clone(),
        source_type,
        source_id: redact_for_llm_preview(source_id),
        label,
        severity,
        related_instance_id,
    });
    id
}

fn quality_metadata_component(
    skill: &SkillDetailRecord,
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let mut score = 25i16;
    let mut missing = Vec::new();
    let mut suggestions = Vec::new();
    if skill.name.trim().is_empty() {
        score -= 8;
        missing.push("name");
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Add a clear skill name".to_string(),
            detail:
                "Provide a stable, canonical name so agents and reviewers can identify the skill."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.description.trim().is_empty() {
        score -= 8;
        missing.push("description");
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Add a concise description".to_string(),
            detail:
                "Describe the task fit, expected inputs, and safe usage boundaries in metadata."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.frontmatter_raw.trim().is_empty() {
        score -= 5;
        missing.push("frontmatter");
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Restore frontmatter metadata".to_string(),
            detail: "Use structured frontmatter so deterministic rules can evaluate the skill."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.body.trim().chars().count() < 40 {
        score -= 4;
        missing.push("body detail");
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Expand the skill guidance".to_string(),
            detail: "Add enough task-specific instructions for an agent to understand when and how to use the skill."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if missing.is_empty() {
        "Metadata has the expected local name, description, frontmatter, and body guidance."
            .to_string()
    } else {
        format!("Metadata needs attention for: {}.", missing.join(", "))
    };
    (score.clamp(0, 25) as u8, summary, suggestions)
}

fn quality_permission_component(
    skill: &SkillDetailRecord,
) -> (u8, String, Vec<String>, Vec<SkillQualitySuggestion>) {
    let mut score = 20i16;
    let mut risks = Vec::new();
    let mut suggestions = Vec::new();
    let permissions = &skill.permissions;
    let normalized = permissions.get("normalized").unwrap_or(permissions);
    if permissions
        .as_object()
        .is_none_or(|object| object.is_empty())
    {
        score -= 8;
        risks.push("Permission metadata is empty or unavailable.".to_string());
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Declare permission intent".to_string(),
            detail: "Add explicit tools/files/network/exec expectations so risk checks do not rely on unknown-safe defaults."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let tools = normalized
        .get("tools")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or(0);
    if tools == 0 {
        score -= 4;
        risks.push("No explicit tool allow-list was found in normalized permissions.".to_string());
    }
    if normalized
        .get("network")
        .and_then(Value::as_str)
        .is_none_or(|network| network == "unknown")
    {
        score -= 3;
        risks.push("Network access intent is unknown.".to_string());
    }
    let exec = normalized
        .get("exec")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let requires_human = normalized
        .get("requires_human")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if exec && !requires_human {
        score -= 8;
        risks.push(
            "Execution permission is declared without a human-review requirement.".to_string(),
        );
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Require human review for execution".to_string(),
            detail: "Execution-like skills should declare an explicit human confirmation boundary."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if risks.is_empty() {
        "Permission metadata is explicit enough for local risk checks.".to_string()
    } else {
        format!("Permission clarity deductions: {}", risks.join(" "))
    };
    (score.clamp(0, 20) as u8, summary, risks, suggestions)
}

fn quality_risk_component(
    skill: &SkillDetailRecord,
    findings: &[RuleFindingRecord],
) -> (u8, String, Vec<String>, Vec<SkillQualitySuggestion>) {
    let mut deduction = 0i16;
    let mut risks = Vec::new();
    for finding in findings {
        let points = match finding.effective_severity.as_str() {
            "critical" => 15,
            "error" => 10,
            "warning" | "warn" => 6,
            "info" => 2,
            _ => 1,
        };
        deduction += points;
        risks.push(format!(
            "{} finding `{}` affects this score.",
            redact_for_llm_preview(&finding.effective_severity),
            redact_for_llm_preview(&finding.rule_id)
        ));
    }
    let combined = format!("{}\n{}", skill.frontmatter_raw, skill.body).to_lowercase();
    let mut suggestions = Vec::new();
    if combined.contains("#!") || combined.contains("exec") || combined.contains("command") {
        deduction += 5;
        risks.push(
            "Skill text contains execution-related terms; this service still exposes no execution path."
                .to_string(),
        );
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Clarify execution boundaries".to_string(),
            detail:
                "Document whether command-like instructions are examples, manual steps, or blocked automation."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if combined.contains("http") || combined.contains("api") || combined.contains("network") {
        deduction += 4;
        risks.push("Skill text contains network/API-related terms.".to_string());
    }
    if combined.contains("key") || combined.contains("token") || combined.contains("secret") {
        deduction += 4;
        risks.push(
            "Skill text contains secret-like terms; responses redact such tokens.".to_string(),
        );
    }
    let score = (25i16 - deduction.min(25)).clamp(0, 25) as u8;
    let summary = if findings.is_empty() && risks.is_empty() {
        "No related findings or high-risk body signals were detected locally.".to_string()
    } else {
        format!(
            "{} related finding(s) and local text signals reduced the risk component.",
            findings.len()
        )
    };
    (score, summary, risks, suggestions)
}

fn quality_conflict_component(
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let conflict_deduction = (conflicts.len() as i16 * 12).min(15);
    let analysis_deduction = (analysis_groups.len() as i16 * 5).min(10);
    let score = (15i16 - (conflict_deduction + analysis_deduction).min(15)).clamp(0, 15) as u8;
    let mut suggestions = Vec::new();
    if !conflicts.is_empty() {
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Review same-agent conflicts".to_string(),
            detail: "Resolve current-agent name/runtime collisions through the existing conflict review flow."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if !analysis_groups.is_empty() {
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Compare cross-agent overlap".to_string(),
            detail: "Use read-only comparison to decide whether similar skills improve coverage or create routing ambiguity."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if conflicts.is_empty() && analysis_groups.is_empty() {
        "No same-agent conflict or cross-agent overlap currently involves this skill.".to_string()
    } else {
        format!(
            "{} same-agent conflict(s) and {} cross-agent analysis group(s) involve this skill.",
            conflicts.len(),
            analysis_groups.len()
        )
    };
    (score, summary, suggestions)
}

fn quality_adapter_component(
    skill: &SkillDetailRecord,
    diagnostic: Option<&AdapterDiagnosticsRecord>,
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let mut score = 15i16;
    let mut notes = Vec::new();
    let mut suggestions = Vec::new();
    if !skill.enabled {
        score -= 8;
        notes.push("Skill is disabled in the catalog state.".to_string());
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Review enablement state".to_string(),
            detail:
                "If this skill is expected to route tasks, review enablement through the existing safe toggle flow."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.state != "loaded" {
        score -= 10;
        notes.push(format!(
            "Skill state is `{}` instead of loaded.",
            redact_for_llm_preview(&skill.state)
        ));
    }
    match diagnostic {
        Some(diagnostic) => {
            if diagnostic.status != "available" {
                score -= 3;
                notes.push(format!(
                    "Adapter diagnostic status is `{}`.",
                    diagnostic.status
                ));
            }
            if diagnostic.roots.iter().all(|root| !root.exists) {
                score -= 3;
                notes.push(
                    "Adapter diagnostics found no existing scanned root for this agent."
                        .to_string(),
                );
            }
        }
        None => {
            score -= 3;
            notes.push("No adapter diagnostics entry matched this skill agent.".to_string());
        }
    }
    let summary = if notes.is_empty() {
        "Adapter diagnostics and catalog state support read-only analysis for this skill."
            .to_string()
    } else {
        notes.join(" ")
    };
    (score.clamp(0, 15) as u8, summary, suggestions)
}

fn quality_grade_and_band(score: u8) -> (&'static str, &'static str) {
    match score {
        90..=100 => ("A", "excellent"),
        75..=89 => ("B", "good"),
        60..=74 => ("C", "fair"),
        40..=59 => ("D", "poor"),
        _ => ("F", "blocked"),
    }
}

fn quality_priority_for_severity(severity: &str) -> &'static str {
    match severity {
        "critical" | "error" => "high",
        "warning" | "warn" => "medium",
        _ => "low",
    }
}

fn push_quality_evidence(
    evidence: &mut Vec<SkillQualityEvidenceReference>,
    source_type: &'static str,
    source_id: &str,
    label: String,
    severity: Option<String>,
    related_instance_id: Option<String>,
) -> String {
    let id = format!("{source_type}:{source_id}");
    evidence.push(SkillQualityEvidenceReference {
        id: id.clone(),
        source_type,
        source_id: redact_for_llm_preview(source_id),
        label,
        severity,
        related_instance_id,
    });
    id
}

fn quality_refs_or_skill(refs: &[String], skill_ref: &str) -> Vec<String> {
    if refs.is_empty() {
        vec![skill_ref.to_string()]
    } else {
        refs.to_vec()
    }
}

fn dedupe_quality_suggestions(suggestions: &mut Vec<SkillQualitySuggestion>) {
    let mut seen = BTreeMap::new();
    suggestions.retain(|suggestion| {
        let key = format!("{}\x1f{}", suggestion.title, suggestion.detail);
        if let std::collections::btree_map::Entry::Vacant(entry) = seen.entry(key) {
            entry.insert(());
            true
        } else {
            false
        }
    });
}

fn render_quality_score_prompt_section(
    score: &SkillQualityScoreResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let components = score
        .components
        .iter()
        .map(|component| {
            format!(
                "- {}: {}/{}; {}",
                component.id,
                component.score,
                component.max_score,
                redactor.redact(&component.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = score
        .evidence_references
        .iter()
        .take(12)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let suggestions = score
        .suggested_improvements
        .iter()
        .take(8)
        .map(|suggestion| {
            format!(
                "- {}: {} - {}",
                suggestion.priority,
                redactor.redact(&suggestion.title),
                redactor.redact(&suggestion.detail)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Quality score evidence:\n- skill id: {}\n- name: {}\n- agent: {}\n- scope: {}\n- score: {} / 100\n- grade: {}\n- band: {}\n\nComponents:\n{}\n\nEvidence references:\n{}\n\nSuggested improvements:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&score.instance_id),
        redactor.redact(&score.skill_name),
        redactor.redact(&score.agent),
        redactor.redact(&score.scope),
        score.score,
        score.grade,
        score.band,
        if components.is_empty() { "none" } else { &components },
        if evidence.is_empty() { "none" } else { &evidence },
        if suggestions.is_empty() { "none" } else { &suggestions },
    )
}

fn render_stale_drift_prompt_section(
    detection: &StaleDriftDetectionResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let rows = detection
        .stale_drift_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): score={} band={} fingerprint_drift={} finding_drift={} source_drift={} age_days={}; reasons={}",
                row.rank,
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                redactor.redact(&row.scope),
                row.enabled,
                redactor.redact(&row.state),
                row.stale_drift_score,
                row.stale_drift_band,
                row.drift_signals.fingerprint_drift,
                row.drift_signals.finding_drift,
                row.drift_signals.source_drift,
                row.drift_signals
                    .modified_age_days
                    .map(|days| days.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                row.reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let impacts = detection
        .readiness_impact_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} impact={} score={}: {}",
                redactor.redact(&row.skill_name),
                row.impact_level,
                row.stale_drift_score,
                row.notes
                    .iter()
                    .take(2)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = detection
        .evidence_references
        .iter()
        .take(12)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Stale/drift detection evidence:\n- catalog_available: {}\n- scanned_skill_count: {}\n- returned_row_count: {}\n- stale_count: {}\n- drift_count: {}\n- high_risk_count: {}\n- stale_days_threshold: {}\n- summary: {}\n\nRows:\n{}\n\nReadiness impact:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        detection.catalog_available,
        detection.summary.scanned_skill_count,
        detection.summary.returned_row_count,
        detection.summary.stale_count,
        detection.summary.drift_count,
        detection.summary.high_risk_count,
        detection.filters.stale_days,
        redactor.redact(&detection.summary.summary),
        if rows.is_empty() { "none" } else { &rows },
        if impacts.is_empty() { "none" } else { &impacts },
        if detection.gap_notes.is_empty() {
            "none".to_string()
        } else {
            detection
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if detection.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            detection
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

fn render_knowledge_search_prompt_section(
    result: &KnowledgeSearchResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let rows = result
        .rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): matched_fields={}; quality={}; readiness={}; stale_drift={}; reasons={}",
                row.rank,
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                redactor.redact(&row.scope),
                row.enabled,
                redactor.redact(&row.state),
                row.matched_fields.join(", "),
                row.quality_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100)", context.band, context.score))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.readiness_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100, risk={})", context.band, context.score, context.risk_level))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.stale_drift_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100)", context.band, context.score))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.match_reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Knowledge search evidence:\n- catalog_available: {}\n- query: {}\n- normalized_terms: {}\n- indexed_skill_count: {}\n- matched_row_count: {}\n- returned_row_count: {}\n- enabled_count: {}\n- high_risk_count: {}\n- stale_or_drift_count: {}\n- summary: {}\n\nRows:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .query
            .as_deref()
            .map(|query| redactor.redact(query))
            .unwrap_or_else(|| "none".to_string()),
        if result.filters.normalized_terms.is_empty() {
            "none".to_string()
        } else {
            result.filters.normalized_terms.join(", ")
        },
        result.summary.indexed_skill_count,
        result.summary.matched_row_count,
        result.summary.returned_row_count,
        result.summary.enabled_count,
        result.summary.high_risk_count,
        result.summary.stale_or_drift_count,
        redactor.redact(&result.summary.summary),
        if rows.is_empty() { "none" } else { &rows },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

fn render_similar_skill_grouping_prompt_section(
    result: &SimilarSkillGroupingResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let groups = result
        .groups
        .iter()
        .take(8)
        .map(|group| {
            let members = group
                .members
                .iter()
                .take(6)
                .map(|member| {
                    format!(
                        "{} ({}, {}, enabled={}, state={}, quality={}, stale_drift={})",
                        redactor.redact(&member.skill_name),
                        redactor.redact(&member.agent),
                        redactor.redact(&member.scope),
                        member.enabled,
                        redactor.redact(&member.state),
                        member
                            .quality_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                        member
                            .stale_drift_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                    )
                })
                .collect::<Vec<_>>()
                .join("; ");
            format!(
                "- #{} {} type={} score={} ambiguity_risk={} coverage_redundancy={} routing_ambiguity={}; shared_terms={}; shared_tools={}; shared_rules={}; shared_risk={}; why={}; members={}",
                group.rank,
                redactor.redact(&group.title),
                group.group_type,
                group.similarity_score,
                group.ambiguity_risk,
                group.coverage_redundancy,
                group.routing_ambiguity,
                group.shared_terms.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_tools.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_rules.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_risk_tags.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group
                    .why_grouped
                    .iter()
                    .take(4)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" "),
                members
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Similar skill grouping evidence:\n- catalog_available: {}\n- agent: {}\n- min_score: {}\n- indexed_skill_count: {}\n- candidate_skill_count: {}\n- matched_group_count: {}\n- returned_group_count: {}\n- duplicate_group_count: {}\n- coverage_redundancy_group_count: {}\n- routing_ambiguity_count: {}\n- summary: {}\n\nGroups:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "all".to_string()),
        result.filters.min_score,
        result.summary.indexed_skill_count,
        result.summary.candidate_skill_count,
        result.summary.matched_group_count,
        result.summary.returned_group_count,
        result.summary.duplicate_group_count,
        result.summary.coverage_redundancy_group_count,
        result.summary.routing_ambiguity_count,
        redactor.redact(&result.summary.summary),
        if groups.is_empty() { "none" } else { &groups },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

fn render_task_readiness_prompt_section(
    readiness: &TaskReadinessResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let candidates = readiness
        .candidate_skills
        .iter()
        .take(8)
        .map(|candidate| {
            format!(
                "- {} ({}, {}, enabled={}, state={}): score={} band={} risk={} quality={}; reasons={}",
                redactor.redact(&candidate.skill_name),
                redactor.redact(&candidate.agent),
                redactor.redact(&candidate.scope),
                candidate.enabled,
                redactor.redact(&candidate.state),
                candidate.score,
                candidate.band,
                candidate.enabled_scope_risk_state.risk_level,
                candidate
                    .quality_score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                candidate
                    .match_reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let gaps = readiness
        .missing_gap_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let blockers = readiness
        .blocker_risk_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = readiness
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Task readiness evidence:\n- task: {}\n- score: {} / 100\n- band: {}\n- summary: {}\n- catalog_available: {}\n\nCandidate skills:\n{}\n\nMissing/gap notes:\n{}\n\nBlocker/risk notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&readiness.task),
        readiness.score,
        readiness.band,
        redactor.redact(&readiness.summary),
        readiness.catalog_available,
        if candidates.is_empty() { "none" } else { &candidates },
        if gaps.is_empty() { "none" } else { &gaps },
        if blockers.is_empty() { "none" } else { &blockers },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

fn render_routing_confidence_prompt_section(
    ranking: &SkillRouteRankingResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let candidates = ranking
        .route_candidates
        .iter()
        .take(8)
        .map(|candidate| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): confidence={} band={} readiness={} quality={} risk={}; rationale={}; ambiguity={}",
                candidate.rank,
                redactor.redact(&candidate.skill_name),
                redactor.redact(&candidate.agent),
                redactor.redact(&candidate.scope),
                candidate.enabled,
                redactor.redact(&candidate.state),
                candidate.confidence_score,
                candidate.confidence_band,
                candidate.readiness_score,
                candidate
                    .quality_score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                candidate.enabled_scope_risk_state.risk_level,
                candidate
                    .confidence_rationale
                    .iter()
                    .take(3)
                    .map(|rationale| redactor.redact(rationale))
                    .collect::<Vec<_>>()
                    .join(" "),
                candidate
                    .ambiguity_warnings
                    .iter()
                    .take(2)
                    .map(|warning| redactor.redact(warning))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let ambiguity = ranking
        .ambiguity_warnings
        .iter()
        .take(8)
        .map(|warning| format!("- {}", redactor.redact(warning)))
        .collect::<Vec<_>>()
        .join("\n");
    let wrong_pick = ranking
        .likely_wrong_pick_risks
        .iter()
        .take(8)
        .map(|risk| format!("- {}", redactor.redact(risk)))
        .collect::<Vec<_>>()
        .join("\n");
    let miss = ranking
        .likely_miss_risks
        .iter()
        .take(8)
        .map(|risk| format!("- {}", redactor.redact(risk)))
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = ranking
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Routing confidence evidence:\n- task: {}\n- overall_confidence_score: {} / 100\n- overall_confidence_band: {}\n- summary: {}\n- catalog_available: {}\n\nRoute candidates:\n{}\n\nAmbiguity warnings:\n{}\n\nLikely wrong-pick risks:\n{}\n\nLikely miss risks:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&ranking.task),
        ranking.overall_confidence_score,
        ranking.overall_confidence_band,
        redactor.redact(&ranking.summary),
        ranking.catalog_available,
        if candidates.is_empty() { "none" } else { &candidates },
        if ambiguity.is_empty() { "none" } else { &ambiguity },
        if wrong_pick.is_empty() { "none" } else { &wrong_pick },
        if miss.is_empty() { "none" } else { &miss },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

fn llm_skill_analysis_safety_flags() -> LlmSkillAnalysisSafetyFlags {
    LlmSkillAnalysisSafetyFlags {
        write_back_enabled: false,
        script_execution_enabled: false,
        credential_storage_enabled: false,
        confirmation_required: true,
    }
}

fn skill_analysis_prompt_draft(
    analysis_kind: LlmSkillAnalysisKind,
    selected_skill_count: usize,
    included_skills: &[LlmSkillAnalysisIncludedSkill],
    excluded_missing_count: usize,
) -> String {
    let included = skill_analysis_included_summary(included_skills);
    format!(
        "Prepare a read-only {kind} analysis for {selected_skill_count} selected skill instance(s). Included skills: {included}. Missing or excluded selections: {excluded_missing_count}. Do not write files, change agent config, execute scripts, store credentials, create snapshots, or call tools.",
        kind = analysis_kind.as_str()
    )
}

fn skill_analysis_summary_draft(
    analysis_kind: LlmSkillAnalysisKind,
    selected_skill_count: usize,
    included_skills: &[LlmSkillAnalysisIncludedSkill],
    excluded_missing_count: usize,
) -> String {
    let disabled_count = included_skills
        .iter()
        .filter(|skill| !skill.enabled)
        .count();
    format!(
        "Local preview only: {kind} analysis queued for {selected_skill_count} selected skill instance(s), with {} included, {excluded_missing_count} missing or excluded, and {disabled_count} currently disabled. Provider calls, write-back, script execution, credential storage, and snapshots are disabled.",
        included_skills.len(),
        kind = analysis_kind.as_str()
    )
}

fn skill_analysis_included_summary(included_skills: &[LlmSkillAnalysisIncludedSkill]) -> String {
    if included_skills.is_empty() {
        return "none".to_string();
    }
    included_skills
        .iter()
        .map(|skill| {
            format!(
                "{} ({}, {}, enabled={})",
                redact_for_llm_preview(&skill.name),
                redact_for_llm_preview(&skill.agent),
                redact_for_llm_preview(&skill.scope),
                skill.enabled
            )
        })
        .collect::<Vec<_>>()
        .join("; ")
}

fn redact_for_llm_preview(value: &str) -> String {
    let mut redacted = value
        .split_whitespace()
        .map(|token| {
            let lower = token.to_lowercase();
            if lower.contains("key")
                || lower.contains("token")
                || lower.contains("secret")
                || lower.contains("credential")
                || lower.contains("password")
            {
                "<redacted>"
            } else {
                token
            }
        })
        .collect::<Vec<_>>()
        .join(" ");
    const MAX_PREVIEW_CHARS: usize = 220;
    if redacted.chars().count() > MAX_PREVIEW_CHARS {
        redacted = redacted.chars().take(MAX_PREVIEW_CHARS).collect::<String>();
        redacted.push_str("...");
    }
    redacted
}

fn supported_methods() -> Vec<&'static str> {
    SUPPORTED_METHODS.to_vec()
}

fn generated_benchmark_id(title: &str, task: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(task.as_bytes());
    let digest = hasher.finalize();
    format!("bench-{}", hex_prefix(&digest, 12))
}

fn sanitize_benchmark_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

fn normalize_string_list(values: Vec<String>) -> Vec<String> {
    let mut normalized = values
        .into_iter()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    normalized.sort();
    normalized.dedup();
    normalized
}

fn hex_prefix(bytes: &[u8], chars: usize) -> String {
    bytes
        .iter()
        .flat_map(|byte| {
            let high = b"0123456789abcdef"[(byte >> 4) as usize] as char;
            let low = b"0123456789abcdef"[(byte & 0x0f) as usize] as char;
            [high, low]
        })
        .take(chars)
        .collect()
}

fn sanitize_harness_label(label: &str) -> String {
    label
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(80)
        .collect()
}

fn cleanup_queue_response(mut items: Vec<CleanupQueueItem>, limit: Option<usize>) -> CleanupQueue {
    items.sort_by(|left, right| {
        cleanup_kind_rank(&left.kind)
            .cmp(&cleanup_kind_rank(&right.kind))
            .then_with(|| {
                severity_rank_for_queue(&left.severity)
                    .cmp(&severity_rank_for_queue(&right.severity))
            })
            .then_with(|| left.agent.cmp(&right.agent))
            .then_with(|| left.skill_name.cmp(&right.skill_name))
            .then_with(|| left.skill_id.cmp(&right.skill_id))
            .then_with(|| left.id.cmp(&right.id))
    });
    if let Some(limit) = limit {
        items.truncate(limit);
    }

    let mut counts_by_kind = BTreeMap::new();
    let mut counts_by_priority = BTreeMap::new();
    for item in &items {
        *counts_by_kind.entry(item.kind.clone()).or_insert(0) += 1;
        *counts_by_priority.entry(item.priority.clone()).or_insert(0) += 1;
    }

    CleanupQueue {
        summary: CleanupQueueSummary {
            total_count: items.len(),
            counts_by_kind,
            counts_by_priority,
            read_only: true,
            writes_allowed: false,
            provider_request_sent: false,
        },
        items,
    }
}

fn agent_matches(filter: Option<&str>, agent: Option<&str>) -> bool {
    match filter {
        Some(filter) => agent == Some(filter),
        None => true,
    }
}

fn cleanup_kind_rank(kind: &str) -> u8 {
    match kind {
        "integrity" => 0,
        "conflict" => 1,
        "finding" => 2,
        "analysis" => 3,
        _ => 4,
    }
}

fn severity_rank_for_queue(severity: &str) -> u8 {
    match severity {
        "critical" => 0,
        "error" => 1,
        "warn" | "warning" => 2,
        "info" => 3,
        _ => 4,
    }
}

fn priority_for(severity: &str) -> &'static str {
    match severity {
        "critical" => "critical",
        "error" => "high",
        "warn" | "warning" => "medium",
        "info" => "low",
        _ => "low",
    }
}

fn parse_agent_param(agent: &str) -> Result<AgentId, ServiceError> {
    match agent {
        "claude-code" => Ok(AgentId::ClaudeCode),
        "codex" => Ok(AgentId::Codex),
        "opencode" => Ok(AgentId::Opencode),
        other => Err(ServiceError::InvalidRequest(format!(
            "unsupported target_agent: {other}"
        ))),
    }
}

fn parse_scope_param(scope: &str) -> Result<Scope, ServiceError> {
    match scope {
        "agent-global" => Ok(Scope::AgentGlobal),
        "agent-project" => Ok(Scope::AgentProject),
        "tool-global" => Ok(Scope::ToolGlobal),
        other => Err(ServiceError::InvalidRequest(format!(
            "unsupported target_scope: {other}"
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::de::DeserializeOwned;
    use skills_copilot_catalog::{ConflictGroupDraft, RuleFindingDraft, SkillDefinitionDraft};
    use skills_copilot_core::{
        AgentId, NetworkAccess, PermissionRequest, SkillInstance, SkillState,
    };

    #[test]
    fn status_request_returns_supported_methods() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("1".to_string()),
            method: "service.status".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("status result");
        assert_eq!(
            result.get("protocol_version").and_then(Value::as_u64),
            Some(u64::from(SERVICE_PROTOCOL_VERSION))
        );
        let methods = result
            .get("supported_methods")
            .and_then(Value::as_array)
            .expect("methods");
        assert!(methods.contains(&Value::String("app.version".to_string())));
        assert!(methods.contains(&Value::String("app.stateSnapshot".to_string())));
        assert!(methods.contains(&Value::String("adapter.listDiagnostics".to_string())));
        assert!(methods.contains(&Value::String("analysis.scoreSkillQuality".to_string())));
        assert!(methods.contains(&Value::String("analysis.detectStaleDrift".to_string())));
        assert!(methods.contains(&Value::String("knowledge.search".to_string())));
        assert!(methods.contains(&Value::String("task.checkReadiness".to_string())));
        assert!(methods.contains(&Value::String("task.rankSkillRoutes".to_string())));
        assert!(methods.contains(&Value::String("task.compareAgentReadiness".to_string())));
        assert!(methods.contains(&Value::String("task.listBenchmarks".to_string())));
        assert!(methods.contains(&Value::String("task.saveBenchmark".to_string())));
        assert!(methods.contains(&Value::String("task.deleteBenchmark".to_string())));
        assert!(methods.contains(&Value::String("task.evaluateBenchmarks".to_string())));
        assert!(methods.contains(&Value::String("task.saveRoutingBaseline".to_string())));
        assert!(methods.contains(&Value::String("task.detectRoutingRegression".to_string())));
        assert!(methods.contains(&Value::String("routing.accuracyDashboard".to_string())));
        assert!(methods.contains(&Value::String("trace.importLocal".to_string())));
        assert!(methods.contains(&Value::String("trace.listImports".to_string())));
        assert!(methods.contains(&Value::String("trace.deleteImport".to_string())));
        assert!(methods.contains(&Value::String("llm.status".to_string())));
        assert!(methods.contains(&Value::String("llm.listProviderProfiles".to_string())));
        assert!(methods.contains(&Value::String("llm.saveProviderProfile".to_string())));
        assert!(methods.contains(&Value::String("llm.deleteProviderProfile".to_string())));
        assert!(methods.contains(&Value::String("llm.testProviderConnection".to_string())));
        assert!(methods.contains(&Value::String("llm.previewPrompt".to_string())));
        assert!(methods.contains(&Value::String("llm.confirmPromptAndSend".to_string())));
        assert!(methods.contains(&Value::String("llm.prepareAction".to_string())));
        assert!(methods.contains(&Value::String("llm.prepareSkillAnalysis".to_string())));
        assert!(methods.contains(&Value::String("cleanup.listQueue".to_string())));
        assert!(methods.contains(&Value::String("comparison.listCrossAgent".to_string())));
        assert!(methods.contains(&Value::String("rules.listTuning".to_string())));
        assert!(methods.contains(&Value::String("rules.setSeverityOverride".to_string())));
        assert!(methods.contains(&Value::String("rules.clearSeverityOverride".to_string())));
        assert!(methods.contains(&Value::String("rules.setSuppression".to_string())));
        assert!(methods.contains(&Value::String("rules.clearSuppression".to_string())));
        assert!(methods.contains(&Value::String("script.previewExecution".to_string())));
        assert!(methods.contains(&Value::String("script.execute".to_string())));
        assert!(methods.contains(&Value::String("project.getContext".to_string())));
        assert!(methods.contains(&Value::String("project.setContext".to_string())));
        assert!(methods.contains(&Value::String("project.clearContext".to_string())));
        assert!(methods.contains(&Value::String("project.validateContext".to_string())));
        assert!(methods.contains(&Value::String("catalog.listSkills".to_string())));
        assert!(methods.contains(&Value::String("catalog.getSkill".to_string())));
        assert!(methods.contains(&Value::String("catalog.analysis".to_string())));
        assert!(methods.contains(&Value::String("catalog.scanAll".to_string())));
        assert!(methods.contains(&Value::String("skill.exportBundle".to_string())));
        assert!(methods.contains(&Value::String("skill.install".to_string())));
        assert!(methods.contains(&Value::String("config.toggleSkill".to_string())));
        assert!(methods.contains(&Value::String("config.readClaudeSettings".to_string())));
        assert!(methods.contains(&Value::String("config.saveClaudeSettings".to_string())));
        assert!(methods.contains(&Value::String("snapshot.list".to_string())));
        assert!(methods.contains(&Value::String("snapshot.rollback".to_string())));
        let diagnostics = result
            .get("adapter_diagnostics")
            .and_then(Value::as_array)
            .expect("adapter diagnostics");
        assert!(diagnostics.iter().any(|diagnostic| {
            diagnostic.get("agent").and_then(Value::as_str) == Some("hermes")
                && diagnostic
                    .pointer("/access/writable_status")
                    .and_then(Value::as_str)
                    == Some("blocked")
        }));
        let project_context = result
            .get("project_context")
            .and_then(Value::as_object)
            .expect("project context summary");
        assert_eq!(
            project_context.get("source").and_then(Value::as_str),
            Some("none")
        );
        let llm = result.get("llm").and_then(Value::as_object).expect("llm");
        assert_eq!(llm.get("enabled").and_then(Value::as_bool), Some(false));
        assert_eq!(llm.get("configured").and_then(Value::as_bool), Some(false));
        assert_eq!(
            llm.get("credential_persistence_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        let script_execution = result
            .get("script_execution")
            .and_then(Value::as_object)
            .expect("script execution status");
        assert_eq!(
            script_execution.get("enabled").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            script_execution
                .get("llm_initiation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
    }

    #[test]
    fn list_agent_config_snapshots_returns_selected_agent_timeline_only() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-service-timeline-{}",
            std::process::id()
        ));
        let app_data_dir = temp_root.join("app-data");
        fs::create_dir_all(&app_data_dir).expect("create app data");
        let host = test_host(app_data_dir);
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");

        for (id, agent, scope, target, content, created_at_ms) in [
            (
                "snap-claude",
                "claude-code",
                "agent-global",
                "/tmp/home/.claude/settings.json",
                "{}\n",
                10,
            ),
            (
                "snap-codex-new",
                "codex",
                "agent-global",
                "/tmp/home/.codex/config.toml",
                "disable_response_storage = true\n",
                30,
            ),
            (
                "snap-codex-old",
                "codex",
                "agent-project",
                "/tmp/project/.codex/config.toml",
                "approval_policy = \"never\"\n",
                20,
            ),
            (
                "snap-opencode",
                "opencode",
                "agent-global",
                "/tmp/home/.config/opencode/opencode.json",
                "{}\n",
                40,
            ),
        ] {
            catalog
                .create_config_snapshot(skills_copilot_catalog::ConfigSnapshotDraft {
                    id,
                    agent,
                    scope,
                    target,
                    content,
                    reason: "pre-toggle",
                    created_at_ms,
                })
                .expect("create snapshot");
        }

        let response = host.handle(ServiceRequest {
            id: Some("timeline".to_string()),
            method: "snapshot.listAgentConfig".to_string(),
            params: json!({ "agent": "codex" }),
        });

        assert!(response.ok);
        let result = response.result.expect("timeline result");
        let snapshots: Vec<WireConfigSnapshotRecord> =
            serde_json::from_value(result).expect("decode snapshots");
        assert_eq!(
            snapshots
                .iter()
                .map(|snapshot| snapshot.id.as_str())
                .collect::<Vec<_>>(),
            vec!["snap-codex-new", "snap-codex-old"]
        );
        assert!(snapshots.iter().all(|snapshot| snapshot.agent == "codex"));

        let scoped_response = host.handle(ServiceRequest {
            id: Some("timeline-scope".to_string()),
            method: "snapshot.listAgentConfig".to_string(),
            params: json!({ "agent": "codex", "scope": "agent-project" }),
        });
        assert!(scoped_response.ok);
        let scoped_result = scoped_response.result.expect("scoped timeline result");
        let scoped_snapshots: Vec<WireConfigSnapshotRecord> =
            serde_json::from_value(scoped_result).expect("decode scoped snapshots");
        assert_eq!(scoped_snapshots.len(), 1);
        assert_eq!(scoped_snapshots[0].id, "snap-codex-old");
        assert_eq!(scoped_snapshots[0].scope, "agent-project");

        let _ = fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn catalog_analysis_returns_empty_read_only_summary() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-analysis-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("analysis".to_string()),
            method: "catalog.analysis".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("analysis result");
        assert_eq!(
            result
                .pointer("/summary/total_groups")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/summary/affected_skill_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result.get("groups").and_then(Value::as_array).map(Vec::len),
            Some(0)
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn cleanup_queue_orders_counts_and_filters_read_only_items() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-cleanup-queue-test-{}-{unique}",
            std::process::id()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_cleanup_queue_fixture(&host);

        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("cleanup".to_string()),
            method: "cleanup.listQueue".to_string(),
            params: json!({}),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("cleanup result");
        assert_eq!(
            result
                .pointer("/summary/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/writes_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        let items = result
            .get("items")
            .and_then(Value::as_array)
            .expect("queue items");
        assert!(
            items.len() >= 5,
            "expected aggregate queue items: {items:?}"
        );
        assert_eq!(
            items
                .iter()
                .map(|item| item.get("kind").and_then(Value::as_str).unwrap())
                .take(4)
                .collect::<Vec<_>>(),
            vec!["integrity", "conflict", "finding", "finding"]
        );
        assert_eq!(
            result
                .pointer("/summary/counts_by_kind/integrity")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/summary/counts_by_kind/conflict")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert!(result
            .pointer("/summary/counts_by_kind/analysis")
            .and_then(Value::as_u64)
            .is_some_and(|count| count >= 1));
        assert!(
            items
                .iter()
                .all(|item| item.get("read_only").and_then(Value::as_bool) == Some(true)),
            "all queue items should be read-only"
        );
        assert!(
            items
                .iter()
                .all(|item| item.get("writes_allowed").and_then(Value::as_bool) == Some(false)),
            "queue must expose no write affordance"
        );
        assert!(
            !items.iter().any(
                |item| item.get("source_id").and_then(Value::as_str) == Some("ignored-finding")
            ),
            "ignored triage findings should not be queued"
        );

        let filtered = host.handle(ServiceRequest {
            id: Some("cleanup-filtered".to_string()),
            method: "cleanup.listQueue".to_string(),
            params: json!({ "agent": "codex", "limit": 2 }),
        });
        assert!(filtered.ok, "{:?}", filtered.error);
        let filtered_result = filtered.result.expect("filtered cleanup");
        let filtered_items = filtered_result
            .get("items")
            .and_then(Value::as_array)
            .expect("filtered items");
        assert_eq!(filtered_items.len(), 2);
        assert!(filtered_items.iter().all(|item| {
            item.get("agent")
                .and_then(Value::as_str)
                .is_none_or(|agent| agent == "codex")
        }));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn comparison_list_cross_agent_returns_read_only_payload() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-comparison-test-{}-{unique}",
            std::process::id()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_cleanup_queue_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("comparison".to_string()),
            method: "comparison.listCrossAgent".to_string(),
            params: json!({
                "selected_instance_id": "codex-alpha",
                "agent": "codex",
                "query": "shared",
                "limit": 5
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("comparison result");
        assert_eq!(result.get("read_only").and_then(Value::as_bool), Some(true));
        assert_eq!(
            result.get("writes_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/selected_instance_id")
                .and_then(Value::as_str),
            Some("codex-alpha")
        );
        assert_eq!(
            result
                .pointer("/summary/returned_groups")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/groups/0/canonical_name")
                .and_then(Value::as_str),
            Some("shared-fixture")
        );
        assert!(result
            .pointer("/groups/0/risk_summary/finding_count")
            .and_then(Value::as_u64)
            .is_some_and(|count| count >= 1));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn comparison_list_cross_agent_missing_catalog_is_read_only_empty() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-comparison-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("comparison-empty".to_string()),
            method: "comparison.listCrossAgent".to_string(),
            params: Value::Null,
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("comparison empty result");
        assert_eq!(
            result
                .pointer("/summary/returned_groups")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(result.get("read_only").and_then(Value::as_bool), Some(true));
        assert_eq!(
            result.get("writes_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert!(
            !app_data_dir.exists(),
            "comparison.listCrossAgent must not initialize app data when there is no catalog"
        );
    }

    #[test]
    fn cleanup_queue_missing_catalog_returns_empty_without_creating_app_data() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-cleanup-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("cleanup-empty".to_string()),
            method: "cleanup.listQueue".to_string(),
            params: Value::Null,
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("cleanup result");
        assert_eq!(
            result
                .pointer("/summary/total_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result.get("items").and_then(Value::as_array).map(Vec::len),
            Some(0)
        );
        assert!(
            !app_data_dir.exists(),
            "cleanup.listQueue must not initialize app data when there is no catalog"
        );
    }

    #[test]
    fn llm_status_defaults_disabled_without_creating_files() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-status-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-llm-home-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };

        let response = host.handle(ServiceRequest {
            id: Some("llm-status".to_string()),
            method: "llm.status".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("llm status");
        assert_eq!(result.get("enabled").and_then(Value::as_bool), Some(false));
        assert_eq!(
            result.get("configured").and_then(Value::as_bool),
            Some(false)
        );
        assert!(result.get("provider").is_some_and(Value::is_null));
        assert!(result.get("model").is_some_and(Value::is_null));
        assert_eq!(
            result.get("credentials_storage").and_then(Value::as_str),
            Some("none")
        );
        assert_eq!(
            result
                .get("credential_persistence_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("provider_profile_count").and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .get("raw_prompt_persistence_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("raw_response_persistence_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(
            !app_data_dir.exists(),
            "llm.status must not initialize app data"
        );
        assert!(
            !user_home.exists(),
            "llm.status must not create credential or config roots"
        );
    }

    #[test]
    fn llm_provider_profile_save_persists_metadata_without_secret_file() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-provider-profile-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "fixture-openai",
                "display_name": "Fixture OpenAI",
                "provider_type": "openai-compatible",
                "base_url": "https://example.invalid/v1",
                "model": "fixture-model",
                "enabled": true,
                "single_request_token_limit": 4096,
                "monthly_budget_usd": 3.5
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("provider save result");
        assert_eq!(
            result.pointer("/profile/id").and_then(Value::as_str),
            Some("fixture-openai")
        );
        assert_eq!(
            result
                .pointer("/profile/provider_type")
                .and_then(Value::as_str),
            Some("openai-compatible")
        );
        assert_eq!(
            result
                .pointer("/credential_status/secret_available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("raw_secret_returned").and_then(Value::as_bool),
            Some(false)
        );

        let profiles_path = provider_profiles_path(&app_data_dir);
        let profile_content = fs::read_to_string(&profiles_path).expect("profile metadata");
        assert!(profile_content.contains("fixture-openai"));
        assert!(!profile_content.contains("api_key"));
        assert!(!app_data_dir.join("llm-credentials.json").exists());
        assert!(!app_data_dir.join("llm.yaml").exists());

        let list = host.handle(ServiceRequest {
            id: Some("provider-list".to_string()),
            method: "llm.listProviderProfiles".to_string(),
            params: Value::Null,
        });
        assert!(list.ok, "{:?}", list.error);
        let list_result = list.result.expect("provider list");
        assert_eq!(
            list_result
                .pointer("/profiles/0/id")
                .and_then(Value::as_str),
            Some("fixture-openai")
        );
        assert_eq!(
            list_result
                .get("raw_secrets_returned")
                .and_then(Value::as_bool),
            Some(false)
        );

        let status = host.handle(ServiceRequest {
            id: Some("provider-status".to_string()),
            method: "llm.status".to_string(),
            params: Value::Null,
        });
        assert!(status.ok);
        let status_result = status.result.expect("status");
        assert_eq!(
            status_result.get("configured").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            status_result
                .get("provider_profile_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            status_result
                .get("credentials_storage")
                .and_then(Value::as_str),
            Some("keychain")
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_test_provider_connection_blocks_without_key_and_writes_metadata_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-provider-test-call-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let save = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "fixture-claude",
                "display_name": "Fixture Claude",
                "provider_type": "claude-compatible",
                "base_url": "https://example.invalid",
                "model": "fixture-claude-model",
                "enabled": true,
                "api_version": "2023-06-01",
                "single_request_token_limit": 4096,
                "monthly_budget_usd": 2.0
            }),
        });
        assert!(save.ok, "{:?}", save.error);

        let test = host.handle(ServiceRequest {
            id: Some("provider-test".to_string()),
            method: "llm.testProviderConnection".to_string(),
            params: json!({
                "profile_id": "fixture-claude",
                "confirmation_id": "confirm-fixture-test",
                "timeout_ms": 250
            }),
        });

        assert!(test.ok, "{:?}", test.error);
        let result = test.result.expect("test connection");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("blocked")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("credential_accessed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("raw_prompt_persisted").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("raw_response_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("raw_secret_returned").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.pointer("/audit/action_type").and_then(Value::as_str),
            Some("test_connection")
        );
        assert_eq!(
            result
                .pointer("/audit/destination_host")
                .and_then(Value::as_str),
            Some("example.invalid")
        );
        assert_eq!(
            result
                .pointer("/audit/raw_prompt_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/audit/raw_response_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );

        let audit_path = provider_call_metadata_path(&app_data_dir);
        let audit_content = fs::read_to_string(&audit_path).expect("provider metadata");
        assert!(audit_content.contains("\"action_type\":\"test_connection\""));
        assert!(audit_content.contains("\"destination_host\":\"example.invalid\""));
        assert!(!audit_content.contains("connection test"));
        assert!(!audit_content.contains("api_key"));
        assert!(!host.script_execution_audit_path().exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn script_preview_returns_disabled_scope_without_writing_audit() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-script-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("script-preview".to_string()),
            method: "script.previewExecution".to_string(),
            params: json!({
                "command": ["python3", "scripts/build.py"],
                "cwd": "fixture-project",
                "env": {
                    "API_TOKEN": "fixture-redacted-value"
                },
                "network": "full",
                "files": ["./src/**"],
                "skill_instance_id": "skill-fixture",
                "initiated_by": "user"
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("preview result");
        assert_eq!(
            result.get("execution_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("initiator_allowed").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/confirmation/required")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.pointer("/env/value_policy").and_then(Value::as_str),
            Some("values-redacted")
        );
        let serialized = serde_json::to_string(&result).expect("serialize result");
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(
            !host.script_execution_audit_path().exists(),
            "preview must not write audit records"
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn script_execute_requires_per_request_confirmation() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-script-confirm-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("script-execute-unconfirmed".to_string()),
            method: "script.execute".to_string(),
            params: json!({
                "command": ["sh", "-c", "touch should-not-run"],
                "confirmed": false
            }),
        });

        assert!(!response.ok);
        let error = response.error.expect("confirmation error");
        assert_eq!(error.code, "confirmation_required");
        assert!(
            !host.script_execution_audit_path().exists(),
            "unconfirmed execute must not write an audit record"
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn script_execute_confirmed_writes_blocked_audit_without_spawning() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-script-audit-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("script-execute-confirmed".to_string()),
            method: "script.execute".to_string(),
            params: json!({
                "command": ["sh", "-c", "touch spawned-marker"],
                "confirmed": true
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("attempt result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("blocked")
        );
        assert_eq!(
            result.get("outcome").and_then(Value::as_str),
            Some("execution_disabled")
        );
        assert_eq!(
            result.get("spawned_process").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/preview/execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        let audit_path = host.script_execution_audit_path();
        let audit_content = fs::read_to_string(&audit_path).expect("read audit");
        assert!(audit_content.contains("\"status\":\"blocked\""));
        assert!(!app_data_dir.join("spawned-marker").exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn script_execute_confirmed_llm_initiator_is_audited_as_blocked() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-script-llm-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("script-execute-llm".to_string()),
            method: "script.execute".to_string(),
            params: json!({
                "command": ["python3", "-c", "print('blocked')"],
                "confirmed": true,
                "initiated_by": "llm"
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("attempt result");
        assert_eq!(
            result.get("outcome").and_then(Value::as_str),
            Some("llm_initiator_not_allowed")
        );
        assert_eq!(
            result
                .pointer("/preview/initiator_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        let audit_content =
            fs::read_to_string(host.script_execution_audit_path()).expect("read audit");
        assert!(audit_content.contains("llm_initiator_not_allowed"));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_prepare_action_never_allows_direct_write_or_leaks_skill_content() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-prepare-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("secret-project-path").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);

        let response = host.handle(ServiceRequest {
            id: Some("llm-prepare".to_string()),
            method: "llm.prepareAction".to_string(),
            params: json!({
                "kind": "analyze",
                "skill_instance_id": "llm-skill-id",
                "user_intent": "summarize local risk"
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("prepare action");
        assert_eq!(
            result.get("action").and_then(Value::as_str),
            Some("analyze")
        );
        assert_eq!(result.get("allowed").and_then(Value::as_bool), Some(false));
        assert_eq!(
            result.get("requires_confirmation").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("draft_requires_user_copy")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .get("estimated_total_tokens")
            .and_then(Value::as_u64)
            .is_some_and(|tokens| tokens > 0));
        assert!(result
            .get("prompt_scope")
            .and_then(Value::as_array)
            .expect("prompt scope")
            .contains(&Value::String("selected skill body".to_string())));
        let review = result
            .get("review_preview")
            .and_then(Value::as_object)
            .expect("review preview");
        assert_eq!(
            review.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            review
                .get("write_actions_available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            review
                .get("execution_actions_available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/review_preview/redaction/skill_body_returned")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/review_preview/redaction/paths_returned")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/review_preview/redaction/credentials_returned")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/review_preview/risk/level")
                .and_then(Value::as_str),
            Some("high")
        );
        assert!(review
            .get("finding_explanations")
            .and_then(Value::as_array)
            .is_some_and(|findings| !findings.is_empty()));

        let serialized = serde_json::to_string(&result).expect("serialize result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("Analyze local skill posture"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_prepare_missing_skill_returns_stable_error_without_creating_catalog() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("llm-missing".to_string()),
            method: "llm.prepareAction".to_string(),
            params: json!({
                "kind": "draft_frontmatter",
                "skill_instance_id": "missing-skill"
            }),
        });

        assert!(!response.ok);
        let error = response.error.expect("missing skill error");
        assert_eq!(error.code, "skill_not_found");
        assert!(error.message.contains("missing-skill"));
        assert!(
            !app_data_dir.exists(),
            "missing LLM skill lookup must not create catalog or app data"
        );
    }

    #[test]
    fn llm_prepare_action_does_not_create_credentials_config_or_catalog_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-no-write-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-llm-no-write-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("llm-no-write".to_string()),
            method: "llm.prepareAction".to_string(),
            params: json!({
                "kind": "draft_frontmatter",
                "skill_instance_id": "llm-skill-id",
                "user_intent": "draft safer metadata"
            }),
        });

        assert!(response.ok);
        assert_eq!(
            response
                .result
                .as_ref()
                .and_then(|result| result.get("write_back_allowed"))
                .and_then(Value::as_bool),
            Some(false)
        );
        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        let after_records = after_catalog.list_skill_records().expect("records after");
        let after_snapshots = after_catalog
            .list_all_config_snapshots()
            .expect("snapshots after");
        assert_eq!(after_records, before_records);
        assert_eq!(after_snapshots, before_snapshots);
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());
        assert!(!app_data_dir.join("llm-credentials.json").exists());
        assert!(!app_data_dir.join("llm-config.json").exists());
        let serialized = serde_json::to_string(&response.result).expect("serialize response");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("Analyze local skill posture"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn llm_prepare_skill_analysis_is_read_only_and_reports_missing_selection() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-skill-analysis-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-llm-skill-analysis-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("llm-skill-analysis".to_string()),
            method: "llm.prepareSkillAnalysis".to_string(),
            params: json!({
                "instance_ids": ["llm-skill-id", "missing-skill-id"],
                "analysis_kind": "risk"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("skill analysis prepare result");
        assert_eq!(result.get("enabled").and_then(Value::as_bool), Some(false));
        assert_eq!(
            result.get("analysis_kind").and_then(Value::as_str),
            Some("risk")
        );
        assert_eq!(
            result.get("selected_skill_count").and_then(Value::as_u64),
            Some(2)
        );
        assert_eq!(
            result.get("included_skill_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result.get("excluded_missing_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_enabled")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/script_execution_enabled")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/credential_storage_enabled")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/confirmation_required")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/included_skills/0/name")
                .and_then(Value::as_str),
            Some("llm-fixture")
        );
        assert!(result
            .get("estimated_total_tokens")
            .and_then(Value::as_u64)
            .is_some_and(|tokens| tokens > 0));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());
        assert!(!app_data_dir.join("llm-credentials.json").exists());
        assert!(!app_data_dir.join("llm-config.json").exists());
        let serialized = serde_json::to_string(&result).expect("serialize result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("Analyze local skill posture"));
        assert!(!serialized.contains("fixture-skill"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn analysis_score_skill_quality_returns_local_read_only_score() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-quality-score-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-quality-score-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("quality-score".to_string()),
            method: "analysis.scoreSkillQuality".to_string(),
            params: json!({ "instance_id": "llm-skill-id" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("quality score result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert!(result
            .get("score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score <= 100));
        assert_eq!(
            result
                .pointer("/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/script_execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/config_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/snapshot_created")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/triage_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("quality_score")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("quality_score")
        );
        assert!(result
            .get("components")
            .and_then(Value::as_array)
            .is_some_and(|components| components.len() == 5));
        assert!(result
            .get("evidence_references")
            .and_then(Value::as_array)
            .is_some_and(|evidence| !evidence.is_empty()));
        assert!(result
            .get("suggested_improvements")
            .and_then(Value::as_array)
            .is_some_and(|suggestions| !suggestions.is_empty()));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize quality result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("Analyze local skill posture"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn analysis_score_skill_quality_missing_skill_does_not_create_catalog() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-quality-score-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("quality-score-missing".to_string()),
            method: "analysis.scoreSkillQuality".to_string(),
            params: json!({ "instance_id": "missing-skill-id" }),
        });

        assert!(!response.ok);
        let error = response.error.expect("missing quality score error");
        assert_eq!(error.code, "skill_not_found");
        assert!(error.message.contains("missing-skill-id"));
        assert!(
            !app_data_dir.exists(),
            "quality scoring must not initialize app data when there is no catalog"
        );
    }

    #[test]
    fn analysis_detect_stale_drift_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-stale-drift-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("stale-drift-missing".to_string()),
            method: "analysis.detectStaleDrift".to_string(),
            params: json!({ "agent": "claude-code" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog stale drift result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/returned_row_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert!(result
            .get("stale_drift_rows")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_agent_readiness_safety(&result);
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog stale/drift detection must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn analysis_detect_stale_drift_rejects_invalid_threshold_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-stale-drift-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("stale-drift-invalid".to_string()),
            method: "analysis.detectStaleDrift".to_string(),
            params: json!({ "stale_days": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid stale drift error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("stale_days"));
        assert!(
            !app_data_dir.exists(),
            "invalid stale/drift request must not initialize app data"
        );
    }

    #[test]
    fn analysis_detect_stale_drift_returns_local_read_only_rows() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-stale-drift-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-stale-drift-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_stale_drift_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("stale-drift".to_string()),
            method: "analysis.detectStaleDrift".to_string(),
            params: json!({
                "agent": "claude-code",
                "candidate_instance_ids": ["stale-drift-alpha"],
                "limit": 4,
                "thresholds": { "stale_days": 30 }
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("stale drift result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/returned_row_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/stale_drift_rows/0/instance_id")
                .and_then(Value::as_str),
            Some("stale-drift-alpha")
        );
        assert_eq!(
            result
                .pointer("/stale_drift_rows/0/drift_signals/fingerprint_drift")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/stale_drift_rows/0/drift_signals/stale_by_mtime")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .pointer("/stale_drift_rows/0/stale_drift_score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score > 0 && score <= 100));
        assert!(result
            .get("readiness_impact_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| !rows.is_empty()));
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("stale_drift_detection")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("stale_drift_detection")
        );
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/stale_drift_rows/0/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize stale drift result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains("skills-copilot-stale-drift"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_search_lists_local_catalog_rows() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-knowledge-list-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-knowledge-list-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_knowledge_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("knowledge-list".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({ "limit": 10 }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("knowledge search result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/indexed_skill_count")
                .and_then(Value::as_u64),
            Some(2)
        );
        assert!(result
            .get("rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows.len() == 2));
        assert!(result
            .pointer("/rows/0/keywords")
            .and_then(Value::as_array)
            .is_some_and(|keywords| !keywords.is_empty()));
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("knowledge_search")
        );
        assert_agent_readiness_safety(&result);

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_search_matches_query_and_filters() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-knowledge-query-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-knowledge-query-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_knowledge_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("knowledge-query".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({
                "query": "release readiness audit",
                "agent": "claude-code",
                "tool": "Read",
                "risk": "high",
                "enabled": true,
                "limit": 5
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("knowledge query result");
        assert_eq!(
            result.pointer("/filters/query").and_then(Value::as_str),
            Some("release readiness audit")
        );
        assert_eq!(
            result
                .pointer("/filters/normalized_terms")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(3)
        );
        assert_eq!(
            result
                .pointer("/rows/0/instance_id")
                .and_then(Value::as_str),
            Some("knowledge-release")
        );
        assert!(result
            .pointer("/rows/0/matched_fields")
            .and_then(Value::as_array)
            .is_some_and(|fields| fields
                .iter()
                .any(|field| field.as_str() == Some("description"))));
        assert!(result
            .pointer("/rows/0/tools")
            .and_then(Value::as_array)
            .is_some_and(|tools| tools.iter().any(|tool| tool.as_str() == Some("Read"))));
        assert!(result
            .pointer("/rows/0/quality_context/score")
            .and_then(Value::as_u64)
            .is_some());
        assert!(result
            .pointer("/rows/0/readiness_context/score")
            .and_then(Value::as_u64)
            .is_some());
        assert!(result
            .pointer("/rows/0/stale_drift_context/score")
            .and_then(Value::as_u64)
            .is_some());
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_agent_readiness_safety(&result);

        let serialized = serde_json::to_string(&result).expect("serialize knowledge result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_search_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-knowledge-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("knowledge-missing".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({ "query": "release readiness" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog knowledge result");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/returned_row_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert!(result
            .get("rows")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_agent_readiness_safety(&result);
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog knowledge search must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn knowledge_search_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-knowledge-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("knowledge-invalid".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid knowledge error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid knowledge request must not initialize app data"
        );
    }

    #[test]
    fn knowledge_search_preserves_provider_and_write_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-knowledge-safety-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-knowledge-safety-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_knowledge_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("knowledge-safety".to_string()),
            method: "knowledge.search".to_string(),
            params: json!({ "query": "release readiness", "limit": 5 }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("knowledge safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/rows/0/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_group_similar_skills_returns_duplicate_and_confusable_groups() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-similar-group-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-similar-group-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_similar_grouping_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("similar-group".to_string()),
            method: "knowledge.groupSimilarSkills".to_string(),
            params: json!({ "limit": 10, "min_score": 40 }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("similar grouping result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/candidate_skill_count")
                .and_then(Value::as_u64),
            Some(4)
        );
        let groups = result
            .get("groups")
            .and_then(Value::as_array)
            .expect("groups");
        assert!(groups.iter().any(|group| {
            group.get("group_type").and_then(Value::as_str) == Some("duplicate")
                && group
                    .get("members")
                    .and_then(Value::as_array)
                    .is_some_and(|members| members.len() >= 2)
        }));
        assert!(groups.iter().any(|group| {
            group
                .get("routing_ambiguity")
                .and_then(Value::as_str)
                .is_some_and(|value| value == "medium" || value == "high")
        }));
        assert!(groups.iter().all(|group| {
            group
                .get("why_grouped")
                .and_then(Value::as_array)
                .is_some_and(|why| !why.is_empty())
        }));
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("similar_skill_grouping")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("similar_skill_grouping")
        );
        assert_agent_readiness_safety(&result);
        for group in groups {
            assert_eq!(
                group
                    .pointer("/safety_flags/read_only")
                    .and_then(Value::as_bool),
                Some(true)
            );
        }

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_group_similar_skills_applies_filters_limit_and_singletons() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-similar-filter-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-similar-filter-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_similar_grouping_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("similar-filter".to_string()),
            method: "knowledge.groupSimilarSkills".to_string(),
            params: json!({
                "agent": "codex",
                "candidate_instance_ids": ["similar-codex-a", "similar-unrelated"],
                "include_singletons": true,
                "limit": 1,
                "min_score": 90
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("similar filter result");
        assert_eq!(
            result.pointer("/filters/agent").and_then(Value::as_str),
            Some("codex")
        );
        assert_eq!(
            result
                .pointer("/filters/include_singletons")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/matched_group_count")
                .and_then(Value::as_u64),
            Some(2)
        );
        assert_eq!(
            result
                .pointer("/summary/returned_group_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result.get("groups").and_then(Value::as_array).map(Vec::len),
            Some(1)
        );
        assert!(result
            .pointer("/groups/0/members")
            .and_then(Value::as_array)
            .is_some_and(|members| members.len() == 1));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn knowledge_group_similar_skills_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-similar-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("similar-missing".to_string()),
            method: "knowledge.groupSimilarSkills".to_string(),
            params: json!({ "agent": "codex" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog similar result");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/returned_group_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert!(result
            .get("groups")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_agent_readiness_safety(&result);
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog grouping must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn knowledge_group_similar_skills_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-similar-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("similar-invalid".to_string()),
            method: "knowledge.groupSimilarSkills".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid similar grouping error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid grouping request must not initialize app data"
        );
    }

    #[test]
    fn knowledge_group_similar_skills_preserves_provider_and_write_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-similar-safety-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-similar-safety-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("similar-safety".to_string()),
            method: "knowledge.groupSimilarSkills".to_string(),
            params: json!({ "limit": 10 }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("similar safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize similar result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_check_readiness_returns_local_read_only_candidates() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-readiness-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-readiness-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("readiness-check".to_string()),
            method: "task.checkReadiness".to_string(),
            params: json!({
                "task": "Analyze local skill posture and execution safety",
                "agent": "claude-code",
                "candidate_instance_ids": ["llm-skill-id"],
                "limit": 4
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("task readiness result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .get("score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score <= 100));
        assert!(result
            .get("candidate_skills")
            .and_then(Value::as_array)
            .is_some_and(|candidates| candidates.len() == 1));
        assert_eq!(
            result
                .pointer("/candidate_skills/0/instance_id")
                .and_then(Value::as_str),
            Some("llm-skill-id")
        );
        assert!(result
            .pointer("/candidate_skills/0/quality_score")
            .and_then(Value::as_u64)
            .is_some());
        assert_eq!(
            result
                .pointer("/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/script_execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/config_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/snapshot_created")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/triage_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("task_readiness")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("task_readiness")
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize readiness result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_check_readiness_rejects_empty_task_without_creating_catalog() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-readiness-empty-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("readiness-empty".to_string()),
            method: "task.checkReadiness".to_string(),
            params: json!({ "task": "   " }),
        });

        assert!(!response.ok);
        let error = response.error.expect("empty task error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("non-empty task"));
        assert!(
            !app_data_dir.exists(),
            "empty readiness request must not initialize app data"
        );
    }

    #[test]
    fn task_check_readiness_missing_catalog_returns_empty_read_only_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-readiness-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("readiness-missing".to_string()),
            method: "task.checkReadiness".to_string(),
            params: json!({ "task": "Prepare a release readiness report" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog readiness result");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(result.get("score").and_then(Value::as_u64), Some(0));
        assert!(result
            .get("candidate_skills")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog readiness must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn task_rank_skill_routes_returns_local_read_only_ranking() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-routing-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("routing-rank".to_string()),
            method: "task.rankSkillRoutes".to_string(),
            params: json!({
                "task": "Analyze local skill posture and execution safety",
                "agent": "claude-code",
                "candidate_instance_ids": ["llm-skill-id"],
                "limit": 4
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("routing confidence result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .get("overall_confidence_score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score <= 100));
        assert_eq!(
            result
                .pointer("/route_candidates/0/rank")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/route_candidates/0/instance_id")
                .and_then(Value::as_str),
            Some("llm-skill-id")
        );
        assert!(result
            .pointer("/route_candidates/0/confidence_rationale")
            .and_then(Value::as_array)
            .is_some_and(|rationale| !rationale.is_empty()));
        assert!(result
            .get("likely_wrong_pick_risks")
            .and_then(Value::as_array)
            .is_some());
        assert!(result
            .get("likely_miss_risks")
            .and_then(Value::as_array)
            .is_some());
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("routing_confidence")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("routing_confidence")
        );
        assert_eq!(
            result
                .pointer("/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/script_execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/config_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/snapshot_created")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/triage_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/credential_accessed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/raw_prompt_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/raw_response_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize routing result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_rank_skill_routes_rejects_empty_task_without_creating_catalog() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-empty-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("routing-empty".to_string()),
            method: "task.rankSkillRoutes".to_string(),
            params: json!({ "task": "   " }),
        });

        assert!(!response.ok);
        let error = response.error.expect("empty routing error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("non-empty task"));
        assert!(
            !app_data_dir.exists(),
            "empty routing request must not initialize app data"
        );
    }

    #[test]
    fn task_rank_skill_routes_missing_catalog_returns_empty_read_only_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("routing-missing".to_string()),
            method: "task.rankSkillRoutes".to_string(),
            params: json!({ "task": "Prepare a release readiness report" }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog routing result");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("overall_confidence_score")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert!(result
            .get("route_candidates")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog routing must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn task_compare_agent_readiness_rejects_empty_task_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-empty-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("agent-readiness-empty".to_string()),
            method: "task.compareAgentReadiness".to_string(),
            params: json!({ "task": "   " }),
        });

        assert!(!response.ok);
        let error = response.error.expect("empty compare error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("non-empty task"));
        assert!(
            !app_data_dir.exists(),
            "empty cross-agent readiness request must not initialize app data"
        );
    }

    #[test]
    fn task_compare_agent_readiness_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-missing-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("agent-readiness-missing".to_string()),
            method: "task.compareAgentReadiness".to_string(),
            params: json!({
                "task_text": "Prepare a release readiness report",
                "agents": ["claude-code", "codex"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog comparison");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/agent_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert!(result
            .get("agent_rows")
            .and_then(Value::as_array)
            .is_some_and(Vec::is_empty));
        assert!(result.get("recommended_agent").is_some_and(Value::is_null));
        assert!(result
            .get("gap_issue_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows.len() == 1));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_agent_readiness_safety(&result);
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog cross-agent readiness must not initialize catalog.sqlite"
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
    }

    #[test]
    fn task_compare_agent_readiness_ranks_multiple_agents_and_recommends_one() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-multi-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-multi-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_cleanup_queue_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("agent-readiness-multi".to_string()),
            method: "task.compareAgentReadiness".to_string(),
            params: json!({
                "user_intent": "Review the shared fixture skill and local cleanup posture",
                "agents": ["codex", "claude-code"],
                "limit_per_agent": 2
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("multi-agent comparison");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/summary/agent_count")
                .and_then(Value::as_u64),
            Some(2)
        );
        assert!(result
            .pointer("/summary/candidate_count")
            .and_then(Value::as_u64)
            .is_some_and(|count| count >= 2));
        assert!(result
            .get("agent_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows.len() == 2));
        assert!(result
            .pointer("/agent_rows/0/comparison_score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score <= 100));
        assert!(result
            .pointer("/agent_rows/0/best_candidate/skill_name")
            .and_then(Value::as_str)
            .is_some());
        assert!(result
            .pointer("/recommended_agent/agent")
            .and_then(Value::as_str)
            .is_some_and(|agent| matches!(agent, "claude-code" | "codex")));
        assert_eq!(
            result
                .pointer("/prompt_request/action")
                .and_then(Value::as_str),
            Some("task_readiness")
        );
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("task_readiness")
        );
        assert_agent_readiness_safety(&result);

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_compare_agent_readiness_includes_optional_accuracy_context_read_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-accuracy-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-agent-readiness-accuracy-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save = host.handle(ServiceRequest {
            id: Some("agent-readiness-benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "agent-readiness-routing-fixture",
                "title": "Agent readiness routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"],
                "acceptable_agents": ["claude-code"]
            }),
        });
        assert!(save.ok, "{:?}", save.error);
        let import = host.handle(ServiceRequest {
            id: Some("agent-readiness-trace-import".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "title": "Agent readiness trace fixture",
                "content": "The agent selected llm-skill-id for Analyze local skill posture and execution safety.",
                "task": "Analyze local skill posture and execution safety",
                "agent": "claude-code",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(import.ok, "{:?}", import.error);

        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("agent-readiness-accuracy".to_string()),
            method: "task.compareAgentReadiness".to_string(),
            params: json!({
                "task": "Analyze local skill posture and execution safety",
                "agents": ["claude-code"],
                "include_routing_accuracy": true,
                "include_benchmarks": true
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("accuracy comparison");
        assert_eq!(
            result
                .pointer("/filters/include_routing_accuracy")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/filters/include_benchmarks")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .pointer("/agent_rows/0/routing_accuracy_context/benchmark_count")
            .and_then(Value::as_u64)
            .is_some());
        assert!(result
            .pointer("/agent_rows/0/benchmark_context/evaluated_count")
            .and_then(Value::as_u64)
            .is_some());
        assert_agent_readiness_safety(&result);

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_benchmark_save_list_delete_roundtrip_is_app_local() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-benchmark-roundtrip-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-benchmark-roundtrip-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };

        let save = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"],
                "expected_skill_names": ["llm-fixture"],
                "acceptable_agents": ["claude-code"],
                "acceptable_scopes": ["agent-global"],
                "success_criteria": ["Top deterministic route matches the fixture skill."]
            }),
        });
        assert!(save.ok, "{:?}", save.error);
        let saved = save.result.expect("save benchmark result");
        assert_eq!(
            saved.pointer("/benchmark/id").and_then(Value::as_str),
            Some("local-routing-fixture")
        );
        assert_eq!(saved.get("created").and_then(Value::as_bool), Some(true));
        assert_eq!(
            saved.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            saved.get("agent_config_mutated").and_then(Value::as_bool),
            Some(false)
        );
        assert!(app_data_dir.join("task-benchmarks.json").exists());
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let list = host.handle(ServiceRequest {
            id: Some("benchmark-list".to_string()),
            method: "task.listBenchmarks".to_string(),
            params: json!({}),
        });
        assert!(list.ok, "{:?}", list.error);
        let listed = list.result.expect("list benchmark result");
        assert_eq!(listed.get("count").and_then(Value::as_u64), Some(1));
        assert_eq!(
            listed.pointer("/benchmarks/0/id").and_then(Value::as_str),
            Some("local-routing-fixture")
        );
        assert_eq!(
            listed.pointer("/benchmarks/0/task").and_then(Value::as_str),
            Some("Analyze local skill posture and execution safety")
        );
        assert_eq!(
            listed.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            listed.get("raw_prompt_persisted").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            listed
                .get("raw_response_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );

        let delete = host.handle(ServiceRequest {
            id: Some("benchmark-delete".to_string()),
            method: "task.deleteBenchmark".to_string(),
            params: json!({ "id": "local-routing-fixture" }),
        });
        assert!(delete.ok, "{:?}", delete.error);
        let deleted = delete.result.expect("delete benchmark result");
        assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
        assert_eq!(
            deleted.get("remaining_count").and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            deleted
                .get("provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            deleted.get("agent_config_mutated").and_then(Value::as_bool),
            Some(false)
        );

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_benchmark_evaluate_returns_deterministic_read_only_results() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-benchmark-evaluate-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-benchmark-evaluate-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let save = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"],
                "acceptable_agents": ["claude-code"],
                "acceptable_scopes": ["agent-global"]
            }),
        });
        assert!(save.ok, "{:?}", save.error);

        let response = host.handle(ServiceRequest {
            id: Some("benchmark-evaluate".to_string()),
            method: "task.evaluateBenchmarks".to_string(),
            params: json!({ "ids": ["local-routing-fixture"] }),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("benchmark evaluation result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("evaluated_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/benchmark_results/0/expected_match_status")
                .and_then(Value::as_str),
            Some("expected_match")
        );
        assert_eq!(
            result
                .pointer("/benchmark_results/0/top_route/instance_id")
                .and_then(Value::as_str),
            Some("llm-skill-id")
        );
        assert!(result
            .pointer("/benchmark_results/0/score")
            .and_then(Value::as_u64)
            .is_some_and(|score| score <= 100));
        assert_eq!(
            result
                .pointer("/prompt_request/request/action")
                .and_then(Value::as_str),
            Some("routing_confidence")
        );
        for path in [
            "/safety_flags/read_only",
            "/benchmark_results/0/safety_flags/read_only",
        ] {
            assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(true));
        }
        for path in [
            "/safety_flags/provider_request_sent",
            "/safety_flags/write_back_allowed",
            "/safety_flags/script_execution_allowed",
            "/safety_flags/config_mutation_allowed",
            "/safety_flags/snapshot_created",
            "/safety_flags/triage_mutation_allowed",
            "/safety_flags/credential_accessed",
            "/safety_flags/raw_prompt_persisted",
            "/safety_flags/raw_response_persisted",
            "/benchmark_results/0/safety_flags/provider_request_sent",
            "/benchmark_results/0/safety_flags/write_back_allowed",
            "/benchmark_results/0/safety_flags/script_execution_allowed",
            "/benchmark_results/0/safety_flags/config_mutation_allowed",
            "/benchmark_results/0/safety_flags/snapshot_created",
            "/benchmark_results/0/safety_flags/triage_mutation_allowed",
            "/benchmark_results/0/safety_flags/credential_accessed",
            "/benchmark_results/0/safety_flags/raw_prompt_persisted",
            "/benchmark_results/0/safety_flags/raw_response_persisted",
        ] {
            assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(false));
        }

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize benchmark result");
        assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn task_benchmark_evaluate_missing_catalog_returns_safe_blocker_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-benchmark-missing-catalog-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let save = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "missing-catalog-fixture",
                "title": "Missing catalog fixture",
                "task": "Prepare a release readiness report",
                "expected_skill_refs": ["missing-skill-id"]
            }),
        });
        assert!(save.ok, "{:?}", save.error);
        assert!(!host.catalog_path().exists());

        let response = host.handle(ServiceRequest {
            id: Some("benchmark-evaluate".to_string()),
            method: "task.evaluateBenchmarks".to_string(),
            params: json!({}),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing catalog benchmark result");
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("evaluated_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/benchmark_results/0/expected_match_status")
                .and_then(Value::as_str),
            Some("blocked_no_route")
        );
        assert_eq!(
            result
                .pointer("/benchmark_results/0/score")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_back_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/script_execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/config_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/snapshot_created")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/triage_mutation_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/credential_accessed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn routing_regression_detect_missing_baseline_is_read_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-missing-baseline-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-missing-baseline-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(save.ok, "{:?}", save.error);

        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("routing-regression-detect".to_string()),
            method: "task.detectRoutingRegression".to_string(),
            params: json!({}),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("missing baseline detection result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("baseline_missing")
        );
        assert_eq!(
            result.get("baseline_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("current_evaluated_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result.get("regression_count").and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(!host.routing_regression_baseline_path().exists());

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn routing_regression_baseline_save_is_app_local() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-save-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-save-home-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(save_benchmark.ok, "{:?}", save_benchmark.error);

        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("routing-baseline-save".to_string()),
            method: "task.saveRoutingBaseline".to_string(),
            params: json!({ "ids": ["local-routing-fixture"] }),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("baseline save result");
        assert_eq!(
            result.get("app_local_only").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("baseline_file").and_then(Value::as_str),
            Some("task-routing-baseline.json")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("agent_config_mutated").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("skill_files_mutated").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/baseline/benchmark_results/0/benchmark_id")
                .and_then(Value::as_str),
            Some("local-routing-fixture")
        );
        assert!(host.routing_regression_baseline_path().exists());
        assert!(app_data_dir.join("task-routing-baseline.json").exists());

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn routing_regression_detect_after_baseline_reports_no_regression_when_unchanged() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-unchanged-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
        let save_baseline = host.handle(ServiceRequest {
            id: Some("routing-baseline-save".to_string()),
            method: "task.saveRoutingBaseline".to_string(),
            params: json!({}),
        });
        assert!(save_baseline.ok, "{:?}", save_baseline.error);

        let response = host.handle(ServiceRequest {
            id: Some("routing-regression-detect".to_string()),
            method: "task.detectRoutingRegression".to_string(),
            params: json!({}),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("unchanged detection result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("no_regressions")
        );
        assert_eq!(
            result.get("baseline_available").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("regression_count").and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result.pointer("/items/0/status").and_then(Value::as_str),
            Some("unchanged")
        );
        assert_eq!(
            result
                .pointer("/items/0/regression")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn routing_regression_detect_reports_worse_benchmark_expectation() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-regression-worse-expectation-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
        let save_baseline = host.handle(ServiceRequest {
            id: Some("routing-baseline-save".to_string()),
            method: "task.saveRoutingBaseline".to_string(),
            params: json!({}),
        });
        assert!(save_baseline.ok, "{:?}", save_baseline.error);

        let update_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-update".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["other-skill-id"]
            }),
        });
        assert!(update_benchmark.ok, "{:?}", update_benchmark.error);

        let response = host.handle(ServiceRequest {
            id: Some("routing-regression-detect".to_string()),
            method: "task.detectRoutingRegression".to_string(),
            params: json!({ "score_drop_threshold": 1, "confidence_drop_threshold": 1 }),
        });
        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("regression detection result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("regressions_detected")
        );
        assert_eq!(
            result.get("regression_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result.pointer("/items/0/status").and_then(Value::as_str),
            Some("regression")
        );
        assert_eq!(
            result
                .pointer("/items/0/regression")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/items/0/baseline/expected_match_status")
                .and_then(Value::as_str),
            Some("expected_match")
        );
        assert_eq!(
            result
                .pointer("/items/0/current/expected_match_status")
                .and_then(Value::as_str),
            Some("mismatch")
        );
        assert!(result
            .pointer("/items/0/reasons")
            .and_then(Value::as_array)
            .is_some_and(|reasons| reasons.iter().any(|reason| reason
                .as_str()
                .is_some_and(|reason| reason.contains("Expected match status worsened")))));
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn trace_import_rejects_empty_content_without_writing() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-trace-empty-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("trace-empty".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({ "content": "   " }),
        });

        assert!(!response.ok);
        let error = response.error.expect("empty trace error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("non-empty trace content"));
        assert!(!host.trace_imports_path().exists());
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn trace_import_persists_redacted_only_app_local_record() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-trace-import-test-{}-{unique}",
            std::process::id(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-trace-import-home-{}-{unique}",
            std::process::id(),
        ));
        let project_root = app_data_dir.join("project-root");
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: Some(project_root.clone()),
                project_cwd: Some(project_root.clone()),
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_llm_skill(&host, &project_root.join("fixture-skill").join("SKILL.md"));
        let raw_secret = "trace-secret-value";
        let key_label = ["API", "_", "KEY"].join("");
        let auth_label = ["Author", "ization"].join("");
        let raw_content = format!(
            "Agent selected llm-skill-id for local task.\n{key_label}={raw_secret}\nPath: {}\n{auth_label}: Bearer {raw_secret}",
            user_home.join(".local/share/app.log").display()
        );

        let response = host.handle(ServiceRequest {
            id: Some("trace-import".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "content": raw_content,
                "title": "Trace with local path",
                "source_kind": "pasted-transcript",
                "agent": "claude-code",
                "task": "Analyze local skill posture",
                "expected_skill_refs": ["llm-skill-id"],
                "expected_skill_names": ["llm-fixture"],
                "max_excerpt_chars": 1200
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("trace import result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result
                .pointer("/import/analysis/outcome")
                .and_then(Value::as_str),
            Some("hit")
        );
        assert_eq!(
            result
                .pointer("/import/analysis/detected_skills/0/instance_id")
                .and_then(Value::as_str),
            Some("llm-skill-id")
        );
        assert_eq!(
            result
                .pointer("/import/safety_flags/raw_trace_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("raw_trace_persisted").and_then(Value::as_bool),
            Some(false)
        );
        assert!(host.trace_imports_path().exists());
        let persisted =
            fs::read_to_string(host.trace_imports_path()).expect("read persisted trace import");
        assert!(persisted.contains("<redacted>"));
        assert!(persisted.contains("$HOME"));
        assert!(!persisted.contains(raw_secret));
        assert!(!persisted.contains(&key_label));
        assert!(!persisted.contains(&user_home.to_string_lossy().to_string()));
        assert!(!persisted.contains(&project_root.to_string_lossy().to_string()));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn trace_import_list_delete_roundtrip_is_app_local() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-trace-roundtrip-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

        let import = host.handle(ServiceRequest {
            id: Some("trace-import".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "trace_text": "Trace routed to llm-fixture using llm-skill-id.",
                "title": "Trace roundtrip",
                "expected_skill_names": ["llm-fixture"]
            }),
        });
        assert!(import.ok, "{:?}", import.error);
        let import_id = import
            .result
            .as_ref()
            .and_then(|result| result.pointer("/import/id"))
            .and_then(Value::as_str)
            .expect("import id")
            .to_string();

        let list = host.handle(ServiceRequest {
            id: Some("trace-list".to_string()),
            method: "trace.listImports".to_string(),
            params: json!({}),
        });
        assert!(list.ok, "{:?}", list.error);
        let listed = list.result.expect("trace list result");
        assert_eq!(listed.get("count").and_then(Value::as_u64), Some(1));
        assert_eq!(
            listed.pointer("/imports/0/id").and_then(Value::as_str),
            Some(import_id.as_str())
        );
        assert_eq!(
            listed.get("raw_trace_persisted").and_then(Value::as_bool),
            Some(false)
        );

        let delete = host.handle(ServiceRequest {
            id: Some("trace-delete".to_string()),
            method: "trace.deleteImport".to_string(),
            params: json!({ "id": import_id }),
        });
        assert!(delete.ok, "{:?}", delete.error);
        let deleted = delete.result.expect("trace delete result");
        assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
        assert_eq!(
            deleted.get("remaining_count").and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            deleted
                .get("provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn trace_import_missing_catalog_remains_read_only_unknown() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-trace-missing-catalog-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        assert!(!host.catalog_path().exists());

        let response = host.handle(ServiceRequest {
            id: Some("trace-missing-catalog".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "transcript": "Trace mentioned expected local routing but the catalog is absent.",
                "title": "Missing catalog trace",
                "expected_skill_refs": ["missing-local-skill"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response
            .result
            .expect("missing catalog trace import result");
        assert_eq!(
            result
                .pointer("/import/analysis/catalog_available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/import/analysis/outcome")
                .and_then(Value::as_str),
            Some("unknown")
        );
        assert_eq!(
            result
                .pointer("/import/safety_flags/read_only")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result
                .pointer("/import/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(host.trace_imports_path().exists());
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn routing_accuracy_dashboard_empty_evidence_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-accuracy-empty-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        assert!(!host.catalog_path().exists());
        assert!(!host.task_benchmarks_path().exists());
        assert!(!host.routing_regression_baseline_path().exists());
        assert!(!host.trace_imports_path().exists());

        let response = host.handle(ServiceRequest {
            id: Some("routing-accuracy-empty".to_string()),
            method: "routing.accuracyDashboard".to_string(),
            params: json!({
                "window_days": 30,
                "include_history": true,
                "include_recent_evidence": true
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("empty dashboard result");
        assert_eq!(
            result.get("generated_by").and_then(Value::as_str),
            Some("deterministic-service")
        );
        assert_eq!(
            result.get("catalog_available").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/summary/trace_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/summary/benchmark_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/summary/regression_count")
                .and_then(Value::as_u64),
            Some(0)
        );
        assert_eq!(
            result
                .pointer("/agent_rows")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(0)
        );
        assert!(result
            .pointer("/blocker_notes")
            .and_then(Value::as_array)
            .is_some_and(|notes| notes.iter().any(|note| note
                .as_str()
                .is_some_and(|note| note.contains("No app-local trace imports")))));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_routing_accuracy_dashboard_safety(&result);
        assert!(!host.catalog_path().exists());
        assert!(!host.task_benchmarks_path().exists());
        assert!(!host.routing_regression_baseline_path().exists());
        assert!(!host.trace_imports_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn routing_accuracy_dashboard_trace_imports_produce_counts_and_agent_rows() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-accuracy-trace-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

        let hit = host.handle(ServiceRequest {
            id: Some("trace-hit".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "content": "Assistant selected llm-fixture with id llm-skill-id.",
                "title": "Hit trace",
                "agent": "claude-code",
                "task": "Analyze local skill posture",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(hit.ok, "{:?}", hit.error);
        let wrong_pick = host.handle(ServiceRequest {
            id: Some("trace-wrong-pick".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "content": "Assistant selected llm-fixture with id llm-skill-id.",
                "title": "Wrong pick trace",
                "agent": "claude-code",
                "task": "Route release notes",
                "expected_skill_refs": ["other-skill-id"]
            }),
        });
        assert!(wrong_pick.ok, "{:?}", wrong_pick.error);

        let response = host.handle(ServiceRequest {
            id: Some("routing-accuracy-traces".to_string()),
            method: "routing.accuracyDashboard".to_string(),
            params: json!({
                "agent": "claude-code",
                "include_history": true,
                "include_recent_evidence": true,
                "limit": 10
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("trace dashboard result");
        assert_eq!(
            result
                .pointer("/summary/trace_count")
                .and_then(Value::as_u64),
            Some(2)
        );
        assert_eq!(
            result.pointer("/summary/hit_count").and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/summary/wrong_pick_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/summary/accuracy_rate")
                .and_then(Value::as_f64),
            Some(0.5)
        );
        assert_eq!(
            result
                .pointer("/agent_rows/0/agent")
                .and_then(Value::as_str),
            Some("claude-code")
        );
        assert_eq!(
            result
                .pointer("/agent_rows/0/outcomes/hit")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/agent_rows/0/outcomes/wrong_pick")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert!(result
            .pointer("/history_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows.len() == 1));
        assert!(result
            .pointer("/recent_evidence_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows.len() >= 2));
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_routing_accuracy_dashboard_safety(&result);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn routing_accuracy_dashboard_includes_benchmark_regression_and_recent_evidence() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-accuracy-regression-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

        let save_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-save".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
        assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
        let save_baseline = host.handle(ServiceRequest {
            id: Some("routing-baseline-save".to_string()),
            method: "task.saveRoutingBaseline".to_string(),
            params: json!({}),
        });
        assert!(save_baseline.ok, "{:?}", save_baseline.error);
        let update_benchmark = host.handle(ServiceRequest {
            id: Some("benchmark-update".to_string()),
            method: "task.saveBenchmark".to_string(),
            params: json!({
                "id": "local-routing-fixture",
                "title": "Local routing fixture",
                "task": "Analyze local skill posture and execution safety",
                "expected_skill_refs": ["other-skill-id"]
            }),
        });
        assert!(update_benchmark.ok, "{:?}", update_benchmark.error);

        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");
        let baseline_before =
            fs::read_to_string(host.routing_regression_baseline_path()).expect("baseline before");

        let response = host.handle(ServiceRequest {
            id: Some("routing-accuracy-regression".to_string()),
            method: "routing.accuracyDashboard".to_string(),
            params: json!({
                "include_recent_evidence": true,
                "limit": 10
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("regression dashboard result");
        assert_eq!(
            result
                .pointer("/summary/benchmark_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/summary/benchmark_gap_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/summary/regression_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert!(result
            .pointer("/gap_issue_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows
                .iter()
                .any(|row| row.get("source").and_then(Value::as_str)
                    == Some("task.detectRoutingRegression"))));
        assert!(result
            .pointer("/recent_evidence_rows")
            .and_then(Value::as_array)
            .is_some_and(|rows| rows
                .iter()
                .any(|row| row.get("source").and_then(Value::as_str)
                    == Some("task.evaluateBenchmarks"))));
        assert_eq!(
            result
                .pointer("/agent_rows/0/regression_count")
                .and_then(Value::as_u64),
            Some(1)
        );
        assert_eq!(
            result
                .pointer("/prompt_request/available")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_routing_accuracy_dashboard_safety(&result);

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        let baseline_after =
            fs::read_to_string(host.routing_regression_baseline_path()).expect("baseline after");
        assert_eq!(baseline_after, baseline_before);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_preview_prompt_accepts_task_readiness_action_with_redaction() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-readiness-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);

        let response = host.handle(ServiceRequest {
            id: Some("readiness-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "task_readiness",
                "instance_ids": ["llm-skill-id"],
                "user_intent": "Analyze local skill posture with token=fixture-redacted-value"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("task readiness preview result");
        assert_eq!(
            result.get("action").and_then(Value::as_str),
            Some("task_readiness")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert!(result
            .get("requires_confirmation")
            .and_then(Value::as_bool)
            .unwrap_or(false));
        let serialized = serde_json::to_string(&result).expect("serialize readiness preview");
        assert!(serialized.contains("Task readiness evidence"));
        assert!(serialized.contains("<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains("OPENAI_API_KEY"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_preview_prompt_accepts_routing_confidence_action_with_redaction() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-routing-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);

        let response = host.handle(ServiceRequest {
            id: Some("routing-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "routing_confidence",
                "instance_ids": ["llm-skill-id"],
                "user_intent": "Analyze local skill posture with token=fixture-redacted-value"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("routing confidence preview result");
        assert_eq!(
            result.get("action").and_then(Value::as_str),
            Some("routing_confidence")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert!(result
            .get("requires_confirmation")
            .and_then(Value::as_bool)
            .unwrap_or(false));
        let serialized =
            serde_json::to_string(&result).expect("serialize routing confidence preview");
        assert!(serialized.contains("Routing confidence evidence"));
        assert!(serialized.contains("<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains("OPENAI_API_KEY"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_preview_prompt_accepts_stale_drift_action_with_redaction() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-stale-drift-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_stale_drift_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("stale-drift-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "stale_drift_detection",
                "instance_ids": ["stale-drift-alpha"],
                "user_intent": "explain stale drift without leaking token=fixture-redacted-value"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("stale drift preview result");
        assert_eq!(
            result.get("action").and_then(Value::as_str),
            Some("stale_drift_detection")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert!(result
            .get("requires_confirmation")
            .and_then(Value::as_bool)
            .unwrap_or(false));
        let serialized = serde_json::to_string(&result).expect("serialize stale drift preview");
        assert!(serialized.contains("Stale/drift detection evidence"));
        assert!(serialized.contains("<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains("OPENAI_API_KEY"));
        assert!(!serialized.contains("skills-copilot-stale-drift"));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_preview_prompt_accepts_quality_score_action_without_sending_provider_request() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-quality-score-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);

        let response = host.handle(ServiceRequest {
            id: Some("quality-score-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "quality_score",
                "skill_instance_id": "llm-skill-id",
                "user_intent": "explain quality without leaking token=fixture-redacted-value"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("quality score preview result");
        assert_eq!(
            result.get("action").and_then(Value::as_str),
            Some("quality_score")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert!(result
            .get("requires_confirmation")
            .and_then(Value::as_bool)
            .unwrap_or(false));
        let serialized = serde_json::to_string(&result).expect("serialize quality preview");
        assert!(serialized.contains("Quality score evidence"));
        assert!(serialized.contains("<redacted>"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains("OPENAI_API_KEY"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_preview_prompt_returns_redacted_confirmation_payload() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-preview-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("secret-project-path").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let save = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "fixture-openai",
                "display_name": "Fixture OpenAI",
                "provider_type": "openai-compatible",
                "base_url": "https://example.invalid/v1",
                "model": "fixture-model",
                "enabled": true,
                "single_request_token_limit": 4096,
                "monthly_budget_usd": 3.5
            }),
        });
        assert!(save.ok, "{:?}", save.error);

        let response = host.handle(ServiceRequest {
            id: Some("preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "skill_analysis",
                "instance_ids": ["llm-skill-id", "missing-skill-id"],
                "analysis_kind": "risk",
                "user_intent": "review credential_marker=fixture-redacted-value without leaking local paths"
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("preview result");
        assert_eq!(result.get("status").and_then(Value::as_str), Some("ready"));
        assert_eq!(result.get("allowed").and_then(Value::as_bool), Some(true));
        assert_eq!(
            result.get("requires_confirmation").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("draft_requires_user_copy")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert!(result
            .get("preview_id")
            .and_then(Value::as_str)
            .is_some_and(|id| id.starts_with("prompt-preview-")));
        assert_eq!(
            result
                .pointer("/redaction/raw_prompt_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/redaction/raw_secret_returned")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert!(result
            .pointer("/redaction/redacted_value_count")
            .and_then(Value::as_u64)
            .is_some_and(|count| count > 0));

        let serialized = serde_json::to_string(&result).expect("serialize preview");
        assert!(serialized.contains("<redacted>"));
        assert!(!serialized.contains("OPENAI_API_KEY"));
        assert!(!serialized.contains("fixture-redacted-value"));
        assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_confirm_prompt_rejects_mismatched_preview_without_metadata() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-preview-mismatch-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
        let save = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "fixture-openai",
                "display_name": "Fixture OpenAI",
                "provider_type": "openai-compatible",
                "base_url": "https://example.invalid/v1",
                "model": "fixture-model",
                "enabled": true
            }),
        });
        assert!(save.ok, "{:?}", save.error);

        let response = host.handle(ServiceRequest {
            id: Some("confirm".to_string()),
            method: "llm.confirmPromptAndSend".to_string(),
            params: json!({
                "preview_id": "prompt-preview-stale",
                "confirmation_id": "confirm-preview",
                "request": {
                    "action": "analyze",
                    "skill_instance_id": "llm-skill-id"
                }
            }),
        });

        assert!(!response.ok);
        let error = response.error.expect("mismatch error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("preview_id"));
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_confirm_prompt_blocks_without_credential_and_writes_metadata_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-confirm-blocked-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        let save = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "fixture-openai",
                "display_name": "Fixture OpenAI",
                "provider_type": "openai-compatible",
                "base_url": "https://example.invalid/v1",
                "model": "fixture-model",
                "enabled": true
            }),
        });
        assert!(save.ok, "{:?}", save.error);
        let request = json!({
            "action": "recommend",
            "user_intent": "review token=fixture-redacted-value"
        });
        let preview = host.handle(ServiceRequest {
            id: Some("preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: request.clone(),
        });
        assert!(preview.ok, "{:?}", preview.error);
        let preview_id = preview
            .result
            .as_ref()
            .and_then(|result| result.get("preview_id"))
            .and_then(Value::as_str)
            .expect("preview id")
            .to_string();

        let confirm = host.handle(ServiceRequest {
            id: Some("confirm".to_string()),
            method: "llm.confirmPromptAndSend".to_string(),
            params: json!({
                "preview_id": preview_id,
                "confirmation_id": "confirm-without-credential",
                "request": request,
                "timeout_ms": 250
            }),
        });

        assert!(confirm.ok, "{:?}", confirm.error);
        let result = confirm.result.expect("confirm result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("blocked")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("credential_accessed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.pointer("/audit/error_code").and_then(Value::as_str),
            Some("credential_unavailable")
        );
        assert_eq!(
            result
                .pointer("/audit/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );

        let audit_content =
            fs::read_to_string(provider_call_metadata_path(&app_data_dir)).expect("audit content");
        assert!(audit_content.contains("\"action_type\":\"recommend\""));
        assert!(audit_content.contains("\"status\":\"blocked\""));
        assert!(!audit_content.contains("fixture-redacted-value"));
        assert!(!audit_content.contains("review token"));
        assert!(!audit_content.contains("api_key"));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn llm_confirm_prompt_sends_redacted_prompt_to_mock_provider_and_audits_metadata_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-llm-confirm-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let (base_url, server) = spawn_mock_openai_server();
        let host = test_host(app_data_dir.clone());
        let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
        seed_catalog_with_llm_skill(&host, &skill_path);
        let save = host.handle(ServiceRequest {
            id: Some("provider-save".to_string()),
            method: "llm.saveProviderProfile".to_string(),
            params: json!({
                "id": "mock-openai",
                "display_name": "Mock OpenAI",
                "provider_type": "openai-compatible",
                "base_url": base_url,
                "model": "mock-model",
                "enabled": true,
                "single_request_token_limit": 4096,
                "monthly_budget_usd": 10.0
            }),
        });
        assert!(save.ok, "{:?}", save.error);
        std::env::set_var(
            "SKILLS_COPILOT_TEST_SECRET_PROVIDER_MOCK_OPENAI",
            "test-secret-key",
        );

        let request = json!({
            "action": "analyze",
            "skill_instance_id": "llm-skill-id",
            "user_intent": "summarize risk without exposing token=fixture-redacted-value"
        });
        let preview = host.handle(ServiceRequest {
            id: Some("preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: request.clone(),
        });
        assert!(preview.ok, "{:?}", preview.error);
        let preview_result = preview.result.expect("preview result");
        let preview_id = preview_result
            .get("preview_id")
            .and_then(Value::as_str)
            .expect("preview id")
            .to_string();

        let confirm = host.handle(ServiceRequest {
            id: Some("confirm".to_string()),
            method: "llm.confirmPromptAndSend".to_string(),
            params: json!({
                "preview_id": preview_id,
                "confirmation_id": "confirm-mock-provider",
                "request": request,
                "timeout_ms": 2_000
            }),
        });
        std::env::remove_var("SKILLS_COPILOT_TEST_SECRET_PROVIDER_MOCK_OPENAI");

        assert!(confirm.ok, "{:?}", confirm.error);
        let result = confirm.result.expect("confirm result");
        assert_eq!(
            result.get("status").and_then(Value::as_str),
            Some("succeeded")
        );
        assert_eq!(
            result.get("provider_request_sent").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("credential_accessed").and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            result.get("draft_output").and_then(Value::as_str),
            Some("Draft-only review from mock provider.")
        );
        assert_eq!(
            result.get("write_back_allowed").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("script_execution_allowed")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.get("raw_prompt_persisted").and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .get("raw_response_persisted")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result.pointer("/audit/action_type").and_then(Value::as_str),
            Some("analyze")
        );
        assert_eq!(
            result
                .pointer("/audit/confirmation_id")
                .and_then(Value::as_str),
            Some("confirm-mock-provider")
        );

        let request_text = server.join().expect("mock server thread");
        assert!(request_text
            .to_lowercase()
            .contains("authorization: bearer test-secret-key"));
        assert!(request_text.contains("<redacted>"));
        assert!(!request_text.contains("OPENAI_API_KEY"));
        assert!(!request_text.contains("fixture-redacted-value"));
        assert!(!request_text.contains(&skill_path.to_string_lossy().to_string()));

        let audit_content =
            fs::read_to_string(provider_call_metadata_path(&app_data_dir)).expect("audit content");
        assert!(audit_content.contains("\"action_type\":\"analyze\""));
        assert!(audit_content.contains("\"status\":\"succeeded\""));
        assert!(audit_content.contains("\"provider_request_sent\":true"));
        assert!(!audit_content.contains("Draft-only review from mock provider."));
        assert!(!audit_content.contains("OPENAI_API_KEY"));
        assert!(!audit_content.contains("test-secret-key"));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn app_version_returns_version_and_protocol() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("version".to_string()),
            method: "app.version".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("version result");
        assert_eq!(
            result.get("protocol_version").and_then(Value::as_u64),
            Some(u64::from(SERVICE_PROTOCOL_VERSION))
        );
        assert_eq!(
            result.get("version").and_then(Value::as_str),
            Some(skills_copilot_commands::app_version())
        );
    }

    #[test]
    fn rules_tuning_methods_store_app_local_state_and_affect_findings() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-rule-tuning-service-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let skill_path = app_data_dir.join("skills/review/SKILL.md");
        let instance = SkillInstance {
            id: "rule-tuning-skill-id".to_string(),
            agent: AgentId::Codex,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: skill_path.clone(),
            display_path: skill_path,
            definition_id: "rule-tuning-definition-id".to_string(),
            name: "rule-tuning-fixture".to_string(),
            display_name: "rule-tuning-fixture".to_string(),
            description: "Rule tuning fixture.".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: "name: rule-tuning-fixture\ndescription: Rule tuning fixture\n"
                .to_string(),
            body: "Fixture body.".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: "rule-tuning-fingerprint".to_string(),
            mtime: 1,
            first_seen: 1,
            last_seen: 1,
        };
        catalog
            .upsert_skill_instance(&instance)
            .expect("upsert skill");
        catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "rule-tuning-finding-id".to_string(),
                instance_id: Some(instance.id.clone()),
                definition_id: Some(instance.definition_id.clone()),
                rule_id: "body.too-long".to_string(),
                severity: "warn".to_string(),
                message: "Skill body is longer than the local review threshold.".to_string(),
                suggestion: Some("Move long reference material into references/.".to_string()),
                created_at: 1,
            }])
            .expect("seed finding");
        drop(catalog);

        let override_response = host.handle(ServiceRequest {
            id: Some("set-override".to_string()),
            method: "rules.setSeverityOverride".to_string(),
            params: json!({
                "rule_id": "body.too-long",
                "agent": "codex",
                "severity": "info"
            }),
        });
        assert!(override_response.ok);

        let suppression_response = host.handle(ServiceRequest {
            id: Some("set-suppression".to_string()),
            method: "rules.setSuppression".to_string(),
            params: json!({
                "rule_id": "body.too-long",
                "agent": "codex",
                "reason": "Accepted locally after review.",
                "note": "V2.32 app-local suppression."
            }),
        });
        assert!(suppression_response.ok);

        let findings_response = host.handle(ServiceRequest {
            id: Some("list-findings".to_string()),
            method: "catalog.listFindings".to_string(),
            params: Value::Null,
        });
        assert!(findings_response.ok);
        let findings = findings_response
            .result
            .expect("findings result")
            .as_array()
            .expect("findings array")
            .clone();
        let finding = findings.first().expect("finding exists");
        assert_eq!(
            finding.get("effective_severity").and_then(Value::as_str),
            Some("info")
        );
        assert_eq!(
            finding.get("suppressed").and_then(Value::as_bool),
            Some(true)
        );

        let queue_response = host.handle(ServiceRequest {
            id: Some("cleanup".to_string()),
            method: "cleanup.listQueue".to_string(),
            params: Value::Null,
        });
        assert!(queue_response.ok);
        assert_eq!(
            queue_response
                .result
                .as_ref()
                .and_then(|value| value.pointer("/summary/total_count"))
                .and_then(Value::as_u64),
            Some(0)
        );

        let clear_suppression_response = host.handle(ServiceRequest {
            id: Some("clear-suppression".to_string()),
            method: "rules.clearSuppression".to_string(),
            params: json!({
                "rule_id": "body.too-long",
                "agent": "codex"
            }),
        });
        assert!(clear_suppression_response.ok);
        let clear_override_response = host.handle(ServiceRequest {
            id: Some("clear-override".to_string()),
            method: "rules.clearSeverityOverride".to_string(),
            params: json!({
                "rule_id": "body.too-long",
                "agent": "codex"
            }),
        });
        assert!(clear_override_response.ok);

        let tuning_response = host.handle(ServiceRequest {
            id: Some("list-tuning".to_string()),
            method: "rules.listTuning".to_string(),
            params: Value::Null,
        });
        assert!(tuning_response.ok);
        assert_eq!(
            tuning_response
                .result
                .and_then(|value| value.as_array().cloned())
                .map(|rows| rows.len()),
            Some(0)
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn app_state_snapshot_returns_current_catalog_state() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos();
        let host = ServiceHost {
            app_data_dir: env::temp_dir().join(format!(
                "skills-copilot-state-snapshot-test-{}-{unique}",
                std::process::id(),
            )),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("snapshot".to_string()),
            method: "app.stateSnapshot".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("snapshot result");
        assert!(result.get("status").is_some());
        assert_eq!(
            result.get("skills").and_then(Value::as_array).map(Vec::len),
            Some(0)
        );
        assert_eq!(
            result
                .get("findings")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(0)
        );
        assert_eq!(
            result
                .get("conflicts")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(0)
        );
        assert_eq!(
            result
                .get("snapshots")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(0)
        );

        let _ = fs::remove_dir_all(&host.app_data_dir);
    }

    #[test]
    fn finding_triage_service_writes_only_app_local_catalog() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-triage-service-test-{}-{unique}",
            std::process::id()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-triage-home-test-{}-{unique}",
            std::process::id()
        ));
        let settings_path = user_home.join(".claude/settings.json");
        fs::create_dir_all(settings_path.parent().expect("settings parent"))
            .expect("create settings parent");
        fs::write(&settings_path, "{\"skillOverrides\":{\"keep\":\"on\"}}\n")
            .expect("write settings");
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "triage-finding-id".to_string(),
                instance_id: Some("triage-skill-id".to_string()),
                definition_id: Some("triage-definition-id".to_string()),
                rule_id: "body.too-long".to_string(),
                severity: "warn".to_string(),
                message: "Skill body is longer than the local review threshold.".to_string(),
                suggestion: Some("Split long reference material into references/.".to_string()),
                created_at: 1,
            }])
            .expect("seed finding");
        let triage_key = catalog
            .list_rule_findings()
            .expect("list findings")
            .pop()
            .expect("finding exists")
            .triage_key;

        let response = host.handle(ServiceRequest {
            id: Some("set-triage".to_string()),
            method: "catalog.setFindingTriage".to_string(),
            params: json!({
                "triage_key": triage_key,
                "status": "ignored",
                "note": "not actionable locally"
            }),
        });

        assert!(
            response.ok,
            "triage set should succeed: {:?}",
            response.error
        );
        assert_eq!(
            fs::read_to_string(&settings_path).expect("read settings"),
            "{\"skillOverrides\":{\"keep\":\"on\"}}\n",
            "finding triage must not write agent config"
        );
        let catalog = Catalog::open(&host.catalog_path()).expect("reopen catalog");
        catalog.init().expect("re-init catalog");
        assert_eq!(
            catalog
                .list_all_config_snapshots()
                .expect("snapshots")
                .len(),
            0,
            "finding triage must not create agent config snapshots"
        );
        let finding = catalog
            .list_rule_findings()
            .expect("findings")
            .pop()
            .expect("finding exists");
        assert_eq!(finding.triage_status, "ignored");
        assert_eq!(
            finding.triage_note.as_deref(),
            Some("not actionable locally")
        );

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn unknown_method_returns_stable_error_code() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("2".to_string()),
            method: "missing.method".to_string(),
            params: Value::Null,
        });

        assert!(!response.ok);
        assert_eq!(
            response.error.expect("error").code,
            "unknown_method".to_string()
        );
    }

    #[test]
    fn get_skill_requires_instance_id_param() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("3".to_string()),
            method: "catalog.getSkill".to_string(),
            params: json!({}),
        });

        assert!(!response.ok);
        assert_eq!(response.error.expect("error").code, "json_error");
    }

    #[test]
    fn toggle_requires_on_param() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("4".to_string()),
            method: "config.toggleSkill".to_string(),
            params: json!({"instance_id": "x"}),
        });

        assert!(!response.ok);
        assert_eq!(response.error.expect("error").code, "json_error");
    }

    #[test]
    fn save_settings_requires_content_param() {
        let host = ServiceHost {
            app_data_dir: PathBuf::from("/tmp/skills-copilot-test"),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("5".to_string()),
            method: "config.saveClaudeSettings".to_string(),
            params: json!({}),
        });

        assert!(!response.ok);
        assert_eq!(response.error.expect("error").code, "json_error");
    }

    #[test]
    fn project_context_set_get_and_clear_persist_state() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-project-context-test-{}-{unique}",
            std::process::id(),
        ));
        let root = app_data_dir.join("project");
        let nested = root.join("nested");
        fs::create_dir_all(&nested).expect("create project dirs");
        let host = test_host(app_data_dir.clone());

        let set_response = host.handle(ServiceRequest {
            id: Some("set-context".to_string()),
            method: "project.setContext".to_string(),
            params: json!({
                "root_path": root,
                "current_cwd": nested,
                "name": "Fixture Project"
            }),
        });
        assert!(set_response.ok);
        let set_result = set_response.result.expect("set result");
        assert_eq!(
            set_result.pointer("/active/name").and_then(Value::as_str),
            Some("Fixture Project")
        );
        assert_eq!(
            set_result
                .pointer("/active/is_active")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert_eq!(
            set_result
                .get("recent")
                .and_then(Value::as_array)
                .map(Vec::len),
            Some(1)
        );
        assert!(app_data_dir.join("project-context.json").exists());

        let get_response = host.handle(ServiceRequest {
            id: Some("get-context".to_string()),
            method: "project.getContext".to_string(),
            params: Value::Null,
        });
        assert!(get_response.ok);
        assert_eq!(
            get_response
                .result
                .as_ref()
                .and_then(|result| result.pointer("/active/name"))
                .and_then(Value::as_str),
            Some("Fixture Project")
        );

        let clear_response = host.handle(ServiceRequest {
            id: Some("clear-context".to_string()),
            method: "project.clearContext".to_string(),
            params: Value::Null,
        });
        assert!(clear_response.ok);
        let clear_result = clear_response.result.expect("clear result");
        assert!(clear_result.get("active").is_some_and(Value::is_null));
        assert_eq!(
            clear_result
                .pointer("/recent/0/is_active")
                .and_then(Value::as_bool),
            Some(false)
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn project_validate_context_reports_validation_error_without_persisting() {
        let host = test_host(env::temp_dir().join(format!(
            "skills-copilot-project-validate-test-{}-{}",
            std::process::id(),
            unique_suffix()
        )));

        let response = host.handle(ServiceRequest {
            id: Some("validate-context".to_string()),
            method: "project.validateContext".to_string(),
            params: json!({
                "root_path": "/tmp/skills-copilot-missing-project-root-for-validation"
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("validate result");
        assert!(result
            .get("validation_error")
            .and_then(Value::as_str)
            .is_some_and(|message| message.contains("root_path")));
        assert!(!host.app_data_dir.join("project-context.json").exists());

        let _ = fs::remove_dir_all(host.app_data_dir);
    }

    #[test]
    fn project_set_context_rejects_cwd_outside_root() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-project-reject-test-{}-{unique}",
            std::process::id(),
        ));
        let root = app_data_dir.join("project");
        let outside = app_data_dir.join("outside");
        fs::create_dir_all(&root).expect("create root");
        fs::create_dir_all(&outside).expect("create outside");
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("set-invalid-context".to_string()),
            method: "project.setContext".to_string(),
            params: json!({
                "root_path": root,
                "current_cwd": outside
            }),
        });

        assert!(!response.ok);
        assert_eq!(
            response.error.expect("error").code,
            "invalid_request".to_string()
        );
        assert!(!app_data_dir.join("project-context.json").exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[cfg(unix)]
    #[test]
    fn project_set_context_rejects_symlink_escape_cwd() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-project-symlink-test-{}-{unique}",
            std::process::id(),
        ));
        let root = app_data_dir.join("project");
        let outside = app_data_dir.join("outside");
        let link = root.join("link-outside");
        fs::create_dir_all(&root).expect("create root");
        fs::create_dir_all(&outside).expect("create outside");
        std::os::unix::fs::symlink(&outside, &link).expect("create symlink");
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("set-symlink-context".to_string()),
            method: "project.setContext".to_string(),
            params: json!({
                "root_path": root,
                "current_cwd": link
            }),
        });

        assert!(!response.ok);
        assert_eq!(
            response.error.expect("error").code,
            "invalid_request".to_string()
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn scan_claude_returns_refresh_activity() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos();
        let fixture_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join("fixtures/claude-code/personal");
        let host = ServiceHost {
            app_data_dir: env::temp_dir().join(format!(
                "skills-copilot-scan-activity-test-{}-{unique}",
                std::process::id(),
            )),
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: vec![AdapterRoot {
                    scope: Scope::AgentGlobal,
                    path: fixture_root,
                    source: RootSource::Extra,
                }],
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("scan".to_string()),
            method: "catalog.scanClaude".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("scan result");
        assert_eq!(result.get("scanned_count").and_then(Value::as_u64), Some(1));
        let activity = result
            .get("activity")
            .and_then(Value::as_object)
            .expect("activity");
        assert_eq!(
            activity.get("status").and_then(Value::as_str),
            Some("completed")
        );
        assert_eq!(activity.get("skill_count").and_then(Value::as_u64), Some(1));
        assert!(activity
            .get("log_entries")
            .and_then(Value::as_array)
            .is_some_and(|entries| !entries.is_empty()));

        let _ = fs::remove_dir_all(&host.app_data_dir);
    }

    #[test]
    fn import_skill_imports_local_directory_to_tool_global_staging_only() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-service-import-test-{}-{unique}",
            std::process::id(),
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-service-import-home-{}-{unique}",
            std::process::id(),
        ));
        let source = app_data_dir.join("external-source").join("service-import");
        std::fs::create_dir_all(&source).expect("create source");
        std::fs::create_dir_all(user_home.join(".claude")).expect("create claude dir");
        let settings_path = user_home.join(".claude/settings.json");
        std::fs::write(&settings_path, "{\"skillOverrides\":{\"keep\":\"off\"}}\n")
            .expect("write settings");
        std::fs::write(
            source.join("SKILL.md"),
            "---\nname: Service Import\ndescription: Service import fixture\ntools:\n  - bash\n---\nRun `curl https://example.test/input.json`.\n",
        )
        .expect("write skill");
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };

        let response = host.handle(ServiceRequest {
            id: Some("import-local".to_string()),
            method: "catalog.importSkill".to_string(),
            params: json!({ "source_path": source }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("import result");
        assert_eq!(
            result.pointer("/imported/agent").and_then(Value::as_str),
            Some("tool-global")
        );
        assert_eq!(
            result.pointer("/imported/scope").and_then(Value::as_str),
            Some("tool-global")
        );
        let staging_path = result
            .get("staging_path")
            .and_then(Value::as_str)
            .expect("staging path");
        assert!(PathBuf::from(staging_path).starts_with(
            host.tool_global_staging_root()
                .join("skills")
                .canonicalize()
                .expect("canonical staging skills root")
        ));
        assert!(PathBuf::from(staging_path).exists());
        assert_eq!(
            std::fs::read_to_string(&settings_path).expect("read settings"),
            "{\"skillOverrides\":{\"keep\":\"off\"}}\n"
        );
        assert!(
            !user_home.join(".codex/config.toml").exists(),
            "tool-global import must not create agent config"
        );
        assert_eq!(
            result
                .pointer("/audit/read_only_preview")
                .and_then(Value::as_bool),
            Some(true)
        );
        assert!(
            result
                .get("findings")
                .and_then(Value::as_array)
                .is_some_and(|findings| !findings.is_empty()),
            "import should return audit findings"
        );

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn import_skill_rejects_github_url_without_network_clone() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-service-import-github-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("import-github".to_string()),
            method: "catalog.importSkill".to_string(),
            params: json!({ "github_url": "https://github.com/example/skill.git" }),
        });

        assert!(!response.ok);
        let error = response.error.expect("github unsupported error");
        assert_eq!(error.code, "command_error");
        assert!(error.message.contains("explicitly deferred"));
        assert!(
            !host.tool_global_staging_root().exists(),
            "unsupported GitHub import must not initialize staging"
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn scan_all_returns_multi_agent_refresh_activity() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos();
        let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
        let host = ServiceHost {
            app_data_dir: env::temp_dir().join(format!(
                "skills-copilot-scan-all-activity-test-{}-{unique}",
                std::process::id(),
            )),
            adapter_ctx: AdapterContext {
                user_home: repo_root.join("fixtures/codex/user-home"),
                project_root: None,
                project_cwd: None,
                extra_roots: vec![AdapterRoot {
                    scope: Scope::AgentGlobal,
                    path: repo_root.join("fixtures/claude-code/personal"),
                    source: RootSource::Extra,
                }],
            },
        };
        let response = host.handle(ServiceRequest {
            id: Some("scan-all".to_string()),
            method: "catalog.scanAll".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let result = response.result.expect("scan all result");
        assert_eq!(result.get("scanned_count").and_then(Value::as_u64), Some(4));
        let activity = result
            .get("activity")
            .and_then(Value::as_object)
            .expect("activity");
        assert_eq!(
            activity.get("operation").and_then(Value::as_str),
            Some("catalog.scanAll")
        );
        let first_message = activity
            .get("log_entries")
            .and_then(Value::as_array)
            .and_then(|entries| entries.first())
            .and_then(|entry| entry.get("message"))
            .and_then(Value::as_str)
            .expect("first log message");
        assert!(
            first_message.contains("Claude Code, Codex, opencode, Pi, OpenClaw, and Hermes"),
            "scanAll activity should name all supported adapters"
        );
        let summaries = activity
            .get("agent_summaries")
            .and_then(Value::as_array)
            .expect("agent summaries");
        assert_eq!(summaries.len(), 6);
        let hermes = summaries
            .iter()
            .find(|summary| summary.get("agent").and_then(Value::as_str) == Some("hermes"))
            .expect("Hermes summary");
        assert_eq!(
            hermes.get("writable_status").and_then(Value::as_str),
            Some("blocked")
        );
        assert!(hermes
            .get("read_only_reason")
            .and_then(Value::as_str)
            .is_some_and(
                |reason| reason.contains("Hermes writable toggle/install remains blocked")
            ));
        let log_messages: Vec<&str> = activity
            .get("log_entries")
            .and_then(Value::as_array)
            .expect("log entries")
            .iter()
            .filter_map(|entry| entry.get("message").and_then(Value::as_str))
            .collect();
        assert!(
            log_messages
                .iter()
                .any(|message| message.contains("root-error skipped-root path(s):")),
            "scanAll activity should name skipped roots as root-error/skipped-root"
        );
        let claude = summaries
            .iter()
            .find(|summary| summary.get("agent").and_then(Value::as_str) == Some("claude-code"))
            .expect("Claude Code summary");
        assert_eq!(
            claude.get("display_label").and_then(Value::as_str),
            Some("Claude Code")
        );
        assert_eq!(claude.get("scanned_count").and_then(Value::as_u64), Some(1));
        assert!(claude
            .get("roots_considered")
            .and_then(Value::as_array)
            .is_some_and(|roots| roots.len() >= 2));
        let codex = summaries
            .iter()
            .find(|summary| summary.get("agent").and_then(Value::as_str) == Some("codex"))
            .expect("Codex summary");
        assert_eq!(
            codex.get("display_label").and_then(Value::as_str),
            Some("Codex")
        );
        assert_eq!(codex.get("scanned_count").and_then(Value::as_u64), Some(1));
        assert_eq!(codex.get("catalog_count").and_then(Value::as_u64), Some(1));

        let _ = fs::remove_dir_all(&host.app_data_dir);
    }

    #[test]
    fn adapter_list_diagnostics_reports_roots_config_and_blockers() {
        let unique = unique_suffix();
        let temp_root = env::temp_dir().join(format!(
            "skills-copilot-adapter-diagnostics-test-{}-{unique}",
            std::process::id(),
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("project");
        fs::create_dir_all(home.join(".pi/agent/skills")).expect("create Pi skills root");
        fs::create_dir_all(home.join(".codex")).expect("create Codex config parent");
        fs::write(home.join(".codex/config.toml"), "[skills]\n").expect("write Codex config");

        let host = ServiceHost {
            app_data_dir: temp_root.join("app-data"),
            adapter_ctx: AdapterContext {
                user_home: home,
                project_root: Some(project),
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };

        let response = host.handle(ServiceRequest {
            id: Some("diagnostics".to_string()),
            method: "adapter.listDiagnostics".to_string(),
            params: Value::Null,
        });

        assert!(response.ok);
        let diagnostics = response.result.expect("diagnostics result");
        let records = diagnostics.as_array().expect("diagnostic records");
        let codex = records
            .iter()
            .find(|record| record.get("agent").and_then(Value::as_str) == Some("codex"))
            .expect("Codex diagnostics");
        assert_eq!(
            codex.pointer("/config/status").and_then(Value::as_str),
            Some("detected")
        );
        assert_eq!(
            codex
                .pointer("/access/writable_status")
                .and_then(Value::as_str),
            Some("verified-user-config")
        );
        let pi = records
            .iter()
            .find(|record| record.get("agent").and_then(Value::as_str) == Some("pi"))
            .expect("Pi diagnostics");
        assert!(pi
            .get("blockers")
            .and_then(Value::as_array)
            .is_some_and(|blockers| blockers
                .iter()
                .any(|blocker| { blocker.as_str() == Some("Pi install remains blocked.") })));
        let hermes = records
            .iter()
            .find(|record| record.get("agent").and_then(Value::as_str) == Some("hermes"))
            .expect("Hermes diagnostics");
        assert_eq!(
            hermes.pointer("/config/status").and_then(Value::as_str),
            Some("blocked")
        );
        assert_eq!(
            hermes
                .pointer("/access/writable_status")
                .and_then(Value::as_str),
            Some("blocked")
        );

        let _ = fs::remove_dir_all(temp_root);
    }

    #[test]
    fn scan_all_label_formats_four_agent_reports() {
        let reports = vec![
            AgentCatalogScanReport {
                agent: AgentId::ClaudeCode,
                display_name: "Claude Code",
                scanned_count: 1,
                roots_considered: vec![PathBuf::from("/tmp/home/.claude/skills")],
                scanned_roots: vec![PathBuf::from("/tmp/home/.claude/skills")],
                skipped_roots: Vec::new(),
            },
            AgentCatalogScanReport {
                agent: AgentId::Codex,
                display_name: "Codex",
                scanned_count: 1,
                roots_considered: vec![PathBuf::from("/tmp/home/.agents/skills")],
                scanned_roots: vec![PathBuf::from("/tmp/home/.agents/skills")],
                skipped_roots: Vec::new(),
            },
            AgentCatalogScanReport {
                agent: AgentId::Opencode,
                display_name: "opencode",
                scanned_count: 1,
                roots_considered: vec![PathBuf::from("/tmp/home/.config/opencode/skills")],
                scanned_roots: vec![PathBuf::from("/tmp/home/.config/opencode/skills")],
                skipped_roots: Vec::new(),
            },
            AgentCatalogScanReport {
                agent: AgentId::Pi,
                display_name: "Pi",
                scanned_count: 1,
                roots_considered: vec![PathBuf::from("/tmp/home/.pi/agent/skills")],
                scanned_roots: vec![PathBuf::from("/tmp/home/.pi/agent/skills")],
                skipped_roots: Vec::new(),
            },
        ];

        assert_eq!(
            scan_all_label(&reports),
            "Claude Code, Codex, opencode, and Pi"
        );
    }

    #[test]
    fn scan_all_uses_stored_project_context_when_env_context_is_absent() {
        let unique = unique_suffix();
        let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
        let host = ServiceHost {
            app_data_dir: env::temp_dir().join(format!(
                "skills-copilot-scan-all-stored-project-test-{}-{unique}",
                std::process::id(),
            )),
            adapter_ctx: AdapterContext {
                user_home: repo_root.join("fixtures/codex/user-home"),
                project_root: None,
                project_cwd: None,
                extra_roots: vec![AdapterRoot {
                    scope: Scope::AgentGlobal,
                    path: repo_root.join("fixtures/claude-code/personal"),
                    source: RootSource::Extra,
                }],
            },
        };
        let set_response = host.handle(ServiceRequest {
            id: Some("set-context".to_string()),
            method: "project.setContext".to_string(),
            params: json!({
                "root_path": repo_root.join("fixtures/codex/project"),
                "current_cwd": repo_root.join("fixtures/codex/project/nested")
            }),
        });
        assert!(set_response.ok);

        let scan_response = host.handle(ServiceRequest {
            id: Some("scan-all".to_string()),
            method: "catalog.scanAll".to_string(),
            params: Value::Null,
        });

        assert!(scan_response.ok);
        let result = scan_response.result.expect("scan all result");
        assert_eq!(result.get("scanned_count").and_then(Value::as_u64), Some(8));
        let skills = result
            .get("skills")
            .and_then(Value::as_array)
            .expect("scan skills");
        assert!(
            skills.iter().any(|skill| {
                skill.get("agent").and_then(Value::as_str) == Some("codex")
                    && skill.get("name").and_then(Value::as_str) == Some("repo-beta")
            }),
            "project context scan should expose the current project skill"
        );
        let codex = result
            .pointer("/activity/agent_summaries")
            .and_then(Value::as_array)
            .and_then(|summaries| {
                summaries
                    .iter()
                    .find(|summary| summary.get("agent").and_then(Value::as_str) == Some("codex"))
            })
            .expect("Codex summary");
        assert_eq!(codex.get("scanned_count").and_then(Value::as_u64), Some(3));
        assert!(codex
            .get("roots_considered")
            .and_then(Value::as_array)
            .is_some_and(|roots| roots.len() >= 3));

        let clear_response = host.handle(ServiceRequest {
            id: Some("clear-context".to_string()),
            method: "project.clearContext".to_string(),
            params: Value::Null,
        });
        assert!(clear_response.ok);

        let cleared_scan_response = host.handle(ServiceRequest {
            id: Some("scan-all-cleared".to_string()),
            method: "catalog.scanAll".to_string(),
            params: Value::Null,
        });
        assert!(cleared_scan_response.ok);
        let cleared = cleared_scan_response.result.expect("cleared scan result");
        let cleared_skills = cleared
            .get("skills")
            .and_then(Value::as_array)
            .expect("cleared scan skills");
        assert!(
            cleared_skills.iter().any(|skill| {
                skill.get("agent").and_then(Value::as_str) == Some("codex")
                    && skill.get("name").and_then(Value::as_str) == Some("user-alpha")
            }),
            "no-project scan should keep user-scope Codex skills visible"
        );
        assert!(
            !cleared_skills.iter().any(|skill| {
                skill.get("agent").and_then(Value::as_str) == Some("codex")
                    && skill.get("name").and_then(Value::as_str) == Some("repo-beta")
            }),
            "no-project scan should hide previously cataloged project skills"
        );

        let _ = fs::remove_dir_all(&host.app_data_dir);
    }

    #[test]
    fn skill_export_bundle_exports_staging_skill_through_service() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-service-export-test-{}-{}",
            std::process::id(),
            unique_suffix(),
        ));
        let source_dir = app_data_dir.join("staging/demo");
        fs::create_dir_all(&source_dir).expect("create source skill");
        fs::write(
            source_dir.join("SKILL.md"),
            "---\nname: service-demo\ndescription: Service export demo\nversion: 2.9.0\n---\nBody.\n",
        )
        .expect("write source skill");
        let output_dir = app_data_dir.join("exports");
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("export-service".to_string()),
            method: "skill.exportBundle".to_string(),
            params: json!({
                "source_path": source_dir,
                "output_dir": output_dir,
            }),
        });

        assert!(response.ok);
        let result = response.result.expect("export result");
        let export: WireExportedSkillBundle =
            serde_json::from_value(result).expect("decode export result");
        assert!(export.manifest_path.exists());
        assert!(export.bundle_path.join("skill/SKILL.md").exists());
        assert_eq!(export.metadata.name, "service-demo");
        assert_eq!(export.metadata.source_scope, "tool-global");
        let manifest = fs::read_to_string(&export.manifest_path).expect("read manifest");
        assert!(
            !manifest.contains(&app_data_dir.to_string_lossy().to_string()),
            "manifest reproducible fields should not include absolute app-data paths"
        );

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn report_export_local_writes_redacted_reports_and_keeps_catalog_read_only() {
        let unique = unique_suffix();
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-report-export-test-{}-{unique}",
            std::process::id()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-report-home-{}-{unique}",
            std::process::id()
        ));
        let project_root = env::temp_dir().join(format!(
            "skills-copilot-report-project-{}-{unique}",
            std::process::id()
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: Some(project_root.clone()),
                project_cwd: Some(project_root.join("nested")),
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_cleanup_queue_fixture(&host);
        seed_catalog_with_llm_skill(&host, &user_home.join(".claude/skills/redacted/SKILL.md"));
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_visible_records = host
            .list_visible_skill_records(&before_catalog)
            .expect("visible records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("report-export".to_string()),
            method: "report.exportLocal".to_string(),
            params: json!({ "formats": ["json", "markdown"] }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("report export result");
        let export: WireReportExportLocalResult =
            serde_json::from_value(result).expect("decode report export");
        assert!(export.catalog_available);
        assert!(export.read_only);
        assert!(!export.writes_allowed);
        assert!(!export.provider_request_sent);
        assert!(!export.script_execution_allowed);
        assert!(!export.credential_accessed);
        assert_eq!(export.files.len(), 2);
        assert_eq!(export.summary.skill_count, before_visible_records.len());
        assert_eq!(export.summary.finding_count, before_findings.len());
        assert!(export
            .output_dir
            .starts_with("<app-data-dir>/report-exports/"));
        assert!(export
            .files
            .iter()
            .all(|file| file.path.starts_with("<app-data-dir>/report-exports/")));

        let json_path = app_data_dir
            .join("report-exports")
            .join(&export.export_id)
            .join("report.json");
        let markdown_path = app_data_dir
            .join("report-exports")
            .join(&export.export_id)
            .join("report.md");
        let json_content = fs::read_to_string(json_path).expect("read json report");
        let markdown_content = fs::read_to_string(markdown_path).expect("read markdown report");
        for raw_path in [
            app_data_dir.to_string_lossy().to_string(),
            user_home.to_string_lossy().to_string(),
            project_root.to_string_lossy().to_string(),
        ] {
            assert!(
                !json_content.contains(&raw_path),
                "json report leaked raw path {raw_path}"
            );
            assert!(
                !markdown_content.contains(&raw_path),
                "markdown report leaked raw path {raw_path}"
            );
        }
        assert!(json_content.contains("<app-data-dir>"));
        assert!(json_content.contains("$HOME"));
        assert!(json_content.contains("<project-root>"));
        assert!(markdown_content.contains("Skills Copilot Local Report"));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!user_home.join(".codex/config.toml").exists());
        assert!(!user_home.join(".claude/settings.json").exists());

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
        let _ = fs::remove_dir_all(project_root);
    }

    #[test]
    fn report_export_local_missing_catalog_writes_empty_report_without_catalog_init() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-report-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("report-empty".to_string()),
            method: "report.exportLocal".to_string(),
            params: json!({ "formats": ["json"] }),
        });

        assert!(response.ok, "{:?}", response.error);
        let export: WireReportExportLocalResult =
            serde_json::from_value(response.result.expect("report result"))
                .expect("decode report result");
        assert!(!export.catalog_available);
        assert_eq!(export.summary.skill_count, 0);
        assert_eq!(export.summary.finding_count, 0);
        assert_eq!(export.summary.cleanup_item_count, 0);
        assert_eq!(export.files.len(), 1);
        assert!(
            !host.catalog_path().exists(),
            "missing-catalog export must not initialize catalog.sqlite"
        );
        assert!(!host.script_execution_audit_path().exists());
        let json_path = app_data_dir
            .join("report-exports")
            .join(&export.export_id)
            .join("report.json");
        let json_content = fs::read_to_string(json_path).expect("read empty report");
        assert!(json_content.contains("\"catalog_available\": false"));
        assert!(json_content.contains("\"writes_allowed\": false"));

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn service_protocol_fixtures_decode() {
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

    fn decode_response_fixture(method: &str, result: &Value, path: &Path) {
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
                let _: Vec<WireAdapterCapabilityRecord> =
                    decode_fixture_result(method, result, path);
            }
            "adapter.listDiagnostics" => {
                let diagnostics: Vec<WireAdapterDiagnosticsRecord> =
                    decode_fixture_result(method, result, path);
                assert!(diagnostics
                    .iter()
                    .any(|diagnostic| diagnostic.access.writable_status == "blocked"));
            }
            "evidence.piWritableHarness" => {
                let report: WirePiWritableHarnessReport =
                    decode_fixture_result(method, result, path);
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
                let score: WireSkillQualityScoreResult =
                    decode_fixture_result(method, result, path);
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
            "task.checkReadiness" => {
                let readiness: WireTaskReadinessResult =
                    decode_fixture_result(method, result, path);
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
                let ranking: WireSkillRouteRankingResult =
                    decode_fixture_result(method, result, path);
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
                let saved: WireSaveTaskBenchmarkResult =
                    decode_fixture_result(method, result, path);
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
                let saved: WireSaveRoutingBaselineResult =
                    decode_fixture_result(method, result, path);
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
            "trace.importLocal" => {
                let imported: WireTraceImportLocalResult =
                    decode_fixture_result(method, result, path);
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
                let imports: WireTraceImportListResult =
                    decode_fixture_result(method, result, path);
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
                let deleted: WireTraceDeleteImportResult =
                    decode_fixture_result(method, result, path);
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
                let saved: WireSaveProviderProfileResult =
                    decode_fixture_result(method, result, path);
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
                let preview: WireLlmPreviewPromptResult =
                    decode_fixture_result(method, result, path);
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
            "llm.prepareAction" => {
                let prepare: WireLlmPrepareActionResult =
                    decode_fixture_result(method, result, path);
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
                let preview: WireBatchTogglePreviewRecord =
                    decode_fixture_result(method, result, path);
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
                let applied: WireBatchToggleApplyRecord =
                    decode_fixture_result(method, result, path);
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
                let export: WireReportExportLocalResult =
                    decode_fixture_result(method, result, path);
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
                let findings: Vec<WireRuleFindingRecord> =
                    decode_fixture_result(method, result, path);
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
                    let _: Vec<WireFindingTriageRecord> =
                        decode_fixture_result(method, result, path);
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
                let import: WireToolGlobalImportResult =
                    decode_fixture_result(method, result, path);
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
            "config.readClaudeSettings" | "config.saveClaudeSettings" => {
                let _: WireConfigDocumentRecord = decode_fixture_result(method, result, path);
            }
            "snapshot.list" | "snapshot.listAgentConfig" => {
                let _: Vec<WireConfigSnapshotRecord> = decode_fixture_result(method, result, path);
            }
            "snapshot.previewRollback" => {
                let _: WireSnapshotRollbackPreviewRecord =
                    decode_fixture_result(method, result, path);
            }
            "snapshot.rollback" => {
                let _: usize = decode_fixture_result(method, result, path);
            }
            _ => panic!("no typed response decoder for fixture method {method}"),
        }
    }

    fn fixture_method_from_name<'a>(name: &'a str, suffix: &str) -> &'a str {
        let stem = name
            .strip_suffix(suffix)
            .unwrap_or_else(|| panic!("fixture {name} missing suffix {suffix}"));
        supported_methods()
            .into_iter()
            .filter(|method| stem == *method || stem.starts_with(&format!("{method}.")))
            .max_by_key(|method| method.len())
            .unwrap_or(stem)
    }

    fn decode_fixture_result<T: DeserializeOwned>(method: &str, result: &Value, path: &Path) -> T {
        serde_json::from_value::<T>(result.clone()).unwrap_or_else(|error| {
            panic!(
                "response fixture {} result for {method} failed typed decode: {error}",
                path.display()
            )
        })
    }

    fn assert_supported_methods(method: &str, actual: &[String]) {
        let expected: Vec<String> = supported_methods()
            .into_iter()
            .map(ToOwned::to_owned)
            .collect();
        assert_eq!(actual, expected, "{method} supported_methods drifted");
    }

    fn assert_trace_import_safety(flags: &WireTraceImportSafetyFlags) {
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

    fn assert_routing_accuracy_dashboard_safety(result: &Value) {
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

    fn assert_agent_readiness_safety(result: &Value) {
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

    fn assert_agent_readiness_safety_flags(flags: &WireAgentReadinessSafetyFlags) {
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

    fn assert_findings_cover_v28_contract(
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

    fn assert_v28_permissions_payload(permissions: &Value, method: &str) {
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
    fn skill_detail_contract_accepts_legacy_and_v28_permission_payloads() {
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
            "llm.prepareSkillAnalysis" => {
                json!({ "instance_ids": ["missing-skill"], "analysis_kind": "overview" })
            }
            "analysis.scoreSkillQuality" => json!({ "instance_id": "missing-skill" }),
            "analysis.detectStaleDrift" => json!({ "limit": 4, "stale_days": 30 }),
            "knowledge.search" => json!({ "query": "fixture knowledge search", "limit": 4 }),
            "task.checkReadiness" => json!({ "task": "fixture task readiness check" }),
            "task.rankSkillRoutes" => json!({ "task": "fixture routing confidence check" }),
            "task.compareAgentReadiness" => json!({
                "task": "fixture cross-agent readiness check",
                "agents": ["claude-code", "codex"],
                "limit_per_agent": 2
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

    fn test_host(app_data_dir: PathBuf) -> ServiceHost {
        ServiceHost {
            app_data_dir,
            adapter_ctx: AdapterContext {
                user_home: PathBuf::from("/tmp/home"),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        }
    }

    fn spawn_mock_openai_server() -> (String, std::thread::JoinHandle<String>) {
        let listener =
            std::net::TcpListener::bind("127.0.0.1:0").expect("bind mock provider listener");
        let port = listener
            .local_addr()
            .expect("mock provider local addr")
            .port();
        let handle = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().expect("accept mock provider request");
            let mut bytes = Vec::new();
            let mut buffer = [0u8; 1024];
            let mut header_end = None;
            while header_end.is_none() {
                let read = std::io::Read::read(&mut stream, &mut buffer)
                    .expect("read mock provider headers");
                assert!(read > 0, "mock provider request closed before headers");
                bytes.extend_from_slice(&buffer[..read]);
                header_end = find_header_end(&bytes);
            }
            let header_end = header_end.expect("header end");
            let headers = String::from_utf8_lossy(&bytes[..header_end]).to_string();
            let content_length = headers
                .lines()
                .find_map(|line| {
                    let (name, value) = line.split_once(':')?;
                    if name.eq_ignore_ascii_case("content-length") {
                        value.trim().parse::<usize>().ok()
                    } else {
                        None
                    }
                })
                .unwrap_or(0);
            let body_start = header_end + 4;
            while bytes.len().saturating_sub(body_start) < content_length {
                let read =
                    std::io::Read::read(&mut stream, &mut buffer).expect("read mock provider body");
                assert!(read > 0, "mock provider request closed before body");
                bytes.extend_from_slice(&buffer[..read]);
            }
            let request_text = String::from_utf8_lossy(&bytes).to_string();
            let body = r#"{"choices":[{"message":{"content":"Draft-only review from mock provider."}}],"usage":{"prompt_tokens":32,"completion_tokens":8,"total_tokens":40}}"#;
            let response = format!(
                "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                body.len(),
                body
            );
            std::io::Write::write_all(&mut stream, response.as_bytes())
                .expect("write mock provider response");
            request_text
        });
        (format!("http://localhost:{port}/v1"), handle)
    }

    fn find_header_end(bytes: &[u8]) -> Option<usize> {
        bytes.windows(4).position(|window| window == b"\r\n\r\n")
    }

    fn seed_catalog_with_llm_skill(host: &ServiceHost, path: &Path) {
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).expect("create skill parent");
        }
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let instance = SkillInstance {
            id: "llm-skill-id".to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: path.to_path_buf(),
            display_path: path.to_path_buf(),
            definition_id: "llm-definition-id".to_string(),
            name: "llm-fixture".to_string(),
            display_name: "llm-fixture".to_string(),
            description: "Fixture skill for local LLM planning.".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: "name: llm-fixture\ndescription: Fixture skill\n".to_string(),
            body: "Analyze local skill posture. OPENAI_API_KEY=<redacted>".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: "llm-fingerprint".to_string(),
            mtime: 1,
            first_seen: 1,
            last_seen: 1,
        };
        catalog
            .upsert_skill_instance(&instance)
            .expect("upsert llm fixture skill");
        catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "llm-finding-id".to_string(),
                instance_id: Some("llm-skill-id".to_string()),
                definition_id: Some("llm-definition-id".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message: "Execution-like behavior needs human review; sample-key=fixture-redacted-value must not leak.".to_string(),
                suggestion: Some(
                    "Keep execution disabled and require explicit human confirmation.".to_string(),
                ),
                created_at: 1,
            }])
            .expect("upsert llm fixture finding");
    }

    fn seed_catalog_with_cleanup_queue_fixture(host: &ServiceHost) {
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let instances = vec![
            cleanup_skill(
                "claude-alpha",
                AgentId::ClaudeCode,
                Scope::AgentGlobal,
                "shared-fixture",
                "Shared Fixture",
                SkillState::Loaded,
                true,
            ),
            cleanup_skill(
                "codex-alpha",
                AgentId::Codex,
                Scope::AgentGlobal,
                "shared-fixture",
                "Shared Fixture",
                SkillState::Loaded,
                true,
            ),
            cleanup_skill(
                "codex-conflict-a",
                AgentId::Codex,
                Scope::AgentGlobal,
                "codex-conflict-definition",
                "Codex Conflict",
                SkillState::Loaded,
                true,
            ),
            cleanup_skill(
                "codex-conflict-b",
                AgentId::Codex,
                Scope::AgentProject,
                "codex-conflict-definition",
                "Codex Conflict",
                SkillState::Loaded,
                true,
            ),
            cleanup_skill(
                "broken-skill",
                AgentId::ClaudeCode,
                Scope::AgentGlobal,
                "broken-definition",
                "Broken Fixture",
                SkillState::Broken,
                false,
            ),
        ];
        catalog
            .upsert_skill_instances(&instances)
            .expect("upsert cleanup skills");
        catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "error-finding".to_string(),
                    instance_id: Some("codex-alpha".to_string()),
                    definition_id: Some("shared-fixture".to_string()),
                    rule_id: "permissions.exec-needs-human".to_string(),
                    severity: "error".to_string(),
                    message: "Execution permission needs human review.".to_string(),
                    suggestion: Some(
                        "Keep execution disabled unless explicitly reviewed.".to_string(),
                    ),
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "warn-finding".to_string(),
                    instance_id: Some("claude-alpha".to_string()),
                    definition_id: Some("shared-fixture".to_string()),
                    rule_id: "body.too-long".to_string(),
                    severity: "warn".to_string(),
                    message: "Skill body is long.".to_string(),
                    suggestion: Some("Move reference content into references/.".to_string()),
                    created_at: 2,
                },
                RuleFindingDraft {
                    id: "ignored-finding".to_string(),
                    instance_id: Some("claude-alpha".to_string()),
                    definition_id: Some("shared-fixture".to_string()),
                    rule_id: "fingerprint.changed".to_string(),
                    severity: "info".to_string(),
                    message: "Fingerprint changed.".to_string(),
                    suggestion: Some("Review the changed skill.".to_string()),
                    created_at: 3,
                },
            ])
            .expect("refresh cleanup findings");
        let ignored_key = catalog
            .list_rule_findings()
            .expect("list seeded findings")
            .into_iter()
            .find(|finding| finding.id == "ignored-finding")
            .expect("ignored finding")
            .triage_key;
        catalog
            .set_finding_triage(&ignored_key, "ignored", Some("not actionable"), 4)
            .expect("ignore fixture finding");
        catalog
            .refresh_definitions_and_conflicts(
                &[SkillDefinitionDraft {
                    id: "codex-conflict-definition".to_string(),
                    canonical_name: "codex-conflict".to_string(),
                    description: "Codex conflict fixture.".to_string(),
                    active_instance: Some("codex-conflict-a".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                }],
                &[ConflictGroupDraft {
                    id: "codex-runtime-conflict".to_string(),
                    definition_id: "codex-conflict-definition".to_string(),
                    reason: "content-drift".to_string(),
                    winner_id: Some("codex-conflict-a".to_string()),
                    instance_ids: vec![
                        "codex-conflict-a".to_string(),
                        "codex-conflict-b".to_string(),
                    ],
                }],
            )
            .expect("refresh cleanup conflicts");
    }

    fn seed_catalog_with_stale_drift_fixture(host: &ServiceHost) {
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let instances = vec![
            stale_drift_skill(
                "stale-drift-alpha",
                AgentId::ClaudeCode,
                Scope::AgentGlobal,
                "stale-drift-definition",
                "Stale Drift Alpha",
                1,
            ),
            stale_drift_skill(
                "stale-drift-beta",
                AgentId::ClaudeCode,
                Scope::AgentProject,
                "stale-drift-definition",
                "Stale Drift Alpha",
                unix_timestamp_millis(),
            ),
        ];
        catalog
            .upsert_skill_instances(&instances)
            .expect("upsert stale drift skills");
        catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "stale-drift-fingerprint".to_string(),
                    instance_id: Some("stale-drift-alpha".to_string()),
                    definition_id: Some("stale-drift-definition".to_string()),
                    rule_id: "fingerprint.changed".to_string(),
                    severity: "warning".to_string(),
                    message:
                        "Skill content fingerprint changed since the previous scan; token=fixture-redacted-value."
                            .to_string(),
                    suggestion: Some("Review the changed skill before routing to it.".to_string()),
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "stale-drift-warning".to_string(),
                    instance_id: Some("stale-drift-alpha".to_string()),
                    definition_id: Some("stale-drift-definition".to_string()),
                    rule_id: "body.too-long".to_string(),
                    severity: "warn".to_string(),
                    message: "Skill body is long enough to require review.".to_string(),
                    suggestion: Some("Move durable details into references/.".to_string()),
                    created_at: 2,
                },
            ])
            .expect("refresh stale drift findings");
        catalog
            .refresh_definitions_and_conflicts(
                &[SkillDefinitionDraft {
                    id: "stale-drift-definition".to_string(),
                    canonical_name: "stale-drift-alpha".to_string(),
                    description: "Stale drift fixture definition.".to_string(),
                    active_instance: Some("stale-drift-alpha".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                }],
                &[ConflictGroupDraft {
                    id: "stale-drift-conflict".to_string(),
                    definition_id: "stale-drift-definition".to_string(),
                    reason: "content-drift".to_string(),
                    winner_id: Some("stale-drift-alpha".to_string()),
                    instance_ids: vec![
                        "stale-drift-alpha".to_string(),
                        "stale-drift-beta".to_string(),
                    ],
                }],
            )
            .expect("refresh stale drift conflicts");
    }

    fn seed_catalog_with_knowledge_fixture(host: &ServiceHost) {
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let release_path = host
            .adapter_ctx
            .user_home
            .join(".claude/skills/release-readiness/SKILL.md");
        let disabled_path = host
            .adapter_ctx
            .user_home
            .join(".codex/skills/disabled-research/SKILL.md");
        let instances = vec![
            SkillInstance {
                id: "knowledge-release".to_string(),
                agent: AgentId::ClaudeCode,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: release_path.clone(),
                display_path: release_path,
                definition_id: "knowledge-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local app validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and validation notes."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: false,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "knowledge-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "knowledge-disabled".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: disabled_path.clone(),
                display_path: disabled_path,
                definition_id: "knowledge-disabled-definition".to_string(),
                name: "disabled-research-helper".to_string(),
                display_name: "disabled-research-helper".to_string(),
                description: "Disabled research helper fixture.".to_string(),
                version: None,
                state: SkillState::Broken,
                enabled: false,
                frontmatter_raw:
                    "name: disabled-research-helper\ndescription: Disabled research helper\n"
                        .to_string(),
                body: "Research helper body for listing tests.".to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest::default(),
                fingerprint: "knowledge-disabled-fingerprint".to_string(),
                mtime: unix_timestamp_millis(),
                first_seen: 1,
                last_seen: unix_timestamp_millis(),
            },
        ];
        catalog
            .upsert_skill_instances(&instances)
            .expect("upsert knowledge skills");
        catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "knowledge-release-risk".to_string(),
                    instance_id: Some("knowledge-release".to_string()),
                    definition_id: Some("knowledge-release-definition".to_string()),
                    rule_id: "permissions.exec-needs-human".to_string(),
                    severity: "error".to_string(),
                    message:
                        "Release readiness fixture requires human review; token=fixture-redacted-value."
                            .to_string(),
                    suggestion: Some("Keep release audit actions read-only.".to_string()),
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "knowledge-release-drift".to_string(),
                    instance_id: Some("knowledge-release".to_string()),
                    definition_id: Some("knowledge-release-definition".to_string()),
                    rule_id: "fingerprint.changed".to_string(),
                    severity: "warning".to_string(),
                    message: "Release readiness fingerprint drift fixture.".to_string(),
                    suggestion: Some("Review changed release readiness guidance.".to_string()),
                    created_at: 2,
                },
            ])
            .expect("refresh knowledge findings");
        catalog
            .refresh_definitions_and_conflicts(
                &[SkillDefinitionDraft {
                    id: "knowledge-release-definition".to_string(),
                    canonical_name: "release-readiness-audit".to_string(),
                    description: "Knowledge release readiness fixture.".to_string(),
                    active_instance: Some("knowledge-release".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                }],
                &[ConflictGroupDraft {
                    id: "knowledge-release-conflict".to_string(),
                    definition_id: "knowledge-release-definition".to_string(),
                    reason: "content-drift".to_string(),
                    winner_id: Some("knowledge-release".to_string()),
                    instance_ids: vec!["knowledge-release".to_string()],
                }],
            )
            .expect("refresh knowledge conflicts");
    }

    fn seed_catalog_with_similar_grouping_fixture(host: &ServiceHost) {
        fs::create_dir_all(&host.app_data_dir).expect("create app data");
        let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
        catalog.init().expect("init catalog");
        let claude_path = host
            .adapter_ctx
            .user_home
            .join(".claude/skills/release-readiness/SKILL.md");
        let codex_path = host
            .adapter_ctx
            .user_home
            .join(".codex/skills/release-readiness/SKILL.md");
        let research_path = host
            .adapter_ctx
            .user_home
            .join(".codex/skills/release-research/SKILL.md");
        let unrelated_path = host
            .adapter_ctx
            .user_home
            .join(".codex/skills/theme-helper/SKILL.md");
        let instances = vec![
            SkillInstance {
                id: "similar-claude-a".to_string(),
                agent: AgentId::ClaudeCode,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: claude_path.clone(),
                display_path: claude_path,
                definition_id: "similar-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and privacy checks."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-codex-a".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: codex_path.clone(),
                display_path: codex_path,
                definition_id: "similar-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and privacy checks."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-codex-research".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: research_path.clone(),
                display_path: research_path,
                definition_id: "similar-research-definition".to_string(),
                name: "release-research-readiness".to_string(),
                display_name: "release-research-readiness".to_string(),
                description:
                    "Research release readiness evidence, validation notes, and privacy findings."
                        .to_string(),
                version: None,
                state: SkillState::Broken,
                enabled: false,
                frontmatter_raw:
                    "name: release-research-readiness\ndescription: Release research readiness\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Research local release evidence and compare readiness findings for review."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-research-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-unrelated".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: unrelated_path.clone(),
                display_path: unrelated_path,
                definition_id: "similar-theme-definition".to_string(),
                name: "theme-helper".to_string(),
                display_name: "theme-helper".to_string(),
                description: "Theme helper fixture for unrelated grouping coverage.".to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw: "name: theme-helper\ndescription: Theme helper\n".to_string(),
                body: "Theme helper body for unrelated singleton tests.".to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest::default(),
                fingerprint: "similar-theme-fingerprint".to_string(),
                mtime: unix_timestamp_millis(),
                first_seen: 1,
                last_seen: unix_timestamp_millis(),
            },
        ];
        catalog
            .upsert_skill_instances(&instances)
            .expect("upsert similar grouping skills");
        catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "similar-release-exec".to_string(),
                    instance_id: Some("similar-claude-a".to_string()),
                    definition_id: Some("similar-release-definition".to_string()),
                    rule_id: "permissions.exec-needs-human".to_string(),
                    severity: "error".to_string(),
                    message:
                        "Release readiness fixture requires human review; token=fixture-redacted-value."
                            .to_string(),
                    suggestion: Some("Keep release audit actions read-only.".to_string()),
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "similar-research-drift".to_string(),
                    instance_id: Some("similar-codex-research".to_string()),
                    definition_id: Some("similar-research-definition".to_string()),
                    rule_id: "fingerprint.changed".to_string(),
                    severity: "warning".to_string(),
                    message: "Research readiness fingerprint drift fixture.".to_string(),
                    suggestion: Some("Review changed release research guidance.".to_string()),
                    created_at: 2,
                },
            ])
            .expect("refresh similar grouping findings");
        catalog
            .refresh_definitions_and_conflicts(
                &[
                    SkillDefinitionDraft {
                        id: "similar-release-definition".to_string(),
                        canonical_name: "release-readiness-audit".to_string(),
                        description: "Similar release readiness fixture.".to_string(),
                        active_instance: Some("similar-claude-a".to_string()),
                        has_multiple_instances: true,
                        has_conflict: true,
                    },
                    SkillDefinitionDraft {
                        id: "similar-research-definition".to_string(),
                        canonical_name: "release-research-readiness".to_string(),
                        description: "Similar release research fixture.".to_string(),
                        active_instance: Some("similar-codex-research".to_string()),
                        has_multiple_instances: false,
                        has_conflict: false,
                    },
                ],
                &[ConflictGroupDraft {
                    id: "similar-release-conflict".to_string(),
                    definition_id: "similar-release-definition".to_string(),
                    reason: "duplicate-canonical-name".to_string(),
                    winner_id: Some("similar-claude-a".to_string()),
                    instance_ids: vec![
                        "similar-claude-a".to_string(),
                        "similar-codex-a".to_string(),
                    ],
                }],
            )
            .expect("refresh similar grouping conflicts");
    }

    fn cleanup_skill(
        id: &str,
        agent: AgentId,
        scope: Scope,
        definition_id: &str,
        name: &str,
        state: SkillState,
        enabled: bool,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent,
            scope,
            project_root: None,
            path: PathBuf::from(format!("/tmp/skills-copilot-cleanup/{id}/SKILL.md")),
            display_path: PathBuf::from(format!("/tmp/skills-copilot-cleanup/{id}/SKILL.md")),
            definition_id: definition_id.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "Cleanup queue fixture skill.".to_string(),
            version: None,
            state,
            enabled,
            frontmatter_raw: format!("name: {name}\ndescription: Cleanup queue fixture\n"),
            body: "Cleanup queue fixture body.".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: format!("fingerprint-{id}"),
            mtime: 1,
            first_seen: 1,
            last_seen: 1,
        }
    }

    fn stale_drift_skill(
        id: &str,
        agent: AgentId,
        scope: Scope,
        definition_id: &str,
        name: &str,
        mtime: i64,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent,
            scope,
            project_root: None,
            path: PathBuf::from(format!("/tmp/skills-copilot-stale-drift/{id}/SKILL.md")),
            display_path: PathBuf::from(format!("/tmp/skills-copilot-stale-drift/{id}/SKILL.md")),
            definition_id: definition_id.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "Stale drift fixture skill.".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: format!("name: {name}\ndescription: Stale drift fixture\n"),
            body: "Stale drift fixture body.".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: format!("fingerprint-{id}"),
            mtime,
            first_seen: 1,
            last_seen: if mtime > 1 { mtime } else { 1 },
        }
    }

    fn unique_suffix() -> u128 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos()
    }
}
