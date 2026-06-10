use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentConfigAdapter,
    AgentConfigDocument, AgentId, PermissionRequest, RootSource, Scope, SkillInstance, SkillState,
};

#[derive(Debug, Default)]
pub struct PiAdapter;

impl AgentAdapter for PiAdapter {
    fn id(&self) -> AgentId {
        AgentId::Pi
    }

    fn display_name(&self) -> &'static str {
        "Pi"
    }

    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot> {
        let mut roots = vec![AdapterRoot {
            scope: Scope::AgentGlobal,
            path: ctx.user_home.join(".pi/agent/skills"),
            source: RootSource::UserHome,
        }];

        if let Some(project_root) = &ctx.project_root {
            roots.extend(pi_project_skill_roots(
                project_root,
                ctx.project_cwd.as_deref(),
            ));
        }

        roots
    }

    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError> {
        let content = std::fs::read_to_string(path)
            .map_err(|err| AdapterError::new(format!("failed to read skill: {err}")))?;
        let fallback_name = fallback_skill_name(path);
        let parsed = parse_skill_content(&content);
        let (frontmatter_raw, body, name, description, state, enabled) = match parsed {
            Ok(parsed) => (
                parsed.frontmatter_raw,
                parsed.body,
                parsed.name.clone(),
                parsed.description,
                SkillState::Loaded,
                true,
            ),
            Err(message) => (
                String::new(),
                content,
                fallback_name.clone(),
                message,
                SkillState::Broken,
                false,
            ),
        };

        Ok(SkillInstance {
            id: stable_path_id(path),
            agent: AgentId::Pi,
            scope: Scope::AgentProject,
            project_root: None,
            path: PathBuf::from(path),
            display_path: PathBuf::from(path),
            definition_id: name.clone(),
            name: name.clone(),
            display_name: name,
            description,
            version: None,
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

    fn config_paths(&self, ctx: &AdapterContext) -> Vec<PathBuf> {
        let mut paths = vec![ctx.user_home.join(".pi/settings.json")];
        if let Some(project_root) = &ctx.project_root {
            paths.push(project_root.join(".pi/settings.json"));
        }
        paths
    }
}

impl AgentConfigAdapter for PiAdapter {
    fn patch_enabled(
        &self,
        doc: &mut AgentConfigDocument,
        instance: &SkillInstance,
        on: bool,
    ) -> Result<(), AdapterError> {
        doc.text = patch_pi_config(&doc.text, &instance.name, on, instance.scope)?;
        Ok(())
    }
}

struct ParsedSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
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
    validate_skill_name(&name)?;
    let description = required_string(&frontmatter, "description")?;

    Ok(ParsedSkill {
        frontmatter_raw: frontmatter_raw.to_string(),
        body,
        name,
        description,
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
    let value = frontmatter
        .get(key)
        .and_then(serde_yaml::Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| format!("missing required Pi frontmatter field `{key}`"))?;
    Ok(value.to_string())
}

fn validate_skill_name(name: &str) -> Result<(), String> {
    if name.is_empty() || name.len() > 64 {
        return Err(format!(
            "invalid Pi skill name `{name}`: must be 1-64 characters"
        ));
    }
    if name.starts_with('-') || name.ends_with('-') || name.contains("--") {
        return Err(format!(
            "invalid Pi skill name `{name}`: use single hyphen separators with no leading or trailing hyphen"
        ));
    }
    if !name
        .bytes()
        .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
    {
        return Err(format!(
            "invalid Pi skill name `{name}`: use lowercase alphanumeric characters and hyphens only"
        ));
    }
    Ok(())
}

fn pi_project_skill_roots(project_root: &Path, project_cwd: Option<&Path>) -> Vec<AdapterRoot> {
    let start = project_cwd
        .filter(|cwd| cwd.starts_with(project_root))
        .unwrap_or(project_root);
    let mut roots = Vec::new();
    let mut current = Some(start);

    while let Some(dir) = current {
        roots.push(AdapterRoot {
            scope: Scope::AgentProject,
            path: dir.join(".pi/skills"),
            source: RootSource::Project,
        });
        if dir == project_root {
            break;
        }
        current = dir
            .parent()
            .filter(|parent| parent.starts_with(project_root));
    }

    roots
}

fn fallback_skill_name(path: &Path) -> String {
    if path.file_name().and_then(|name| name.to_str()) == Some("SKILL.md") {
        return path
            .parent()
            .and_then(Path::file_name)
            .and_then(|name| name.to_str())
            .unwrap_or("unknown")
            .to_string();
    }
    path.file_stem()
        .and_then(|name| name.to_str())
        .unwrap_or("unknown")
        .to_string()
}

fn stable_path_id(path: &Path) -> String {
    format!("pi:{}", path.display())
}

fn patch_pi_config(
    content: &str,
    skill_name: &str,
    enabled: bool,
    scope: Scope,
) -> Result<String, AdapterError> {
    let mut value = if content.trim().is_empty() {
        serde_json::json!({
            "project": {
                "trusted": scope == Scope::AgentGlobal
            },
            "skills": {
                "disabled": []
            }
        })
    } else {
        serde_json::from_str(content)
            .map_err(|err| AdapterError::new(format!("invalid Pi settings JSON: {err}")))?
    };

    if scope == Scope::AgentProject && !pi_project_trusted(&value) {
        return Err(AdapterError::new(
            "Pi project settings must explicitly set project.trusted or trust.projectRootTrusted before project/package toggles are allowed",
        ));
    }

    let disabled = pi_disabled_array_mut(&mut value)?;
    if enabled {
        disabled.retain(|value| value.as_str() != Some(skill_name));
    } else if !disabled
        .iter()
        .any(|value| value.as_str() == Some(skill_name))
    {
        disabled.push(serde_json::Value::String(skill_name.to_string()));
    }

    let mut text = serde_json::to_string_pretty(&value)
        .map_err(|err| AdapterError::new(format!("failed to serialize Pi settings: {err}")))?;
    text.push('\n');
    Ok(text)
}

fn pi_project_trusted(value: &serde_json::Value) -> bool {
    value
        .get("project")
        .and_then(|project| project.get("trusted"))
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        || value
            .get("trust")
            .and_then(|trust| trust.get("projectRootTrusted"))
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
}

fn pi_disabled_array_mut(
    value: &mut serde_json::Value,
) -> Result<&mut Vec<serde_json::Value>, AdapterError> {
    let object = value
        .as_object_mut()
        .ok_or_else(|| AdapterError::new("Pi settings must be a JSON object"))?;
    if object.contains_key("disabledSkills") {
        return object
            .get_mut("disabledSkills")
            .and_then(serde_json::Value::as_array_mut)
            .ok_or_else(|| AdapterError::new("Pi disabledSkills must be an array"));
    }
    let skills = object
        .entry("skills")
        .or_insert_with(|| serde_json::json!({}));
    let skills_obj = skills
        .as_object_mut()
        .ok_or_else(|| AdapterError::new("Pi skills settings must be a JSON object"))?;
    let disabled = skills_obj
        .entry("disabled")
        .or_insert_with(|| serde_json::json!([]));
    disabled
        .as_array_mut()
        .ok_or_else(|| AdapterError::new("Pi skills.disabled must be an array"))
}

pub fn pi_disabled_skill_names(content: &str) -> Result<Vec<String>, AdapterError> {
    let value: serde_json::Value = serde_json::from_str(content)
        .map_err(|err| AdapterError::new(format!("invalid Pi settings JSON: {err}")))?;
    let disabled = value
        .get("disabledSkills")
        .and_then(serde_json::Value::as_array)
        .or_else(|| {
            value
                .get("skills")
                .and_then(|skills| skills.get("disabled"))
                .and_then(serde_json::Value::as_array)
        });
    Ok(disabled
        .into_iter()
        .flatten()
        .filter_map(serde_json::Value::as_str)
        .map(str::to_string)
        .collect())
}

#[cfg(test)]
mod tests {
    use skills_copilot_core::{AdapterRoot, RootSource};

    use super::*;

    #[test]
    fn exposes_native_user_and_project_roots_only() {
        let adapter = PiAdapter;
        let ctx = AdapterContext {
            user_home: PathBuf::from("/tmp/home"),
            project_root: Some(PathBuf::from("/tmp/project")),
            project_cwd: Some(PathBuf::from("/tmp/project/nested/deeper")),
            extra_roots: vec![AdapterRoot {
                scope: Scope::AgentGlobal,
                path: PathBuf::from("/tmp/unverified"),
                source: RootSource::Extra,
            }],
        };

        let roots = adapter.roots(&ctx);

        assert_eq!(roots[0].path, PathBuf::from("/tmp/home/.pi/agent/skills"));
        assert_eq!(
            roots[1].path,
            PathBuf::from("/tmp/project/nested/deeper/.pi/skills")
        );
        assert_eq!(
            roots[2].path,
            PathBuf::from("/tmp/project/nested/.pi/skills")
        );
        assert_eq!(roots[3].path, PathBuf::from("/tmp/project/.pi/skills"));
        assert_eq!(roots.len(), 4);
    }

    #[test]
    fn parses_valid_directory_skill_frontmatter() {
        let adapter = PiAdapter;
        let fixture = fixture_path("fixtures/pi/global/agent/skills/global-pdf/SKILL.md");

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.agent, AgentId::Pi);
        assert_eq!(skill.name, "global-pdf");
        assert_eq!(
            skill.description,
            "Extracts and reviews PDF text during Pi sessions. Use when a workflow needs PDF inspection steps."
        );
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
    }

    #[test]
    fn marks_missing_description_as_broken() {
        let adapter = PiAdapter;
        let fixture = fixture_path("fixtures/pi/broken/missing-description/SKILL.md");

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "missing-description");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill.description.contains("description"));
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
