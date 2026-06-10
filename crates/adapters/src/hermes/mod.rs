use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentId, PermissionRequest,
    RootSource, Scope, SkillInstance, SkillState,
};

#[derive(Debug, Default)]
pub struct HermesAdapter;

impl AgentAdapter for HermesAdapter {
    fn id(&self) -> AgentId {
        AgentId::Hermes
    }

    fn display_name(&self) -> &'static str {
        "Hermes"
    }

    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot> {
        let hermes_home = hermes_home(ctx);
        let mut roots = vec![AdapterRoot {
            scope: Scope::AgentGlobal,
            path: hermes_home.join("skills"),
            source: RootSource::UserHome,
        }];
        roots.extend(hermes_external_skill_roots(&hermes_home, &ctx.user_home));
        roots
    }

    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError> {
        let content = std::fs::read_to_string(path)
            .map_err(|err| AdapterError::new(format!("failed to read skill: {err}")))?;
        let fallback_name = containing_dir_name(path);
        let parsed = parse_skill_content(&content);
        let (frontmatter_raw, body, name, description, version, state, enabled) = match parsed {
            Ok(parsed) => (
                parsed.frontmatter_raw,
                parsed.body,
                parsed.name.clone(),
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
            agent: AgentId::Hermes,
            scope: Scope::AgentGlobal,
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

fn hermes_home(ctx: &AdapterContext) -> PathBuf {
    ctx.user_home.join(".hermes")
}

fn hermes_external_skill_roots(hermes_home: &Path, user_home: &Path) -> Vec<AdapterRoot> {
    let config_path = hermes_home.join("config.yaml");
    let Ok(config_text) = std::fs::read_to_string(&config_path) else {
        return Vec::new();
    };
    let config_dir = config_path.parent().unwrap_or(hermes_home);
    parse_external_dirs(&config_text, config_dir, user_home)
        .into_iter()
        .map(|path| AdapterRoot {
            scope: Scope::AgentGlobal,
            path,
            source: RootSource::Extra,
        })
        .collect()
}

fn parse_external_dirs(config_text: &str, config_dir: &Path, user_home: &Path) -> Vec<PathBuf> {
    let Ok(config) = serde_yaml::from_str::<serde_yaml::Value>(config_text) else {
        return Vec::new();
    };
    let Some(external_dirs) = config
        .get("skills")
        .and_then(|skills| skills.get("external_dirs"))
        .and_then(serde_yaml::Value::as_sequence)
    else {
        return Vec::new();
    };

    let mut dirs = Vec::new();
    for entry in external_dirs {
        let Some(raw_dir) = entry.as_str() else {
            continue;
        };
        let Some(path) = external_dir_path(raw_dir, config_dir, user_home) else {
            continue;
        };
        if !dirs.contains(&path) {
            dirs.push(path);
        }
    }
    dirs
}

fn external_dir_path(raw_dir: &str, config_dir: &Path, user_home: &Path) -> Option<PathBuf> {
    let raw_dir = raw_dir.trim();
    if raw_dir.is_empty() {
        return None;
    }

    let path = if raw_dir == "~" {
        user_home.to_path_buf()
    } else if let Some(stripped) = raw_dir.strip_prefix("~/") {
        user_home.join(stripped)
    } else {
        let path = PathBuf::from(raw_dir);
        if path.is_absolute() {
            path
        } else {
            config_dir.join(path)
        }
    };

    Some(normalize_path_lexically(&path))
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

struct ParsedSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
    version: Option<String>,
}

fn parse_skill_content(content: &str) -> Result<ParsedSkill, String> {
    let rest = content
        .strip_prefix("---\n")
        .or_else(|| content.strip_prefix("---\r\n"))
        .ok_or_else(|| "missing YAML frontmatter".to_string())?;
    let (frontmatter_raw, body) = split_frontmatter(rest)?;
    let frontmatter: serde_yaml::Value =
        serde_yaml::from_str(frontmatter_raw).map_err(|err| err.to_string())?;
    let name = required_string(&frontmatter, "name")?;
    let description = required_string(&frontmatter, "description")?;
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

fn required_string(frontmatter: &serde_yaml::Value, key: &str) -> Result<String, String> {
    optional_string(frontmatter, key)
        .ok_or_else(|| format!("missing required Hermes frontmatter field `{key}`"))
}

fn optional_string(frontmatter: &serde_yaml::Value, key: &str) -> Option<String> {
    frontmatter
        .get(key)
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

fn containing_dir_name(path: &Path) -> String {
    path.parent()
        .and_then(Path::file_name)
        .and_then(|name| name.to_str())
        .unwrap_or("unknown")
        .to_string()
}

fn stable_path_id(path: &Path) -> String {
    format!("hermes:{}", path.display())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_active_hermes_home_without_inferred_project_or_extra_roots() {
        let adapter = HermesAdapter;
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

        assert_eq!(roots.len(), 1);
        assert_eq!(roots[0].scope, Scope::AgentGlobal);
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(roots[0].path, PathBuf::from("/tmp/home/.hermes/skills"));
    }

    #[test]
    fn exposes_explicit_external_dirs_from_hermes_config_as_read_only_extra_roots() {
        let temp_root = std::env::temp_dir().join(format!(
            "skills-copilot-hermes-external-roots-{}",
            std::process::id()
        ));
        let home = temp_root.join("home");
        let external_one = temp_root.join("external-one");
        std::fs::create_dir_all(home.join(".hermes")).expect("create Hermes home");
        std::fs::write(
            home.join(".hermes/config.yaml"),
            format!(
                "skills:\n  external_dirs:\n    - {}\n    - ~/shared-hermes\n    - ../relative-external\n    - {}\n    - 42\n",
                external_one.display(),
                external_one.display()
            ),
        )
        .expect("write Hermes config");
        let adapter = HermesAdapter;
        let ctx = AdapterContext {
            user_home: home.clone(),
            project_root: Some(temp_root.join("project")),
            project_cwd: Some(temp_root.join("project/nested")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: temp_root.join("unverified"),
                source: RootSource::Extra,
            }],
        };

        let roots = adapter.roots(&ctx);

        assert_eq!(roots.len(), 4);
        assert_eq!(roots[0].path, home.join(".hermes/skills"));
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(roots[1].path, external_one);
        assert_eq!(roots[1].scope, Scope::AgentGlobal);
        assert_eq!(roots[1].source, RootSource::Extra);
        assert_eq!(roots[2].path, home.join("shared-hermes"));
        assert_eq!(roots[2].source, RootSource::Extra);
        assert_eq!(roots[3].path, home.join("relative-external"));
        assert_eq!(roots[3].source, RootSource::Extra);
        assert!(
            roots
                .iter()
                .all(|root| root.path != temp_root.join("project")),
            "Hermes must not infer generic project roots"
        );
        assert!(
            roots
                .iter()
                .all(|root| root.path != temp_root.join("unverified")),
            "Hermes must not consume AdapterContext extra_roots as external_dirs"
        );

        let _ = std::fs::remove_dir_all(&temp_root);
    }

    #[test]
    fn parses_nested_hermes_skill_frontmatter() {
        let adapter = HermesAdapter;
        let fixture = fixture_path(
            "fixtures/hermes/active-home/.hermes/skills/nested/research-brief/SKILL.md",
        );

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.agent, AgentId::Hermes);
        assert_eq!(skill.scope, Scope::AgentGlobal);
        assert_eq!(skill.name, "research-brief");
        assert_eq!(
            skill.description,
            "Prepare read-only research summaries for Hermes sessions."
        );
        assert_eq!(skill.version.as_deref(), Some("0.1.0"));
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
    }

    #[test]
    fn marks_malformed_frontmatter_as_broken_without_failing_parse() {
        let adapter = HermesAdapter;
        let fixture = fixture_path(
            "fixtures/hermes/active-home/.hermes/skills/broken/malformed-metadata/SKILL.md",
        );

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.agent, AgentId::Hermes);
        assert_eq!(skill.name, "malformed-metadata");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
