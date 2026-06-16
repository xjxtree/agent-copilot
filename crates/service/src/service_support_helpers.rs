use super::*;

pub(crate) fn scan_all_label(agent_reports: &[AgentCatalogScanReport]) -> String {
    let labels: Vec<&str> = agent_reports
        .iter()
        .map(|report| report.display_name)
        .collect();
    display_label_list(&labels).unwrap_or_else(|| "supported agents".to_string())
}

pub(crate) fn display_label_list(labels: &[&str]) -> Option<String> {
    match labels {
        [] => None,
        [one] => Some((*one).to_string()),
        [first, second] => Some(format!("{first} and {second}")),
        _ => {
            let mut label = labels[..labels.len() - 1].join(", ");
            label.push_str(", and ");
            label.push_str(labels[labels.len() - 1]);
            Some(label)
        }
    }
}

pub(crate) fn skipped_roots_detail(roots_skipped: &[String]) -> String {
    if roots_skipped.is_empty() {
        return String::new();
    }
    let mut detail = format!("; root-error skipped-root path(s): {}", roots_skipped[0]);
    if roots_skipped.len() > 1 {
        detail.push_str(&format!(" (+{} more)", roots_skipped.len() - 1));
    }
    detail
}

pub fn handle_request_json(input: &str) -> String {
    let response = match serde_json::from_str::<ServiceRequest>(input) {
        Ok(request) => match ServiceHost::from_env() {
            Ok(host) => host.handle(request),
            Err(error) => ServiceResponse {
                id: None,
                ok: false,
                result: None,
                error: Some(ServiceErrorRecord {
                    code: error.code().to_string(),
                    message: error.to_string(),
                }),
            },
        },
        Err(error) => ServiceResponse {
            id: None,
            ok: false,
            result: None,
            error: Some(ServiceErrorRecord {
                code: "parse_error".to_string(),
                message: error.to_string(),
            }),
        },
    };
    serde_json::to_string(&response).unwrap_or_else(|error| {
        json!({
            "id": null,
            "ok": false,
            "error": {
                "code": "serialize_error",
                "message": error.to_string()
            }
        })
        .to_string()
    })
}

pub(crate) fn default_app_data_dir(user_home: &Path) -> PathBuf {
    if cfg!(target_os = "macos") {
        user_home
            .join("Library")
            .join("Application Support")
            .join(DEFAULT_BUNDLE_ID)
    } else {
        user_home.join(".skills-copilot").join(DEFAULT_BUNDLE_ID)
    }
}

pub(crate) fn infer_project_root(cwd: &Path) -> PathBuf {
    let mut current = Some(cwd);
    while let Some(dir) = current {
        if dir.join(".git").exists() {
            return dir.to_path_buf();
        }
        current = dir.parent();
    }
    cwd.to_path_buf()
}

pub(crate) fn extra_claude_roots_from_env() -> Vec<AdapterRoot> {
    let Some(raw) = env::var_os("SKILLS_COPILOT_CLAUDE_EXTRA_ROOTS") else {
        return Vec::new();
    };
    env::split_paths(&raw)
        .map(|path| AdapterRoot {
            scope: Scope::AgentGlobal,
            path,
            source: RootSource::Extra,
        })
        .collect()
}

pub(crate) fn display_path(path: &Path) -> String {
    path.to_string_lossy().to_string()
}

pub(crate) fn report_export_formats(
    mut formats: Vec<ReportExportFormat>,
) -> Vec<ReportExportFormat> {
    if formats.is_empty() {
        formats = vec![ReportExportFormat::Json, ReportExportFormat::Markdown];
    }
    let mut seen = Vec::new();
    formats
        .into_iter()
        .filter(|format| {
            if seen.contains(format) {
                false
            } else {
                seen.push(*format);
                true
            }
        })
        .collect()
}

pub(crate) fn report_export_redaction() -> ReportExportRedaction {
    ReportExportRedaction {
        enabled: true,
        placeholders: vec!["$HOME", "<project-root>", "<project-cwd>", "<app-data-dir>"],
        path_policy:
            "Local home, app data, and active project path prefixes are replaced before writing report files.",
    }
}

pub(crate) fn report_export_summary(
    skills: &Value,
    findings: &Value,
    triage: &Value,
    cleanup: &Value,
    comparison: &Value,
) -> ReportExportSummary {
    let finding_items = findings.as_array().map(Vec::len).unwrap_or_default();
    ReportExportSummary {
        skill_count: skills.as_array().map(Vec::len).unwrap_or_default(),
        finding_count: finding_items,
        open_finding_count: findings
            .as_array()
            .map(|items| {
                items
                    .iter()
                    .filter(|finding| {
                        finding
                            .get("triage_status")
                            .and_then(Value::as_str)
                            .is_none_or(|status| status == "open")
                            && !finding
                                .get("suppressed")
                                .and_then(Value::as_bool)
                                .unwrap_or(false)
                    })
                    .count()
            })
            .unwrap_or_default(),
        triage_count: triage.as_array().map(Vec::len).unwrap_or_default(),
        cleanup_item_count: cleanup
            .get("items")
            .and_then(Value::as_array)
            .map(Vec::len)
            .unwrap_or_default(),
        comparison_group_count: comparison
            .get("groups")
            .and_then(Value::as_array)
            .map(Vec::len)
            .unwrap_or_default(),
    }
}

pub(crate) fn empty_health_summary_json() -> Value {
    json!({
        "total_count": 0,
        "enabled_count": 0,
        "disabled_count": 0,
        "broken_count": 0,
        "missing_count": 0,
        "malformed_count": 0,
        "finding_count": 0,
        "conflict_count": 0,
        "risky_script_count": 0,
        "risky_permission_count": 0,
        "findings_by_severity": {
            "error_count": 0,
            "warning_count": 0,
            "info_count": 0
        },
        "analysis_groups": {
            "total_count": 0,
            "error_count": 0,
            "warning_count": 0,
            "info_count": 0,
            "duplicate_name_count": 0,
            "canonical_name_count": 0,
            "path_overlap_count": 0,
            "enabled_mismatch_count": 0,
            "malformed_count": 0,
            "precedence_count": 0
        },
        "agent_summaries": []
    })
}

pub(crate) fn empty_cross_agent_analysis_json() -> Value {
    json!({
        "summary": {
            "total_groups": 0,
            "duplicate_name_groups": 0,
            "canonical_name_groups": 0,
            "path_overlap_groups": 0,
            "enabled_mismatch_groups": 0,
            "malformed_groups": 0,
            "precedence_groups": 0,
            "affected_skill_count": 0
        },
        "groups": []
    })
}

pub(crate) fn redact_report_value(value: &mut Value, roots: &[(String, &'static str)]) {
    match value {
        Value::String(text) => {
            *text = redact_string(text, roots);
        }
        Value::Array(items) => {
            for item in items {
                redact_report_value(item, roots);
            }
        }
        Value::Object(object) => {
            for item in object.values_mut() {
                redact_report_value(item, roots);
            }
        }
        Value::Null | Value::Bool(_) | Value::Number(_) => {}
    }
}

pub(crate) fn redact_path_string(path: &Path, roots: &[(String, &'static str)]) -> String {
    redact_string(&path.to_string_lossy(), roots)
}

pub(crate) fn redact_string(value: &str, roots: &[(String, &'static str)]) -> String {
    let mut redacted = value.to_string();
    for (root, placeholder) in roots {
        if !root.is_empty() {
            redacted = redacted.replace(root, placeholder);
        }
    }
    redacted
}

pub(crate) fn render_report_markdown(report: &Value) -> String {
    let summary = report.get("summary").unwrap_or(&Value::Null);
    let safety = report.get("safety").unwrap_or(&Value::Null);
    let health = report.get("health").unwrap_or(&Value::Null);
    let cleanup = report.get("cleanup_queue").unwrap_or(&Value::Null);
    let comparison = report
        .pointer("/cross_agent/comparison/summary")
        .unwrap_or(&Value::Null);
    let mut markdown = String::new();
    markdown.push_str("# Skills Copilot Local Report\n\n");
    markdown.push_str(&format!(
        "- Export ID: {}\n",
        report_string(report, "/export_id")
    ));
    markdown.push_str(&format!(
        "- Generated at: {}\n",
        report_string(report, "/generated_at")
    ));
    markdown.push_str(&format!(
        "- Catalog available: {}\n\n",
        report_string(report, "/catalog_available")
    ));
    markdown.push_str("## Safety\n\n");
    markdown.push_str(&format!(
        "- Read-only: {}\n- Writes allowed: {}\n- Provider request sent: {}\n- Script execution allowed: {}\n- Credential accessed: {}\n\n",
        json_field_string(safety, "read_only"),
        json_field_string(safety, "writes_allowed"),
        json_field_string(safety, "provider_request_sent"),
        json_field_string(safety, "script_execution_allowed"),
        json_field_string(safety, "credential_accessed")
    ));
    markdown.push_str("## Summary\n\n");
    for key in [
        "skill_count",
        "finding_count",
        "open_finding_count",
        "triage_count",
        "cleanup_item_count",
        "comparison_group_count",
    ] {
        markdown.push_str(&format!("- {}: {}\n", key, json_field_string(summary, key)));
    }
    markdown.push_str("\n## Health\n\n");
    for key in [
        "total_count",
        "enabled_count",
        "disabled_count",
        "broken_count",
        "missing_count",
        "finding_count",
        "conflict_count",
    ] {
        markdown.push_str(&format!("- {}: {}\n", key, json_field_string(health, key)));
    }
    markdown.push_str("\n## Cleanup Queue\n\n");
    markdown.push_str(&format!(
        "- Total items: {}\n- Read-only: {}\n- Writes allowed: {}\n\n",
        report_string(cleanup, "/summary/total_count"),
        report_string(cleanup, "/summary/read_only"),
        report_string(cleanup, "/summary/writes_allowed")
    ));
    markdown.push_str("## Cross-agent Comparison\n\n");
    markdown.push_str(&format!(
        "- Total groups: {}\n- Returned groups: {}\n- Compared skill count: {}\n\n",
        json_field_string(comparison, "total_groups"),
        json_field_string(comparison, "returned_groups"),
        json_field_string(comparison, "compared_skill_count")
    ));
    markdown.push_str("## Redaction\n\n");
    markdown.push_str("- Path prefixes are replaced with `$HOME`, `<project-root>`, `<project-cwd>`, or `<app-data-dir>` before report files are written.\n");
    markdown
}

pub(crate) fn report_string(value: &Value, pointer: &str) -> String {
    value
        .pointer(pointer)
        .map(value_to_markdown_string)
        .unwrap_or_else(|| "n/a".to_string())
}

pub(crate) fn json_field_string(value: &Value, field: &str) -> String {
    value
        .get(field)
        .map(value_to_markdown_string)
        .unwrap_or_else(|| "n/a".to_string())
}

pub(crate) fn value_to_markdown_string(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Number(number) => number.to_string(),
        Value::Bool(flag) => flag.to_string(),
        Value::Null => "null".to_string(),
        Value::Array(items) => format!("{} item(s)", items.len()),
        Value::Object(object) => format!("{} field(s)", object.len()),
    }
}

pub(crate) fn is_pi_plain_markdown_catalog_noise(skill: &SkillRecord) -> bool {
    skill.agent == AgentId::Pi.as_str()
        && skill
            .path
            .extension()
            .and_then(|extension| extension.to_str())
            == Some("md")
        && skill.path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md")
}

pub(crate) fn is_pi_plain_markdown_instance_noise(skill: &SkillInstance) -> bool {
    skill.agent == AgentId::Pi
        && skill
            .path
            .extension()
            .and_then(|extension| extension.to_str())
            == Some("md")
        && skill.path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md")
}

pub(crate) fn unix_timestamp_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| i64::try_from(duration.as_millis()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

pub(crate) fn estimate_tokens(parts: &[&str]) -> u32 {
    let chars = parts.iter().map(|part| part.chars().count()).sum::<usize>();
    let estimated = chars.div_ceil(4).saturating_add(120);
    u32::try_from(estimated).unwrap_or(u32::MAX)
}

#[derive(Debug, Clone)]
pub(crate) struct BuiltLlmPrompt {
    pub(crate) prompt_preview: String,
    pub(crate) prompt_scope: Vec<String>,
    pub(crate) included_fields: Vec<String>,
    pub(crate) excluded_fields: Vec<String>,
    pub(crate) redaction: LlmPromptRedactionSummary,
    pub(crate) estimated_output_tokens: u32,
}

pub(crate) struct PromptRedactor<'a> {
    roots: &'a [(String, &'static str)],
    redacted_value_count: usize,
    redacted_fields: BTreeMap<String, ()>,
}

impl<'a> PromptRedactor<'a> {
    pub(crate) fn new(roots: &'a [(String, &'static str)]) -> Self {
        Self {
            roots,
            redacted_value_count: 0,
            redacted_fields: BTreeMap::new(),
        }
    }

    pub(crate) fn redact(&mut self, value: &str) -> String {
        let (path_redacted, path_count) = redact_with_count(value, self.roots);
        if path_count > 0 {
            self.redacted_value_count += path_count;
            self.redacted_fields.insert("local paths".to_string(), ());
        }
        let mut token_count = 0usize;
        let mut redact_next_token = false;
        let redacted = path_redacted
            .split_whitespace()
            .map(|token| {
                let trimmed = token.trim_matches(|ch: char| {
                    matches!(ch, '"' | '\'' | ',' | ';' | ')' | '(' | '[' | ']')
                });
                let lower = trimmed.to_lowercase();
                if redact_next_token {
                    redact_next_token = lower == "bearer";
                    token_count += 1;
                    "<redacted>"
                } else if lower.contains("key")
                    || lower.contains("token")
                    || lower.contains("secret")
                    || lower.contains("credential")
                    || lower.contains("password")
                    || lower == "authorization:"
                    || lower == "bearer"
                {
                    redact_next_token = !trimmed.contains('=');
                    token_count += 1;
                    "<redacted>"
                } else if lower.starts_with("http://") || lower.starts_with("https://") {
                    token_count += 1;
                    "<redacted-url>"
                } else if looks_like_high_entropy_secret(trimmed) {
                    token_count += 1;
                    "<redacted-secret>"
                } else {
                    token
                }
            })
            .collect::<Vec<_>>()
            .join(" ");
        if token_count > 0 {
            self.redacted_value_count += token_count;
            self.redacted_fields
                .insert("secret-like tokens and private URLs".to_string(), ());
        }
        redacted
    }

    pub(crate) fn summary(self) -> LlmPromptRedactionSummary {
        LlmPromptRedactionSummary {
            status: "redacted-preview-confirmed-required".to_string(),
            redacted_value_count: self.redacted_value_count,
            redacted_fields: self.redacted_fields.into_keys().collect(),
            placeholders: vec![
                "$HOME",
                "<project-root>",
                "<project-cwd>",
                "<app-data-dir>",
                "<redacted>",
                "<redacted-url>",
            ],
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_secret_returned: false,
        }
    }
}

pub(crate) fn looks_like_high_entropy_secret(value: &str) -> bool {
    let token = value.trim_matches(|ch: char| {
        matches!(
            ch,
            '"' | '\'' | ',' | ';' | ')' | '(' | '[' | ']' | '{' | '}' | ':' | '.'
        )
    });
    let len = token.chars().count();
    if len < 32 || token.contains('/') || token.contains('\\') {
        return false;
    }
    let allowed = token
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_' | '=' | '+'));
    if !allowed {
        return false;
    }
    let has_upper = token.chars().any(|ch| ch.is_ascii_uppercase());
    let has_lower = token.chars().any(|ch| ch.is_ascii_lowercase());
    let has_digit = token.chars().any(|ch| ch.is_ascii_digit());
    let has_symbol = token.chars().any(|ch| matches!(ch, '-' | '_' | '=' | '+'));
    let class_count = [has_upper, has_lower, has_digit, has_symbol]
        .into_iter()
        .filter(|flag| *flag)
        .count();
    let unique_count = token.chars().collect::<BTreeSet<_>>().len();
    class_count >= 3 && unique_count >= 16
}

pub(crate) fn redact_with_count(value: &str, roots: &[(String, &'static str)]) -> (String, usize) {
    let mut redacted = value.to_string();
    let mut count = 0usize;
    for (root, placeholder) in roots {
        if !root.is_empty() && redacted.contains(root) {
            count += redacted.matches(root).count();
            redacted = redacted.replace(root, placeholder);
        }
    }
    (redacted, count)
}

pub(crate) fn llm_preview_id(
    params: &LlmPreviewPromptParams,
    profile: Option<&ProviderProfileRecord>,
    prompt_preview: &str,
    estimated_input_tokens: u32,
    estimated_output_tokens: u32,
) -> String {
    let profile_fingerprint = profile
        .map(|profile| {
            format!(
                "{}\x1f{}\x1f{}\x1f{}",
                profile.id,
                profile.provider_type.as_str(),
                profile.base_url,
                profile.model
            )
        })
        .unwrap_or_else(|| "no-profile".to_string());
    let source = serde_json::json!({
        "version": "v2.42",
        "profile": profile_fingerprint,
        "action": params.action.as_str(),
        "skill_instance_id": params.skill_instance_id,
        "instance_ids": params.instance_ids,
        "analysis_kind": params.analysis_kind.map(|kind| kind.as_str()),
        "user_intent": params.user_intent.as_deref(),
        "prompt": prompt_preview,
        "estimated_input_tokens": estimated_input_tokens,
        "estimated_output_tokens": estimated_output_tokens
    });
    let digest = Sha256::digest(source.to_string().as_bytes());
    format!("prompt-preview-{digest:x}")
}

pub(crate) fn llm_prompt_action_type(params: &LlmPreviewPromptParams) -> String {
    match params.action {
        LlmPromptActionKind::SkillAnalysis => format!(
            "skill_analysis:{}",
            params
                .analysis_kind
                .unwrap_or(LlmSkillAnalysisKind::Overview)
                .as_str()
        ),
        other => other.as_str().to_string(),
    }
}

pub(crate) fn inferred_llm_prompt_scope(params: &LlmPreviewPromptParams) -> Option<String> {
    if params.instance_ids.len() > 1 {
        Some("visible".to_string())
    } else if params.skill_instance_id.is_some() || params.instance_ids.len() == 1 {
        Some("selected".to_string())
    } else {
        None
    }
}

pub(crate) fn destination_host_for_url(base_url: &str) -> String {
    let without_scheme = base_url
        .strip_prefix("https://")
        .or_else(|| base_url.strip_prefix("http://"))
        .unwrap_or(base_url);
    without_scheme
        .split('/')
        .next()
        .unwrap_or("<unknown>")
        .to_string()
}

pub(crate) fn llm_review_risk(
    findings: &[RuleFindingRecord],
    frontmatter_raw: &str,
    body: &str,
) -> LlmReviewRisk {
    let highest = findings
        .iter()
        .map(|finding| finding.severity.as_str())
        .max_by_key(|severity| severity_rank(severity))
        .unwrap_or("none");
    let level = match highest {
        "critical" | "error" => "high",
        "warning" | "warn" => "medium",
        _ if findings.is_empty() => "low",
        _ => "medium",
    };
    let mut signals = findings
        .iter()
        .take(8)
        .map(|finding| {
            format!(
                "{} finding from rule {}",
                redact_for_llm_preview(&finding.severity),
                redact_for_llm_preview(&finding.rule_id)
            )
        })
        .collect::<Vec<_>>();
    let combined = format!("{frontmatter_raw}\n{body}").to_lowercase();
    if combined.contains("exec") || combined.contains("command") || combined.contains("#!") {
        signals.push(
            "Skill text contains execution-related terms; scripts remain non-executable by this service."
                .to_string(),
        );
    }
    if combined.contains("network") || combined.contains("http") || combined.contains("api") {
        signals.push(
            "Skill text contains network/API-related terms; this preview performs no network I/O."
                .to_string(),
        );
    }
    if signals.is_empty() {
        signals.push("No current rule findings are associated with this skill.".to_string());
    }
    LlmReviewRisk {
        level,
        summary: format!(
            "Offline risk preview is {level}; based on {} related finding(s) and redacted local metadata only.",
            findings.len()
        ),
        signals,
    }
}

pub(crate) fn severity_rank(severity: &str) -> u8 {
    match severity {
        "critical" => 5,
        "error" => 4,
        "warning" | "warn" => 3,
        "info" => 2,
        _ => 1,
    }
}

pub(crate) fn llm_review_redaction() -> LlmReviewRedaction {
    LlmReviewRedaction {
        skill_body_returned: false,
        paths_returned: false,
        credentials_returned: false,
        included_fields: vec![
            "skill name",
            "skill description",
            "agent",
            "scope",
            "definition id match counts",
            "rule finding ids",
            "rule finding severities",
            "redacted rule messages",
        ],
        excluded_fields: vec![
            "skill body",
            "raw frontmatter",
            "source paths",
            "credential values",
            "provider prompts",
            "provider responses",
        ],
    }
}
