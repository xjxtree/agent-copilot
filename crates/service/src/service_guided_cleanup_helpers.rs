use super::*;

pub(crate) fn supported_methods() -> Vec<&'static str> {
    SUPPORTED_METHODS.to_vec()
}

pub(crate) fn generated_benchmark_id(title: &str, task: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(task.as_bytes());
    let digest = hasher.finalize();
    format!("bench-{}", hex_prefix(&digest, 12))
}

pub(crate) fn sanitize_benchmark_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

pub(crate) fn normalize_string_list(values: Vec<String>) -> Vec<String> {
    let mut normalized = values
        .into_iter()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    normalized.sort();
    normalized.dedup();
    normalized
}

pub(crate) fn hex_prefix(bytes: &[u8], chars: usize) -> String {
    bytes
        .iter()
        .flat_map(|byte| {
            let high = b"0123456789abcdef"[(byte >> 4) as usize] as char;
            let low = b"0123456789abcdef"[(byte & 0x0f) as usize] as char;
            [high, low]
        })
        .take(chars)
        .collect()
}

pub(crate) fn sanitize_harness_label(label: &str) -> String {
    label
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(80)
        .collect()
}

pub(crate) fn agent_matches(filter: Option<&str>, agent: Option<&str>) -> bool {
    match filter {
        Some(filter) => agent == Some(filter),
        None => true,
    }
}

pub(crate) fn severity_rank_for_queue(severity: &str) -> u8 {
    match severity {
        "critical" => 0,
        "error" => 1,
        "warn" | "warning" => 2,
        "info" => 3,
        _ => 4,
    }
}

pub(crate) fn guided_cleanup_safety_flags() -> GuidedCleanupSafetyFlags {
    remediation_history_safety_flags()
}

pub(crate) fn guided_cleanup_filters(
    params: &GuidedCleanupPlanParams,
    adapter_ctx: &AdapterContext,
    roots: &[(String, &'static str)],
) -> GuidedCleanupFlowFilters {
    let mut candidate_instance_ids = normalized_redacted_ids(&params.candidate_instance_ids);
    if let Some(selected) = params
        .selected_skill_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| truncate_chars(&redact_string(&redact_for_llm_preview(value), roots), 160))
    {
        if !candidate_instance_ids.iter().any(|id| id == &selected) {
            candidate_instance_ids.push(selected);
        }
    }
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();

    GuidedCleanupFlowFilters {
        task: skill_lifecycle_filter_text(params.task.as_deref(), roots, 320),
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        selected_skill_id: skill_lifecycle_filter_token(
            params.selected_skill_id.as_deref(),
            roots,
            160,
        ),
        selected_skill_name: skill_lifecycle_filter_text(
            params.selected_skill_name.as_deref(),
            roots,
            180,
        ),
        selected_skill_agent: params
            .selected_skill_agent
            .as_deref()
            .and_then(normalize_agent_label),
        project_root: params
            .project_root
            .as_deref()
            .map(|value| skill_lifecycle_filter_path_text(value, roots, 240))
            .or_else(|| {
                adapter_ctx.project_root.as_ref().map(|path| {
                    skill_lifecycle_filter_path_text(&path.to_string_lossy(), roots, 240)
                })
            }),
        current_cwd: params
            .current_cwd
            .as_deref()
            .map(|value| skill_lifecycle_filter_path_text(value, roots, 240))
            .or_else(|| {
                adapter_ctx.project_cwd.as_ref().map(|path| {
                    skill_lifecycle_filter_path_text(&path.to_string_lossy(), roots, 240)
                })
            }),
        workspace: skill_lifecycle_filter_text(params.workspace.as_deref(), roots, 240),
        candidate_instance_ids,
        limit: params.limit.unwrap_or(18).clamp(1, 100),
        include_recorded_steps: params.include_recorded_steps,
    }
}

pub(crate) fn guided_cleanup_candidate_ids(
    params: &GuidedCleanupPlanParams,
    filters: &GuidedCleanupFlowFilters,
    visible_by_id: &BTreeMap<&str, &SkillRecord>,
) -> Vec<String> {
    let mut ids = filters.candidate_instance_ids.clone();
    if let Some(name) = filters.selected_skill_name.as_deref() {
        ids.extend(
            visible_by_id
                .values()
                .filter(|skill| skill.name.eq_ignore_ascii_case(name))
                .map(|skill| skill.id.clone()),
        );
    }
    if let Some(agent) = filters
        .selected_skill_agent
        .as_deref()
        .or(filters.agent.as_deref())
    {
        ids.retain(|id| {
            visible_by_id
                .get(id.as_str())
                .is_none_or(|skill| skill.agent.eq_ignore_ascii_case(agent))
        });
    }
    if ids.is_empty() && params.selected_skill_id.is_none() && params.selected_skill_name.is_none()
    {
        return Vec::new();
    }
    ids.sort();
    ids.dedup();
    ids
}

pub(crate) fn empty_guided_cleanup_flow_result(
    filters: GuidedCleanupFlowFilters,
    catalog_available: bool,
    recorded_steps: Vec<GuidedCleanupStepRecord>,
) -> GuidedCleanupFlowResult {
    GuidedCleanupFlowResult {
        generated_by: "local-v2.67",
        catalog_available,
        summary: GuidedCleanupFlowSummary {
            recorded_step_count: recorded_steps.len(),
            blocker_count: 1,
            summary:
                "No local catalog is available, so guided cleanup flow has no catalog evidence."
                    .to_string(),
            ..GuidedCleanupFlowSummary::default()
        },
        filters,
        flow_steps: Vec::new(),
        issue_groups: Vec::new(),
        safe_next_actions: Vec::new(),
        recorded_steps,
        gap_notes: vec![
            "Run a local scan before relying on guided cleanup flow evidence.".to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted.".to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: GuidedCleanupPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "guided_cleanup_flow",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::GuidedCleanupFlow,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic guided cleanup flow steps using only local redacted evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence produces guided cleanup flow steps."
                .to_string(),
        },
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_step_from_batch_item(
    item: &RemediationBatchReviewItem,
) -> GuidedCleanupFlowStep {
    let source_method = guided_cleanup_source_method(item.source);
    let (instance_id, definition_id, skill_name) = item
        .affected_skill
        .as_ref()
        .map(|skill| {
            (
                Some(skill.instance_id.clone()),
                Some(skill.definition_id.clone()),
                Some(skill.skill_name.clone()),
            )
        })
        .unwrap_or_else(|| {
            (
                item.affected_instance_ids.first().cloned(),
                None,
                item.title
                    .split(':')
                    .next_back()
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .map(redact_for_llm_preview),
            )
        });
    let id = format!("guided:batch:{}", item.id);
    let instance_ids = instance_id.iter().cloned().collect::<Vec<_>>();
    GuidedCleanupFlowStep {
        id: id.clone(),
        rank: 0,
        step_type: guided_cleanup_step_type(item.source),
        phase: guided_cleanup_step_phase(item.source),
        title: item.title.clone(),
        summary: item.summary.clone(),
        status: item.status.clone(),
        risk: item.risk,
        source_method,
        source_id: item.source_id.clone(),
        agent: item.agent.clone(),
        skill_name,
        instance_id,
        definition_id,
        recommended_action_label: item.recommended_next_step_label.clone(),
        safe_entry_method: source_method,
        existing_safe_method: Some(source_method),
        safe_action_deep_link: guided_cleanup_deep_link_for_method(
            source_method,
            &item.recommended_next_step_label,
            vec![id],
            instance_ids,
            item.evidence_refs.clone(),
        ),
        requires_explicit_confirmation: false,
        evidence_refs: item.evidence_refs.clone(),
        blocker_notes: guided_cleanup_step_blockers(&item.blocker_notes),
        gap_notes: item.gap_notes.clone(),
        side_effect_flags: guided_cleanup_side_effect_flags(),
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_step_from_next_label(
    label: &str,
    task: &Option<String>,
) -> GuidedCleanupFlowStep {
    let id = stable_guided_cleanup_step_id("next-action", label, &[]);
    let safe_label = redact_for_llm_preview(label);
    GuidedCleanupFlowStep {
        id: id.clone(),
        rank: 0,
        step_type: "safe_next_action",
        phase: "review",
        title: safe_label.clone(),
        summary: task
            .as_ref()
            .map(|task| format!("Review this safe next step for task `{}`.", task))
            .unwrap_or_else(|| {
                "Review this safe next step against current local evidence.".to_string()
            }),
        status: "open".to_string(),
        risk: "low",
        source_method: "remediation.batchReview",
        source_id: redact_for_llm_preview(label),
        agent: None,
        skill_name: None,
        instance_id: None,
        definition_id: None,
        recommended_action_label: safe_label.clone(),
        safe_entry_method: "remediation.batchReview",
        existing_safe_method: Some("remediation.batchReview"),
        safe_action_deep_link: guided_cleanup_deep_link_for_method(
            "remediation.batchReview",
            &safe_label,
            vec![id],
            Vec::new(),
            Vec::new(),
        ),
        requires_explicit_confirmation: false,
        evidence_refs: Vec::new(),
        blocker_notes: vec![
            "Guided cleanup next steps are advisory and do not execute cleanup.".to_string(),
        ],
        gap_notes: Vec::new(),
        side_effect_flags: guided_cleanup_side_effect_flags(),
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_step_from_lifecycle(
    row: &SkillLifecycleTimelineRow,
) -> GuidedCleanupFlowStep {
    let id = format!("guided:lifecycle:{}", row.id);
    let instance_ids = row.instance_id.iter().cloned().collect::<Vec<_>>();
    GuidedCleanupFlowStep {
        id: id.clone(),
        rank: 0,
        step_type: "lifecycle_context",
        phase: "context",
        title: row.title.clone(),
        summary: row.summary.clone(),
        status: row
            .status
            .clone()
            .unwrap_or_else(|| row.lifecycle_stage.to_string()),
        risk: guided_cleanup_risk_for_severity(row.severity.as_deref()),
        source_method: "skill.lifecycleTimeline",
        source_id: row.id.clone(),
        agent: row.agent.clone(),
        skill_name: row.skill_name.clone(),
        instance_id: row.instance_id.clone(),
        definition_id: row.definition_id.clone(),
        recommended_action_label: "Review lifecycle timeline context".to_string(),
        safe_entry_method: "skill.lifecycleTimeline",
        existing_safe_method: Some("skill.lifecycleTimeline"),
        safe_action_deep_link: guided_cleanup_deep_link_for_method(
            "skill.lifecycleTimeline",
            "Review lifecycle timeline context",
            vec![id],
            instance_ids,
            row.evidence_refs.clone(),
        ),
        requires_explicit_confirmation: false,
        evidence_refs: row.evidence_refs.clone(),
        blocker_notes: vec![
            "Lifecycle context is read-only and cannot apply cleanup actions.".to_string(),
        ],
        gap_notes: Vec::new(),
        side_effect_flags: guided_cleanup_side_effect_flags(),
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_step_from_cockpit(
    next: &TaskCockpitRemediationNextStep,
) -> GuidedCleanupFlowStep {
    let id = format!("guided:cockpit:{}", next.id);
    GuidedCleanupFlowStep {
        id: id.clone(),
        rank: 0,
        step_type: "task_context",
        phase: "task_context",
        title: next.title.clone(),
        summary: next.suggested_safe_next_action.clone(),
        status: "open".to_string(),
        risk: next.priority,
        source_method: "task.buildCockpit",
        source_id: next.id.clone(),
        agent: None,
        skill_name: None,
        instance_id: None,
        definition_id: None,
        recommended_action_label: next.suggested_safe_next_action.clone(),
        safe_entry_method: "task.buildCockpit",
        existing_safe_method: Some("task.buildCockpit"),
        safe_action_deep_link: guided_cleanup_deep_link_for_method(
            "task.buildCockpit",
            &next.suggested_safe_next_action,
            vec![id],
            Vec::new(),
            next.evidence_refs.clone(),
        ),
        requires_explicit_confirmation: false,
        evidence_refs: next.evidence_refs.clone(),
        blocker_notes: guided_cleanup_step_blockers(&next.blocker_notes),
        gap_notes: next.gap_notes.clone(),
        side_effect_flags: guided_cleanup_side_effect_flags(),
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_step_blockers(blockers: &[String]) -> Vec<String> {
    let mut notes = blockers.to_vec();
    notes.push(
        "This guided cleanup step does not write files, mutate config, change triage, create snapshots, execute scripts, or send provider requests."
            .to_string(),
    );
    normalize_note_list(&mut notes);
    notes
}

pub(crate) fn guided_cleanup_source_method(source: &str) -> &'static str {
    match source {
        "cleanup_queue" => "cleanup.listQueue",
        "remediation_plan" => "remediation.plan",
        "fix_preview_draft" => "remediation.previewDrafts",
        "impact_preview" => "remediation.previewImpact",
        _ => "remediation.batchReview",
    }
}

pub(crate) fn guided_cleanup_step_type(source: &str) -> &'static str {
    match source {
        "cleanup_queue" => "queue_review",
        "remediation_plan" => "plan_review",
        "fix_preview_draft" => "copy_only_draft_review",
        "impact_preview" => "impact_review",
        _ => "review",
    }
}

pub(crate) fn guided_cleanup_step_phase(source: &str) -> &'static str {
    match source {
        "fix_preview_draft" => "draft_preview",
        "impact_preview" => "impact_preview",
        "remediation_plan" => "plan",
        _ => "inspect",
    }
}

pub(crate) fn guided_cleanup_risk_for_severity(severity: Option<&str>) -> &'static str {
    match severity.unwrap_or("info") {
        "critical" | "error" | "high" | "failed" | "miss" | "wrong_pick" => "high",
        "warning" | "warn" | "medium" | "ambiguous" => "medium",
        _ => "low",
    }
}

pub(crate) fn guided_cleanup_side_effect_flags() -> Vec<&'static str> {
    vec![
        "provider_request_sent=false",
        "write_back_allowed=false",
        "write_actions_available=false",
        "skill_files_mutated=false",
        "agent_config_mutated=false",
        "script_execution_allowed=false",
        "snapshot_created=false",
        "rollback_performed=false",
        "triage_mutation_allowed=false",
        "credential_accessed=false",
        "cloud_sync_performed=false",
        "telemetry_emitted=false",
    ]
}

pub(crate) fn stable_guided_cleanup_step_id(
    kind: &str,
    label: &str,
    evidence_refs: &[String],
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(kind.as_bytes());
    hasher.update(b"\0");
    hasher.update(label.as_bytes());
    hasher.update(b"\0");
    for reference in evidence_refs {
        hasher.update(reference.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("guided-step-{}", hex_prefix(&digest, 12))
}

pub(crate) fn guided_cleanup_sort_steps(steps: &mut Vec<GuidedCleanupFlowStep>, limit: usize) {
    let mut by_id = BTreeMap::<String, GuidedCleanupFlowStep>::new();
    for step in steps.drain(..) {
        by_id.entry(step.id.clone()).or_insert(step);
    }
    steps.extend(by_id.into_values());
    steps.sort_by(|left, right| {
        remediation_batch_risk_rank(left.risk)
            .cmp(&remediation_batch_risk_rank(right.risk))
            .then_with(|| {
                guided_cleanup_phase_rank(left.phase).cmp(&guided_cleanup_phase_rank(right.phase))
            })
            .then_with(|| left.source_method.cmp(right.source_method))
            .then_with(|| left.title.cmp(&right.title))
            .then_with(|| left.id.cmp(&right.id))
    });
    steps.truncate(limit);
    for (index, step) in steps.iter_mut().enumerate() {
        step.rank = index + 1;
    }
}

pub(crate) fn guided_cleanup_phase_rank(phase: &str) -> u8 {
    match phase {
        "inspect" => 0,
        "plan" => 1,
        "draft_preview" => 2,
        "impact_preview" => 3,
        "task_context" => 4,
        "context" => 5,
        _ => 6,
    }
}

pub(crate) fn guided_cleanup_issue_groups(
    steps: &[GuidedCleanupFlowStep],
    limit: usize,
) -> Vec<GuidedCleanupIssueGroup> {
    let mut grouped = BTreeMap::<(&'static str, String), Vec<&GuidedCleanupFlowStep>>::new();
    for step in steps {
        grouped
            .entry(("phase", step.phase.to_string()))
            .or_default()
            .push(step);
        grouped
            .entry(("risk", step.risk.to_string()))
            .or_default()
            .push(step);
        if let Some(agent) = step.agent.as_ref() {
            grouped
                .entry(("agent", agent.clone()))
                .or_default()
                .push(step);
        }
    }
    let mut groups = grouped
        .into_iter()
        .map(|((group_type, label), rows)| {
            let step_ids = rows
                .iter()
                .take(8)
                .map(|step| step.id.clone())
                .collect::<Vec<_>>();
            let evidence_refs = rows
                .iter()
                .flat_map(|step| step.evidence_refs.iter().cloned())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .take(8)
                .collect::<Vec<_>>();
            let blocker_notes = rows
                .iter()
                .flat_map(|step| step.blocker_notes.iter().cloned())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .take(6)
                .collect::<Vec<_>>();
            GuidedCleanupIssueGroup {
                id: stable_guided_cleanup_step_id(group_type, &label, &evidence_refs),
                group_type,
                label,
                step_count: rows.len(),
                high_risk_count: rows.iter().filter(|step| step.risk == "high").count(),
                medium_risk_count: rows.iter().filter(|step| step.risk == "medium").count(),
                low_risk_count: rows.iter().filter(|step| step.risk == "low").count(),
                step_ids,
                evidence_refs,
                blocker_notes,
                safety_flags: guided_cleanup_safety_flags(),
            }
        })
        .collect::<Vec<_>>();
    groups.sort_by(|left, right| {
        guided_cleanup_group_rank(left.group_type)
            .cmp(&guided_cleanup_group_rank(right.group_type))
            .then_with(|| right.step_count.cmp(&left.step_count))
            .then_with(|| left.label.cmp(&right.label))
    });
    groups.truncate(limit);
    groups
}

pub(crate) fn guided_cleanup_group_rank(group_type: &str) -> u8 {
    match group_type {
        "risk" => 0,
        "phase" => 1,
        "agent" => 2,
        _ => 3,
    }
}

pub(crate) fn guided_cleanup_safe_next_actions(
    steps: &[GuidedCleanupFlowStep],
) -> Vec<GuidedCleanupSafeNextAction> {
    let mut by_method = BTreeMap::<&'static str, Vec<&GuidedCleanupFlowStep>>::new();
    for step in steps {
        by_method
            .entry(step.safe_entry_method)
            .or_default()
            .push(step);
    }
    let mut actions = by_method
        .into_iter()
        .map(|(method, rows)| guided_cleanup_safe_next_action_for_method(method, &rows))
        .collect::<Vec<_>>();
    if !steps.is_empty() {
        actions.push(GuidedCleanupSafeNextAction {
            id: "guided-action-record-step".to_string(),
            label: "Record guided cleanup step metadata".to_string(),
            entry_method: "cleanup.recordGuidedStep",
            description:
                "Store only redacted app-local review metadata for the selected guided step."
                    .to_string(),
            requires_preview: false,
            requires_confirmation: true,
            copy_only: false,
            deep_link: guided_cleanup_deep_link_for_method(
                "cleanup.recordGuidedStep",
                "Record guided cleanup step metadata",
                steps.iter().take(8).map(|step| step.id.clone()).collect(),
                Vec::new(),
                Vec::new(),
            ),
            related_step_ids: steps.iter().take(8).map(|step| step.id.clone()).collect(),
            evidence_refs: Vec::new(),
            safety_flags: guided_cleanup_safety_flags(),
        });
        if steps.iter().any(|step| step.instance_id.is_some()) {
            actions.push(GuidedCleanupSafeNextAction {
                id: "guided-action-preview-toggle".to_string(),
                label: "Preview enable/disable with existing safe batch toggle flow".to_string(),
                entry_method: "batch.previewSkillToggles",
                description:
                    "If runtime enable/disable is still desired, open the existing preview-first toggle method; apply remains separate and explicit-confirm."
                        .to_string(),
                requires_preview: true,
                requires_confirmation: true,
                copy_only: false,
                deep_link: guided_cleanup_deep_link_for_method(
                    "batch.previewSkillToggles",
                    "Preview enable/disable with existing safe batch toggle flow",
                    steps
                        .iter()
                        .filter(|step| step.instance_id.is_some())
                        .take(8)
                        .map(|step| step.id.clone())
                        .collect(),
                    steps
                        .iter()
                        .filter_map(|step| step.instance_id.clone())
                        .collect::<BTreeSet<_>>()
                        .into_iter()
                        .take(8)
                        .collect(),
                    steps
                        .iter()
                        .flat_map(|step| step.evidence_refs.iter().cloned())
                        .collect::<BTreeSet<_>>()
                        .into_iter()
                        .take(8)
                        .collect(),
                ),
                related_step_ids: steps
                    .iter()
                    .filter(|step| step.instance_id.is_some())
                    .take(8)
                    .map(|step| step.id.clone())
                    .collect(),
                evidence_refs: steps
                    .iter()
                    .flat_map(|step| step.evidence_refs.iter().cloned())
                    .collect::<BTreeSet<_>>()
                    .into_iter()
                    .take(8)
                    .collect(),
                safety_flags: guided_cleanup_safety_flags(),
            });
        }
    }
    actions.sort_by(|left, right| left.entry_method.cmp(right.entry_method));
    actions
}

pub(crate) fn guided_cleanup_safe_next_action_for_method(
    method: &'static str,
    rows: &[&GuidedCleanupFlowStep],
) -> GuidedCleanupSafeNextAction {
    let (label, description, copy_only) = match method {
        "cleanup.listQueue" => (
            "Review cleanup queue evidence",
            "Open the existing read-only cleanup queue/detail evidence.",
            false,
        ),
        "remediation.plan" => (
            "Review remediation plan item",
            "Open the existing read-only remediation planner for prioritization context.",
            false,
        ),
        "remediation.previewDrafts" => (
            "Open copy-only fix preview draft",
            "Open existing draft suggestions; any wording remains copy-only unless separately applied outside this flow.",
            true,
        ),
        "remediation.previewImpact" => (
            "Open read-only impact preview",
            "Open existing impact preview rows before considering any separate write flow.",
            false,
        ),
        "skill.lifecycleTimeline" => (
            "Review lifecycle timeline",
            "Open existing lifecycle context to understand recent local evidence.",
            false,
        ),
        "task.buildCockpit" => (
            "Review task cockpit",
            "Open existing task-first cockpit context before routing or cleanup decisions.",
            false,
        ),
        _ => (
            "Open batch review workflow",
            "Open the existing read-only batch review workflow.",
            false,
        ),
    };
    GuidedCleanupSafeNextAction {
        id: format!("guided-action-{}", stable_slug(method)),
        label: label.to_string(),
        entry_method: method,
        description: description.to_string(),
        requires_preview: matches!(method, "batch.previewSkillToggles"),
        requires_confirmation: false,
        copy_only,
        deep_link: guided_cleanup_deep_link_for_method(
            method,
            label,
            rows.iter().take(8).map(|step| step.id.clone()).collect(),
            rows.iter()
                .filter_map(|step| step.instance_id.clone())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .take(8)
                .collect(),
            rows.iter()
                .flat_map(|step| step.evidence_refs.iter().cloned())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .take(8)
                .collect(),
        ),
        related_step_ids: rows.iter().take(8).map(|step| step.id.clone()).collect(),
        evidence_refs: rows
            .iter()
            .flat_map(|step| step.evidence_refs.iter().cloned())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(8)
            .collect(),
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_deep_link_for_method(
    method: &'static str,
    label: &str,
    related_step_ids: Vec<String>,
    instance_ids: Vec<String>,
    evidence_refs: Vec<String>,
) -> GuidedCleanupSafeActionDeepLink {
    let (target, detail_section, trigger, preview_only, requires_confirmation, copy_only) =
        match method {
            "cleanup.listQueue" => (
                "detail_section",
                "cleanup",
                "selectDetailSection",
                true,
                false,
                false,
            ),
            "remediation.plan" => (
                "analysis_action",
                "analysis",
                "planRemediation",
                true,
                false,
                false,
            ),
            "remediation.previewDrafts" => (
                "analysis_action",
                "analysis",
                "previewRemediationDrafts",
                true,
                false,
                true,
            ),
            "remediation.previewImpact" => (
                "analysis_action",
                "analysis",
                "previewRemediationImpact",
                true,
                false,
                false,
            ),
            "remediation.batchReview" => (
                "analysis_action",
                "analysis",
                "reviewRemediationBatch",
                true,
                false,
                false,
            ),
            "skill.lifecycleTimeline" => (
                "detail_section",
                "skillMap",
                "loadSkillLifecycleTimeline",
                true,
                false,
                false,
            ),
            "task.buildCockpit" => (
                "detail_section",
                "taskCockpit",
                "buildTaskCockpit",
                true,
                false,
                false,
            ),
            "batch.previewSkillToggles" => (
                "sidebar_preview",
                "cleanup",
                "openSafeBatchPreviewPanel",
                true,
                true,
                false,
            ),
            "cleanup.recordGuidedStep" => (
                "guided_metadata",
                "guidedCleanup",
                "recordGuidedStep",
                false,
                true,
                false,
            ),
            _ => (
                "analysis_action",
                "analysis",
                "reviewRemediationBatch",
                true,
                false,
                false,
            ),
        };

    GuidedCleanupSafeActionDeepLink {
        label: label.to_string(),
        target,
        detail_section,
        method,
        trigger,
        preview_only,
        requires_confirmation,
        copy_only,
        can_apply: false,
        instance_ids,
        related_step_ids,
        evidence_refs,
        safety_flags: guided_cleanup_safety_flags(),
    }
}

pub(crate) fn guided_cleanup_summary(
    total_step_count: usize,
    steps: &[GuidedCleanupFlowStep],
    issue_group_count: usize,
    safe_next_action_count: usize,
    recorded_step_count: usize,
) -> GuidedCleanupFlowSummary {
    let high_risk_count = steps.iter().filter(|step| step.risk == "high").count();
    let medium_risk_count = steps.iter().filter(|step| step.risk == "medium").count();
    let low_risk_count = steps.iter().filter(|step| step.risk == "low").count();
    let blocker_count = steps.iter().map(|step| step.blocker_notes.len()).sum();
    let summary = if steps.is_empty() {
        "No guided cleanup steps matched the selected local filters.".to_string()
    } else {
        format!(
            "Guided cleanup flow returned {} local read-only step(s): {high_risk_count} high, {medium_risk_count} medium, {low_risk_count} low, with {safe_next_action_count} safe next action row(s).",
            steps.len()
        )
    };
    GuidedCleanupFlowSummary {
        total_step_count,
        returned_step_count: steps.len(),
        issue_group_count,
        safe_next_action_count,
        recorded_step_count,
        high_risk_count,
        medium_risk_count,
        low_risk_count,
        blocker_count,
        summary,
    }
}

pub(crate) fn guided_cleanup_record_matches(
    filters: &GuidedCleanupFlowFilters,
    record: &GuidedCleanupStepRecord,
) -> bool {
    if let Some(agent) = filters
        .selected_skill_agent
        .as_deref()
        .or(filters.agent.as_deref())
    {
        if record
            .agent
            .as_deref()
            .is_some_and(|value| !value.eq_ignore_ascii_case(agent))
        {
            return false;
        }
    }
    if let Some(task) = filters.task.as_deref() {
        if !record.task.as_deref().is_some_and(|value| {
            value
                .to_ascii_lowercase()
                .contains(&task.to_ascii_lowercase())
        }) {
            return false;
        }
    }
    let mut ids = filters.candidate_instance_ids.clone();
    if let Some(selected) = filters.selected_skill_id.clone() {
        ids.push(selected);
    }
    ids.sort();
    ids.dedup();
    if !ids.is_empty()
        && !record
            .instance_id
            .as_deref()
            .is_some_and(|instance_id| ids.iter().any(|id| id == instance_id))
    {
        return false;
    }
    if let Some(name) = filters.selected_skill_name.as_deref() {
        if !record
            .skill_name
            .as_deref()
            .is_some_and(|value| value.eq_ignore_ascii_case(name))
        {
            return false;
        }
    }
    true
}

pub(crate) fn guided_cleanup_record_sort(
    left: &GuidedCleanupStepRecord,
    right: &GuidedCleanupStepRecord,
) -> std::cmp::Ordering {
    right
        .updated_at
        .cmp(&left.updated_at)
        .then_with(|| right.created_at.cmp(&left.created_at))
        .then_with(|| left.title.cmp(&right.title))
        .then_with(|| left.id.cmp(&right.id))
}

pub(crate) fn generated_guided_cleanup_record_id(
    flow_step_id: &str,
    decision: &str,
    recorded_at: i64,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(flow_step_id.as_bytes());
    hasher.update(b"\0");
    hasher.update(decision.as_bytes());
    hasher.update(b"\0");
    hasher.update(recorded_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("guided-cleanup-{}", hex_prefix(&digest, 12))
}

pub(crate) fn sanitize_guided_cleanup_record_id(id: &str) -> String {
    sanitize_remediation_history_id(id)
}

pub(crate) fn parse_agent_param(agent: &str) -> Result<AgentId, ServiceError> {
    match agent {
        "claude-code" => Ok(AgentId::ClaudeCode),
        "codex" => Ok(AgentId::Codex),
        "opencode" => Ok(AgentId::Opencode),
        other => Err(ServiceError::InvalidRequest(format!(
            "unsupported target_agent: {other}"
        ))),
    }
}

pub(crate) fn parse_scope_param(scope: &str) -> Result<Scope, ServiceError> {
    match scope {
        "agent-global" => Ok(Scope::AgentGlobal),
        "agent-project" => Ok(Scope::AgentProject),
        "tool-global" => Ok(Scope::ToolGlobal),
        other => Err(ServiceError::InvalidRequest(format!(
            "unsupported target_scope: {other}"
        ))),
    }
}
