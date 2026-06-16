fn remediation_plan_safety_flags() -> RemediationPlanSafetyFlags {
    agent_readiness_safety_flags()
}

fn remediation_preview_drafts_safety_flags() -> RemediationPreviewDraftsSafetyFlags {
    agent_readiness_safety_flags()
}

fn remediation_preview_impact_safety_flags() -> RemediationPreviewImpactSafetyFlags {
    agent_readiness_safety_flags()
}

fn remediation_batch_review_safety_flags() -> RemediationBatchReviewSafetyFlags {
    agent_readiness_safety_flags()
}

fn remediation_plan_filters(
    params: &RemediationPlanParams,
    redaction_roots: &[(String, &'static str)],
) -> RemediationPlanFilters {
    let mut focus_areas = Vec::new();
    if let Some(focus) = params.focus.as_deref() {
        focus_areas.extend(
            focus
                .split([',', ';'])
                .filter_map(normalize_remediation_focus),
        );
    }
    focus_areas.extend(
        params
            .focus_areas
            .iter()
            .filter_map(|focus| normalize_remediation_focus(focus)),
    );
    focus_areas.sort();
    focus_areas.dedup();
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();

    RemediationPlanFilters {
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        task: params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(redact_for_llm_preview),
        project_root: params
            .project_root
            .as_deref()
            .map(str::trim)
            .filter(|path| !path.is_empty())
            .map(|path| redact_string(&redact_for_llm_preview(path), redaction_roots)),
        focus_areas,
        limit: params.limit.unwrap_or(12).clamp(1, 50),
        candidate_instance_ids,
        include_deferred: params.include_deferred,
    }
}

fn normalize_remediation_focus(focus: &str) -> Option<String> {
    let normalized = focus.trim().to_ascii_lowercase().replace(['_', ' '], "-");
    let canonical = match normalized.as_str() {
        "" => return None,
        "finding" | "findings" | "rule" | "rules" => "finding",
        "gap" | "gaps" | "coverage" | "capability-gap" => "gap",
        "ambiguity" | "routing" | "routing-ambiguity" | "conflict" | "conflicts" => "ambiguity",
        "drift" | "stale" | "stale-drift" => "drift",
        "readiness" | "workspace" | "workspace-readiness" | "task-readiness" => "readiness",
        "policy" | "cleanup" | "queue" => "policy",
        other => other,
    };
    Some(canonical.to_string())
}

fn empty_remediation_plan_result(
    filters: RemediationPlanFilters,
    catalog_available: bool,
) -> RemediationPlanResult {
    RemediationPlanResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters: filters.clone(),
        summary: RemediationPlanSummary {
            total_item_count: 0,
            returned_item_count: 0,
            high_priority_count: 0,
            medium_priority_count: 0,
            low_priority_count: 0,
            deferred_count: 0,
            finding_item_count: 0,
            gap_item_count: 0,
            ambiguity_item_count: 0,
            drift_item_count: 0,
            readiness_item_count: 0,
            policy_item_count: 0,
            blocker_count: 1,
            summary:
                "No local catalog is available, so remediation planning has no evidence."
                    .to_string(),
        },
        plan_items: Vec::new(),
        priority_rows: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on remediation planning.".to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: RemediationPlanPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "remediation_plan",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RemediationPlan,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic remediation plan items using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        aggregation: empty_aggregation_runtime(
            REMEDIATION_AGGREGATION_TIMEOUT_MS,
            filters.limit,
            "remediation.plan",
            "No local catalog was available; remediation planning returned an empty read-only result.",
        ),
        safety_flags: remediation_plan_safety_flags(),
    }
}

struct RemediationItemInput {
    category: &'static str,
    priority_score: u8,
    severity: &'static str,
    title: String,
    summary: String,
    detail: String,
    affected_agent: Option<String>,
    affected_skill: Option<RemediationAffectedSkill>,
    affected_capability: Option<String>,
    affected_task: Option<String>,
    affected_instance_ids: Vec<String>,
    suggested_safe_next_action: String,
    prerequisites: Vec<String>,
    blockers: Vec<String>,
    deferred: bool,
    evidence_refs: Vec<String>,
}

fn remediation_item(input: RemediationItemInput) -> RemediationPlanItem {
    let mut affected_instance_ids = input
        .affected_instance_ids
        .into_iter()
        .map(|id| redact_for_llm_preview(&id))
        .collect::<Vec<_>>();
    affected_instance_ids.sort();
    affected_instance_ids.dedup();
    let id = stable_remediation_item_id(
        input.category,
        &input.title,
        &affected_instance_ids,
        &input.evidence_refs,
    );
    RemediationPlanItem {
        id,
        rank: 0,
        priority: remediation_priority_for_score(input.priority_score),
        severity: input.severity,
        category: input.category,
        title: input.title,
        summary: input.summary,
        detail: input.detail,
        affected_agent: input.affected_agent,
        affected_skill: input.affected_skill,
        affected_capability: input.affected_capability,
        affected_task: input.affected_task,
        affected_instance_ids,
        suggested_safe_next_action: input.suggested_safe_next_action,
        prerequisites: input.prerequisites,
        blockers: input.blockers,
        deferred: input.deferred,
        evidence_refs: input.evidence_refs,
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_plan_safety_flags(),
    }
}

fn remediation_insert_evidence(
    evidence_by_id: &mut BTreeMap<String, TaskReadinessEvidenceReference>,
    source_type: &'static str,
    source_id: &str,
    label: String,
    severity: Option<String>,
    related_instance_id: Option<String>,
) -> String {
    let id = format!("{source_type}:{source_id}");
    evidence_by_id
        .entry(id.clone())
        .or_insert_with(|| TaskReadinessEvidenceReference {
            id: id.clone(),
            source_type,
            source_id: redact_for_llm_preview(source_id),
            label,
            severity,
            related_instance_id,
        });
    id
}

fn remediation_affected_skill(skill: &SkillDetailRecord) -> RemediationAffectedSkill {
    RemediationAffectedSkill {
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.clone(),
        scope: skill.scope.clone(),
        enabled: skill.enabled,
        state: skill.state.clone(),
    }
}

fn remediation_related_instances_for_finding(
    finding: &RuleFindingRecord,
    visible_skill_ids: &BTreeSet<&str>,
) -> Vec<String> {
    finding
        .instance_id
        .iter()
        .filter(|id| visible_skill_ids.contains(id.as_str()))
        .cloned()
        .collect()
}

fn remediation_matches_filter(
    filters: &RemediationPlanFilters,
    instance_id: Option<&str>,
    affected_instance_ids: &[String],
) -> bool {
    let id_matches = filters.candidate_instance_ids.is_empty()
        || instance_id.is_some_and(|id| {
            filters
                .candidate_instance_ids
                .iter()
                .any(|candidate| candidate == id)
        })
        || affected_instance_ids.iter().any(|id| {
            filters
                .candidate_instance_ids
                .iter()
                .any(|candidate| candidate == id)
        });
    id_matches
}

fn remediation_focus_matches(filters: &RemediationPlanFilters, category: &str) -> bool {
    filters.focus_areas.is_empty()
        || filters
            .focus_areas
            .iter()
            .any(|focus| focus == category || (focus == "readiness" && category == "gap"))
}

fn remediation_score_for_severity(severity: &str) -> u8 {
    match severity {
        "critical" => 100,
        "error" => 90,
        "warning" | "warn" => 72,
        "info" => 42,
        _ => 35,
    }
}

fn remediation_score_for_priority(priority: &str) -> u8 {
    match priority {
        "high" => 86,
        "medium" => 62,
        "low" => 34,
        _ => 30,
    }
}

fn remediation_priority_for_score(score: u8) -> &'static str {
    match score {
        75..=100 => "high",
        45..=74 => "medium",
        _ => "low",
    }
}

fn remediation_severity(severity: &str) -> &'static str {
    match severity {
        "critical" => "critical",
        "error" => "error",
        "warning" | "warn" => "warning",
        "info" => "info",
        _ => "info",
    }
}

fn remediation_blockers_for_finding(finding: &RuleFindingRecord) -> Vec<String> {
    let mut blockers = Vec::new();
    if matches!(finding.effective_severity.as_str(), "critical" | "error") {
        blockers.push("High-severity local finding requires human review.".to_string());
    }
    if finding.suppressed {
        blockers.push("Finding is suppressed; verify suppression before acting.".to_string());
    }
    if !matches!(finding.triage_status.as_str(), "open" | "needs-follow-up") {
        blockers.push(format!(
            "Finding triage status is `{}`.",
            redact_for_llm_preview(&finding.triage_status)
        ));
    }
    blockers
}

fn remediation_side_effect_flags() -> Vec<&'static str> {
    vec![
        "provider_request_sent=false",
        "write_back_allowed=false",
        "write_actions_available=false",
        "skill_files_mutated=false",
        "agent_config_mutated=false",
        "script_execution_allowed=false",
        "snapshot_created=false",
        "triage_mutation_allowed=false",
        "credential_accessed=false",
        "cloud_sync_performed=false",
        "telemetry_emitted=false",
    ]
}

fn stable_remediation_item_id(
    category: &str,
    title: &str,
    affected_instance_ids: &[String],
    evidence_refs: &[String],
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(category.as_bytes());
    hasher.update(b"\0");
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    for id in affected_instance_ids {
        hasher.update(id.as_bytes());
        hasher.update(b"\0");
    }
    for evidence in evidence_refs {
        hasher.update(evidence.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("remediation-{}", hex_prefix(&digest, 12))
}

fn remediation_sorted_items(
    mut items: Vec<RemediationPlanItem>,
    filters: &RemediationPlanFilters,
) -> Vec<RemediationPlanItem> {
    items.retain(|item| filters.include_deferred || !item.deferred);
    items.retain(|item| remediation_focus_matches(filters, item.category));
    items.sort_by(|left, right| {
        remediation_priority_rank(left.priority)
            .cmp(&remediation_priority_rank(right.priority))
            .then_with(|| {
                severity_rank_for_queue(left.severity).cmp(&severity_rank_for_queue(right.severity))
            })
            .then_with(|| left.deferred.cmp(&right.deferred))
            .then_with(|| left.category.cmp(right.category))
            .then_with(|| left.title.cmp(&right.title))
            .then_with(|| left.id.cmp(&right.id))
    });
    items.truncate(filters.limit);
    for (index, item) in items.iter_mut().enumerate() {
        item.rank = index + 1;
    }
    items
}

fn remediation_priority_rank(priority: &str) -> u8 {
    match priority {
        "high" => 0,
        "medium" => 1,
        "low" => 2,
        _ => 3,
    }
}

fn remediation_plan_summary(
    total_item_count: usize,
    returned_item_count: usize,
    items: &[RemediationPlanItem],
) -> RemediationPlanSummary {
    let high_priority_count = items.iter().filter(|item| item.priority == "high").count();
    let medium_priority_count = items
        .iter()
        .filter(|item| item.priority == "medium")
        .count();
    let low_priority_count = items.iter().filter(|item| item.priority == "low").count();
    let deferred_count = items.iter().filter(|item| item.deferred).count();
    let category_count = |category: &str| {
        items
            .iter()
            .filter(|item| item.category == category)
            .count()
    };
    let blocker_count = items.iter().map(|item| item.blockers.len()).sum();
    let summary = if returned_item_count == 0 {
        "No remediation plan items matched the selected local filters.".to_string()
    } else {
        format!(
            "Remediation planner returned {returned_item_count} of {total_item_count} local read-only item(s): {high_priority_count} high, {medium_priority_count} medium, {low_priority_count} low."
        )
    };
    RemediationPlanSummary {
        total_item_count,
        returned_item_count,
        high_priority_count,
        medium_priority_count,
        low_priority_count,
        deferred_count,
        finding_item_count: category_count("finding"),
        gap_item_count: category_count("gap"),
        ambiguity_item_count: category_count("ambiguity"),
        drift_item_count: category_count("drift"),
        readiness_item_count: category_count("readiness"),
        policy_item_count: category_count("policy"),
        blocker_count,
        summary,
    }
}

fn remediation_priority_rows(items: &[RemediationPlanItem]) -> Vec<RemediationPriorityRow> {
    let mut rows = Vec::new();
    for priority in ["high", "medium", "low"] {
        let matching = items
            .iter()
            .filter(|item| item.priority == priority)
            .collect::<Vec<_>>();
        if matching.is_empty() {
            continue;
        }
        let mut category_counts = BTreeMap::new();
        for item in &matching {
            *category_counts
                .entry(item.category.to_string())
                .or_insert(0) += 1;
        }
        rows.push(RemediationPriorityRow {
            priority,
            severity: matching
                .iter()
                .map(|item| item.severity)
                .min_by_key(|severity| severity_rank_for_queue(severity))
                .unwrap_or("info"),
            item_count: matching.len(),
            category_counts,
            top_item_ids: matching
                .iter()
                .take(5)
                .map(|item| item.id.clone())
                .collect(),
        });
    }
    rows
}

fn remediation_preview_drafts_filters(
    params: &RemediationPreviewDraftsParams,
    redaction_roots: &[(String, &'static str)],
) -> RemediationPreviewDraftsFilters {
    let mut skill_ids = params
        .skill_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    skill_ids.sort();
    skill_ids.dedup();
    let mut finding_ids = params
        .finding_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    finding_ids.sort();
    finding_ids.dedup();
    let mut draft_types = params
        .draft_types
        .iter()
        .filter_map(|value| normalize_remediation_draft_type(value))
        .collect::<Vec<_>>();
    draft_types.sort();
    draft_types.dedup();
    RemediationPreviewDraftsFilters {
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        task: params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| redact_string(&redact_for_llm_preview(task), redaction_roots)),
        skill_ids,
        finding_ids,
        draft_types,
        limit: params.limit.unwrap_or(12).clamp(1, 50),
        include_policy_drafts: params.include_policy_drafts,
    }
}

fn normalize_remediation_draft_type(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase().replace(['_', ' '], "-");
    let canonical = match normalized.as_str() {
        "" => return None,
        "frontmatter" | "metadata" | "yaml" => "frontmatter",
        "description" | "body" | "summary" => "description",
        "permissions" | "permission" | "allowed-tools" | "tool" | "tools" => "permissions",
        "dependency" | "dependencies" | "dep" | "deps" => "dependency",
        "policy" | "governance" | "routing-policy" => "policy",
        other => other,
    };
    Some(canonical.to_string())
}

fn remediation_preview_draft_type_matches(
    filters: &RemediationPreviewDraftsFilters,
    draft_type: &str,
) -> bool {
    filters.draft_types.is_empty() || filters.draft_types.iter().any(|value| value == draft_type)
}

fn empty_remediation_preview_drafts_result(
    filters: RemediationPreviewDraftsFilters,
    catalog_available: bool,
) -> RemediationPreviewDraftsResult {
    RemediationPreviewDraftsResult {
        generated_by: "local-v2.57",
        catalog_available,
        filters: filters.clone(),
        summary: RemediationPreviewDraftsSummary {
            total_draft_count: 0,
            returned_draft_count: 0,
            frontmatter_count: 0,
            description_count: 0,
            permissions_count: 0,
            dependency_count: 0,
            policy_count: 0,
            high_confidence_count: 0,
            medium_confidence_count: 0,
            low_confidence_count: 0,
            blocker_count: 1,
            summary: "No local catalog is available, so fix preview drafts have no evidence."
                .to_string(),
        },
        draft_items: Vec::new(),
        gap_notes: vec!["Run a local scan before relying on fix preview drafts.".to_string()],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: RemediationPreviewDraftsPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "remediation_preview_drafts",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RemediationPreviewDrafts,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic fix preview drafts using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: remediation_preview_drafts_safety_flags(),
    }
}

fn remediation_preview_impact_filters(
    params: &RemediationPreviewImpactParams,
    redaction_roots: &[(String, &'static str)],
) -> RemediationPreviewImpactFilters {
    let skill_ids = normalized_redacted_ids(&params.skill_ids);
    let candidate_instance_ids = normalized_redacted_ids(&params.candidate_instance_ids);
    let draft_ids = normalized_redacted_ids(&params.draft_ids);
    let plan_item_ids = normalized_redacted_ids(&params.plan_item_ids);
    RemediationPreviewImpactFilters {
        action: normalize_remediation_impact_action(params.action.as_deref()),
        task: params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| redact_string(&redact_for_llm_preview(task), redaction_roots)),
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        project_root: params
            .project_root
            .as_deref()
            .map(str::trim)
            .filter(|path| !path.is_empty())
            .map(|path| redact_string(&redact_for_llm_preview(path), redaction_roots)),
        skill_ids,
        candidate_instance_ids,
        draft_ids,
        plan_item_ids,
        limit: params.limit.unwrap_or(12).clamp(1, 50),
        include_snapshot_plan: params.include_snapshot_plan,
        include_rollback_plan: params.include_rollback_plan,
        include_risk_impact: params.include_risk_impact || params.action.as_deref().is_none(),
        include_task_impact: params.include_task_impact || params.task.is_some(),
    }
}

fn normalized_redacted_ids(values: &[String]) -> Vec<String> {
    let mut ids = values
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    ids.sort();
    ids.dedup();
    ids
}

fn normalize_remediation_impact_action(action: Option<&str>) -> String {
    match action
        .unwrap_or("review")
        .trim()
        .to_ascii_lowercase()
        .replace(['_', ' '], "-")
        .as_str()
    {
        "enable" | "on" => "enable",
        "disable" | "off" => "disable",
        "edit" | "draft" => "edit",
        "remediate" | "fix" => "remediate",
        _ => "review",
    }
    .to_string()
}

fn empty_remediation_preview_impact_result(
    filters: RemediationPreviewImpactFilters,
    catalog_available: bool,
) -> RemediationPreviewImpactResult {
    RemediationPreviewImpactResult {
        generated_by: "local-v2.58",
        catalog_available,
        filters: filters.clone(),
        summary: RemediationPreviewImpactSummary {
            total_impact_count: 0,
            returned_impact_count: 0,
            task_impact_count: 0,
            agent_impact_count: 0,
            skill_impact_count: 0,
            risk_delta_count: 0,
            snapshot_plan_count: 0,
            rollback_plan_count: 0,
            blocker_count: 1,
            summary: "No local catalog is available, so impact preview has no evidence."
                .to_string(),
        },
        impact_rows: Vec::new(),
        task_impact_rows: Vec::new(),
        agent_impact_rows: Vec::new(),
        skill_impact_rows: Vec::new(),
        risk_delta_rows: Vec::new(),
        snapshot_rollback_plan_rows: Vec::new(),
        gap_notes: vec!["Run a local scan before relying on impact preview.".to_string()],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: RemediationPreviewImpactPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "remediation_preview_impact",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RemediationPreviewImpact,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic remediation impact preview using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: remediation_preview_impact_safety_flags(),
    }
}

fn remediation_batch_review_filters(
    params: &RemediationBatchReviewParams,
    redaction_roots: &[(String, &'static str)],
) -> RemediationBatchReviewFilters {
    let mut group_by = params
        .group_by
        .iter()
        .filter_map(|value| normalize_batch_review_group_by(value))
        .collect::<Vec<_>>();
    if group_by.is_empty() {
        group_by.extend([
            "risk".to_string(),
            "rule".to_string(),
            "agent".to_string(),
            "workspace".to_string(),
            "task".to_string(),
        ]);
    }
    group_by.sort();
    group_by.dedup();
    RemediationBatchReviewFilters {
        task: params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| redact_string(&redact_for_llm_preview(task), redaction_roots)),
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        project_root: params
            .project_root
            .as_deref()
            .map(str::trim)
            .filter(|path| !path.is_empty())
            .map(|path| redact_string(&redact_for_llm_preview(path), redaction_roots)),
        workspace_label: params
            .workspace_label
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(redact_for_llm_preview),
        rule_id: params
            .rule_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(redact_for_llm_preview),
        severity: params
            .severity
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| remediation_severity(value).to_string()),
        status: params
            .status
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase().replace(['_', ' '], "-")),
        triage_status: params
            .triage_status
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase().replace(['_', ' '], "-")),
        candidate_instance_ids: normalized_redacted_ids(&params.candidate_instance_ids),
        group_by,
        limit: params.limit.unwrap_or(24).clamp(1, 100),
    }
}

fn normalize_batch_review_group_by(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase().replace(['_', ' '], "-");
    let canonical = match normalized.as_str() {
        "" => return None,
        "task" | "tasks" => "task",
        "risk" | "severity" | "priority" => "risk",
        "rule" | "rules" | "rule-id" => "rule",
        "agent" | "agents" => "agent",
        "workspace" | "project" | "project-root" => "workspace",
        "status" | "triage" | "triage-status" => "status",
        other => other,
    };
    Some(canonical.to_string())
}

fn empty_remediation_batch_review_result(
    filters: RemediationBatchReviewFilters,
    catalog_available: bool,
) -> RemediationBatchReviewResult {
    RemediationBatchReviewResult {
        generated_by: "local-v2.59",
        catalog_available,
        filters: filters.clone(),
        summary: RemediationBatchReviewSummary {
            total_item_count: 0,
            returned_item_count: 0,
            group_count: 0,
            high_risk_count: 0,
            medium_risk_count: 0,
            low_risk_count: 0,
            task_group_count: 0,
            agent_group_count: 0,
            workspace_group_count: 0,
            rule_group_count: 0,
            blocker_count: 1,
            summary: "No local catalog is available, so batch review has no evidence.".to_string(),
        },
        review_groups: Vec::new(),
        review_items: Vec::new(),
        recommended_next_step_labels: Vec::new(),
        gap_notes: vec!["Run a local scan before relying on batch review.".to_string()],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: RemediationBatchReviewPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "remediation_batch_review",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RemediationBatchReview,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic batch review workflow items using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        aggregation: empty_aggregation_runtime(
            REMEDIATION_AGGREGATION_TIMEOUT_MS,
            filters.limit,
            "remediation.batchReview",
            "No local catalog was available; batch review returned an empty read-only result.",
        ),
        safety_flags: remediation_batch_review_safety_flags(),
    }
}

fn remediation_batch_review_item_from_plan(
    item: &RemediationPlanItem,
    filters: &RemediationBatchReviewFilters,
    detail_by_id: &BTreeMap<&str, &SkillDetailRecord>,
) -> RemediationBatchReviewItem {
    let affected_skill = item.affected_skill.clone().or_else(|| {
        item.affected_instance_ids
            .first()
            .and_then(|id| detail_by_id.get(id.as_str()).copied())
            .map(remediation_affected_skill)
    });
    RemediationBatchReviewItem {
        id: format!("batch-review:plan:{}", item.id),
        rank: 0,
        source: "remediation_plan",
        source_id: item.id.clone(),
        title: redact_for_llm_preview(&item.title),
        summary: redact_for_llm_preview(&item.summary),
        risk: remediation_risk_band(item.severity),
        severity: item.severity.to_string(),
        status: if item.deferred {
            "deferred".to_string()
        } else {
            "open".to_string()
        },
        triage_status: None,
        rule_id: if item.category == "finding" {
            remediation_rule_id_from_plan_item(item)
        } else {
            Some(item.category.to_string())
        },
        task: item.affected_task.clone().or_else(|| filters.task.clone()),
        agent: item.affected_agent.clone(),
        workspace: filters
            .workspace_label
            .clone()
            .or_else(|| filters.project_root.clone()),
        affected_skill,
        affected_instance_ids: item.affected_instance_ids.clone(),
        recommended_next_step_label: redact_for_llm_preview(&item.suggested_safe_next_action),
        blocker_notes: redacted_string_vec(&item.blockers),
        gap_notes: redacted_string_vec(&item.prerequisites),
        evidence_refs: item.evidence_refs.clone(),
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_batch_review_safety_flags(),
    }
}

fn remediation_batch_review_item_from_draft(
    item: &RemediationDraftItem,
    filters: &RemediationBatchReviewFilters,
) -> RemediationBatchReviewItem {
    let affected_instance_ids = item
        .affected_skill
        .as_ref()
        .map(|skill| vec![skill.instance_id.clone()])
        .unwrap_or_default();
    RemediationBatchReviewItem {
        id: format!("batch-review:draft:{}", item.id),
        rank: 0,
        source: "fix_preview_draft",
        source_id: item.id.clone(),
        title: redact_for_llm_preview(&item.title),
        summary: redact_for_llm_preview(&item.rationale),
        risk: remediation_risk_for_confidence(item.confidence),
        severity: remediation_severity_for_confidence(item.confidence).to_string(),
        status: "copy-only".to_string(),
        triage_status: None,
        rule_id: item.rule_id.clone(),
        task: filters.task.clone(),
        agent: item.agent.clone(),
        workspace: filters
            .workspace_label
            .clone()
            .or_else(|| filters.project_root.clone()),
        affected_skill: item.affected_skill.clone(),
        affected_instance_ids,
        recommended_next_step_label: redact_for_llm_preview(&item.copy_label),
        blocker_notes: redacted_string_vec(&item.blocker_notes),
        gap_notes: vec![redact_for_llm_preview(&item.edit_guidance)],
        evidence_refs: item.evidence_refs.clone(),
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_batch_review_safety_flags(),
    }
}

fn remediation_rule_id_from_plan_item(item: &RemediationPlanItem) -> Option<String> {
    item.title
        .split('`')
        .nth(1)
        .map(redact_for_llm_preview)
        .or_else(|| {
            item.evidence_refs
                .iter()
                .find_map(|reference| reference.strip_prefix("rule:"))
                .map(redact_for_llm_preview)
        })
}

fn remediation_batch_review_item_from_impact(
    row: &RemediationImpactRow,
    filters: &RemediationBatchReviewFilters,
) -> RemediationBatchReviewItem {
    let affected_instance_ids = row
        .affected_skill
        .as_ref()
        .map(|skill| vec![skill.instance_id.clone()])
        .unwrap_or_default();
    RemediationBatchReviewItem {
        id: format!("batch-review:impact:{}", row.id),
        rank: 0,
        source: "impact_preview",
        source_id: row.id.clone(),
        title: redact_for_llm_preview(&row.title),
        summary: redact_for_llm_preview(&row.summary),
        risk: remediation_risk_for_confidence(row.confidence),
        severity: remediation_severity_for_confidence(row.confidence).to_string(),
        status: "plan-only".to_string(),
        triage_status: None,
        rule_id: Some(row.area.to_string()),
        task: row.affected_task.clone().or_else(|| filters.task.clone()),
        agent: row.affected_agent.clone(),
        workspace: filters
            .workspace_label
            .clone()
            .or_else(|| filters.project_root.clone()),
        affected_skill: row.affected_skill.clone(),
        affected_instance_ids,
        recommended_next_step_label: "Open impact preview".to_string(),
        blocker_notes: redacted_string_vec(&row.blockers),
        gap_notes: Vec::new(),
        evidence_refs: row.evidence_refs.clone(),
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_batch_review_safety_flags(),
    }
}

fn remediation_batch_review_item_from_cleanup(
    item: &CleanupQueueItem,
    filters: &RemediationBatchReviewFilters,
    detail_by_id: &BTreeMap<&str, &SkillDetailRecord>,
) -> RemediationBatchReviewItem {
    let affected_skill = item
        .skill_id
        .as_deref()
        .and_then(|id| detail_by_id.get(id).copied())
        .map(remediation_affected_skill);
    RemediationBatchReviewItem {
        id: format!("batch-review:cleanup:{}", item.id),
        rank: 0,
        source: "cleanup_queue",
        source_id: item.source_id.clone(),
        title: redact_for_llm_preview(&item.title),
        summary: redact_for_llm_preview(&item.detail),
        risk: remediation_risk_band(&item.severity),
        severity: remediation_severity(&item.severity).to_string(),
        status: "open".to_string(),
        triage_status: None,
        rule_id: Some(item.kind.clone()),
        task: filters.task.clone(),
        agent: item.agent.clone(),
        workspace: filters
            .workspace_label
            .clone()
            .or_else(|| filters.project_root.clone()),
        affected_skill,
        affected_instance_ids: item.skill_id.iter().cloned().collect(),
        recommended_next_step_label: redact_for_llm_preview(&item.recommended_next_action_label),
        blocker_notes: vec![
            "Cleanup queue item is read-only and does not execute cleanup.".to_string(),
        ],
        gap_notes: Vec::new(),
        evidence_refs: vec![format!("cleanup:{}", item.source_id)],
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_batch_review_safety_flags(),
    }
}

fn remediation_risk_for_confidence(confidence: u8) -> &'static str {
    match confidence {
        75..=100 => "low",
        50..=74 => "medium",
        _ => "high",
    }
}

fn remediation_severity_for_confidence(confidence: u8) -> &'static str {
    match confidence {
        75..=100 => "info",
        50..=74 => "warning",
        _ => "error",
    }
}

fn remediation_batch_review_item_matches(
    filters: &RemediationBatchReviewFilters,
    item: &RemediationBatchReviewItem,
) -> bool {
    if let Some(agent) = filters.agent.as_deref() {
        if item.agent.as_deref() != Some(agent) {
            return false;
        }
    }
    if let Some(rule_id) = filters.rule_id.as_deref() {
        if item.rule_id.as_deref() != Some(rule_id) {
            return false;
        }
    }
    if let Some(severity) = filters.severity.as_deref() {
        if item.severity != severity && item.risk != severity {
            return false;
        }
    }
    if let Some(status) = filters.status.as_deref() {
        if item.status != status {
            return false;
        }
    }
    if let Some(triage_status) = filters.triage_status.as_deref() {
        if item.triage_status.as_deref() != Some(triage_status) {
            return false;
        }
    }
    if !filters.candidate_instance_ids.is_empty()
        && !item.affected_instance_ids.iter().any(|id| {
            filters
                .candidate_instance_ids
                .iter()
                .any(|candidate| candidate == id)
        })
    {
        return false;
    }
    true
}

fn remediation_sorted_batch_review_items(
    mut items: Vec<RemediationBatchReviewItem>,
    limit: usize,
) -> Vec<RemediationBatchReviewItem> {
    items.sort_by(|left, right| {
        remediation_batch_risk_rank(left.risk)
            .cmp(&remediation_batch_risk_rank(right.risk))
            .then_with(|| {
                severity_rank_for_queue(&left.severity)
                    .cmp(&severity_rank_for_queue(&right.severity))
            })
            .then_with(|| left.source.cmp(right.source))
            .then_with(|| left.title.cmp(&right.title))
            .then_with(|| left.id.cmp(&right.id))
    });
    items.truncate(limit);
    for (index, item) in items.iter_mut().enumerate() {
        item.rank = index + 1;
    }
    items
}

fn remediation_batch_risk_rank(risk: &str) -> u8 {
    match risk {
        "high" => 0,
        "medium" => 1,
        "low" => 2,
        _ => 3,
    }
}

fn remediation_batch_review_groups(
    filters: &RemediationBatchReviewFilters,
    items: &[RemediationBatchReviewItem],
) -> Vec<RemediationBatchReviewGroup> {
    let mut grouped: BTreeMap<(&'static str, String), Vec<&RemediationBatchReviewItem>> =
        BTreeMap::new();
    for item in items {
        for group_by in &filters.group_by {
            let group_type = match group_by.as_str() {
                "task" => "task",
                "risk" => "risk",
                "rule" => "rule",
                "agent" => "agent",
                "workspace" => "workspace",
                "status" => "status",
                _ => continue,
            };
            let label = match group_type {
                "task" => item
                    .task
                    .clone()
                    .unwrap_or_else(|| "No task filter".to_string()),
                "risk" => item.risk.to_string(),
                "rule" => item
                    .rule_id
                    .clone()
                    .unwrap_or_else(|| "No rule id".to_string()),
                "agent" => item.agent.clone().unwrap_or_else(|| "No agent".to_string()),
                "workspace" => item
                    .workspace
                    .clone()
                    .unwrap_or_else(|| "Local catalog".to_string()),
                "status" => item.status.clone(),
                _ => unreachable!(),
            };
            grouped.entry((group_type, label)).or_default().push(item);
        }
    }
    let mut groups = grouped
        .into_iter()
        .map(|((group_type, label), rows)| {
            let evidence_refs = rows
                .iter()
                .flat_map(|item| item.evidence_refs.iter().cloned())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .take(8)
                .collect::<Vec<_>>();
            RemediationBatchReviewGroup {
                id: stable_batch_review_group_id(group_type, &label, &evidence_refs),
                group_type,
                label,
                item_count: rows.len(),
                high_risk_count: rows.iter().filter(|item| item.risk == "high").count(),
                medium_risk_count: rows.iter().filter(|item| item.risk == "medium").count(),
                low_risk_count: rows.iter().filter(|item| item.risk == "low").count(),
                top_item_ids: rows.iter().take(5).map(|item| item.id.clone()).collect(),
                recommended_next_step_label: rows
                    .first()
                    .map(|item| item.recommended_next_step_label.clone())
                    .unwrap_or_else(|| "Review local evidence".to_string()),
                blocker_notes: rows
                    .iter()
                    .flat_map(|item| item.blocker_notes.iter().cloned())
                    .collect::<BTreeSet<_>>()
                    .into_iter()
                    .take(5)
                    .collect(),
                evidence_refs,
            }
        })
        .collect::<Vec<_>>();
    groups.sort_by(|left, right| {
        remediation_batch_group_rank(left.group_type)
            .cmp(&remediation_batch_group_rank(right.group_type))
            .then_with(|| right.item_count.cmp(&left.item_count))
            .then_with(|| left.label.cmp(&right.label))
    });
    groups.truncate(filters.limit);
    groups
}

fn remediation_batch_group_rank(group_type: &str) -> u8 {
    match group_type {
        "risk" => 0,
        "rule" => 1,
        "agent" => 2,
        "workspace" => 3,
        "task" => 4,
        "status" => 5,
        _ => 6,
    }
}

fn stable_batch_review_group_id(group_type: &str, label: &str, evidence_refs: &[String]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(group_type.as_bytes());
    hasher.update(b"\0");
    hasher.update(label.as_bytes());
    hasher.update(b"\0");
    for evidence in evidence_refs {
        hasher.update(evidence.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("batch-group-{}", hex_prefix(&digest, 12))
}

fn remediation_batch_review_next_steps(items: &[RemediationBatchReviewItem]) -> Vec<String> {
    items
        .iter()
        .map(|item| item.recommended_next_step_label.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .take(10)
        .collect()
}

fn remediation_batch_review_summary(
    total_item_count: usize,
    items: &[RemediationBatchReviewItem],
    groups: &[RemediationBatchReviewGroup],
    filters: &RemediationBatchReviewFilters,
) -> RemediationBatchReviewSummary {
    let high_risk_count = items.iter().filter(|item| item.risk == "high").count();
    let medium_risk_count = items.iter().filter(|item| item.risk == "medium").count();
    let low_risk_count = items.iter().filter(|item| item.risk == "low").count();
    let group_count = |group_type: &str| {
        groups
            .iter()
            .filter(|group| group.group_type == group_type)
            .count()
    };
    let blocker_count = items.iter().map(|item| item.blocker_notes.len()).sum();
    let summary = if items.is_empty() {
        "No batch review items matched the selected local filters.".to_string()
    } else {
        format!(
            "Batch review returned {} of {} local read-only item(s) across {} group(s) using {:?} grouping.",
            items.len(),
            total_item_count,
            groups.len(),
            filters.group_by
        )
    };
    RemediationBatchReviewSummary {
        total_item_count,
        returned_item_count: items.len(),
        group_count: groups.len(),
        high_risk_count,
        medium_risk_count,
        low_risk_count,
        task_group_count: group_count("task"),
        agent_group_count: group_count("agent"),
        workspace_group_count: group_count("workspace"),
        rule_group_count: group_count("rule"),
        blocker_count,
        summary,
    }
}

fn remediation_impact_direction_for_action(action: &str) -> &'static str {
    match action {
        "enable" | "remediate" | "edit" => "improve",
        "disable" => "reduce",
        _ => "neutral",
    }
}

fn remediation_impact_direction_for_skill(
    action: &str,
    detail: &SkillDetailRecord,
) -> &'static str {
    match action {
        "enable" if !detail.enabled => "improve",
        "enable" => "neutral",
        "disable" if detail.enabled => "reduce",
        "disable" => "neutral",
        "edit" | "remediate" => "improve",
        _ => "neutral",
    }
}

fn remediation_estimated_enabled_after(action: &str, detail: &SkillDetailRecord) -> bool {
    match action {
        "enable" => true,
        "disable" => false,
        _ => detail.enabled,
    }
}

fn remediation_skill_impact_notes(action: &str, detail: &SkillDetailRecord) -> Vec<String> {
    let mut notes = Vec::new();
    match action {
        "enable" if detail.enabled => notes.push("Skill is already enabled; enable impact is neutral.".to_string()),
        "disable" if !detail.enabled => notes.push("Skill is already disabled; disable impact is neutral.".to_string()),
        "edit" | "remediate" => notes.push("Edit/remediation impact is advisory until a separate safe write flow is explicitly confirmed.".to_string()),
        "review" => notes.push("Review impact is informational and does not change runtime state.".to_string()),
        _ => notes.push("Impact estimate is derived from current local enabled/state evidence.".to_string()),
    }
    if detail.state != "loaded" {
        notes.push(format!(
            "Current skill state is `{}`.",
            redact_for_llm_preview(&detail.state)
        ));
    }
    notes
}

fn remediation_risk_band(severity: &str) -> &'static str {
    match severity {
        "critical" | "error" => "high",
        "warning" | "warn" => "medium",
        _ => "low",
    }
}

fn remediation_expected_risk_after(action: &str, severity: &str) -> &'static str {
    match action {
        "edit" | "remediate" => match remediation_risk_band(severity) {
            "high" => "medium",
            "medium" => "low",
            other => other,
        },
        "disable" => "low",
        _ => remediation_risk_band(severity),
    }
}

fn remediation_snapshot_rollback_rows(
    filters: &RemediationPreviewImpactFilters,
    details: &[SkillDetailRecord],
    diagnostics: &[AdapterDiagnosticsRecord],
    evidence_by_id: &mut BTreeMap<String, TaskReadinessEvidenceReference>,
) -> Vec<RemediationSnapshotRollbackPlanRow> {
    details
        .iter()
        .take(filters.limit)
        .map(|detail| {
            let diagnostic = diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let writable_status = diagnostic
                .map(|diagnostic| diagnostic.access.writable_status)
                .unwrap_or("unknown");
            let verified_writable = matches!(
                writable_status,
                "verified" | "verified-writable" | "writable" | "partial"
            );
            let write_like_action = matches!(filters.action.as_str(), "enable" | "disable" | "edit" | "remediate");
            let evidence_id = remediation_insert_evidence(
                evidence_by_id,
                "adapter_diagnostic",
                &detail.agent,
                format!(
                    "{} writable status is `{}` for impact preview planning.",
                    redact_for_llm_preview(&detail.agent),
                    redact_for_llm_preview(writable_status)
                ),
                None,
                Some(detail.id.clone()),
            );
            RemediationSnapshotRollbackPlanRow {
                id: format!("snapshot-plan-{}", detail.id),
                agent: detail.agent.clone(),
                instance_id: detail.id.clone(),
                skill_name: redact_for_llm_preview(&detail.name),
                action_intent: filters.action.clone(),
                snapshot_required: write_like_action && verified_writable && filters.include_snapshot_plan,
                rollback_available: write_like_action && verified_writable && filters.include_rollback_plan,
                verified_writable,
                blocked_reason: if write_like_action && !verified_writable {
                    Some(format!(
                        "Adapter writable status is `{}`; impact preview cannot promise snapshot or rollback.",
                        redact_for_llm_preview(writable_status)
                    ))
                } else {
                    None
                },
                plan_only: true,
                evidence_refs: vec![evidence_id],
            }
        })
        .collect()
}

fn remediation_agent_impact_rows(
    filters: &RemediationPreviewImpactFilters,
    skill_rows: &[RemediationSkillImpactRow],
    diagnostics: &[AdapterDiagnosticsRecord],
) -> Vec<RemediationAgentImpactRow> {
    let mut by_agent: BTreeMap<String, Vec<&RemediationSkillImpactRow>> = BTreeMap::new();
    for row in skill_rows {
        by_agent
            .entry(row.affected_skill.agent.clone())
            .or_default()
            .push(row);
    }
    by_agent
        .into_iter()
        .map(|(agent, rows)| {
            let enabled_before_count = rows.iter().filter(|row| row.enabled_before).count();
            let enabled_after_estimate_count =
                rows.iter().filter(|row| row.enabled_after_estimate).count();
            let diagnostic = diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == agent);
            RemediationAgentImpactRow {
                agent,
                action_intent: filters.action.clone(),
                expected_direction: remediation_impact_direction_for_action(&filters.action),
                impacted_skill_count: rows.len(),
                enabled_before_count,
                enabled_after_estimate_count,
                writable_status: diagnostic
                    .map(|diagnostic| diagnostic.access.writable_status.to_string()),
                blocker_notes: diagnostic
                    .filter(|diagnostic| diagnostic.access.writable_status == "blocked")
                    .map(|diagnostic| {
                        vec![format!(
                            "Adapter writable status is `{}`; this remains a read-only impact preview.",
                            diagnostic.access.writable_status
                        )]
                    })
                    .unwrap_or_default(),
                evidence_refs: rows
                    .iter()
                    .flat_map(|row| row.evidence_refs.clone())
                    .collect::<BTreeSet<_>>()
                    .into_iter()
                    .collect(),
            }
        })
        .take(filters.limit)
        .collect()
}

fn remediation_task_impact_rows(
    filters: &RemediationPreviewImpactFilters,
    readiness: Option<&TaskReadinessResult>,
    routing: Option<&SkillRouteRankingResult>,
) -> Vec<RemediationTaskImpactRow> {
    let Some(task) = filters.task.clone() else {
        return Vec::new();
    };
    let readiness_score = readiness.map(|readiness| readiness.score);
    let routing_score = routing.map(|routing| routing.overall_confidence_score);
    let after_readiness =
        readiness_score.map(|score| remediation_estimated_score_after(&filters.action, score));
    let after_routing =
        routing_score.map(|score| remediation_estimated_score_after(&filters.action, score));
    let mut evidence_refs = Vec::new();
    if let Some(readiness) = readiness {
        evidence_refs.extend(
            readiness
                .evidence_references
                .iter()
                .take(4)
                .map(|e| e.id.clone()),
        );
    }
    if let Some(routing) = routing {
        evidence_refs.extend(
            routing
                .evidence_references
                .iter()
                .take(4)
                .map(|e| e.id.clone()),
        );
    }
    evidence_refs.sort();
    evidence_refs.dedup();
    vec![RemediationTaskImpactRow {
        task,
        action_intent: filters.action.clone(),
        expected_direction: remediation_impact_direction_for_action(&filters.action),
        readiness_score_before: readiness_score,
        readiness_score_after_estimate: after_readiness,
        routing_confidence_before: routing_score,
        routing_confidence_after_estimate: after_routing,
        notes: vec![
            "Task impact is an estimate from deterministic local readiness/routing evidence; no provider request was sent.".to_string(),
        ],
        evidence_refs,
    }]
}

fn remediation_estimated_score_after(action: &str, score: u8) -> u8 {
    match action {
        "enable" | "edit" | "remediate" => score.saturating_add(8).min(100),
        "disable" => score.saturating_sub(12),
        _ => score,
    }
}

fn remediation_top_level_impact_rows(
    filters: &RemediationPreviewImpactFilters,
    skill_rows: &[RemediationSkillImpactRow],
    agent_rows: &[RemediationAgentImpactRow],
    task_rows: &[RemediationTaskImpactRow],
    risk_rows: &[RemediationRiskDeltaRow],
    snapshot_rows: &[RemediationSnapshotRollbackPlanRow],
) -> Vec<RemediationImpactRow> {
    let mut rows = Vec::new();
    if !skill_rows.is_empty() {
        rows.push(remediation_impact_row(RemediationImpactRowInput {
            area: "skill",
            rank: 1,
            title: "Skill impact",
            summary: format!(
                "{} local skill(s) are in scope for `{}`.",
                skill_rows.len(),
                filters.action
            ),
            filters,
            affected_agent: Some(skill_rows[0].affected_skill.agent.clone()),
            affected_skill: Some(skill_rows[0].affected_skill.clone()),
            evidence_refs: skill_rows[0].evidence_refs.clone(),
            blockers: Vec::new(),
        }));
    }
    if !agent_rows.is_empty() {
        rows.push(remediation_impact_row(RemediationImpactRowInput {
            area: "agent",
            rank: 2,
            title: "Agent impact",
            summary: format!(
                "{} agent(s) have scoped skill impact rows.",
                agent_rows.len()
            ),
            filters,
            affected_agent: Some(agent_rows[0].agent.clone()),
            affected_skill: None,
            evidence_refs: agent_rows[0].evidence_refs.clone(),
            blockers: agent_rows[0].blocker_notes.clone(),
        }));
    }
    if !task_rows.is_empty() {
        rows.push(remediation_impact_row(RemediationImpactRowInput {
            area: "task",
            rank: 3,
            title: "Task impact",
            summary: "Task readiness/routing impact is estimated from local evidence.".to_string(),
            filters,
            affected_agent: filters.agent.clone(),
            affected_skill: None,
            evidence_refs: task_rows[0].evidence_refs.clone(),
            blockers: Vec::new(),
        }));
    }
    if !risk_rows.is_empty() {
        rows.push(remediation_impact_row(RemediationImpactRowInput {
            area: "risk",
            rank: 4,
            title: "Risk impact",
            summary: format!("{} local risk delta row(s) are in scope.", risk_rows.len()),
            filters,
            affected_agent: filters.agent.clone(),
            affected_skill: None,
            evidence_refs: risk_rows[0].evidence_refs.clone(),
            blockers: risk_rows
                .iter()
                .flat_map(|row| row.blockers.clone())
                .collect(),
        }));
    }
    if !snapshot_rows.is_empty() {
        rows.push(remediation_impact_row(RemediationImpactRowInput {
            area: "snapshot",
            rank: 5,
            title: "Snapshot and rollback plan",
            summary: format!(
                "{} plan-only snapshot/rollback row(s) are in scope.",
                snapshot_rows.len()
            ),
            filters,
            affected_agent: Some(snapshot_rows[0].agent.clone()),
            affected_skill: None,
            evidence_refs: snapshot_rows[0].evidence_refs.clone(),
            blockers: snapshot_rows
                .iter()
                .filter_map(|row| row.blocked_reason.clone())
                .collect(),
        }));
    }
    rows
}

struct RemediationImpactRowInput<'a> {
    area: &'static str,
    rank: usize,
    title: &'static str,
    summary: String,
    filters: &'a RemediationPreviewImpactFilters,
    affected_agent: Option<String>,
    affected_skill: Option<RemediationAffectedSkill>,
    evidence_refs: Vec<String>,
    blockers: Vec<String>,
}

fn remediation_impact_row(input: RemediationImpactRowInput<'_>) -> RemediationImpactRow {
    let RemediationImpactRowInput {
        area,
        rank,
        title,
        summary,
        filters,
        affected_agent,
        affected_skill,
        evidence_refs,
        mut blockers,
    } = input;
    blockers.sort();
    blockers.dedup();
    RemediationImpactRow {
        id: stable_remediation_item_id(area, title, &Vec::new(), &evidence_refs),
        rank,
        area,
        title: title.to_string(),
        summary,
        action_intent: filters.action.clone(),
        expected_direction: remediation_impact_direction_for_action(&filters.action),
        confidence: if blockers.is_empty() { 82 } else { 64 },
        confidence_band: if blockers.is_empty() {
            "high"
        } else {
            "medium"
        },
        affected_agent,
        affected_skill,
        affected_task: filters.task.clone(),
        evidence_refs,
        blockers,
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_preview_impact_safety_flags(),
    }
}

fn remediation_preview_impact_summary(
    impact_rows: &[RemediationImpactRow],
    task_rows: &[RemediationTaskImpactRow],
    agent_rows: &[RemediationAgentImpactRow],
    skill_rows: &[RemediationSkillImpactRow],
    risk_rows: &[RemediationRiskDeltaRow],
    snapshot_rows: &[RemediationSnapshotRollbackPlanRow],
    blocker_count: usize,
) -> RemediationPreviewImpactSummary {
    let snapshot_plan_count = snapshot_rows
        .iter()
        .filter(|row| row.snapshot_required)
        .count();
    let rollback_plan_count = snapshot_rows
        .iter()
        .filter(|row| row.rollback_available)
        .count();
    RemediationPreviewImpactSummary {
        total_impact_count: impact_rows.len(),
        returned_impact_count: impact_rows.len(),
        task_impact_count: task_rows.len(),
        agent_impact_count: agent_rows.len(),
        skill_impact_count: skill_rows.len(),
        risk_delta_count: risk_rows.len(),
        snapshot_plan_count,
        rollback_plan_count,
        blocker_count,
        summary: format!(
            "Impact preview returned {} top-level row(s), {} skill row(s), {} risk delta row(s), and {} plan-only snapshot/rollback row(s).",
            impact_rows.len(),
            skill_rows.len(),
            risk_rows.len(),
            snapshot_rows.len()
        ),
    }
}

fn remediation_draft_type_for_rule(rule_id: &str) -> Option<&'static str> {
    let normalized = rule_id.to_ascii_lowercase();
    if normalized.starts_with("frontmatter.")
        || normalized == "name.canonical-case"
        || normalized.contains("metadata")
    {
        Some("frontmatter")
    } else if normalized.starts_with("permissions.") || normalized.starts_with("script.") {
        Some("permissions")
    } else if normalized.starts_with("dependency.") || normalized.contains("dependency") {
        Some("dependency")
    } else if normalized.starts_with("body.") || normalized.contains("description") {
        Some("description")
    } else {
        None
    }
}

fn remediation_draft_item_for_finding(
    skill: &SkillDetailRecord,
    finding: &RuleFindingRecord,
    draft_type: &'static str,
    evidence_refs: Vec<String>,
) -> RemediationDraftItem {
    let (title, current_text, proposed_text, edit_guidance, copy_label) = match draft_type {
        "frontmatter" => {
            let proposed = remediation_frontmatter_draft(skill);
            (
                format!("Draft frontmatter fix for `{}`", redact_for_llm_preview(&skill.name)),
                Some(redacted_snippet(&skill.frontmatter_raw, 900)),
                proposed,
                "Review the YAML snippet, copy it into the normal editor if appropriate, and keep any agent-specific fields that are intentionally present."
                    .to_string(),
                "Copy frontmatter draft".to_string(),
            )
        }
        "description" => {
            let proposed = remediation_description_draft(skill, finding);
            (
                format!("Draft description fix for `{}`", redact_for_llm_preview(&skill.name)),
                Some(redacted_snippet(&skill.description, 500)),
                proposed,
                "Use this as a replacement or starting point for the skill description; verify it still matches the body before editing."
                    .to_string(),
                "Copy description draft".to_string(),
            )
        }
        "permissions" => {
            let proposed = remediation_permissions_draft(skill, finding);
            (
                format!("Draft permission fix for `{}`", redact_for_llm_preview(&skill.name)),
                Some(redacted_snippet(&skill.frontmatter_raw, 900)),
                proposed,
                "Copy the permission snippet only after reviewing whether the requested tools are still required; this preview does not edit files."
                    .to_string(),
                "Copy permission draft".to_string(),
            )
        }
        "dependency" => {
            let proposed = remediation_dependency_draft(skill, finding);
            (
                format!("Draft dependency note for `{}`", redact_for_llm_preview(&skill.name)),
                Some(redacted_snippet(&skill.body, 700)),
                proposed,
                "Use this note to update dependency documentation or remove stale dependency references through an existing manual edit flow."
                    .to_string(),
                "Copy dependency draft".to_string(),
            )
        }
        _ => {
            let proposed = finding
                .suggestion
                .as_deref()
                .map(redact_for_llm_preview)
                .unwrap_or_else(|| redact_for_llm_preview(&finding.message));
            (
                format!("Draft fix for `{}`", redact_for_llm_preview(&skill.name)),
                None,
                proposed,
                "Review and copy this draft manually; no write path is available here.".to_string(),
                "Copy draft".to_string(),
            )
        }
    };
    let confidence = remediation_draft_confidence(finding);
    let patch_like_snippet =
        remediation_patch_like_snippet(draft_type, current_text.as_deref(), &proposed_text);
    RemediationDraftItem {
        id: stable_remediation_draft_id(
            draft_type,
            &skill.id,
            Some(&finding.id),
            Some(&finding.rule_id),
            &proposed_text,
        ),
        rank: 0,
        title,
        draft_type,
        agent: Some(skill.agent.clone()),
        affected_skill: Some(remediation_affected_skill(skill)),
        finding_id: Some(redact_for_llm_preview(&finding.id)),
        rule_id: Some(redact_for_llm_preview(&finding.rule_id)),
        current_text,
        proposed_text,
        patch_like_snippet,
        rationale: finding
            .suggestion
            .as_deref()
            .map(redact_for_llm_preview)
            .unwrap_or_else(|| redact_for_llm_preview(&finding.message)),
        confidence,
        confidence_band: remediation_draft_confidence_band(confidence),
        copy_label,
        edit_guidance,
        evidence_refs,
        blocker_notes: remediation_blockers_for_finding(finding),
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_preview_drafts_safety_flags(),
    }
}

struct RemediationPolicyDraftInput<'a> {
    title: String,
    draft_type: &'static str,
    skill: Option<&'a SkillDetailRecord>,
    finding_id: Option<String>,
    rule_id: Option<String>,
    proposed_text: String,
    rationale: String,
    evidence_refs: Vec<String>,
}

fn remediation_policy_draft_item(input: RemediationPolicyDraftInput<'_>) -> RemediationDraftItem {
    let current_text = input
        .skill
        .map(|skill| redacted_snippet(&skill.frontmatter_raw, 700));
    let patch_like_snippet = remediation_patch_like_snippet(
        input.draft_type,
        current_text.as_deref(),
        &input.proposed_text,
    );
    RemediationDraftItem {
        id: stable_remediation_draft_id(
            input.draft_type,
            input
                .skill
                .map(|skill| skill.id.as_str())
                .unwrap_or("workspace-policy"),
            input.finding_id.as_deref(),
            input.rule_id.as_deref(),
            &input.proposed_text,
        ),
        rank: 0,
        title: redact_for_llm_preview(&input.title),
        draft_type: input.draft_type,
        agent: input.skill.map(|skill| skill.agent.clone()),
        affected_skill: input.skill.map(remediation_affected_skill),
        finding_id: input.finding_id.map(|id| redact_for_llm_preview(&id)),
        rule_id: input.rule_id.map(|id| redact_for_llm_preview(&id)),
        current_text,
        proposed_text: redact_for_llm_preview(&input.proposed_text),
        patch_like_snippet,
        rationale: redact_for_llm_preview(&input.rationale),
        confidence: 58,
        confidence_band: "medium",
        copy_label: "Copy policy draft".to_string(),
        edit_guidance:
            "Use this as copy-only policy guidance in skill metadata or review notes; no config or skill file is changed by this preview."
                .to_string(),
        evidence_refs: input.evidence_refs,
        blocker_notes: vec![
            "Policy draft is advisory and must be reviewed before any existing write flow."
                .to_string(),
        ],
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_preview_drafts_safety_flags(),
    }
}

fn remediation_policy_draft_item_from_plan(
    plan_item: &RemediationPlanItem,
) -> RemediationDraftItem {
    let proposed_text = format!(
        "{} Review note: {}",
        redact_for_llm_preview(&plan_item.suggested_safe_next_action),
        redact_for_llm_preview(&plan_item.summary)
    );
    let patch_like_snippet = remediation_patch_like_snippet("policy", None, &proposed_text);
    RemediationDraftItem {
        id: stable_remediation_draft_id(
            "policy",
            plan_item
                .affected_skill
                .as_ref()
                .map(|skill| skill.instance_id.as_str())
                .unwrap_or("remediation-plan-policy"),
            Some(&plan_item.id),
            Some(plan_item.category),
            &proposed_text,
        ),
        rank: 0,
        title: format!(
            "Draft policy note from `{}`",
            redact_for_llm_preview(&plan_item.title)
        ),
        draft_type: "policy",
        agent: plan_item.affected_agent.clone(),
        affected_skill: plan_item.affected_skill.clone(),
        finding_id: None,
        rule_id: Some(plan_item.category.to_string()),
        current_text: None,
        proposed_text,
        patch_like_snippet,
        rationale: redact_for_llm_preview(&plan_item.detail),
        confidence: 55,
        confidence_band: "medium",
        copy_label: "Copy policy draft".to_string(),
        edit_guidance:
            "Use this copy-only policy note to clarify review expectations; this preview does not toggle, merge, delete, or write skills."
                .to_string(),
        evidence_refs: plan_item.evidence_refs.clone(),
        blocker_notes: plan_item.blockers.clone(),
        side_effect_flags: remediation_side_effect_flags(),
        safety_flags: remediation_preview_drafts_safety_flags(),
    }
}

fn remediation_frontmatter_draft(skill: &SkillDetailRecord) -> String {
    let mut lines = vec![
        format!("name: {}", redact_for_llm_preview(&skill.name)),
        format!("description: {}", remediation_description_draft_text(skill)),
    ];
    let tools = remediation_permission_tools(skill);
    if !tools.is_empty() {
        lines.push("allowed-tools:".to_string());
        for tool in tools {
            lines.push(format!("  - {}", redact_for_llm_preview(&tool)));
        }
    }
    lines.join("\n")
}

fn remediation_description_draft(skill: &SkillDetailRecord, finding: &RuleFindingRecord) -> String {
    let base = remediation_description_draft_text(skill);
    let finding_hint = finding
        .suggestion
        .as_deref()
        .or(Some(finding.message.as_str()))
        .map(redact_for_llm_preview)
        .unwrap_or_default();
    if finding_hint.is_empty() {
        base
    } else {
        format!("{base} Review note: {finding_hint}")
    }
}

fn remediation_description_draft_text(skill: &SkillDetailRecord) -> String {
    let name = redact_for_llm_preview(&skill.name).replace('-', " ");
    let body_hint = first_non_empty_line(&skill.body)
        .map(redact_for_llm_preview)
        .unwrap_or_else(|| "Use this skill for the documented local workflow.".to_string());
    let mut text = format!("{name}: {body_hint}");
    if text.len() > 220 {
        text.truncate(217);
        text.push_str("...");
    }
    text
}

fn remediation_permissions_draft(skill: &SkillDetailRecord, finding: &RuleFindingRecord) -> String {
    let mut lines = Vec::new();
    let tools = remediation_permission_tools(skill);
    if tools.is_empty() {
        lines.push("allowed-tools: []".to_string());
    } else {
        lines.push("allowed-tools:".to_string());
        for tool in tools {
            lines.push(format!("  - {}", redact_for_llm_preview(&tool)));
        }
    }
    if finding.rule_id == "permissions.exec-needs-human" {
        lines.push("requires-human-review: true".to_string());
    }
    lines.push("# Copy-only preview: verify each permission before editing.".to_string());
    lines.join("\n")
}

fn remediation_dependency_draft(skill: &SkillDetailRecord, finding: &RuleFindingRecord) -> String {
    format!(
        "Dependency review for `{}`: {} If the dependency is intentional, document the exact local requirement and review path; otherwise remove the stale dependency reference.",
        redact_for_llm_preview(&skill.name),
        finding
            .suggestion
            .as_deref()
            .map(redact_for_llm_preview)
            .unwrap_or_else(|| redact_for_llm_preview(&finding.message))
    )
}

fn remediation_permission_tools(skill: &SkillDetailRecord) -> Vec<String> {
    skill
        .permissions
        .get("tools")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::trim)
        .filter(|tool| !tool.is_empty())
        .map(str::to_string)
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn first_non_empty_line(value: &str) -> Option<&str> {
    value.lines().map(str::trim).find(|line| !line.is_empty())
}

fn redacted_snippet(value: &str, max_len: usize) -> String {
    let mut snippet = redact_for_llm_preview(value.trim());
    if snippet.len() > max_len {
        snippet.truncate(max_len.saturating_sub(3));
        snippet.push_str("...");
    }
    snippet
}

fn redacted_string_vec(values: &[String]) -> Vec<String> {
    values
        .iter()
        .map(|value| redact_for_llm_preview(value))
        .collect()
}

fn remediation_patch_like_snippet(
    draft_type: &str,
    current_text: Option<&str>,
    proposed_text: &str,
) -> String {
    let mut lines = vec![format!("*** Copy-only {} draft ***", draft_type)];
    if let Some(current) = current_text.filter(|value| !value.trim().is_empty()) {
        lines.push("--- current".to_string());
        lines.extend(current.lines().take(12).map(|line| format!("- {line}")));
    }
    lines.push("+++ proposed".to_string());
    lines.extend(
        proposed_text
            .lines()
            .take(20)
            .map(|line| format!("+ {line}")),
    );
    lines.push("*** No apply action is available from this preview ***".to_string());
    lines.join("\n")
}

fn remediation_draft_confidence(finding: &RuleFindingRecord) -> u8 {
    match finding.effective_severity.as_str() {
        "critical" | "error" => 82,
        "warning" | "warn" => 68,
        "info" => 52,
        _ => 45,
    }
}

fn remediation_draft_confidence_band(confidence: u8) -> &'static str {
    match confidence {
        75..=100 => "high",
        50..=74 => "medium",
        _ => "low",
    }
}

fn stable_remediation_draft_id(
    draft_type: &str,
    skill_id: &str,
    finding_id: Option<&str>,
    rule_id: Option<&str>,
    proposed_text: &str,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(draft_type.as_bytes());
    hasher.update(b"\0");
    hasher.update(skill_id.as_bytes());
    hasher.update(b"\0");
    if let Some(finding_id) = finding_id {
        hasher.update(finding_id.as_bytes());
    }
    hasher.update(b"\0");
    if let Some(rule_id) = rule_id {
        hasher.update(rule_id.as_bytes());
    }
    hasher.update(b"\0");
    hasher.update(proposed_text.as_bytes());
    let digest = hasher.finalize();
    format!("draft-{}", hex_prefix(&digest, 12))
}

fn remediation_sorted_draft_items(
    mut items: Vec<RemediationDraftItem>,
    filters: &RemediationPreviewDraftsFilters,
) -> Vec<RemediationDraftItem> {
    items.sort_by(|left, right| {
        remediation_draft_type_rank(left.draft_type)
            .cmp(&remediation_draft_type_rank(right.draft_type))
            .then_with(|| right.confidence.cmp(&left.confidence))
            .then_with(|| left.title.cmp(&right.title))
            .then_with(|| left.id.cmp(&right.id))
    });
    items.truncate(filters.limit);
    for (index, item) in items.iter_mut().enumerate() {
        item.rank = index + 1;
    }
    items
}

fn remediation_draft_type_rank(draft_type: &str) -> u8 {
    match draft_type {
        "frontmatter" => 0,
        "description" => 1,
        "permissions" => 2,
        "dependency" => 3,
        "policy" => 4,
        _ => 5,
    }
}

fn remediation_preview_drafts_summary(
    total_draft_count: usize,
    returned_draft_count: usize,
    items: &[RemediationDraftItem],
) -> RemediationPreviewDraftsSummary {
    let type_count = |draft_type: &str| {
        items
            .iter()
            .filter(|item| item.draft_type == draft_type)
            .count()
    };
    let high_confidence_count = items
        .iter()
        .filter(|item| item.confidence_band == "high")
        .count();
    let medium_confidence_count = items
        .iter()
        .filter(|item| item.confidence_band == "medium")
        .count();
    let low_confidence_count = items
        .iter()
        .filter(|item| item.confidence_band == "low")
        .count();
    let blocker_count = items.iter().map(|item| item.blocker_notes.len()).sum();
    let summary = if returned_draft_count == 0 {
        "No fix preview drafts matched the selected local filters.".to_string()
    } else {
        format!(
            "Fix preview drafts returned {returned_draft_count} of {total_draft_count} copy-only draft(s): {high_confidence_count} high confidence, {medium_confidence_count} medium, {low_confidence_count} low."
        )
    };
    RemediationPreviewDraftsSummary {
        total_draft_count,
        returned_draft_count,
        frontmatter_count: type_count("frontmatter"),
        description_count: type_count("description"),
        permissions_count: type_count("permissions"),
        dependency_count: type_count("dependency"),
        policy_count: type_count("policy"),
        high_confidence_count,
        medium_confidence_count,
        low_confidence_count,
        blocker_count,
        summary,
    }
}
