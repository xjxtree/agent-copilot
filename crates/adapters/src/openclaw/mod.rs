use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentId, PermissionRequest,
    RootSource, Scope, SkillInstance, SkillState,
};

#[derive(Debug, Default)]
pub struct OpenclawAdapter;

impl AgentAdapter for OpenclawAdapter {
    fn id(&self) -> AgentId {
        AgentId::Openclaw
    }

    fn display_name(&self) -> &'static str {
        "OpenClaw"
    }

    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot> {
        let mut roots = vec![
            AdapterRoot {
                scope: Scope::AgentGlobal,
                path: ctx.user_home.join(".openclaw/skills"),
                source: RootSource::UserHome,
            },
            AdapterRoot {
                scope: Scope::AgentGlobal,
                path: ctx.user_home.join(".agents/skills"),
                source: RootSource::UserHome,
            },
        ];

        roots.extend(openclaw_bundled_skill_roots());

        if let Some(workspace_root) = openclaw_selected_workspace_root(ctx) {
            roots.push(AdapterRoot {
                scope: Scope::AgentProject,
                path: workspace_root.join("skills"),
                source: RootSource::Project,
            });
            roots.push(AdapterRoot {
                scope: Scope::AgentProject,
                path: workspace_root.join(".agents/skills"),
                source: RootSource::Project,
            });
        }

        roots
    }

    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError> {
        let content = std::fs::read_to_string(path)
            .map_err(|err| AdapterError::new(format!("failed to read skill: {err}")))?;
        let fallback_name = containing_dir_name(path);
        let parsed = parse_skill_content(&content, &fallback_name);
        let (frontmatter_raw, body, name, description, version, state, enabled) = match parsed {
            Ok(parsed) => (
                parsed.frontmatter_raw,
                parsed.body,
                parsed.name,
                parsed.description,
                parsed.version,
                SkillState::Loaded,
                true,
            ),
            Err(message) => (
                String::new(),
                content,
                fallback_name,
                message,
                None,
                SkillState::Broken,
                false,
            ),
        };

        Ok(SkillInstance {
            id: stable_path_id(path),
            agent: AgentId::Openclaw,
            scope: Scope::AgentProject,
            project_root: None,
            path: PathBuf::from(path),
            display_path: PathBuf::from(path),
            definition_id: name.clone(),
            name: name.clone(),
            display_name: name,
            description,
            version,
            state,
            enabled,
            frontmatter_raw,
            body,
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        })
    }

    fn is_enabled(&self, instance: &SkillInstance) -> bool {
        instance.enabled
    }

    fn config_paths(&self, _ctx: &AdapterContext) -> Vec<PathBuf> {
        Vec::new()
    }
}

struct ParsedSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
    version: Option<String>,
}

fn parse_skill_content(content: &str, fallback_name: &str) -> Result<ParsedSkill, String> {
    let rest = content
        .strip_prefix("---\n")
        .or_else(|| content.strip_prefix("---\r\n"))
        .ok_or_else(|| "missing YAML frontmatter".to_string())?;
    let (frontmatter_raw, body) = split_frontmatter(rest)?;
    let frontmatter: serde_yaml::Value =
        serde_yaml::from_str(frontmatter_raw).map_err(|err| err.to_string())?;
    let name = optional_string(&frontmatter, "name").unwrap_or_else(|| fallback_name.to_string());
    let description = optional_string(&frontmatter, "description").unwrap_or_default();
    let version = optional_string(&frontmatter, "version");

    Ok(ParsedSkill {
        frontmatter_raw: frontmatter_raw.to_string(),
        body,
        name,
        description,
        version,
    })
}

fn split_frontmatter(rest: &str) -> Result<(&str, String), String> {
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

fn optional_string(frontmatter: &serde_yaml::Value, key: &str) -> Option<String> {
    frontmatter
        .get(key)
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

fn openclaw_selected_workspace_root(ctx: &AdapterContext) -> Option<PathBuf> {
    let selected_paths = [ctx.project_root.as_ref(), ctx.project_cwd.as_ref()];
    openclaw_home_workspace_candidates(ctx)
        .into_iter()
        .find(|candidate| {
            selected_paths
                .iter()
                .flatten()
                .any(|selected| selected == &candidate || selected.starts_with(candidate))
        })
}

fn openclaw_home_workspace_candidates(ctx: &AdapterContext) -> [PathBuf; 2] {
    [
        ctx.user_home.join(".openclaw/workspace"),
        ctx.user_home.join("openclaw/workspace"),
    ]
}

fn openclaw_bundled_skill_roots() -> Vec<AdapterRoot> {
    [
        "/usr/lib/node_modules/openclaw/skills",
        "/usr/local/lib/node_modules/openclaw/skills",
        "/opt/jvs-claw/base/lib/node_modules/openclaw/skills",
    ]
    .into_iter()
    .map(|path| AdapterRoot {
        scope: Scope::AgentGlobal,
        path: PathBuf::from(path),
        source: RootSource::Extra,
    })
    .collect()
}

fn containing_dir_name(path: &Path) -> String {
    path.parent()
        .and_then(Path::file_name)
        .and_then(|name| name.to_str())
        .unwrap_or("unknown")
        .to_string()
}

fn stable_path_id(path: &Path) -> String {
    format!("openclaw:{}", path.display())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_documented_read_only_roots_without_generic_project_roots() {
        let adapter = OpenclawAdapter;
        let ctx = AdapterContext {
            user_home: PathBuf::from("/tmp/home"),
            project_root: Some(PathBuf::from("/tmp/project")),
            project_cwd: Some(PathBuf::from("/tmp/project/nested")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: PathBuf::from("/tmp/unverified"),
                source: RootSource::Extra,
            }],
        };

        let roots = adapter.roots(&ctx);

        assert_eq!(roots[0].path, PathBuf::from("/tmp/home/.openclaw/skills"));
        assert_eq!(roots[0].scope, Scope::AgentGlobal);
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(roots[1].path, PathBuf::from("/tmp/home/.agents/skills"));
        assert_eq!(roots[1].scope, Scope::AgentGlobal);
        assert_eq!(roots[1].source, RootSource::UserHome);
        assert!(
            roots
                .iter()
                .all(|root| !root.path.starts_with("/tmp/project")),
            "OpenClaw must not infer arbitrary repository roots as project workspaces"
        );
        assert!(
            roots
                .iter()
                .all(|root| !root.path.starts_with("/tmp/unverified")),
            "OpenClaw must not consume generic extra roots as configured extraDirs"
        );
    }

    #[test]
    fn exposes_home_openclaw_workspace_roots_when_project_is_workspace() {
        let adapter = OpenclawAdapter;
        let ctx = AdapterContext {
            user_home: PathBuf::from("/tmp/home"),
            project_root: Some(PathBuf::from("/tmp/home/.openclaw/workspace")),
            project_cwd: None,
            extra_roots: vec![],
        };

        let roots = adapter.roots(&ctx);

        assert!(roots.iter().any(|root| {
            root.scope == Scope::AgentProject
                && root.source == RootSource::Project
                && root.path == Path::new("/tmp/home/.openclaw/workspace/skills")
        }));
        assert!(roots.iter().any(|root| {
            root.scope == Scope::AgentProject
                && root.source == RootSource::Project
                && root.path == Path::new("/tmp/home/.openclaw/workspace/.agents/skills")
        }));
    }

    #[test]
    fn exposes_home_openclaw_workspace_roots_when_selection_is_inside_workspace() {
        let adapter = OpenclawAdapter;
        let ctx = AdapterContext {
            user_home: PathBuf::from("/tmp/home"),
            project_root: Some(PathBuf::from("/tmp/home/.openclaw/workspace/repo")),
            project_cwd: Some(PathBuf::from("/tmp/home/.openclaw/workspace/repo/nested")),
            extra_roots: vec![],
        };

        let roots = adapter.roots(&ctx);

        assert!(roots.iter().any(|root| {
            root.scope == Scope::AgentProject
                && root.source == RootSource::Project
                && root.path == Path::new("/tmp/home/.openclaw/workspace/skills")
        }));
        assert!(roots.iter().any(|root| {
            root.scope == Scope::AgentProject
                && root.source == RootSource::Project
                && root.path == Path::new("/tmp/home/.openclaw/workspace/.agents/skills")
        }));
        assert!(
            roots
                .iter()
                .all(|root| !root.path.starts_with("/tmp/home/.openclaw/workspace/repo")),
            "OpenClaw must scan the confirmed workspace roots, not infer nested repo roots"
        );
    }

    #[test]
    fn parses_valid_openclaw_skill_frontmatter() {
        let adapter = OpenclawAdapter;
        let fixture =
            fixture_path("fixtures/openclaw/skill-evidence/sample-openclaw-skill/SKILL.md");

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.agent, AgentId::Openclaw);
        assert_eq!(skill.name, "sample-openclaw-skill");
        assert_eq!(
            skill.description,
            "Evidence sample only for an OpenClaw skill directory containing SKILL.md."
        );
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
    }

    #[test]
    fn falls_back_to_directory_name_when_name_is_missing() {
        let adapter = OpenclawAdapter;
        let fixture = fixture_path("fixtures/openclaw/broken/missing-name/SKILL.md");

        let skill = adapter.parse(&fixture).expect("skill parses with fallback");

        assert_eq!(skill.name, "missing-name");
        assert_eq!(skill.description, "Missing name fallback fixture.");
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
    }

    #[test]
    fn keeps_missing_description_loaded_with_empty_description() {
        let adapter = OpenclawAdapter;
        let fixture = fixture_path("fixtures/openclaw/broken/missing-description/SKILL.md");

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.name, "missing-description");
        assert_eq!(skill.description, "");
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
