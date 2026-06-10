use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs, io,
    io::Write,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use fs4::FileExt;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use skills_copilot_adapters::{
    parse_codex_skill_config_entries, ClaudeCodeAdapter, CodexAdapter, HermesAdapter,
    OpenclawAdapter, OpencodeAdapter, PiAdapter,
};
use skills_copilot_ai_core::{evaluate_mvp_rules, Finding, RuleContext, RuleReport, Severity};
use skills_copilot_catalog::{
    Catalog, CatalogError, ConfigSnapshotDraft, ConfigSnapshotRecord, ConflictGroupDraft,
    ConflictGroupRecord, RuleFindingDraft, RuleFindingRecord, SkillDefinitionDraft,
    SkillDetailRecord, SkillEventDraft, SkillEventRecord, SkillInstanceMeta, SkillRecord,
};
use skills_copilot_core::{
    AdapterContext, AgentAdapter, AgentConfigAdapter, AgentConfigDocument, AgentId, ConfigFormat,
    NetworkAccess, PermissionRequest, Scope, SkillInstance, SkillState,
};
use skills_copilot_scanner::{scan_agent, ScannerError};
use thiserror::Error;

#[cfg(test)]
use skills_copilot_core::SkillScript;

pub fn app_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[derive(Debug, Error)]
pub enum CommandError {
    #[error("scanner error: {0}")]
    Scanner(#[from] ScannerError),
    #[error("catalog error: {0}")]
    Catalog(#[from] CatalogError),
    #[error("io error: {0}")]
    Io(#[from] io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("adapter error: {0}")]
    Adapter(String),
    #[error("skill instance not found: {0}")]
    InstanceNotFound(String),
    #[error("config snapshot not found: {0}")]
    SnapshotNotFound(String),
    #[error("scope not supported for toggle: {0:?}")]
    UnsupportedScope(Scope),
    #[error("config write verification failed; rolled back")]
    VerificationFailed,
    #[error("invalid json config: {0}")]
    InvalidJson(String),
    #[error("unsafe config path: {0}")]
    UnsafeConfigPath(String),
    #[error("invalid skill bundle: {0}")]
    InvalidSkillBundle(String),
    #[error("invalid skill source: {0}")]
    InvalidSkillSource(String),
    #[error("invalid import source: {0}")]
    InvalidImportSource(String),
    #[error("unsupported import source: {0}")]
    UnsupportedImportSource(String),
    #[error("install is not supported: {0}")]
    InstallUnsupported(String),
    #[error("invalid script execution request: {0}")]
    InvalidScriptExecutionRequest(String),
}

pub fn scan_claude_to_catalog(
    ctx: &AdapterContext,
    catalog: &Catalog,
) -> Result<usize, CommandError> {
    scan_single_agent_to_catalog(&ClaudeCodeAdapter, ctx, catalog)
}

#[derive(Debug, Clone)]
pub struct CatalogScanReport {
    pub scanned_count: usize,
    pub agents: Vec<AgentCatalogScanReport>,
}

#[derive(Debug, Clone)]
pub struct AgentCatalogScanReport {
    pub agent: AgentId,
    pub display_name: &'static str,
    pub scanned_count: usize,
    pub roots_considered: Vec<PathBuf>,
    pub scanned_roots: Vec<PathBuf>,
    pub skipped_roots: Vec<PathBuf>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AdapterCapabilityRecord {
    pub agent: &'static str,
    pub display_name: &'static str,
    pub status: &'static str,
    pub scan: AdapterFeatureCapability,
    pub project_scan: AdapterFeatureCapability,
    pub config_toggle: AdapterFeatureCapability,
    pub config_snapshot: AdapterFeatureCapability,
    pub install: AdapterFeatureCapability,
    pub writable: AdapterFeatureCapability,
    pub blockers: Vec<&'static str>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AdapterFeatureCapability {
    pub supported: bool,
    pub status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<&'static str>,
}

impl AdapterFeatureCapability {
    fn supported(status: &'static str) -> Self {
        Self {
            supported: true,
            status,
            reason: None,
        }
    }

    fn supported_with_reason(status: &'static str, reason: &'static str) -> Self {
        Self {
            supported: true,
            status,
            reason: Some(reason),
        }
    }

    fn blocked(status: &'static str, reason: &'static str) -> Self {
        Self {
            supported: false,
            status,
            reason: Some(reason),
        }
    }
}

pub fn scan_all_to_catalog(ctx: &AdapterContext, catalog: &Catalog) -> Result<usize, CommandError> {
    Ok(scan_all_catalog_report(ctx, catalog)?.scanned_count)
}

pub fn tool_global_staging_skills_root(app_data_dir: &Path) -> PathBuf {
    app_data_dir.join("tool-global").join("skills")
}

pub fn ensure_tool_global_staging_skills_root(
    app_data_dir: &Path,
) -> Result<PathBuf, CommandError> {
    let root = tool_global_staging_skills_root(app_data_dir);
    fs::create_dir_all(&root)?;
    Ok(root)
}

pub fn upsert_tool_global_staging_skill(
    catalog: &Catalog,
    ctx: &AdapterContext,
    app_data_dir: &Path,
    skill_path: &Path,
) -> Result<SkillRecord, CommandError> {
    let previous_fingerprints = catalog.instance_fingerprints()?;
    let root = tool_global_staging_skills_root(app_data_dir);
    let canonical_path = validate_tool_global_staging_skill_path(&root, skill_path)?;
    let mut instance = ClaudeCodeAdapter
        .parse(&canonical_path)
        .map_err(|err| CommandError::Adapter(err.message))?;
    instance.agent = AgentId::ToolGlobal;
    instance.scope = Scope::ToolGlobal;
    instance.project_root = None;
    instance.path = canonical_path.clone();
    instance.display_path = display_path_under_app_data(app_data_dir, &canonical_path);
    instance.id = stable_catalog_id(
        AgentId::ToolGlobal.as_str(),
        Scope::ToolGlobal.as_str(),
        &canonical_path,
    );
    instance.definition_id = canonical_definition_id(&instance.name);
    instance.fingerprint = content_fingerprint(&instance.frontmatter_raw, &instance.body);
    if let Ok(metadata) = fs::metadata(&canonical_path) {
        instance.mtime = metadata
            .modified()
            .ok()
            .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
            .map(|duration| duration.as_millis() as i64)
            .unwrap_or_default();
    }
    instance.first_seen = instance.mtime;
    instance.last_seen = instance.mtime;

    let id = instance.id.clone();
    catalog.upsert_skill_instance(&instance)?;
    refresh_catalog_rule_outputs(catalog, ctx, previous_fingerprints)?;
    catalog
        .get_skill_record(&id)?
        .ok_or(CommandError::InstanceNotFound(id))
}

fn validate_tool_global_staging_skill_path(
    staging_root: &Path,
    skill_path: &Path,
) -> Result<PathBuf, CommandError> {
    if skill_path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md") {
        return Err(CommandError::UnsafeConfigPath(format!(
            "tool-global staging path must point to SKILL.md: {}",
            skill_path.display()
        )));
    }
    reject_symlink(skill_path, "tool-global staging skill")?;
    let canonical_root = staging_root.canonicalize()?;
    let canonical_path = skill_path.canonicalize()?;
    if !canonical_path.starts_with(&canonical_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "tool-global staging skill {} resolves outside staging root {}",
            canonical_path.display(),
            canonical_root.display()
        )));
    }
    Ok(canonical_path)
}

fn display_path_under_app_data(app_data_dir: &Path, canonical_path: &Path) -> PathBuf {
    match app_data_dir.canonicalize() {
        Ok(canonical_app_data_dir) => canonical_path
            .strip_prefix(&canonical_app_data_dir)
            .map(|relative| PathBuf::from("$APP_DATA").join(relative))
            .unwrap_or_else(|_| canonical_path.to_path_buf()),
        Err(_) => canonical_path.to_path_buf(),
    }
}

fn stable_catalog_id(agent: &str, scope: &str, path: &Path) -> String {
    hash_string(&format!("{}|{}|{}", agent, scope, path.to_string_lossy()))
}

fn canonical_definition_id(name: &str) -> String {
    hash_string(&name.to_ascii_lowercase())
}

fn content_fingerprint(frontmatter: &str, body: &str) -> String {
    hash_string(&format!("{frontmatter}\n---\n{body}"))
}

fn hash_string(value: &str) -> String {
    let digest = Sha256::digest(value.as_bytes());
    format!("{digest:x}")
}

pub fn scan_all_catalog_report(
    ctx: &AdapterContext,
    catalog: &Catalog,
) -> Result<CatalogScanReport, CommandError> {
    let previous_fingerprints = catalog.instance_fingerprints()?;
    let mut scanned_count = 0;
    let mut agents = Vec::new();
    for adapter in supported_scan_adapters() {
        let roots_considered: Vec<PathBuf> = adapter
            .roots(ctx)
            .into_iter()
            .map(|root| root.path)
            .collect();
        let report = scan_agent_for_catalog(adapter.as_ref(), ctx)?;
        scanned_count += report.instances.len();
        let seen: Vec<(String, std::path::PathBuf)> = report
            .instances
            .iter()
            .map(|inst| (inst.scope.as_str().to_string(), inst.path.clone()))
            .collect();
        catalog.upsert_skill_instances(&report.instances)?;
        catalog.mark_missing_except_for_project_context(
            adapter.id().as_str(),
            ctx.project_root.as_deref(),
            &report.scanned_roots,
            &seen,
        )?;
        agents.push(AgentCatalogScanReport {
            agent: adapter.id(),
            display_name: adapter.display_name(),
            scanned_count: report.instances.len(),
            roots_considered,
            scanned_roots: report.scanned_roots.clone(),
            skipped_roots: report.skipped_roots.clone(),
        });
    }
    refresh_catalog_rule_outputs(catalog, ctx, previous_fingerprints)?;
    Ok(CatalogScanReport {
        scanned_count,
        agents,
    })
}

fn scan_single_agent_to_catalog(
    adapter: &dyn AgentAdapter,
    ctx: &AdapterContext,
    catalog: &Catalog,
) -> Result<usize, CommandError> {
    let previous_fingerprints = catalog.instance_fingerprints()?;
    let report = scan_agent_for_catalog(adapter, ctx)?;
    catalog.upsert_skill_instances(&report.instances)?;
    let seen: Vec<(String, std::path::PathBuf)> = report
        .instances
        .iter()
        .map(|inst| (inst.scope.as_str().to_string(), inst.path.clone()))
        .collect();
    catalog.mark_missing_except_for_project_context(
        adapter.id().as_str(),
        ctx.project_root.as_deref(),
        &report.scanned_roots,
        &seen,
    )?;
    refresh_catalog_rule_outputs(catalog, ctx, previous_fingerprints)?;
    Ok(report.instances.len())
}

fn scan_agent_for_catalog(
    adapter: &dyn AgentAdapter,
    ctx: &AdapterContext,
) -> Result<skills_copilot_scanner::ScanReport, CommandError> {
    let mut report = scan_agent(adapter, ctx)?;
    if adapter.id() == AgentId::Codex {
        apply_codex_config_overrides(ctx, &mut report.instances)?;
    }
    Ok(report)
}

fn supported_scan_adapters() -> Vec<Box<dyn AgentAdapter>> {
    vec![
        Box::new(ClaudeCodeAdapter),
        Box::new(CodexAdapter),
        Box::new(OpencodeAdapter),
        Box::new(PiAdapter),
        Box::new(OpenclawAdapter),
        Box::new(HermesAdapter),
    ]
}

pub fn list_adapter_capabilities(_ctx: &AdapterContext) -> Vec<AdapterCapabilityRecord> {
    vec![
        AdapterCapabilityRecord {
            agent: AgentId::ClaudeCode.as_str(),
            display_name: "Claude Code",
            status: "verified",
            scan: AdapterFeatureCapability::supported("verified"),
            project_scan: AdapterFeatureCapability::supported("verified"),
            config_toggle: AdapterFeatureCapability::supported("verified"),
            config_snapshot: AdapterFeatureCapability::supported("verified"),
            install: AdapterFeatureCapability::supported("verified"),
            writable: AdapterFeatureCapability::supported("verified"),
            blockers: Vec::new(),
        },
        AdapterCapabilityRecord {
            agent: AgentId::Codex.as_str(),
            display_name: "Codex",
            status: "verified",
            scan: AdapterFeatureCapability::supported("verified"),
            project_scan: AdapterFeatureCapability::supported("verified"),
            config_toggle: AdapterFeatureCapability::supported_with_reason(
                "verified-user-config",
                "Project skill toggles write only the user config.toml override; project-local .codex/config.toml remains blocked.",
            ),
            config_snapshot: AdapterFeatureCapability::supported("verified"),
            install: AdapterFeatureCapability::supported("verified"),
            writable: AdapterFeatureCapability::supported_with_reason(
                "verified-user-config",
                "Codex writes are limited to verified user config and skill roots.",
            ),
            blockers: vec!["Project-local .codex/config.toml toggle semantics remain unverified."],
        },
        AdapterCapabilityRecord {
            agent: AgentId::Opencode.as_str(),
            display_name: "opencode",
            status: "verified",
            scan: AdapterFeatureCapability::supported("verified"),
            project_scan: AdapterFeatureCapability::supported("verified"),
            config_toggle: AdapterFeatureCapability::supported_with_reason(
                "verified-exact-skill-deny",
                "V2.12 writes exact permission.skill.<name> = deny and re-enables by removing that exact deny without changing wildcard rules.",
            ),
            config_snapshot: AdapterFeatureCapability::supported_with_reason(
                "verified",
                "opencode global/project opencode.json writes use the same snapshot, atomic write, verify, and rollback path as other writable adapters.",
            ),
            install: AdapterFeatureCapability::supported_with_reason(
                "verified",
                "Tool-global skills can be installed to native opencode user/project skill roots after confirmation; compatibility roots are scanned but not install targets.",
            ),
            writable: AdapterFeatureCapability::supported_with_reason(
                "verified",
                "Writable support uses managed exact skill permission overrides; file installs stay limited to native opencode roots.",
            ),
            blockers: Vec::new(),
        },
        AdapterCapabilityRecord {
            agent: AgentId::Pi.as_str(),
            display_name: "Pi",
            status: "read-only",
            scan: AdapterFeatureCapability::supported_with_reason(
                "verified-read-only",
                "V2.13 scans Pi-native global ~/.pi/agent/skills and project .pi/skills roots without reading or writing Pi settings.",
            ),
            project_scan: AdapterFeatureCapability::supported_with_reason(
                "verified-read-only",
                "Project scan walks .pi/skills from cwd up to the selected project root; .agents compatibility roots remain out of scope to avoid duplicate records.",
            ),
            config_toggle: AdapterFeatureCapability::blocked(
                "blocked",
                "Pi enable/disable JSON mutation and rollback semantics are not verified.",
            ),
            config_snapshot: AdapterFeatureCapability::blocked(
                "blocked",
                "No verified Pi config write target is available yet.",
            ),
            install: AdapterFeatureCapability::blocked(
                "blocked",
                "Pi install target roots are not enabled until writable evidence is complete.",
            ),
            writable: AdapterFeatureCapability::blocked(
                "blocked",
                "Pi writes are blocked until the disposable local round-trip is complete.",
            ),
            blockers: vec![
                "Verify Pi settings schema and enable/disable semantics.",
                "Verify rollback-safe global/project config writes.",
            ],
        },
        AdapterCapabilityRecord {
            agent: AgentId::Hermes.as_str(),
            display_name: "Hermes",
            status: "read-only",
            scan: AdapterFeatureCapability::supported_with_reason(
                "verified-read-only",
                "V2.17 scans active Hermes home ~/.hermes/skills/**/SKILL.md without reading Hermes secrets, cron content, logs, or config files.",
            ),
            project_scan: AdapterFeatureCapability::blocked(
                "blocked",
                "Hermes has no generic project-local skill discovery; project scan remains disabled unless explicit external_dirs policy is implemented.",
            ),
            config_toggle: AdapterFeatureCapability::blocked(
                "blocked",
                "Hermes toggle semantics and config schema are not confirmed.",
            ),
            config_snapshot: AdapterFeatureCapability::blocked(
                "blocked",
                "No verified Hermes rollback-safe config target exists.",
            ),
            install: AdapterFeatureCapability::blocked(
                "blocked",
                "Hermes install semantics are not confirmed.",
            ),
            writable: AdapterFeatureCapability::blocked(
                "blocked",
                "Hermes writable toggle/install remains blocked until individual skill disable schema and rollback-safe writes are verified.",
            ),
            blockers: vec![
                "Generic Hermes project-local skill discovery is not confirmed and remains disabled.",
                "Confirm individual skill disable/re-enable schema and rollback semantics before writable support.",
                "Do not map Hermes cron jobs to SkillInstance in the first adapter slice.",
            ],
        },
        AdapterCapabilityRecord {
            agent: AgentId::Openclaw.as_str(),
            display_name: "OpenClaw",
            status: "read-only",
            scan: AdapterFeatureCapability::supported_with_reason(
                "verified-read-only",
                "V2.16 scans documented OpenClaw filesystem roots without calling the OpenClaw CLI.",
            ),
            project_scan: AdapterFeatureCapability::supported_with_reason(
                "verified-read-only",
                "Project scan is limited to confirmed OpenClaw home workspace roots and only reads <workspace>/skills plus <workspace>/.agents/skills.",
            ),
            config_toggle: AdapterFeatureCapability::blocked(
                "blocked",
                "OpenClaw plugin config evidence is not a verified skill toggle contract.",
            ),
            config_snapshot: AdapterFeatureCapability::blocked(
                "blocked",
                "No verified OpenClaw rollback-safe skill config target exists.",
            ),
            install: AdapterFeatureCapability::blocked(
                "blocked",
                "OpenClaw install semantics are not confirmed.",
            ),
            writable: AdapterFeatureCapability::blocked(
                "blocked",
                "OpenClaw writable toggle/install remains blocked until disposable config mutation and credential-safe rollback are verified.",
            ),
            blockers: vec![
                "Arbitrary repository roots are not OpenClaw projects and are not scanned as project roots.",
                "Verify config mutation, credential preservation, and rollback before writable/install support.",
            ],
        },
    ]
}

pub fn get_skill(catalog: &Catalog, instance_id: &str) -> Result<SkillDetailRecord, CommandError> {
    catalog
        .get_skill_detail(instance_id)?
        .ok_or_else(|| CommandError::InstanceNotFound(instance_id.to_string()))
}

pub const SCRIPT_EXECUTION_DISABLED_REASON: &str =
    "Script execution is disabled by default; the service will not spawn a process.";

#[derive(Debug, Clone, Copy, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ScriptExecutionInitiator {
    User,
    Llm,
}

impl ScriptExecutionInitiator {
    fn as_str(self) -> &'static str {
        match self {
            Self::User => "user",
            Self::Llm => "llm",
        }
    }
}

fn default_script_execution_initiator() -> ScriptExecutionInitiator {
    ScriptExecutionInitiator::User
}

#[derive(Debug, Clone, Deserialize)]
pub struct ScriptExecutionRequest {
    pub command: Vec<String>,
    #[serde(default)]
    pub cwd: Option<PathBuf>,
    #[serde(default)]
    pub env: BTreeMap<String, String>,
    #[serde(default)]
    pub network: Option<String>,
    #[serde(default)]
    pub files: Vec<String>,
    #[serde(default)]
    pub skill_instance_id: Option<String>,
    #[serde(default = "default_script_execution_initiator")]
    pub initiated_by: ScriptExecutionInitiator,
    #[serde(default)]
    pub confirmed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionPreviewRecord {
    pub skill_instance_id: Option<String>,
    pub initiated_by: String,
    pub initiator_allowed: bool,
    pub cwd: ScriptExecutionCwdScope,
    pub env: ScriptExecutionEnvScope,
    pub network: ScriptExecutionNetworkScope,
    pub files: ScriptExecutionFilesScope,
    pub command_preview: ScriptExecutionCommandPreview,
    pub risks: Vec<String>,
    pub confirmation: ScriptExecutionConfirmation,
    pub execution_allowed: bool,
    pub disabled_reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionCwdScope {
    pub requested: Option<String>,
    pub effective: String,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionEnvScope {
    pub inherit_parent: bool,
    pub provided_keys: Vec<String>,
    pub redacted_keys: Vec<String>,
    pub value_policy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionNetworkScope {
    pub requested: String,
    pub allowed: bool,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionFilesScope {
    pub requested: Vec<String>,
    pub read_allowed: bool,
    pub write_allowed: bool,
    pub allowed_roots: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionCommandPreview {
    pub argv: Vec<String>,
    pub display: String,
    pub shell: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionConfirmation {
    pub required: bool,
    pub confirmed: bool,
    pub fields: Vec<String>,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ScriptExecutionAttemptRecord {
    pub id: String,
    pub created_at: i64,
    pub status: String,
    pub outcome: String,
    pub reason: String,
    pub spawned_process: bool,
    pub audit_path: String,
    pub preview: ScriptExecutionPreviewRecord,
}

pub fn preview_script_execution(
    ctx: &AdapterContext,
    request: &ScriptExecutionRequest,
) -> Result<ScriptExecutionPreviewRecord, CommandError> {
    if request.command.is_empty() {
        return Err(CommandError::InvalidScriptExecutionRequest(
            "script execution preview requires a non-empty command argv".to_string(),
        ));
    }

    let (effective_cwd, cwd_source) = effective_script_cwd(ctx, request.cwd.as_deref());
    let provided_keys: Vec<String> = request.env.keys().cloned().collect();
    let requested_network = request
        .network
        .as_deref()
        .filter(|network| !network.trim().is_empty())
        .unwrap_or("none")
        .to_string();
    let initiator_allowed = request.initiated_by != ScriptExecutionInitiator::Llm;
    let mut risks = vec![SCRIPT_EXECUTION_DISABLED_REASON.to_string()];
    if !initiator_allowed {
        risks.push("LLM-initiated script execution is rejected by the service.".to_string());
    }
    if requested_network != "none" {
        risks.push(
            "Network access was requested but is unavailable while execution is disabled."
                .to_string(),
        );
    }
    if !request.files.is_empty() {
        risks.push("File access was requested but no read or write roots are granted.".to_string());
    }
    if !provided_keys.is_empty() {
        risks.push("Environment values are accepted only for preview and audit metadata; values are redacted.".to_string());
    }

    Ok(ScriptExecutionPreviewRecord {
        skill_instance_id: request.skill_instance_id.clone(),
        initiated_by: request.initiated_by.as_str().to_string(),
        initiator_allowed,
        cwd: ScriptExecutionCwdScope {
            requested: request
                .cwd
                .as_ref()
                .map(|path| path.to_string_lossy().to_string()),
            effective: effective_cwd.to_string_lossy().to_string(),
            source: cwd_source.to_string(),
        },
        env: ScriptExecutionEnvScope {
            inherit_parent: false,
            redacted_keys: provided_keys.clone(),
            provided_keys,
            value_policy: "values-redacted".to_string(),
        },
        network: ScriptExecutionNetworkScope {
            requested: requested_network,
            allowed: false,
            reason: "Network access is not granted because script execution is disabled."
                .to_string(),
        },
        files: ScriptExecutionFilesScope {
            requested: request.files.clone(),
            read_allowed: false,
            write_allowed: false,
            allowed_roots: Vec::new(),
        },
        command_preview: ScriptExecutionCommandPreview {
            argv: request.command.clone(),
            display: display_argv(&request.command),
            shell: None,
        },
        risks,
        confirmation: ScriptExecutionConfirmation {
            required: true,
            confirmed: request.confirmed,
            fields: vec![
                "command_preview".to_string(),
                "cwd".to_string(),
                "env.provided_keys".to_string(),
                "network".to_string(),
                "files".to_string(),
                "initiated_by".to_string(),
            ],
            message: "Per-request user confirmation is required before any execution attempt."
                .to_string(),
        },
        execution_allowed: false,
        disabled_reason: SCRIPT_EXECUTION_DISABLED_REASON.to_string(),
    })
}

pub fn record_blocked_script_execution(
    ctx: &AdapterContext,
    audit_path: &Path,
    request: &ScriptExecutionRequest,
) -> Result<ScriptExecutionAttemptRecord, CommandError> {
    let preview = preview_script_execution(ctx, request)?;
    let created_at = current_time_ms();
    let outcome = if request.initiated_by == ScriptExecutionInitiator::Llm {
        "llm_initiator_not_allowed"
    } else {
        "execution_disabled"
    };
    let reason = if request.initiated_by == ScriptExecutionInitiator::Llm {
        "LLM-initiated execution is not allowed; no process was spawned."
    } else {
        SCRIPT_EXECUTION_DISABLED_REASON
    };
    let record = ScriptExecutionAttemptRecord {
        id: format!("script-exec-{created_at}"),
        created_at,
        status: "blocked".to_string(),
        outcome: outcome.to_string(),
        reason: reason.to_string(),
        spawned_process: false,
        audit_path: audit_path.to_string_lossy().to_string(),
        preview,
    };
    if let Some(parent) = audit_path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut audit_file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(audit_path)?;
    let line = serde_json::to_string(&record)?;
    writeln!(audit_file, "{line}")?;
    Ok(record)
}

fn effective_script_cwd(ctx: &AdapterContext, requested: Option<&Path>) -> (PathBuf, &'static str) {
    if let Some(path) = requested {
        if path.is_absolute() {
            return (path.to_path_buf(), "request");
        }
        let base = ctx
            .project_cwd
            .as_deref()
            .or(ctx.project_root.as_deref())
            .map(Path::to_path_buf)
            .or_else(|| env::current_dir().ok())
            .unwrap_or_else(|| PathBuf::from("."));
        return (base.join(path), "request-relative");
    }
    if let Some(path) = &ctx.project_cwd {
        return (path.clone(), "project_cwd");
    }
    if let Some(path) = &ctx.project_root {
        return (path.clone(), "project_root");
    }
    (
        env::current_dir().unwrap_or_else(|_| PathBuf::from(".")),
        "process_cwd",
    )
}

fn display_argv(argv: &[String]) -> String {
    argv.iter()
        .map(|part| {
            if part.is_empty()
                || part
                    .chars()
                    .any(|ch| ch.is_whitespace() || matches!(ch, '\'' | '"' | '\\' | '$' | '`'))
            {
                format!("'{}'", part.replace('\'', "'\\''"))
            } else {
                part.clone()
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn list_findings(catalog: &Catalog) -> Result<Vec<RuleFindingRecord>, CommandError> {
    Ok(dedupe_rule_finding_records(&catalog.list_rule_findings()?))
}

pub fn list_conflicts(catalog: &Catalog) -> Result<Vec<ConflictGroupRecord>, CommandError> {
    Ok(catalog.list_conflict_groups()?)
}

pub fn analyze_catalog(
    catalog: &Catalog,
    ctx: &AdapterContext,
) -> Result<CrossAgentAnalysisRecord, CommandError> {
    let instances = visible_catalog_instances(
        catalog.list_skill_instances_for_project_context(ctx.project_root.as_deref())?,
    );
    Ok(analyze_skill_instances(&instances))
}

pub fn skill_health_summary(
    catalog: &Catalog,
    ctx: &AdapterContext,
) -> Result<SkillHealthSummary, CommandError> {
    let instances = visible_catalog_instances(
        catalog.list_skill_instances_for_project_context(ctx.project_root.as_deref())?,
    );
    let findings = catalog.list_rule_findings()?;
    let conflicts = catalog.list_conflict_groups()?;
    let analysis = analyze_skill_instances(&instances);
    Ok(build_skill_health_summary(
        &instances, &findings, &conflicts, &analysis,
    ))
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CrossAgentAnalysisRecord {
    pub summary: CrossAgentAnalysisSummary,
    pub groups: Vec<CrossAgentAnalysisGroup>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CrossAgentAnalysisSummary {
    pub total_groups: usize,
    pub duplicate_name_groups: usize,
    pub canonical_name_groups: usize,
    pub path_overlap_groups: usize,
    pub enabled_mismatch_groups: usize,
    pub malformed_groups: usize,
    pub precedence_groups: usize,
    pub affected_skill_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CrossAgentAnalysisGroup {
    pub id: String,
    pub kind: String,
    pub severity: String,
    pub title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub canonical_name: Option<String>,
    pub explanation: String,
    pub instance_ids: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub winner_id: Option<String>,
    pub agents: Vec<String>,
    pub scopes: Vec<String>,
    pub paths: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SkillHealthSummary {
    pub total_count: usize,
    pub enabled_count: usize,
    pub disabled_count: usize,
    pub broken_count: usize,
    pub missing_count: usize,
    pub malformed_count: usize,
    pub finding_count: usize,
    pub conflict_count: usize,
    pub risky_script_count: usize,
    pub risky_permission_count: usize,
    pub findings_by_severity: HealthSeverityCounts,
    pub analysis_groups: HealthAnalysisGroupCounts,
    pub agent_summaries: Vec<AgentSkillHealthSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct HealthSeverityCounts {
    pub error_count: usize,
    pub warning_count: usize,
    pub info_count: usize,
}

impl HealthSeverityCounts {
    fn total(&self) -> usize {
        self.error_count + self.warning_count + self.info_count
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HealthAnalysisGroupCounts {
    pub total_count: usize,
    pub error_count: usize,
    pub warning_count: usize,
    pub info_count: usize,
    pub duplicate_name_count: usize,
    pub canonical_name_count: usize,
    pub path_overlap_count: usize,
    pub enabled_mismatch_count: usize,
    pub malformed_count: usize,
    pub precedence_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentSkillHealthSummary {
    pub agent: String,
    pub total_count: usize,
    pub enabled_count: usize,
    pub disabled_count: usize,
    pub broken_count: usize,
    pub missing_count: usize,
    pub malformed_count: usize,
    pub finding_count: usize,
    pub conflict_count: usize,
    pub risky_script_count: usize,
    pub risky_permission_count: usize,
    pub analysis_group_count: usize,
}

pub fn build_skill_health_summary(
    instances: &[SkillInstance],
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    analysis: &CrossAgentAnalysisRecord,
) -> SkillHealthSummary {
    let findings = dedupe_rule_finding_records(findings);
    let agent_by_instance_id = instances
        .iter()
        .map(|inst| (inst.id.as_str(), inst.agent.as_str()))
        .collect::<BTreeMap<_, _>>();
    let malformed_instance_ids = malformed_instance_ids(instances, &findings);
    let risky_script_instance_ids = risky_script_instance_ids(instances, &findings);
    let risky_permission_instance_ids = risky_permission_instance_ids(instances, &findings);
    let findings_by_severity =
        severity_counts(findings.iter().map(|finding| finding.severity.as_str()));
    let analysis_groups = health_analysis_group_counts(analysis);

    let mut agent_summaries = Vec::new();
    for agent in instances
        .iter()
        .map(|inst| inst.agent.as_str().to_string())
        .collect::<BTreeSet<_>>()
    {
        let members = instances
            .iter()
            .filter(|inst| inst.agent.as_str() == agent)
            .collect::<Vec<_>>();
        let member_ids = members
            .iter()
            .map(|inst| inst.id.as_str())
            .collect::<BTreeSet<_>>();
        let finding_count = findings
            .iter()
            .filter(|finding| finding_applies_to(&member_ids, finding))
            .count();
        let conflict_count = conflicts
            .iter()
            .filter(|conflict| conflict_applies_to_agent_instances(&member_ids, conflict))
            .count();
        let analysis_group_count = analysis
            .groups
            .iter()
            .filter(|group| group.agents.iter().any(|group_agent| group_agent == &agent))
            .count();

        agent_summaries.push(AgentSkillHealthSummary {
            agent: agent.clone(),
            total_count: members.len(),
            enabled_count: members
                .iter()
                .filter(|inst| is_health_enabled(inst))
                .count(),
            disabled_count: members
                .iter()
                .filter(|inst| is_health_disabled(inst))
                .count(),
            broken_count: members
                .iter()
                .filter(|inst| matches!(inst.state, SkillState::Broken))
                .count(),
            missing_count: members
                .iter()
                .filter(|inst| matches!(inst.state, SkillState::Missing))
                .count(),
            malformed_count: member_ids
                .iter()
                .filter(|id| malformed_instance_ids.contains(**id))
                .count(),
            finding_count,
            conflict_count,
            risky_script_count: member_ids
                .iter()
                .filter(|id| risky_script_instance_ids.contains(**id))
                .count(),
            risky_permission_count: member_ids
                .iter()
                .filter(|id| risky_permission_instance_ids.contains(**id))
                .count(),
            analysis_group_count,
        });
    }

    SkillHealthSummary {
        total_count: instances.len(),
        enabled_count: instances
            .iter()
            .filter(|inst| is_health_enabled(inst))
            .count(),
        disabled_count: instances
            .iter()
            .filter(|inst| is_health_disabled(inst))
            .count(),
        broken_count: instances
            .iter()
            .filter(|inst| matches!(inst.state, SkillState::Broken))
            .count(),
        missing_count: instances
            .iter()
            .filter(|inst| matches!(inst.state, SkillState::Missing))
            .count(),
        malformed_count: malformed_instance_ids.len(),
        finding_count: findings_by_severity.total(),
        conflict_count: conflicts
            .iter()
            .filter(|conflict| conflict_has_same_agent_instances(&agent_by_instance_id, conflict))
            .count(),
        risky_script_count: risky_script_instance_ids.len(),
        risky_permission_count: risky_permission_instance_ids.len(),
        findings_by_severity,
        analysis_groups,
        agent_summaries,
    }
}

pub fn analyze_skill_instances(instances: &[SkillInstance]) -> CrossAgentAnalysisRecord {
    let mut groups = Vec::new();

    append_duplicate_name_groups(instances, &mut groups);
    append_canonical_name_groups(instances, &mut groups);
    append_path_overlap_groups(instances, &mut groups);
    append_enabled_mismatch_groups(instances, &mut groups);
    append_malformed_groups(instances, &mut groups);
    append_precedence_groups(instances, &mut groups);

    groups.sort_by(|left, right| {
        severity_rank(&left.severity)
            .cmp(&severity_rank(&right.severity))
            .then_with(|| left.kind.cmp(&right.kind))
            .then_with(|| left.title.cmp(&right.title))
    });

    let affected_skill_count = groups
        .iter()
        .flat_map(|group| group.instance_ids.iter().cloned())
        .collect::<BTreeSet<_>>()
        .len();

    CrossAgentAnalysisRecord {
        summary: CrossAgentAnalysisSummary {
            total_groups: groups.len(),
            duplicate_name_groups: count_kind(&groups, "duplicate_name"),
            canonical_name_groups: count_kind(&groups, "canonical_name_overlap"),
            path_overlap_groups: count_kind(&groups, "source_path_overlap"),
            enabled_mismatch_groups: count_kind(&groups, "enabled_state_mismatch"),
            malformed_groups: count_kind(&groups, "malformed_or_broken"),
            precedence_groups: count_kind(&groups, "precedence_shadowing"),
            affected_skill_count,
        },
        groups,
    }
}

fn is_health_enabled(inst: &SkillInstance) -> bool {
    inst.enabled && matches!(inst.state, SkillState::Loaded)
}

fn is_health_disabled(inst: &SkillInstance) -> bool {
    !inst.enabled || matches!(inst.state, SkillState::Disabled)
}

fn malformed_instance_ids(
    instances: &[SkillInstance],
    findings: &[RuleFindingRecord],
) -> BTreeSet<String> {
    let mut ids = instances
        .iter()
        .filter(|inst| matches!(inst.state, SkillState::Broken | SkillState::Missing))
        .map(|inst| inst.id.clone())
        .collect::<BTreeSet<_>>();
    add_finding_affected_instances(
        findings
            .iter()
            .filter(|finding| finding.rule_id == "frontmatter.required-fields"),
        instances,
        &mut ids,
    );
    ids
}

fn risky_script_instance_ids(
    instances: &[SkillInstance],
    findings: &[RuleFindingRecord],
) -> BTreeSet<String> {
    let mut ids = instances
        .iter()
        .filter(|inst| !inst.scripts.is_empty())
        .map(|inst| inst.id.clone())
        .collect::<BTreeSet<_>>();
    add_finding_affected_instances(
        findings
            .iter()
            .filter(|finding| finding.rule_id.starts_with("script.")),
        instances,
        &mut ids,
    );
    ids
}

fn risky_permission_instance_ids(
    instances: &[SkillInstance],
    findings: &[RuleFindingRecord],
) -> BTreeSet<String> {
    let mut ids = instances
        .iter()
        .filter(|inst| {
            inst.permissions.exec
                || !matches!(inst.permissions.network, NetworkAccess::None)
                || !inst.permissions.tools.is_empty()
        })
        .map(|inst| inst.id.clone())
        .collect::<BTreeSet<_>>();
    add_finding_affected_instances(
        findings.iter().filter(|finding| {
            matches!(
                finding.rule_id.as_str(),
                "frontmatter.tools-not-empty"
                    | "permissions.network-declared"
                    | "permissions.exec-needs-human"
                    | "dependency.unknown"
            )
        }),
        instances,
        &mut ids,
    );
    ids
}

fn add_finding_affected_instances<'a>(
    findings: impl Iterator<Item = &'a RuleFindingRecord>,
    instances: &[SkillInstance],
    ids: &mut BTreeSet<String>,
) {
    for finding in findings {
        if let Some(instance_id) = &finding.instance_id {
            ids.insert(instance_id.clone());
        }
        if let Some(definition_id) = &finding.definition_id {
            ids.extend(
                instances
                    .iter()
                    .filter(|inst| &inst.definition_id == definition_id)
                    .map(|inst| inst.id.clone()),
            );
        }
    }
}

fn severity_counts<'a>(severities: impl Iterator<Item = &'a str>) -> HealthSeverityCounts {
    let mut counts = HealthSeverityCounts::default();
    for severity in severities {
        match severity {
            "error" => counts.error_count += 1,
            "warn" | "warning" => counts.warning_count += 1,
            "info" => counts.info_count += 1,
            _ => counts.info_count += 1,
        }
    }
    counts
}

fn dedupe_rule_finding_records(findings: &[RuleFindingRecord]) -> Vec<RuleFindingRecord> {
    let mut seen = BTreeSet::new();
    let mut deduped = Vec::new();
    for finding in findings {
        if seen.insert(rule_finding_record_key(finding)) {
            deduped.push(finding.clone());
        }
    }
    deduped
}

fn rule_finding_record_key(finding: &RuleFindingRecord) -> String {
    stable_finding_key(
        finding.instance_id.as_deref(),
        finding.definition_id.as_deref(),
        &finding.rule_id,
        &finding.message,
        finding.suggestion.as_deref(),
    )
}

fn dedupe_rule_findings(findings: Vec<Finding>) -> Vec<Finding> {
    let mut seen = BTreeSet::new();
    let mut deduped = Vec::new();
    for finding in findings {
        if seen.insert(finding_key(&finding)) {
            deduped.push(finding);
        }
    }
    deduped
}

fn finding_key(finding: &Finding) -> String {
    stable_finding_key(
        finding.instance_id.as_deref(),
        finding.definition_id.as_deref(),
        &finding.rule_id,
        &finding.message,
        finding.suggestion.as_deref(),
    )
}

fn stable_finding_key(
    instance_id: Option<&str>,
    definition_id: Option<&str>,
    rule_id: &str,
    message: &str,
    suggestion: Option<&str>,
) -> String {
    format!(
        "{}\x1f{}\x1f{}\x1f{}\x1f{}",
        instance_id.unwrap_or(""),
        definition_id.unwrap_or(""),
        rule_id,
        message,
        suggestion.unwrap_or("")
    )
}

fn health_analysis_group_counts(analysis: &CrossAgentAnalysisRecord) -> HealthAnalysisGroupCounts {
    let severity = severity_counts(analysis.groups.iter().map(|group| group.severity.as_str()));
    HealthAnalysisGroupCounts {
        total_count: analysis.summary.total_groups,
        error_count: severity.error_count,
        warning_count: severity.warning_count,
        info_count: severity.info_count,
        duplicate_name_count: analysis.summary.duplicate_name_groups,
        canonical_name_count: analysis.summary.canonical_name_groups,
        path_overlap_count: analysis.summary.path_overlap_groups,
        enabled_mismatch_count: analysis.summary.enabled_mismatch_groups,
        malformed_count: analysis.summary.malformed_groups,
        precedence_count: analysis.summary.precedence_groups,
    }
}

fn finding_applies_to(instance_ids: &BTreeSet<&str>, finding: &RuleFindingRecord) -> bool {
    finding
        .instance_id
        .as_deref()
        .is_some_and(|instance_id| instance_ids.contains(instance_id))
}

fn conflict_applies_to_agent_instances(
    instance_ids: &BTreeSet<&str>,
    conflict: &ConflictGroupRecord,
) -> bool {
    conflict
        .instance_ids
        .iter()
        .filter(|instance_id| instance_ids.contains(instance_id.as_str()))
        .count()
        > 1
}

fn conflict_has_same_agent_instances(
    agent_by_instance_id: &BTreeMap<&str, &str>,
    conflict: &ConflictGroupRecord,
) -> bool {
    let mut counts_by_agent = BTreeMap::new();
    for instance_id in &conflict.instance_ids {
        if let Some(agent) = agent_by_instance_id.get(instance_id.as_str()) {
            let count = counts_by_agent.entry(*agent).or_insert(0usize);
            *count += 1;
            if *count > 1 {
                return true;
            }
        }
    }
    false
}

fn append_duplicate_name_groups(
    instances: &[SkillInstance],
    groups: &mut Vec<CrossAgentAnalysisGroup>,
) {
    let mut by_name: BTreeMap<String, Vec<&SkillInstance>> = BTreeMap::new();
    for inst in instances {
        by_name
            .entry(inst.name.trim().to_ascii_lowercase())
            .or_default()
            .push(inst);
    }
    for (name, members) in by_name {
        if members.len() < 2 {
            continue;
        }
        groups.push(analysis_group(
            "duplicate_name",
            "warning",
            format!("Duplicate skill name '{name}' appears in {} records.", members.len()),
            Some(name.clone()),
            "Multiple visible skills use the same name. Agents load independently, so this is not automatically a runtime conflict across agents, but users may see ambiguous skills in the catalog.".to_string(),
            members,
            None,
        ));
    }
}

fn append_canonical_name_groups(
    instances: &[SkillInstance],
    groups: &mut Vec<CrossAgentAnalysisGroup>,
) {
    let mut by_canonical: BTreeMap<String, Vec<&SkillInstance>> = BTreeMap::new();
    for inst in instances {
        by_canonical
            .entry(canonical_skill_name_suggestion(&inst.name))
            .or_default()
            .push(inst);
    }
    for (canonical_name, members) in by_canonical {
        if members.len() < 2 {
            continue;
        }
        let distinct_names = members
            .iter()
            .map(|inst| inst.name.trim().to_ascii_lowercase())
            .collect::<BTreeSet<_>>();
        if distinct_names.len() < 2 {
            continue;
        }
        groups.push(analysis_group(
            "canonical_name_overlap",
            "info",
            format!(
                "Canonical name '{canonical_name}' maps to {} visible spelling variants.",
                distinct_names.len()
            ),
            Some(canonical_name),
            "These skills are not exact duplicates, but their names normalize to the same canonical slug. Review them together before renaming, exporting, or installing shared copies.".to_string(),
            members,
            None,
        ));
    }
}

fn append_path_overlap_groups(
    instances: &[SkillInstance],
    groups: &mut Vec<CrossAgentAnalysisGroup>,
) {
    let mut by_path: BTreeMap<String, Vec<&SkillInstance>> = BTreeMap::new();
    for inst in instances {
        by_path
            .entry(inst.path.to_string_lossy().to_string())
            .or_default()
            .push(inst);
    }
    for (path, members) in by_path {
        if members.len() < 2 {
            continue;
        }
        groups.push(analysis_group(
            "source_path_overlap",
            "warning",
            format!("Same SKILL.md source is cataloged by {} records.", members.len()),
            None,
            format!(
                "The same physical skill path is visible through multiple catalog rows: {path}. Treat edits to this file as shared-source changes even though this analysis does not write files."
            ),
            members,
            None,
        ));
    }
}

fn append_enabled_mismatch_groups(
    instances: &[SkillInstance],
    groups: &mut Vec<CrossAgentAnalysisGroup>,
) {
    let mut by_canonical: BTreeMap<String, Vec<&SkillInstance>> = BTreeMap::new();
    for inst in instances {
        by_canonical
            .entry(canonical_skill_name_suggestion(&inst.name))
            .or_default()
            .push(inst);
    }
    for (canonical_name, members) in by_canonical {
        if members.len() < 2 {
            continue;
        }
        let enabled_values = members
            .iter()
            .map(|inst| inst.enabled)
            .collect::<BTreeSet<_>>();
        let state_values = members
            .iter()
            .map(|inst| inst.state.as_str())
            .collect::<BTreeSet<_>>();
        if enabled_values.len() < 2 && state_values.len() < 2 {
            continue;
        }
        groups.push(analysis_group(
            "enabled_state_mismatch",
            "warning",
            format!("Canonical name '{canonical_name}' has mixed enabled or load states."),
            Some(canonical_name),
            "Some visible records are enabled/loaded while related records are disabled, shadowed, missing, or broken. This is read-only catalog evidence; use adapter capability blockers before attempting any config action.".to_string(),
            members,
            None,
        ));
    }
}

fn append_malformed_groups(instances: &[SkillInstance], groups: &mut Vec<CrossAgentAnalysisGroup>) {
    let members: Vec<&SkillInstance> = instances
        .iter()
        .filter(|inst| matches!(inst.state, SkillState::Broken | SkillState::Missing))
        .collect();
    if members.is_empty() {
        return;
    }
    groups.push(analysis_group(
        "malformed_or_broken",
        "error",
        format!(
            "{} visible skill record(s) are broken, malformed, or missing.",
            members.len()
        ),
        None,
        "Broken rows usually come from parser/frontmatter failures; missing rows are retained catalog records from previously scanned roots. Rescan or inspect the source before relying on these skills.".to_string(),
        members,
        None,
    ));
}

fn append_precedence_groups(
    instances: &[SkillInstance],
    groups: &mut Vec<CrossAgentAnalysisGroup>,
) {
    let mut by_agent_and_name: BTreeMap<(String, String), Vec<&SkillInstance>> = BTreeMap::new();
    for inst in instances {
        if inst.agent == AgentId::ToolGlobal {
            continue;
        }
        by_agent_and_name
            .entry((
                inst.agent.as_str().to_string(),
                canonical_skill_name_suggestion(&inst.name),
            ))
            .or_default()
            .push(inst);
    }
    for ((agent, canonical_name), members) in by_agent_and_name {
        if members.len() < 2
            && !members
                .iter()
                .any(|inst| matches!(inst.state, SkillState::Shadowed))
        {
            continue;
        }
        let winner_id = precedence_winner_id(&members);
        groups.push(analysis_group(
            "precedence_shadowing",
            "info",
            format!(
                "{} has {} visible records for canonical name '{canonical_name}'.",
                agent,
                members.len()
            ),
            Some(canonical_name),
            "Within a single agent, project-scoped skills are treated as higher precedence than agent-global rows when both are visible. Cross-agent duplicates do not share runtime precedence because each agent loads its own roots independently.".to_string(),
            members,
            winner_id,
        ));
    }
}

fn analysis_group(
    kind: &str,
    severity: &str,
    title: String,
    canonical_name: Option<String>,
    explanation: String,
    members: Vec<&SkillInstance>,
    winner_id: Option<String>,
) -> CrossAgentAnalysisGroup {
    let instance_ids = members
        .iter()
        .map(|inst| inst.id.clone())
        .collect::<Vec<_>>();
    let agents = members
        .iter()
        .map(|inst| inst.agent.as_str().to_string())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
    let scopes = members
        .iter()
        .map(|inst| inst.scope.as_str().to_string())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
    let paths = members
        .iter()
        .map(|inst| inst.display_path.to_string_lossy().to_string())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let seed = format!(
        "{kind}|{}|{}",
        canonical_name.as_deref().unwrap_or(""),
        instance_ids.join("|")
    );

    CrossAgentAnalysisGroup {
        id: format!("analysis:{kind}:{}", short_hash(&seed)),
        kind: kind.to_string(),
        severity: severity.to_string(),
        title,
        canonical_name,
        explanation,
        instance_ids,
        winner_id,
        agents,
        scopes,
        paths,
    }
}

fn precedence_winner_id(members: &[&SkillInstance]) -> Option<String> {
    members
        .iter()
        .filter(|inst| inst.enabled && matches!(inst.state, SkillState::Loaded))
        .min_by_key(|inst| (scope_precedence_rank(inst.scope), inst.name.clone()))
        .map(|inst| inst.id.clone())
}

fn scope_precedence_rank(scope: Scope) -> u8 {
    match scope {
        Scope::AgentProject => 0,
        Scope::AgentGlobal => 1,
        Scope::ToolGlobal => 2,
        _ => 3,
    }
}

fn severity_rank(severity: &str) -> u8 {
    match severity {
        "error" => 0,
        "warn" | "warning" => 1,
        "info" => 2,
        _ => 3,
    }
}

fn count_kind(groups: &[CrossAgentAnalysisGroup], kind: &str) -> usize {
    groups.iter().filter(|group| group.kind == kind).count()
}

pub fn list_snapshots(catalog: &Catalog) -> Result<Vec<ConfigSnapshotRecord>, CommandError> {
    Ok(catalog.list_all_config_snapshots()?)
}

pub fn list_agent_config_snapshots(
    catalog: &Catalog,
    agent: &str,
    scope: Option<&str>,
) -> Result<Vec<ConfigSnapshotRecord>, CommandError> {
    Ok(catalog.list_agent_config_snapshots(agent, scope)?)
}

pub fn list_skill_events(
    catalog: &Catalog,
    instance_id: &str,
    limit: Option<usize>,
) -> Result<Vec<SkillEventRecord>, CommandError> {
    Ok(catalog.list_skill_events(instance_id, limit)?)
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ExportedSkillMetadata {
    pub name: String,
    pub description: String,
    pub skill_path: String,
    pub source_agent: String,
    pub source_scope: String,
    pub version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExportedSkillManifest {
    pub manifest_version: u32,
    pub bundle_format: String,
    pub metadata: ExportedSkillMetadata,
    pub fingerprint: String,
    pub permissions: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExportedSkillBundle {
    pub manifest_path: PathBuf,
    pub bundle_path: PathBuf,
    pub fingerprint: String,
    pub metadata: ExportedSkillMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReimportedSkillBundle {
    pub fingerprint: String,
    pub metadata: ExportedSkillMetadata,
    pub permissions: serde_json::Value,
}

struct ExportSkillSource {
    agent: String,
    scope: String,
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
    version: Option<String>,
    permissions: serde_json::Value,
    fingerprint: String,
}

pub fn export_skill_bundle(
    catalog: &Catalog,
    instance_id: &str,
    output_dir: &Path,
) -> Result<ExportedSkillBundle, CommandError> {
    let detail = get_skill(catalog, instance_id)?;
    let version = version_from_frontmatter(&detail.frontmatter_raw);
    let source = ExportSkillSource {
        agent: detail.agent,
        scope: detail.scope,
        frontmatter_raw: detail.frontmatter_raw,
        body: detail.body,
        name: detail.name,
        description: detail.description,
        version,
        permissions: stable_permissions(detail.permissions),
        fingerprint: detail.fingerprint,
    };
    write_export_bundle(source, output_dir)
}

pub fn export_staging_skill_bundle(
    source_path: &Path,
    output_dir: &Path,
) -> Result<ExportedSkillBundle, CommandError> {
    let source = read_staging_skill_source(source_path)?;
    write_export_bundle(source, output_dir)
}

pub fn reimport_skill_bundle(bundle_path: &Path) -> Result<ReimportedSkillBundle, CommandError> {
    let manifest_path = bundle_path.join("manifest.json");
    let manifest_text = fs::read_to_string(&manifest_path)?;
    let manifest: ExportedSkillManifest = serde_json::from_str(&manifest_text)?;
    validate_relative_bundle_path(&manifest.metadata.skill_path)?;
    let skill_path = bundle_path.join(&manifest.metadata.skill_path);
    let parsed = parse_export_skill_file(&skill_path)?;
    let fingerprint = content_fingerprint(&parsed.frontmatter_raw, &parsed.body);
    if fingerprint != manifest.fingerprint {
        return Err(CommandError::InvalidSkillBundle(format!(
            "manifest fingerprint {} does not match bundle content {}",
            manifest.fingerprint, fingerprint
        )));
    }
    Ok(ReimportedSkillBundle {
        fingerprint,
        metadata: manifest.metadata,
        permissions: manifest.permissions,
    })
}

fn write_export_bundle(
    source: ExportSkillSource,
    output_dir: &Path,
) -> Result<ExportedSkillBundle, CommandError> {
    let bundle_path = output_dir.join(safe_bundle_dir_name(&source.name));
    let skill_relative_path = "skill/SKILL.md";
    let skill_dir = bundle_path.join("skill");
    fs::create_dir_all(&skill_dir)?;
    fs::write(
        skill_dir.join("SKILL.md"),
        skill_file_content(&source.frontmatter_raw, &source.body),
    )?;

    let metadata = ExportedSkillMetadata {
        name: source.name,
        description: source.description,
        skill_path: skill_relative_path.to_string(),
        source_agent: source.agent,
        source_scope: source.scope,
        version: source.version,
    };
    let manifest = ExportedSkillManifest {
        manifest_version: 1,
        bundle_format: "skills-copilot.tool-global.v2.9".to_string(),
        metadata: metadata.clone(),
        fingerprint: source.fingerprint.clone(),
        permissions: source.permissions,
    };
    let manifest_path = bundle_path.join("manifest.json");
    let manifest_text = serde_json::to_string_pretty(&manifest)?;
    fs::write(&manifest_path, format!("{manifest_text}\n"))?;

    Ok(ExportedSkillBundle {
        manifest_path,
        bundle_path,
        fingerprint: source.fingerprint,
        metadata,
    })
}

struct ParsedExportSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
    version: Option<String>,
    permissions: serde_json::Value,
}

fn read_staging_skill_source(path: &Path) -> Result<ExportSkillSource, CommandError> {
    let parsed = parse_export_skill_file(path)?;
    let fingerprint = content_fingerprint(&parsed.frontmatter_raw, &parsed.body);
    Ok(ExportSkillSource {
        agent: "skills-copilot".to_string(),
        scope: Scope::ToolGlobal.as_str().to_string(),
        frontmatter_raw: parsed.frontmatter_raw,
        body: parsed.body,
        name: parsed.name,
        description: parsed.description,
        version: parsed.version,
        permissions: parsed.permissions,
        fingerprint,
    })
}

fn parse_export_skill_file(path: &Path) -> Result<ParsedExportSkill, CommandError> {
    let skill_path = if path.is_dir() {
        path.join("SKILL.md")
    } else {
        path.to_path_buf()
    };
    if skill_path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md") {
        return Err(CommandError::InvalidSkillSource(format!(
            "expected a skill directory or SKILL.md path, got {}",
            path.display()
        )));
    }
    let content = fs::read_to_string(&skill_path)?;
    let rest = content
        .strip_prefix("---\n")
        .or_else(|| content.strip_prefix("---\r\n"))
        .ok_or_else(|| {
            CommandError::InvalidSkillSource(format!(
                "{} is missing YAML frontmatter",
                skill_path.display()
            ))
        })?;
    let (frontmatter_raw, body) = split_export_frontmatter(rest).ok_or_else(|| {
        CommandError::InvalidSkillSource(format!(
            "{} has unterminated YAML frontmatter",
            skill_path.display()
        ))
    })?;
    let frontmatter: serde_yaml::Value = serde_yaml::from_str(frontmatter_raw)
        .map_err(|err| CommandError::InvalidSkillSource(err.to_string()))?;
    let name = yaml_string(&frontmatter, "name")
        .ok_or_else(|| CommandError::InvalidSkillSource("missing skill name".to_string()))?;
    let description = yaml_string(&frontmatter, "description").unwrap_or_else(|| {
        body.lines()
            .map(str::trim)
            .find(|line| !line.is_empty() && !line.starts_with('#'))
            .unwrap_or_default()
            .to_string()
    });
    let version = yaml_string(&frontmatter, "version");
    let permissions = permissions_from_frontmatter(&frontmatter);
    Ok(ParsedExportSkill {
        frontmatter_raw: frontmatter_raw.to_string(),
        body,
        name,
        description,
        version,
        permissions,
    })
}

fn split_export_frontmatter(rest: &str) -> Option<(&str, String)> {
    if let Some((frontmatter, body)) = rest.split_once("\n---\n") {
        return Some((frontmatter, body.to_string()));
    }
    if let Some((frontmatter, body)) = rest.split_once("\n---\r\n") {
        return Some((frontmatter, body.to_string()));
    }
    rest.strip_suffix("\n---")
        .or_else(|| rest.strip_suffix("\r\n---"))
        .map(|frontmatter| (frontmatter, String::new()))
}

fn skill_file_content(frontmatter_raw: &str, body: &str) -> String {
    let mut content = String::from("---\n");
    content.push_str(frontmatter_raw);
    content.push_str("\n---\n");
    content.push_str(body);
    content
}

fn version_from_frontmatter(frontmatter_raw: &str) -> Option<String> {
    serde_yaml::from_str::<serde_yaml::Value>(frontmatter_raw)
        .ok()
        .and_then(|value| yaml_string(&value, "version"))
}

fn yaml_string(value: &serde_yaml::Value, key: &str) -> Option<String> {
    value
        .get(key)
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

fn permissions_from_frontmatter(frontmatter: &serde_yaml::Value) -> serde_json::Value {
    let mut permissions = serde_json::Map::new();
    if let Some(tools) = yaml_string_vec(frontmatter.get("tools"))
        .or_else(|| yaml_string_vec(frontmatter.get("allowed-tools")))
    {
        permissions.insert("tools".to_string(), string_array_value(tools));
    }
    if let Some(files) = yaml_string_vec(frontmatter.get("files")) {
        permissions.insert("files".to_string(), string_array_value(files));
    }
    if let Some(network) = yaml_string(frontmatter, "network")
        .or_else(|| yaml_nested_string(frontmatter, &["permissions", "network"]))
    {
        permissions.insert("network".to_string(), serde_json::Value::String(network));
    }
    if let Some(exec) = yaml_bool(frontmatter, "exec")
        .or_else(|| yaml_nested_bool(frontmatter, &["permissions", "exec"]))
    {
        permissions.insert("exec".to_string(), exec.into());
    }
    if let Some(requires_human) = yaml_bool(frontmatter, "requires_human")
        .or_else(|| yaml_nested_bool(frontmatter, &["permissions", "requires_human"]))
    {
        permissions.insert("requires_human".to_string(), requires_human.into());
    }
    serde_json::Value::Object(permissions)
}

fn yaml_string_vec(value: Option<&serde_yaml::Value>) -> Option<Vec<String>> {
    match value? {
        serde_yaml::Value::Sequence(items) => items
            .iter()
            .map(|item| item.as_str().map(ToString::to_string))
            .collect(),
        serde_yaml::Value::String(raw) => Some(
            raw.split(',')
                .map(str::trim)
                .filter(|item| !item.is_empty())
                .map(ToString::to_string)
                .collect(),
        ),
        _ => None,
    }
}

fn yaml_bool(value: &serde_yaml::Value, key: &str) -> Option<bool> {
    value.get(key).and_then(serde_yaml::Value::as_bool)
}

fn yaml_nested_string(value: &serde_yaml::Value, path: &[&str]) -> Option<String> {
    yaml_nested_value(value, path)?
        .as_str()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

fn yaml_nested_bool(value: &serde_yaml::Value, path: &[&str]) -> Option<bool> {
    yaml_nested_value(value, path)?.as_bool()
}

fn yaml_nested_value<'a>(
    value: &'a serde_yaml::Value,
    path: &[&str],
) -> Option<&'a serde_yaml::Value> {
    let mut current = value;
    for key in path {
        current = current.get(*key)?;
    }
    Some(current)
}

fn string_array_value(values: Vec<String>) -> serde_json::Value {
    serde_json::Value::Array(values.into_iter().map(serde_json::Value::String).collect())
}

fn stable_permissions(value: serde_json::Value) -> serde_json::Value {
    match value {
        serde_json::Value::Object(map) => {
            let mut stable = serde_json::Map::new();
            for key in ["tools", "files", "network", "exec", "requires_human"] {
                if let Some(value) = map.get(key) {
                    stable.insert(key.to_string(), value.clone());
                }
            }
            serde_json::Value::Object(stable)
        }
        _ => serde_json::json!({}),
    }
}

fn validate_relative_bundle_path(path: &str) -> Result<(), CommandError> {
    let candidate = Path::new(path);
    if candidate.is_absolute() || path.contains("..") {
        return Err(CommandError::InvalidSkillBundle(format!(
            "manifest skill_path must be relative and contained: {path}"
        )));
    }
    Ok(())
}

fn safe_bundle_dir_name(name: &str) -> String {
    let sanitized: String = name
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_') {
                ch
            } else {
                '-'
            }
        })
        .collect();
    let trimmed = sanitized.trim_matches('-');
    if trimmed.is_empty() {
        "skill".to_string()
    } else {
        trimmed.to_string()
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct ToolGlobalImportResult {
    pub imported: SkillRecord,
    pub instance_id: String,
    pub source_path: String,
    pub staging_path: String,
    pub findings: Vec<RuleFindingRecord>,
    pub audit: ToolGlobalImportAudit,
}

#[derive(Debug, Clone, Serialize)]
pub struct ToolGlobalImportAudit {
    pub status: &'static str,
    pub read_only_preview: bool,
    pub finding_count: usize,
    pub error_count: usize,
    pub warn_count: usize,
    pub info_count: usize,
    pub conflict_count: usize,
}

pub fn import_local_skill_to_tool_global(
    catalog: &Catalog,
    ctx: &AdapterContext,
    staging_root: &Path,
    source_path: &Path,
) -> Result<ToolGlobalImportResult, CommandError> {
    reject_symlink(source_path, "import source")?;
    let source_dir = canonical_import_source(source_path)?;
    let source_skill_path = source_dir.join("SKILL.md");
    if !source_skill_path.is_file() {
        return Err(CommandError::InvalidImportSource(format!(
            "{} does not contain SKILL.md",
            source_dir.display()
        )));
    }
    reject_symlink(&source_dir, "import source")?;
    reject_symlink(&source_skill_path, "import SKILL.md")?;

    let source_content = fs::read_to_string(&source_skill_path)?;
    let parsed = parse_tool_global_skill(
        &source_content,
        source_dir
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("imported-skill"),
    );
    fs::create_dir_all(staging_root)?;
    reject_symlink(staging_root, "tool-global staging root")?;
    let staging_skills_root = staging_root.join("skills");
    fs::create_dir_all(&staging_skills_root)?;
    reject_symlink(&staging_skills_root, "tool-global staging skills root")?;
    let canonical_staging_skills_root = staging_skills_root.canonicalize()?;
    let destination_dir = canonical_staging_skills_root.join(format!(
        "{}-{}",
        canonical_skill_name_suggestion(&parsed.name),
        short_hash(&source_dir.to_string_lossy())
    ));
    ensure_path_inside(
        &destination_dir,
        &canonical_staging_skills_root,
        "staging destination",
    )?;

    let temp_dir = canonical_staging_skills_root.join(format!(
        ".{}.tmp-{}",
        destination_dir
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("import"),
        current_time_ms()
    ));
    ensure_path_inside(
        &temp_dir,
        &canonical_staging_skills_root,
        "staging temp destination",
    )?;
    if temp_dir.exists() {
        fs::remove_dir_all(&temp_dir)?;
    }
    if let Err(error) =
        copy_skill_dir_to_staging(&source_dir, &temp_dir, &canonical_staging_skills_root)
    {
        let _ = fs::remove_dir_all(&temp_dir);
        return Err(error);
    }
    if destination_dir.exists() {
        fs::remove_dir_all(&destination_dir)?;
    }
    fs::rename(&temp_dir, &destination_dir)?;

    let staged_skill_path = destination_dir.join("SKILL.md").canonicalize()?;
    ensure_path_inside(
        &staged_skill_path,
        &canonical_staging_skills_root,
        "staged skill path",
    )?;
    let staged_content = fs::read_to_string(&staged_skill_path)?;
    let staged = parse_tool_global_skill(&staged_content, &parsed.name);
    let metadata = fs::metadata(&staged_skill_path)?;
    let mtime = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or_default();
    let instance = SkillInstance {
        id: stable_tool_global_instance_id(&staged_skill_path),
        agent: AgentId::ToolGlobal,
        scope: Scope::ToolGlobal,
        project_root: None,
        path: staged_skill_path.clone(),
        display_path: staged_skill_path.clone(),
        definition_id: hash_string(&staged.name.to_ascii_lowercase()),
        name: staged.name.clone(),
        display_name: staged.name.clone(),
        description: staged.description.clone(),
        version: staged.version.clone(),
        state: staged.state,
        enabled: true,
        frontmatter_raw: staged.frontmatter_raw.clone(),
        body: staged.body.clone(),
        scripts: Vec::new(),
        permissions: staged.permissions.clone(),
        fingerprint: hash_string(&format!("{}\n---\n{}", staged.frontmatter_raw, staged.body)),
        mtime,
        first_seen: mtime,
        last_seen: mtime,
    };
    let previous_fingerprints = catalog.instance_fingerprints()?;
    catalog.upsert_skill_instance(&instance)?;
    refresh_catalog_rule_outputs(catalog, ctx, previous_fingerprints)?;

    let imported = catalog
        .get_skill_record(&instance.id)?
        .ok_or_else(|| CommandError::InstanceNotFound(instance.id.clone()))?;
    let all_findings = list_findings(catalog)?;
    let findings: Vec<RuleFindingRecord> = all_findings
        .into_iter()
        .filter(|finding| {
            finding.instance_id.as_deref() == Some(instance.id.as_str())
                || finding.definition_id.as_deref() == Some(instance.definition_id.as_str())
        })
        .collect();
    let conflicts = list_conflicts(catalog)?;
    let audit = import_audit_summary(&findings, conflicts.len());
    Ok(ToolGlobalImportResult {
        imported,
        instance_id: instance.id,
        source_path: source_dir.to_string_lossy().to_string(),
        staging_path: staged_skill_path.to_string_lossy().to_string(),
        findings,
        audit,
    })
}

pub fn import_github_skill_to_tool_global_deferred(url: &str) -> Result<(), CommandError> {
    Err(CommandError::UnsupportedImportSource(format!(
        "GitHub repo import is explicitly deferred; provide a local source_path after cloning or unpacking the repo yourself. Requested URL: {url}"
    )))
}

#[derive(Debug, Clone)]
struct ParsedToolGlobalSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
    version: Option<String>,
    state: SkillState,
    permissions: PermissionRequest,
}

fn canonical_import_source(source_path: &Path) -> Result<PathBuf, CommandError> {
    if !source_path.exists() {
        return Err(CommandError::InvalidImportSource(format!(
            "{} does not exist",
            source_path.display()
        )));
    }
    let source_dir = source_path.canonicalize()?;
    if !source_dir.is_dir() {
        return Err(CommandError::InvalidImportSource(format!(
            "{} is not a directory",
            source_dir.display()
        )));
    }
    Ok(source_dir)
}

fn parse_tool_global_skill(content: &str, fallback_name: &str) -> ParsedToolGlobalSkill {
    match parse_tool_global_skill_content(content, fallback_name) {
        Ok(parsed) => parsed,
        Err(message) => ParsedToolGlobalSkill {
            frontmatter_raw: String::new(),
            body: content.to_string(),
            name: fallback_name.to_string(),
            description: message,
            version: None,
            state: SkillState::Broken,
            permissions: PermissionRequest::default(),
        },
    }
}

fn parse_tool_global_skill_content(
    content: &str,
    fallback_name: &str,
) -> Result<ParsedToolGlobalSkill, String> {
    let rest = content
        .strip_prefix("---\n")
        .or_else(|| content.strip_prefix("---\r\n"))
        .ok_or_else(|| "missing YAML frontmatter".to_string())?;
    let (frontmatter_raw, body) = split_import_frontmatter(rest)?;
    let frontmatter: serde_yaml::Value =
        serde_yaml::from_str(frontmatter_raw).map_err(|err| err.to_string())?;
    let name = frontmatter
        .get("name")
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .unwrap_or(fallback_name)
        .to_string();
    let description = frontmatter
        .get("description")
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|description| !description.is_empty())
        .map(ToString::to_string)
        .unwrap_or_else(|| first_markdown_paragraph(&body));
    let version = frontmatter
        .get("version")
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|version| !version.is_empty())
        .map(ToString::to_string);
    let permissions = import_permissions_from_frontmatter(&frontmatter);
    Ok(ParsedToolGlobalSkill {
        frontmatter_raw: frontmatter_raw.to_string(),
        body,
        name,
        description,
        version,
        state: SkillState::Loaded,
        permissions,
    })
}

fn split_import_frontmatter(rest: &str) -> Result<(&str, String), String> {
    if let Some((frontmatter, body)) = rest.split_once("\n---\n") {
        return Ok((frontmatter, body.to_string()));
    }
    if let Some((frontmatter, body)) = rest.split_once("\n---\r\n") {
        return Ok((frontmatter, body.to_string()));
    }
    if let Some(frontmatter) = rest.strip_suffix("\n---") {
        return Ok((frontmatter, String::new()));
    }
    if let Some(frontmatter) = rest.strip_suffix("\r\n---") {
        return Ok((frontmatter, String::new()));
    }
    Err("unterminated YAML frontmatter".to_string())
}

fn first_markdown_paragraph(body: &str) -> String {
    body.split("\n\n")
        .map(str::trim)
        .find(|paragraph| !paragraph.is_empty() && !paragraph.starts_with('#'))
        .unwrap_or_default()
        .lines()
        .map(str::trim)
        .collect::<Vec<_>>()
        .join(" ")
}

fn import_permissions_from_frontmatter(frontmatter: &serde_yaml::Value) -> PermissionRequest {
    let tools = yaml_string_list(frontmatter.get("tools"));
    let files = yaml_string_list(
        frontmatter
            .get("permissions")
            .and_then(|permissions| permissions.get("files"))
            .or_else(|| frontmatter.get("files")),
    );
    let network_value = frontmatter
        .get("permissions")
        .and_then(|permissions| permissions.get("network"))
        .or_else(|| frontmatter.get("network"));
    let network_declared = network_value.is_some();
    let network = network_value
        .and_then(serde_yaml::Value::as_str)
        .map(|value| match value.trim().to_ascii_lowercase().as_str() {
            "none" => NetworkAccess::None,
            "read-only" | "readonly" | "read_only" => NetworkAccess::ReadOnly,
            "full" => NetworkAccess::Full,
            other => NetworkAccess::Unknown(other.to_string()),
        })
        .unwrap_or(NetworkAccess::None);
    let exec_value = frontmatter
        .get("permissions")
        .and_then(|permissions| permissions.get("exec"))
        .or_else(|| frontmatter.get("exec"));
    let requires_human_value = frontmatter
        .get("permissions")
        .and_then(|permissions| permissions.get("requires_human"))
        .or_else(|| frontmatter.get("requires_human"));

    PermissionRequest {
        tools,
        files,
        network,
        network_declared,
        exec: exec_value
            .and_then(serde_yaml::Value::as_bool)
            .unwrap_or(false),
        exec_declared: exec_value.is_some(),
        requires_human: requires_human_value
            .and_then(serde_yaml::Value::as_bool)
            .unwrap_or(true),
        requires_human_declared: requires_human_value.is_some(),
    }
}

fn yaml_string_list(value: Option<&serde_yaml::Value>) -> Vec<String> {
    match value {
        Some(serde_yaml::Value::Sequence(items)) => items
            .iter()
            .filter_map(serde_yaml::Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
            .collect(),
        Some(serde_yaml::Value::String(value)) => value
            .split([',', '\n', '\r'])
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
            .collect(),
        _ => Vec::new(),
    }
}

fn copy_skill_dir_to_staging(
    source_dir: &Path,
    destination_dir: &Path,
    staging_root: &Path,
) -> Result<(), CommandError> {
    ensure_path_inside(destination_dir, staging_root, "staging destination")?;
    fs::create_dir_all(destination_dir)?;
    for entry in fs::read_dir(source_dir)? {
        let entry = entry?;
        let file_type = entry.file_type()?;
        let file_name = entry.file_name();
        let source = entry.path();
        let destination = destination_dir.join(file_name);
        ensure_path_inside(&destination, staging_root, "staging copy target")?;
        if file_type.is_symlink() {
            return Err(CommandError::InvalidImportSource(format!(
                "{} is a symlink; tool-global import does not follow source symlinks",
                source.display()
            )));
        }
        if file_type.is_dir() {
            copy_skill_dir_to_staging(&source, &destination, staging_root)?;
        } else if file_type.is_file() {
            fs::copy(&source, &destination)?;
        }
    }
    Ok(())
}

fn ensure_path_inside(path: &Path, root: &Path, label: &str) -> Result<(), CommandError> {
    let normalized_path = normalize_path_lexically(path);
    let normalized_root = normalize_path_lexically(root);
    if !normalized_path.starts_with(&normalized_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "{label} {} resolves outside staging root {}",
            path.display(),
            root.display()
        )));
    }
    Ok(())
}

fn stable_tool_global_instance_id(path: &Path) -> String {
    hash_string(&format!(
        "{}|{}|{}",
        AgentId::ToolGlobal.as_str(),
        Scope::ToolGlobal.as_str(),
        path.to_string_lossy()
    ))
}

fn short_hash(value: &str) -> String {
    hash_string(value).chars().take(12).collect()
}

fn import_audit_summary(
    findings: &[RuleFindingRecord],
    conflict_count: usize,
) -> ToolGlobalImportAudit {
    let error_count = findings
        .iter()
        .filter(|finding| finding.severity == "error")
        .count();
    let warn_count = findings
        .iter()
        .filter(|finding| finding.severity == "warn" || finding.severity == "warning")
        .count();
    let info_count = findings
        .iter()
        .filter(|finding| finding.severity == "info")
        .count();
    ToolGlobalImportAudit {
        status: if error_count == 0 {
            "completed"
        } else {
            "issues"
        },
        read_only_preview: true,
        finding_count: findings.len(),
        error_count,
        warn_count,
        info_count,
        conflict_count,
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillInstallFilePreview {
    pub source: String,
    pub target: String,
    pub kind: String,
    pub will_write: bool,
    pub target_exists: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillInstallConfirmation {
    pub required: bool,
    pub confirmed: bool,
    pub fields: Vec<&'static str>,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct SkillInstallPreviewRecord {
    pub source_instance_id: String,
    pub source_path: String,
    pub target_agent: String,
    pub target_scope: String,
    pub target_path: String,
    pub files: Vec<SkillInstallFilePreview>,
    pub risks: Vec<String>,
    pub confirmation: SkillInstallConfirmation,
    pub wrote: bool,
    pub snapshot_id: Option<String>,
}

pub fn install_skill_from_tool_global(
    catalog: &Catalog,
    ctx: &AdapterContext,
    instance_id: &str,
    target_agent: AgentId,
    target_scope: Scope,
    project_path: Option<&Path>,
    confirmed: bool,
) -> Result<SkillInstallPreviewRecord, CommandError> {
    let preview = preview_skill_install_from_tool_global(
        catalog,
        ctx,
        instance_id,
        target_agent,
        target_scope,
        project_path,
        confirmed,
    )?;
    if !confirmed {
        return Ok(preview);
    }

    let target = PathBuf::from(&preview.target_path);
    let source = PathBuf::from(&preview.source_path);
    validate_skill_install_target(ctx, target_agent, target_scope, &target, project_path, true)?;
    validate_tool_global_source(&source)?;
    let lock_file = lock_install_target(ctx, target_agent, target_scope, &target, project_path)?;

    let write_result = (|| {
        let original_text = match fs::read_to_string(&target) {
            Ok(content) => content,
            Err(err) if err.kind() == io::ErrorKind::NotFound => String::new(),
            Err(err) => return Err(err.into()),
        };
        let new_text = fs::read_to_string(&source)?;

        write_skill_file_atomic(
            ctx,
            target_agent,
            target_scope,
            &target,
            &new_text,
            project_path,
        )?;
        let written = fs::read_to_string(&target)?;
        if written != new_text {
            let _ = write_skill_file_atomic(
                ctx,
                target_agent,
                target_scope,
                &target,
                &original_text,
                project_path,
            );
            return Err(CommandError::VerificationFailed);
        }
        Ok(())
    })();
    lock_file.unlock()?;
    write_result?;

    let scan_ctx = install_scan_context(ctx, target_scope, project_path)?;
    scan_agent_id_to_catalog(target_agent, &scan_ctx, catalog)?;

    Ok(SkillInstallPreviewRecord {
        wrote: true,
        snapshot_id: None,
        confirmation: SkillInstallConfirmation {
            confirmed: true,
            ..preview.confirmation
        },
        ..preview
    })
}

fn preview_skill_install_from_tool_global(
    catalog: &Catalog,
    ctx: &AdapterContext,
    instance_id: &str,
    target_agent: AgentId,
    target_scope: Scope,
    project_path: Option<&Path>,
    confirmed: bool,
) -> Result<SkillInstallPreviewRecord, CommandError> {
    if !matches!(
        target_agent,
        AgentId::ClaudeCode | AgentId::Codex | AgentId::Opencode
    ) {
        return Err(CommandError::InstallUnsupported(format!(
            "{} skills are not writable by install commands",
            target_agent.as_str()
        )));
    }
    if !matches!(target_scope, Scope::AgentGlobal | Scope::AgentProject) {
        return Err(CommandError::UnsupportedScope(target_scope));
    }

    let meta = catalog
        .get_skill_instance_meta(instance_id)?
        .ok_or_else(|| CommandError::InstanceNotFound(instance_id.to_string()))?;
    if meta.scope != Scope::ToolGlobal {
        return Err(CommandError::UnsupportedScope(meta.scope));
    }
    reject_symlink(&meta.path, "tool-global source file")?;
    let source = meta.path.canonicalize().map_err(|err| {
        CommandError::UnsafeConfigPath(format!(
            "tool-global source {} cannot be canonicalized: {err}",
            meta.path.display()
        ))
    })?;
    validate_tool_global_source(&source)?;

    let target =
        skill_install_target_path(ctx, target_agent, target_scope, &meta.name, project_path)?;
    validate_skill_install_target(
        ctx,
        target_agent,
        target_scope,
        &target,
        project_path,
        false,
    )?;
    let target_exists = target.exists();
    let risks = install_preview_risks(target_agent, target_scope, target_exists);
    Ok(SkillInstallPreviewRecord {
        source_instance_id: instance_id.to_string(),
        source_path: source.to_string_lossy().to_string(),
        target_agent: target_agent.as_str().to_string(),
        target_scope: target_scope.as_str().to_string(),
        target_path: target.to_string_lossy().to_string(),
        files: vec![SkillInstallFilePreview {
            source: source.to_string_lossy().to_string(),
            target: target.to_string_lossy().to_string(),
            kind: "skill".to_string(),
            will_write: true,
            target_exists,
        }],
        risks,
        confirmation: SkillInstallConfirmation {
            required: true,
            confirmed,
            fields: vec![
                "source_instance_id",
                "source_path",
                "target_agent",
                "target_scope",
                "target_path",
                "files",
                "risks",
            ],
            message: "Confirm install to copy this tool-global skill into the selected agent root."
                .to_string(),
        },
        wrote: false,
        snapshot_id: None,
    })
}

#[derive(Debug, Clone, Serialize)]
pub struct ConfigDocumentRecord {
    pub agent: String,
    pub scope: String,
    pub target: String,
    pub format: String,
    pub content: String,
    pub exists: bool,
}

pub fn read_claude_settings(ctx: &AdapterContext) -> Result<ConfigDocumentRecord, CommandError> {
    let target = claude_global_settings_path(ctx);
    validate_config_write_target(ctx, AgentId::ClaudeCode, Scope::AgentGlobal, &target)?;
    let (content, exists) = match fs::read_to_string(&target) {
        Ok(content) => (content, true),
        Err(err) if err.kind() == io::ErrorKind::NotFound => ("{}\n".to_string(), false),
        Err(err) => return Err(err.into()),
    };
    Ok(ConfigDocumentRecord {
        agent: ClaudeCodeAdapter.id().as_str().to_string(),
        scope: Scope::AgentGlobal.as_str().to_string(),
        target: target.to_string_lossy().to_string(),
        format: "json".to_string(),
        content,
        exists,
    })
}

pub fn save_claude_settings(
    catalog: &Catalog,
    ctx: &AdapterContext,
    content: &str,
) -> Result<ConfigDocumentRecord, CommandError> {
    serde_json::from_str::<serde_json::Value>(content)
        .map_err(|err| CommandError::InvalidJson(err.to_string()))?;

    let target = claude_global_settings_path(ctx);
    validate_config_write_target(ctx, AgentId::ClaudeCode, Scope::AgentGlobal, &target)?;
    let lock_file = lock_config(ctx, AgentId::ClaudeCode, Scope::AgentGlobal, &target)?;
    let original_text = if target.exists() {
        fs::read_to_string(&target)?
    } else {
        String::new()
    };

    let snapshot_id = generate_snapshot_id();
    let snapshot_content = redact_snapshot_content(&original_text);
    catalog.create_config_snapshot(ConfigSnapshotDraft {
        id: &snapshot_id,
        agent: ClaudeCodeAdapter.id().as_str(),
        scope: Scope::AgentGlobal.as_str(),
        target: &target.to_string_lossy(),
        content: &snapshot_content,
        reason: "pre-config-edit",
        created_at_ms: current_time_ms(),
    })?;

    write_config_atomic(
        ctx,
        AgentId::ClaudeCode,
        Scope::AgentGlobal,
        &target,
        content,
    )?;
    let written = fs::read_to_string(&target)?;
    if written != content {
        let _ = write_config_atomic(
            ctx,
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            &target,
            &original_text,
        );
        lock_file.unlock()?;
        return Err(CommandError::VerificationFailed);
    }
    lock_file.unlock()?;

    scan_claude_to_catalog(ctx, catalog)?;
    read_claude_settings(ctx)
}

#[derive(Debug, Clone, Serialize)]
pub struct SnapshotRollbackPreviewRecord {
    pub snapshot: ConfigSnapshotRecord,
    pub current_content: String,
    pub current_read_error: Option<String>,
    pub changed: bool,
    pub redacted: bool,
    pub rollback_supported: bool,
}

pub fn preview_snapshot_rollback(
    catalog: &Catalog,
    snapshot_id: &str,
) -> Result<SnapshotRollbackPreviewRecord, CommandError> {
    let snapshot = catalog
        .get_config_snapshot(snapshot_id)?
        .ok_or_else(|| CommandError::SnapshotNotFound(snapshot_id.to_string()))?;
    let ctx = preview_context_from_snapshot(&snapshot)?;
    preview_snapshot_rollback_for_record(&ctx, snapshot)
}

pub fn preview_snapshot_rollback_with_context(
    catalog: &Catalog,
    ctx: &AdapterContext,
    snapshot_id: &str,
) -> Result<SnapshotRollbackPreviewRecord, CommandError> {
    let snapshot = catalog
        .get_config_snapshot(snapshot_id)?
        .ok_or_else(|| CommandError::SnapshotNotFound(snapshot_id.to_string()))?;
    preview_snapshot_rollback_for_record(ctx, snapshot)
}

fn preview_snapshot_rollback_for_record(
    ctx: &AdapterContext,
    snapshot: ConfigSnapshotRecord,
) -> Result<SnapshotRollbackPreviewRecord, CommandError> {
    let target = PathBuf::from(&snapshot.target);
    let scope = scope_from_snapshot(&snapshot.scope)?;
    let agent = agent_from_snapshot(&snapshot.agent)?;
    validate_config_write_target(ctx, agent, scope, &target)?;

    let (current_content, current_read_error) = match fs::read_to_string(&target) {
        Ok(content) => (content, None),
        Err(err) if err.kind() == io::ErrorKind::NotFound => (
            String::new(),
            Some("target file does not exist; rollback will recreate it".to_string()),
        ),
        Err(err) => (String::new(), Some(err.to_string())),
    };
    let redacted = is_redacted_snapshot_content(&snapshot.content);
    let changed = redacted || current_content != snapshot.content;
    Ok(SnapshotRollbackPreviewRecord {
        snapshot,
        current_content,
        current_read_error,
        changed,
        redacted,
        rollback_supported: !redacted,
    })
}

pub fn rollback_snapshot(
    catalog: &Catalog,
    ctx: &AdapterContext,
    snapshot_id: &str,
) -> Result<usize, CommandError> {
    let snapshot = catalog
        .get_config_snapshot(snapshot_id)?
        .ok_or_else(|| CommandError::SnapshotNotFound(snapshot_id.to_string()))?;
    let target = PathBuf::from(&snapshot.target);
    let scope = scope_from_snapshot(&snapshot.scope)?;
    let agent = agent_from_snapshot(&snapshot.agent)?;
    if !matches!(agent, AgentId::ClaudeCode | AgentId::Codex) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "snapshot agent {} is not writable by config rollback commands",
            snapshot.agent
        )));
    }
    if is_redacted_snapshot_content(&snapshot.content) {
        return Err(CommandError::UnsafeConfigPath(
            "snapshot content was redacted and cannot be rolled back directly".to_string(),
        ));
    }
    validate_config_write_target(ctx, agent, scope, &target)?;
    write_locked(ctx, agent, scope, &target, &snapshot.content)?;
    scan_agent_id_to_catalog(agent, ctx, catalog)
}

fn refresh_catalog_rule_outputs(
    catalog: &Catalog,
    ctx: &AdapterContext,
    previous_fingerprints: std::collections::HashMap<String, String>,
) -> Result<(), CommandError> {
    let instances = visible_catalog_instances(
        catalog.list_skill_instances_for_project_context(ctx.project_root.as_deref())?,
    );
    let mut rule_report = evaluate_mvp_rules(
        &instances,
        &RuleContext {
            previous_fingerprints,
        },
    );
    append_v28_local_rule_findings(&instances, &mut rule_report);
    refresh_rule_outputs(catalog, rule_report)
}

const BODY_TOO_LONG_CHAR_THRESHOLD: usize = 32_000;

fn visible_catalog_instances(instances: Vec<SkillInstance>) -> Vec<SkillInstance> {
    instances
        .into_iter()
        .filter(|instance| !is_pi_plain_markdown_catalog_noise(instance.agent, &instance.path))
        .collect()
}

fn is_pi_plain_markdown_catalog_noise(agent: AgentId, path: &Path) -> bool {
    agent == AgentId::Pi
        && path.extension().and_then(|extension| extension.to_str()) == Some("md")
        && path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md")
}

fn append_v28_local_rule_findings(instances: &[SkillInstance], report: &mut RuleReport) {
    for inst in instances {
        if frontmatter_tools_present_but_empty(&inst.frontmatter_raw) {
            push_instance_finding(
                report,
                inst,
                "frontmatter.tools-not-empty",
                Severity::Warn,
                "Frontmatter tools field is present but empty.",
                "Remove the tools field or list at least one required tool.",
            );
        }
        if !is_canonical_skill_name(&inst.name) {
            let suggestion = canonical_skill_name_suggestion(&inst.name);
            report.findings.push(Finding {
                instance_id: Some(inst.id.clone()),
                definition_id: Some(inst.definition_id.clone()),
                rule_id: "name.canonical-case".to_string(),
                severity: Severity::Warn,
                message: format!(
                    "Skill name '{}' is not a canonical lowercase slug.",
                    inst.name
                ),
                suggestion: Some(format!(
                    "Rename the skill to a lowercase slug such as '{}'.",
                    suggestion
                )),
            });
        }
        let body_len = inst.body.chars().count();
        if body_len > BODY_TOO_LONG_CHAR_THRESHOLD {
            report.findings.push(Finding {
                instance_id: Some(inst.id.clone()),
                definition_id: Some(inst.definition_id.clone()),
                rule_id: "body.too-long".to_string(),
                severity: Severity::Warn,
                message: format!(
                    "Skill body is {body_len} characters, exceeding the local limit of {BODY_TOO_LONG_CHAR_THRESHOLD}."
                ),
                suggestion: Some(
                    "Shorten the body or move detailed reference material into separate files."
                        .to_string(),
                ),
            });
        }
        if skill_uses_network_capability(inst) && !permissions_network_declared(inst) {
            push_instance_finding(
                report,
                inst,
                "permissions.network-declared",
                Severity::Warn,
                "Skill uses network capability without declaring permissions.network.",
                "Declare permissions.network as none, read-only, or full to match the skill's network use.",
            );
        }
        if skill_needs_exec_capability(inst) && !requires_human_explicit_true(inst) {
            push_instance_finding(
                report,
                inst,
                "permissions.exec-needs-human",
                Severity::Warn,
                "Skill requires command or script execution without explicitly requiring human approval.",
                "Set requires_human: true for skills that use exec, scripts, or shell commands.",
            );
        }
        if skill_embeds_shebang_script(inst) {
            push_instance_finding(
                report,
                inst,
                "script.no-shebang",
                Severity::Warn,
                "Skill embeds a script that starts with a shebang.",
                "Move executable script bodies into reviewed files or remove the shebang from inline script fields.",
            );
        }
        if skill_declares_unknown_dependency(inst) {
            push_instance_finding(
                report,
                inst,
                "dependency.unknown",
                Severity::Warn,
                "Skill declares dependencies that are not known safe local dependencies.",
                "Replace unknown packages with reviewed local dependencies or document them in an approved dependency allowlist.",
            );
        }
    }
}

fn push_instance_finding(
    report: &mut RuleReport,
    inst: &SkillInstance,
    rule_id: &str,
    severity: Severity,
    message: &str,
    suggestion: &str,
) {
    report.findings.push(Finding {
        instance_id: Some(inst.id.clone()),
        definition_id: Some(inst.definition_id.clone()),
        rule_id: rule_id.to_string(),
        severity,
        message: message.to_string(),
        suggestion: Some(suggestion.to_string()),
    });
}

fn permissions_network_declared(inst: &SkillInstance) -> bool {
    inst.permissions.network_declared
        || frontmatter_has_any_path(inst, &[&["permissions", "network"], &["network"]])
}

fn requires_human_explicit_true(inst: &SkillInstance) -> bool {
    if inst.permissions.requires_human && inst.permissions.requires_human_declared {
        return true;
    }
    frontmatter_bool(
        inst,
        &[&["permissions", "requires_human"], &["requires_human"]],
    )
    .unwrap_or(false)
}

fn skill_uses_network_capability(inst: &SkillInstance) -> bool {
    if inst.permissions.network_declared
        && !matches!(
            inst.permissions.network,
            NetworkAccess::None | NetworkAccess::Unknown(_)
        )
    {
        return true;
    }
    if inst
        .permissions
        .tools
        .iter()
        .any(|tool| contains_any_ci(tool, &["webfetch", "websearch", "http", "curl", "wget"]))
    {
        return true;
    }
    contains_network_command(&inst.frontmatter_raw) || contains_network_command(&inst.body)
}

fn skill_needs_exec_capability(inst: &SkillInstance) -> bool {
    inst.permissions.exec
        || !inst.scripts.is_empty()
        || inst.permissions.tools.iter().any(|tool| {
            contains_any_ci(
                tool,
                &["bash", "shell", "exec", "python", "node", "npm", "cargo"],
            )
        })
        || frontmatter_has_any_path(
            inst,
            &[
                &["permissions", "exec"],
                &["exec"],
                &["scripts"],
                &["script"],
                &["commands"],
                &["command"],
            ],
        )
        || contains_command_marker(&inst.frontmatter_raw)
        || contains_command_marker(&inst.body)
}

fn skill_embeds_shebang_script(inst: &SkillInstance) -> bool {
    text_has_shebang_line(&inst.body) || frontmatter_script_value_has_shebang(inst)
}

fn skill_declares_unknown_dependency(inst: &SkillInstance) -> bool {
    let Some(frontmatter) = frontmatter_value(inst) else {
        return false;
    };
    dependency_declarations(&frontmatter)
        .into_iter()
        .any(|dependency| !is_known_safe_local_dependency(&dependency))
}

fn contains_network_command(text: &str) -> bool {
    contains_any_ci(
        text,
        &[
            "curl ",
            "wget ",
            "fetch(",
            "requests.get",
            "urllib.request",
            "reqwest::",
            "net/http",
            "http.get",
            "invoke-webrequest",
            "pip install ",
            "npm install ",
            "cargo install ",
            "go get ",
            "docker pull ",
        ],
    )
}

fn contains_command_marker(text: &str) -> bool {
    contains_any_ci(
        text,
        &[
            "```bash", "```sh", "```shell", "bash ", "sh ", "python ", "python3 ", "node ", "npm ",
            "cargo ",
        ],
    )
}

fn contains_any_ci(text: &str, needles: &[&str]) -> bool {
    let lower = text.to_ascii_lowercase();
    needles.iter().any(|needle| lower.contains(needle))
}

fn text_has_shebang_line(text: &str) -> bool {
    text.lines().any(|line| line.trim_start().starts_with("#!"))
}

fn frontmatter_value(inst: &SkillInstance) -> Option<serde_yaml::Value> {
    if inst.frontmatter_raw.trim().is_empty() {
        return None;
    }
    serde_yaml::from_str(&inst.frontmatter_raw).ok()
}

fn frontmatter_has_any_path(inst: &SkillInstance, paths: &[&[&str]]) -> bool {
    let Some(value) = frontmatter_value(inst) else {
        return false;
    };
    paths.iter().any(|path| yaml_path(&value, path).is_some())
}

fn frontmatter_bool(inst: &SkillInstance, paths: &[&[&str]]) -> Option<bool> {
    let value = frontmatter_value(inst)?;
    paths
        .iter()
        .find_map(|path| yaml_path(&value, path).and_then(serde_yaml::Value::as_bool))
}

fn yaml_path<'a>(value: &'a serde_yaml::Value, path: &[&str]) -> Option<&'a serde_yaml::Value> {
    let mut current = value;
    for part in path {
        let mapping = current.as_mapping()?;
        current = mapping.get(serde_yaml::Value::String((*part).to_string()))?;
    }
    Some(current)
}

fn frontmatter_script_value_has_shebang(inst: &SkillInstance) -> bool {
    let Some(value) = frontmatter_value(inst) else {
        return false;
    };
    yaml_script_value_has_shebang(&value, false)
}

fn yaml_script_value_has_shebang(value: &serde_yaml::Value, in_script_field: bool) -> bool {
    match value {
        serde_yaml::Value::String(raw) => in_script_field && raw.trim_start().starts_with("#!"),
        serde_yaml::Value::Sequence(items) => items
            .iter()
            .any(|item| yaml_script_value_has_shebang(item, in_script_field)),
        serde_yaml::Value::Mapping(mapping) => mapping.iter().any(|(key, value)| {
            let script_field =
                in_script_field || key.as_str().is_some_and(matches_script_field_name);
            yaml_script_value_has_shebang(value, script_field)
        }),
        _ => false,
    }
}

fn frontmatter_tools_present_but_empty(frontmatter_raw: &str) -> bool {
    let Ok(value) = serde_yaml::from_str::<serde_yaml::Value>(frontmatter_raw) else {
        return false;
    };
    let Some(tools) = value.get(serde_yaml::Value::String("tools".to_string())) else {
        return false;
    };
    match tools {
        serde_yaml::Value::Sequence(items) => items.iter().all(yaml_value_is_blank),
        serde_yaml::Value::String(value) => value.trim().is_empty(),
        serde_yaml::Value::Null => true,
        _ => false,
    }
}

fn matches_script_field_name(key: &str) -> bool {
    let normalized = key.to_ascii_lowercase().replace(['-', '_'], "");
    matches!(
        normalized.as_str(),
        "script" | "scripts" | "command" | "commands" | "inline" | "inlinescript"
    )
}

fn dependency_declarations(value: &serde_yaml::Value) -> Vec<String> {
    let mut declarations = Vec::new();
    collect_dependency_declarations(value, false, &mut declarations);
    declarations
}

fn collect_dependency_declarations(
    value: &serde_yaml::Value,
    in_dependency_field: bool,
    declarations: &mut Vec<String>,
) {
    match value {
        serde_yaml::Value::String(raw) if in_dependency_field => {
            declarations.extend(split_dependency_string(raw));
        }
        serde_yaml::Value::Number(number) if in_dependency_field => {
            declarations.push(number.to_string());
        }
        serde_yaml::Value::Sequence(items) => {
            for item in items {
                collect_dependency_declarations(item, in_dependency_field, declarations);
            }
        }
        serde_yaml::Value::Mapping(mapping) => {
            for (key, value) in mapping {
                let dependency_field = key.as_str().is_some_and(matches_dependency_field_name);
                if in_dependency_field {
                    if let Some(key) = key.as_str() {
                        declarations.extend(split_dependency_string(key));
                    }
                }
                collect_dependency_declarations(
                    value,
                    in_dependency_field || dependency_field,
                    declarations,
                );
            }
        }
        _ => {}
    }
}

fn split_dependency_string(raw: &str) -> Vec<String> {
    raw.split([',', '\n', '\r'])
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(ToString::to_string)
        .collect()
}

fn matches_dependency_field_name(key: &str) -> bool {
    let normalized = key.to_ascii_lowercase().replace(['-', '_'], "");
    matches!(
        normalized.as_str(),
        "dependency" | "dependencies" | "package" | "packages" | "requirements"
    )
}

fn is_known_safe_local_dependency(raw: &str) -> bool {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return true;
    }
    let lower = trimmed.to_ascii_lowercase();
    if lower.starts_with("./")
        || lower.starts_with("../")
        || lower.starts_with('/')
        || lower.starts_with("file:")
    {
        return true;
    }
    let name = lower
        .split(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    '=' | '<' | '>' | '~' | '^' | ':' | '@' | '[' | '(' | ')' | ','
                )
        })
        .next()
        .unwrap_or("");
    matches!(
        name,
        "bash"
            | "sh"
            | "zsh"
            | "python"
            | "python3"
            | "node"
            | "npm"
            | "npx"
            | "bun"
            | "deno"
            | "git"
            | "cargo"
            | "rustc"
            | "go"
            | "make"
            | "jq"
            | "sqlite3"
            | "rg"
            | "ripgrep"
    )
}

fn yaml_value_is_blank(value: &serde_yaml::Value) -> bool {
    match value {
        serde_yaml::Value::String(value) => value.trim().is_empty(),
        serde_yaml::Value::Null => true,
        _ => false,
    }
}

fn is_canonical_skill_name(name: &str) -> bool {
    let mut previous_was_separator = false;
    let mut saw_char = false;
    for (idx, ch) in name.chars().enumerate() {
        let is_separator = matches!(ch, '-' | '_');
        if ch.is_ascii_lowercase() || ch.is_ascii_digit() {
            previous_was_separator = false;
            saw_char = true;
            continue;
        }
        if is_separator && idx > 0 && !previous_was_separator {
            previous_was_separator = true;
            saw_char = true;
            continue;
        }
        return false;
    }
    saw_char && !previous_was_separator
}

fn canonical_skill_name_suggestion(name: &str) -> String {
    let mut output = String::new();
    let mut previous_was_separator = false;
    for ch in name.chars().flat_map(char::to_lowercase) {
        if ch.is_ascii_lowercase() || ch.is_ascii_digit() {
            output.push(ch);
            previous_was_separator = false;
        } else if matches!(ch, '-' | '_') && !output.is_empty() && !previous_was_separator {
            output.push(ch);
            previous_was_separator = true;
        } else if !output.is_empty() && !previous_was_separator {
            output.push('-');
            previous_was_separator = true;
        }
    }
    while output.ends_with(['-', '_']) {
        output.pop();
    }
    if output.is_empty() {
        "skill-name".to_string()
    } else {
        output
    }
}

fn refresh_rule_outputs(catalog: &Catalog, report: RuleReport) -> Result<(), CommandError> {
    let now_ms = current_time_ms();
    let report_findings = dedupe_rule_findings(report.findings);
    let findings: Vec<RuleFindingDraft> = report_findings
        .into_iter()
        .enumerate()
        .map(|(idx, finding)| RuleFindingDraft {
            id: format!(
                "{}:{}",
                finding.rule_id,
                finding
                    .instance_id
                    .as_deref()
                    .or(finding.definition_id.as_deref())
                    .unwrap_or("global")
            )
            .replace('/', "_")
                + &format!(":{idx}"),
            instance_id: finding.instance_id,
            definition_id: finding.definition_id,
            rule_id: finding.rule_id,
            severity: finding.severity.as_str().to_string(),
            message: finding.message,
            suggestion: finding.suggestion,
            created_at: now_ms,
        })
        .collect();
    let mut seen_definition_names = std::collections::HashSet::new();
    let definitions: Vec<SkillDefinitionDraft> = report
        .definitions
        .into_iter()
        .filter(|definition| seen_definition_names.insert(definition.canonical_name.clone()))
        .map(|definition| SkillDefinitionDraft {
            id: definition.id,
            canonical_name: definition.canonical_name,
            description: definition.description,
            active_instance: definition.active_instance,
            has_multiple_instances: definition.has_multiple_instances,
            has_conflict: definition.has_conflict,
        })
        .collect();
    let conflicts: Vec<ConflictGroupDraft> = report
        .conflicts
        .into_iter()
        .map(|conflict| ConflictGroupDraft {
            id: conflict.id,
            definition_id: conflict.definition_id,
            reason: conflict.reason,
            winner_id: conflict.winner_id,
            instance_ids: conflict.instances,
        })
        .collect();

    catalog.refresh_definitions_and_conflicts(&definitions, &conflicts)?;
    catalog.refresh_rule_findings(&findings)?;
    Ok(())
}

/// Toggle a skill's `skillOverrides` entry in the agent's settings file, with
/// snapshot + atomic write + verification + rollback semantics. Returns the
/// updated `SkillRecord` so the UI can refresh the row in place.
pub fn toggle_skill(
    catalog: &Catalog,
    ctx: &AdapterContext,
    instance_id: &str,
    on: bool,
) -> Result<SkillRecord, CommandError> {
    let meta = catalog
        .get_skill_instance_meta(instance_id)?
        .ok_or_else(|| CommandError::InstanceNotFound(instance_id.to_string()))?;

    let config_target = config_target_for_instance(ctx, &meta)?;

    validate_config_write_target(
        ctx,
        config_target.agent,
        config_target.scope,
        &config_target.path,
    )?;
    let lock_file = lock_config(
        ctx,
        config_target.agent,
        config_target.scope,
        &config_target.path,
    )?;

    // 1. Read current settings (empty string if file does not exist yet).
    let original_text = if config_target.path.exists() {
        fs::read_to_string(&config_target.path)?
    } else {
        String::new()
    };

    // 2. Take a pre-toggle snapshot.
    let snapshot_id = generate_snapshot_id();
    let now_ms = current_time_ms();
    let snapshot_content = redact_snapshot_content(&original_text);
    catalog.create_config_snapshot(ConfigSnapshotDraft {
        id: &snapshot_id,
        agent: meta.agent.as_str(),
        scope: config_target.scope.as_str(),
        target: &config_target.path.to_string_lossy(),
        content: &snapshot_content,
        reason: "pre-toggle",
        created_at_ms: now_ms,
    })?;

    // 3. Apply the patch in memory.
    let mut doc = AgentConfigDocument {
        path: config_target.path.clone(),
        format: config_target.format,
        text: original_text.clone(),
    };
    let instance_for_patch = minimal_skill_instance(&meta);
    patch_enabled_for_agent(meta.agent, &mut doc, &instance_for_patch, on)?;

    // 4. Atomic write.
    write_config_atomic(
        ctx,
        config_target.agent,
        config_target.scope,
        &config_target.path,
        &doc.text,
    )?;

    // 5. Verify by reading back.
    let written = fs::read_to_string(&config_target.path)?;
    if written != doc.text {
        // Roll back to the snapshot content (best-effort; surface the failure).
        let _ = write_config_atomic(
            ctx,
            config_target.agent,
            config_target.scope,
            &config_target.path,
            &original_text,
        );
        lock_file.unlock()?;
        return Err(CommandError::VerificationFailed);
    }

    // File is now the authoritative source for skillOverrides; release the
    // lock before mutating the per-process catalog cache.
    lock_file.unlock()?;

    // 6. Update the catalog to reflect the new effective state.
    let new_state = if on { "loaded" } else { "disabled" };
    catalog.set_skill_toggle(instance_id, on, new_state)?;

    let target = config_target.path.to_string_lossy().to_string();
    let event_payload = serde_json::json!({
        "enabled": on,
        "agent": meta.agent.as_str(),
        "scope": meta.scope.as_str(),
        "target": target,
        "skill_name": meta.name.clone(),
        "config_scope": config_target.scope.as_str(),
        "previous_enabled": meta.enabled,
    });
    let event_payload = serde_json::to_string(&event_payload)?;
    catalog.create_skill_event(SkillEventDraft {
        instance_id,
        kind: "toggle",
        payload: &event_payload,
        occurred_at_ms: now_ms,
    })?;

    // 7. Return the updated record for the UI.
    catalog
        .get_skill_record(instance_id)?
        .ok_or_else(|| CommandError::InstanceNotFound(instance_id.to_string()))
}

#[derive(Debug, Clone)]
struct ConfigTarget {
    agent: AgentId,
    scope: Scope,
    path: PathBuf,
    format: ConfigFormat,
}

fn config_target_for_instance(
    ctx: &AdapterContext,
    meta: &SkillInstanceMeta,
) -> Result<ConfigTarget, CommandError> {
    if meta.scope == Scope::AgentProject
        && !project_record_matches_context(
            meta.project_root.as_deref(),
            ctx.project_root.as_deref(),
        )
    {
        return Err(CommandError::UnsafeConfigPath(
            "project skill does not belong to the current project context".to_string(),
        ));
    }

    match meta.agent {
        AgentId::ClaudeCode => config_target_for_claude(ctx, meta.scope),
        AgentId::Codex => match meta.scope {
            Scope::AgentGlobal | Scope::AgentProject => Ok(ConfigTarget {
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                path: codex_user_config_path(ctx),
                format: ConfigFormat::Toml,
            }),
            Scope::ToolGlobal => Err(CommandError::UnsupportedScope(meta.scope)),
            _ => Err(CommandError::UnsupportedScope(meta.scope)),
        },
        AgentId::Opencode => match meta.scope {
            Scope::AgentGlobal | Scope::AgentProject => Ok(ConfigTarget {
                agent: AgentId::Opencode,
                scope: meta.scope,
                path: opencode_config_path(ctx, meta.scope)?,
                format: ConfigFormat::Json,
            }),
            Scope::ToolGlobal => Err(CommandError::UnsupportedScope(meta.scope)),
            _ => Err(CommandError::UnsupportedScope(meta.scope)),
        },
        agent => Err(CommandError::UnsafeConfigPath(format!(
            "{} skills are not writable by config.toggleSkill",
            agent.as_str()
        ))),
    }
}

fn project_record_matches_context(
    record_project_root: Option<&Path>,
    current_project_root: Option<&Path>,
) -> bool {
    let (Some(record_project_root), Some(current_project_root)) =
        (record_project_root, current_project_root)
    else {
        return false;
    };
    if record_project_root == current_project_root {
        return true;
    }
    match (
        record_project_root.canonicalize(),
        current_project_root.canonicalize(),
    ) {
        (Ok(record), Ok(current)) => record == current,
        _ => false,
    }
}

fn config_target_for_claude(
    ctx: &AdapterContext,
    scope: Scope,
) -> Result<ConfigTarget, CommandError> {
    let path = match scope {
        Scope::AgentGlobal => ctx.user_home.join(".claude/settings.json"),
        Scope::AgentProject => ctx
            .project_root
            .as_ref()
            .map(|root| root.join(".claude/settings.local.json"))
            .ok_or(CommandError::UnsupportedScope(scope))?,
        Scope::ToolGlobal => return Err(CommandError::UnsupportedScope(scope)),
        // Scope is #[non_exhaustive]; unknown variants cannot be toggled.
        _ => return Err(CommandError::UnsupportedScope(scope)),
    };
    Ok(ConfigTarget {
        agent: AgentId::ClaudeCode,
        scope,
        path,
        format: ConfigFormat::Json,
    })
}

fn skill_install_target_path(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    skill_name: &str,
    project_path: Option<&Path>,
) -> Result<PathBuf, CommandError> {
    let root = skill_install_root(ctx, agent, scope, project_path)?;
    Ok(root
        .join(safe_install_dir_name(skill_name)?)
        .join("SKILL.md"))
}

fn skill_install_root(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    project_path: Option<&Path>,
) -> Result<PathBuf, CommandError> {
    match (agent, scope) {
        (AgentId::ClaudeCode, Scope::AgentGlobal) => Ok(ctx.user_home.join(".claude/skills")),
        (AgentId::ClaudeCode, Scope::AgentProject) => {
            Ok(target_project_root(ctx, project_path)?.join(".claude/skills"))
        }
        (AgentId::Codex, Scope::AgentGlobal) => Ok(ctx.user_home.join(".agents/skills")),
        (AgentId::Codex, Scope::AgentProject) => {
            Ok(target_project_root(ctx, project_path)?.join(".agents/skills"))
        }
        (AgentId::Opencode, Scope::AgentGlobal) => {
            Ok(ctx.user_home.join(".config/opencode/skills"))
        }
        (AgentId::Opencode, Scope::AgentProject) => {
            Ok(target_project_root(ctx, project_path)?.join(".opencode/skills"))
        }
        (_, Scope::ToolGlobal) => Err(CommandError::UnsupportedScope(scope)),
        (agent, _) => Err(CommandError::InstallUnsupported(format!(
            "{} skills are not writable by install commands",
            agent.as_str()
        ))),
    }
}

fn target_project_root(
    ctx: &AdapterContext,
    project_path: Option<&Path>,
) -> Result<PathBuf, CommandError> {
    let project_root = project_path
        .map(Path::to_path_buf)
        .or_else(|| ctx.project_root.clone())
        .ok_or(CommandError::UnsupportedScope(Scope::AgentProject))?;
    let canonical_project = project_root.canonicalize().map_err(|err| {
        CommandError::UnsafeConfigPath(format!(
            "project path {} cannot be canonicalized: {err}",
            project_root.display()
        ))
    })?;
    if !canonical_project.is_dir() {
        return Err(CommandError::UnsafeConfigPath(format!(
            "project path {} is not a directory",
            canonical_project.display()
        )));
    }
    if let Some(current_root) = &ctx.project_root {
        let canonical_current = current_root.canonicalize()?;
        if canonical_project != canonical_current {
            return Err(CommandError::UnsafeConfigPath(format!(
                "target project {} does not match current project context {}",
                canonical_project.display(),
                canonical_current.display()
            )));
        }
    }
    Ok(canonical_project)
}

fn install_scan_context(
    ctx: &AdapterContext,
    scope: Scope,
    project_path: Option<&Path>,
) -> Result<AdapterContext, CommandError> {
    if scope != Scope::AgentProject {
        return Ok(ctx.clone());
    }
    let project_root = target_project_root(ctx, project_path)?;
    Ok(AdapterContext {
        user_home: ctx.user_home.clone(),
        project_cwd: Some(project_root.clone()),
        project_root: Some(project_root),
        extra_roots: ctx.extra_roots.clone(),
    })
}

fn safe_install_dir_name(name: &str) -> Result<String, CommandError> {
    let name = name.trim();
    let invalid = name.is_empty()
        || name == "."
        || name == ".."
        || name.contains('/')
        || name.contains('\\')
        || name.bytes().any(|byte| byte == 0);
    if invalid {
        return Err(CommandError::UnsafeConfigPath(format!(
            "skill name `{name}` cannot be used as an install directory"
        )));
    }
    Ok(name.to_string())
}

fn install_preview_risks(agent: AgentId, scope: Scope, target_exists: bool) -> Vec<String> {
    let mut risks = vec![
        format!(
            "Will write into the {} {} skill root through the verified install path.",
            agent.as_str(),
            scope.as_str()
        ),
        "Only the tool-global SKILL.md source will be copied.".to_string(),
    ];
    if target_exists {
        risks.push(
            "Target SKILL.md already exists and will be replaced after snapshot.".to_string(),
        );
    }
    if agent == AgentId::Codex {
        risks.push(
            "Codex may need to be restarted before it reads newly installed user/project skills."
                .to_string(),
        );
    }
    risks
}

fn claude_global_settings_path(ctx: &AdapterContext) -> PathBuf {
    ctx.user_home.join(".claude/settings.json")
}

fn codex_user_config_path(ctx: &AdapterContext) -> PathBuf {
    let codex_home = env::var_os("CODEX_HOME").map(PathBuf::from);
    codex_user_config_path_for(ctx, codex_home.as_deref())
}

fn codex_user_config_path_for(ctx: &AdapterContext, codex_home: Option<&Path>) -> PathBuf {
    if let Some(codex_home) = codex_home {
        if should_honor_codex_home(ctx, codex_home) {
            return codex_home.join("config.toml");
        }
    }
    ctx.user_home.join(".codex/config.toml")
}

fn opencode_config_path(ctx: &AdapterContext, scope: Scope) -> Result<PathBuf, CommandError> {
    match scope {
        Scope::AgentGlobal => Ok(ctx.user_home.join(".config/opencode/opencode.json")),
        Scope::AgentProject => ctx
            .project_root
            .as_ref()
            .map(|root| root.join("opencode.json"))
            .ok_or(CommandError::UnsupportedScope(scope)),
        Scope::ToolGlobal => Err(CommandError::UnsupportedScope(scope)),
        _ => Err(CommandError::UnsupportedScope(scope)),
    }
}

fn should_honor_codex_home(ctx: &AdapterContext, codex_home: &Path) -> bool {
    codex_home.is_absolute()
        && normalize_path_lexically(codex_home)
            .starts_with(normalize_path_lexically(&ctx.user_home))
}

fn normalize_path_lexically(path: &Path) -> PathBuf {
    use std::path::Component;

    let mut normalized = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                if !normalized.pop() {
                    normalized.push(component.as_os_str());
                }
            }
            Component::Prefix(_) | Component::RootDir | Component::Normal(_) => {
                normalized.push(component.as_os_str());
            }
        }
    }
    normalized
}

fn scan_agent_id_to_catalog(
    agent: AgentId,
    ctx: &AdapterContext,
    catalog: &Catalog,
) -> Result<usize, CommandError> {
    match agent {
        AgentId::ClaudeCode => scan_single_agent_to_catalog(&ClaudeCodeAdapter, ctx, catalog),
        AgentId::Codex => scan_single_agent_to_catalog(&CodexAdapter, ctx, catalog),
        AgentId::Opencode => scan_single_agent_to_catalog(&OpencodeAdapter, ctx, catalog),
        AgentId::Pi => scan_single_agent_to_catalog(&PiAdapter, ctx, catalog),
        AgentId::Openclaw => scan_single_agent_to_catalog(&OpenclawAdapter, ctx, catalog),
        AgentId::Hermes => scan_single_agent_to_catalog(&HermesAdapter, ctx, catalog),
        agent => Err(CommandError::UnsafeConfigPath(format!(
            "{} skills are not supported by scan commands",
            agent.as_str()
        ))),
    }
}

fn patch_enabled_for_agent(
    agent: AgentId,
    doc: &mut AgentConfigDocument,
    instance: &SkillInstance,
    on: bool,
) -> Result<(), CommandError> {
    match agent {
        AgentId::ClaudeCode => ClaudeCodeAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        AgentId::Codex => CodexAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        AgentId::Opencode => OpencodeAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        agent => Err(CommandError::UnsafeConfigPath(format!(
            "{} skills are not writable by config.toggleSkill",
            agent.as_str()
        ))),
    }
}

fn minimal_skill_instance(meta: &SkillInstanceMeta) -> SkillInstance {
    SkillInstance {
        id: meta.id.clone(),
        agent: meta.agent,
        scope: meta.scope,
        project_root: meta.project_root.clone(),
        path: meta.path.clone(),
        display_path: meta.path.clone(),
        definition_id: String::new(),
        name: meta.name.clone(),
        display_name: meta.name.clone(),
        description: String::new(),
        version: None,
        state: SkillState::Loaded,
        enabled: meta.enabled,
        frontmatter_raw: String::new(),
        body: String::new(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: String::new(),
        mtime: 0,
        first_seen: 0,
        last_seen: 0,
    }
}

fn preview_context_from_snapshot(
    snapshot: &ConfigSnapshotRecord,
) -> Result<AdapterContext, CommandError> {
    let target = PathBuf::from(&snapshot.target);
    let scope = scope_from_snapshot(&snapshot.scope)?;
    let agent = agent_from_snapshot(&snapshot.agent)?;
    let parent = target.parent().ok_or_else(|| {
        CommandError::UnsafeConfigPath("snapshot target has no parent".to_string())
    })?;

    match (agent, scope) {
        (AgentId::ClaudeCode, Scope::AgentGlobal) => {
            if target.file_name().and_then(|name| name.to_str()) != Some("settings.json")
                || parent.file_name().and_then(|name| name.to_str()) != Some(".claude")
            {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not a Claude global settings path",
                    target.display()
                )));
            }
            let user_home = parent
                .parent()
                .ok_or_else(|| {
                    CommandError::UnsafeConfigPath(
                        "Claude global settings target has no user home".to_string(),
                    )
                })?
                .to_path_buf();
            Ok(AdapterContext {
                user_home,
                project_root: None,
                project_cwd: None,
                extra_roots: vec![],
            })
        }
        (AgentId::ClaudeCode, Scope::AgentProject) => {
            if target.file_name().and_then(|name| name.to_str()) != Some("settings.local.json")
                || parent.file_name().and_then(|name| name.to_str()) != Some(".claude")
            {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not a Claude project settings path",
                    target.display()
                )));
            }
            let project_root = parent
                .parent()
                .ok_or_else(|| {
                    CommandError::UnsafeConfigPath(
                        "Claude project settings target has no project root".to_string(),
                    )
                })?
                .to_path_buf();
            Ok(AdapterContext {
                user_home: project_root.clone(),
                project_root: Some(project_root),
                project_cwd: None,
                extra_roots: vec![],
            })
        }
        (AgentId::Codex, Scope::AgentGlobal) => {
            if target.file_name().and_then(|name| name.to_str()) != Some("config.toml") {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not a Codex user config path",
                    target.display()
                )));
            }
            let parent_is_codex_home = parent.file_name().and_then(|name| name.to_str())
                == Some(".codex")
                || env::var_os("CODEX_HOME")
                    .map(PathBuf::from)
                    .is_some_and(|codex_home| normalize_path_lexically(&codex_home) == parent);
            if !parent_is_codex_home {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not a Codex user config path",
                    target.display()
                )));
            }
            let user_home = parent
                .parent()
                .ok_or_else(|| {
                    CommandError::UnsafeConfigPath(
                        "Codex config target has no user home".to_string(),
                    )
                })?
                .to_path_buf();
            Ok(AdapterContext {
                user_home,
                project_root: None,
                project_cwd: None,
                extra_roots: vec![],
            })
        }
        (AgentId::Opencode, Scope::AgentGlobal) => {
            if target.file_name().and_then(|name| name.to_str()) != Some("opencode.json")
                || parent.file_name().and_then(|name| name.to_str()) != Some("opencode")
            {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not an opencode global config path",
                    target.display()
                )));
            }
            let user_home = parent
                .parent()
                .and_then(Path::parent)
                .ok_or_else(|| {
                    CommandError::UnsafeConfigPath(
                        "opencode global config target has no user home".to_string(),
                    )
                })?
                .to_path_buf();
            Ok(AdapterContext {
                user_home,
                project_root: None,
                project_cwd: None,
                extra_roots: vec![],
            })
        }
        (AgentId::Opencode, Scope::AgentProject) => {
            if target.file_name().and_then(|name| name.to_str()) != Some("opencode.json") {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "snapshot target {} is not an opencode project config path",
                    target.display()
                )));
            }
            let project_root = parent.to_path_buf();
            Ok(AdapterContext {
                user_home: project_root.clone(),
                project_root: Some(project_root),
                project_cwd: None,
                extra_roots: vec![],
            })
        }
        _ => Err(CommandError::UnsafeConfigPath(format!(
            "snapshot agent {} scope {} is not previewable",
            snapshot.agent, snapshot.scope
        ))),
    }
}

fn scope_from_snapshot(scope: &str) -> Result<Scope, CommandError> {
    if scope == Scope::AgentGlobal.as_str() {
        Ok(Scope::AgentGlobal)
    } else if scope == Scope::AgentProject.as_str() {
        Ok(Scope::AgentProject)
    } else {
        Err(CommandError::UnsafeConfigPath(format!(
            "snapshot scope {scope} is not writable"
        )))
    }
}

fn agent_from_snapshot(agent: &str) -> Result<AgentId, CommandError> {
    match agent {
        "claude-code" => Ok(AgentId::ClaudeCode),
        "codex" => Ok(AgentId::Codex),
        "opencode" => Ok(AgentId::Opencode),
        other => Err(CommandError::UnsafeConfigPath(format!(
            "snapshot agent {other} is not writable by config rollback commands"
        ))),
    }
}

fn expected_config_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
) -> Result<ConfigTarget, CommandError> {
    match agent {
        AgentId::ClaudeCode => config_target_for_claude(ctx, scope),
        AgentId::Codex => {
            if scope != Scope::AgentGlobal {
                return Err(CommandError::UnsafeConfigPath(format!(
                    "codex config writes use user config scope only; snapshot scope {} is not writable",
                    scope.as_str()
                )));
            }
            Ok(ConfigTarget {
                agent,
                scope,
                path: codex_user_config_path(ctx),
                format: ConfigFormat::Toml,
            })
        }
        AgentId::Opencode => Ok(ConfigTarget {
            agent,
            scope,
            path: opencode_config_path(ctx, scope)?,
            format: ConfigFormat::Json,
        }),
        agent => Err(CommandError::UnsafeConfigPath(format!(
            "{} config writes are not supported",
            agent.as_str()
        ))),
    }
}

fn validate_config_write_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
) -> Result<(), CommandError> {
    let expected = expected_config_target(ctx, agent, scope)?;
    if path != expected.path.as_path() {
        return Err(CommandError::UnsafeConfigPath(format!(
            "{} does not match expected {} config path {}",
            path.display(),
            agent.as_str(),
            expected.path.display()
        )));
    }

    let allowed_root = match scope {
        Scope::AgentGlobal if agent == AgentId::Codex => &ctx.user_home,
        Scope::AgentGlobal => &ctx.user_home,
        Scope::AgentProject if matches!(agent, AgentId::ClaudeCode | AgentId::Opencode) => ctx
            .project_root
            .as_ref()
            .ok_or(CommandError::UnsupportedScope(scope))?,
        Scope::ToolGlobal => return Err(CommandError::UnsupportedScope(scope)),
        _ => return Err(CommandError::UnsupportedScope(scope)),
    };
    let parent = path
        .parent()
        .ok_or_else(|| CommandError::UnsafeConfigPath("config path has no parent".to_string()))?;
    fs::create_dir_all(parent)?;

    reject_symlink(parent, "config directory")?;
    reject_symlink(path, "config file")?;

    let canonical_root = allowed_root.canonicalize()?;
    let canonical_parent = parent.canonicalize()?;
    if !canonical_parent.starts_with(&canonical_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "config directory {} resolves outside allowed root {}",
            canonical_parent.display(),
            canonical_root.display()
        )));
    }

    Ok(())
}

fn validate_tool_global_source(path: &Path) -> Result<(), CommandError> {
    if path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md") {
        return Err(CommandError::UnsafeConfigPath(format!(
            "tool-global source {} is not a SKILL.md file",
            path.display()
        )));
    }
    reject_symlink(path, "tool-global source file")?;
    let metadata = fs::metadata(path)?;
    if !metadata.is_file() {
        return Err(CommandError::UnsafeConfigPath(format!(
            "tool-global source {} is not a regular file",
            path.display()
        )));
    }
    Ok(())
}

fn validate_skill_install_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
    project_path: Option<&Path>,
    create_dirs: bool,
) -> Result<(), CommandError> {
    let expected_root = skill_install_root(ctx, agent, scope, project_path)?;
    let expected_target = expected_root
        .join(path.parent().and_then(Path::file_name).ok_or_else(|| {
            CommandError::UnsafeConfigPath("install target has no skill directory".to_string())
        })?)
        .join("SKILL.md");
    if path != expected_target.as_path() {
        return Err(CommandError::UnsafeConfigPath(format!(
            "{} does not match expected {} install target {}",
            path.display(),
            agent.as_str(),
            expected_target.display()
        )));
    }
    if path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md") {
        return Err(CommandError::UnsafeConfigPath(format!(
            "install target {} is not a SKILL.md path",
            path.display()
        )));
    }

    let allowed_root = match scope {
        Scope::AgentGlobal => ctx.user_home.clone(),
        Scope::AgentProject => target_project_root(ctx, project_path)?,
        Scope::ToolGlobal => return Err(CommandError::UnsupportedScope(scope)),
        _ => return Err(CommandError::UnsupportedScope(scope)),
    };
    if create_dirs {
        fs::create_dir_all(&expected_root)?;
    }
    let parent = path.parent().ok_or_else(|| {
        CommandError::UnsafeConfigPath("install target has no parent".to_string())
    })?;
    if create_dirs {
        fs::create_dir_all(parent)?;
    }

    reject_symlink(&expected_root, "install root")?;
    reject_symlink(parent, "install skill directory")?;
    reject_symlink(path, "install target file")?;

    let canonical_allowed_root = allowed_root.canonicalize()?;
    let normalized_install_root = normalize_path_lexically(&expected_root);
    let normalized_parent = normalize_path_lexically(parent);
    let normalized_allowed_root = normalize_path_lexically(&allowed_root);
    if !normalized_install_root.starts_with(&normalized_allowed_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "install root {} is outside allowed root {}",
            expected_root.display(),
            allowed_root.display()
        )));
    }
    if !normalized_parent.starts_with(&normalized_install_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "install target directory {} is outside install root {}",
            parent.display(),
            expected_root.display()
        )));
    }
    if expected_root.exists() {
        let canonical_install_root = expected_root.canonicalize()?;
        if !canonical_install_root.starts_with(&canonical_allowed_root) {
            return Err(CommandError::UnsafeConfigPath(format!(
                "install root {} resolves outside allowed root {}",
                canonical_install_root.display(),
                canonical_allowed_root.display()
            )));
        }
    }
    if parent.exists() {
        let canonical_install_root = expected_root.canonicalize()?;
        let canonical_parent = parent.canonicalize()?;
        if !canonical_parent.starts_with(&canonical_install_root) {
            return Err(CommandError::UnsafeConfigPath(format!(
                "install target directory {} resolves outside install root {}",
                canonical_parent.display(),
                canonical_install_root.display()
            )));
        }
    }
    Ok(())
}

fn reject_symlink(path: &Path, label: &str) -> Result<(), CommandError> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(CommandError::UnsafeConfigPath(
            format!("{label} is a symlink: {}", path.display()),
        )),
        Ok(_) => Ok(()),
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(err) => Err(err.into()),
    }
}

fn write_config_atomic(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
    content: &str,
) -> Result<(), CommandError> {
    validate_config_write_target(ctx, agent, scope, path)?;
    let parent = path
        .parent()
        .ok_or_else(|| CommandError::UnsafeConfigPath("config path has no parent".to_string()))?;
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| {
            CommandError::UnsafeConfigPath("config path has no file name".to_string())
        })?;
    let tmp = parent.join(format!(
        ".{file_name}.{}.{}.tmp",
        std::process::id(),
        current_time_ms()
    ));

    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut tmp_file = options.open(&tmp)?;
    set_private_file_permissions(&tmp_file)?;
    tmp_file.write_all(content.as_bytes())?;
    tmp_file.sync_all()?;
    drop(tmp_file);

    validate_config_write_target(ctx, agent, scope, path)?;
    let rename_result = fs::rename(&tmp, path);
    if rename_result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    rename_result?;
    set_private_path_permissions(path)?;
    validate_config_write_target(ctx, agent, scope, path)?;
    if let Ok(parent_dir) = fs::File::open(parent) {
        let _ = parent_dir.sync_all();
    }
    Ok(())
}

fn write_skill_file_atomic(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
    content: &str,
    project_path: Option<&Path>,
) -> Result<(), CommandError> {
    validate_skill_install_target(ctx, agent, scope, path, project_path, true)?;
    let parent = path.parent().ok_or_else(|| {
        CommandError::UnsafeConfigPath("install target has no parent".to_string())
    })?;
    let tmp = parent.join(format!(
        ".SKILL.md.{}.{}.tmp",
        std::process::id(),
        current_time_ms()
    ));

    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut tmp_file = options.open(&tmp)?;
    set_private_file_permissions(&tmp_file)?;
    tmp_file.write_all(content.as_bytes())?;
    tmp_file.sync_all()?;
    drop(tmp_file);

    validate_skill_install_target(ctx, agent, scope, path, project_path, true)?;
    let rename_result = fs::rename(&tmp, path);
    if rename_result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    rename_result?;
    set_private_path_permissions(path)?;
    validate_skill_install_target(ctx, agent, scope, path, project_path, true)?;
    if let Ok(parent_dir) = fs::File::open(parent) {
        let _ = parent_dir.sync_all();
    }
    Ok(())
}

#[cfg(unix)]
fn set_private_file_permissions(file: &fs::File) -> Result<(), CommandError> {
    use std::os::unix::fs::PermissionsExt;

    file.set_permissions(fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(not(unix))]
fn set_private_file_permissions(_file: &fs::File) -> Result<(), CommandError> {
    Ok(())
}

#[cfg(unix)]
fn set_private_path_permissions(path: &Path) -> Result<(), CommandError> {
    use std::os::unix::fs::PermissionsExt;

    fs::set_permissions(path, fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(not(unix))]
fn set_private_path_permissions(_path: &Path) -> Result<(), CommandError> {
    Ok(())
}

fn write_locked(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
    content: &str,
) -> Result<(), CommandError> {
    let lock_file = lock_config(ctx, agent, scope, path)?;
    let result = write_config_atomic(ctx, agent, scope, path, content);
    lock_file.unlock()?;
    result
}

fn lock_config(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
) -> Result<fs::File, CommandError> {
    validate_config_write_target(ctx, agent, scope, path)?;
    let lock_path = path.with_extension("lock");
    reject_symlink(&lock_path, "config lock file")?;
    let mut options = fs::OpenOptions::new();
    options.create(true).read(true).write(true).truncate(false);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let lock_file = options.open(&lock_path)?;
    set_private_file_permissions(&lock_file)?;
    reject_symlink(&lock_path, "config lock file")?;
    lock_file.lock_exclusive()?;
    Ok(lock_file)
}

fn lock_install_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
    project_path: Option<&Path>,
) -> Result<fs::File, CommandError> {
    validate_skill_install_target(ctx, agent, scope, path, project_path, true)?;
    let lock_path = path.with_extension("lock");
    reject_symlink(&lock_path, "install lock file")?;
    let mut options = fs::OpenOptions::new();
    options.create(true).read(true).write(true).truncate(false);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let lock_file = options.open(&lock_path)?;
    set_private_file_permissions(&lock_file)?;
    reject_symlink(&lock_path, "install lock file")?;
    lock_file.lock_exclusive()?;
    Ok(lock_file)
}

fn apply_codex_config_overrides(
    ctx: &AdapterContext,
    instances: &mut [SkillInstance],
) -> Result<(), CommandError> {
    let disabled_paths = codex_disabled_skill_paths(&codex_user_config_path(ctx))?;
    if disabled_paths.is_empty() {
        return Ok(());
    }
    for instance in instances.iter_mut() {
        if disabled_paths
            .iter()
            .any(|disabled_path| disabled_path == &instance.path)
        {
            instance.enabled = false;
            instance.state = SkillState::Disabled;
        }
    }
    Ok(())
}

fn codex_disabled_skill_paths(path: &Path) -> Result<Vec<PathBuf>, CommandError> {
    let content = match fs::read_to_string(path) {
        Ok(content) => content,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(err.into()),
    };
    Ok(parse_codex_skill_config_entries(&content)
        .into_iter()
        .filter(|block| block.enabled == Some(false))
        .filter_map(|block| block.path.map(PathBuf::from))
        .collect())
}

const REDACTED_SNAPSHOT_PREFIX: &str = "# skills-copilot: snapshot content redacted\n";
const REDACTED_VALUE: &str = "[REDACTED]";

fn redact_snapshot_content(content: &str) -> String {
    if content.is_empty() || is_redacted_snapshot_content(content) {
        return content.to_string();
    }

    if let Ok(mut value) = serde_json::from_str::<serde_json::Value>(content) {
        if redact_json_value(&mut value) {
            let rendered =
                serde_json::to_string_pretty(&value).unwrap_or_else(|_| content.to_string());
            return format!("{REDACTED_SNAPSHOT_PREFIX}{rendered}\n");
        }
        return content.to_string();
    }

    let redacted = content
        .lines()
        .map(redact_simple_secret_line)
        .collect::<Vec<_>>()
        .join("\n");
    let redacted = if content.ends_with('\n') {
        format!("{redacted}\n")
    } else {
        redacted
    };
    if redacted == content {
        content.to_string()
    } else {
        format!("{REDACTED_SNAPSHOT_PREFIX}{redacted}")
    }
}

fn is_redacted_snapshot_content(content: &str) -> bool {
    content.starts_with(REDACTED_SNAPSHOT_PREFIX)
}

fn redact_json_value(value: &mut serde_json::Value) -> bool {
    match value {
        serde_json::Value::Object(map) => {
            let mut changed = false;
            for (key, value) in map {
                if is_sensitive_key(key) {
                    if !matches!(
                        value,
                        serde_json::Value::String(redacted) if redacted == REDACTED_VALUE
                    ) {
                        *value = serde_json::Value::String(REDACTED_VALUE.to_string());
                        changed = true;
                    }
                } else {
                    changed |= redact_json_value(value);
                }
            }
            changed
        }
        serde_json::Value::Array(values) => {
            let mut changed = false;
            for value in values {
                changed |= redact_json_value(value);
            }
            changed
        }
        _ => false,
    }
}

fn redact_simple_secret_line(line: &str) -> String {
    let Some((key_part, value_part, separator)) = split_assignment_line(line) else {
        return line.to_string();
    };
    let key = key_part.trim().trim_matches('"').trim_matches('\'');
    if !is_sensitive_key(key) {
        return line.to_string();
    }
    let trailing_comma = value_part.trim_end().ends_with(',');
    let comment = value_part.find('#').map(|idx| &value_part[idx..]);
    let suffix = match (trailing_comma, comment) {
        (true, Some(comment)) => format!(", {comment}"),
        (true, None) => ",".to_string(),
        (false, Some(comment)) => format!(" {comment}"),
        (false, None) => String::new(),
    };
    format!("{key_part}{separator} \"{REDACTED_VALUE}\"{suffix}")
}

fn split_assignment_line(line: &str) -> Option<(&str, &str, &'static str)> {
    if let Some((key, value)) = line.split_once('=') {
        return Some((key, value, "="));
    }
    line.split_once(':').map(|(key, value)| (key, value, ":"))
}

fn is_sensitive_key(key: &str) -> bool {
    let normalized: String = key
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric())
        .flat_map(char::to_lowercase)
        .collect();
    matches!(
        normalized.as_str(),
        "apikey"
            | "token"
            | "accesstoken"
            | "refreshtoken"
            | "secret"
            | "clientsecret"
            | "password"
            | "passwd"
    ) || normalized.ends_with("token")
        || normalized.ends_with("secret")
        || normalized.ends_with("password")
}

fn generate_snapshot_id() -> String {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("snap-{nanos:x}")
}

fn current_time_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use std::{
        path::{Path, PathBuf},
        time::{Instant, SystemTime, UNIX_EPOCH},
    };

    use skills_copilot_catalog::Catalog;
    use skills_copilot_core::{
        AdapterContext, AdapterRoot, AgentId, NetworkAccess, PermissionRequest, RootSource,
        SkillInstance, SkillState,
    };

    use super::*;

    #[test]
    fn script_execution_preview_is_disabled_and_redacts_env_values() {
        let root = temp_test_dir("script-preview");
        let ctx = AdapterContext {
            user_home: root.join("home"),
            project_root: Some(root.clone()),
            project_cwd: Some(root.join("project")),
            extra_roots: Vec::new(),
        };
        let request = ScriptExecutionRequest {
            command: vec!["python3".to_string(), "scripts/task.py".to_string()],
            cwd: Some(PathBuf::from("work")),
            env: std::collections::BTreeMap::from([(
                "API_TOKEN".to_string(),
                "fixture-redacted-value".to_string(),
            )]),
            network: Some("full".to_string()),
            files: vec!["./src/**".to_string()],
            skill_instance_id: Some("skill-fixture".to_string()),
            initiated_by: ScriptExecutionInitiator::User,
            confirmed: false,
        };

        let preview = preview_script_execution(&ctx, &request).expect("preview");

        assert!(!preview.execution_allowed);
        assert!(preview.initiator_allowed);
        assert_eq!(preview.cwd.source, "request-relative");
        assert_eq!(preview.env.provided_keys, vec!["API_TOKEN".to_string()]);
        assert_eq!(preview.env.value_policy, "values-redacted");
        assert!(!preview.network.allowed);
        assert!(!preview.files.read_allowed);
        assert!(!preview.files.write_allowed);
        assert!(preview.confirmation.required);
        let serialized = serde_json::to_string(&preview).expect("serialize preview");
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn blocked_script_execution_writes_app_data_audit_only() {
        let root = temp_test_dir("script-audit");
        let ctx = AdapterContext {
            user_home: root.join("home"),
            project_root: Some(root.join("project")),
            project_cwd: Some(root.join("project")),
            extra_roots: Vec::new(),
        };
        let audit_path = root.join("app-data/audit/script-execution.jsonl");
        let skill_dir = root.join("project/skills/demo");
        std::fs::create_dir_all(&skill_dir).expect("create skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(&skill_path, "name: demo\n").expect("write skill");
        let before = std::fs::read_to_string(&skill_path).expect("read skill");
        let request = ScriptExecutionRequest {
            command: vec![
                "sh".to_string(),
                "-c".to_string(),
                "touch marker".to_string(),
            ],
            cwd: None,
            env: std::collections::BTreeMap::new(),
            network: None,
            files: Vec::new(),
            skill_instance_id: Some("skill-fixture".to_string()),
            initiated_by: ScriptExecutionInitiator::Llm,
            confirmed: true,
        };

        let record =
            record_blocked_script_execution(&ctx, &audit_path, &request).expect("blocked record");

        assert_eq!(record.status, "blocked");
        assert_eq!(record.outcome, "llm_initiator_not_allowed");
        assert!(!record.spawned_process);
        assert!(!root.join("project/marker").exists());
        assert_eq!(
            std::fs::read_to_string(&skill_path).expect("read skill after"),
            before,
            "audit must not write to skill files"
        );
        let audit_content = std::fs::read_to_string(&audit_path).expect("read audit");
        assert!(audit_content.contains("llm_initiator_not_allowed"));

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn imports_local_skill_to_tool_global_staging_and_refreshes_audit() {
        let root = temp_test_dir("tool-global-import");
        let source = root.join("source/local-skill");
        let staging = root.join("app-data/tool-global-staging");
        let user_home = root.join("home");
        std::fs::create_dir_all(&source).expect("create source");
        std::fs::create_dir_all(user_home.join(".claude")).expect("create claude dir");
        let claude_settings = user_home.join(".claude/settings.json");
        std::fs::write(
            &claude_settings,
            "{\"skillOverrides\":{\"existing\":\"off\"}}\n",
        )
        .expect("write claude settings");
        std::fs::write(
            source.join("SKILL.md"),
            "---\nname: Imported Skill\ndescription: Imported fixture\ntools:\n  - bash\n---\nRun `curl https://example.test/data.json`.\n",
        )
        .expect("write skill");
        std::fs::write(source.join("notes.txt"), "copied supporting file")
            .expect("write support file");
        let catalog = Catalog::in_memory().expect("catalog");
        catalog.init().expect("init catalog");
        let ctx = AdapterContext {
            user_home: user_home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: Vec::new(),
        };

        let result =
            import_local_skill_to_tool_global(&catalog, &ctx, &staging, &source).expect("import");

        assert_eq!(result.imported.agent, "tool-global");
        assert_eq!(result.imported.scope, "tool-global");
        assert_eq!(result.imported.name, "Imported Skill");
        assert!(result.audit.read_only_preview);
        assert!(PathBuf::from(&result.staging_path).starts_with(
            staging
                .join("skills")
                .canonicalize()
                .expect("canonical staging skills root")
        ));
        assert!(PathBuf::from(&result.staging_path).exists());
        assert!(PathBuf::from(&result.staging_path)
            .parent()
            .expect("staged parent")
            .join("notes.txt")
            .exists());
        assert_eq!(
            std::fs::read_to_string(&claude_settings).expect("read settings"),
            "{\"skillOverrides\":{\"existing\":\"off\"}}\n"
        );
        assert!(
            result
                .findings
                .iter()
                .any(|finding| finding.rule_id == "name.canonical-case"),
            "import should run local rule audit for staged content"
        );
        let catalog_findings = list_findings(&catalog).expect("list findings");
        assert!(
            catalog_findings
                .iter()
                .any(|finding| finding.instance_id.as_deref() == Some(result.instance_id.as_str())),
            "import should refresh catalog findings"
        );

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn import_local_skill_rejects_missing_skill_md() {
        let root = temp_test_dir("tool-global-import-missing");
        let source = root.join("source/no-skill");
        std::fs::create_dir_all(&source).expect("create source");
        let catalog = Catalog::in_memory().expect("catalog");
        catalog.init().expect("init catalog");
        let ctx = AdapterContext {
            user_home: root.join("home"),
            project_root: None,
            project_cwd: None,
            extra_roots: Vec::new(),
        };

        let error =
            import_local_skill_to_tool_global(&catalog, &ctx, &root.join("staging"), &source)
                .expect_err("missing SKILL.md should fail");

        assert!(matches!(error, CommandError::InvalidImportSource(_)));
        assert!(!root.join("staging/skills").exists());

        let _ = std::fs::remove_dir_all(root);
    }

    #[cfg(unix)]
    #[test]
    fn import_local_skill_rejects_source_symlink_escape() {
        let root = temp_test_dir("tool-global-import-symlink");
        let source = root.join("source/symlink-skill");
        let outside = root.join("outside");
        std::fs::create_dir_all(&source).expect("create source");
        std::fs::create_dir_all(&outside).expect("create outside");
        std::fs::write(
            source.join("SKILL.md"),
            "---\nname: symlink-skill\ndescription: symlink fixture\n---\nbody\n",
        )
        .expect("write skill");
        std::os::unix::fs::symlink(&outside, source.join("outside-link")).expect("create symlink");
        let catalog = Catalog::in_memory().expect("catalog");
        catalog.init().expect("init catalog");
        let ctx = AdapterContext {
            user_home: root.join("home"),
            project_root: None,
            project_cwd: None,
            extra_roots: Vec::new(),
        };

        let error =
            import_local_skill_to_tool_global(&catalog, &ctx, &root.join("staging"), &source)
                .expect_err("symlink should fail");

        assert!(matches!(error, CommandError::InvalidImportSource(_)));

        let _ = std::fs::remove_dir_all(root);
    }

    #[test]
    fn v28_local_rules_flag_permission_script_and_dependency_findings() {
        let network = local_rule_instance(
            "network",
            "name: network\ndescription: network\n",
            "Run `curl https://example.test/report.json` before summarizing.",
        );
        let mut exec = local_rule_instance(
            "exec",
            "name: exec\ndescription: exec\npermissions:\n  exec: true\n",
            "Run the generated command.",
        );
        exec.permissions.exec = true;
        exec.permissions.exec_declared = true;
        let shebang = local_rule_instance(
            "shebang",
            "name: shebang\ndescription: shebang\nscript: |\n  #!/bin/sh\n  echo hi\n",
            "No body script.",
        );
        let dependency = local_rule_instance(
            "dependency",
            "name: dependency\ndescription: dependency\ndependencies:\n  - requests\n",
            "No dependency body.",
        );
        let mut report = RuleReport::default();

        append_v28_local_rule_findings(&[network, exec, shebang, dependency], &mut report);

        assert_rule_present(&report, "permissions.network-declared");
        assert_rule_present(&report, "permissions.exec-needs-human");
        assert_rule_present(&report, "script.no-shebang");
        assert_rule_present(&report, "dependency.unknown");
        for finding in &report.findings {
            assert_eq!(finding.severity, Severity::Warn);
            assert!(finding.suggestion.as_deref().is_some_and(|s| !s.is_empty()));
            assert!(!finding.message.is_empty());
        }
    }

    #[test]
    fn v28_local_rules_do_not_infer_unknown_or_missing_fields_as_safe() {
        let mut unknown_network = local_rule_instance(
            "unknown-network",
            "name: unknown-network\ndescription: unknown\n",
            "Run `curl https://example.test/report.json`.",
        );
        unknown_network.permissions.network = NetworkAccess::Unknown("internet".to_string());
        unknown_network.permissions.network_declared = true;
        let mut explicit_human = local_rule_instance(
            "explicit-human",
            "name: explicit-human\ndescription: exec\nrequires_human: true\npermissions:\n  exec: true\n",
            "Run the command.",
        );
        explicit_human.permissions.exec = true;
        explicit_human.permissions.exec_declared = true;
        let no_dependencies = local_rule_instance(
            "no-dependencies",
            "name: no-dependencies\ndescription: no deps\n",
            "This skill has no dependency declarations.",
        );
        let known_dependencies = local_rule_instance(
            "known-dependencies",
            "name: known-dependencies\ndescription: known deps\ndependencies:\n  - python3\n  - ./tools/local-helper\n",
            "Known local dependencies only.",
        );
        let mut report = RuleReport::default();

        append_v28_local_rule_findings(
            &[
                unknown_network,
                explicit_human,
                no_dependencies,
                known_dependencies,
            ],
            &mut report,
        );

        assert_rule_absent(&report, "permissions.network-declared");
        assert_rule_absent(&report, "permissions.exec-needs-human");
        assert_rule_absent(&report, "dependency.unknown");
    }

    #[test]
    fn scans_claude_fixtures_into_catalog() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: fixture_path("fixtures/claude-code/empty-home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: fixture_path("fixtures/claude-code/personal"),
                source: RootSource::Extra,
            }],
        };

        let count = scan_claude_to_catalog(&ctx, &catalog).expect("scan succeeds");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(count, 1);
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].name, "summarize-changes");
    }

    #[test]
    fn scan_all_includes_claude_and_codex_fixtures() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: fixture_path("fixtures/codex/user-home"),
            project_root: Some(fixture_path("fixtures/codex/project")),
            project_cwd: Some(fixture_path("fixtures/codex/project/nested")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: fixture_path("fixtures/claude-code/personal"),
                source: RootSource::Extra,
            }],
        };

        let count = scan_all_to_catalog(&ctx, &catalog).expect("scan all succeeds");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(count, 8);
        assert!(
            records
                .iter()
                .any(|record| record.agent == "claude-code" && record.name == "summarize-changes"),
            "Claude Code fixture should still be scanned"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "codex" && record.name == "user-alpha"),
            "Codex fixture should be included in scanAll"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "codex" && record.name == "repo-beta"),
            "Codex repo-root fixture should be included in scanAll"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "codex" && record.name == "nested-gamma"),
            "Codex nested cwd fixture should be included in scanAll"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "openclaw" && record.name == "user-alpha"),
            "OpenClaw should include documented shared ~/.agents/skills user roots"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "opencode" && record.name == "user-alpha"),
            "opencode should include documented shared ~/.agents/skills user roots"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "opencode" && record.name == "repo-beta"),
            "opencode should include documented project .agents/skills compatibility roots"
        );
        assert!(
            records
                .iter()
                .any(|record| record.agent == "opencode" && record.name == "nested-gamma"),
            "opencode should include nested project .agents/skills compatibility roots"
        );
    }

    #[test]
    fn scan_all_report_splits_agent_counts_and_roots() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: fixture_path("fixtures/codex/user-home"),
            project_root: Some(fixture_path("fixtures/codex/project")),
            project_cwd: Some(fixture_path("fixtures/codex/project/nested")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: fixture_path("fixtures/claude-code/personal"),
                source: RootSource::Extra,
            }],
        };

        let report = scan_all_catalog_report(&ctx, &catalog).expect("scan all succeeds");

        assert_eq!(report.scanned_count, 8);
        let claude = report
            .agents
            .iter()
            .find(|agent| agent.agent == AgentId::ClaudeCode)
            .expect("Claude Code report");
        assert_eq!(claude.display_name, "Claude Code");
        assert_eq!(claude.scanned_count, 1);
        assert!(claude
            .roots_considered
            .iter()
            .any(|root| root.ends_with("fixtures/claude-code/personal")));
        let codex = report
            .agents
            .iter()
            .find(|agent| agent.agent == AgentId::Codex)
            .expect("Codex report");
        assert_eq!(codex.display_name, "Codex");
        assert_eq!(codex.scanned_count, 3);
        assert_eq!(
            codex.scanned_roots.len(),
            3,
            "Codex scans user, repo, and nested cwd roots"
        );
        let opencode = report
            .agents
            .iter()
            .find(|agent| agent.agent == AgentId::Opencode)
            .expect("opencode report");
        assert_eq!(opencode.display_name, "opencode");
        assert_eq!(opencode.scanned_count, 3);
        assert_eq!(
            opencode.scanned_roots.len(),
            3,
            "opencode scans user, repo, and nested cwd .agents compatibility roots"
        );
        let openclaw = report
            .agents
            .iter()
            .find(|agent| agent.agent == AgentId::Openclaw)
            .expect("OpenClaw report");
        assert_eq!(openclaw.display_name, "OpenClaw");
        assert_eq!(openclaw.scanned_count, 1);
    }

    #[test]
    fn exports_tool_global_manifest_stably_without_absolute_reproducible_paths() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-export-stable-{}",
            std::process::id()
        ));
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let instance = tool_global_instance(
            "tool-global-export-id",
            &temp_root.join("staging/prompt/SKILL.md"),
        );
        catalog
            .upsert_skill_instance(&instance)
            .expect("upsert tool-global instance");

        let first =
            export_skill_bundle(&catalog, "tool-global-export-id", &temp_root.join("out-a"))
                .expect("first export");
        let second =
            export_skill_bundle(&catalog, "tool-global-export-id", &temp_root.join("out-b"))
                .expect("second export");
        let first_manifest =
            std::fs::read_to_string(&first.manifest_path).expect("read first manifest");
        let second_manifest =
            std::fs::read_to_string(&second.manifest_path).expect("read second manifest");

        assert_eq!(
            first_manifest, second_manifest,
            "manifest content must be byte-stable across repeated exports"
        );
        assert!(
            !first_manifest.contains(&temp_root.to_string_lossy().to_string()),
            "reproducible manifest fields must not include absolute local paths"
        );
        assert!(first_manifest.contains("\"skill_path\": \"skill/SKILL.md\""));
        assert_eq!(first.fingerprint, instance.fingerprint);
        assert_eq!(first.metadata.source_scope, "tool-global");
        assert_eq!(first.metadata.version.as_deref(), Some("2.9.0"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn reimports_export_bundle_with_stable_fingerprint_and_metadata() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-reimport-stable-{}",
            std::process::id()
        ));
        let source_dir = temp_root.join("incoming/review-helper");
        std::fs::create_dir_all(&source_dir).expect("create staging skill");
        std::fs::write(
            source_dir.join("SKILL.md"),
            "---\nname: review-helper\ndescription: Review helper\nversion: 2.9.0\npermissions:\n  network: none\n  requires_human: true\n---\nReview local changes only.\n",
        )
        .expect("write staging skill");

        let exported = export_staging_skill_bundle(&source_dir, &temp_root.join("exports"))
            .expect("export staging skill");
        let reimported =
            reimport_skill_bundle(&exported.bundle_path).expect("reimport exported bundle");

        assert_eq!(reimported.fingerprint, exported.fingerprint);
        assert_eq!(reimported.metadata, exported.metadata);
        assert_eq!(reimported.metadata.source_scope, "tool-global");
        assert_eq!(
            reimported
                .permissions
                .get("network")
                .and_then(serde_json::Value::as_str),
            Some("none")
        );
        assert_eq!(
            reimported
                .permissions
                .get("requires_human")
                .and_then(serde_json::Value::as_bool),
            Some(true)
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn scan_all_includes_openclaw_and_hermes_after_pi() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-pi-scan-all-{}", std::process::id()));
        let home = temp_root.join("home");
        let claude_path = write_claude_skill(&home, "claude-alpha");
        let codex_path = write_codex_skill(&home, "codex-alpha");
        let opencode_path = write_opencode_global_skill(&home, "opencode-alpha");
        let pi_path = write_pi_global_skill(&home, "pi-alpha");
        let hermes_path = write_hermes_global_skill(&home, "hermes-alpha");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_all_catalog_report(&ctx, &catalog).expect("scan all succeeds");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(report.scanned_count, 8);
        assert_eq!(
            report
                .agents
                .iter()
                .map(|agent| agent.agent)
                .collect::<Vec<_>>(),
            vec![
                AgentId::ClaudeCode,
                AgentId::Codex,
                AgentId::Opencode,
                AgentId::Pi,
                AgentId::Openclaw,
                AgentId::Hermes
            ],
            "scanAll reports OpenClaw and Hermes after Pi"
        );
        assert!(records.iter().any(|record| {
            record.agent == "claude-code"
                && record.name == "claude-alpha"
                && record.path == claude_path
        }));
        assert!(records.iter().any(|record| {
            record.agent == "codex" && record.name == "codex-alpha" && record.path == codex_path
        }));
        assert!(records.iter().any(|record| {
            record.agent == "opencode"
                && record.name == "opencode-alpha"
                && record.path == opencode_path
        }));
        assert!(records
            .iter()
            .any(|record| record.agent == "opencode" && record.name == "claude-alpha"));
        assert!(records
            .iter()
            .any(|record| record.agent == "opencode" && record.name == "codex-alpha"));
        assert!(records.iter().any(|record| {
            record.agent == "pi" && record.name == "pi-alpha" && record.path == pi_path
        }));
        assert!(records.iter().any(|record| {
            record.agent == "openclaw" && record.name == "codex-alpha" && record.path == codex_path
        }));
        assert!(records.iter().any(|record| {
            record.agent == "hermes" && record.name == "hermes-alpha" && record.path == hermes_path
        }));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn tool_global_staging_root_is_app_data_scoped() {
        let app_data = PathBuf::from("/tmp/skills-copilot-app-data");

        assert_eq!(
            tool_global_staging_skills_root(&app_data),
            app_data.join("tool-global/skills")
        );
    }

    #[test]
    fn upserts_existing_staging_skill_as_tool_global_record() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-tool-global-upsert-{}",
            std::process::id()
        ));
        let app_data = temp_root.join("app-data");
        let home = temp_root.join("home");
        let staging_root =
            ensure_tool_global_staging_skills_root(&app_data).expect("create staging root");
        let skill_path = write_staging_skill(&staging_root, "imported-alpha");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let record = upsert_tool_global_staging_skill(&catalog, &ctx, &app_data, &skill_path)
            .expect("tool-global upsert succeeds");
        let records = catalog.list_skill_records().expect("records list");
        let detail = get_skill(&catalog, &record.id).expect("detail lookup");

        assert_eq!(records.len(), 1);
        assert_eq!(record.agent, "tool-global");
        assert_eq!(record.scope, "tool-global");
        assert_eq!(record.name, "imported-alpha");
        assert_eq!(record.path, skill_path);
        assert_eq!(
            record.display_path,
            PathBuf::from("$APP_DATA").join("tool-global/skills/imported-alpha/SKILL.md")
        );
        assert_eq!(detail.agent, "tool-global");
        assert_eq!(detail.scope, "tool-global");
        assert_eq!(detail.name, "imported-alpha");
        assert!(
            !home.join(".claude/settings.json").exists(),
            "tool-global upsert must not write Claude config"
        );
        assert!(
            !home.join(".codex/config.toml").exists(),
            "tool-global upsert must not write Codex config"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn tool_global_upsert_rejects_paths_outside_staging_root() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-tool-global-outside-{}",
            std::process::id()
        ));
        let app_data = temp_root.join("app-data");
        let outside_root = temp_root.join("outside");
        std::fs::create_dir_all(&outside_root).expect("create outside root");
        ensure_tool_global_staging_skills_root(&app_data).expect("create staging root");
        let outside_path = write_staging_skill(&outside_root, "outside-alpha");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: temp_root.join("home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let err = upsert_tool_global_staging_skill(&catalog, &ctx, &app_data, &outside_path)
            .expect_err("outside staging path must be rejected");

        assert!(
            err.to_string().contains("outside staging root"),
            "unexpected error: {err}"
        );
        assert_eq!(catalog.list_skill_records().expect("records").len(), 0);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn scan_all_preserves_tool_global_record() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-tool-global-scan-{}",
            std::process::id()
        ));
        let app_data = temp_root.join("app-data");
        let home = temp_root.join("home");
        let staging_root =
            ensure_tool_global_staging_skills_root(&app_data).expect("create staging root");
        let tool_global_path = write_staging_skill(&staging_root, "tool-persist");
        let claude_path = write_claude_skill(&home, "claude-visible");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let tool_global =
            upsert_tool_global_staging_skill(&catalog, &ctx, &app_data, &tool_global_path)
                .expect("tool-global upsert succeeds");
        scan_all_to_catalog(&ctx, &catalog).expect("scan all succeeds");
        let records = catalog.list_skill_records().expect("records list");

        assert!(records.iter().any(|record| {
            record.id == tool_global.id && record.agent == "tool-global" && record.state == "loaded"
        }));
        assert!(records.iter().any(|record| {
            record.agent == "claude-code"
                && record.name == "claude-visible"
                && record.path == claude_path
        }));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn tool_global_and_agent_global_same_name_overlap_without_runtime_conflict() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-tool-global-conflict-{}",
            std::process::id()
        ));
        let app_data = temp_root.join("app-data");
        let home = temp_root.join("home");
        let staging_root =
            ensure_tool_global_staging_skills_root(&app_data).expect("create staging root");
        let tool_global_path = write_staging_skill(&staging_root, "shared-alpha");
        let agent_global_path = write_claude_skill(&home, "shared-alpha");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let tool_global =
            upsert_tool_global_staging_skill(&catalog, &ctx, &app_data, &tool_global_path)
                .expect("tool-global upsert succeeds");
        scan_all_to_catalog(&ctx, &catalog).expect("scan all succeeds");
        let records = catalog.list_skill_records().expect("records list");
        let agent_global = records
            .iter()
            .find(|record| record.agent == "claude-code" && record.path == agent_global_path)
            .expect("agent-global record");
        let tool_global_after = records
            .iter()
            .find(|record| record.id == tool_global.id)
            .expect("tool-global record");

        assert_eq!(records.len(), 3);
        assert_eq!(agent_global.scope, "agent-global");
        assert_eq!(tool_global_after.scope, "tool-global");
        assert_eq!(
            agent_global.definition_id, tool_global_after.definition_id,
            "same names share a definition id for conflict display"
        );

        let conflicts = list_conflicts(&catalog).expect("conflicts list");
        assert!(
            conflicts.iter().all(|conflict| {
                !(conflict.instance_ids.contains(&agent_global.id)
                    && conflict.instance_ids.contains(&tool_global.id))
            }),
            "tool-global and agent runtime rows overlap in analysis, not conflict tab"
        );
        assert!(records
            .iter()
            .any(|record| record.agent == "opencode" && record.name == "shared-alpha"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn toggle_opencode_skill_writes_permission_skill_deny_and_reenables() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-toggle-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        write_opencode_global_skill(&home, "writable-skill");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };
        scan_all_to_catalog(&ctx, &catalog).expect("scan all");
        let opencode_record = catalog
            .list_skill_records()
            .expect("records")
            .into_iter()
            .find(|record| record.agent == "opencode" && record.name == "writable-skill")
            .expect("opencode record");

        let disabled = toggle_skill(&catalog, &ctx, &opencode_record.id, false)
            .expect("opencode disable succeeds");

        let config_path = ctx.user_home.join(".config/opencode/opencode.json");
        let config: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&config_path).expect("opencode config"))
                .expect("config json");
        assert_eq!(config["permission"]["skill"]["writable-skill"], "deny");
        assert!(!disabled.enabled);
        assert_eq!(disabled.state, "disabled");

        let snapshots = catalog
            .list_config_snapshots("opencode", &config_path.to_string_lossy())
            .expect("snapshots");
        assert_eq!(snapshots.len(), 1);
        assert_eq!(snapshots[0].scope, "agent-global");

        let enabled = toggle_skill(&catalog, &ctx, &opencode_record.id, true)
            .expect("opencode enable succeeds");
        let config: serde_json::Value =
            serde_json::from_str(&std::fs::read_to_string(&config_path).expect("opencode config"))
                .expect("config json");
        assert!(config["permission"]["skill"]
            .get("writable-skill")
            .is_none());
        assert!(enabled.enabled);
        assert_eq!(enabled.state, "loaded");

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn codex_cwd_walk_records_selected_project_root() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let selected_project = fixture_path("fixtures/codex/project");
        let ctx = AdapterContext {
            user_home: fixture_path("fixtures/codex/user-home"),
            project_root: Some(selected_project.clone()),
            project_cwd: Some(selected_project.join("nested")),
            extra_roots: vec![],
        };

        scan_all_to_catalog(&ctx, &catalog).expect("scan all succeeds");
        let nested_record = catalog
            .list_skill_records()
            .expect("records")
            .into_iter()
            .find(|record| record.agent == "codex" && record.name == "nested-gamma")
            .expect("nested cwd Codex record");
        let meta = catalog
            .get_skill_instance_meta(&nested_record.id)
            .expect("meta lookup")
            .expect("meta present");

        assert_eq!(
            meta.project_root,
            Some(selected_project),
            "cwd walk should keep the selected project root as the catalog boundary"
        );
    }

    #[test]
    fn scan_all_project_context_sweeps_only_current_boundary() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-project-context-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project_a = temp_root.join("project-a");
        let project_b = temp_root.join("project-b");
        let global_path = write_codex_skill(&home, "global-visible");
        let project_a_path = write_codex_skill(&project_a, "project-a-visible");
        let project_b_path = write_codex_skill(&project_b, "project-b-visible");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");

        let ctx_a = AdapterContext {
            user_home: home.clone(),
            project_root: Some(project_a.clone()),
            project_cwd: Some(project_a.clone()),
            extra_roots: vec![],
        };
        scan_all_to_catalog(&ctx_a, &catalog).expect("project A scan");
        let records = catalog.list_skill_records().expect("records after A");
        assert!(
            records.iter().any(|record| record.path == project_a_path),
            "project A scan records project A skill"
        );
        assert!(
            records.iter().any(|record| record.path == global_path),
            "project A scan records user-scope Codex skill"
        );

        let ctx_b = AdapterContext {
            user_home: home.clone(),
            project_root: Some(project_b.clone()),
            project_cwd: Some(project_b.clone()),
            extra_roots: vec![],
        };
        scan_all_to_catalog(&ctx_b, &catalog).expect("project B scan");
        let records = catalog.list_skill_records().expect("records after B");
        assert!(
            records
                .iter()
                .any(|record| record.path == project_a_path && record.state == "loaded"),
            "project B scan does not mark project A record missing"
        );
        assert!(
            records
                .iter()
                .any(|record| record.path == project_b_path && record.state == "loaded"),
            "project B scan records project B skill"
        );

        let foreign_under_b = project_b
            .join(".agents/skills/foreign-project-a-record/SKILL.md")
            .canonicalize()
            .unwrap_or_else(|_| project_b.join(".agents/skills/foreign-project-a-record/SKILL.md"));
        catalog
            .upsert_skill_instance(&synthetic_codex_project_instance(
                "foreign-under-b",
                &project_a,
                foreign_under_b.clone(),
                "foreign-under-b",
            ))
            .expect("upsert foreign project record");
        let foreign_toggle = toggle_skill(&catalog, &ctx_b, "foreign-under-b", false)
            .expect_err("foreign project rows must not be writable in current context");
        assert!(
            foreign_toggle
                .to_string()
                .contains("current project context"),
            "unexpected foreign project toggle error: {foreign_toggle}"
        );
        scan_all_to_catalog(&ctx_b, &catalog).expect("project B rescan");
        let records = catalog
            .list_skill_records()
            .expect("records after B rescan");
        assert!(
            records
                .iter()
                .any(|record| record.id == "foreign-under-b" && record.state == "loaded"),
            "project B scan must not sweep an AgentProject row owned by project A"
        );

        let project_scoped_under_user_root =
            home.join(".agents/skills/project-scoped-leak/SKILL.md");
        catalog
            .upsert_skill_instance(&synthetic_codex_project_instance(
                "project-scoped-under-user-root",
                &project_a,
                project_scoped_under_user_root,
                "project-scoped-under-user-root",
            ))
            .expect("upsert no-project guard record");
        let clear_ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };
        scan_all_to_catalog(&clear_ctx, &catalog).expect("clear project scan");
        let records = catalog.list_skill_records().expect("records after clear");
        assert!(
            records.iter().any(|record| {
                record.id == "project-scoped-under-user-root" && record.state == "loaded"
            }),
            "no-project scan must not sweep project-scoped records under scanned user roots"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn marks_deleted_fixture_as_missing_on_rescan() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-sweep-{}", std::process::id()));
        let personal = temp_root.join("personal");
        let skill_dir = personal.join("ephemeral");
        std::fs::create_dir_all(&skill_dir).expect("create temp skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        let skill_body =
            "---\nname: ephemeral\ndescription: temporary sweep test skill\n---\nBody content.\n";
        std::fs::write(&skill_path, skill_body).expect("write temp skill");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: temp_root.join("empty-home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: personal.clone(),
                source: RootSource::Extra,
            }],
        };

        let first_count = scan_claude_to_catalog(&ctx, &catalog).expect("first scan");
        assert_eq!(first_count, 1);
        let records = catalog
            .list_skill_records()
            .expect("records after first scan");
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].state, "loaded");

        std::fs::remove_file(&skill_path).expect("delete skill file");

        let second_count = scan_claude_to_catalog(&ctx, &catalog).expect("second scan");
        assert_eq!(second_count, 0, "no skills found after deletion");
        let records = catalog
            .list_skill_records()
            .expect("records after second scan");
        assert_eq!(records.len(), 1, "record retained but marked missing");
        assert_eq!(
            records[0].state, "missing",
            "deleted file is marked missing"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn sweep_does_not_touch_records_outside_scanned_roots() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-scope-{}", std::process::id()));

        let project_skill_dir = temp_root
            .join("project")
            .join(".claude")
            .join("skills")
            .join("never-scanned");
        std::fs::create_dir_all(&project_skill_dir).expect("create project skill dir");
        let project_path = project_skill_dir.join("SKILL.md");
        std::fs::write(
            &project_path,
            "---\nname: never-scanned\ndescription: synthetic\n---\nbody",
        )
        .expect("write project skill");
        let project_path = project_path
            .canonicalize()
            .expect("canonicalize project path");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let project_inst = SkillInstance {
            id: "synthetic-project-id".to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::AgentProject,
            project_root: Some(temp_root.join("project")),
            path: project_path.clone(),
            display_path: project_path.clone(),
            definition_id: "never-scanned".to_string(),
            name: "never-scanned".to_string(),
            display_name: "never-scanned".to_string(),
            description: "synthetic project record".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: String::new(),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        };
        catalog
            .upsert_skill_instance(&project_inst)
            .expect("upsert project record");

        let personal = temp_root.join("personal");
        let ephemeral_dir = personal.join("ephemeral");
        std::fs::create_dir_all(&ephemeral_dir).expect("create personal skill dir");
        std::fs::write(
            ephemeral_dir.join("SKILL.md"),
            "---\nname: ephemeral\ndescription: x\n---\nbody",
        )
        .expect("write personal skill");

        let ctx = AdapterContext {
            user_home: temp_root.join("empty-home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: personal,
                source: RootSource::Extra,
            }],
        };

        scan_claude_to_catalog(&ctx, &catalog).expect("scan succeeds");

        let records = catalog.list_skill_records().expect("records");
        let project_record = records
            .iter()
            .find(|r| r.path == project_path)
            .expect("project record still present");
        assert_eq!(
            project_record.state, "loaded",
            "project record outside scanned roots is not swept"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn toggle_off_writes_skill_overrides_and_creates_snapshot() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-toggle-{}", std::process::id()));
        let home = temp_root.join("home");
        std::fs::create_dir_all(home.join(".claude/skills/foo")).expect("create skill dir");
        std::fs::write(
            home.join(".claude/skills/foo/SKILL.md"),
            "---\nname: foo\n---\nbody",
        )
        .expect("write skill");
        let settings_path = home.join(".claude/settings.json");
        std::fs::write(&settings_path, "{}\n").expect("write initial settings");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let inst = SkillInstance {
            id: "toggle-off-id".to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: home.join(".claude/skills/foo/SKILL.md"),
            display_path: home.join(".claude/skills/foo/SKILL.md"),
            definition_id: "foo".to_string(),
            name: "foo".to_string(),
            display_name: "foo".to_string(),
            description: "test".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: String::new(),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        };
        catalog.upsert_skill_instance(&inst).expect("upsert");

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let record = toggle_skill(&catalog, &ctx, "toggle-off-id", false).expect("toggle off");
        assert!(!record.enabled);
        assert_eq!(record.state, "disabled");

        let content = std::fs::read_to_string(&settings_path).expect("read settings");
        assert!(
            content.contains("\"foo\""),
            "skillOverrides has the skill name"
        );
        assert!(content.contains("\"off\""), "skillOverrides set to off");

        let snapshots = catalog
            .list_config_snapshots("claude-code", &settings_path.to_string_lossy())
            .expect("list snapshots");
        assert_eq!(snapshots.len(), 1, "exactly one pre-toggle snapshot");
        assert_eq!(snapshots[0].reason, "pre-toggle");
        assert_eq!(
            snapshots[0].content, "{}\n",
            "snapshot captures pre-toggle state"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn toggle_on_removes_skill_overrides_entry() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-toggle-on-{}", std::process::id()));
        let home = temp_root.join("home");
        std::fs::create_dir_all(home.join(".claude/skills/bar")).expect("create skill dir");
        let settings_path = home.join(".claude/settings.json");
        let initial = "{\n  \"skillOverrides\": {\n    \"bar\": \"off\"\n  }\n}\n";
        std::fs::write(&settings_path, initial).expect("write initial settings");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let inst = SkillInstance {
            id: "toggle-on-id".to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: home.join(".claude/skills/bar/SKILL.md"),
            display_path: home.join(".claude/skills/bar/SKILL.md"),
            definition_id: "bar".to_string(),
            name: "bar".to_string(),
            display_name: "bar".to_string(),
            description: "test".to_string(),
            version: None,
            state: SkillState::Disabled,
            enabled: false,
            frontmatter_raw: String::new(),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        };
        catalog.upsert_skill_instance(&inst).expect("upsert");

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let record = toggle_skill(&catalog, &ctx, "toggle-on-id", true).expect("toggle on");
        assert!(record.enabled);
        assert_eq!(record.state, "loaded");

        let content = std::fs::read_to_string(&settings_path).expect("read settings");
        assert!(
            !content.contains("\"bar\""),
            "skillOverrides entry for bar is removed"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn toggle_codex_project_skill_writes_only_user_config_toml() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-codex-toggle-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("project");
        let skill_dir = project.join(".agents/skills/proj");
        let project_config = project.join(".codex/config.toml");
        std::fs::create_dir_all(&skill_dir).expect("create codex skill dir");
        std::fs::create_dir_all(project_config.parent().expect("project config parent"))
            .expect("create project codex config dir");
        std::fs::create_dir_all(project.join(".git")).expect("create git marker");
        std::fs::write(&project_config, "# project config must remain untouched\n")
            .expect("write existing project config");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            "---\nname: proj\ndescription: Project Codex skill\n---\nbody",
        )
        .expect("write codex skill");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: Some(project.clone()),
            project_cwd: None,
            extra_roots: vec![],
        };
        scan_all_to_catalog(&ctx, &catalog).expect("scan all");
        let codex_record = catalog
            .list_skill_records()
            .expect("records")
            .into_iter()
            .find(|record| record.agent == "codex" && record.name == "proj")
            .expect("codex project record");

        let disabled =
            toggle_skill(&catalog, &ctx, &codex_record.id, false).expect("toggle codex off");
        assert!(!disabled.enabled);
        assert_eq!(disabled.state, "disabled");

        let user_config = home.join(".codex/config.toml");
        let content = std::fs::read_to_string(&user_config).expect("read codex config");
        assert!(content.contains("[[skills.config]]"));
        assert!(content.contains("enabled = false"));
        assert!(
            content.contains(&skill_path.to_string_lossy().to_string()),
            "Codex toggle should write the absolute SKILL.md path"
        );
        assert_eq!(
            std::fs::read_to_string(&project_config).expect("read project config"),
            "# project config must remain untouched\n",
            "Codex toggle must not modify project .codex/config.toml"
        );

        let snapshots = catalog
            .list_config_snapshots("codex", &user_config.to_string_lossy())
            .expect("codex snapshots");
        assert_eq!(snapshots.len(), 1);
        assert_eq!(snapshots[0].scope, "agent-global");
        assert_eq!(snapshots[0].reason, "pre-toggle");

        let enabled =
            toggle_skill(&catalog, &ctx, &codex_record.id, true).expect("toggle codex on");
        assert!(enabled.enabled);
        let content = std::fs::read_to_string(&user_config).expect("read codex config");
        assert!(
            !content.contains(&skill_path.to_string_lossy().to_string()),
            "re-enabling removes matching Codex config entries"
        );
        assert_eq!(
            std::fs::read_to_string(&project_config).expect("read project config"),
            "# project config must remain untouched\n",
            "Codex re-enable must not modify project .codex/config.toml"
        );

        let no_project_ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };
        let stale_toggle = toggle_skill(&catalog, &no_project_ctx, &codex_record.id, false)
            .expect_err("stale project records must not be writable without project context");
        assert!(
            stale_toggle.to_string().contains("current project context"),
            "unexpected stale toggle error: {stale_toggle}"
        );

        let other_project = temp_root.join("other-project");
        std::fs::create_dir_all(&other_project).expect("create other project");
        let stale_mismatch_ctx = AdapterContext {
            user_home: home.clone(),
            project_root: Some(other_project),
            project_cwd: None,
            extra_roots: vec![],
        };
        let stale_mismatch = toggle_skill(&catalog, &stale_mismatch_ctx, &codex_record.id, false)
            .expect_err("stale project rows must not be writable from a different project context");
        assert!(
            stale_mismatch
                .to_string()
                .contains("current project context"),
            "unexpected stale mismatch toggle error: {stale_mismatch}"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn codex_config_path_honors_only_safe_codex_home_under_user_home() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-codex-home-boundary-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let safe_codex_home = home.join("custom-codex-home");
        let unsafe_codex_home = temp_root.join("outside-codex-home");
        let escaping_codex_home = home.join("../outside-codex-home");
        std::fs::create_dir_all(&home).expect("create home");

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        assert_eq!(
            codex_user_config_path_for(&ctx, Some(&safe_codex_home)),
            safe_codex_home.join("config.toml"),
            "safe CODEX_HOME under user_home should be honored"
        );
        assert_eq!(
            codex_user_config_path_for(&ctx, Some(&unsafe_codex_home)),
            home.join(".codex/config.toml"),
            "unsafe CODEX_HOME outside user_home must fall back to user config"
        );
        assert_eq!(
            codex_user_config_path_for(&ctx, Some(&escaping_codex_home)),
            home.join(".codex/config.toml"),
            "CODEX_HOME path traversal must not escape user_home"
        );

        validate_config_write_target(
            &ctx,
            AgentId::Codex,
            Scope::AgentGlobal,
            &home.join(".codex/config.toml"),
        )
        .expect("fallback Codex config target validates");
        let unsafe_result = validate_config_write_target(
            &ctx,
            AgentId::Codex,
            Scope::AgentGlobal,
            &unsafe_codex_home.join("config.toml"),
        );
        assert!(
            matches!(unsafe_result, Err(CommandError::UnsafeConfigPath(_))),
            "unsafe CODEX_HOME target must not validate for writes"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn codex_rescan_reads_disabled_state_with_adapter_toml_semantics() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-codex-disabled-toml-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let alpha_path = write_codex_skill(&home, "alpha-disabled");
        let beta_path = write_codex_skill(&home, "beta-disabled");
        let config_path = home.join(".codex/config.toml");
        std::fs::create_dir_all(config_path.parent().expect("codex config parent"))
            .expect("create codex config dir");
        std::fs::write(
            &config_path,
            format!(
                "[[skills.config]]\npath = '{}' # literal string\nenabled = false # disabled\n\n[[skills.config]]\npath = \"{}\" # basic string\nenabled = false # disabled\n",
                alpha_path.display(),
                beta_path.display()
            ),
        )
        .expect("write codex config");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        scan_all_to_catalog(&ctx, &catalog).expect("scan all");
        let records = catalog.list_skill_records().expect("records");

        for name in ["alpha-disabled", "beta-disabled"] {
            let record = records
                .iter()
                .find(|record| record.agent == "codex" && record.name == name)
                .expect("codex record");
            assert_eq!(record.state, "disabled");
            assert!(!record.enabled);
        }

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn rescan_preserves_disabled_state_from_skill_overrides() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-rescan-{}", std::process::id()));
        let home = temp_root.join("home");
        std::fs::create_dir_all(home.join(".claude/skills/foo")).expect("create skill dir");
        std::fs::write(
            home.join(".claude/skills/foo/SKILL.md"),
            "---\nname: foo\ndescription: x\n---\nbody",
        )
        .expect("write skill");
        let settings_path = home.join(".claude/settings.json");
        std::fs::write(&settings_path, "{}\n").expect("write initial settings");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        // First scan: parser default state=loaded.
        scan_claude_to_catalog(&ctx, &catalog).expect("first scan");
        let records = catalog
            .list_skill_records()
            .expect("records after first scan");
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].state, "loaded");

        // Toggle off: settings.json now contains skillOverrides[foo] = "off".
        let inst_id = records[0].id.clone();
        toggle_skill(&catalog, &ctx, &inst_id, false).expect("toggle off");
        let content = std::fs::read_to_string(&settings_path).expect("read settings");
        assert!(content.contains("\"foo\""));
        assert!(content.contains("\"off\""));

        // Re-scan: scanner must read the override and keep the catalog at
        // state=disabled instead of reverting to state=loaded.
        scan_claude_to_catalog(&ctx, &catalog).expect("re-scan");
        let records = catalog.list_skill_records().expect("records after re-scan");
        assert_eq!(records.len(), 1);
        assert_eq!(
            records[0].state, "disabled",
            "re-scan must preserve the disabled state from skillOverrides"
        );
        assert!(!records[0].enabled);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn scan_records_rule_findings_and_conflicts() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: fixture_path("fixtures/claude-code/empty-home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: fixture_path("fixtures/claude-code/project"),
                source: RootSource::Extra,
            }],
        };

        scan_claude_to_catalog(&ctx, &catalog).expect("scan succeeds");

        let findings = catalog.list_rule_findings().expect("findings list");
        assert!(
            findings
                .iter()
                .any(|finding| finding.rule_id == "frontmatter.required-fields"),
            "broken frontmatter fixtures produce required-field findings"
        );
        assert!(
            findings
                .iter()
                .any(|finding| finding.rule_id == "name.collision"),
            "same-name fixtures produce collision findings"
        );

        let conflicts = catalog.list_conflict_groups().expect("conflicts list");
        assert!(
            conflicts
                .iter()
                .any(|conflict| conflict.reason == "content-drift"),
            "same-name fixtures with different content create a content-drift conflict"
        );
    }

    #[test]
    fn scan_records_v2_8_local_content_rule_findings() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-v2-8-content-rules-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        write_codex_skill_file(
            &home,
            "tools-empty-array",
            "---\nname: tools-empty-array\ndescription: empty tools array\ntools: []\n---\nbody",
        );
        write_codex_skill_file(
            &home,
            "tools-blank-string",
            "---\nname: tools-blank-string\ndescription: blank tools string\ntools: \"   \"\n---\nbody",
        );
        write_codex_skill_file(
            &home,
            "bad-name",
            "---\nname: Bad_Name\ndescription: noncanonical name\n---\nbody",
        );
        write_codex_skill_file(
            &home,
            "long-body",
            &format!(
                "---\nname: long-body\ndescription: long body\n---\n{}",
                "x".repeat(BODY_TOO_LONG_CHAR_THRESHOLD + 1)
            ),
        );
        write_codex_skill_file(
            &home,
            "no-tools",
            "---\nname: no-tools\ndescription: missing tools is valid\n---\nbody",
        );
        write_codex_skill_file(
            &home,
            "has-tools",
            "---\nname: has-tools\ndescription: nonempty tools is valid\ntools:\n  - Read\n---\nbody",
        );

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        scan_all_to_catalog(&ctx, &catalog).expect("scan all succeeds");

        let records = catalog.list_skill_records().expect("records list");
        let findings = catalog.list_rule_findings().expect("findings list");
        assert_eq!(
            records.len(),
            18,
            "Codex, OpenClaw, and opencode scan the documented shared ~/.agents/skills root"
        );
        assert_eq!(
            findings
                .iter()
                .filter(|finding| finding.rule_id == "frontmatter.tools-not-empty")
                .count(),
            6,
            "empty array and blank string tools fields are reported for all shared-root agents"
        );
        assert!(
            has_rule_for_name(
                &records,
                &findings,
                "tools-empty-array",
                "frontmatter.tools-not-empty"
            ) && has_rule_for_name(
                &records,
                &findings,
                "tools-blank-string",
                "frontmatter.tools-not-empty"
            ),
            "both empty tools forms produce findings"
        );
        assert!(
            has_rule_for_name(&records, &findings, "Bad_Name", "name.canonical-case"),
            "noncanonical case is reported"
        );
        assert!(
            has_rule_for_name(&records, &findings, "long-body", "body.too-long"),
            "body over the local threshold is reported"
        );
        assert!(
            !has_rule_for_name(
                &records,
                &findings,
                "no-tools",
                "frontmatter.tools-not-empty"
            ),
            "missing tools field must not be reported"
        );
        assert!(
            !has_rule_for_name(
                &records,
                &findings,
                "has-tools",
                "frontmatter.tools-not-empty"
            ),
            "nonempty tools field must not be reported"
        );
        assert!(
            !has_rule_for_name(&records, &findings, "has-tools", "name.canonical-case"),
            "canonical lowercase slug must not be reported"
        );
        assert!(
            !has_rule_for_name(&records, &findings, "has-tools", "body.too-long"),
            "short body must not be reported"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn single_agent_scan_preserves_other_agent_findings_without_cross_agent_conflict() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-single-scan-rules-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("project");
        let outside = temp_root.join("outside");
        std::fs::create_dir_all(&project).expect("create project");
        std::fs::create_dir_all(&outside).expect("create outside");
        write_claude_skill(&home, "shared-skill");
        write_codex_skill(&home, "shared-skill");
        write_opencode_global_skill(&home, "shared-skill");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(project.clone()),
            project_cwd: None,
            extra_roots: vec![],
        };

        scan_all_to_catalog(&ctx, &catalog).expect("scan all");
        catalog
            .upsert_skill_instance(&synthetic_opencode_project_instance(
                "opencode:outside-workspace",
                &project,
                outside.join("opencode/SKILL.md"),
                "opencode-outside-workspace",
            ))
            .expect("upsert opencode outside-workspace record");
        let previous_fingerprints = catalog
            .instance_fingerprints()
            .expect("fingerprints before rule refresh");
        refresh_catalog_rule_outputs(&catalog, &ctx, previous_fingerprints)
            .expect("refresh rules after synthetic opencode finding");
        assert!(catalog
            .list_rule_findings()
            .expect("findings after scan all")
            .iter()
            .any(|finding| finding
                .instance_id
                .as_deref()
                .is_some_and(|id| id.starts_with("opencode:"))));

        scan_claude_to_catalog(&ctx, &catalog).expect("scan claude");

        let findings = catalog.list_rule_findings().expect("findings after claude");
        assert!(
            findings.iter().any(|finding| finding
                .instance_id
                .as_deref()
                .is_some_and(|id| id.starts_with("opencode:"))),
            "scanClaude must not drop opencode findings"
        );

        let conflicts = catalog.list_conflict_groups().expect("conflicts");
        let records = catalog.list_skill_records().expect("records");
        let codex_shared_id = records
            .iter()
            .find(|record| record.agent == "codex" && record.name == "shared-skill")
            .expect("codex shared record")
            .id
            .clone();
        let opencode_shared_id = records
            .iter()
            .find(|record| record.agent == "opencode" && record.name == "shared-skill")
            .expect("opencode shared record")
            .id
            .clone();
        assert!(
            conflicts.iter().all(|conflict| {
                !(conflict.instance_ids.contains(&codex_shared_id)
                    && conflict.instance_ids.contains(&opencode_shared_id))
            }),
            "cross-agent duplicate names must not be runtime conflict groups"
        );
        let analysis = analyze_catalog(&catalog, &ctx).expect("analysis after scanClaude");
        assert!(
            analysis.groups.iter().any(|group| {
                group.kind == "duplicate_name"
                    && group.instance_ids.contains(&codex_shared_id)
                    && group.instance_ids.contains(&opencode_shared_id)
            }),
            "cross-agent duplicate names remain visible through analysis"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn rescan_records_fingerprint_changed_finding() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-fingerprint-{}", std::process::id()));
        let home = temp_root.join("home");
        let skill_dir = home.join(".claude/skills/foo");
        std::fs::create_dir_all(&skill_dir).expect("create skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(&skill_path, "---\nname: foo\ndescription: x\n---\nbody v1")
            .expect("write initial skill");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        scan_claude_to_catalog(&ctx, &catalog).expect("first scan");
        std::fs::write(&skill_path, "---\nname: foo\ndescription: x\n---\nbody v2")
            .expect("edit skill");
        scan_claude_to_catalog(&ctx, &catalog).expect("second scan");

        let findings = catalog.list_rule_findings().expect("findings list");
        assert!(
            findings
                .iter()
                .any(|finding| finding.rule_id == "fingerprint.changed"),
            "fingerprint changes are reported after re-scan"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn rollback_snapshot_restores_settings_and_rescans() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-rollback-{}", std::process::id()));
        let home = temp_root.join("home");
        let skill_dir = home.join(".claude/skills/foo");
        std::fs::create_dir_all(&skill_dir).expect("create skill dir");
        std::fs::write(
            skill_dir.join("SKILL.md"),
            "---\nname: foo\ndescription: x\n---\nbody",
        )
        .expect("write skill");
        let settings_path = home.join(".claude/settings.json");
        std::fs::write(&settings_path, "{}\n").expect("write settings");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        scan_claude_to_catalog(&ctx, &catalog).expect("scan");
        let skill_id = catalog.list_skill_records().expect("records")[0].id.clone();
        toggle_skill(&catalog, &ctx, &skill_id, false).expect("toggle off");

        let snapshots = list_snapshots(&catalog).expect("snapshots");
        assert_eq!(snapshots.len(), 1);
        let preview = preview_snapshot_rollback_with_context(&catalog, &ctx, &snapshots[0].id)
            .expect("rollback preview");
        assert_eq!(preview.snapshot.content, "{}\n");
        assert!(
            preview.current_content.contains("skillOverrides"),
            "preview reads the current config before rollback"
        );
        assert!(preview.changed, "preview detects changed content");
        assert!(!preview.redacted);
        assert!(preview.rollback_supported);
        rollback_snapshot(&catalog, &ctx, &snapshots[0].id).expect("rollback");

        let settings = std::fs::read_to_string(&settings_path).expect("settings");
        assert_eq!(settings, "{}\n");
        let records = catalog
            .list_skill_records()
            .expect("records after rollback");
        assert!(records[0].enabled);
        assert_eq!(records[0].state, "loaded");

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn read_claude_settings_returns_default_for_missing_file() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-read-config-{}", std::process::id()));
        let ctx = AdapterContext {
            user_home: temp_root.join("home"),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let doc = read_claude_settings(&ctx).expect("read missing settings");

        assert_eq!(doc.agent, "claude-code");
        assert_eq!(doc.scope, "agent-global");
        assert_eq!(doc.content, "{}\n");
        assert!(!doc.exists);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn read_claude_settings_rejects_symlinked_config_directory() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-read-symlink-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let outside = temp_root.join("outside");
        std::fs::create_dir_all(&home).expect("create home");
        std::fs::create_dir_all(&outside).expect("create outside dir");
        std::os::unix::fs::symlink(&outside, home.join(".claude"))
            .expect("create config dir symlink");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = read_claude_settings(&ctx);

        assert!(
            matches!(result, Err(CommandError::UnsafeConfigPath(_))),
            "read must reject the same symlinked target shape as writes"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn save_claude_settings_snapshots_validates_and_rescans() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-save-config-{}", std::process::id()));
        let home = temp_root.join("home");
        let skill_dir = home.join(".claude/skills/config-editor");
        std::fs::create_dir_all(&skill_dir).expect("create skill dir");
        std::fs::write(
            skill_dir.join("SKILL.md"),
            "---\nname: config-editor\ndescription: config editor fixture\n---\nbody",
        )
        .expect("write skill");
        let settings_path = home.join(".claude/settings.json");
        std::fs::write(&settings_path, "{}\n").expect("write initial settings");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };
        scan_claude_to_catalog(&ctx, &catalog).expect("initial scan");

        let invalid = save_claude_settings(&catalog, &ctx, "{ broken");
        assert!(matches!(invalid, Err(CommandError::InvalidJson(_))));

        let updated = save_claude_settings(
            &catalog,
            &ctx,
            "{\n  \"skillOverrides\": {\n    \"config-editor\": \"off\"\n  }\n}\n",
        )
        .expect("save config");

        assert!(updated.exists);
        assert!(updated.content.contains("skillOverrides"));
        let snapshots = catalog
            .list_config_snapshots("claude-code", &settings_path.to_string_lossy())
            .expect("snapshots");
        assert_eq!(snapshots.len(), 1);
        assert_eq!(snapshots[0].reason, "pre-config-edit");
        assert_eq!(snapshots[0].content, "{}\n");

        let records = catalog.list_skill_records().expect("records");
        assert_eq!(records.len(), 1);
        assert!(!records[0].enabled);
        assert_eq!(records[0].state, "disabled");

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn install_preview_from_tool_global_does_not_write_disk() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-install-preview-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        std::fs::create_dir_all(&home).expect("create home");
        let source_path = write_tool_global_skill(&temp_root, "portable-alpha");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .upsert_skill_instance(&install_tool_global_instance(
                "tool-global-alpha",
                source_path.clone(),
                "portable-alpha",
            ))
            .expect("upsert tool-global");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let preview = install_skill_from_tool_global(
            &catalog,
            &ctx,
            "tool-global-alpha",
            AgentId::Codex,
            Scope::AgentGlobal,
            None,
            false,
        )
        .expect("preview install");

        assert!(!preview.wrote);
        assert_eq!(preview.source_path, source_path.to_string_lossy());
        assert_eq!(
            preview.target_path,
            home.join(".agents/skills/portable-alpha/SKILL.md")
                .to_string_lossy()
        );
        assert!(
            !home.join(".agents").exists(),
            "preview must not create target dirs"
        );
        assert!(
            catalog
                .list_all_config_snapshots()
                .expect("snapshots")
                .is_empty(),
            "preview must not create audit snapshots"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn confirmed_install_writes_target_verified_path_without_config_snapshot() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-install-confirmed-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        std::fs::create_dir_all(&home).expect("create home");
        let source_path = write_tool_global_skill(&temp_root, "portable-beta");
        let source_content = std::fs::read_to_string(&source_path).expect("source content");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .upsert_skill_instance(&install_tool_global_instance(
                "tool-global-beta",
                source_path,
                "portable-beta",
            ))
            .expect("upsert tool-global");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = install_skill_from_tool_global(
            &catalog,
            &ctx,
            "tool-global-beta",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            None,
            true,
        )
        .expect("confirmed install");

        let target = home.join(".claude/skills/portable-beta/SKILL.md");
        assert!(result.wrote);
        assert_eq!(result.target_path, target.to_string_lossy());
        assert_eq!(
            std::fs::read_to_string(&target).expect("target content"),
            source_content
        );
        let snapshots = catalog
            .list_config_snapshots("claude-code", &target.to_string_lossy())
            .expect("snapshots");
        assert!(
            snapshots.is_empty(),
            "direct skill-file installs must not create agent config snapshots"
        );
        assert!(catalog
            .list_skill_records()
            .expect("records")
            .iter()
            .any(|record| record.agent == "claude-code" && record.name == "portable-beta"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn install_to_opencode_writes_native_user_skill_root() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-install-opencode-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        std::fs::create_dir_all(&home).expect("create home");
        let source_path = write_tool_global_skill(&temp_root, "portable-gamma");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .upsert_skill_instance(&install_tool_global_instance(
                "tool-global-gamma",
                source_path,
                "portable-gamma",
            ))
            .expect("upsert tool-global");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = install_skill_from_tool_global(
            &catalog,
            &ctx,
            "tool-global-gamma",
            AgentId::Opencode,
            Scope::AgentGlobal,
            None,
            true,
        )
        .expect("opencode install succeeds");

        let target = home.join(".config/opencode/skills/portable-gamma/SKILL.md");
        assert!(result.wrote);
        assert_eq!(result.target_path, target.to_string_lossy());
        assert!(target.exists());
        assert!(catalog
            .list_skill_records()
            .expect("records")
            .iter()
            .any(|record| record.agent == "opencode" && record.name == "portable-gamma"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn install_project_target_outside_current_root_is_rejected() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-install-project-boundary-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project_a = temp_root.join("project-a");
        let project_b = temp_root.join("project-b");
        std::fs::create_dir_all(&home).expect("create home");
        std::fs::create_dir_all(&project_a).expect("create project a");
        std::fs::create_dir_all(&project_b).expect("create project b");
        let source_path = write_tool_global_skill(&temp_root, "portable-delta");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .upsert_skill_instance(&install_tool_global_instance(
                "tool-global-delta",
                source_path,
                "portable-delta",
            ))
            .expect("upsert tool-global");
        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(project_a.clone()),
            project_cwd: Some(project_a),
            extra_roots: vec![],
        };

        let err = install_skill_from_tool_global(
            &catalog,
            &ctx,
            "tool-global-delta",
            AgentId::Codex,
            Scope::AgentProject,
            Some(&project_b),
            false,
        )
        .expect_err("project install outside current context must be rejected");

        assert!(err.to_string().contains("current project context"));
        assert!(
            !project_b.join(".agents").exists(),
            "rejected project install must not create target dirs"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn save_claude_settings_redacts_sensitive_snapshot_content() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-redacted-snapshot-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let settings_path = home.join(".claude/settings.json");
        std::fs::create_dir_all(settings_path.parent().expect("settings parent"))
            .expect("create settings dir");
        std::fs::write(
            &settings_path,
            "{\n  \"apiKey\": \"sk-live-secret\",\n  \"nested\": { \"access_token\": \"tok\" }\n}\n",
        )
        .expect("write sensitive settings");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        save_claude_settings(&catalog, &ctx, "{}\n").expect("save config");

        let snapshots = catalog
            .list_config_snapshots("claude-code", &settings_path.to_string_lossy())
            .expect("snapshots");
        assert_eq!(snapshots.len(), 1);
        assert!(snapshots[0].content.starts_with(REDACTED_SNAPSHOT_PREFIX));
        assert!(!snapshots[0].content.contains("sk-live-secret"));
        assert!(!snapshots[0].content.contains("\"tok\""));
        assert!(snapshots[0].content.contains(REDACTED_VALUE));

        let preview = preview_snapshot_rollback_with_context(&catalog, &ctx, &snapshots[0].id)
            .expect("preview redacted snapshot");
        assert!(preview.redacted);
        assert!(!preview.rollback_supported);
        let rollback = rollback_snapshot(&catalog, &ctx, &snapshots[0].id);
        assert!(
            matches!(rollback, Err(CommandError::UnsafeConfigPath(_))),
            "redacted snapshots must not be written back"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn save_claude_settings_writes_private_config_and_lock_permissions() {
        use std::os::unix::fs::PermissionsExt;

        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-private-config-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let settings_path = home.join(".claude/settings.json");
        std::fs::create_dir_all(settings_path.parent().expect("settings parent"))
            .expect("create settings dir");
        std::fs::write(&settings_path, "{}\n").expect("write settings");
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        save_claude_settings(&catalog, &ctx, "{\n  \"skillOverrides\": {}\n}\n")
            .expect("save config");

        let config_mode = std::fs::metadata(&settings_path)
            .expect("config metadata")
            .permissions()
            .mode()
            & 0o777;
        let lock_mode = std::fs::metadata(settings_path.with_extension("lock"))
            .expect("lock metadata")
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(config_mode, 0o600);
        assert_eq!(lock_mode, 0o600);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn save_claude_settings_rejects_symlinked_config_directory() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-save-symlink-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let outside = temp_root.join("outside");
        std::fs::create_dir_all(&home).expect("create home");
        std::fs::create_dir_all(&outside).expect("create outside dir");
        std::os::unix::fs::symlink(&outside, home.join(".claude"))
            .expect("create config dir symlink");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = save_claude_settings(&catalog, &ctx, "{}\n");

        assert!(
            matches!(result, Err(CommandError::UnsafeConfigPath(_))),
            "symlinked config directory must be rejected"
        );
        assert!(
            !outside.join("settings.json").exists(),
            "write must not follow the symlinked config directory"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn rollback_snapshot_rejects_target_outside_expected_config_path() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-rollback-path-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        std::fs::create_dir_all(home.join(".claude")).expect("create claude dir");
        let outside_target = temp_root.join("outside-settings.json");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .create_config_snapshot(ConfigSnapshotDraft {
                id: "tampered-snapshot",
                agent: ClaudeCodeAdapter.id().as_str(),
                scope: Scope::AgentGlobal.as_str(),
                target: &outside_target.to_string_lossy(),
                content: "{}\n",
                reason: "tampered",
                created_at_ms: current_time_ms(),
            })
            .expect("create tampered snapshot");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = rollback_snapshot(&catalog, &ctx, "tampered-snapshot");

        assert!(
            matches!(result, Err(CommandError::UnsafeConfigPath(_))),
            "rollback must reject snapshot targets outside the expected settings path"
        );
        assert!(
            !outside_target.exists(),
            "rollback must not write the tampered snapshot target"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn preview_snapshot_rejects_target_outside_expected_config_path() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-preview-path-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        std::fs::create_dir_all(home.join(".claude")).expect("create claude dir");
        let outside_target = temp_root.join("outside-settings.json");
        std::fs::write(&outside_target, "do not read\n").expect("write outside target");

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        catalog
            .create_config_snapshot(ConfigSnapshotDraft {
                id: "tampered-preview",
                agent: ClaudeCodeAdapter.id().as_str(),
                scope: Scope::AgentGlobal.as_str(),
                target: &outside_target.to_string_lossy(),
                content: "{}\n",
                reason: "tampered",
                created_at_ms: current_time_ms(),
            })
            .expect("create tampered snapshot");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let result = preview_snapshot_rollback_with_context(&catalog, &ctx, "tampered-preview");

        assert!(
            matches!(result, Err(CommandError::UnsafeConfigPath(_))),
            "preview must reject snapshot targets outside the expected settings path"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[ignore = "10k benchmark; run with `pnpm benchmark:10k`"]
    fn benchmark_10k_scan_to_catalog() {
        const SKILL_COUNT: usize = 10_000;

        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-bench-{}", std::process::id()));
        let home = temp_root.join("home");
        let skills_root = home.join(".claude/skills");
        std::fs::create_dir_all(&skills_root).expect("create skills root");
        std::fs::write(home.join(".claude/settings.json"), "{}\n").expect("write settings");

        for idx in 0..SKILL_COUNT {
            let skill_dir = skills_root.join(format!("bench-{idx:05}"));
            std::fs::create_dir_all(&skill_dir).expect("create skill dir");
            std::fs::write(
                skill_dir.join("SKILL.md"),
                format!(
                    "---\nname: bench-{idx:05}\ndescription: Synthetic benchmark skill {idx}\n---\n# bench-{idx:05}\n\nBody {idx}.\n"
                ),
            )
            .expect("write skill");
        }

        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let started_at = Instant::now();
        let count = scan_claude_to_catalog(&ctx, &catalog).expect("benchmark scan succeeds");
        let elapsed = started_at.elapsed();
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(count, SKILL_COUNT);
        assert_eq!(records.len(), SKILL_COUNT);
        println!(
            "skills-copilot-bench scanned={count} records={} elapsed_ms={} elapsed_s={:.3}",
            records.len(),
            elapsed.as_millis(),
            elapsed.as_secs_f64()
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }

    fn temp_test_dir(label: &str) -> PathBuf {
        env::temp_dir().join(format!(
            "skills-copilot-{label}-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("system clock")
                .as_nanos()
        ))
    }

    fn write_codex_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(".agents/skills").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create codex skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write codex skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_codex_skill_file(root: &Path, dir_name: &str, content: &str) -> PathBuf {
        let skill_dir = root.join(".agents/skills").join(dir_name);
        std::fs::create_dir_all(&skill_dir).expect("create codex skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(&skill_path, content).expect("write codex skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn tool_global_instance(id: &str, path: &Path) -> SkillInstance {
        let frontmatter =
            "name: exportable\ndescription: Exportable fixture\nversion: 2.9.0\nallowed-tools:\n  - Read";
        let body = "Use local read-only context.\n";
        SkillInstance {
            id: id.to_string(),
            agent: AgentId::Codex,
            scope: Scope::ToolGlobal,
            project_root: None,
            path: path.to_path_buf(),
            display_path: PathBuf::from("tool-global/exportable/SKILL.md"),
            definition_id: "exportable-definition".to_string(),
            name: "exportable".to_string(),
            display_name: "exportable".to_string(),
            description: "Exportable fixture".to_string(),
            version: Some("2.9.0".to_string()),
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: frontmatter.to_string(),
            body: body.to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest {
                tools: vec!["Read".to_string()],
                ..PermissionRequest::default()
            },
            fingerprint: content_fingerprint(frontmatter, body),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn has_rule_for_name(
        records: &[SkillRecord],
        findings: &[RuleFindingRecord],
        name: &str,
        rule_id: &str,
    ) -> bool {
        let Some(record) = records.iter().find(|record| record.name == name) else {
            return false;
        };
        findings.iter().any(|finding| {
            finding.rule_id == rule_id && finding.instance_id.as_deref() == Some(record.id.as_str())
        })
    }

    fn write_claude_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(".claude/skills").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create claude skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write claude skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_staging_skill(staging_root: &Path, name: &str) -> PathBuf {
        let skill_dir = staging_root.join(name);
        std::fs::create_dir_all(&skill_dir).expect("create staging skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} staging fixture\n---\nbody"),
        )
        .expect("write staging skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_opencode_global_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(".config/opencode/skills").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create opencode skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write opencode skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_pi_global_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(".pi/agent/skills").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create pi skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write pi skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_hermes_global_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(".hermes/skills").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create hermes skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write hermes skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_tool_global_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join("tool-global").join(name);
        std::fs::create_dir_all(&skill_dir).expect("create tool-global skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write tool-global skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn install_tool_global_instance(id: &str, path: PathBuf, name: &str) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::ToolGlobal,
            project_root: None,
            path: path.clone(),
            display_path: path,
            definition_id: name.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "synthetic tool-global import".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: String::new(),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn synthetic_codex_project_instance(
        id: &str,
        project_root: &Path,
        path: PathBuf,
        name: &str,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent: AgentId::Codex,
            scope: Scope::AgentProject,
            project_root: Some(project_root.to_path_buf()),
            path: path.clone(),
            display_path: path,
            definition_id: name.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "synthetic project context guard".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: String::new(),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn synthetic_opencode_project_instance(
        id: &str,
        project_root: &Path,
        path: PathBuf,
        name: &str,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent: AgentId::Opencode,
            scope: Scope::AgentProject,
            project_root: Some(project_root.to_path_buf()),
            path: path.clone(),
            display_path: path,
            definition_id: name.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "synthetic outside-workspace guard".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: format!("name: {name}\ndescription: synthetic\n"),
            body: String::new(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn local_rule_instance(id: &str, frontmatter_raw: &str, body: &str) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent: AgentId::ClaudeCode,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: PathBuf::from(format!("/tmp/{id}/SKILL.md")),
            display_path: PathBuf::from(format!("/tmp/{id}/SKILL.md")),
            definition_id: id.to_string(),
            name: id.to_string(),
            display_name: id.to_string(),
            description: "synthetic local rule skill".to_string(),
            version: None,
            state: SkillState::Loaded,
            enabled: true,
            frontmatter_raw: frontmatter_raw.to_string(),
            body: body.to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn assert_rule_present(report: &RuleReport, rule_id: &str) {
        assert!(
            report
                .findings
                .iter()
                .any(|finding| finding.rule_id == rule_id),
            "expected {rule_id} finding"
        );
    }

    fn assert_rule_absent(report: &RuleReport, rule_id: &str) {
        assert!(
            report
                .findings
                .iter()
                .all(|finding| finding.rule_id != rule_id),
            "did not expect {rule_id} finding"
        );
    }
}
#[cfg(test)]
mod v219_skill_health_tests {
    use super::*;

    #[test]
    fn health_summary_counts_triage_risk_and_analysis_groups() {
        let mut scripted = health_skill(
            "scripted",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "review-diff",
            true,
            SkillState::Loaded,
        );
        scripted.scripts.push(SkillScript {
            name: "setup".to_string(),
            path: PathBuf::from("/tmp/claude/review/scripts/setup.sh"),
            interpreter: Some("bash".to_string()),
            description: None,
            fingerprint: "script-fp".to_string(),
        });
        let scripted_project = health_skill(
            "scripted-project",
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "review-diff",
            true,
            SkillState::Loaded,
        );

        let mut permissioned = health_skill(
            "permissioned",
            AgentId::Codex,
            Scope::AgentGlobal,
            "review-diff",
            false,
            SkillState::Disabled,
        );
        permissioned.permissions.network = NetworkAccess::Full;
        permissioned.permissions.exec = true;

        let broken = health_skill(
            "broken",
            AgentId::Hermes,
            Scope::AgentGlobal,
            "broken-skill",
            false,
            SkillState::Broken,
        );
        let missing = health_skill(
            "missing",
            AgentId::Openclaw,
            Scope::AgentProject,
            "missing-skill",
            false,
            SkillState::Missing,
        );

        let instances = vec![scripted, scripted_project, permissioned, broken, missing];
        let findings = vec![
            health_finding(
                "finding-script",
                Some("scripted"),
                None,
                "script.no-shebang",
                "info",
            ),
            health_finding(
                "finding-permission",
                Some("permissioned"),
                None,
                "permissions.exec-needs-human",
                "warning",
            ),
            health_finding(
                "finding-permission-duplicate",
                Some("permissioned"),
                None,
                "permissions.exec-needs-human",
                "warning",
            ),
            health_finding(
                "finding-malformed",
                Some("broken"),
                None,
                "frontmatter.required-fields",
                "error",
            ),
        ];
        let conflicts = vec![ConflictGroupRecord {
            id: "conflict-review-diff".to_string(),
            definition_id: "def.review-diff".to_string(),
            reason: "content-drift".to_string(),
            winner_id: Some("scripted".to_string()),
            instance_ids: vec!["scripted".to_string(), "scripted-project".to_string()],
        }];
        let analysis = analyze_skill_instances(&instances);

        let health = build_skill_health_summary(&instances, &findings, &conflicts, &analysis);

        assert_eq!(health.total_count, 5);
        assert_eq!(health.enabled_count, 2);
        assert_eq!(health.disabled_count, 3);
        assert_eq!(health.broken_count, 1);
        assert_eq!(health.missing_count, 1);
        assert_eq!(health.malformed_count, 2);
        assert_eq!(health.findings_by_severity.error_count, 1);
        assert_eq!(health.findings_by_severity.warning_count, 1);
        assert_eq!(health.findings_by_severity.info_count, 1);
        assert_eq!(health.finding_count, 3);
        assert_eq!(health.conflict_count, 1);
        assert_eq!(health.risky_script_count, 1);
        assert_eq!(health.risky_permission_count, 1);
        assert!(health.analysis_groups.total_count >= 2);
        assert_eq!(health.analysis_groups.duplicate_name_count, 1);
        assert_eq!(health.analysis_groups.malformed_count, 1);

        let codex = health
            .agent_summaries
            .iter()
            .find(|summary| summary.agent == "codex")
            .expect("codex health summary");
        assert_eq!(codex.total_count, 1);
        assert_eq!(codex.disabled_count, 1);
        assert_eq!(codex.finding_count, 1);
        assert_eq!(codex.conflict_count, 0);
        assert_eq!(codex.risky_permission_count, 1);
        assert!(codex.analysis_group_count >= 1);
    }

    #[test]
    fn health_summary_dedupes_findings_and_counts_only_same_agent_runtime_conflicts() {
        let claude_user = health_skill(
            "claude-user-review",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "review-diff",
            true,
            SkillState::Loaded,
        );
        let claude_project = health_skill(
            "claude-project-review",
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "review-diff",
            true,
            SkillState::Loaded,
        );
        let codex_review = health_skill(
            "codex-review",
            AgentId::Codex,
            Scope::AgentGlobal,
            "review-diff",
            true,
            SkillState::Loaded,
        );
        let opencode_review = health_skill(
            "opencode-review",
            AgentId::Opencode,
            Scope::AgentGlobal,
            "review-diff",
            true,
            SkillState::Loaded,
        );
        let instances = vec![claude_user, claude_project, codex_review, opencode_review];
        let duplicate_finding = health_finding(
            "finding-1",
            Some("claude-user-review"),
            None,
            "body.too-long",
            "warning",
        );
        let mut duplicate_finding_with_new_id = duplicate_finding.clone();
        duplicate_finding_with_new_id.id = "finding-1-duplicate-row".to_string();
        let findings = vec![
            duplicate_finding,
            duplicate_finding_with_new_id,
            health_finding(
                "finding-2",
                Some("codex-review"),
                None,
                "permissions.exec-needs-human",
                "warning",
            ),
        ];
        let conflicts = vec![
            ConflictGroupRecord {
                id: "same-agent-claude-runtime".to_string(),
                definition_id: "def.review-diff".to_string(),
                reason: "content-drift".to_string(),
                winner_id: Some("claude-user-review".to_string()),
                instance_ids: vec![
                    "claude-user-review".to_string(),
                    "claude-project-review".to_string(),
                ],
            },
            ConflictGroupRecord {
                id: "stale-cross-agent-duplicate".to_string(),
                definition_id: "def.review-diff".to_string(),
                reason: "cross-agent-duplicate-name".to_string(),
                winner_id: None,
                instance_ids: vec![
                    "claude-user-review".to_string(),
                    "codex-review".to_string(),
                    "opencode-review".to_string(),
                ],
            },
        ];
        let analysis = analyze_skill_instances(&instances);

        let health = build_skill_health_summary(&instances, &findings, &conflicts, &analysis);

        assert_eq!(health.finding_count, 2);
        assert_eq!(health.findings_by_severity.warning_count, 2);
        assert_eq!(health.conflict_count, 1);
        assert_eq!(health.analysis_groups.duplicate_name_count, 1);

        let claude = health
            .agent_summaries
            .iter()
            .find(|summary| summary.agent == "claude-code")
            .expect("claude health summary");
        assert_eq!(claude.finding_count, 1);
        assert_eq!(claude.conflict_count, 1);

        let codex = health
            .agent_summaries
            .iter()
            .find(|summary| summary.agent == "codex")
            .expect("codex health summary");
        assert_eq!(codex.finding_count, 1);
        assert_eq!(codex.conflict_count, 0);
    }

    #[test]
    fn refresh_rule_outputs_dedupes_same_skill_rule_message_and_remediation() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("catalog initializes");
        let duplicate = Finding {
            instance_id: Some("skill-1".to_string()),
            definition_id: Some("def.skill-1".to_string()),
            rule_id: "body.too-long".to_string(),
            severity: Severity::Warn,
            message: "Skill body is longer than the local review threshold.".to_string(),
            suggestion: Some("Split long reference material into references/.".to_string()),
        };
        let mut second = duplicate.clone();
        second.severity = Severity::Error;
        let report = RuleReport {
            findings: vec![duplicate, second],
            definitions: Vec::new(),
            conflicts: Vec::new(),
        };

        refresh_rule_outputs(&catalog, report).expect("refresh rule outputs");

        let findings = list_findings(&catalog).expect("findings");
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].rule_id, "body.too-long");
        assert_eq!(
            findings[0].suggestion.as_deref(),
            Some("Split long reference material into references/.")
        );
    }

    fn health_skill(
        id: &str,
        agent: AgentId,
        scope: Scope,
        name: &str,
        enabled: bool,
        state: SkillState,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent,
            scope,
            project_root: if scope == Scope::AgentProject {
                Some(PathBuf::from("/tmp/project"))
            } else {
                None
            },
            path: PathBuf::from(format!("/tmp/{}/{}/SKILL.md", agent.as_str(), id)),
            display_path: PathBuf::from(format!("/tmp/{}/{}/SKILL.md", agent.as_str(), id)),
            definition_id: format!("def.{}", canonical_skill_name_suggestion(name)),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "fixture skill".to_string(),
            version: None,
            state,
            enabled,
            frontmatter_raw: format!("name: {name}\ndescription: fixture"),
            body: "fixture body".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: format!("{id}-fingerprint"),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    fn health_finding(
        id: &str,
        instance_id: Option<&str>,
        definition_id: Option<&str>,
        rule_id: &str,
        severity: &str,
    ) -> RuleFindingRecord {
        RuleFindingRecord {
            id: id.to_string(),
            instance_id: instance_id.map(str::to_string),
            definition_id: definition_id.map(str::to_string),
            rule_id: rule_id.to_string(),
            severity: severity.to_string(),
            message: format!("{rule_id} fixture"),
            suggestion: None,
            created_at: 0,
        }
    }
}

#[cfg(test)]
mod v218_cross_agent_analysis_tests {
    use super::*;

    #[test]
    fn cross_agent_analysis_groups_duplicates_overlap_mismatch_and_broken_rows() {
        let shared_path = PathBuf::from("/tmp/shared/SKILL.md");
        let claude = analysis_skill(
            "claude-alpha",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "review-diff",
            true,
            SkillState::Loaded,
            shared_path.clone(),
        );
        let mut codex = analysis_skill(
            "codex-alpha",
            AgentId::Codex,
            Scope::AgentGlobal,
            "review-diff",
            false,
            SkillState::Disabled,
            shared_path.clone(),
        );
        codex.display_path = PathBuf::from("/tmp/codex/shared/SKILL.md");
        let canonical_variant = analysis_skill(
            "pi-alpha",
            AgentId::Pi,
            Scope::AgentGlobal,
            "Review Diff",
            true,
            SkillState::Loaded,
            PathBuf::from("/tmp/pi/review/SKILL.md"),
        );
        let broken = analysis_skill(
            "broken-alpha",
            AgentId::Hermes,
            Scope::AgentGlobal,
            "broken-skill",
            false,
            SkillState::Broken,
            PathBuf::from("/tmp/hermes/broken/SKILL.md"),
        );

        let analysis = analyze_skill_instances(&[claude, codex, canonical_variant, broken]);

        assert_eq!(analysis.summary.duplicate_name_groups, 1);
        assert_eq!(analysis.summary.canonical_name_groups, 1);
        assert_eq!(analysis.summary.path_overlap_groups, 1);
        assert_eq!(analysis.summary.enabled_mismatch_groups, 1);
        assert_eq!(analysis.summary.malformed_groups, 1);
        assert!(analysis.summary.affected_skill_count >= 4);
        assert!(analysis.groups.iter().any(|group| {
            group.kind == "source_path_overlap"
                && group.instance_ids == vec!["claude-alpha".to_string(), "codex-alpha".to_string()]
        }));
        assert!(analysis
            .groups
            .iter()
            .any(|group| { group.kind == "malformed_or_broken" && group.severity == "error" }));
    }

    #[test]
    fn precedence_analysis_only_selects_same_agent_loaded_project_winner() {
        let global = analysis_skill(
            "codex-global",
            AgentId::Codex,
            Scope::AgentGlobal,
            "ship-helper",
            true,
            SkillState::Loaded,
            PathBuf::from("/tmp/home/.agents/skills/ship-helper/SKILL.md"),
        );
        let project = analysis_skill(
            "codex-project",
            AgentId::Codex,
            Scope::AgentProject,
            "ship-helper",
            true,
            SkillState::Loaded,
            PathBuf::from("/tmp/project/.agents/skills/ship-helper/SKILL.md"),
        );
        let other_agent = analysis_skill(
            "claude-project",
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "ship-helper",
            true,
            SkillState::Loaded,
            PathBuf::from("/tmp/project/.claude/skills/ship-helper/SKILL.md"),
        );

        let analysis = analyze_skill_instances(&[global, project, other_agent]);
        let precedence = analysis
            .groups
            .iter()
            .find(|group| group.kind == "precedence_shadowing")
            .expect("same-agent precedence group");

        assert_eq!(analysis.summary.precedence_groups, 1);
        assert_eq!(precedence.winner_id.as_deref(), Some("codex-project"));
        assert_eq!(precedence.agents, vec!["codex".to_string()]);
        assert!(precedence
            .explanation
            .contains("Cross-agent duplicates do not share runtime precedence"));
    }

    fn analysis_skill(
        id: &str,
        agent: AgentId,
        scope: Scope,
        name: &str,
        enabled: bool,
        state: SkillState,
        path: PathBuf,
    ) -> SkillInstance {
        SkillInstance {
            id: id.to_string(),
            agent,
            scope,
            project_root: if scope == Scope::AgentProject {
                Some(PathBuf::from("/tmp/project"))
            } else {
                None
            },
            path: path.clone(),
            display_path: path,
            definition_id: hash_string(&canonical_skill_name_suggestion(name)),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "fixture skill".to_string(),
            version: None,
            state,
            enabled,
            frontmatter_raw: format!("name: {name}\ndescription: fixture"),
            body: "fixture body".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: format!("{id}-fingerprint"),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }
}
