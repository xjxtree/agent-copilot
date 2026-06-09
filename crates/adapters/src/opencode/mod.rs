use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentId, PermissionRequest,
    RootSource, Scope, SkillInstance, SkillState,
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
        let mut roots = vec![AdapterRoot {
            scope: Scope::AgentGlobal,
            path: ctx.user_home.join(".config/opencode/skills"),
            source: RootSource::UserHome,
        }];

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
        Vec::new()
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

#[cfg(test)]
mod tests {
    use skills_copilot_core::{AdapterRoot, RootSource, SkillState};

    use super::*;

    #[test]
    fn exposes_native_user_and_project_roots_only() {
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

        assert_eq!(roots.len(), 4);
        assert_eq!(
            roots[0].path,
            PathBuf::from("/tmp/home/.config/opencode/skills")
        );
        assert_eq!(roots[0].scope, Scope::AgentGlobal);
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(
            roots[1].path,
            PathBuf::from("/tmp/project/nested/deeper/.opencode/skills")
        );
        assert_eq!(
            roots[2].path,
            PathBuf::from("/tmp/project/nested/.opencode/skills")
        );
        assert_eq!(
            roots[3].path,
            PathBuf::from("/tmp/project/.opencode/skills")
        );
        for root in &roots[1..] {
            assert_eq!(root.scope, Scope::AgentProject);
            assert_eq!(root.source, RootSource::Project);
        }
        assert!(
            roots
                .iter()
                .all(|root| !root.path.starts_with("/tmp/unverified")),
            "opencode V2.4 does not scan extra compatibility roots"
        );
        assert!(
            roots
                .iter()
                .all(|root| !root.path.ends_with(".agents/skills")),
            "opencode V2.4 does not scan .agents compatibility roots"
        );
        assert!(
            roots
                .iter()
                .all(|root| !root.path.ends_with(".claude/skills")),
            "opencode V2.4 does not scan .claude compatibility roots"
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
}
