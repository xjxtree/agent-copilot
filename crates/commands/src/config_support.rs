use std::{collections::BTreeSet, fs, io, path::Path};

use skills_copilot_adapters::{
    ClaudeCodeAdapter, CodexAdapter, HermesAdapter, OpenclawAdapter, OpencodeAdapter, PiAdapter,
};
use skills_copilot_catalog::SkillInstanceMeta;
use skills_copilot_core::{
    AdapterContext, AgentConfigAdapter, AgentConfigDocument, AgentId, ConfigFormat,
    PermissionRequest, Scope, SkillInstance, SkillState,
};

use super::{
    expected_config_target, normalize_path_lexically, reject_symlink, BatchToggleAffectedItem,
    BatchToggleSkippedItem, CommandError, ConfigDocumentRecord, ConfigTarget,
};

pub fn read_agent_config(
    ctx: &AdapterContext,
    agent: &str,
    scope: Option<&str>,
) -> Result<Vec<ConfigDocumentRecord>, CommandError> {
    let agent = parse_config_agent(agent)?;
    let scopes = read_config_scopes_for_agent(ctx, agent, scope)?;
    let mut documents = Vec::with_capacity(scopes.len());
    for scope in scopes {
        let target = read_config_target(ctx, agent, scope)?;
        validate_config_read_target(ctx, agent, scope, &target.path)?;
        let default_content = default_config_content(&target);
        let (content, exists) = match fs::read_to_string(&target.path) {
            Ok(content) => (content, true),
            Err(err) if err.kind() == io::ErrorKind::NotFound => (default_content, false),
            Err(err) => return Err(err.into()),
        };
        documents.push(ConfigDocumentRecord {
            agent: agent.as_str().to_string(),
            scope: scope.as_str().to_string(),
            target: target.path.to_string_lossy().to_string(),
            format: config_format_label(target.format).to_string(),
            content,
            exists,
        });
    }
    Ok(documents)
}

fn parse_config_agent(agent: &str) -> Result<AgentId, CommandError> {
    match agent {
        "claude-code" => Ok(AgentId::ClaudeCode),
        "codex" => Ok(AgentId::Codex),
        "opencode" => Ok(AgentId::Opencode),
        "pi" => Ok(AgentId::Pi),
        "hermes" => Ok(AgentId::Hermes),
        "openclaw" => Ok(AgentId::Openclaw),
        other => Err(CommandError::UnsafeConfigPath(format!(
            "agent {other} does not expose readable agent config"
        ))),
    }
}

fn parse_config_scope(scope: &str) -> Result<Scope, CommandError> {
    match scope {
        "agent-global" => Ok(Scope::AgentGlobal),
        "agent-project" => Ok(Scope::AgentProject),
        "tool-global" => Err(CommandError::UnsupportedScope(Scope::ToolGlobal)),
        other => Err(CommandError::UnsafeConfigPath(format!(
            "scope {other} does not expose readable agent config"
        ))),
    }
}

fn read_config_scopes_for_agent(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Option<&str>,
) -> Result<Vec<Scope>, CommandError> {
    if let Some(scope) = scope {
        return Ok(vec![parse_config_scope(scope)?]);
    }

    let mut scopes = vec![Scope::AgentGlobal];
    if ctx.project_root.is_some()
        && matches!(
            agent,
            AgentId::ClaudeCode | AgentId::Codex | AgentId::Opencode | AgentId::Pi
        )
    {
        scopes.push(Scope::AgentProject);
    }
    Ok(scopes)
}

fn read_config_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
) -> Result<ConfigTarget, CommandError> {
    match (agent, scope) {
        (AgentId::Codex, Scope::AgentProject) => Ok(ConfigTarget {
            agent,
            scope,
            path: ctx
                .project_root
                .as_ref()
                .map(|root| root.join(".codex/config.toml"))
                .ok_or(CommandError::UnsupportedScope(scope))?,
            format: ConfigFormat::Toml,
        }),
        _ => expected_config_target(ctx, agent, scope),
    }
}

fn default_config_content(target: &ConfigTarget) -> String {
    match (target.agent, target.format) {
        (AgentId::Pi, ConfigFormat::Json) => pi_default_settings_text(target.scope),
        (AgentId::Hermes, ConfigFormat::Yaml) => hermes_default_config_text(),
        (AgentId::Openclaw, ConfigFormat::Json) => openclaw_default_config_text(),
        (_, ConfigFormat::Json) => "{}\n".to_string(),
        _ => String::new(),
    }
}

fn config_format_label(format: ConfigFormat) -> &'static str {
    match format {
        ConfigFormat::Json => "json",
        ConfigFormat::Toml => "toml",
        ConfigFormat::Yaml => "yaml",
        ConfigFormat::Markdown => "markdown",
    }
}

fn validate_config_read_target(
    ctx: &AdapterContext,
    agent: AgentId,
    scope: Scope,
    path: &Path,
) -> Result<(), CommandError> {
    let expected = read_config_target(ctx, agent, scope)?;
    if path != expected.path.as_path() {
        return Err(CommandError::UnsafeConfigPath(format!(
            "{} does not match expected {} config path {}",
            path.display(),
            agent.as_str(),
            expected.path.display()
        )));
    }

    let allowed_root = match scope {
        Scope::AgentGlobal => &ctx.user_home,
        Scope::AgentProject
            if matches!(
                agent,
                AgentId::ClaudeCode | AgentId::Codex | AgentId::Opencode | AgentId::Pi
            ) =>
        {
            ctx.project_root
                .as_ref()
                .ok_or(CommandError::UnsupportedScope(scope))?
        }
        Scope::ToolGlobal => return Err(CommandError::UnsupportedScope(scope)),
        _ => return Err(CommandError::UnsupportedScope(scope)),
    };
    let parent = path
        .parent()
        .ok_or_else(|| CommandError::UnsafeConfigPath("config path has no parent".to_string()))?;

    reject_symlink(parent, "config directory")?;
    reject_symlink(path, "config file")?;

    let normalized_parent = normalize_path_lexically(parent);
    let normalized_allowed_root = normalize_path_lexically(allowed_root);
    if !normalized_parent.starts_with(&normalized_allowed_root) {
        return Err(CommandError::UnsafeConfigPath(format!(
            "config directory {} is outside allowed root {}",
            parent.display(),
            allowed_root.display()
        )));
    }

    Ok(())
}

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
