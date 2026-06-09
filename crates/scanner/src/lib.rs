use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
    time::UNIX_EPOCH,
};

use sha2::{Digest, Sha256};
use skills_copilot_core::{
    AdapterContext, AdapterRoot, AgentAdapter, AgentId, RootSource, Scope, SkillInstance,
    SkillState,
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
        if !is_allowed_canonical_root(ctx, &root, &canonical_root) {
            report.skipped_roots.push(root.path);
            continue;
        }
        report.scanned_roots.push(canonical_root.clone());
        let allowed_target_base = allowed_target_base(ctx, &root, &canonical_root);
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
    Ok(report)
}

fn is_allowed_canonical_root(
    ctx: &AdapterContext,
    root: &AdapterRoot,
    canonical_root: &Path,
) -> bool {
    use skills_copilot_core::RootSource;

    let allowed_base = match root.source {
        RootSource::UserHome => ctx.user_home.canonicalize().ok(),
        RootSource::Project => ctx
            .project_root
            .as_ref()
            .and_then(|project_root| project_root.canonicalize().ok()),
        RootSource::Extra => None,
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
        for entry in entries {
            let Ok(entry) = entry else {
                continue;
            };
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

fn allowed_target_base(ctx: &AdapterContext, root: &AdapterRoot, canonical_root: &Path) -> PathBuf {
    use skills_copilot_core::RootSource;

    match root.source {
        RootSource::UserHome => ctx
            .user_home
            .canonicalize()
            .unwrap_or_else(|_| canonical_root.to_path_buf()),
        RootSource::Project => ctx
            .project_root
            .as_ref()
            .and_then(|project_root| project_root.canonicalize().ok())
            .unwrap_or_else(|| canonical_root.to_path_buf()),
        RootSource::Extra => canonical_root.to_path_buf(),
    }
}

fn is_allowed_scan_target(path: &Path, canonical_root: &Path, allowed_target_base: &Path) -> bool {
    path.starts_with(canonical_root) || path.starts_with(allowed_target_base)
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

#[derive(Debug, Default)]
struct SkillConfigOverrides {
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
            disabled_by_settings_path,
        }
    }

    fn is_disabled(&self, ctx: &AdapterContext, root: &AdapterRoot, skill_name: &str) -> bool {
        let settings_path = match root.source {
            RootSource::UserHome if root.path.ends_with(".config/opencode/skills") => {
                opencode_settings_path_for(ctx, root)
            }
            RootSource::Project if root.path.ends_with(".opencode/skills") => {
                opencode_settings_path_for(ctx, root)
            }
            _ => claude_settings_path_for(ctx, root),
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
    use skills_copilot_adapters::{ClaudeCodeAdapter, CodexAdapter, OpencodeAdapter};
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

        assert_eq!(opencode.instances.len(), 1);
        assert_eq!(opencode.instances[0].name, "same-name");
        assert_eq!(opencode.instances[0].state, SkillState::Loaded);
        assert!(opencode.instances[0].enabled);

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

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
