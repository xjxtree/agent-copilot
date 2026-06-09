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
        vec![AdapterRoot {
            scope: Scope::AgentGlobal,
            path: ctx.user_home.join(".hermes/skills"),
            source: RootSource::UserHome,
        }]
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
    fn exposes_active_hermes_home_only() {
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
