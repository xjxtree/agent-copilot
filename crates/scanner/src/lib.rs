use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
    time::UNIX_EPOCH,
};

use sha2::{Digest, Sha256};
use skills_copilot_core::{
    AdapterContext, AdapterRoot, AgentAdapter, AgentId, Scope, SkillInstance, SkillState,
};
use thiserror::Error;
#[derive(Debug, Default)]
pub struct ScanReport {
    pub instances: Vec<SkillInstance>,
    pub skipped_roots: Vec<PathBuf>,
    /// Canonical paths of roots that were actually walked this round.
    /// Callers (e.g. catalog sweep) should only consider records whose
    /// path is under one of these roots as candidates for cleanup.
    pub scanned_roots: Vec<PathBuf>,
}

#[derive(Debug, Error)]
pub enum ScannerError {
    #[error("failed to read directory {path}: {source}")]
    ReadDir {
        path: PathBuf,
        source: std::io::Error,
    },
    #[error("failed to canonicalize root {path}: {source}")]
    CanonicalizeRoot {
        path: PathBuf,
        source: std::io::Error,
    },
}

pub fn scan_roots(adapter: &dyn AgentAdapter, ctx: &AdapterContext) -> Vec<AdapterRoot> {
    adapter.roots(ctx)
}

pub fn scan_agent(
    adapter: &dyn AgentAdapter,
    ctx: &AdapterContext,
) -> Result<ScanReport, ScannerError> {
    let mut report = ScanReport::default();
    let roots = adapter.roots(ctx);
    let mut scanned_root_keys = HashSet::new();
    let overrides = SkillConfigOverrides::preload(adapter.id(), ctx, &roots);
    for root in roots {
        if !root.path.exists() {
            report.skipped_roots.push(root.path);
            continue;
        }
        let canonical_root =
            root.path
                .canonicalize()
                .map_err(|source| ScannerError::CanonicalizeRoot {
                    path: root.path.clone(),
                    source,
                })?;
        if !is_allowed_canonical_root(adapter.id(), ctx, &root, &canonical_root) {
            report.skipped_roots.push(root.path);
            continue;
        }
        let root_key = format!(
            "{}|{}",
            root.scope.as_str(),
            canonical_root.to_string_lossy()
        );
        if !scanned_root_keys.insert(root_key) {
            continue;
        }
        report.scanned_roots.push(canonical_root.clone());
        let allowed_target_base = allowed_target_base(adapter.id(), ctx, &root, &canonical_root);
        visit_root(
            adapter,
            ctx,
            &root,
            &canonical_root,
            &allowed_target_base,
            &overrides,
            &mut report,
        )?;
    }
    report.instances = dedup_instances(report.instances);
    Ok(report)
}

fn is_allowed_canonical_root(
    agent: AgentId,
    ctx: &AdapterContext,
    root: &AdapterRoot,
    canonical_root: &Path,
) -> bool {
    use skills_copilot_core::RootSource;

    let allowed_base = match root.source {
        RootSource::UserHome => ctx.user_home.canonicalize().ok(),
        RootSource::Project if agent == AgentId::Openclaw => {
            openclaw_workspace_base_for_root_path(&root.path)
                .and_then(|workspace_root| workspace_root.canonicalize().ok())
        }
        RootSource::Project => ctx
            .project_root
            .as_ref()
            .and_then(|project_root| project_root.canonicalize().ok()),
        RootSource::Compatibility => match root.scope {
            Scope::AgentGlobal => ctx.user_home.canonicalize().ok(),
            Scope::AgentProject => ctx
                .project_root
                .as_ref()
                .and_then(|project_root| project_root.canonicalize().ok()),
            Scope::ToolGlobal => None,
            _ => None,
        },
        RootSource::Configured
        | RootSource::Admin
        | RootSource::Plugin
        | RootSource::System
        | RootSource::Extra => Some(canonical_root.to_path_buf()),
    };
    allowed_base.is_none_or(|base| canonical_root.starts_with(base))
}

fn visit_root(
    adapter: &dyn AgentAdapter,
    ctx: &AdapterContext,
    root: &AdapterRoot,
    canonical_root: &Path,
    allowed_target_base: &Path,
    overrides: &SkillConfigOverrides,
    report: &mut ScanReport,
) -> Result<(), ScannerError> {
    // Each stack entry is (resolved_dir, display_root).
    // `display_root` is the user-visible path of the directory being scanned.
    // For the initial scan root it equals canonical_root; for symlinked
    // subdirectories it is the original symlink path so that the user sees
    // ~/.claude/skills/foo/SKILL.md rather than ~/.agents/skills/foo/SKILL.md.
    let mut stack: Vec<(PathBuf, PathBuf)> =
        vec![(canonical_root.to_path_buf(), root.path.clone())];
    let mut visited_dirs = HashSet::new();
    while let Some((dir, display_root)) = stack.pop() {
        if !visited_dirs.insert(dir.clone()) {
            continue;
        }
        let entries = fs::read_dir(&dir).map_err(|source| ScannerError::ReadDir {
            path: dir.clone(),
            source,
        })?;
        let mut entries = entries.filter_map(Result::ok).collect::<Vec<_>>();
        entries.sort_by_key(|entry| entry.file_name());
        for entry in entries {
            let path = entry.path();
            let display_path = display_root.join(entry.file_name());
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            if file_type.is_symlink() {
                let Ok(resolved) = path.canonicalize() else {
                    continue;
                };
                if !is_allowed_scan_target(&resolved, canonical_root, allowed_target_base) {
                    continue;
                }
                if resolved.is_dir() {
                    stack.push((resolved, display_path));
                } else if resolved
                    .file_name()
                    .map(|n| n == "SKILL.md")
                    .unwrap_or(false)
                {
                    if !adapter_accepts_skill_path(adapter.id(), canonical_root, &resolved) {
                        continue;
                    }
                    let mut instance = adapter.parse(&resolved).unwrap_or_else(|err| {
                        broken_instance(adapter, root, resolved.clone(), err.message)
                    });
                    normalize_instance(ctx, root, resolved, overrides, &mut instance);
                    instance.display_path = display_path.clone();
                    report.instances.push(instance);
                }
                continue;
            }
            if file_type.is_dir() {
                stack.push((path.clone(), display_path));
                continue;
            }
            if entry.file_name() == "SKILL.md" {
                let Ok(canonical_path) = path.canonicalize() else {
                    continue;
                };
                if !is_allowed_scan_target(&canonical_path, canonical_root, allowed_target_base) {
                    continue;
                }
                if !adapter_accepts_skill_path(adapter.id(), canonical_root, &canonical_path) {
                    continue;
                }
                let mut instance = adapter.parse(&canonical_path).unwrap_or_else(|err| {
                    broken_instance(adapter, root, canonical_path.clone(), err.message)
                });
                normalize_instance(ctx, root, canonical_path, overrides, &mut instance);
                instance.display_path = display_path.clone();
                report.instances.push(instance);
            }
        }
    }
    Ok(())
}

fn adapter_accepts_skill_path(
    agent: AgentId,
    canonical_root: &Path,
    canonical_path: &Path,
) -> bool {
    if agent != AgentId::Pi {
        return true;
    }
    let Ok(relative) = canonical_path.strip_prefix(canonical_root) else {
        return false;
    };
    let components = relative.components().collect::<Vec<_>>();
    components.len() == 2
        && canonical_path.file_name().and_then(|name| name.to_str()) == Some("SKILL.md")
}

fn dedup_instances(instances: Vec<SkillInstance>) -> Vec<SkillInstance> {
    let mut seen_paths = HashSet::new();
    let mut deduped = Vec::new();

    for instance in instances {
        let path_key = format!(
            "{}|{}|{}",
            instance.agent.as_str(),
            instance.scope.as_str(),
            instance.path.to_string_lossy()
        );
        if !seen_paths.insert(path_key) {
            continue;
        }

        deduped.push(instance);
    }

    deduped
}

fn allowed_target_base(
    agent: AgentId,
    ctx: &AdapterContext,
    root: &AdapterRoot,
    canonical_root: &Path,
) -> PathBuf {
    use skills_copilot_core::RootSource;

    match root.source {
        RootSource::UserHome => ctx
            .user_home
            .canonicalize()
            .unwrap_or_else(|_| canonical_root.to_path_buf()),
        RootSource::Project if agent == AgentId::Openclaw => {
            openclaw_workspace_base_for_root_path(&root.path)
                .and_then(|workspace_root| workspace_root.canonicalize().ok())
                .unwrap_or_else(|| canonical_root.to_path_buf())
        }
        RootSource::Project => ctx
            .project_root
            .as_ref()
            .and_then(|project_root| project_root.canonicalize().ok())
            .unwrap_or_else(|| canonical_root.to_path_buf()),
        RootSource::Compatibility => match root.scope {
            Scope::AgentGlobal => ctx
                .user_home
                .canonicalize()
                .unwrap_or_else(|_| canonical_root.to_path_buf()),
            Scope::AgentProject => ctx
                .project_root
                .as_ref()
                .and_then(|project_root| project_root.canonicalize().ok())
                .unwrap_or_else(|| canonical_root.to_path_buf()),
            Scope::ToolGlobal => canonical_root.to_path_buf(),
            _ => canonical_root.to_path_buf(),
        },
        RootSource::Configured
        | RootSource::Admin
        | RootSource::Plugin
        | RootSource::System
        | RootSource::Extra => canonical_root.to_path_buf(),
    }
}

fn is_allowed_scan_target(path: &Path, canonical_root: &Path, allowed_target_base: &Path) -> bool {
    path.starts_with(canonical_root) || path.starts_with(allowed_target_base)
}

fn openclaw_workspace_base_for_root_path(root_path: &Path) -> Option<PathBuf> {
    if root_path.file_name().and_then(|name| name.to_str()) != Some("skills") {
        return None;
    }
    let parent = root_path.parent()?;
    if parent.file_name().and_then(|name| name.to_str()) == Some(".agents") {
        return parent.parent().map(Path::to_path_buf);
    }
    Some(parent.to_path_buf())
}

fn normalize_instance(
    ctx: &AdapterContext,
    root: &AdapterRoot,
    canonical_path: PathBuf,
    overrides: &SkillConfigOverrides,
    instance: &mut SkillInstance,
) {
    instance.scope = root.scope;
    instance.path = canonical_path.clone();
    instance.project_root = match root.scope {
        Scope::AgentProject if instance.agent == AgentId::Openclaw => {
            openclaw_workspace_base_for_root_path(&root.path).or_else(|| ctx.project_root.clone())
        }
        Scope::AgentProject => ctx.project_root.clone(),
        _ => None,
    };
    instance.id = stable_instance_id(
        instance.agent.as_str(),
        root.scope.as_str(),
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

    // Agent config overrides are scoped to the current adapter only. Keep the
    // per-scan settings cache outside adapter parsing so one file is not reread
    // for every skill in a root.
    if matches!(instance.state, SkillState::Loaded)
        && overrides.is_disabled(ctx, root, &instance.name)
    {
        instance.enabled = false;
        instance.state = SkillState::Disabled;
    }
}

#[derive(Debug)]
struct SkillConfigOverrides {
    agent: AgentId,
    disabled_by_settings_path: HashMap<PathBuf, HashSet<String>>,
}

impl SkillConfigOverrides {
    fn preload(agent: AgentId, ctx: &AdapterContext, roots: &[AdapterRoot]) -> Self {
        let mut disabled_by_settings_path = HashMap::new();
        match agent {
            AgentId::ClaudeCode => {
                for settings_path in roots
                    .iter()
                    .filter_map(|root| claude_settings_path_for(ctx, root))
                    .collect::<HashSet<_>>()
                {
                    if let Some(disabled) = read_disabled_claude_skill_overrides(&settings_path) {
                        disabled_by_settings_path.insert(settings_path, disabled);
                    }
                }
            }
            AgentId::Opencode => {
                for settings_path in roots
                    .iter()
                    .filter_map(|root| opencode_settings_path_for(ctx, root))
                    .collect::<HashSet<_>>()
                {
                    if let Some(disabled) = read_disabled_opencode_skill_permissions(&settings_path)
                    {
                        disabled_by_settings_path.insert(settings_path, disabled);
                    }
                }
            }
            _ => {}
        }

        Self {
            agent,
            disabled_by_settings_path,
        }
    }

    fn is_disabled(&self, ctx: &AdapterContext, root: &AdapterRoot, skill_name: &str) -> bool {
        let settings_path = match self.agent {
            AgentId::Opencode => opencode_settings_path_for(ctx, root),
            AgentId::ClaudeCode => claude_settings_path_for(ctx, root),
            _ => None,
        };
        settings_path
            .and_then(|settings_path| self.disabled_by_settings_path.get(&settings_path))
            .is_some_and(|disabled| disabled.contains(skill_name))
    }
}

fn claude_settings_path_for(ctx: &AdapterContext, root: &AdapterRoot) -> Option<PathBuf> {
    match root.scope {
        Scope::AgentGlobal => Some(ctx.user_home.join(".claude/settings.json")),
        Scope::AgentProject => ctx
            .project_root
            .as_ref()
            .map(|p| p.join(".claude/settings.local.json")),
        Scope::ToolGlobal => None,
        // Scope is `#[non_exhaustive]`; future variants have no default path.
        _ => None,
    }
}

fn opencode_settings_path_for(ctx: &AdapterContext, root: &AdapterRoot) -> Option<PathBuf> {
    match root.scope {
        Scope::AgentGlobal => Some(ctx.user_home.join(".config/opencode/opencode.json")),
        Scope::AgentProject => ctx.project_root.as_ref().map(|p| p.join("opencode.json")),
        Scope::ToolGlobal => None,
        _ => None,
    }
}

fn read_disabled_claude_skill_overrides(settings_path: &Path) -> Option<HashSet<String>> {
    let Ok(content) = fs::read_to_string(settings_path) else {
        return None;
    };
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&content) else {
        return None;
    };
    let overrides = value
        .get("skillOverrides")
        .and_then(serde_json::Value::as_object)?;
    Some(
        overrides
            .iter()
            .filter(|(_, value)| *value == "off")
            .map(|(name, _)| name.clone())
            .collect(),
    )
}

fn read_disabled_opencode_skill_permissions(settings_path: &Path) -> Option<HashSet<String>> {
    let Ok(content) = fs::read_to_string(settings_path) else {
        return None;
    };
    let stripped = strip_json_comments(&content);
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&stripped) else {
        return None;
    };
    let skill_permissions = value
        .get("permission")
        .and_then(|permission| permission.get("skill"))
        .and_then(serde_json::Value::as_object)?;
    Some(
        skill_permissions
            .iter()
            .filter(|(_, value)| value.as_str() == Some("deny"))
            .filter(|(name, _)| !name.contains('*') && !name.contains('?'))
            .map(|(name, _)| name.clone())
            .collect(),
    )
}

fn strip_json_comments(content: &str) -> String {
    let mut output = String::with_capacity(content.len());
    let mut chars = content.chars().peekable();
    let mut in_string = false;
    let mut escaped = false;

    while let Some(ch) = chars.next() {
        if in_string {
            output.push(ch);
            if escaped {
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                in_string = false;
            }
            continue;
        }

        if ch == '"' {
            in_string = true;
            output.push(ch);
            continue;
        }

        if ch == '/' {
            match chars.peek().copied() {
                Some('/') => {
                    chars.next();
                    for next in chars.by_ref() {
                        if next == '\n' {
                            output.push('\n');
                            break;
                        }
                    }
                    continue;
                }
                Some('*') => {
                    chars.next();
                    let mut previous = '\0';
                    for next in chars.by_ref() {
                        if previous == '*' && next == '/' {
                            break;
                        }
                        previous = next;
                    }
                    continue;
                }
                _ => {}
            }
        }

        output.push(ch);
    }

    output
}

fn broken_instance(
    adapter: &dyn AgentAdapter,
    root: &AdapterRoot,
    path: PathBuf,
    message: String,
) -> SkillInstance {
    let name = path
        .parent()
        .and_then(Path::file_name)
        .and_then(|name| name.to_str())
        .unwrap_or("broken")
        .to_string();
    SkillInstance {
        id: stable_instance_id(adapter.id().as_str(), root.scope.as_str(), &path),
        agent: adapter.id(),
        scope: root.scope,
        project_root: None,
        path: path.clone(),
        display_path: path,
        definition_id: canonical_definition_id(&name),
        name: name.clone(),
        display_name: name,
        description: message,
        version: None,
        state: SkillState::Broken,
        enabled: false,
        frontmatter_raw: String::new(),
        body: String::new(),
        scripts: Vec::new(),
        permissions: Default::default(),
        fingerprint: String::new(),
        mtime: 0,
        first_seen: 0,
        last_seen: 0,
    }
}

fn stable_instance_id(agent: &str, scope: &str, path: &Path) -> String {
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

#[cfg(test)]
mod tests {
    use skills_copilot_adapters::{
        ClaudeCodeAdapter, CodexAdapter, HermesAdapter, OpenclawAdapter, OpencodeAdapter, PiAdapter,
    };
    use skills_copilot_core::{AdapterContext, AdapterRoot, RootSource};

    use super::*;

    #[test]
    fn scans_extra_root_for_skill_files() {
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

        let report = scan_agent(&ClaudeCodeAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 1);
        assert_eq!(report.instances[0].name, "summarize-changes");
        assert_eq!(report.instances[0].scope, Scope::AgentGlobal);
    }

    #[test]
    fn claude_skill_overrides_do_not_disable_other_agents() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-claude-only-overrides-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let claude_skill_dir = home.join(".claude/skills/same-name");
        let codex_skill_dir = home.join(".agents/skills/same-name");
        let opencode_skill_dir = home.join(".config/opencode/skills/same-name");
        std::fs::create_dir_all(&claude_skill_dir).expect("create Claude skill dir");
        std::fs::create_dir_all(&codex_skill_dir).expect("create Codex skill dir");
        std::fs::create_dir_all(&opencode_skill_dir).expect("create opencode skill dir");
        std::fs::write(
            home.join(".claude/settings.json"),
            "{\n  \"skillOverrides\": {\n    \"same-name\": \"off\"\n  }\n}\n",
        )
        .expect("write Claude settings");
        std::fs::write(
            claude_skill_dir.join("SKILL.md"),
            "---\nname: same-name\ndescription: Claude skill\n---\nBody.\n",
        )
        .expect("write Claude skill");
        std::fs::write(
            codex_skill_dir.join("SKILL.md"),
            "---\nname: same-name\ndescription: Codex skill\n---\nBody.\n",
        )
        .expect("write Codex skill");
        std::fs::write(
            opencode_skill_dir.join("SKILL.md"),
            "---\nname: same-name\ndescription: opencode skill\n---\nBody.\n",
        )
        .expect("write opencode skill");

        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let claude = scan_agent(&ClaudeCodeAdapter, &ctx).expect("Claude scan succeeds");
        let codex = scan_agent(&CodexAdapter, &ctx).expect("Codex scan succeeds");
        let opencode = scan_agent(&OpencodeAdapter, &ctx).expect("opencode scan succeeds");

        assert_eq!(claude.instances.len(), 1);
        assert_eq!(claude.instances[0].name, "same-name");
        assert_eq!(claude.instances[0].state, SkillState::Disabled);
        assert!(!claude.instances[0].enabled);

        assert_eq!(codex.instances.len(), 1);
        assert_eq!(codex.instances[0].name, "same-name");
        assert_eq!(codex.instances[0].state, SkillState::Loaded);
        assert!(codex.instances[0].enabled);

        assert_eq!(opencode.instances.len(), 3);
        assert!(opencode
            .instances
            .iter()
            .all(|skill| skill.name == "same-name"
                && skill.state == SkillState::Loaded
                && skill.enabled));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn follows_user_home_symlinks_that_stay_inside_user_home() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-home-symlink-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let claude_skills_dir = home.join(".claude/skills");
        let real_skill_dir = home.join(".agents/skills/symlink-test");
        std::fs::create_dir_all(&real_skill_dir).expect("create real skill dir");
        std::fs::create_dir_all(&claude_skills_dir).expect("create claude skills dir");
        std::fs::write(
            real_skill_dir.join("SKILL.md"),
            "---\nname: symlink-test\ndescription: follows user-home symlinks\n---\nBody.",
        )
        .expect("write SKILL.md");
        std::os::unix::fs::symlink(&real_skill_dir, claude_skills_dir.join("symlink-test"))
            .expect("create symlink");

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&ClaudeCodeAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 1);
        assert_eq!(report.instances[0].name, "symlink-test");
        assert_eq!(
            report.instances[0].display_path,
            claude_skills_dir.join("symlink-test").join("SKILL.md"),
            "display_path should show the original symlink location"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn rejects_extra_root_symlinks_outside_scan_root() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-symlink-{}", std::process::id()));
        let skills_dir = temp_root.join("skills");
        let real_skill_dir = temp_root.join("real-skill-outside-scan-root");
        std::fs::create_dir_all(&real_skill_dir).expect("create real skill dir");
        std::fs::create_dir_all(&skills_dir).expect("create skills dir");
        std::fs::write(
            real_skill_dir.join("SKILL.md"),
            "---\nname: symlink-test\ndescription: follows symlinks\n---\nBody.",
        )
        .expect("write SKILL.md");
        std::os::unix::fs::symlink(&real_skill_dir, skills_dir.join("symlink-test"))
            .expect("create symlink");

        let ctx = AdapterContext {
            user_home: temp_root.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: skills_dir.clone(),
                source: RootSource::Extra,
            }],
        };

        let report = scan_agent(&ClaudeCodeAdapter, &ctx).expect("scan succeeds");

        assert!(
            report.instances.is_empty(),
            "scanner must reject SKILL.md files whose canonical path escapes the scanned root"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn rejects_builtin_root_symlink_that_escapes_user_home() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-root-symlink-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let claude_dir = home.join(".claude");
        let outside_skills_dir = temp_root.join("outside-skills");
        let outside_skill_dir = outside_skills_dir.join("escaped");
        std::fs::create_dir_all(&claude_dir).expect("create claude dir");
        std::fs::create_dir_all(&outside_skill_dir).expect("create outside skill dir");
        std::fs::write(
            outside_skill_dir.join("SKILL.md"),
            "---\nname: escaped\ndescription: outside root\n---\nBody.",
        )
        .expect("write outside SKILL.md");
        std::os::unix::fs::symlink(&outside_skills_dir, claude_dir.join("skills"))
            .expect("create root symlink");

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&ClaudeCodeAdapter, &ctx).expect("scan succeeds");

        assert!(
            report.instances.is_empty(),
            "builtin user-home root symlink must not let the scanner escape user_home"
        );
        assert_eq!(report.skipped_roots, vec![home.join(".claude/skills")]);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    #[cfg(unix)]
    fn rejects_project_root_symlinks_outside_project_root() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-project-symlink-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("project");
        let project_skills_dir = project.join(".claude/skills");
        let home_skill_dir = home.join(".agents/skills/home-only");
        std::fs::create_dir_all(&project_skills_dir).expect("create project skills dir");
        std::fs::create_dir_all(&home_skill_dir).expect("create home skill dir");
        std::fs::write(
            home_skill_dir.join("SKILL.md"),
            "---\nname: home-only\ndescription: outside project\n---\nBody.",
        )
        .expect("write home SKILL.md");
        std::os::unix::fs::symlink(&home_skill_dir, project_skills_dir.join("home-only"))
            .expect("create project symlink");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(project),
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&ClaudeCodeAdapter, &ctx).expect("scan succeeds");

        assert!(
            report.instances.is_empty(),
            "project roots must not scan symlink targets outside the project root"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn opencode_permission_skill_deny_marks_exact_skill_disabled() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-permission-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let skill_dir = home.join(".config/opencode/skills/global-review");
        std::fs::create_dir_all(&skill_dir).expect("create opencode skill dir");
        std::fs::create_dir_all(home.join(".config/opencode")).expect("create opencode config dir");
        std::fs::write(
            skill_dir.join("SKILL.md"),
            "---\nname: global-review\ndescription: opencode disabled fixture\n---\nBody.",
        )
        .expect("write opencode SKILL.md");
        std::fs::write(
            home.join(".config/opencode/opencode.json"),
            r#"{
              // JSONC comments are accepted for readback.
              "permission": {
                "skill": {
                  "*": "allow",
                  "global-review": "deny"
                }
              }
            }"#,
        )
        .expect("write opencode config");

        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpencodeAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 1);
        assert_eq!(report.instances[0].name, "global-review");
        assert!(!report.instances[0].enabled);
        assert_eq!(report.instances[0].state, SkillState::Disabled);

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn opencode_scans_claude_and_agent_compatible_roots_with_opencode_permissions() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-compat-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let claude_skill_dir = home.join(".claude/skills/claude-compatible");
        let agent_skill_dir = home.join(".agents/skills/agent-compatible");
        std::fs::create_dir_all(&claude_skill_dir).expect("create Claude-compatible skill dir");
        std::fs::create_dir_all(&agent_skill_dir).expect("create agent-compatible skill dir");
        std::fs::create_dir_all(home.join(".config/opencode")).expect("create opencode config dir");
        std::fs::write(
            claude_skill_dir.join("SKILL.md"),
            "---\nname: claude-compatible\ndescription: opencode Claude compatibility fixture\n---\nBody.",
        )
        .expect("write Claude-compatible SKILL.md");
        std::fs::write(
            agent_skill_dir.join("SKILL.md"),
            "---\nname: agent-compatible\ndescription: opencode agent compatibility fixture\n---\nBody.",
        )
        .expect("write agent-compatible SKILL.md");
        std::fs::write(
            home.join(".claude/settings.json"),
            "{\n  \"skillOverrides\": {\n    \"claude-compatible\": \"off\"\n  }\n}\n",
        )
        .expect("write Claude settings");
        std::fs::write(
            home.join(".config/opencode/opencode.json"),
            r#"{"permission":{"skill":{"agent-compatible":"deny"}}}"#,
        )
        .expect("write opencode config");

        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpencodeAdapter, &ctx).expect("scan succeeds");
        let by_name: HashMap<_, _> = report
            .instances
            .iter()
            .map(|skill| (skill.name.as_str(), (skill.state.clone(), skill.enabled)))
            .collect();

        assert_eq!(report.instances.len(), 2);
        assert_eq!(
            by_name.get("claude-compatible"),
            Some(&(SkillState::Loaded, true)),
            "opencode compatibility roots must not inherit Claude skillOverrides"
        );
        assert_eq!(
            by_name.get("agent-compatible"),
            Some(&(SkillState::Disabled, false)),
            "opencode compatibility roots must honor opencode permission.skill"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn opencode_scans_configured_local_paths_without_fetching_urls() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-configured-scan-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let configured_root = temp_root.join("custom-skills");
        let skill_dir = configured_root.join("custom-review");
        std::fs::create_dir_all(&skill_dir).expect("create configured skill dir");
        std::fs::create_dir_all(home.join(".config/opencode")).expect("create opencode config dir");
        std::fs::write(
            skill_dir.join("SKILL.md"),
            "---\nname: custom-review\ndescription: opencode configured path fixture\n---\nBody.",
        )
        .expect("write configured skill");
        std::fs::write(
            home.join(".config/opencode/opencode.json"),
            format!(
                r#"{{
                  "skills": {{
                    "paths": ["{0}", "{0}"],
                    "urls": ["https://example.invalid/.well-known/skills/"]
                  }},
                  "permission": {{
                    "skill": {{
                      "custom-review": "deny"
                    }}
                  }}
                }}"#,
                configured_root.to_string_lossy()
            ),
        )
        .expect("write opencode config");

        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpencodeAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 1);
        assert_eq!(report.instances[0].name, "custom-review");
        assert_eq!(report.instances[0].state, SkillState::Disabled);
        assert!(!report.instances[0].enabled);
        assert_eq!(
            report.scanned_roots.len(),
            1,
            "duplicate configured paths should canonicalize and dedupe before scanning"
        );
        assert!(report.scanned_roots[0].ends_with("custom-skills"));
        assert!(
            report
                .skipped_roots
                .iter()
                .all(|root| !root.to_string_lossy().contains("https://example.invalid")),
            "skills.urls must not become skipped filesystem roots or trigger fetch attempts"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn opencode_keeps_native_and_compatible_roots_for_conflict_analysis() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-dedup-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let native_skill_dir = home.join(".config/opencode/skills/shared-review");
        let claude_skill_dir = home.join(".claude/skills/shared-review");
        let agents_skill_dir = home.join(".agents/skills/shared-review");
        std::fs::create_dir_all(&native_skill_dir).expect("create native skill dir");
        std::fs::create_dir_all(&claude_skill_dir).expect("create Claude-compatible skill dir");
        std::fs::create_dir_all(&agents_skill_dir).expect("create agents-compatible skill dir");
        for dir in [&native_skill_dir, &claude_skill_dir, &agents_skill_dir] {
            std::fs::write(
                dir.join("SKILL.md"),
                "---\nname: shared-review\ndescription: duplicate opencode fixture\n---\nBody.",
            )
            .expect("write duplicate opencode skill");
        }

        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpencodeAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 3);
        assert!(report.instances.iter().any(|skill| skill.path
            == native_skill_dir
                .join("SKILL.md")
                .canonicalize()
                .expect("canonical native path")));
        assert!(report
            .instances
            .iter()
            .all(|skill| skill.name == "shared-review"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn pi_scans_native_directory_skills_and_ignores_plain_markdown() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-pi-scan-{}", std::process::id()));
        let home = temp_root.join("home");
        let root = home.join(".pi/agent/skills");
        let dir_skill = root.join("global-pdf");
        std::fs::create_dir_all(&dir_skill).expect("create pi dir skill");
        std::fs::write(
            dir_skill.join("SKILL.md"),
            "---\nname: global-pdf\ndescription: Pi directory fixture\n---\nBody.",
        )
        .expect("write pi dir skill");
        std::fs::write(
            root.join("root-note.md"),
            "---\nname: root-note\ndescription: Pi root markdown fixture\n---\nBody.",
        )
        .expect("write pi root markdown");
        let nested_reference_dir = dir_skill.join("references");
        std::fs::create_dir_all(&nested_reference_dir).expect("create nested reference dir");
        std::fs::write(
            nested_reference_dir.join("implementation.md"),
            "---\nname: implementation\ndescription: This markdown is support material, not a Pi root skill.\n---\nBody.",
        )
        .expect("write nested reference markdown");
        std::fs::write(
            nested_reference_dir.join("SKILL.md"),
            "---\nname: implementation\ndescription: This nested SKILL.md is support material, not a Pi root skill.\n---\nBody.",
        )
        .expect("write nested reference SKILL.md");
        std::fs::write(
            root.join("SKILL.md"),
            "---\nname: root-noise\ndescription: Historical catalog noise, not a Pi directory skill.\n---\nBody.",
        )
        .expect("write root SKILL.md noise");

        let ctx = AdapterContext {
            user_home: home,
            project_root: None,
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&PiAdapter, &ctx).expect("scan succeeds");
        let names: HashSet<_> = report
            .instances
            .iter()
            .map(|skill| skill.name.as_str())
            .collect();

        assert_eq!(report.instances.len(), 1);
        assert!(names.contains("global-pdf"));
        assert!(!names.contains("root-note"));
        assert!(!names.contains("implementation"));
        assert!(!names.contains("root-noise"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn pi_scans_agent_compatibility_roots_without_markdown_noise() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-pi-compat-scan-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("project");
        let global_root = home.join(".agents/skills");
        let project_root = project.join(".agents/skills");
        let global_skill = global_root.join("pi-agent-global");
        let project_skill = project_root.join("pi-agent-project");
        std::fs::create_dir_all(&global_skill).expect("create global compat skill");
        std::fs::create_dir_all(&project_skill).expect("create project compat skill");
        std::fs::write(
            global_skill.join("SKILL.md"),
            "---\nname: pi-agent-global\ndescription: Pi global compatibility fixture\n---\nBody.",
        )
        .expect("write global compat skill");
        std::fs::write(
            project_skill.join("SKILL.md"),
            "---\nname: pi-agent-project\ndescription: Pi project compatibility fixture\n---\nBody.",
        )
        .expect("write project compat skill");
        std::fs::write(
            global_root.join("root-noise.md"),
            "---\nname: root-noise\ndescription: ignored compatibility markdown\n---\nBody.",
        )
        .expect("write root markdown");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(project.clone()),
            project_cwd: Some(project),
            extra_roots: vec![],
        };

        let report = scan_agent(&PiAdapter, &ctx).expect("scan succeeds");
        let names: HashSet<_> = report
            .instances
            .iter()
            .map(|skill| skill.name.as_str())
            .collect();

        assert!(names.contains("pi-agent-global"));
        assert!(names.contains("pi-agent-project"));
        assert!(!names.contains("root-noise"));
        assert!(report
            .scanned_roots
            .iter()
            .any(|root| root.ends_with(".agents/skills")));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn openclaw_scans_documented_global_and_selected_home_workspace_roots() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-openclaw-scan-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let workspace = home.join(".openclaw/workspace");
        let managed_global_path =
            write_openclaw_skill(&home.join(".openclaw/skills"), "managed-global");
        write_openclaw_skill(&home.join(".agents/skills"), "managed-global");
        write_openclaw_skill(&home.join(".agents/skills"), "personal-shared");
        write_openclaw_skill(&workspace.join("skills"), "workspace-local");
        write_openclaw_skill(&workspace.join(".agents/skills"), "workspace-agents");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(workspace),
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpenclawAdapter, &ctx).expect("scan succeeds");
        let by_name: HashMap<_, _> = report
            .instances
            .iter()
            .map(|skill| (skill.name.as_str(), skill.scope))
            .collect();

        assert_eq!(report.instances.len(), 5);
        assert_eq!(by_name.get("managed-global"), Some(&Scope::AgentGlobal));
        assert_eq!(by_name.get("personal-shared"), Some(&Scope::AgentGlobal));
        assert_eq!(by_name.get("workspace-local"), Some(&Scope::AgentProject));
        assert_eq!(by_name.get("workspace-agents"), Some(&Scope::AgentProject));
        assert_eq!(
            report
                .instances
                .iter()
                .find(|skill| skill.name == "managed-global")
                .expect("managed global")
                .path,
            managed_global_path,
            "OpenClaw native global root wins over shared compatibility root"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn openclaw_scans_home_workspace_roots_when_selected_project_is_inside_workspace() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-openclaw-nested-workspace-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let workspace = home.join(".openclaw/workspace");
        let nested_project = workspace.join("repo");
        let workspace_skill = write_openclaw_skill(&workspace.join("skills"), "workspace-local");
        let workspace_agents_skill =
            write_openclaw_skill(&workspace.join(".agents/skills"), "workspace-agents");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(nested_project.clone()),
            project_cwd: Some(nested_project.join("nested")),
            extra_roots: vec![],
        };

        let report = scan_agent(&OpenclawAdapter, &ctx).expect("scan succeeds");
        let by_name: HashMap<_, _> = report
            .instances
            .iter()
            .map(|skill| (skill.name.as_str(), skill))
            .collect();

        assert_eq!(report.instances.len(), 2);
        assert_eq!(
            by_name.get("workspace-local").map(|skill| &skill.path),
            Some(&workspace_skill)
        );
        assert_eq!(
            by_name.get("workspace-agents").map(|skill| &skill.path),
            Some(&workspace_agents_skill)
        );
        assert!(report.instances.iter().all(|skill| {
            skill.scope == Scope::AgentProject && skill.project_root == Some(workspace.clone())
        }));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn openclaw_does_not_scan_arbitrary_project_skill_roots() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-openclaw-project-scope-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let project = temp_root.join("repo");
        write_openclaw_skill(&project.join("skills"), "not-workspace-skills");
        write_openclaw_skill(&project.join(".agents/skills"), "not-workspace-agents");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(project),
            project_cwd: None,
            extra_roots: vec![],
        };

        let report = scan_agent(&OpenclawAdapter, &ctx).expect("scan succeeds");

        assert!(
            report.instances.is_empty(),
            "OpenClaw must not infer arbitrary repo skills or .agents roots as workspace roots"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn hermes_scans_active_home_and_explicit_external_dirs_only() {
        let temp_root =
            std::env::temp_dir().join(format!("skills-copilot-hermes-scan-{}", std::process::id()));
        let home = temp_root.join("home");
        let hermes_skill_path = write_hermes_skill(
            &home.join(".hermes/skills/nested/research"),
            "hermes-research",
        );
        let external_skill_path = write_hermes_skill(
            &temp_root.join("configured-external/analysis"),
            "external-analysis",
        );
        write_hermes_skill(
            &temp_root.join("repo/skills/project-skill"),
            "project-skill",
        );
        std::fs::write(
            home.join(".hermes/config.yaml"),
            format!(
                "skills:\n  external_dirs:\n    - {}\n",
                temp_root.join("configured-external").display()
            ),
        )
        .expect("write Hermes config");
        std::fs::create_dir_all(home.join(".hermes/cron")).expect("create hermes cron dir");
        std::fs::create_dir_all(home.join(".hermes/logs")).expect("create hermes logs dir");
        std::fs::write(home.join(".hermes/.env"), "HERMES_TOKEN=<redacted>\n")
            .expect("write redacted env fixture");
        std::fs::write(
            home.join(".hermes/auth.json"),
            "{\"token\":\"<redacted>\"}\n",
        )
        .expect("write redacted auth fixture");
        std::fs::write(
            home.join(".hermes/cron/jobs.json"),
            "{\"jobs\":[{\"id\":\"not-a-skill\",\"enabled\":false}]}\n",
        )
        .expect("write cron fixture");
        std::fs::write(home.join(".hermes/logs/session.log"), "<redacted>\n")
            .expect("write log fixture");

        let ctx = AdapterContext {
            user_home: home,
            project_root: Some(temp_root.join("repo")),
            project_cwd: Some(temp_root.join("repo/nested")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: temp_root.join("unverified"),
                source: RootSource::Extra,
            }],
        };

        let report = scan_agent(&HermesAdapter, &ctx).expect("scan succeeds");

        assert_eq!(report.instances.len(), 2);
        assert!(report.instances.iter().any(|instance| {
            instance.agent == AgentId::Hermes
                && instance.scope == Scope::AgentGlobal
                && instance.name == "hermes-research"
                && instance.path == hermes_skill_path
        }));
        assert!(report.instances.iter().any(|instance| {
            instance.agent == AgentId::Hermes
                && instance.scope == Scope::AgentGlobal
                && instance.name == "external-analysis"
                && instance.path == external_skill_path
        }));
        assert!(report
            .instances
            .iter()
            .all(|instance| instance.name != "project-skill"));

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }

    fn write_openclaw_skill(root: &Path, name: &str) -> PathBuf {
        let skill_dir = root.join(name);
        std::fs::create_dir_all(&skill_dir).expect("create OpenClaw skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write OpenClaw skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }

    fn write_hermes_skill(root: &Path, name: &str) -> PathBuf {
        std::fs::create_dir_all(root).expect("create Hermes skill dir");
        let skill_path = root.join("SKILL.md");
        std::fs::write(
            &skill_path,
            format!("---\nname: {name}\ndescription: {name} fixture\n---\nbody"),
        )
        .expect("write Hermes skill");
        skill_path.canonicalize().expect("canonicalize skill path")
    }
}
