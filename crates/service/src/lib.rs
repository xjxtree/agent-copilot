use std::{
    collections::BTreeMap,
    env, fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use skills_copilot_catalog::{
    Catalog, ConfigSnapshotRecord, ConflictGroupRecord, FindingTriageRecord, RuleFindingRecord,
    RuleTuningRecord, SkillDetailRecord, SkillEventRecord, SkillRecord,
};
use skills_copilot_commands::{
    analyze_catalog, apply_skill_toggles, clear_finding_triage, clear_rule_severity_override,
    clear_rule_suppression, export_skill_bundle, export_staging_skill_bundle, get_skill,
    import_github_skill_to_tool_global_deferred, import_local_skill_to_tool_global,
    install_skill_from_tool_global, list_adapter_capabilities, list_agent_config_snapshots,
    list_conflicts, list_finding_triage, list_findings, list_rule_tuning, list_skill_events,
    list_snapshots, preview_script_execution, preview_skill_toggles, preview_snapshot_rollback,
    read_claude_settings, record_blocked_script_execution, rollback_snapshot, save_claude_settings,
    scan_all_catalog_report, scan_claude_to_catalog, set_finding_triage,
    set_rule_severity_override, set_rule_suppression, skill_health_summary, toggle_skill,
    AdapterCapabilityRecord, AgentCatalogScanReport, BatchToggleApplyRecord,
    BatchTogglePreviewRecord, ConfigDocumentRecord, CrossAgentAnalysisRecord, ExportedSkillBundle,
    ScriptExecutionAttemptRecord, ScriptExecutionPreviewRecord, ScriptExecutionRequest,
    SkillHealthSummary, SkillInstallPreviewRecord, SnapshotRollbackPreviewRecord,
    ToolGlobalImportResult, SCRIPT_EXECUTION_DISABLED_REASON,
};
use skills_copilot_core::{AdapterContext, AdapterRoot, AgentId, RootSource, Scope};
use thiserror::Error;

mod project_context;

use project_context::{
    clear_project_context, context_from_paths, load_project_context_state, project_context_summary,
    set_project_context, stored_active_adapter_paths, validate_project_context_for_response,
    ProjectContext, ProjectContextParams, ProjectContextState, ProjectContextSummary,
};

const DEFAULT_BUNDLE_ID: &str = "dev.skills-copilot.native";
const SERVICE_PROTOCOL_VERSION: u32 = 1;
const SUPPORTED_METHODS: &[&str] = &[
    "app.version",
    "app.stateSnapshot",
    "service.status",
    "adapter.listCapabilities",
    "llm.status",
    "llm.prepareAction",
    "llm.prepareSkillAnalysis",
    "cleanup.listQueue",
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
    pub llm: LlmStatus,
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

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmSkillAnalysisKind {
    Overview,
    Risk,
    Cleanup,
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
            "llm.status" => serde_json::to_value(self.llm_status()).map_err(Into::into),
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
                let agent_summaries = self.agent_refresh_summaries(&scan_report.agents, &skills);
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
        ServiceStatus {
            protocol_version: SERVICE_PROTOCOL_VERSION,
            version: skills_copilot_commands::app_version(),
            app_data_dir: display_path(&self.app_data_dir),
            catalog_path: display_path(&self.catalog_path()),
            user_home: display_path(&self.adapter_ctx.user_home),
            supported_methods: supported_methods(),
            refresh: RefreshStatus {
                scan_progress: "summary-only",
                watcher_state: "manual-refresh",
                watcher_detail: "The current stdio sidecar reports completed refresh summaries; native automatic watcher events are not running in this process.",
                recovery_actions: vec!["Retry the last refresh", "Run Scan to rebuild the agent catalog"],
            },
            project_context: project_context_summary(&self.app_data_dir, self.env_project_context()),
            adapter_capabilities: list_adapter_capabilities(&self.adapter_ctx),
            llm: self.llm_status(),
            script_execution: self.script_execution_status(),
        }
    }

    pub fn llm_status(&self) -> LlmStatus {
        LlmStatus {
            enabled: false,
            configured: false,
            provider: None,
            model: None,
            reason: "LLM actions are disabled by default; no local provider is configured."
                .to_string(),
            single_request_token_limit: 8_000,
            monthly_budget_usd: 0.0,
            credentials_storage: "none".to_string(),
            credential_persistence_allowed: false,
        }
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

    fn tool_global_staging_root(&self) -> PathBuf {
        self.app_data_dir.join("tool-global")
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
    ) -> Vec<AgentRefreshSummary> {
        agent_reports
            .iter()
            .map(|agent_report| {
                let agent = agent_report.agent.as_str();
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

fn is_pi_plain_markdown_catalog_noise(skill: &SkillRecord) -> bool {
    skill.agent == AgentId::Pi.as_str()
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
    use skills_copilot_core::{AgentId, PermissionRequest, SkillInstance, SkillState};

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
        assert!(methods.contains(&Value::String("llm.status".to_string())));
        assert!(methods.contains(&Value::String("llm.prepareAction".to_string())));
        assert!(methods.contains(&Value::String("llm.prepareSkillAnalysis".to_string())));
        assert!(methods.contains(&Value::String("cleanup.listQueue".to_string())));
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
            "llm.status" => {
                let status: WireLlmStatus = decode_fixture_result(method, result, path);
                assert!(!status.enabled);
                assert!(!status.configured);
                assert!(!status.credential_persistence_allowed);
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
            "llm.prepareSkillAnalysis" => {
                json!({ "instance_ids": ["missing-skill"], "analysis_kind": "overview" })
            }
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
        script_execution: WireScriptExecutionStatus,
        adapter_capabilities: Vec<WireAdapterCapabilityRecord>,
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

    fn unique_suffix() -> u128 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos()
    }
}
