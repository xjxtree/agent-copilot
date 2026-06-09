use std::path::{Path, PathBuf};

use skills_copilot_core::{
    AdapterContext, AdapterError, AdapterRoot, AgentAdapter, AgentConfigAdapter,
    AgentConfigDocument, AgentId, PermissionRequest, RootSource, Scope, SkillInstance, SkillState,
};

#[derive(Debug, Default)]
pub struct CodexAdapter;

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct CodexSkillConfigEntry {
    pub path: Option<String>,
    pub enabled: Option<bool>,
}

impl AgentAdapter for CodexAdapter {
    fn id(&self) -> AgentId {
        AgentId::Codex
    }

    fn display_name(&self) -> &'static str {
        "Codex"
    }

    fn roots(&self, ctx: &AdapterContext) -> Vec<AdapterRoot> {
        let mut roots = vec![AdapterRoot {
            scope: Scope::AgentGlobal,
            path: ctx.user_home.join(".agents/skills"),
            source: RootSource::UserHome,
        }];

        if let Some(project_root) = &ctx.project_root {
            roots.extend(codex_project_skill_roots(
                project_root,
                ctx.project_cwd.as_deref(),
            ));
        }

        roots
    }

    fn parse(&self, path: &Path) -> Result<SkillInstance, AdapterError> {
        let content = std::fs::read_to_string(path)
            .map_err(|err| AdapterError::new(format!("failed to read skill: {err}")))?;
        let fallback_name = path
            .parent()
            .and_then(Path::file_name)
            .and_then(|name| name.to_str())
            .unwrap_or("unknown")
            .to_string();
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
            agent: AgentId::Codex,
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
        vec![codex_user_config_path(ctx)]
    }
}

impl AgentConfigAdapter for CodexAdapter {
    fn patch_enabled(
        &self,
        doc: &mut AgentConfigDocument,
        instance: &SkillInstance,
        on: bool,
    ) -> Result<(), AdapterError> {
        doc.text = patch_codex_config(&doc.text, &instance.path, on)?;
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
        .ok_or_else(|| format!("missing required Codex frontmatter field `{key}`"))?;
    Ok(value.to_string())
}

fn codex_user_config_path(ctx: &AdapterContext) -> PathBuf {
    // AdapterContext does not yet expose a first-class Codex home override.
    // Honor CODEX_HOME only when it stays within the context user home;
    // otherwise use the verified default user config path.
    std::env::var_os("CODEX_HOME")
        .map(PathBuf::from)
        .filter(|path| path.is_absolute() && path.starts_with(&ctx.user_home))
        .unwrap_or_else(|| ctx.user_home.join(".codex"))
        .join("config.toml")
}

fn codex_project_skill_roots(project_root: &Path, project_cwd: Option<&Path>) -> Vec<AdapterRoot> {
    let start = project_cwd
        .filter(|cwd| cwd.starts_with(project_root))
        .unwrap_or(project_root);
    let mut roots = Vec::new();
    let mut current = Some(start);

    while let Some(dir) = current {
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

fn patch_codex_config(content: &str, skill_path: &Path, on: bool) -> Result<String, AdapterError> {
    let skill_path = skill_path.to_string_lossy();
    let mut output = String::new();
    let mut cursor = 0;

    while cursor < content.len() {
        let remaining = &content[cursor..];
        let Some(relative_start) = find_skills_config_header(remaining) else {
            output.push_str(remaining);
            break;
        };
        let block_start = cursor + relative_start;
        output.push_str(&content[cursor..block_start]);

        let after_header = next_line_start(content, block_start);
        let block_end = next_table_header(content, after_header).unwrap_or(content.len());
        let block = &content[block_start..block_end];
        if classify_skills_config_block(block, &skill_path)? != SkillsConfigBlock::Target {
            output.push_str(block);
        }
        cursor = block_end;
    }

    if !on {
        append_disabled_entry(&mut output, &skill_path);
    }

    if output.is_empty() {
        return Ok(output);
    }
    if !output.ends_with('\n') {
        output.push('\n');
    }
    Ok(output)
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
enum SkillsConfigBlock {
    Target,
    NonTarget,
}

fn find_skills_config_header(content: &str) -> Option<usize> {
    let mut offset = 0;
    for line in content.split_inclusive('\n') {
        if line.trim() == "[[skills.config]]" {
            return Some(offset);
        }
        offset += line.len();
    }
    if !content.ends_with('\n') && content[offset..].trim() == "[[skills.config]]" {
        return Some(offset);
    }
    None
}

fn next_line_start(content: &str, line_start: usize) -> usize {
    content[line_start..]
        .find('\n')
        .map(|offset| line_start + offset + 1)
        .unwrap_or(content.len())
}

fn next_table_header(content: &str, start: usize) -> Option<usize> {
    let mut offset = start;
    for line in content[start..].split_inclusive('\n') {
        if line.trim_start().starts_with('[') {
            return Some(offset);
        }
        offset += line.len();
    }
    None
}

pub fn parse_codex_skill_config_entries(text: &str) -> Vec<CodexSkillConfigEntry> {
    let mut entries = Vec::new();
    let mut cursor = 0;

    while cursor < text.len() {
        let remaining = &text[cursor..];
        let Some(relative_start) = find_skills_config_header(remaining) else {
            break;
        };
        let block_start = cursor + relative_start;
        let after_header = next_line_start(text, block_start);
        let block_end = next_table_header(text, after_header).unwrap_or(text.len());
        let block = &text[block_start..block_end];

        let mut entry = CodexSkillConfigEntry {
            path: None,
            enabled: None,
        };
        for raw_line in block.lines() {
            let line = raw_line.trim();
            if line.is_empty() || line.starts_with('#') || line == "[[skills.config]]" {
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };
            match key.trim() {
                "path" => {
                    if let Ok(path) = parse_toml_string(value.trim()) {
                        entry.path = Some(path);
                    }
                }
                "enabled" => {
                    if let Ok(enabled) = parse_toml_bool(value.trim()) {
                        entry.enabled = Some(enabled);
                    }
                }
                _ => {}
            }
        }
        entries.push(entry);
        cursor = block_end;
    }

    entries
}

fn classify_skills_config_block(
    block: &str,
    skill_path: &str,
) -> Result<SkillsConfigBlock, AdapterError> {
    let mut valid_paths = Vec::new();
    let mut path_line_count = 0;
    let mut target_path_line_is_malformed = false;
    let mut target_schema_errors = Vec::new();

    for (line_number, raw_line) in block.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') || line == "[[skills.config]]" {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            if looks_like_key(line, "path") && raw_line.contains(skill_path) {
                target_path_line_is_malformed = true;
            }
            if looks_like_key(line, "enabled") && raw_line.contains(skill_path) {
                target_schema_errors.push(format!(
                    "line {} has an invalid `enabled` assignment",
                    line_number + 1
                ));
            }
            continue;
        };

        let key = key.trim();
        let value = value.trim();
        if key == "path" {
            path_line_count += 1;
            match parse_toml_string(value) {
                Ok(path) => valid_paths.push(path),
                Err(err) => {
                    if raw_line.contains(skill_path) {
                        target_path_line_is_malformed = true;
                        target_schema_errors.push(format!(
                            "line {} has an invalid `path` assignment: {err}",
                            line_number + 1
                        ));
                    }
                }
            }
        } else if key == "enabled" && parse_toml_bool(value).is_err() {
            target_schema_errors.push(format!(
                "line {} has an invalid `enabled` assignment",
                line_number + 1
            ));
        }
    }

    let is_target = valid_paths.iter().any(|path| path == skill_path);
    if target_path_line_is_malformed && !is_target {
        return Err(AdapterError::new(format!(
            "invalid Codex skills.config path entry for target `{skill_path}`"
        )));
    }
    if is_target && path_line_count > 1 {
        return Err(AdapterError::new(format!(
            "malformed Codex skills.config block for target `{skill_path}`: duplicate path entries"
        )));
    }
    if is_target && !target_schema_errors.is_empty() {
        return Err(AdapterError::new(format!(
            "malformed Codex skills.config block for target `{skill_path}`: {}",
            target_schema_errors.join("; ")
        )));
    }

    if is_target {
        Ok(SkillsConfigBlock::Target)
    } else {
        Ok(SkillsConfigBlock::NonTarget)
    }
}

fn looks_like_key(line: &str, key: &str) -> bool {
    let rest = line.strip_prefix(key).unwrap_or_default();
    !rest.is_empty()
        && rest
            .chars()
            .next()
            .is_some_and(|ch| ch.is_whitespace() || ch == '=')
}

fn parse_toml_string(value: &str) -> Result<String, String> {
    if value.starts_with("\"\"\"") || value.starts_with("'''") {
        return Err("multi-line strings are not supported for Codex skill paths".to_string());
    }
    if value.starts_with('"') {
        parse_basic_toml_string(value)
    } else if value.starts_with('\'') {
        parse_literal_toml_string(value)
    } else {
        Err("path must be a TOML basic or literal string".to_string())
    }
}

fn parse_basic_toml_string(value: &str) -> Result<String, String> {
    let mut chars = value.char_indices();
    if chars.next().map(|(_, ch)| ch) != Some('"') {
        return Err("path must start with a basic string quote".to_string());
    }
    let mut parsed = String::new();
    let mut escaped = false;
    while let Some((offset, ch)) = chars.next() {
        if escaped {
            let unescaped = match ch {
                'b' => '\u{0008}',
                't' => '\t',
                'n' => '\n',
                'f' => '\u{000c}',
                'r' => '\r',
                '"' => '"',
                '\\' => '\\',
                'u' => parse_hex_escape(&mut chars, 4)?,
                'U' => parse_hex_escape(&mut chars, 8)?,
                other => return Err(format!("unsupported TOML escape `\\{other}`")),
            };
            parsed.push(unescaped);
            escaped = false;
            continue;
        }
        match ch {
            '\\' => escaped = true,
            '"' => {
                validate_toml_trailing(&value[offset + ch.len_utf8()..])?;
                return Ok(parsed);
            }
            other => parsed.push(other),
        }
    }
    Err("unterminated TOML basic string".to_string())
}

fn parse_hex_escape(chars: &mut std::str::CharIndices<'_>, width: usize) -> Result<char, String> {
    let mut hex = String::new();
    for _ in 0..width {
        let Some((_, ch)) = chars.next() else {
            return Err("incomplete TOML unicode escape".to_string());
        };
        if !ch.is_ascii_hexdigit() {
            return Err("invalid TOML unicode escape".to_string());
        }
        hex.push(ch);
    }
    let codepoint = u32::from_str_radix(&hex, 16)
        .map_err(|err| format!("invalid TOML unicode escape: {err}"))?;
    char::from_u32(codepoint).ok_or_else(|| "invalid TOML unicode scalar value".to_string())
}

fn parse_literal_toml_string(value: &str) -> Result<String, String> {
    let rest = value
        .strip_prefix('\'')
        .ok_or_else(|| "path must start with a literal string quote".to_string())?;
    let end = rest
        .find('\'')
        .ok_or_else(|| "unterminated TOML literal string".to_string())?;
    validate_toml_trailing(&rest[end + 1..])?;
    Ok(rest[..end].to_string())
}

fn parse_toml_bool(value: &str) -> Result<bool, String> {
    let value = value.trim_start();
    if let Some(rest) = value.strip_prefix("true") {
        validate_toml_trailing(rest)?;
        return Ok(true);
    }
    if let Some(rest) = value.strip_prefix("false") {
        validate_toml_trailing(rest)?;
        return Ok(false);
    }
    Err("enabled must be true or false".to_string())
}

fn validate_toml_trailing(rest: &str) -> Result<(), String> {
    let trailing = rest.trim_start();
    if trailing.is_empty() || trailing.starts_with('#') {
        Ok(())
    } else {
        Err(format!("unexpected trailing content `{trailing}`"))
    }
}

fn append_disabled_entry(output: &mut String, skill_path: &str) {
    if !output.is_empty() && !output.ends_with("\n\n") {
        if !output.ends_with('\n') {
            output.push('\n');
        }
        output.push('\n');
    }
    output.push_str("[[skills.config]]\npath = \"");
    output.push_str(&escape_toml_basic_string(skill_path));
    output.push_str("\"\nenabled = false\n");
}

fn escape_toml_basic_string(value: &str) -> String {
    let mut escaped = String::new();
    for ch in value.chars() {
        match ch {
            '\u{0008}' => escaped.push_str("\\b"),
            '\t' => escaped.push_str("\\t"),
            '\n' => escaped.push_str("\\n"),
            '\u{000c}' => escaped.push_str("\\f"),
            '\r' => escaped.push_str("\\r"),
            '"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            other => escaped.push(other),
        }
    }
    escaped
}

fn stable_path_id(path: &Path) -> String {
    format!("codex:{}", path.display())
}

#[cfg(test)]
mod tests {
    use skills_copilot_core::{AgentConfigDocument, ConfigFormat, RootSource, SkillState};

    use super::*;

    #[test]
    fn exposes_verified_user_and_project_roots_only() {
        let adapter = CodexAdapter;
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
        assert_eq!(roots[0].path, PathBuf::from("/tmp/home/.agents/skills"));
        assert_eq!(roots[0].scope, Scope::AgentGlobal);
        assert_eq!(roots[0].source, RootSource::UserHome);
        assert_eq!(
            roots[1].path,
            PathBuf::from("/tmp/project/nested/deeper/.agents/skills")
        );
        assert_eq!(
            roots[2].path,
            PathBuf::from("/tmp/project/nested/.agents/skills")
        );
        assert_eq!(roots[3].path, PathBuf::from("/tmp/project/.agents/skills"));
        for root in &roots[1..] {
            assert_eq!(root.scope, Scope::AgentProject);
            assert_eq!(root.source, RootSource::Project);
        }
    }

    #[test]
    fn parses_valid_skill_frontmatter() {
        let adapter = CodexAdapter;
        let fixture = write_skill(
            "valid-codex",
            "---\nname: codex-alpha\ndescription: Alpha Codex skill.\n---\nBody.\n",
        );

        let skill = adapter.parse(&fixture).expect("skill parses");

        assert_eq!(skill.agent, AgentId::Codex);
        assert_eq!(skill.name, "codex-alpha");
        assert_eq!(skill.description, "Alpha Codex skill.");
        assert_eq!(
            skill.frontmatter_raw,
            "name: codex-alpha\ndescription: Alpha Codex skill."
        );
        assert_eq!(skill.body, "Body.\n");
        assert_eq!(skill.state, SkillState::Loaded);
        assert!(skill.enabled);
        assert!(skill.permissions.tools.is_empty());
    }

    #[test]
    fn marks_missing_description_as_broken() {
        let adapter = CodexAdapter;
        let fixture = fixture_path("fixtures/codex/broken/missing-description/SKILL.md");

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "missing-description");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill.description.contains("description"));
    }

    #[test]
    fn marks_missing_name_as_broken() {
        let adapter = CodexAdapter;
        let fixture = write_skill(
            "missing-name",
            "---\ndescription: Missing name fixture.\n---\nBody.\n",
        );

        let skill = adapter.parse(&fixture).expect("broken skill is returned");

        assert_eq!(skill.name, "missing-name");
        assert_eq!(skill.state, SkillState::Broken);
        assert!(!skill.enabled);
        assert!(skill.description.contains("name"));
    }

    #[test]
    fn disable_adds_one_disabled_entry() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc("profile = \"default\"\n");
        let skill = skill_for_path(&skill_path);

        adapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch succeeds");

        assert!(doc.text.contains("profile = \"default\""));
        assert_eq!(doc.text.matches("[[skills.config]]").count(), 1);
        assert!(doc.text.contains("path = \"/tmp/codex/alpha/SKILL.md\""));
        assert!(doc.text.contains("enabled = false"));
    }

    #[test]
    fn disable_preserves_comments_and_non_target_config() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc(
            "# Codex user config\nprofile = \"default\"\n\n[model]\nname = \"gpt-5\"\n\n# keep beta disabled\n[[skills.config]]\n# literal string path must remain intact\npath = '/tmp/codex/beta/SKILL.md'\nenabled = false\n\n[profiles.work]\nmodel = \"gpt-5-codex\"\n\n[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = true\n",
        );
        let skill = skill_for_path(&skill_path);

        adapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch succeeds");

        assert!(doc.text.contains("# Codex user config"));
        assert!(doc.text.contains("[model]\nname = \"gpt-5\""));
        assert!(doc.text.contains("# keep beta disabled"));
        assert!(doc.text.contains("path = '/tmp/codex/beta/SKILL.md'"));
        assert!(doc
            .text
            .contains("[profiles.work]\nmodel = \"gpt-5-codex\""));
        assert_eq!(doc.text.matches("/tmp/codex/alpha/SKILL.md").count(), 1);
        assert!(doc.text.contains("path = \"/tmp/codex/alpha/SKILL.md\""));
        assert!(doc.text.contains("enabled = false"));
        assert!(!doc
            .text
            .contains("path = \"/tmp/codex/alpha/SKILL.md\"\nenabled = true"));
    }

    #[test]
    fn enable_removes_all_matching_entries_and_leaves_non_targets() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc(
            "profile = \"default\"\n\n[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = false\n\n[[skills.config]]\npath = '/tmp/codex/beta/SKILL.md'\nenabled = false\n\n[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = true\n",
        );
        let skill = skill_for_path(&skill_path);

        adapter
            .patch_enabled(&mut doc, &skill, true)
            .expect("enable patch succeeds");

        assert!(doc.text.contains("profile = \"default\""));
        assert!(!doc.text.contains("/tmp/codex/alpha/SKILL.md"));
        assert!(doc.text.contains("/tmp/codex/beta/SKILL.md"));
        assert_eq!(doc.text.matches("[[skills.config]]").count(), 1);
    }

    #[test]
    fn disable_normalizes_duplicate_matching_entries() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc(
            "[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = true\n\n[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = false\n",
        );
        let skill = skill_for_path(&skill_path);

        adapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch succeeds");

        assert_eq!(doc.text.matches("[[skills.config]]").count(), 1);
        assert_eq!(doc.text.matches("/tmp/codex/alpha/SKILL.md").count(), 1);
        assert!(doc.text.contains("enabled = false"));
        assert!(!doc.text.contains("enabled = true"));
    }

    #[test]
    fn disable_matches_basic_and_literal_target_strings() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc(
            "[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\" # basic string\nenabled = true\n\n[[skills.config]]\npath = '/tmp/codex/alpha/SKILL.md' # literal string\nenabled = false\n",
        );
        let skill = skill_for_path(&skill_path);

        adapter
            .patch_enabled(&mut doc, &skill, false)
            .expect("disable patch succeeds");

        assert_eq!(doc.text.matches("[[skills.config]]").count(), 1);
        assert_eq!(doc.text.matches("/tmp/codex/alpha/SKILL.md").count(), 1);
        assert!(doc.text.contains("path = \"/tmp/codex/alpha/SKILL.md\""));
        assert!(doc.text.contains("enabled = false"));
        assert!(!doc.text.contains("# basic string"));
        assert!(!doc.text.contains("# literal string"));
    }

    #[test]
    fn parses_skill_config_entries_with_toml_comments_and_literal_strings() {
        let entries = parse_codex_skill_config_entries(
            r#"
profile = "default"

[[skills.config]]
path = '/tmp/codex/alpha/SKILL.md' # literal path
enabled = false # trailing comment

[[skills.config]]
path = "/tmp/codex/beta/SKILL.md" # basic path
enabled = true
"#,
        );

        assert_eq!(entries.len(), 2);
        assert_eq!(
            entries[0].path.as_deref(),
            Some("/tmp/codex/alpha/SKILL.md")
        );
        assert_eq!(entries[0].enabled, Some(false));
        assert_eq!(entries[1].path.as_deref(), Some("/tmp/codex/beta/SKILL.md"));
        assert_eq!(entries[1].enabled, Some(true));
    }

    #[test]
    fn invalid_target_path_line_returns_error() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc =
            config_doc("[[skills.config]]\npath = /tmp/codex/alpha/SKILL.md\nenabled = false\n");
        let skill = skill_for_path(&skill_path);

        let err = adapter
            .patch_enabled(&mut doc, &skill, false)
            .expect_err("invalid target path should fail");

        assert!(err.message.contains("invalid Codex skills.config path"));
        assert!(doc.text.contains("path = /tmp/codex/alpha/SKILL.md"));
    }

    #[test]
    fn malformed_target_block_returns_error() {
        let adapter = CodexAdapter;
        let skill_path = PathBuf::from("/tmp/codex/alpha/SKILL.md");
        let mut doc = config_doc(
            "[[skills.config]]\npath = \"/tmp/codex/alpha/SKILL.md\"\nenabled = \"false\"\n",
        );
        let skill = skill_for_path(&skill_path);

        let err = adapter
            .patch_enabled(&mut doc, &skill, true)
            .expect_err("malformed target block should fail");

        assert!(err.message.contains("malformed Codex skills.config block"));
        assert!(err.message.contains("enabled"));
        assert!(doc.text.contains("enabled = \"false\""));
    }

    #[test]
    fn same_frontmatter_name_keeps_path_distinct_instances() {
        let adapter = CodexAdapter;
        let path_a = write_skill(
            "conflict-a",
            "---\nname: shared-codex\ndescription: First.\n---\nBody A.\n",
        );
        let path_b = write_skill(
            "conflict-b",
            "---\nname: shared-codex\ndescription: Second.\n---\nBody B.\n",
        );

        let skill_a = adapter.parse(&path_a).expect("skill a parses");
        let skill_b = adapter.parse(&path_b).expect("skill b parses");

        assert_eq!(skill_a.name, skill_b.name);
        assert_ne!(skill_a.id, skill_b.id);
    }

    fn config_doc(text: &str) -> AgentConfigDocument {
        AgentConfigDocument {
            path: PathBuf::from("/tmp/home/.codex/config.toml"),
            format: ConfigFormat::Toml,
            text: text.to_string(),
        }
    }

    fn skill_for_path(path: &Path) -> SkillInstance {
        SkillInstance {
            id: "codex-alpha-id".to_string(),
            agent: AgentId::Codex,
            scope: Scope::AgentGlobal,
            project_root: None,
            path: path.to_path_buf(),
            display_path: path.to_path_buf(),
            definition_id: "codex-alpha".to_string(),
            name: "codex-alpha".to_string(),
            display_name: "codex-alpha".to_string(),
            description: "Alpha".to_string(),
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

    fn write_skill(name: &str, content: &str) -> PathBuf {
        let root = std::env::temp_dir().join(format!(
            "skills-copilot-codex-adapter-{}-{}",
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
