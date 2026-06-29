use super::*;
use std::io::{self, Write};
use time::{format_description::well_known::Rfc3339, OffsetDateTime};
use url::Url;

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
    app_data_dir_for_bundle_id(user_home, DEFAULT_BUNDLE_ID)
}

pub(crate) fn legacy_app_data_dir(user_home: &Path) -> PathBuf {
    app_data_dir_for_bundle_id(user_home, LEGACY_BUNDLE_ID)
}

pub(crate) fn resolve_default_app_data_dir(user_home: &Path) -> Result<PathBuf, ServiceError> {
    let preferred = default_app_data_dir(user_home);
    let legacy = legacy_app_data_dir(user_home);
    if preferred.exists() || !legacy.is_dir() {
        return Ok(preferred);
    }
    migrate_legacy_app_data_dir(&legacy, &preferred)?;
    Ok(preferred)
}

fn app_data_dir_for_bundle_id(user_home: &Path, bundle_id: &str) -> PathBuf {
    if cfg!(target_os = "macos") {
        user_home
            .join("Library")
            .join("Application Support")
            .join(bundle_id)
    } else {
        user_home.join(".skills-copilot").join(bundle_id)
    }
}

fn migrate_legacy_app_data_dir(source: &Path, target: &Path) -> Result<(), ServiceError> {
    if target.exists() {
        return Ok(());
    }
    let parent = target
        .parent()
        .ok_or_else(|| ServiceError::InvalidRequest("app data target has no parent".to_string()))?;
    fs::create_dir_all(parent)?;
    let target_name = target
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("agent-copilot-app-data");
    let staging = parent.join(format!(
        ".{target_name}.migration-{}",
        unix_timestamp_millis()
    ));
    if staging.exists() {
        fs::remove_dir_all(&staging)?;
    }

    let result = (|| -> Result<(), ServiceError> {
        create_private_dir_all(&staging)?;
        copy_app_data_contents(source, &staging)?;
        let marker = json!({
            "version": 1,
            "migration": "v2.90-agent-copilot-app-data",
            "source_bundle_id": LEGACY_BUNDLE_ID,
            "target_bundle_id": DEFAULT_BUNDLE_ID,
            "source_path": display_path(source),
            "target_path": display_path(target),
            "migrated_at_unix_ms": unix_timestamp_millis(),
        });
        write_private_text_file(
            &staging.join("agent-copilot-app-data-migration.json"),
            &serde_json::to_string_pretty(&marker)?,
        )?;
        fs::rename(&staging, target)?;
        set_private_dir_permissions(target)?;
        Ok(())
    })();

    if result.is_err() {
        let _ = fs::remove_dir_all(&staging);
    }
    result
}

fn copy_app_data_contents(source: &Path, target: &Path) -> Result<(), ServiceError> {
    for entry in fs::read_dir(source)? {
        let entry = entry?;
        let file_type = entry.file_type()?;
        let destination = target.join(entry.file_name());
        if file_type.is_symlink() {
            continue;
        }
        if file_type.is_dir() {
            create_private_dir_all(&destination)?;
            copy_app_data_contents(&entry.path(), &destination)?;
        } else if file_type.is_file() {
            fs::copy(entry.path(), &destination)?;
            set_private_path_permissions(&destination)?;
        }
    }
    Ok(())
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

pub(crate) fn create_private_dir_all(path: &Path) -> io::Result<()> {
    fs::create_dir_all(path)?;
    set_private_dir_permissions(path)?;
    Ok(())
}

pub(crate) fn write_private_text_file(path: &Path, content: &str) -> io::Result<()> {
    write_private_bytes_file(path, content.as_bytes())
}

pub(crate) fn write_private_bytes_file(path: &Path, content: &[u8]) -> io::Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "private file has no parent"))?;
    create_private_dir_all(parent)?;
    reject_symlink(path, "private file")?;

    let tmp = private_tmp_path(path)?;
    reject_symlink(&tmp, "private temp file")?;
    let mut options = fs::OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let write_result = (|| -> io::Result<()> {
        let mut file = options.open(&tmp)?;
        set_private_file_permissions(&file)?;
        file.write_all(content)?;
        file.sync_all()?;
        drop(file);

        reject_symlink(path, "private file")?;
        fs::rename(&tmp, path)?;
        set_private_path_permissions(path)?;
        sync_parent_dir(parent);
        Ok(())
    })();
    if write_result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    write_result
}

pub(crate) fn append_private_line(path: &Path, line: &str) -> io::Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "private file has no parent"))?;
    create_private_dir_all(parent)?;
    reject_symlink(path, "private file")?;

    let mut options = fs::OpenOptions::new();
    options.create(true).append(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(path)?;
    set_private_file_permissions(&file)?;
    writeln!(file, "{line}")?;
    file.sync_all()?;
    sync_parent_dir(parent);
    Ok(())
}

fn private_tmp_path(path: &Path) -> io::Result<PathBuf> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "private file has no parent"))?;
    let file_name = path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "private file has no name"))?
        .to_string_lossy();
    Ok(parent.join(format!(
        ".{file_name}.{}.{}.tmp",
        std::process::id(),
        unix_timestamp_millis()
    )))
}

fn reject_symlink(path: &Path, label: &str) -> io::Result<()> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{label} is a symlink: {}", path.display()),
        )),
        Ok(_) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error),
    }
}

#[cfg(unix)]
fn set_private_dir_permissions(path: &Path) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    fs::set_permissions(path, fs::Permissions::from_mode(0o700))
}

#[cfg(not(unix))]
fn set_private_dir_permissions(_path: &Path) -> io::Result<()> {
    Ok(())
}

#[cfg(unix)]
fn set_private_file_permissions(file: &fs::File) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    file.set_permissions(fs::Permissions::from_mode(0o600))
}

#[cfg(not(unix))]
fn set_private_file_permissions(_file: &fs::File) -> io::Result<()> {
    Ok(())
}

#[cfg(unix)]
fn set_private_path_permissions(path: &Path) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;

    fs::set_permissions(path, fs::Permissions::from_mode(0o600))
}

#[cfg(not(unix))]
fn set_private_path_permissions(_path: &Path) -> io::Result<()> {
    Ok(())
}

fn sync_parent_dir(parent: &Path) {
    if let Ok(parent_dir) = fs::File::open(parent) {
        let _ = parent_dir.sync_all();
    }
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

pub(crate) fn report_filter_skills(
    skills: Vec<SkillRecord>,
    params: &ReportExportLocalParams,
) -> Vec<SkillRecord> {
    let agent_filter = normalized_optional_filter(params.agent.as_deref());
    let instance_filter = normalized_optional_filter(params.instance_id.as_deref());
    let state_filter = normalized_optional_filter(params.state_filter.as_deref());
    let search_filter = normalized_optional_filter(params.search.as_deref());

    skills
        .into_iter()
        .filter(|skill| {
            agent_filter
                .as_ref()
                .is_none_or(|agent| skill.agent.eq_ignore_ascii_case(agent))
        })
        .filter(|skill| {
            instance_filter
                .as_ref()
                .is_none_or(|instance_id| skill.id.eq_ignore_ascii_case(instance_id))
        })
        .filter(|skill| {
            state_filter
                .as_ref()
                .is_none_or(|state| report_skill_matches_state(skill, state))
        })
        .filter(|skill| {
            search_filter.as_ref().is_none_or(|query| {
                let query = query.to_ascii_lowercase();
                [
                    skill.id.as_str(),
                    skill.name.as_str(),
                    skill.definition_id.as_str(),
                    skill.agent.as_str(),
                    skill.scope.as_str(),
                    &skill.display_path.to_string_lossy(),
                ]
                .iter()
                .any(|value| value.to_ascii_lowercase().contains(&query))
            })
        })
        .collect()
}

pub(crate) fn report_filter_findings(
    findings: Vec<RuleFindingRecord>,
    skills: &[SkillRecord],
) -> Vec<RuleFindingRecord> {
    let instance_ids = skills
        .iter()
        .map(|skill| skill.id.as_str())
        .collect::<BTreeSet<_>>();
    let definition_ids = skills
        .iter()
        .map(|skill| skill.definition_id.as_str())
        .collect::<BTreeSet<_>>();
    findings
        .into_iter()
        .filter(|finding| !finding.suppressed)
        .filter(|finding| finding.triage_status != "ignored")
        .filter(|finding| {
            finding
                .instance_id
                .as_deref()
                .is_some_and(|id| instance_ids.contains(id))
                || finding
                    .definition_id
                    .as_deref()
                    .is_some_and(|id| definition_ids.contains(id))
        })
        .collect()
}

pub(crate) fn report_filter_conflicts(
    conflicts: Vec<ConflictGroupRecord>,
    skills: &[SkillRecord],
) -> Vec<ConflictGroupRecord> {
    let instance_ids = skills
        .iter()
        .map(|skill| skill.id.as_str())
        .collect::<BTreeSet<_>>();
    conflicts
        .into_iter()
        .filter(|conflict| {
            conflict
                .instance_ids
                .iter()
                .any(|id| instance_ids.contains(id.as_str()))
        })
        .collect()
}

pub(crate) fn report_agent_scope(
    params: &ReportExportLocalParams,
    skills: &[SkillRecord],
    catalog_available: bool,
) -> Value {
    let agents = skills
        .iter()
        .map(|skill| skill.agent.as_str())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    json!({
        "agent": normalized_optional_filter(params.agent.as_deref()).unwrap_or_else(|| "all".to_string()),
        "instance_id": normalized_optional_filter(params.instance_id.as_deref()),
        "state_filter": normalized_optional_filter(params.state_filter.as_deref()).unwrap_or_else(|| "all".to_string()),
        "search": normalized_optional_filter(params.search.as_deref()),
        "catalog_available": catalog_available,
        "active_agents": agents,
    })
}

pub(crate) fn report_skill_usage(
    skills: &[SkillRecord],
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
) -> Value {
    let finding_counts = report_finding_counts_by_instance(findings);
    let conflict_counts = report_conflict_counts_by_instance(conflicts);
    let installed = skills
        .iter()
        .map(|skill| {
            let issue_count = finding_counts
                .get(skill.id.as_str())
                .copied()
                .unwrap_or_default()
                + conflict_counts
                    .get(skill.id.as_str())
                    .copied()
                    .unwrap_or_default();
            json!({
                "id": skill.id,
                "name": skill.name,
                "agent": skill.agent,
                "scope": skill.scope,
                "state": skill.state,
                "enabled": skill.enabled,
                "definition_id": skill.definition_id,
                "source_path": skill.display_path,
                "issue_count": issue_count,
                "has_issues": issue_count > 0,
            })
        })
        .collect::<Vec<_>>();
    let enabled_count = skills.iter().filter(|skill| skill.enabled).count();
    let disabled_count = skills.len().saturating_sub(enabled_count);
    let unavailable_count = skills
        .iter()
        .filter(|skill| skill.state != "loaded")
        .count();
    json!({
        "summary": {
            "installed_count": skills.len(),
            "enabled_count": enabled_count,
            "disabled_count": disabled_count,
            "unavailable_count": unavailable_count,
            "with_issues_count": skills.iter().filter(|skill| {
                finding_counts.contains_key(skill.id.as_str())
                    || conflict_counts.contains_key(skill.id.as_str())
            }).count(),
        },
        "installed": installed,
    })
}

pub(crate) fn report_issue_rows(
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    skills: &[SkillRecord],
) -> Value {
    let skill_by_id = skills
        .iter()
        .map(|skill| (skill.id.as_str(), skill))
        .collect::<BTreeMap<_, _>>();
    let skill_by_definition = skills
        .iter()
        .map(|skill| (skill.definition_id.as_str(), skill))
        .collect::<BTreeMap<_, _>>();
    let mut issues = findings
        .iter()
        .map(|finding| {
            let skill = finding
                .instance_id
                .as_deref()
                .and_then(|id| skill_by_id.get(id).copied())
                .or_else(|| {
                    finding
                        .definition_id
                        .as_deref()
                        .and_then(|id| skill_by_definition.get(id).copied())
                });
            json!({
                "kind": "finding",
                "severity": finding.effective_severity,
                "status": finding.triage_status,
                "rule_id": finding.rule_id,
                "title": finding.message,
                "suggestion": finding.suggestion,
                "affected_skill": skill.map(|skill| skill.name.clone()),
                "affected_agent": skill.map(|skill| skill.agent.clone()),
                "instance_id": finding.instance_id,
                "definition_id": finding.definition_id,
            })
        })
        .collect::<Vec<_>>();

    issues.extend(conflicts.iter().map(|conflict| {
        let affected = conflict
            .instance_ids
            .iter()
            .filter_map(|id| skill_by_id.get(id.as_str()).copied())
            .map(|skill| {
                json!({
                    "id": skill.id,
                    "name": skill.name,
                    "agent": skill.agent,
                    "scope": skill.scope,
                })
            })
            .collect::<Vec<_>>();
        json!({
            "kind": "same_agent_conflict",
            "severity": "warn",
            "status": "open",
            "rule_id": "same_agent_conflict",
            "title": format!("Same-agent conflict: {}", conflict.reason),
            "suggestion": "Review duplicate same-agent instances and keep one active route.",
            "definition_id": conflict.definition_id,
            "winner_id": conflict.winner_id,
            "affected_skills": affected,
        })
    }));

    Value::Array(issues)
}

pub(crate) fn report_recommended_usage(skills: &[SkillRecord], issues: &Value) -> Value {
    let issue_counts = report_issue_counts_by_instance(issues);
    let issue_instance_ids = issue_counts
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let mut ready = Vec::new();
    let mut review_first = Vec::new();
    let mut unavailable = Vec::new();
    for skill in skills {
        let issue_count = issue_counts
            .get(skill.id.as_str())
            .copied()
            .unwrap_or_default();
        let item = json!({
            "id": skill.id,
            "name": skill.name,
            "agent": skill.agent,
            "scope": skill.scope,
            "state": skill.state,
            "issue_count": issue_count,
        });
        if !skill.enabled || skill.state != "loaded" {
            unavailable.push(item);
        } else if issue_instance_ids.contains(skill.id.as_str()) {
            review_first.push(item);
        } else {
            ready.push(item);
        }
    }
    ready.truncate(25);
    review_first.truncate(25);
    unavailable.truncate(25);
    json!({
        "ready_to_use": ready,
        "review_before_use": review_first,
        "not_recommended_now": unavailable,
        "note": "Recommendations are derived from local catalog state and issue rows only; they do not call a provider or execute skills.",
    })
}

fn report_issue_counts_by_instance(issues: &Value) -> BTreeMap<String, usize> {
    let mut counts = BTreeMap::new();
    let Some(items) = issues.as_array() else {
        return counts;
    };
    for issue in items {
        if let Some(instance_id) = issue.get("instance_id").and_then(Value::as_str) {
            *counts.entry(instance_id.to_string()).or_insert(0) += 1;
        }
        if let Some(affected_skills) = issue.get("affected_skills").and_then(Value::as_array) {
            for skill in affected_skills {
                if let Some(instance_id) = skill.get("id").and_then(Value::as_str) {
                    *counts.entry(instance_id.to_string()).or_insert(0) += 1;
                }
            }
        }
    }
    counts
}

pub(crate) fn report_task_preflight() -> Value {
    json!({
        "available": false,
        "status": "not_exported",
        "summary": "No task Preflight result is persisted into this local report yet. Run Task Preflight in the Agent Workspace to inspect a task-specific route before using an agent or skill.",
    })
}

pub(crate) fn report_analysis_results(
    health: &Value,
    analysis: &Value,
    _cleanup: &Value,
    _comparison: &Value,
) -> Value {
    let total_analysis_groups = analysis
        .pointer("/summary/total_groups")
        .and_then(Value::as_u64)
        .unwrap_or_default();
    Value::Array(vec![
        json!({
            "kind": "local_health",
            "title": "Local skill health",
            "status": "derived",
            "summary": {
                "total": health.get("total_count").cloned().unwrap_or(Value::Null),
                "enabled": health.get("enabled_count").cloned().unwrap_or(Value::Null),
                "disabled": health.get("disabled_count").cloned().unwrap_or(Value::Null),
                "issues": health.get("finding_count").cloned().unwrap_or(Value::Null),
                "conflicts": health.get("conflict_count").cloned().unwrap_or(Value::Null),
            }
        }),
        json!({
            "kind": "local_catalog_analysis",
            "title": "Local catalog analysis",
            "status": if total_analysis_groups > 0 { "review" } else { "clear" },
            "summary": format!("{total_analysis_groups} derived analysis group(s).")
        }),
    ])
}

pub(crate) fn report_usage_summary(
    skills: &[SkillRecord],
    issues: &Value,
    conflicts: &[ConflictGroupRecord],
    analysis_results: &Value,
) -> Value {
    let issue_count = issues.as_array().map(Vec::len).unwrap_or_default();
    json!({
        "skill_count": skills.len(),
        "enabled_skill_count": skills.iter().filter(|skill| skill.enabled).count(),
        "disabled_skill_count": skills.iter().filter(|skill| !skill.enabled).count(),
        "issue_count": issue_count,
        "conflict_count": conflicts.len(),
        "analysis_result_count": analysis_results.as_array().map(Vec::len).unwrap_or_default(),
    })
}

pub(crate) fn report_usage_sections(summary: &Value) -> Vec<ReportExportSection> {
    vec![
        ReportExportSection {
            name: "current_state",
            count: 1,
        },
        ReportExportSection {
            name: "installed_skills",
            count: report_summary_count(summary, "skill_count"),
        },
        ReportExportSection {
            name: "issues",
            count: report_summary_count(summary, "issue_count"),
        },
        ReportExportSection {
            name: "task_preflight",
            count: 1,
        },
        ReportExportSection {
            name: "analysis_results",
            count: report_summary_count(summary, "analysis_result_count"),
        },
        ReportExportSection {
            name: "safety",
            count: 1,
        },
    ]
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
    redact_with_count(value, roots).0
}

pub(crate) fn render_report_markdown(report: &Value) -> String {
    let summary = report.get("summary").unwrap_or(&Value::Null);
    let safety = report.get("safety").unwrap_or(&Value::Null);
    let agent = report.get("agent").unwrap_or(&Value::Null);
    let skills = report.get("skills").unwrap_or(&Value::Null);
    let issues = report.get("issues").unwrap_or(&Value::Null);
    let recommended = report.get("recommended_usage").unwrap_or(&Value::Null);
    let preflight = report.get("task_preflight").unwrap_or(&Value::Null);
    let analysis_results = report.get("analysis_results").unwrap_or(&Value::Null);
    let mut markdown = String::new();
    markdown.push_str("# Agent Copilot Agent Usage Report\n\n");
    markdown.push_str(&format!(
        "- Export ID: {}\n",
        report_string(report, "/export_id")
    ));
    markdown.push_str(&format!(
        "- Generated at: {}\n",
        report_timestamp_label(report.pointer("/generated_at"))
    ));
    markdown.push_str(&format!(
        "- Catalog available: {}\n\n",
        report_string(report, "/catalog_available")
    ));
    markdown.push_str("## 1. Current State\n\n");
    markdown.push_str(&format!(
        "- Agent scope: {}\n- Active agents in export: {}\n- Skills: {}\n- Enabled skills: {}\n- Skills with issues: {}\n- Issues: {}\n\n",
        json_field_string(agent, "agent"),
        markdown_array_label(agent.pointer("/active_agents")),
        json_field_string(summary, "skill_count"),
        json_field_string(summary, "enabled_skill_count"),
        report_string(skills, "/summary/with_issues_count"),
        json_field_string(summary, "issue_count")
    ));

    markdown.push_str("## 2. Installed Skills\n\n");
    markdown.push_str(&format!(
        "- Installed: {}\n- Enabled: {}\n- Disabled: {}\n- Unavailable: {}\n\n",
        report_string(skills, "/summary/installed_count"),
        report_string(skills, "/summary/enabled_count"),
        report_string(skills, "/summary/disabled_count"),
        report_string(skills, "/summary/unavailable_count")
    ));
    markdown_skill_rows(&mut markdown, skills.pointer("/installed"));

    markdown.push_str("\n## 3. Recommended Use\n\n");
    markdown.push_str("### Ready to use\n\n");
    markdown_skill_rows(&mut markdown, recommended.pointer("/ready_to_use"));
    markdown.push_str("\n### Review before use\n\n");
    markdown_skill_rows(&mut markdown, recommended.pointer("/review_before_use"));
    markdown.push_str("\n### Not recommended now\n\n");
    markdown_skill_rows(&mut markdown, recommended.pointer("/not_recommended_now"));

    markdown.push_str("\n## 4. Issues\n\n");
    markdown_issue_rows(&mut markdown, issues);

    markdown.push_str("\n## 5. Task Preflight\n\n");
    markdown.push_str(&format!(
        "- Status: {}\n- Summary: {}\n\n",
        json_field_string(preflight, "status"),
        json_field_string(preflight, "summary")
    ));

    markdown.push_str("## 6. Intelligent Analysis\n\n");
    markdown_analysis_rows(&mut markdown, analysis_results);

    markdown.push_str("\n## 7. Local Safety Boundary\n\n");
    markdown.push_str(&format!(
        "- Read-only: {}\n- Writes allowed: {}\n- Provider request sent: {}\n- Script execution allowed: {}\n- Credential accessed: {}\n- Redaction: local path prefixes are replaced with `$HOME`, `<project-root>`, `<project-cwd>`, or `<app-data-dir>` before report files are written.\n",
        json_field_string(safety, "read_only"),
        json_field_string(safety, "writes_allowed"),
        json_field_string(safety, "provider_request_sent"),
        json_field_string(safety, "script_execution_allowed"),
        json_field_string(safety, "credential_accessed")
    ));
    markdown
}

fn normalized_optional_filter(value: Option<&str>) -> Option<String> {
    value
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .filter(|value| !value.eq_ignore_ascii_case("all"))
        .map(ToOwned::to_owned)
}

fn report_skill_matches_state(skill: &SkillRecord, state: &str) -> bool {
    if state.eq_ignore_ascii_case("enabled") {
        return skill.enabled;
    }
    if state.eq_ignore_ascii_case("disabled") {
        return !skill.enabled;
    }
    skill.state.eq_ignore_ascii_case(state)
}

fn report_finding_counts_by_instance(findings: &[RuleFindingRecord]) -> BTreeMap<&str, usize> {
    let mut counts = BTreeMap::new();
    for finding in findings {
        if let Some(instance_id) = finding.instance_id.as_deref() {
            *counts.entry(instance_id).or_insert(0) += 1;
        }
    }
    counts
}

fn report_conflict_counts_by_instance(conflicts: &[ConflictGroupRecord]) -> BTreeMap<&str, usize> {
    let mut counts = BTreeMap::new();
    for conflict in conflicts {
        for instance_id in &conflict.instance_ids {
            *counts.entry(instance_id.as_str()).or_insert(0) += 1;
        }
    }
    counts
}

fn report_summary_count(summary: &Value, key: &str) -> usize {
    summary
        .get(key)
        .and_then(Value::as_u64)
        .and_then(|value| usize::try_from(value).ok())
        .unwrap_or_default()
}

fn markdown_array_label(value: Option<&Value>) -> String {
    value
        .and_then(Value::as_array)
        .map(|items| {
            if items.is_empty() {
                "none".to_string()
            } else {
                items
                    .iter()
                    .map(value_to_markdown_string)
                    .collect::<Vec<_>>()
                    .join(", ")
            }
        })
        .unwrap_or_else(|| "none".to_string())
}

fn markdown_skill_rows(markdown: &mut String, value: Option<&Value>) {
    let Some(items) = value.and_then(Value::as_array) else {
        markdown.push_str("- None.\n");
        return;
    };
    if items.is_empty() {
        markdown.push_str("- None.\n");
        return;
    }
    for item in items.iter().take(25) {
        let issue_count = item
            .get("issue_count")
            .and_then(Value::as_u64)
            .unwrap_or_default();
        let issue_note = if issue_count > 0 {
            format!(", issues: {issue_count}")
        } else {
            String::new()
        };
        markdown.push_str(&format!(
            "- {} — {} / {} / {}{}\n",
            report_string(item, "/name"),
            report_string(item, "/agent"),
            report_string(item, "/scope"),
            report_string(item, "/state"),
            issue_note
        ));
    }
    if items.len() > 25 {
        markdown.push_str(&format!(
            "- ... {} more in JSON export.\n",
            items.len() - 25
        ));
    }
}

fn markdown_issue_rows(markdown: &mut String, value: &Value) {
    let Some(items) = value.as_array() else {
        markdown.push_str("- No issue rows.\n");
        return;
    };
    if items.is_empty() {
        markdown.push_str("- No issue rows.\n");
        return;
    }
    let mut grouped = BTreeMap::<(String, String, String), usize>::new();
    for item in items {
        let key = (
            report_string(item, "/severity"),
            report_string(item, "/title"),
            report_string(item, "/suggestion"),
        );
        *grouped.entry(key).or_insert(0) += 1;
    }
    for ((severity, title, suggestion), count) in grouped.iter().take(30) {
        let count_label = if *count > 1 {
            format!(" ({count} occurrences)")
        } else {
            String::new()
        };
        markdown.push_str(&format!(
            "- [{}] {}{} — {}\n",
            severity, title, count_label, suggestion
        ));
    }
    if grouped.len() > 30 {
        markdown.push_str(&format!(
            "- ... {} more issue groups in JSON export.\n",
            grouped.len() - 30
        ));
    }
}

fn markdown_analysis_rows(markdown: &mut String, value: &Value) {
    let Some(items) = value.as_array() else {
        markdown.push_str("- No analysis result rows.\n");
        return;
    };
    if items.is_empty() {
        markdown.push_str("- No analysis result rows.\n");
        return;
    }
    for item in items {
        markdown.push_str(&format!(
            "- {}: {} ({})\n",
            report_string(item, "/title"),
            report_string(item, "/summary"),
            report_string(item, "/status")
        ));
    }
}

pub(crate) fn report_string(value: &Value, pointer: &str) -> String {
    value
        .pointer(pointer)
        .map(value_to_markdown_string)
        .unwrap_or_else(|| "n/a".to_string())
}

fn report_timestamp_label(value: Option<&Value>) -> String {
    let Some(millis) = value.and_then(Value::as_i64) else {
        return "n/a".to_string();
    };
    match OffsetDateTime::from_unix_timestamp_nanos(i128::from(millis) * 1_000_000) {
        Ok(timestamp) => match timestamp.format(&Rfc3339) {
            Ok(formatted) => format!("{formatted} ({millis} ms since Unix epoch)"),
            Err(_) => format!("{millis} ms since Unix epoch"),
        },
        Err(_) => format!("{millis} ms since Unix epoch"),
    }
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
    for placeholder in ["$HOME", "<project-root>", "<project-cwd>", "<app-data-dir>"] {
        redacted = redacted.replace(&format!("{placeholder}\\"), &format!("{placeholder}/"));
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
    let Ok(url) = Url::parse(base_url) else {
        return "<unknown>".to_string();
    };
    let Some(host) = url.host_str() else {
        return "<unknown>".to_string();
    };
    let host = if host.contains(':') {
        format!("[{host}]")
    } else {
        host.to_string()
    };
    match url.port() {
        Some(port) => format!("{host}:{port}"),
        None => host,
    }
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
