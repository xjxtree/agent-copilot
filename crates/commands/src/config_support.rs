use std::collections::BTreeSet;

use skills_copilot_adapters::{
    ClaudeCodeAdapter, CodexAdapter, HermesAdapter, OpenclawAdapter, OpencodeAdapter, PiAdapter,
};
use skills_copilot_catalog::SkillInstanceMeta;
use skills_copilot_core::{
    AgentConfigAdapter, AgentConfigDocument, AgentId, PermissionRequest, Scope, SkillInstance,
    SkillState,
};

use super::{BatchToggleAffectedItem, BatchToggleSkippedItem, CommandError, ConfigTarget};

pub(super) fn normalize_initial_config_text(config_target: &ConfigTarget, text: String) -> String {
    if config_target.agent == AgentId::Pi && text.trim().is_empty() {
        return pi_default_settings_text(config_target.scope);
    }
    if config_target.agent == AgentId::Hermes && text.trim().is_empty() {
        return hermes_default_config_text();
    }
    if config_target.agent == AgentId::Openclaw && text.trim().is_empty() {
        return openclaw_default_config_text();
    }
    text
}

fn pi_default_settings_text(_scope: Scope) -> String {
    let mut text = serde_json::json!({
        "skills": {
            "disabled": []
        }
    })
    .to_string();
    text.push('\n');
    text
}

fn hermes_default_config_text() -> String {
    "skills:\n  disabled: []\n".to_string()
}

fn openclaw_default_config_text() -> String {
    let mut text = serde_json::json!({
        "skills": {
            "entries": {}
        }
    })
    .to_string();
    text.push('\n');
    text
}

pub(super) fn batch_capability_labels(
    affected_items: &[BatchToggleAffectedItem],
    skipped_items: &[BatchToggleSkippedItem],
) -> Vec<String> {
    let mut labels = BTreeSet::new();
    for item in affected_items {
        labels.insert(item.capability_label.clone());
    }
    for item in skipped_items {
        if let Some(label) = &item.capability_label {
            labels.insert(label.clone());
        }
    }
    labels.into_iter().collect()
}

pub(super) fn batch_snapshot_rollback_notes(
    affected_items: &[BatchToggleAffectedItem],
) -> Vec<String> {
    let targets = affected_items
        .iter()
        .map(|item| item.config_target.clone())
        .collect::<BTreeSet<_>>();
    if targets.is_empty() {
        return vec![
            "No agent config writes are allowed for this selection after filtering.".to_string(),
        ];
    }
    vec![
        format!(
            "Will create one pre-batch-toggle config snapshot for each affected config target ({} target(s)).",
            targets.len()
        ),
        "Each write uses the existing config lock, atomic write, readback verification, and rollback-safe snapshot path.".to_string(),
        "No skill files, scripts, credentials, AI providers, cloud sync, telemetry, or release artifacts are touched.".to_string(),
    ]
}

pub(super) fn batch_capability_label(agent: AgentId) -> &'static str {
    match agent {
        AgentId::ClaudeCode => "Claude Code verified config toggle",
        AgentId::Codex => "Codex verified native-root user-config toggle",
        AgentId::Opencode => "opencode verified exact permission.skill toggle",
        AgentId::Pi => "Pi guarded config toggle",
        AgentId::Hermes => "Hermes verified skills.disabled toggle",
        AgentId::Openclaw => "OpenClaw verified skills.entries toggle",
        AgentId::ToolGlobal => "Tool-global preview; direct toggle blocked",
    }
}

pub(super) fn batch_skip_reason(agent: AgentId, error: &CommandError) -> String {
    match agent {
        AgentId::Pi => error.to_string(),
        AgentId::ToolGlobal => "Tool-global staging records are preview/import sources and do not have agent config toggles.".to_string(),
        _ => error.to_string(),
    }
}

pub(super) fn patch_enabled_for_agent(
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
        AgentId::Pi => PiAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        AgentId::Hermes => HermesAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        AgentId::Openclaw => OpenclawAdapter
            .patch_enabled(doc, instance, on)
            .map_err(|err| CommandError::Adapter(err.message)),
        agent => Err(CommandError::UnsafeConfigPath(format!(
            "{} skills are not writable by config.toggleSkill",
            agent.as_str()
        ))),
    }
}

pub(super) fn minimal_skill_instance(meta: &SkillInstanceMeta) -> SkillInstance {
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

pub(super) fn scope_from_snapshot(scope: &str) -> Result<Scope, CommandError> {
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

pub(super) fn agent_from_snapshot(agent: &str) -> Result<AgentId, CommandError> {
    match agent {
        "claude-code" => Ok(AgentId::ClaudeCode),
        "codex" => Ok(AgentId::Codex),
        "opencode" => Ok(AgentId::Opencode),
        "pi" => Ok(AgentId::Pi),
        "hermes" => Ok(AgentId::Hermes),
        "openclaw" => Ok(AgentId::Openclaw),
        other => Err(CommandError::UnsafeConfigPath(format!(
            "snapshot agent {other} is not writable by config rollback commands"
        ))),
    }
}
