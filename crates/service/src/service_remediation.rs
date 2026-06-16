use super::*;

impl ServiceHost {
    pub fn plan_remediation(
        &self,
        params: RemediationPlanParams,
    ) -> Result<RemediationPlanResult, ServiceError> {
        let started_at = Instant::now();
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "remediation.plan limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = remediation_plan_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_remediation_plan_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let mut aggregation_notes = Vec::new();
        let mut skipped_stages = Vec::new();
        let mut blocker_codes = Vec::new();
        let skill_ids = skills
            .iter()
            .map(|skill| skill.id.as_str())
            .collect::<BTreeSet<_>>();
        let mut detail_skill_records = skills
            .iter()
            .filter(|skill| {
                agent_matches(filters.agent.as_deref(), Some(skill.agent.as_str()))
                    && (filters.candidate_instance_ids.is_empty()
                        || filters.candidate_instance_ids.contains(&skill.id))
            })
            .collect::<Vec<_>>();
        let total_detail_candidate_count = detail_skill_records.len();
        let detail_scan_limit = filters
            .limit
            .saturating_mul(12)
            .clamp(80, REMEDIATION_MAX_DETAIL_SCAN);
        if filters.candidate_instance_ids.is_empty()
            && detail_skill_records.len() > detail_scan_limit
        {
            detail_skill_records.sort_by(|left, right| {
                right
                    .enabled
                    .cmp(&left.enabled)
                    .then_with(|| left.state.cmp(&right.state))
                    .then_with(|| left.agent.cmp(&right.agent))
                    .then_with(|| left.name.cmp(&right.name))
                    .then_with(|| left.id.cmp(&right.id))
            });
            detail_skill_records.truncate(detail_scan_limit);
            skipped_stages.push("detail-scan-overflow");
            blocker_codes.push("bounded-detail-scan");
            aggregation_notes.push(format!(
                "Remediation planning loaded detail evidence for {} of {} visible candidate skill(s).",
                detail_skill_records.len(),
                total_detail_candidate_count
            ));
        }
        let details = detail_skill_records
            .iter()
            .filter_map(|skill| catalog.get_skill_detail(&skill.id).ok().flatten())
            .filter(|detail| {
                workspace_detail_matches(params.project_root.as_deref().map(Path::new), detail)
            })
            .collect::<Vec<_>>();
        let detail_by_id = details
            .iter()
            .map(|detail| (detail.id.as_str(), detail))
            .collect::<BTreeMap<_, _>>();
        let candidate_instance_ids = if filters.candidate_instance_ids.is_empty() {
            details
                .iter()
                .map(|detail| detail.id.clone())
                .collect::<Vec<_>>()
        } else {
            filters.candidate_instance_ids.clone()
        };

        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let cleanup = self.cleanup_list_queue(CleanupListQueueParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
        })?;
        let taxonomy = self.build_capability_taxonomy(CapabilityTaxonomyParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit),
            include_single_skill_domains: true,
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        let stale_drift = self.detect_stale_drift(DetectStaleDriftParams {
            agent: filters.agent.clone(),
            candidate_instance_ids: candidate_instance_ids.clone(),
            limit: Some(filters.limit),
            stale_days: None,
            thresholds: StaleDriftThresholds::default(),
        })?;
        let similar = self.group_similar_skills(SimilarSkillGroupingParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit),
            min_score: Some(45.0),
            include_singletons: false,
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        let workspace = self.check_workspace_readiness(WorkspaceReadinessParams {
            agent: filters.agent.clone(),
            task: filters.task.clone(),
            project_root: params.project_root.clone(),
            expected_capabilities: filters.focus_areas.clone(),
            limit: Some(filters.limit),
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        let task_readiness = filters
            .task
            .as_ref()
            .map(|task| {
                self.check_task_readiness(TaskReadinessParams {
                    task: task.clone(),
                    agent: filters.agent.clone(),
                    candidate_instance_ids: candidate_instance_ids.clone(),
                    limit: Some(filters.limit.min(20)),
                })
            })
            .transpose()?;
        let route_ranking = task_readiness
            .as_ref()
            .map(|readiness| skill_route_ranking_from_readiness(readiness.clone()));

        let mut evidence_by_id = BTreeMap::new();
        for evidence in taxonomy
            .evidence_references
            .iter()
            .chain(stale_drift.evidence_references.iter())
            .chain(similar.evidence_references.iter())
            .chain(workspace.evidence_references.iter())
        {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert_with(|| evidence.clone());
        }
        for readiness in task_readiness.iter() {
            for evidence in &readiness.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }
        for ranking in route_ranking.iter() {
            for evidence in &ranking.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }

        let mut items = Vec::new();
        for finding in &findings {
            if finding.suppressed || finding.triage_status.eq_ignore_ascii_case("ignored") {
                continue;
            }
            let related = remediation_related_instances_for_finding(finding, &skill_ids);
            if !remediation_matches_filter(&filters, finding.instance_id.as_deref(), &related) {
                continue;
            }
            let skill = finding
                .instance_id
                .as_deref()
                .and_then(|id| detail_by_id.get(id).copied());
            if finding.instance_id.is_some() && skill.is_none() {
                continue;
            }
            if filters.agent.is_some() && skill.is_none() {
                continue;
            }
            let evidence_id = remediation_insert_evidence(
                &mut evidence_by_id,
                "finding",
                &finding.id,
                format!(
                    "{} finding `{}`: {}",
                    redact_for_llm_preview(&finding.effective_severity),
                    redact_for_llm_preview(&finding.rule_id),
                    redact_for_llm_preview(&finding.message)
                ),
                Some(finding.effective_severity.clone()),
                finding.instance_id.clone(),
            );
            items.push(remediation_item(RemediationItemInput {
                category: "finding",
                priority_score: remediation_score_for_severity(&finding.effective_severity),
                severity: remediation_severity(&finding.effective_severity),
                title: format!("Review `{}` finding", redact_for_llm_preview(&finding.rule_id)),
                summary: redact_for_llm_preview(&finding.message),
                detail: finding
                    .suggestion
                    .as_deref()
                    .map(redact_for_llm_preview)
                    .unwrap_or_else(|| "Review this finding in the existing finding/detail surfaces before choosing any safe write path.".to_string()),
                affected_agent: skill.map(|skill| skill.agent.clone()),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: None,
                affected_task: filters.task.clone(),
                affected_instance_ids: related,
                suggested_safe_next_action:
                    "Open the finding or skill detail and decide whether an existing reviewed flow is appropriate; this plan does not apply changes."
                        .to_string(),
                prerequisites: vec!["Confirm the finding is still relevant in the current local scan.".to_string()],
                blockers: remediation_blockers_for_finding(finding),
                deferred: false,
                evidence_refs: vec![evidence_id],
            }));
        }

        for conflict in &conflicts {
            let related = conflict
                .instance_ids
                .iter()
                .filter(|id| detail_by_id.contains_key(id.as_str()))
                .cloned()
                .collect::<Vec<_>>();
            if !remediation_matches_filter(&filters, None, &related) {
                continue;
            }
            let skill = related
                .first()
                .and_then(|id| detail_by_id.get(id.as_str()).copied());
            let evidence_id = remediation_insert_evidence(
                &mut evidence_by_id,
                "conflict",
                &conflict.id,
                format!(
                    "Same-agent conflict `{}` affects {} local instance(s).",
                    redact_for_llm_preview(&conflict.reason),
                    conflict.instance_ids.len()
                ),
                Some("warning".to_string()),
                skill.map(|skill| skill.id.clone()),
            );
            items.push(remediation_item(RemediationItemInput {
                category: "ambiguity",
                priority_score: 78,
                severity: "warning",
                title: "Resolve same-agent skill ambiguity".to_string(),
                summary: format!(
                    "Conflict `{}` can make runtime skill selection ambiguous.",
                    redact_for_llm_preview(&conflict.reason)
                ),
                detail:
                    "Compare the affected instances in the conflict/detail view before using any existing toggle or rollback flow."
                        .to_string(),
                affected_agent: skill.map(|skill| skill.agent.clone()),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: None,
                affected_task: filters.task.clone(),
                affected_instance_ids: related,
                suggested_safe_next_action:
                    "Open the conflict comparison and choose a manual review path; this planner does not toggle, merge, or delete skills."
                        .to_string(),
                prerequisites: vec!["Inspect winner/source provenance and content drift evidence.".to_string()],
                blockers: vec!["Automatic conflict resolution is not enabled.".to_string()],
                deferred: false,
                evidence_refs: vec![evidence_id],
            }));
        }

        for group in &analysis.groups {
            let related = group
                .instance_ids
                .iter()
                .filter(|id| detail_by_id.contains_key(id.as_str()))
                .cloned()
                .collect::<Vec<_>>();
            if !remediation_matches_filter(&filters, None, &related) {
                continue;
            }
            let category = if group.kind.contains("enabled") {
                "policy"
            } else {
                "ambiguity"
            };
            let skill = related
                .first()
                .and_then(|id| detail_by_id.get(id.as_str()).copied());
            let evidence_id = remediation_insert_evidence(
                &mut evidence_by_id,
                "analysis",
                &group.id,
                format!(
                    "{} analysis `{}`: {}",
                    redact_for_llm_preview(&group.severity),
                    redact_for_llm_preview(&group.kind),
                    redact_for_llm_preview(&group.title)
                ),
                Some(group.severity.clone()),
                skill.map(|skill| skill.id.clone()),
            );
            items.push(remediation_item(RemediationItemInput {
                category,
                priority_score: remediation_score_for_severity(&group.severity).saturating_sub(8),
                severity: remediation_severity(&group.severity),
                title: redact_for_llm_preview(&group.title),
                summary: redact_for_llm_preview(&group.explanation),
                detail:
                    "Use the cross-agent comparison and source provenance views to decide whether documentation, naming, or existing guarded toggles need review."
                        .to_string(),
                affected_agent: skill.map(|skill| skill.agent.clone()),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: None,
                affected_task: filters.task.clone(),
                affected_instance_ids: related,
                suggested_safe_next_action:
                    "Review the cross-agent analysis group; no agent configuration is mutated by this plan."
                        .to_string(),
                prerequisites: vec!["Confirm whether this is an intentional cross-agent duplicate or mismatch.".to_string()],
                blockers: vec!["Cross-agent analysis is advisory and not a write affordance.".to_string()],
                deferred: !filters.include_deferred && group.severity == "info",
                evidence_refs: vec![evidence_id],
            }));
        }

        for row in &stale_drift.stale_drift_rows {
            if !remediation_matches_filter(
                &filters,
                Some(row.instance_id.as_str()),
                std::slice::from_ref(&row.instance_id),
            ) {
                continue;
            }
            let skill = detail_by_id.get(row.instance_id.as_str()).copied();
            items.push(remediation_item(RemediationItemInput {
                category: "drift",
                priority_score: row.stale_drift_score,
                severity: if row.stale_drift_score >= 80 {
                    "error"
                } else {
                    "warning"
                },
                title: format!("Review stale/drift signals for `{}`", row.skill_name),
                summary: if row.reasons.is_empty() {
                    format!(
                        "Stale/drift score is {} ({}) from local catalog evidence.",
                        row.stale_drift_score, row.stale_drift_band
                    )
                } else {
                    row.reasons.join(" ")
                },
                detail:
                    "Re-scan, inspect fingerprint/source drift evidence, and decide whether existing manual review paths are needed."
                        .to_string(),
                affected_agent: Some(row.agent.clone()),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: None,
                affected_task: filters.task.clone(),
                affected_instance_ids: vec![row.instance_id.clone()],
                suggested_safe_next_action:
                    "Open stale/drift evidence and refresh local catalog if needed; this planner does not write files or snapshots."
                        .to_string(),
                prerequisites: vec!["Confirm the latest scan reflects the current workspace.".to_string()],
                blockers: row.gap_notes.clone(),
                deferred: false,
                evidence_refs: row.evidence_refs.clone(),
            }));
        }

        for group in &similar.groups {
            if group.routing_ambiguity == "low" && group.coverage_redundancy == "low" {
                continue;
            }
            let related = group
                .members
                .iter()
                .map(|member| member.instance_id.clone())
                .filter(|id| detail_by_id.contains_key(id.as_str()))
                .collect::<Vec<_>>();
            if !remediation_matches_filter(&filters, None, &related) {
                continue;
            }
            let skill = related
                .first()
                .and_then(|id| detail_by_id.get(id.as_str()).copied());
            items.push(remediation_item(RemediationItemInput {
                category: "ambiguity",
                priority_score: group.similarity_score.saturating_sub(10),
                severity: if group.routing_ambiguity == "high" { "warning" } else { "info" },
                title: group.title.clone(),
                summary: group.summary.clone(),
                detail:
                    "Review similar/confusable skills before changing names, descriptions, or enablement through existing safe flows."
                        .to_string(),
                affected_agent: skill.map(|skill| skill.agent.clone()),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: Some(group.canonical_name.clone()),
                affected_task: filters.task.clone(),
                affected_instance_ids: related,
                suggested_safe_next_action:
                    "Open similar skill grouping evidence and decide whether clearer metadata or routing guidance is needed."
                        .to_string(),
                prerequisites: group.why_grouped.iter().take(3).cloned().collect(),
                blockers: vec!["No merge, delete, or auto-disable action is available from remediation.plan.".to_string()],
                deferred: false,
                evidence_refs: group.evidence_refs.clone(),
            }));
        }

        for row in &workspace.readiness_rows {
            if row.status == "ready" {
                continue;
            }
            if !remediation_focus_matches(&filters, "readiness") {
                continue;
            }
            items.push(remediation_item(RemediationItemInput {
                category: "readiness",
                priority_score: 100u8.saturating_sub(row.score),
                severity: if row.status == "blocked" { "error" } else { "warning" },
                title: row.title.clone(),
                summary: row.detail.clone(),
                detail:
                    "Use workspace readiness evidence to choose a manual review path; planner output stays read-only."
                        .to_string(),
                affected_agent: row.agent.clone(),
                affected_skill: None,
                affected_capability: row.capability.clone(),
                affected_task: filters.task.clone(),
                affected_instance_ids: Vec::new(),
                suggested_safe_next_action:
                    "Open workspace readiness details and review the relevant local evidence before taking existing guarded actions."
                        .to_string(),
                prerequisites: Vec::new(),
                blockers: if row.status == "blocked" {
                    vec!["Readiness row is blocked in deterministic local evidence.".to_string()]
                } else {
                    Vec::new()
                },
                deferred: false,
                evidence_refs: row.evidence_refs.clone(),
            }));
        }

        for row in &workspace.capability_rows {
            if row.status == "ready" && row.gap_notes.is_empty() {
                continue;
            }
            if !remediation_focus_matches(&filters, "gap") {
                continue;
            }
            items.push(remediation_item(RemediationItemInput {
                category: "gap",
                priority_score: 100u8.saturating_sub(row.coverage_score),
                severity: if row.status == "blocked" { "error" } else { "warning" },
                title: format!("Close capability gap for `{}`", row.capability),
                summary: if row.gap_notes.is_empty() {
                    format!("Capability coverage is {}.", row.coverage_level)
                } else {
                    row.gap_notes.join(" ")
                },
                detail:
                    "Review capability taxonomy/readiness evidence and decide whether existing skills need clearer metadata or a future safe write flow."
                        .to_string(),
                affected_agent: filters.agent.clone(),
                affected_skill: None,
                affected_capability: Some(row.capability.clone()),
                affected_task: filters.task.clone(),
                affected_instance_ids: Vec::new(),
                suggested_safe_next_action:
                    "Use capability taxonomy and workspace readiness views to inspect coverage; this planner does not create or edit skills."
                        .to_string(),
                prerequisites: vec!["Confirm the expected capability belongs in this workspace.".to_string()],
                blockers: row.blocker_notes.clone(),
                deferred: false,
                evidence_refs: row.evidence_refs.clone(),
            }));
        }

        for item in cleanup.items.iter().take(filters.limit) {
            if !filters.include_deferred && item.priority == "low" {
                continue;
            }
            if !remediation_focus_matches(&filters, "policy") {
                continue;
            }
            let skill = item
                .skill_id
                .as_deref()
                .and_then(|id| detail_by_id.get(id).copied());
            items.push(remediation_item(RemediationItemInput {
                category: "policy",
                priority_score: remediation_score_for_priority(&item.priority),
                severity: remediation_severity(&item.severity),
                title: item.title.clone(),
                summary: item.detail.clone(),
                detail:
                    "Cleanup queue evidence is included as planning context only; queue items remain read-only review entries."
                        .to_string(),
                affected_agent: item.agent.clone(),
                affected_skill: skill.map(remediation_affected_skill),
                affected_capability: None,
                affected_task: filters.task.clone(),
                affected_instance_ids: item.skill_id.iter().cloned().collect(),
                suggested_safe_next_action: item.recommended_next_action_label.clone(),
                prerequisites: vec!["Review the cleanup queue item and its source evidence.".to_string()],
                blockers: vec!["Cleanup queue does not execute cleanup or writes.".to_string()],
                deferred: item.priority == "low",
                evidence_refs: vec![format!("cleanup:{}", item.source_id)],
            }));
        }

        if let Some(readiness) = task_readiness.as_ref() {
            for note in &readiness.missing_gap_notes {
                if !remediation_focus_matches(&filters, "gap") {
                    continue;
                }
                items.push(remediation_item(RemediationItemInput {
                    category: "gap",
                    priority_score: 68,
                    severity: "warning",
                    title: "Address task readiness gap".to_string(),
                    summary: note.clone(),
                    detail:
                        "Task readiness gaps should be reviewed against local candidate evidence before changing skills or config."
                            .to_string(),
                    affected_agent: filters.agent.clone(),
                    affected_skill: None,
                    affected_capability: None,
                    affected_task: filters.task.clone(),
                    affected_instance_ids: Vec::new(),
                    suggested_safe_next_action:
                        "Open task readiness candidates and review missing coverage; no provider or write is triggered."
                            .to_string(),
                    prerequisites: vec!["Confirm task wording and candidate filters.".to_string()],
                    blockers: Vec::new(),
                    deferred: false,
                    evidence_refs: readiness
                        .evidence_references
                        .iter()
                        .take(4)
                        .map(|evidence| evidence.id.clone())
                        .collect(),
                }));
            }
        }

        if let Some(ranking) = route_ranking.as_ref() {
            for warning in &ranking.ambiguity_warnings {
                if !remediation_focus_matches(&filters, "ambiguity") {
                    continue;
                }
                items.push(remediation_item(RemediationItemInput {
                    category: "ambiguity",
                    priority_score: 72,
                    severity: "warning",
                    title: "Reduce routing ambiguity".to_string(),
                    summary: warning.clone(),
                    detail:
                        "Routing ambiguity is advisory; review candidate metadata and benchmark evidence before any manual action."
                            .to_string(),
                    affected_agent: filters.agent.clone(),
                    affected_skill: None,
                    affected_capability: None,
                    affected_task: filters.task.clone(),
                    affected_instance_ids: ranking
                        .route_candidates
                        .iter()
                        .take(3)
                        .map(|candidate| candidate.instance_id.clone())
                        .collect(),
                    suggested_safe_next_action:
                        "Open routing confidence details and inspect top candidates; this planner cannot change routing."
                            .to_string(),
                    prerequisites: vec!["Confirm the intended route for this task.".to_string()],
                    blockers: vec!["No automatic routing change is available.".to_string()],
                    deferred: false,
                    evidence_refs: ranking
                        .evidence_references
                        .iter()
                        .take(4)
                        .map(|evidence| evidence.id.clone())
                        .collect(),
                }));
            }
        }

        let mut gap_notes = workspace.gap_notes.clone();
        gap_notes.extend(taxonomy.gap_notes.iter().cloned());
        gap_notes.extend(stale_drift.gap_notes.iter().cloned());
        gap_notes.extend(similar.gap_notes.iter().cloned());
        gap_notes.extend(aggregation_notes.iter().cloned());
        if details.is_empty() {
            gap_notes.push("No visible local skills matched the remediation filters.".to_string());
        }
        gap_notes.sort();
        gap_notes.dedup();
        gap_notes.truncate(18);

        let mut blocker_notes = workspace.blocker_notes.clone();
        blocker_notes.extend(taxonomy.blocker_notes.iter().cloned());
        blocker_notes.extend(stale_drift.blocker_notes.iter().cloned());
        blocker_notes.extend(similar.blocker_notes.iter().cloned());
        blocker_notes.extend(
            diagnostics
                .iter()
                .filter(|diagnostic| {
                    diagnostic.status == "blocked"
                        || diagnostic.access.writable_status == "blocked"
                })
                .map(|diagnostic| {
                    format!(
                        "{} adapter has status={} and writable_status={}; remediation stays read-only.",
                        diagnostic.display_name,
                        diagnostic.status,
                        diagnostic.access.writable_status
                    )
                }),
        );
        blocker_notes.sort();
        blocker_notes.dedup();
        blocker_notes.truncate(18);

        let total_item_count = items.len();
        let items = remediation_sorted_items(items, &filters);
        let returned_item_count = items.len();
        let summary = remediation_plan_summary(total_item_count, returned_item_count, &items);
        let priority_rows = remediation_priority_rows(&items);
        let prompt_instance_ids = items
            .iter()
            .flat_map(|item| item.affected_instance_ids.iter().cloned())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !items.is_empty();

        Ok(RemediationPlanResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            plan_items: items,
            priority_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence_by_id.into_values().collect(),
            prompt_request: RemediationPlanPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "remediation_plan",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::RemediationPlan,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic remediation plan items using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed remediation explanation must be requested through prompt preview and explicit confirmation; remediation.plan never sends provider traffic and remains copy-only."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local evidence produces remediation plan items."
                        .to_string()
                },
            },
            aggregation: aggregation_runtime_metadata(AggregationRuntimeInput {
                started_at,
                timeout_ms: REMEDIATION_AGGREGATION_TIMEOUT_MS,
                limit: filters.limit,
                scanned_count: details.len(),
                total_count: total_detail_candidate_count,
                completed_stages: vec![
                    "catalog",
                    "detail-scan",
                    "finding-analysis",
                    "cleanup-queue",
                    "capability-taxonomy",
                    "stale-drift",
                    "similar-skills",
                    "workspace-readiness",
                    "task-readiness",
                    "routing",
                ],
                skipped_stages,
                blocker_codes,
                fallback_used: !aggregation_notes.is_empty(),
                notes: aggregation_notes,
            }),
            safety_flags: remediation_plan_safety_flags(),
        })
    }

    pub fn preview_remediation_drafts(
        &self,
        params: RemediationPreviewDraftsParams,
    ) -> Result<RemediationPreviewDraftsResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "remediation.previewDrafts limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = remediation_preview_drafts_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_remediation_preview_drafts_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let details = skills
            .iter()
            .filter(|skill| {
                agent_matches(filters.agent.as_deref(), Some(skill.agent.as_str()))
                    && (filters.skill_ids.is_empty() || filters.skill_ids.contains(&skill.id))
            })
            .filter_map(|skill| catalog.get_skill_detail(&skill.id).ok().flatten())
            .collect::<Vec<_>>();
        let detail_by_id = details
            .iter()
            .map(|detail| (detail.id.as_str(), detail))
            .collect::<BTreeMap<_, _>>();
        let visible_skill_ids = details
            .iter()
            .map(|detail| detail.id.as_str())
            .collect::<BTreeSet<_>>();

        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let plan = self.plan_remediation(RemediationPlanParams {
            agent: filters.agent.clone(),
            task: filters.task.clone(),
            project_root: None,
            focus: None,
            focus_areas: Vec::new(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
            candidate_instance_ids: filters.skill_ids.clone(),
            include_deferred: true,
        })?;

        let mut evidence_by_id = plan
            .evidence_references
            .iter()
            .map(|evidence| (evidence.id.clone(), evidence.clone()))
            .collect::<BTreeMap<_, _>>();
        let mut draft_items = Vec::new();
        for finding in &findings {
            if finding.suppressed || finding.triage_status.eq_ignore_ascii_case("ignored") {
                continue;
            }
            if !filters.finding_ids.is_empty() && !filters.finding_ids.contains(&finding.id) {
                continue;
            }
            let Some(instance_id) = finding.instance_id.as_deref() else {
                continue;
            };
            if !visible_skill_ids.contains(instance_id) {
                continue;
            }
            let Some(skill) = detail_by_id.get(instance_id).copied() else {
                continue;
            };
            let Some(draft_type) = remediation_draft_type_for_rule(&finding.rule_id) else {
                continue;
            };
            if !remediation_preview_draft_type_matches(&filters, draft_type) {
                continue;
            }
            let evidence_id = remediation_insert_evidence(
                &mut evidence_by_id,
                "finding",
                &finding.id,
                format!(
                    "{} finding `{}`: {}",
                    redact_for_llm_preview(&finding.effective_severity),
                    redact_for_llm_preview(&finding.rule_id),
                    redact_for_llm_preview(&finding.message)
                ),
                Some(finding.effective_severity.clone()),
                Some(skill.id.clone()),
            );
            draft_items.push(remediation_draft_item_for_finding(
                skill,
                finding,
                draft_type,
                vec![evidence_id],
            ));
        }

        if filters.include_policy_drafts
            && remediation_preview_draft_type_matches(&filters, "policy")
        {
            for conflict in &conflicts {
                let related = conflict
                    .instance_ids
                    .iter()
                    .filter(|id| detail_by_id.contains_key(id.as_str()))
                    .cloned()
                    .collect::<Vec<_>>();
                if related.is_empty() {
                    continue;
                }
                let skill = related
                    .first()
                    .and_then(|id| detail_by_id.get(id.as_str()).copied());
                let evidence_id = remediation_insert_evidence(
                    &mut evidence_by_id,
                    "conflict",
                    &conflict.id,
                    format!(
                        "Same-agent conflict `{}` affects {} local instance(s).",
                        redact_for_llm_preview(&conflict.reason),
                        conflict.instance_ids.len()
                    ),
                    Some("warning".to_string()),
                    skill.map(|skill| skill.id.clone()),
                );
                draft_items.push(remediation_policy_draft_item(RemediationPolicyDraftInput {
                    title: "Clarify duplicate skill policy".to_string(),
                    draft_type: "policy",
                    skill,
                    finding_id: Some(conflict.id.clone()),
                    rule_id: None,
                    proposed_text: format!(
                        "Prefer the reviewed active skill for `{}` and keep duplicate/confusable variants disabled or clearly scoped until their provenance is reconciled.",
                        skill
                            .map(|skill| redact_for_llm_preview(&skill.name))
                            .unwrap_or_else(|| "the affected skill group".to_string())
                    ),
                    rationale: format!(
                        "Conflict `{}` indicates ambiguous runtime selection.",
                        redact_for_llm_preview(&conflict.reason)
                    ),
                    evidence_refs: vec![evidence_id],
                }));
            }

            for group in &analysis.groups {
                if !group.kind.contains("enabled") && !group.kind.contains("overlap") {
                    continue;
                }
                let related = group
                    .instance_ids
                    .iter()
                    .filter(|id| detail_by_id.contains_key(id.as_str()))
                    .cloned()
                    .collect::<Vec<_>>();
                if related.is_empty() {
                    continue;
                }
                let skill = related
                    .first()
                    .and_then(|id| detail_by_id.get(id.as_str()).copied());
                let evidence_id = remediation_insert_evidence(
                    &mut evidence_by_id,
                    "analysis",
                    &group.id,
                    format!(
                        "{} analysis `{}`: {}",
                        redact_for_llm_preview(&group.severity),
                        redact_for_llm_preview(&group.kind),
                        redact_for_llm_preview(&group.title)
                    ),
                    Some(group.severity.clone()),
                    skill.map(|skill| skill.id.clone()),
                );
                draft_items.push(remediation_policy_draft_item(RemediationPolicyDraftInput {
                    title: group.title.clone(),
                    draft_type: "policy",
                    skill,
                    finding_id: None,
                    rule_id: Some(group.id.clone()),
                    proposed_text: format!(
                        "Document whether `{}` is intentionally shared across agents or should be narrowed by agent/scope before enabling it for task routing.",
                        skill
                            .map(|skill| redact_for_llm_preview(&skill.name))
                            .unwrap_or_else(|| "this skill group".to_string())
                    ),
                    rationale: redact_for_llm_preview(&group.explanation),
                    evidence_refs: vec![evidence_id],
                }));
            }
        }

        if filters.include_policy_drafts
            && remediation_preview_draft_type_matches(&filters, "policy")
        {
            for plan_item in &plan.plan_items {
                if !matches!(plan_item.category, "policy" | "ambiguity") {
                    continue;
                }
                draft_items.push(remediation_policy_draft_item_from_plan(plan_item));
            }
        }

        let mut gap_notes = plan.gap_notes.clone();
        if details.is_empty() {
            gap_notes
                .push("No visible local skills matched the draft preview filters.".to_string());
        }
        if draft_items.is_empty() {
            gap_notes.push(
                "No local findings or remediation signals matched the requested draft types."
                    .to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();
        gap_notes.truncate(16);

        let mut blocker_notes = plan.blocker_notes.clone();
        blocker_notes.push(
            "Draft previews are copy-only; no Apply path is available from remediation.previewDrafts."
                .to_string(),
        );
        blocker_notes.sort();
        blocker_notes.dedup();
        blocker_notes.truncate(16);

        let total_draft_count = draft_items.len();
        let draft_items = remediation_sorted_draft_items(draft_items, &filters);
        let returned_draft_count = draft_items.len();
        let summary = remediation_preview_drafts_summary(
            total_draft_count,
            returned_draft_count,
            &draft_items,
        );
        let prompt_instance_ids = draft_items
            .iter()
            .filter_map(|item| {
                item.affected_skill
                    .as_ref()
                    .map(|skill| skill.instance_id.clone())
            })
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !draft_items.is_empty();

        Ok(RemediationPreviewDraftsResult {
            generated_by: "local-v2.57",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            draft_items,
            gap_notes,
            blocker_notes,
            evidence_references: evidence_by_id.into_values().collect(),
            prompt_request: RemediationPreviewDraftsPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "remediation_preview_drafts",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::RemediationPreviewDrafts,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic fix preview drafts using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed draft explanation must be requested through prompt preview and explicit confirmation; remediation.previewDrafts never sends provider traffic and remains copy-only."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local evidence produces fix preview drafts."
                        .to_string()
                },
            },
            safety_flags: remediation_preview_drafts_safety_flags(),
        })
    }

    pub fn preview_remediation_impact(
        &self,
        params: RemediationPreviewImpactParams,
    ) -> Result<RemediationPreviewImpactResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "remediation.previewImpact limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = remediation_preview_impact_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_remediation_preview_impact_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let mut selected_ids = filters
            .skill_ids
            .iter()
            .chain(filters.candidate_instance_ids.iter())
            .cloned()
            .collect::<Vec<_>>();
        selected_ids.sort();
        selected_ids.dedup();
        let details = skills
            .iter()
            .filter(|skill| {
                agent_matches(filters.agent.as_deref(), Some(skill.agent.as_str()))
                    && (selected_ids.is_empty() || selected_ids.contains(&skill.id))
            })
            .filter_map(|skill| catalog.get_skill_detail(&skill.id).ok().flatten())
            .filter(|detail| {
                workspace_detail_matches(params.project_root.as_deref().map(Path::new), detail)
            })
            .collect::<Vec<_>>();
        let visible_ids = details
            .iter()
            .map(|detail| detail.id.as_str())
            .collect::<BTreeSet<_>>();

        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let plan = self.plan_remediation(RemediationPlanParams {
            agent: filters.agent.clone(),
            task: filters.task.clone(),
            project_root: params.project_root.clone(),
            focus: None,
            focus_areas: Vec::new(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
            candidate_instance_ids: selected_ids.clone(),
            include_deferred: true,
        })?;
        let drafts = self.preview_remediation_drafts(RemediationPreviewDraftsParams {
            agent: filters.agent.clone(),
            task: filters.task.clone(),
            skill_ids: selected_ids.clone(),
            finding_ids: Vec::new(),
            draft_types: Vec::new(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
            include_policy_drafts: true,
        })?;
        let task_readiness = if filters.include_task_impact {
            filters
                .task
                .as_ref()
                .map(|task| {
                    self.check_task_readiness(TaskReadinessParams {
                        task: task.clone(),
                        agent: filters.agent.clone(),
                        candidate_instance_ids: selected_ids.clone(),
                        limit: Some(filters.limit.min(20)),
                    })
                })
                .transpose()?
        } else {
            None
        };
        let routing = if filters.include_task_impact {
            filters
                .task
                .as_ref()
                .map(|task| {
                    self.rank_skill_routes(RankSkillRoutesParams {
                        task: task.clone(),
                        agent: filters.agent.clone(),
                        candidate_instance_ids: selected_ids.clone(),
                        limit: Some(filters.limit.min(20)),
                    })
                })
                .transpose()?
        } else {
            None
        };

        let mut evidence_by_id = BTreeMap::new();
        for evidence in plan
            .evidence_references
            .iter()
            .chain(drafts.evidence_references.iter())
        {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert_with(|| evidence.clone());
        }
        if let Some(readiness) = task_readiness.as_ref() {
            for evidence in &readiness.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }
        if let Some(routing) = routing.as_ref() {
            for evidence in &routing.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }

        let mut skill_rows = Vec::new();
        for detail in &details {
            let finding_count = findings
                .iter()
                .filter(|finding| finding.instance_id.as_deref() == Some(detail.id.as_str()))
                .count();
            let conflict_count = conflicts
                .iter()
                .filter(|conflict| conflict.instance_ids.iter().any(|id| id == &detail.id))
                .count();
            let analysis_count = analysis
                .groups
                .iter()
                .filter(|group| group.instance_ids.iter().any(|id| id == &detail.id))
                .count();
            let evidence_id = remediation_insert_evidence(
                &mut evidence_by_id,
                "skill",
                &detail.id,
                format!(
                    "{} skill `{}` impact preview candidate.",
                    redact_for_llm_preview(&detail.agent),
                    redact_for_llm_preview(&detail.name)
                ),
                None,
                Some(detail.id.clone()),
            );
            skill_rows.push(RemediationSkillImpactRow {
                affected_skill: remediation_affected_skill(detail),
                action_intent: filters.action.clone(),
                expected_direction: remediation_impact_direction_for_skill(&filters.action, detail),
                enabled_before: detail.enabled,
                enabled_after_estimate: remediation_estimated_enabled_after(
                    &filters.action,
                    detail,
                ),
                finding_count,
                conflict_count,
                analysis_count,
                notes: remediation_skill_impact_notes(&filters.action, detail),
                evidence_refs: vec![evidence_id],
            });
        }

        let mut risk_delta_rows = Vec::new();
        if filters.include_risk_impact {
            for finding in &findings {
                if finding.suppressed || finding.triage_status.eq_ignore_ascii_case("ignored") {
                    continue;
                }
                let related = remediation_related_instances_for_finding(finding, &visible_ids);
                if related.is_empty() {
                    continue;
                }
                if !filters.plan_item_ids.is_empty()
                    && !filters
                        .plan_item_ids
                        .iter()
                        .any(|id| finding.id.contains(id))
                {
                    continue;
                }
                let evidence_id = remediation_insert_evidence(
                    &mut evidence_by_id,
                    "finding",
                    &finding.id,
                    format!(
                        "{} finding `{}`: {}",
                        redact_for_llm_preview(&finding.effective_severity),
                        redact_for_llm_preview(&finding.rule_id),
                        redact_for_llm_preview(&finding.message)
                    ),
                    Some(finding.effective_severity.clone()),
                    finding.instance_id.clone(),
                );
                risk_delta_rows.push(RemediationRiskDeltaRow {
                    id: format!("risk_delta:{}", finding.id),
                    source: "finding",
                    severity: finding.effective_severity.clone(),
                    title: redact_for_llm_preview(&finding.message),
                    current_risk: remediation_risk_band(&finding.effective_severity),
                    expected_risk_after: remediation_expected_risk_after(
                        &filters.action,
                        &finding.effective_severity,
                    ),
                    expected_direction: remediation_impact_direction_for_action(&filters.action),
                    affected_instance_ids: related,
                    blockers: remediation_blockers_for_finding(finding),
                    evidence_refs: vec![evidence_id],
                });
            }
            risk_delta_rows.truncate(filters.limit);
        }

        let snapshot_rollback_plan_rows =
            if filters.include_snapshot_plan || filters.include_rollback_plan {
                remediation_snapshot_rollback_rows(
                    &filters,
                    &details,
                    &diagnostics,
                    &mut evidence_by_id,
                )
            } else {
                Vec::new()
            };
        let agent_impact_rows = remediation_agent_impact_rows(&filters, &skill_rows, &diagnostics);
        let task_impact_rows =
            remediation_task_impact_rows(&filters, task_readiness.as_ref(), routing.as_ref());
        let mut impact_rows = remediation_top_level_impact_rows(
            &filters,
            &skill_rows,
            &agent_impact_rows,
            &task_impact_rows,
            &risk_delta_rows,
            &snapshot_rollback_plan_rows,
        );
        impact_rows.truncate(filters.limit);

        let mut gap_notes = plan.gap_notes.clone();
        gap_notes.extend(drafts.gap_notes.clone());
        if details.is_empty() {
            gap_notes
                .push("No visible local skills matched the impact preview filters.".to_string());
        }
        if impact_rows.is_empty() {
            gap_notes.push(
                "No deterministic local impact rows matched the requested preview.".to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();
        gap_notes.truncate(18);

        let mut blocker_notes = plan.blocker_notes.clone();
        blocker_notes.extend(drafts.blocker_notes.clone());
        blocker_notes.push(
            "Impact preview is plan-only; it does not apply actions, create snapshots, roll back configs, or edit skill files."
                .to_string(),
        );
        blocker_notes.extend(
            snapshot_rollback_plan_rows
                .iter()
                .filter_map(|row| row.blocked_reason.clone()),
        );
        blocker_notes.sort();
        blocker_notes.dedup();
        blocker_notes.truncate(18);

        let summary = remediation_preview_impact_summary(
            &impact_rows,
            &task_impact_rows,
            &agent_impact_rows,
            &skill_rows,
            &risk_delta_rows,
            &snapshot_rollback_plan_rows,
            blocker_notes.len(),
        );
        let prompt_instance_ids = skill_rows
            .iter()
            .map(|row| row.affected_skill.instance_id.clone())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !impact_rows.is_empty();

        Ok(RemediationPreviewImpactResult {
            generated_by: "local-v2.58",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            impact_rows,
            task_impact_rows,
            agent_impact_rows,
            skill_impact_rows: skill_rows.into_iter().take(filters.limit).collect(),
            risk_delta_rows,
            snapshot_rollback_plan_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence_by_id.into_values().collect(),
            prompt_request: RemediationPreviewImpactPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "remediation_preview_impact",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::RemediationPreviewImpact,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic remediation impact preview using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed impact explanation must be requested through prompt preview and explicit confirmation; remediation.previewImpact never sends provider traffic and remains copy-only."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local evidence produces impact rows."
                        .to_string()
                },
            },
            safety_flags: remediation_preview_impact_safety_flags(),
        })
    }

    pub fn batch_review_remediation(
        &self,
        params: RemediationBatchReviewParams,
    ) -> Result<RemediationBatchReviewResult, ServiceError> {
        let started_at = Instant::now();
        let budget = Duration::from_millis(REMEDIATION_AGGREGATION_TIMEOUT_MS);
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "remediation.batchReview limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = remediation_batch_review_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_remediation_batch_review_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let details = skills
            .iter()
            .filter(|skill| {
                agent_matches(filters.agent.as_deref(), Some(skill.agent.as_str()))
                    && (filters.candidate_instance_ids.is_empty()
                        || filters.candidate_instance_ids.contains(&skill.id))
            })
            .filter_map(|skill| catalog.get_skill_detail(&skill.id).ok().flatten())
            .filter(|detail| {
                workspace_detail_matches(params.project_root.as_deref().map(Path::new), detail)
            })
            .collect::<Vec<_>>();
        let detail_by_id = details
            .iter()
            .map(|detail| (detail.id.as_str(), detail))
            .collect::<BTreeMap<_, _>>();
        let selected_ids = if filters.candidate_instance_ids.is_empty() {
            details
                .iter()
                .map(|detail| detail.id.clone())
                .collect::<Vec<_>>()
        } else {
            filters.candidate_instance_ids.clone()
        };

        let plan = self.plan_remediation(RemediationPlanParams {
            agent: filters.agent.clone(),
            task: filters.task.clone(),
            project_root: params.project_root.clone(),
            focus: None,
            focus_areas: Vec::new(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
            candidate_instance_ids: selected_ids.clone(),
            include_deferred: true,
        })?;
        let mut aggregation_notes = Vec::new();
        let mut skipped_stages = Vec::new();
        let mut blocker_codes = Vec::new();
        let drafts = if !task_cockpit_budget_reached(started_at, budget)
            && !plan.aggregation.timed_out
        {
            Some(
                self.preview_remediation_drafts(RemediationPreviewDraftsParams {
                    agent: filters.agent.clone(),
                    task: filters.task.clone(),
                    skill_ids: selected_ids.clone(),
                    finding_ids: Vec::new(),
                    draft_types: Vec::new(),
                    limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
                    include_policy_drafts: true,
                })?,
            )
        } else {
            skipped_stages.push("fix-preview-drafts");
            blocker_codes.push("batch-review-budget");
            aggregation_notes.push(
                "Batch review returned plan/cleanup rows and skipped fix preview drafts after reaching the bounded aggregation budget."
                    .to_string(),
            );
            None
        };
        let impact = if !task_cockpit_budget_reached(started_at, budget)
            && !plan.aggregation.timed_out
        {
            Some(
                self.preview_remediation_impact(RemediationPreviewImpactParams {
                    action: Some("review".to_string()),
                    task: filters.task.clone(),
                    agent: filters.agent.clone(),
                    project_root: params.project_root.clone(),
                    skill_ids: selected_ids.clone(),
                    candidate_instance_ids: Vec::new(),
                    draft_ids: Vec::new(),
                    plan_item_ids: Vec::new(),
                    limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
                    include_snapshot_plan: true,
                    include_rollback_plan: true,
                    include_risk_impact: true,
                    include_task_impact: filters.task.is_some(),
                })?,
            )
        } else {
            skipped_stages.push("impact-preview");
            blocker_codes.push("batch-review-budget");
            aggregation_notes.push(
                    "Batch review skipped impact preview after reaching the bounded aggregation budget."
                        .to_string(),
                );
            None
        };
        let cleanup = self.cleanup_list_queue(CleanupListQueueParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit.saturating_mul(2).max(filters.limit)),
        })?;

        let mut evidence_by_id = BTreeMap::new();
        for evidence in &plan.evidence_references {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert_with(|| evidence.clone());
        }
        if let Some(drafts) = drafts.as_ref() {
            for evidence in &drafts.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }
        if let Some(impact) = impact.as_ref() {
            for evidence in &impact.evidence_references {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert_with(|| evidence.clone());
            }
        }

        let mut items = Vec::new();
        for item in &plan.plan_items {
            items.push(remediation_batch_review_item_from_plan(
                item,
                &filters,
                &detail_by_id,
            ));
        }
        if let Some(drafts) = drafts.as_ref() {
            for item in &drafts.draft_items {
                items.push(remediation_batch_review_item_from_draft(item, &filters));
            }
        }
        if let Some(impact) = impact.as_ref() {
            for row in &impact.impact_rows {
                items.push(remediation_batch_review_item_from_impact(row, &filters));
            }
        }
        for item in &cleanup.items {
            items.push(remediation_batch_review_item_from_cleanup(
                item,
                &filters,
                &detail_by_id,
            ));
        }

        if details.is_empty() {
            items.retain(|item| item.affected_instance_ids.is_empty());
        }
        items.retain(|item| remediation_batch_review_item_matches(&filters, item));

        let total_item_count = items.len();
        let items = remediation_sorted_batch_review_items(items, filters.limit);
        let review_groups = remediation_batch_review_groups(&filters, &items);
        let recommended_next_step_labels = remediation_batch_review_next_steps(&items);

        let mut gap_notes = plan.gap_notes.clone();
        if let Some(drafts) = drafts.as_ref() {
            gap_notes.extend(drafts.gap_notes.clone());
        }
        if let Some(impact) = impact.as_ref() {
            gap_notes.extend(impact.gap_notes.clone());
        }
        gap_notes.extend(aggregation_notes.iter().cloned());
        if details.is_empty() {
            gap_notes.push("No visible local skills matched the batch review filters.".to_string());
        }
        if items.is_empty() {
            gap_notes.push(
                "No deterministic local review items matched the selected batch filters."
                    .to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();
        gap_notes.truncate(18);

        let mut blocker_notes = plan.blocker_notes.clone();
        if let Some(drafts) = drafts.as_ref() {
            blocker_notes.extend(drafts.blocker_notes.clone());
        }
        if let Some(impact) = impact.as_ref() {
            blocker_notes.extend(impact.blocker_notes.clone());
        }
        blocker_notes.extend(aggregation_notes.iter().cloned());
        blocker_notes.push(
            "Batch review is read-only; existing preview-first write flows may only be opened separately after explicit user confirmation."
                .to_string(),
        );
        blocker_notes.push(
            "Writable capability, snapshot, rollback, and triage states are warning context only; remediation.batchReview does not apply actions."
                .to_string(),
        );
        blocker_notes.sort();
        blocker_notes.dedup();
        blocker_notes.truncate(18);

        let prompt_instance_ids = items
            .iter()
            .flat_map(|item| item.affected_instance_ids.iter().cloned())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !items.is_empty();
        let summary =
            remediation_batch_review_summary(total_item_count, &items, &review_groups, &filters);
        let mut completed_stages = vec![
            "catalog",
            "detail-scan",
            "remediation-plan",
            "cleanup-queue",
            "batch-grouping",
        ];
        if drafts.is_some() {
            completed_stages.push("fix-preview-drafts");
        }
        if impact.is_some() {
            completed_stages.push("impact-preview");
        }

        Ok(RemediationBatchReviewResult {
            generated_by: "local-v2.59",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            review_groups,
            review_items: items,
            recommended_next_step_labels,
            gap_notes,
            blocker_notes,
            evidence_references: evidence_by_id.into_values().collect(),
            prompt_request: RemediationBatchReviewPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "remediation_batch_review",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::RemediationBatchReview,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic batch review workflow items using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed batch review explanation must be requested through prompt preview and explicit confirmation; remediation.batchReview never sends provider traffic and remains copy-only."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local evidence produces batch review items."
                        .to_string()
                },
            },
            aggregation: aggregation_runtime_metadata(AggregationRuntimeInput {
                started_at,
                timeout_ms: REMEDIATION_AGGREGATION_TIMEOUT_MS,
                limit: filters.limit,
                scanned_count: details.len(),
                total_count: details.len(),
                completed_stages,
                skipped_stages,
                blocker_codes,
                fallback_used: !aggregation_notes.is_empty(),
                notes: aggregation_notes,
            }),
            safety_flags: remediation_batch_review_safety_flags(),
        })
    }

    pub fn list_remediation_history(
        &self,
        params: RemediationHistoryListParams,
    ) -> Result<RemediationHistoryListResult, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let limit = params.limit.unwrap_or(50).clamp(1, 500);
        let filters = RemediationHistoryFilters {
            agent: params
                .agent
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| redact_string(&redact_for_llm_preview(value), &roots)),
            status: params
                .status
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(normalize_history_token),
            decision: params
                .decision
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(normalize_history_token),
            source_item_ref: params
                .source_item_ref
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| redact_string(&redact_for_llm_preview(value), &roots)),
            recurrence_key: params
                .recurrence_key
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| redact_string(&redact_for_llm_preview(value), &roots)),
            limit,
            include_recurrence_rows: params.include_recurrence_rows,
        };
        let records = self.load_remediation_history()?;
        let mut filtered = records
            .iter()
            .filter(|record| remediation_history_matches(&filters, record))
            .cloned()
            .collect::<Vec<_>>();
        let total_count = filtered.len();
        filtered.truncate(limit);
        let summary = remediation_history_summary(total_count, &filtered);
        let recurrence_rows = if filters.include_recurrence_rows {
            remediation_history_recurrence_rows(&filtered)
        } else {
            Vec::new()
        };
        let mut blocker_notes = Vec::new();
        if !self.remediation_history_path().exists() {
            blocker_notes.push("No app-local remediation history records are saved.".to_string());
        }
        if filtered.is_empty() {
            blocker_notes.push(
                "No remediation history records matched the selected local filters.".to_string(),
            );
        }
        blocker_notes.push(
            "Remediation history is local metadata only; listHistory does not apply fixes, mutate triage, create snapshots, or send provider requests."
                .to_string(),
        );

        Ok(RemediationHistoryListResult {
            generated_by: "local-v2.60",
            filters,
            summary,
            records: filtered,
            recurrence_rows,
            blocker_notes,
            app_local_only: true,
            history_file: "remediation-history.json",
            provider_request_sent: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
            safety_flags: remediation_history_safety_flags(),
        })
    }

    pub fn record_remediation_history(
        &self,
        params: RemediationHistoryRecordParams,
    ) -> Result<RemediationHistoryRecordResult, ServiceError> {
        let decision = normalize_history_token(params.decision.trim());
        if decision.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "remediation.recordHistory requires a non-empty decision".to_string(),
            ));
        }
        let status = params
            .status
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(normalize_history_token)
            .unwrap_or_else(|| "recorded".to_string());
        if status.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "remediation.recordHistory requires a valid status".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&roots);
        let now = unix_timestamp_millis();
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 180))
            .unwrap_or_else(|| format!("Remediation decision: {decision}"));
        let source_kind = params
            .source_kind
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 80))
            .unwrap_or_else(|| "local-remediation-review".to_string());
        let source_method = params
            .source_method
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 120));
        let source_item_refs =
            redact_history_string_list(params.source_item_refs, &mut redactor, 160, 40);
        let batch_review_item_ids =
            redact_history_string_list(params.batch_review_item_ids, &mut redactor, 160, 40);
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 80));
        let workspace = params
            .workspace
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 220));
        let task = params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 280));
        let rule_ids = redact_history_string_list(params.rule_ids, &mut redactor, 120, 30);
        let risk_levels = normalize_string_list(
            params
                .risk_levels
                .into_iter()
                .map(|value| normalize_history_token(&value))
                .filter(|value| !value.is_empty())
                .collect(),
        );
        let recurrence_key = params
            .recurrence_key
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 180));
        let reopened_from_ids =
            redact_history_string_list(params.reopened_from_ids, &mut redactor, 120, 40);
        let readiness_improvement_notes =
            redact_history_string_list(params.readiness_improvement_notes, &mut redactor, 240, 20);
        let routing_improvement_notes =
            redact_history_string_list(params.routing_improvement_notes, &mut redactor, 240, 20);
        let blocker_notes =
            redact_history_string_list(params.blocker_notes, &mut redactor, 240, 20);
        let gap_notes = redact_history_string_list(params.gap_notes, &mut redactor, 240, 20);
        let evidence_refs =
            redact_history_string_list(params.evidence_refs, &mut redactor, 180, 80);
        let notes = params
            .notes
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 500));
        let redaction_summary = remediation_history_redaction_summary_from(redactor.summary());
        let id = params
            .id
            .as_deref()
            .map(sanitize_remediation_history_id)
            .filter(|id| !id.is_empty())
            .unwrap_or_else(|| generated_remediation_history_id(&title, &decision, now));
        let reopened = params.reopened.unwrap_or(false) || !reopened_from_ids.is_empty();

        let mut records = self.load_remediation_history()?;
        let created = !records.iter().any(|record| record.id == id);
        let record = RemediationHistoryRecord {
            id: id.clone(),
            title,
            decision,
            status,
            source_kind,
            source_method,
            source_item_refs,
            batch_review_item_ids,
            agent,
            workspace,
            task,
            rule_ids,
            risk_levels,
            recurrence_key,
            recurrence_count_marker: params.recurrence_count_marker,
            reopened,
            reopened_from_ids,
            readiness_improvement_notes,
            routing_improvement_notes,
            blocker_notes,
            gap_notes,
            evidence_refs,
            notes,
            redaction_summary,
            created_at: if created {
                now
            } else {
                records
                    .iter()
                    .find(|record| record.id == id)
                    .map(|record| record.created_at)
                    .unwrap_or(now)
            },
            updated_at: now,
            safety_flags: remediation_history_safety_flags(),
        };
        records.retain(|existing| existing.id != id);
        records.push(record.clone());
        self.save_remediation_history(&records)?;

        Ok(RemediationHistoryRecordResult {
            generated_by: "local-v2.60",
            record,
            created,
            count: records.len(),
            app_local_only: true,
            history_file: "remediation-history.json",
            provider_request_sent: false,
            skill_files_mutated: false,
            agent_config_mutated: false,
            snapshot_created: false,
            rollback_performed: false,
            triage_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
        })
    }

    pub fn delete_remediation_history(
        &self,
        params: RemediationHistoryDeleteParams,
    ) -> Result<RemediationHistoryDeleteResult, ServiceError> {
        let id = sanitize_remediation_history_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "remediation.deleteHistory requires a history id".to_string(),
            ));
        }
        let mut records = self.load_remediation_history()?;
        let before = records.len();
        records.retain(|record| record.id != id);
        let deleted = records.len() != before;
        if deleted {
            self.save_remediation_history(&records)?;
        }
        Ok(RemediationHistoryDeleteResult {
            history_id: id,
            deleted,
            remaining_count: records.len(),
            app_local_only: true,
            provider_request_sent: false,
            skill_files_mutated: false,
            agent_config_mutated: false,
            snapshot_created: false,
            rollback_performed: false,
            triage_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
        })
    }
}
