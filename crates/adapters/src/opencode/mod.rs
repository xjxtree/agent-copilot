use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentConfigAdapter,
    AgentConfigDocument, AgentId, PermissionRequest, RootSource, Scope, SkillInstance, SkillState,
};

#[derive(Debug, Default)]
pub struct OpencodeAdapter;

impl AgentAdapter for OpencodeAdapter {
    fn id(&self) -> AgentId {
        AgentId::Opencode
    }

    fn display_name(&self) -> &'static str {
        "opencode"
    }

    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot> {
        let mut roots = vec![
            AdapterRoot {
                scope: Scope::AgentGlobal,
                path: ctx.user_home.join(".config/opencode/skills"),
                source: RootSource::UserHome,
            },
            AdapterRoot {
                scope: Scope::AgentGlobal,
                path: ctx.user_home.join(".claude/skills"),
                source: RootSource::UserHome,
            },
            AdapterRoot {
                scope: Scope::AgentGlobal,
                path: ctx.user_home.join(".agents/skills"),
                source: RootSource::UserHome,
            },
        ];

        if let Some(project_root) = &ctx.project_root {
            roots.extend(opencode_project_skill_roots(
                project_root,
                ctx.project_cwd.as_deref(),
            ));
        }

        roots
    }

    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError> {
        let content = std::fs::read_to_string(path)
            .map_err(|err| AdapterError::new(format!("failed to read skill: {err}")))?;
        let fallback_name = containing_dir_name(path);
        let parsed = parse_skill_content(&content, &fallback_name);
        let (frontmatter_raw, body, name, description, state, enabled) = match parsed {
            Ok(parsed) => (
                parsed.frontmatter_raw,
                parsed.body,
                parsed.name,
                parsed.description,
                SkillState::Loaded,
                true,
            ),
            Err(message) => (
                String::new(),
                content,
                fallback_name,
                message,
                SkillState::Broken,
                false,
            ),
        };

        Ok(SkillInstance {
            id: stable_path_id(path),
            agent: AgentId::Opencode,
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

    fn config_paths(&self, _ctx: &AdapterContext) -> Vec<PathBuf> {
        vec![_ctx.user_home.join(".config/opencode/opencode.json")]
    }
}

impl AgentConfigAdapter for OpencodeAdapter {
    fn patch_enabled(
        &self,
        doc: &mut AgentConfigDocument,
        instance: &SkillInstance,
        on: bool,
    ) -> Result<(), AdapterError> {
        doc.text = patch_opencode_config(&doc.text, &instance.name, on)?;
        Ok(())
    }
}

struct ParsedSkill {
    frontmatter_raw: String,
    body: String,
    name: String,
    description: String,
}

fn parse_skill_content(content: &str, directory_name: &str) -> Result<ParsedSkill, String> {
    let rest = content
        .strip_prefix("---\n")
        .or_else(|| content.strip_prefix("---\r\n"))
        .ok_or_else(|| "missing YAML frontmatter".to_string())?;
    let (frontmatter_raw, body) = split_frontmatter(rest)?;
    let frontmatter: serde_yaml::Value =
        serde_yaml::from_str(frontmatter_raw).map_err(|err| err.to_string())?;
    let name = required_string(&frontmatter, "name")?;
    validate_skill_name(&name)?;
    if name != directory_name {
        return Err(format!(
            "opencode skill name `{name}` must match containing directory `{directory_name}`"
        ));
    }
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
        .ok_or_else(|| format!("missing required opencode frontmatter field `{key}`"))?;
    Ok(value.to_string())
}

fn validate_skill_name(name: &str) -> Result<(), String> {
    if name.is_empty() || name.len() > 64 {
        return Err(format!(
            "invalid opencode skill name `{name}`: must be 1-64 characters"
        ));
    }
    if name.starts_with('-') || name.ends_with('-') || name.contains("--") {
        return Err(format!(
            "invalid opencode skill name `{name}`: use single hyphen separators with no leading or trailing hyphen"
        ));
    }
    if !name
        .bytes()
        .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-')
    {
        return Err(format!(
            "invalid opencode skill name `{name}`: use lowercase alphanumeric characters and hyphens only"
        ));
    }
    Ok(())
}

fn opencode_project_skill_roots(
    project_root: &Path,
    project_cwd: Option<&Path>,
) -> Vec<AdapterRoot> {
    let start = project_cwd
        .filter(|cwd| cwd.starts_with(project_root))
        .unwrap_or(project_root);
    let mut roots = Vec::new();
    let mut current = Some(start);

    while let Some(dir) = current {
        roots.push(AdapterRoot {
            scope: Scope::AgentProject,
            path: dir.join(".opencode/skills"),
            source: RootSource::Project,
        });
        roots.push(AdapterRoot {
            scope: Scope::AgentProject,
            path: dir.join(".claude/skills"),
            source: RootSource::Project,
        });
        roots.push(AdapterRoot {
            scope: Scope::AgentProject,
            path: dir.join(".agents/skills"),
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

fn containing_dir_name(path: &Path) -> String {
    path.parent()
        .and_then(Path::file_name)
        .and_then(|name| name.to_str())
        .unwrap_or("unknown")
        .to_string()
}

fn stable_path_id(path: &Path) -> String {
    format!("opencode:{}", path.display())
}

fn patch_opencode_config(
    content: &str,
    skill_name: &str,
    on: bool,
) -> Result<String, AdapterError> {
    validate_skill_name(skill_name).map_err(AdapterError::new)?;
    let mut value = parse_opencode_config(content)?;
    let root = object_mut(&mut value, "opencode config root")?;
    let permission = root
        .entry("permission".to_string())
        .or_insert_with(|| serde_json::Value::Object(serde_json::Map::new()));

    if let Some(existing) = permission.as_str().map(str::to_string) {
        *permission = serde_json::json!({ "*": existing });
    }
    let permission = object_mut(permission, "`permission` config")?;
    let skill = permission
        .entry("skill".to_string())
        .or_insert_with(|| serde_json::Value::Object(serde_json::Map::new()));

    if let Some(existing) = skill.as_str().map(str::to_string) {
        *skill = serde_json::json!({ "*": existing });
    }
    let skill = object_mut(skill, "`permission.skill` config")?;

    if on {
        if skill
            .get(skill_name)
            .and_then(serde_json::Value::as_str)
            .is_some_and(|rule| rule == "deny")
        {
            skill.remove(skill_name);
        }
    } else {
        skill.insert(
            skill_name.to_string(),
            serde_json::Value::String("deny".to_string()),
        );
    }

    Ok(format!(
        "{}\n",
        serde_json::to_string_pretty(&value).map_err(|err| {
            AdapterError::new(format!("failed to serialize opencode config: {err}"))
        })?
    ))
}

fn parse_opencode_config(content: &str) -> Result<serde_json::Value, AdapterError> {
    let trimmed = content.trim();
    if trimmed.is_empty() {
        return Ok(serde_json::Value::Object(serde_json::Map::new()));
    }
    serde_json::from_str(trimmed).map_err(|err| {
        AdapterError::new(format!(
            "failed to parse opencode JSON config for writable patch: {err}; JSONC/commented configs are not rewritten because comments cannot be preserved"
        ))
    })
}

fn object_mut<'a>(
    value: &'a mut serde_json::Value,
    label: &str,
) -> Result<&'a mut serde_json::Map<String, serde_json::Value>, AdapterError> {
    value
        .as_object_mut()
        .ok_or_else(|| AdapterError::new(format!("{label} must be a JSON object")))
}

#[cfg(test)]
mod tests {
    use skills_copilot_core::{AdapterRoot, RootSource, SkillState};

    use super::*;

    #[test]
    fn exposes_documented_native_and_compatibility_roots() {
        let adapter = OpencodeAdapter;
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

        assert_eq!(roots.len(), 12);
        assert_eq!(
            roots[0].path,
            PathBuf::from("/tmp/home/.config/opencode/skills")
        );
        assert_eq!(roots[1].path, PathBuf::from("/tmp/home/.claude/skills"));
        assert_eq!(roots[2].path, PathBuf::from("/tmp/home/.agents/skills"));
        assert_eq!(roots[0].scope, Scope::AgentGlobal);
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(
            roots[3].path,
            PathBuf::from("/tmp/project/nested/deeper/.opencode/skills")
        );
        assert_eq!(
            roots[4].path,
            PathBuf::from("/tmp/project/nested/deeper/.claude/skills")
        );
        assert_eq!(
            roots[5].path,
            PathBuf::from("/tmp/project/nested/deeper/.agents/skills")
        );
        assert_eq!(
            roots[6].path,
            PathBuf::from("/tmp/project/nested/.opencode/skills")
        );
        assert_eq!(
            roots[7].path,
            PathBuf::from("/tmp/project/nested/.claude/skills")
        );
        assert_eq!(
            roots[8].path,
            PathBuf::from("/tmp/project/nested/.agents/skills")
        );
        assert_eq!(
            roots[9].path,
            PathBuf::from("/tmp/project/.opencode/skills")
        );
        assert_eq!(roots[10].path, PathBuf::from("/tmp/project/.claude/skills"));
        assert_eq!(roots[11].path, PathBuf::from("/tmp/project/.agents/skills"));
        for root in &roots[3..] {
            assert_eq!(root.scope, Scope::AgentProject);
            assert_eq!(root.source, RootSource::Project);
        }
        assert!(
            roots
                .iter()
                .all(|root| !root.path.starts_with("/tmp/unverified")),
            "opencode must not scan unverified extra roots"
        );
    }

    #[test]
    fn parses_valid_skill_frontmatter() {
        let adapter = OpencodeAdapter;
        let fixture = fixture_path(
            "fixtures/opencode/user-home/.config/opencode/skills/global-review/SKILL.md",
        );

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.agent, AgentId::Opencode);
        assert_eq!(skill.name, "global-review");
        assert_eq!(
            skill.description,
            "Reviews repository changes for maintainability and risk. Use when preparing an opencode review workflow."
        );
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
        assert!(skill.permissions.tools.is_empty());
        assert!(skill.frontmatter_raw.contains("name: global-review"));
        assert!(skill.body.contains("# Global Review"));
    }

    #[test]
    fn marks_name_mismatch_as_broken() {
        let adapter = OpencodeAdapter;
        let fixture = fixture_path("fixtures/opencode/broken/name-mismatch/SKILL.md");

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "name-mismatch");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill
            .description
            .contains("must match containing directory"));
    }

    #[test]
    fn marks_missing_required_fields_as_broken() {
        let adapter = OpencodeAdapter;
        let fixture = write_skill(
            "missing-description",
            "---\nname: missing-description\n---\nBody.\n",
        );

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "missing-description");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill.description.contains("description"));
    }

    #[test]
    fn marks_invalid_name_as_broken() {
        let adapter = OpencodeAdapter;
        let fixture = write_skill(
            "bad--name",
            "---\nname: bad--name\ndescription: Invalid name fixture.\n---\nBody.\n",
        );

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "bad--name");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill.description.contains("single hyphen separators"));
    }

    #[test]
    fn patch_enabled_adds_exact_skill_deny_and_preserves_wildcard() {
        let mut doc = AgentConfigDocument {
            path: PathBuf::from("/tmp/opencode.json"),
            format: skills_copilot_core::ConfigFormat::Json,
            text: r#"{"permission":{"skill":{"*":"allow","internal-*":"deny"}}}"#.to_string(),
        };
        let skill = minimal_skill("global-review");

        OpencodeAdapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch");

        let value: serde_json::Value = serde_json::from_str(&doc.text).expect("patched json");
        assert_eq!(value["permission"]["skill"]["*"], "allow");
        assert_eq!(value["permission"]["skill"]["internal-*"], "deny");
        assert_eq!(value["permission"]["skill"]["global-review"], "deny");
    }

    #[test]
    fn patch_enabled_removes_only_exact_deny() {
        let mut doc = AgentConfigDocument {
            path: PathBuf::from("/tmp/opencode.json"),
            format: skills_copilot_core::ConfigFormat::Json,
            text: r#"{"permission":{"skill":{"*":"ask","global-review":"deny","other":"ask"}}}"#
                .to_string(),
        };
        let skill = minimal_skill("global-review");

        OpencodeAdapter
            .patch_enabled(&mut doc, &skill, true)
            .expect("enable patch");

        let value: serde_json::Value = serde_json::from_str(&doc.text).expect("patched json");
        assert!(value["permission"]["skill"].get("global-review").is_none());
        assert_eq!(value["permission"]["skill"]["*"], "ask");
        assert_eq!(value["permission"]["skill"]["other"], "ask");
    }

    #[test]
    fn patch_enabled_accepts_string_permission_defaults() {
        let mut doc = AgentConfigDocument {
            path: PathBuf::from("/tmp/opencode.json"),
            format: skills_copilot_core::ConfigFormat::Json,
            text: r#"{"permission":"ask"}"#.to_string(),
        };
        let skill = minimal_skill("global-review");

        OpencodeAdapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch");

        let value: serde_json::Value = serde_json::from_str(&doc.text).expect("patched json");
        assert_eq!(value["permission"]["*"], "ask");
        assert_eq!(value["permission"]["skill"]["global-review"], "deny");
    }

    #[test]
    fn patch_enabled_rejects_commented_jsonc_without_rewriting() {
        let original = r#"{
                // OpenCode accepts JSONC, but the managed write should not drop comments.
                "permission": "ask"
            }"#;
        let mut doc = AgentConfigDocument {
            path: PathBuf::from("/tmp/opencode.json"),
            format: skills_copilot_core::ConfigFormat::Json,
            text: original.to_string(),
        };
        let skill = minimal_skill("global-review");

        let err = OpencodeAdapter
            .patch_enabled(&mut doc, &skill, false)
            .expect_err("commented JSONC should not be rewritten");

        assert!(err
            .message
            .contains("JSONC/commented configs are not rewritten"));
        assert_eq!(doc.text, original);
    }

    fn write_skill(name: &str, content: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!(
            "skills-copilot-opencode-adapter-{}-{}",
            std::process::id(),
            name
        ));
        let skill_dir = root.join(name);
        std::fs::create_dir_all(&skill_dir).expect("create skill dir");
        let skill_path = skill_dir.join("SKILL.md");
        std::fs::write(&skill_path, content).expect("write skill");
        skill_path
            .canonicalize()
            .expect("canonicalize temp skill path")
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }

    fn minimal_skill(name: &str) -> SkillInstance {
        SkillInstance {
            id: name.to_string(),
            agent: AgentId::Opencode,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: PathBuf::from(format!("/tmp/{name}/SKILL.md")),
            display_path: PathBuf::from(format!("/tmp/{name}/SKILL.md")),
            definition_id: name.to_string(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: String::new(),
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
}
