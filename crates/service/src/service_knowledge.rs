use super::*;

impl ServiceHost {
    pub fn score_skill_quality(
        &self,
        params: ScoreSkillQualityParams,
    ) -> Result<SkillQualityScoreResult, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Err(ServiceError::SkillNotFound(params.instance_id));
        };
        let skill = catalog
            .get_skill_detail(&params.instance_id)?
            .ok_or_else(|| ServiceError::SkillNotFound(params.instance_id.clone()))?;
        if let Some(agent) = params.agent.as_deref().filter(|agent| !agent.is_empty()) {
            if agent != skill.agent {
                return Err(ServiceError::InvalidRequest(format!(
                    "analysis.scoreSkillQuality agent `{agent}` does not match skill agent `{}`",
                    skill.agent
                )));
            }
        }
        if let Some(definition_id) = params
            .definition_id
            .as_deref()
            .filter(|definition_id| !definition_id.is_empty())
        {
            if definition_id != skill.definition_id {
                return Err(ServiceError::InvalidRequest(format!(
                    "analysis.scoreSkillQuality definition_id `{definition_id}` does not match skill definition `{}`",
                    skill.definition_id
                )));
            }
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let findings = catalog
            .list_rule_findings()?
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect::<Vec<_>>();
        let conflicts = catalog
            .list_conflict_groups()?
            .into_iter()
            .filter(|conflict| {
                conflict.definition_id == skill.definition_id
                    || conflict
                        .instance_ids
                        .iter()
                        .any(|instance_id| instance_id == &skill.id)
            })
            .collect::<Vec<_>>();
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let related_analysis = analysis
            .groups
            .into_iter()
            .filter(|group| {
                group
                    .instance_ids
                    .iter()
                    .any(|instance_id| instance_id == &skill.id)
            })
            .collect::<Vec<_>>();
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx)
            .into_iter()
            .find(|diagnostic| diagnostic.agent == skill.agent);

        let mut evidence = Vec::new();
        let skill_evidence_id = push_quality_evidence(
            &mut evidence,
            "skill",
            &skill.id,
            format!(
                "Catalog metadata for `{}` ({}, {})",
                redact_for_llm_preview(&skill.name),
                redact_for_llm_preview(&skill.agent),
                redact_for_llm_preview(&skill.scope)
            ),
            None,
            Some(skill.id.clone()),
        );
        let definition_evidence_id = push_quality_evidence(
            &mut evidence,
            "definition",
            &skill.definition_id,
            format!(
                "Definition identity `{}`",
                redact_for_llm_preview(&skill.definition_id)
            ),
            None,
            Some(skill.id.clone()),
        );

        let mut components = Vec::new();
        let mut reasons = Vec::new();
        let mut risk_notes = Vec::new();
        let mut suggestions = Vec::new();

        let (metadata_score, metadata_summary, metadata_suggestions) =
            quality_metadata_component(&skill);
        reasons.push(metadata_summary.clone());
        suggestions.extend(metadata_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "metadata_completeness",
            label: "Metadata completeness",
            score: metadata_score,
            max_score: 25,
            summary: metadata_summary,
            evidence_refs: vec![skill_evidence_id.clone(), definition_evidence_id],
        });

        let (permission_score, permission_summary, permission_risks, permission_suggestions) =
            quality_permission_component(&skill);
        reasons.push(permission_summary.clone());
        risk_notes.extend(permission_risks);
        suggestions.extend(permission_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "permission_clarity",
            label: "Permission clarity",
            score: permission_score,
            max_score: 20,
            summary: permission_summary,
            evidence_refs: vec![skill_evidence_id.clone()],
        });

        let mut finding_refs = Vec::new();
        for finding in &findings {
            let evidence_id = push_quality_evidence(
                &mut evidence,
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
            finding_refs.push(evidence_id.clone());
            if let Some(suggestion) = finding.suggestion.as_deref() {
                suggestions.push(SkillQualitySuggestion {
                    priority: quality_priority_for_severity(&finding.effective_severity),
                    title: format!("Address `{}`", redact_for_llm_preview(&finding.rule_id)),
                    detail: redact_for_llm_preview(suggestion),
                    evidence_refs: vec![evidence_id],
                });
            }
        }
        let (risk_score, risk_summary, finding_risks, body_suggestions) =
            quality_risk_component(&skill, &findings);
        reasons.push(risk_summary.clone());
        risk_notes.extend(finding_risks);
        suggestions.extend(body_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "risk_findings",
            label: "Findings and risky signals",
            score: risk_score,
            max_score: 25,
            summary: risk_summary,
            evidence_refs: quality_refs_or_skill(&finding_refs, &skill_evidence_id),
        });

        let mut conflict_refs = Vec::new();
        for conflict in &conflicts {
            let evidence_id = push_quality_evidence(
                &mut evidence,
                "conflict",
                &conflict.id,
                format!(
                    "Same-agent conflict `{}` covers {} instance(s)",
                    redact_for_llm_preview(&conflict.reason),
                    conflict.instance_ids.len()
                ),
                Some("warning".to_string()),
                Some(skill.id.clone()),
            );
            conflict_refs.push(evidence_id);
        }
        for group in &related_analysis {
            let evidence_id = push_quality_evidence(
                &mut evidence,
                "analysis",
                &group.id,
                format!(
                    "{} analysis `{}`: {}",
                    redact_for_llm_preview(&group.severity),
                    redact_for_llm_preview(&group.kind),
                    redact_for_llm_preview(&group.title)
                ),
                Some(group.severity.clone()),
                Some(skill.id.clone()),
            );
            conflict_refs.push(evidence_id);
        }
        let (conflict_score, conflict_summary, conflict_suggestions) =
            quality_conflict_component(&conflicts, &related_analysis);
        reasons.push(conflict_summary.clone());
        suggestions.extend(conflict_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "conflict_and_overlap",
            label: "Conflicts and overlap",
            score: conflict_score,
            max_score: 15,
            summary: conflict_summary,
            evidence_refs: quality_refs_or_skill(&conflict_refs, &skill_evidence_id),
        });

        let adapter_evidence_id = adapter_diagnostics.as_ref().map(|diagnostic| {
            push_quality_evidence(
                &mut evidence,
                "adapter_diagnostics",
                diagnostic.agent,
                format!(
                    "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                    diagnostic.display_name,
                    diagnostic.status,
                    diagnostic.access.writable_status,
                    diagnostic.access.install_status
                ),
                None,
                Some(skill.id.clone()),
            )
        });
        let (adapter_score, adapter_summary, adapter_suggestions) =
            quality_adapter_component(&skill, adapter_diagnostics.as_ref());
        reasons.push(adapter_summary.clone());
        suggestions.extend(adapter_suggestions);
        components.push(SkillQualityScoreComponent {
            id: "adapter_state",
            label: "Adapter state",
            score: adapter_score,
            max_score: 15,
            summary: adapter_summary,
            evidence_refs: adapter_evidence_id
                .map(|evidence_id| vec![evidence_id])
                .unwrap_or_else(|| vec![skill_evidence_id]),
        });

        let score = components
            .iter()
            .map(|component| u16::from(component.score))
            .sum::<u16>()
            .min(100) as u8;
        let (grade, band) = quality_grade_and_band(score);
        dedupe_quality_suggestions(&mut suggestions);
        suggestions.truncate(8);
        if risk_notes.is_empty() {
            risk_notes.push(
                "No high-risk local rule findings or execution/network/body signals were associated with this skill."
                    .to_string(),
            );
        }

        Ok(SkillQualityScoreResult {
            instance_id: skill.id.clone(),
            definition_id: skill.definition_id,
            agent: skill.agent,
            scope: skill.scope,
            skill_name: redact_for_llm_preview(&skill.name),
            score,
            grade,
            band,
            generated_by: "deterministic-service",
            components,
            reasons,
            risk_notes,
            evidence_references: evidence,
            suggested_improvements: suggestions,
            prompt_request: SkillQualityPromptRequest {
                available: true,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "quality_score",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::QualityScore,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: Some(params.instance_id),
                    instance_ids: Vec::new(),
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain this deterministic local quality score using only the included redacted evidence."
                            .to_string(),
                    ),
                },
                note: "Optional provider-backed reasoning must be requested through prompt preview and explicit confirmation; this scoring method never sends provider traffic."
                    .to_string(),
            },
            safety_flags: skill_quality_safety_flags(),
        })
    }

    pub fn detect_stale_drift(
        &self,
        params: DetectStaleDriftParams,
    ) -> Result<StaleDriftDetectionResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "analysis.detectStaleDrift limit must be greater than zero".to_string(),
            ));
        }
        let stale_days = params
            .thresholds
            .stale_days
            .or(params.stale_days)
            .unwrap_or(90);
        if stale_days == 0 {
            return Err(ServiceError::InvalidRequest(
                "analysis.detectStaleDrift stale_days must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let limit = params.limit.unwrap_or(20).clamp(1, 100);
        let filters = StaleDriftFilters {
            agent: params.agent.clone(),
            candidate_instance_ids: params.candidate_instance_ids.clone(),
            limit,
            stale_days,
        };
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_stale_drift_result(filters, false));
        };

        let skills = catalog
            .list_skill_instances_for_project_context(adapter_ctx.project_root.as_deref())?;
        let skills = skills
            .into_iter()
            .filter(|skill| !is_pi_plain_markdown_instance_noise(skill))
            .collect::<Vec<_>>();
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let requested_ids = params
            .candidate_instance_ids
            .iter()
            .filter(|id| !id.trim().is_empty())
            .map(|id| id.as_str())
            .collect::<Vec<_>>();

        let mut gap_notes = Vec::new();
        let visible_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        for requested_id in &requested_ids {
            if !visible_by_id.contains_key(requested_id) {
                gap_notes.push(format!(
                    "Requested candidate `{}` is not visible in the current catalog/project scope.",
                    redact_for_llm_preview(requested_id)
                ));
            }
        }

        let now_ms = unix_timestamp_millis();
        let mut evidence = Vec::new();
        let mut rows = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if !requested_ids.is_empty() && !requested_ids.contains(&skill.id.as_str()) {
                continue;
            }
            let related_findings = findings
                .iter()
                .filter(|finding| {
                    finding.instance_id.as_deref() == Some(skill.id.as_str())
                        || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_conflicts = conflicts
                .iter()
                .filter(|conflict| {
                    conflict.definition_id == skill.definition_id
                        || conflict
                            .instance_ids
                            .iter()
                            .any(|instance_id| instance_id == &skill.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let related_analysis = analysis
                .groups
                .iter()
                .filter(|group| {
                    group
                        .instance_ids
                        .iter()
                        .any(|instance_id| instance_id == &skill.id)
                })
                .cloned()
                .collect::<Vec<_>>();
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == skill.agent.as_str());
            rows.push(stale_drift_row(
                skill,
                StaleDriftRowSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    stale_days,
                    now_ms,
                },
                &mut evidence,
            ));
        }

        rows.sort_by(|left, right| {
            right
                .stale_drift_score
                .cmp(&left.stale_drift_score)
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        rows.truncate(limit);
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        let readiness_impact_rows = rows
            .iter()
            .filter_map(stale_drift_readiness_impact_row)
            .collect::<Vec<_>>();
        if rows.is_empty() {
            gap_notes.push(
                "No visible skill rows matched the stale/drift detection filters.".to_string(),
            );
        }
        if rows
            .iter()
            .any(|row| row.drift_signals.missing_previous_scan)
        {
            gap_notes.push(
                "Some rows lack explicit previous-scan comparison evidence; drift is limited to current catalog findings, conflicts, and analysis groups."
                    .to_string(),
            );
        }
        if rows.iter().any(|row| row.drift_signals.missing_mtime) {
            gap_notes.push(
                "Some rows lack catalog mtime evidence; staleness age could not be derived without reading source files."
                    .to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let blocker_notes = stale_drift_blocker_notes(&rows);
        let summary = stale_drift_summary(skills.len(), &rows);
        let prompt_instance_ids = rows
            .iter()
            .take(8)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();

        Ok(StaleDriftDetectionResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            summary,
            stale_drift_rows: rows,
            readiness_impact_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: StaleDriftPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "stale_drift_detection",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::StaleDriftDetection,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic stale/drift signals using only local catalog evidence."
                            .to_string(),
                    ),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; analysis.detectStaleDrift never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces stale/drift rows."
                        .to_string()
                },
            },
            safety_flags: stale_drift_safety_flags(),
        })
    }

    pub fn search_knowledge(
        &self,
        params: KnowledgeSearchParams,
    ) -> Result<KnowledgeSearchResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "knowledge.search limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let filters = knowledge_search_filters(&params);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_knowledge_search_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let roots = self.redaction_roots(&adapter_ctx);
        let agent_filter = filters.agent.as_deref().filter(|agent| !agent.is_empty());
        let readiness_by_id = if filters.query.is_some() {
            let readiness = self.check_task_readiness(TaskReadinessParams {
                task: filters.query.clone().unwrap_or_default(),
                agent: filters.agent.clone(),
                candidate_instance_ids: Vec::new(),
                limit: Some(100),
            })?;
            readiness
                .candidate_skills
                .into_iter()
                .map(|candidate| (candidate.instance_id.clone(), candidate))
                .collect::<BTreeMap<_, _>>()
        } else {
            BTreeMap::new()
        };
        let stale_by_id = self
            .detect_stale_drift(DetectStaleDriftParams {
                agent: filters.agent.clone(),
                candidate_instance_ids: Vec::new(),
                limit: Some(100),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?
            .stale_drift_rows
            .into_iter()
            .map(|row| (row.instance_id.clone(), row))
            .collect::<BTreeMap<_, _>>();

        let mut gap_notes = Vec::new();
        let mut evidence = Vec::new();
        let mut rows = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = knowledge_related_findings(&findings, &detail);
            let related_conflicts = knowledge_related_conflicts(&conflicts, &detail);
            let related_analysis = knowledge_related_analysis(&analysis.groups, &detail);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let readiness = readiness_by_id.get(&detail.id);
            let stale = stale_by_id.get(&detail.id);
            let Some(row) = knowledge_search_row(
                &detail,
                KnowledgeSearchRowSignals {
                    query_terms: &filters.normalized_terms,
                    filters: &filters,
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                    readiness,
                    stale,
                    redaction_roots: &roots,
                },
                &mut evidence,
            ) else {
                continue;
            };
            rows.push(row);
        }

        let matched_row_count = rows.len();
        rows.sort_by(|left, right| {
            knowledge_row_rank_score(right)
                .cmp(&knowledge_row_rank_score(left))
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        rows.truncate(filters.limit);
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        if rows.is_empty() {
            gap_notes.push(
                "No visible local skill evidence matched the knowledge search filters.".to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let facets = knowledge_search_facets(&rows);
        let blocker_notes = knowledge_search_blocker_notes(&rows);
        let prompt_instance_ids = rows
            .iter()
            .take(8)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = knowledge_search_summary(skills.len(), matched_row_count, &rows);

        Ok(KnowledgeSearchResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            summary,
            filters: filters.clone(),
            rows,
            facets,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: KnowledgeSearchPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "knowledge_search",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::KnowledgeSearch,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.query.clone().or_else(|| {
                        Some("Explain deterministic local knowledge search results.".to_string())
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.search never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces knowledge rows."
                        .to_string()
                },
            },
            safety_flags: knowledge_search_safety_flags(),
        })
    }

    pub fn group_similar_skills(
        &self,
        params: SimilarSkillGroupingParams,
    ) -> Result<SimilarSkillGroupingResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "knowledge.groupSimilarSkills limit must be greater than zero".to_string(),
            ));
        }

        let filters = similar_skill_grouping_filters(&params);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_similar_skill_grouping_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let roots = self.redaction_roots(&adapter_ctx);
        let agent_filter = filters.agent.as_deref().filter(|agent| !agent.is_empty());
        let candidate_ids = filters
            .candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let stale_by_id = self
            .detect_stale_drift(DetectStaleDriftParams {
                agent: filters.agent.clone(),
                candidate_instance_ids: filters.candidate_instance_ids.clone(),
                limit: Some(100),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?
            .stale_drift_rows
            .into_iter()
            .map(|row| (row.instance_id.clone(), row))
            .collect::<BTreeMap<_, _>>();

        let mut gap_notes = Vec::new();
        let mut evidence = Vec::new();
        let mut candidates = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if !candidate_ids.is_empty() && !candidate_ids.contains(&skill.id) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = knowledge_related_findings(&findings, &detail);
            let related_conflicts = knowledge_related_conflicts(&conflicts, &detail);
            let related_analysis = knowledge_related_analysis(&analysis.groups, &detail);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let stale = stale_by_id.get(&detail.id);
            candidates.push(similar_skill_candidate(
                &detail,
                SimilarSkillCandidateSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                    stale,
                    redaction_roots: &roots,
                },
                &mut evidence,
            ));
        }

        let candidate_skill_count = candidates.len();
        let mut groups =
            similar_skill_groups_from_candidates(candidates, filters.min_score, &mut evidence);
        if !filters.include_singletons {
            groups.retain(|group| group.members.len() > 1);
        }
        let matched_group_count = groups.len();
        groups.sort_by(|left, right| {
            right
                .similarity_score
                .cmp(&left.similarity_score)
                .then_with(|| right.members.len().cmp(&left.members.len()))
                .then_with(|| left.canonical_key.cmp(&right.canonical_key))
                .then_with(|| left.group_id.cmp(&right.group_id))
        });
        groups.truncate(filters.limit);
        for (index, group) in groups.iter_mut().enumerate() {
            group.rank = index + 1;
        }

        if candidate_skill_count == 0 {
            gap_notes.push(
                "No visible local skill evidence matched the similar-grouping filters.".to_string(),
            );
        } else if groups.is_empty() {
            gap_notes.push(
                "No deterministic similarity group met the selected score threshold.".to_string(),
            );
        }
        gap_notes.sort();
        gap_notes.dedup();

        let blocker_notes = similar_skill_grouping_blocker_notes(&groups);
        let prompt_instance_ids = groups
            .iter()
            .flat_map(|group| {
                group
                    .members
                    .iter()
                    .map(|member| member.instance_id.clone())
            })
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = similar_skill_grouping_summary(
            skills.len(),
            candidate_skill_count,
            matched_group_count,
            &groups,
        );

        Ok(SimilarSkillGroupingResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            groups,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: SimilarSkillGroupingPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "similar_skill_grouping",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::SimilarSkillGrouping,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic similar skill grouping using only local catalog evidence."
                            .to_string(),
                    ),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.groupSimilarSkills never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces similar-skill groups."
                        .to_string()
                },
            },
            safety_flags: similar_skill_grouping_safety_flags(),
        })
    }

    pub fn build_capability_taxonomy(
        &self,
        params: CapabilityTaxonomyParams,
    ) -> Result<CapabilityTaxonomyResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "knowledge.buildCapabilityTaxonomy limit must be greater than zero".to_string(),
            ));
        }

        let filters = capability_taxonomy_filters(&params);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_capability_taxonomy_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let roots = self.redaction_roots(&adapter_ctx);
        let agent_filter = filters.agent.as_deref().filter(|agent| !agent.is_empty());
        let candidate_ids = filters
            .candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let stale_by_id = self
            .detect_stale_drift(DetectStaleDriftParams {
                agent: filters.agent.clone(),
                candidate_instance_ids: filters.candidate_instance_ids.clone(),
                limit: Some(100),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?
            .stale_drift_rows
            .into_iter()
            .map(|row| (row.instance_id.clone(), row))
            .collect::<BTreeMap<_, _>>();
        let similar = self.group_similar_skills(SimilarSkillGroupingParams {
            agent: filters.agent.clone(),
            limit: Some(100),
            min_score: Some(45.0),
            include_singletons: false,
            candidate_instance_ids: filters.candidate_instance_ids.clone(),
        })?;
        let similar_by_member = capability_similarity_by_member(&similar.groups);

        let mut gap_notes = Vec::new();
        let mut evidence = Vec::new();
        let mut candidates = Vec::new();
        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if !candidate_ids.is_empty() && !candidate_ids.contains(&skill.id) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = knowledge_related_findings(&findings, &detail);
            let related_conflicts = knowledge_related_conflicts(&conflicts, &detail);
            let related_analysis = knowledge_related_analysis(&analysis.groups, &detail);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = self
                .score_skill_quality(ScoreSkillQualityParams {
                    instance_id: detail.id.clone(),
                    agent: Some(detail.agent.clone()),
                    definition_id: Some(detail.definition_id.clone()),
                })
                .ok();
            let stale = stale_by_id.get(&detail.id);
            let similar_candidate = similar_skill_candidate(
                &detail,
                SimilarSkillCandidateSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: quality.as_ref(),
                    stale,
                    redaction_roots: &roots,
                },
                &mut evidence,
            );
            candidates.push(capability_taxonomy_candidate(
                similar_candidate,
                &similar_by_member,
                &roots,
            ));
        }

        let candidate_skill_count = candidates.len();
        let mut domains = capability_domains_from_candidates(
            candidates,
            filters.include_single_skill_domains,
            &mut evidence,
        );
        let domain_count = domains.len();
        domains.sort_by(|left, right| {
            right
                .coverage_score
                .cmp(&left.coverage_score)
                .then_with(|| right.skill_count.cmp(&left.skill_count))
                .then_with(|| left.domain_key.cmp(&right.domain_key))
        });
        domains.truncate(filters.limit);
        for (index, domain) in domains.iter_mut().enumerate() {
            domain.rank = index + 1;
        }

        if candidate_skill_count == 0 {
            gap_notes.push(
                "No visible local skill evidence matched the capability taxonomy filters."
                    .to_string(),
            );
        } else if domains.is_empty() {
            gap_notes.push("No capability domain met the selected taxonomy filters.".to_string());
        }
        gap_notes.extend(
            domains
                .iter()
                .flat_map(|domain| domain.gap_notes.iter().cloned()),
        );
        gap_notes.sort();
        gap_notes.dedup();

        let coverage_rows = capability_coverage_rows(&domains);
        let blocker_notes = capability_taxonomy_blocker_notes(&domains);
        let prompt_instance_ids = domains
            .iter()
            .flat_map(|domain| {
                domain
                    .representative_skills
                    .iter()
                    .map(|skill| skill.instance_id.clone())
            })
            .take(12)
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = capability_taxonomy_summary(
            skills.len(),
            candidate_skill_count,
            domain_count,
            &domains,
        );

        Ok(CapabilityTaxonomyResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            domains,
            coverage_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: CapabilityTaxonomyPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "capability_taxonomy",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::CapabilityTaxonomy,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic capability taxonomy using only local catalog evidence."
                            .to_string(),
                    ),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.buildCapabilityTaxonomy never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces capability domains."
                        .to_string()
                },
            },
            safety_flags: capability_taxonomy_safety_flags(),
        })
    }

    pub fn build_local_skill_map(
        &self,
        params: LocalSkillMapParams,
    ) -> Result<LocalSkillMapResult, ServiceError> {
        if matches!(params.limit, Some(0))
            || matches!(params.node_limit, Some(0))
            || matches!(params.edge_limit, Some(0))
            || matches!(params.cluster_limit, Some(0))
        {
            return Err(ServiceError::InvalidRequest(
                "knowledge.buildLocalSkillMap limits must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = local_skill_map_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_local_skill_map_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let candidate_filter = filters
            .candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let search = self.search_knowledge(KnowledgeSearchParams {
            query: filters.task.clone(),
            agent: filters.agent.clone(),
            limit: Some(filters.limit.max(filters.node_limit).min(100)),
            risk: None,
            scope: None,
            enabled: None,
            tool: None,
            keyword: None,
        })?;
        let mut skill_rows = search.rows;
        if !candidate_filter.is_empty() {
            skill_rows.retain(|row| candidate_filter.contains(&row.instance_id));
        }
        skill_rows.truncate(filters.limit);
        for (index, row) in skill_rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        let candidate_instance_ids = skill_rows
            .iter()
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let candidate_id_set = candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();

        let similar = self.group_similar_skills(SimilarSkillGroupingParams {
            agent: filters.agent.clone(),
            limit: Some(filters.cluster_limit),
            min_score: Some(45.0),
            include_singletons: false,
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        let taxonomy = self.build_capability_taxonomy(CapabilityTaxonomyParams {
            agent: filters.agent.clone(),
            limit: Some(filters.cluster_limit),
            include_single_skill_domains: true,
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        let task_readiness = if filters.include_task_context {
            filters
                .task
                .as_ref()
                .map(|task| {
                    self.check_task_readiness(TaskReadinessParams {
                        task: task.clone(),
                        agent: filters.agent.clone(),
                        candidate_instance_ids: candidate_instance_ids.clone(),
                        limit: Some(filters.limit.min(50)),
                    })
                })
                .transpose()?
        } else {
            None
        };
        let routing = if filters.include_task_context {
            filters
                .task
                .as_ref()
                .map(|task| {
                    self.rank_skill_routes(RankSkillRoutesParams {
                        task: task.clone(),
                        agent: filters.agent.clone(),
                        candidate_instance_ids: candidate_instance_ids.clone(),
                        limit: Some(filters.limit.min(50)),
                    })
                })
                .transpose()?
        } else {
            None
        };

        let mut evidence = Vec::new();
        extend_evidence_references(&mut evidence, search.evidence_references.clone());
        extend_evidence_references(&mut evidence, similar.evidence_references.clone());
        extend_evidence_references(&mut evidence, taxonomy.evidence_references.clone());
        if let Some(readiness) = task_readiness.as_ref() {
            extend_evidence_references(&mut evidence, readiness.evidence_references.clone());
        }
        if let Some(ranking) = routing.as_ref() {
            extend_evidence_references(&mut evidence, ranking.evidence_references.clone());
        }

        let mut nodes = BTreeMap::<String, LocalSkillMapNode>::new();
        let mut edges = BTreeMap::<String, LocalSkillMapEdge>::new();
        let mut clusters = Vec::<LocalSkillMapCluster>::new();
        let mut domains = Vec::<LocalSkillMapDomain>::new();

        if let Some(task) = filters.task.as_ref() {
            upsert_local_skill_map_node(
                &mut nodes,
                LocalSkillMapNode {
                    id: "task:local-skill-map".to_string(),
                    node_type: "task_coverage".to_string(),
                    rank: 0,
                    label: "Task coverage".to_string(),
                    summary: format!(
                        "Local skill map task context: {}",
                        truncate_chars(task, 160)
                    ),
                    weight: 70,
                    agent: None,
                    scope: None,
                    enabled: None,
                    state: None,
                    source: None,
                    risk_level: None,
                    tags: vec!["task-context".to_string(), "read-only".to_string()],
                    evidence_refs: Vec::new(),
                    safety_flags: local_skill_map_safety_flags(),
                },
            );
        }

        for row in &skill_rows {
            let skill_node_id = local_skill_map_skill_node_id(&row.instance_id);
            let agent_node_id = local_skill_map_agent_node_id(&row.agent);
            let source_node_id = local_skill_map_source_node_id(&row.source);
            let risk_level = local_skill_map_risk_level(&row.risk_tags);
            let risk_node_id = local_skill_map_risk_node_id(&risk_level);
            upsert_local_skill_map_node(&mut nodes, local_skill_map_skill_node(row, &risk_level));
            upsert_local_skill_map_node(&mut nodes, local_skill_map_agent_node(&row.agent));
            upsert_local_skill_map_node(&mut nodes, local_skill_map_source_node(&row.source));
            upsert_local_skill_map_node(&mut nodes, local_skill_map_risk_node(&risk_level));
            upsert_local_skill_map_edge(
                &mut edges,
                local_skill_map_edge(
                    "skill_agent",
                    &skill_node_id,
                    &agent_node_id,
                    "agent",
                    65,
                    vec![format!("Skill is visible to {}.", row.agent)],
                    row.evidence_refs.clone(),
                ),
            );
            upsert_local_skill_map_edge(
                &mut edges,
                local_skill_map_edge(
                    "skill_source",
                    &skill_node_id,
                    &source_node_id,
                    "source",
                    55,
                    vec![format!(
                        "Source provenance: {}.",
                        row.source.root_provenance
                    )],
                    row.evidence_refs.clone(),
                ),
            );
            upsert_local_skill_map_edge(
                &mut edges,
                local_skill_map_edge(
                    "skill_risk",
                    &skill_node_id,
                    &risk_node_id,
                    "risk",
                    local_skill_map_risk_weight(&risk_level),
                    vec![format!("Risk level is `{risk_level}` from local evidence.")],
                    row.evidence_refs.clone(),
                ),
            );
        }

        for domain in &taxonomy.domains {
            let capability_node_id = local_skill_map_capability_node_id(&domain.domain_id);
            upsert_local_skill_map_node(
                &mut nodes,
                LocalSkillMapNode {
                    id: capability_node_id.clone(),
                    node_type: "capability".to_string(),
                    rank: domain.rank,
                    label: domain.domain_name.clone(),
                    summary: format!(
                        "{} coverage ({}/100) across {} skill(s).",
                        domain.coverage_level, domain.coverage_score, domain.skill_count
                    ),
                    weight: domain.coverage_score,
                    agent: None,
                    scope: None,
                    enabled: None,
                    state: None,
                    source: None,
                    risk_level: None,
                    tags: domain
                        .capability_tags
                        .iter()
                        .chain(domain.risk_tags.iter())
                        .take(20)
                        .cloned()
                        .collect(),
                    evidence_refs: domain.evidence_refs.clone(),
                    safety_flags: local_skill_map_safety_flags(),
                },
            );
            let mut node_ids = vec![capability_node_id.clone()];
            let mut edge_ids = Vec::new();
            for skill in &domain.representative_skills {
                let skill_node_id = local_skill_map_skill_node_id(&skill.instance_id);
                if candidate_id_set.contains(&skill.instance_id) {
                    let edge = local_skill_map_edge(
                        "skill_capability",
                        &skill_node_id,
                        &capability_node_id,
                        "capability",
                        domain.coverage_score,
                        skill.match_reasons.clone(),
                        skill.evidence_refs.clone(),
                    );
                    edge_ids.push(edge.id.clone());
                    upsert_local_skill_map_edge(&mut edges, edge);
                    node_ids.push(skill_node_id);
                }
            }
            node_ids.sort();
            node_ids.dedup();
            edge_ids.sort();
            edge_ids.dedup();
            clusters.push(LocalSkillMapCluster {
                id: format!("cluster:{}", domain.domain_id),
                cluster_type: "capability_domain".to_string(),
                label: domain.domain_name.clone(),
                summary: format!(
                    "{} local skill(s) mapped to {} with {} coverage.",
                    domain.skill_count, domain.domain_name, domain.coverage_level
                ),
                score: domain.coverage_score,
                risk_level: if domain.routing_ambiguity_count > 0 {
                    "medium".to_string()
                } else {
                    "low".to_string()
                },
                node_ids: node_ids.clone(),
                edge_ids,
                evidence_refs: domain.evidence_refs.clone(),
                safety_flags: local_skill_map_safety_flags(),
            });
            domains.push(LocalSkillMapDomain {
                domain_id: domain.domain_id.clone(),
                domain_key: domain.domain_key.clone(),
                domain_name: domain.domain_name.clone(),
                coverage_level: domain.coverage_level,
                coverage_score: domain.coverage_score,
                node_ids,
                skill_count: domain.skill_count,
                enabled_skill_count: domain.enabled_skill_count,
                agent_count: domain.agent_count,
                gap_notes: domain.gap_notes.clone(),
                blocker_notes: domain.blocker_notes.clone(),
                evidence_refs: domain.evidence_refs.clone(),
            });
        }

        for group in &similar.groups {
            let group_node_id = local_skill_map_similar_group_node_id(&group.group_id);
            upsert_local_skill_map_node(
                &mut nodes,
                LocalSkillMapNode {
                    id: group_node_id.clone(),
                    node_type: "similar_group".to_string(),
                    rank: group.rank,
                    label: group.canonical_name.clone(),
                    summary: group.summary.clone(),
                    weight: group.similarity_score,
                    agent: None,
                    scope: None,
                    enabled: None,
                    state: None,
                    source: None,
                    risk_level: Some(group.ambiguity_risk.to_string()),
                    tags: vec![
                        format!("group-type-{}", group.group_type),
                        format!("routing-ambiguity-{}", group.routing_ambiguity),
                        format!("coverage-redundancy-{}", group.coverage_redundancy),
                    ],
                    evidence_refs: group.evidence_refs.clone(),
                    safety_flags: local_skill_map_safety_flags(),
                },
            );
            let mut node_ids = vec![group_node_id.clone()];
            let mut edge_ids = Vec::new();
            for member in &group.members {
                if !candidate_id_set.contains(&member.instance_id) {
                    continue;
                }
                let skill_node_id = local_skill_map_skill_node_id(&member.instance_id);
                let edge = local_skill_map_edge(
                    "similar_group_member",
                    &group_node_id,
                    &skill_node_id,
                    "similar member",
                    group.similarity_score,
                    group.why_grouped.clone(),
                    member.evidence_refs.clone(),
                );
                edge_ids.push(edge.id.clone());
                upsert_local_skill_map_edge(&mut edges, edge);
                node_ids.push(skill_node_id);
            }
            if node_ids.len() > 1 {
                node_ids.sort();
                node_ids.dedup();
                edge_ids.sort();
                edge_ids.dedup();
                clusters.push(LocalSkillMapCluster {
                    id: format!("cluster:{}", group.group_id),
                    cluster_type: "similar_group".to_string(),
                    label: group.canonical_name.clone(),
                    summary: group.summary.clone(),
                    score: group.similarity_score,
                    risk_level: group.ambiguity_risk.to_string(),
                    node_ids,
                    edge_ids,
                    evidence_refs: group.evidence_refs.clone(),
                    safety_flags: local_skill_map_safety_flags(),
                });
            }
        }

        for conflict in &conflicts {
            let member_ids = conflict
                .instance_ids
                .iter()
                .filter(|id| candidate_id_set.contains(*id))
                .cloned()
                .collect::<Vec<_>>();
            if member_ids.is_empty() {
                continue;
            }
            let conflict_node_id = local_skill_map_conflict_node_id(&conflict.id);
            let conflict_ref = push_task_readiness_evidence(
                &mut evidence,
                "conflict",
                &conflict.id,
                format!(
                    "Same-agent conflict `{}` covers {} local map member(s).",
                    redact_for_llm_preview(&conflict.reason),
                    member_ids.len()
                ),
                Some("warning".to_string()),
                member_ids.first().cloned(),
            );
            upsert_local_skill_map_node(
                &mut nodes,
                LocalSkillMapNode {
                    id: conflict_node_id.clone(),
                    node_type: "conflict".to_string(),
                    rank: 0,
                    label: conflict.reason.clone(),
                    summary: format!(
                        "Same-agent conflict for definition `{}` with {} mapped member(s).",
                        redact_for_llm_preview(&conflict.definition_id),
                        member_ids.len()
                    ),
                    weight: 80,
                    agent: None,
                    scope: None,
                    enabled: None,
                    state: None,
                    source: None,
                    risk_level: Some("medium".to_string()),
                    tags: vec!["same-agent-conflict".to_string(), conflict.reason.clone()],
                    evidence_refs: vec![conflict_ref.clone()],
                    safety_flags: local_skill_map_safety_flags(),
                },
            );
            let mut node_ids = vec![conflict_node_id.clone()];
            let mut edge_ids = Vec::new();
            for instance_id in member_ids {
                let skill_node_id = local_skill_map_skill_node_id(&instance_id);
                let edge = local_skill_map_edge(
                    "same_agent_conflict",
                    &conflict_node_id,
                    &skill_node_id,
                    "same-agent conflict",
                    80,
                    vec![format!(
                        "Conflict reason `{}` is surfaced for review only.",
                        redact_for_llm_preview(&conflict.reason)
                    )],
                    vec![conflict_ref.clone()],
                );
                edge_ids.push(edge.id.clone());
                upsert_local_skill_map_edge(&mut edges, edge);
                node_ids.push(skill_node_id);
            }
            clusters.push(LocalSkillMapCluster {
                id: format!("cluster:{}", conflict.id),
                cluster_type: "conflict".to_string(),
                label: conflict.reason.clone(),
                summary: "Conflict cluster is advisory; no winner is applied by the map."
                    .to_string(),
                score: 80,
                risk_level: "medium".to_string(),
                node_ids,
                edge_ids,
                evidence_refs: vec![conflict_ref],
                safety_flags: local_skill_map_safety_flags(),
            });
        }

        for group in &analysis.groups {
            let member_ids = group
                .instance_ids
                .iter()
                .filter(|id| candidate_id_set.contains(*id))
                .cloned()
                .collect::<Vec<_>>();
            if member_ids.is_empty() {
                continue;
            }
            let analysis_node_id = local_skill_map_analysis_node_id(&group.id);
            let analysis_ref = push_task_readiness_evidence(
                &mut evidence,
                "analysis",
                &group.id,
                format!(
                    "{} cross-agent analysis `{}`: {}",
                    redact_for_llm_preview(&group.severity),
                    redact_for_llm_preview(&group.kind),
                    redact_for_llm_preview(&group.title)
                ),
                Some(group.severity.clone()),
                member_ids.first().cloned(),
            );
            upsert_local_skill_map_node(
                &mut nodes,
                LocalSkillMapNode {
                    id: analysis_node_id.clone(),
                    node_type: "cross_agent_analysis".to_string(),
                    rank: 0,
                    label: group.title.clone(),
                    summary: redact_for_llm_preview(&truncate_chars(&group.explanation, 220)),
                    weight: local_skill_map_severity_weight(&group.severity),
                    agent: None,
                    scope: None,
                    enabled: None,
                    state: None,
                    source: None,
                    risk_level: Some(normalize_filter_value(&group.severity)),
                    tags: vec![group.kind.clone(), group.severity.clone()],
                    evidence_refs: vec![analysis_ref.clone()],
                    safety_flags: local_skill_map_safety_flags(),
                },
            );
            for instance_id in member_ids {
                upsert_local_skill_map_edge(
                    &mut edges,
                    local_skill_map_edge(
                        "cross_agent_analysis",
                        &analysis_node_id,
                        &local_skill_map_skill_node_id(&instance_id),
                        "cross-agent analysis",
                        local_skill_map_severity_weight(&group.severity),
                        vec![
                            "Cross-agent analysis is advisory and does not change routing."
                                .to_string(),
                        ],
                        vec![analysis_ref.clone()],
                    ),
                );
            }
        }

        if let Some(readiness) = task_readiness.as_ref() {
            for candidate in &readiness.candidate_skills {
                if !candidate_id_set.contains(&candidate.instance_id) {
                    continue;
                }
                let task_node_id = "task:local-skill-map".to_string();
                let skill_node_id = local_skill_map_skill_node_id(&candidate.instance_id);
                upsert_local_skill_map_edge(
                    &mut edges,
                    local_skill_map_edge(
                        "task_readiness",
                        &task_node_id,
                        &skill_node_id,
                        "task readiness",
                        candidate.score,
                        candidate.match_reasons.clone(),
                        candidate.evidence_refs.clone(),
                    ),
                );
            }
        }
        if let Some(ranking) = routing.as_ref() {
            for candidate in &ranking.route_candidates {
                if !candidate_id_set.contains(&candidate.instance_id) {
                    continue;
                }
                let task_node_id = "task:local-skill-map".to_string();
                let skill_node_id = local_skill_map_skill_node_id(&candidate.instance_id);
                upsert_local_skill_map_edge(
                    &mut edges,
                    local_skill_map_edge(
                        "task_route_candidate",
                        &task_node_id,
                        &skill_node_id,
                        "route candidate",
                        candidate.confidence_score,
                        candidate.confidence_rationale.clone(),
                        candidate.evidence_refs.clone(),
                    ),
                );
            }
        }

        let mut nodes = nodes.into_values().collect::<Vec<_>>();
        nodes.sort_by(local_skill_map_node_sort);
        nodes.truncate(filters.node_limit);
        for (index, node) in nodes.iter_mut().enumerate() {
            node.rank = index + 1;
        }
        let visible_node_ids = nodes
            .iter()
            .map(|node| node.id.clone())
            .collect::<BTreeSet<_>>();
        let mut edges = edges
            .into_values()
            .filter(|edge| {
                visible_node_ids.contains(&edge.source) && visible_node_ids.contains(&edge.target)
            })
            .collect::<Vec<_>>();
        edges.sort_by(local_skill_map_edge_sort);
        edges.truncate(filters.edge_limit);
        let visible_edge_ids = edges
            .iter()
            .map(|edge| edge.id.clone())
            .collect::<BTreeSet<_>>();
        clusters.retain(|cluster| {
            cluster
                .node_ids
                .iter()
                .any(|node_id| visible_node_ids.contains(node_id))
        });
        for cluster in &mut clusters {
            cluster
                .node_ids
                .retain(|node_id| visible_node_ids.contains(node_id));
            cluster
                .edge_ids
                .retain(|edge_id| visible_edge_ids.contains(edge_id));
        }
        clusters.sort_by(local_skill_map_cluster_sort);
        let cluster_count = clusters.len();
        clusters.truncate(filters.cluster_limit);
        for domain in &mut domains {
            domain
                .node_ids
                .retain(|node_id| visible_node_ids.contains(node_id));
        }
        domains.retain(|domain| !domain.node_ids.is_empty());
        domains.truncate(filters.cluster_limit);

        let risk_notes =
            local_skill_map_risk_notes(&nodes, &edges, task_readiness.as_ref(), routing.as_ref());
        let mut gap_notes = search.gap_notes;
        gap_notes.extend(similar.gap_notes);
        gap_notes.extend(taxonomy.gap_notes);
        if let Some(readiness) = task_readiness.as_ref() {
            gap_notes.extend(readiness.missing_gap_notes.clone());
        }
        if skill_rows.is_empty() {
            gap_notes.push(
                "No visible local skill evidence matched the local skill map filters.".to_string(),
            );
        }
        normalize_note_list(&mut gap_notes);

        let mut blocker_notes = search.blocker_notes;
        blocker_notes.extend(similar.blocker_notes);
        blocker_notes.extend(taxonomy.blocker_notes);
        if let Some(readiness) = task_readiness.as_ref() {
            blocker_notes.extend(readiness.blocker_risk_notes.clone());
        }
        if let Some(ranking) = routing.as_ref() {
            blocker_notes.extend(ranking.ambiguity_warnings.clone());
            blocker_notes.extend(ranking.likely_wrong_pick_risks.clone());
            blocker_notes.extend(ranking.likely_miss_risks.clone());
        }
        if blocker_notes.is_empty() {
            blocker_notes.push(
                "Local skill map used deterministic catalog evidence only and found no returned-map blockers."
                    .to_string(),
            );
        }
        normalize_note_list(&mut blocker_notes);
        dedupe_evidence_references(&mut evidence);

        let prompt_instance_ids = skill_rows
            .iter()
            .take(12)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = local_skill_map_summary(
            skills.len(),
            skill_rows.len(),
            cluster_count,
            &nodes,
            &edges,
            &clusters,
            &domains,
        );

        Ok(LocalSkillMapResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            nodes,
            edges,
            clusters,
            domains,
            risk_notes,
            gap_notes,
            blocker_notes,
            evidence_references: evidence,
            prompt_request: LocalSkillMapPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "local_skill_map",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::LocalSkillMap,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic local skill map using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; knowledge.buildLocalSkillMap never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces map nodes."
                        .to_string()
                },
            },
            safety_flags: local_skill_map_safety_flags(),
        })
    }

    pub fn check_workspace_readiness(
        &self,
        params: WorkspaceReadinessParams,
    ) -> Result<WorkspaceReadinessResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "workspace.checkReadiness limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let filters = workspace_readiness_filters(&params, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_workspace_readiness_result(filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let requested_ids = filters
            .candidate_instance_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let raw_project_root = params
            .project_root
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .or_else(|| adapter_ctx.project_root.clone());

        let mut visible_details = Vec::new();
        let mut evidence_by_id = BTreeMap::new();
        for skill in &skills {
            if !agent_matches(filters.agent.as_deref(), Some(skill.agent.as_str())) {
                continue;
            }
            if !requested_ids.is_empty() && !requested_ids.contains(&skill.id) {
                continue;
            }
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                continue;
            };
            if !workspace_detail_matches(raw_project_root.as_deref(), &detail) {
                continue;
            }
            visible_details.push(detail);
        }

        let candidate_instance_ids = if filters.candidate_instance_ids.is_empty() {
            visible_details
                .iter()
                .map(|detail| detail.id.clone())
                .collect::<Vec<_>>()
        } else {
            filters.candidate_instance_ids.clone()
        };

        let taxonomy = self.build_capability_taxonomy(CapabilityTaxonomyParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit),
            include_single_skill_domains: true,
            candidate_instance_ids: candidate_instance_ids.clone(),
        })?;
        for evidence in taxonomy.evidence_references.iter().cloned() {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert(evidence);
        }

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
        let route_ranking = filters
            .task
            .as_ref()
            .map(|task| {
                self.rank_skill_routes(RankSkillRoutesParams {
                    task: task.clone(),
                    agent: filters.agent.clone(),
                    candidate_instance_ids: candidate_instance_ids.clone(),
                    limit: Some(filters.limit.min(20)),
                })
            })
            .transpose()?;
        let agent_comparison = filters
            .task
            .as_ref()
            .map(|task| {
                self.compare_agent_readiness(CompareAgentReadinessParams {
                    task: task.clone(),
                    agents: filters.agent.clone().into_iter().collect(),
                    limit_per_agent: Some(3),
                    include_routing_accuracy: true,
                    include_benchmarks: true,
                })
            })
            .transpose()?;
        for readiness in task_readiness.iter() {
            for evidence in readiness.evidence_references.iter().cloned() {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert(evidence);
            }
        }
        for ranking in route_ranking.iter() {
            for evidence in ranking.evidence_references.iter().cloned() {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert(evidence);
            }
        }
        for comparison in agent_comparison.iter() {
            for evidence in comparison.evidence_references.iter().cloned() {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert(evidence);
            }
        }

        let stale_drift = self.detect_stale_drift(DetectStaleDriftParams {
            agent: filters.agent.clone(),
            candidate_instance_ids: candidate_instance_ids.clone(),
            limit: Some(filters.limit),
            stale_days: None,
            thresholds: StaleDriftThresholds::default(),
        })?;
        for evidence in stale_drift.evidence_references.iter().cloned() {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert(evidence);
        }
        let similar = self.group_similar_skills(SimilarSkillGroupingParams {
            agent: filters.agent.clone(),
            limit: Some(filters.limit),
            min_score: Some(45.0),
            include_singletons: false,
            candidate_instance_ids,
        })?;
        for evidence in similar.evidence_references.iter().cloned() {
            evidence_by_id
                .entry(evidence.id.clone())
                .or_insert(evidence);
        }

        let mut capability_rows =
            workspace_capability_rows(&filters.expected_capabilities, &taxonomy);
        capability_rows.truncate(filters.limit);
        let mut readiness_rows = workspace_checklist_rows(
            &filters,
            &visible_details,
            &findings,
            &conflicts,
            &analysis.groups,
            &diagnostics,
            &taxonomy,
            task_readiness.as_ref(),
            route_ranking.as_ref(),
            &stale_drift,
            &similar,
        );
        readiness_rows.truncate(filters.limit);
        let checklist_rows = readiness_rows.clone();
        let mut agent_rows = if let Some(comparison) = agent_comparison.as_ref() {
            workspace_agent_rows_from_comparison(comparison, &visible_details, &diagnostics)
        } else {
            workspace_agent_rows_from_catalog(
                &visible_details,
                &diagnostics,
                filters.agent.as_deref(),
            )
        };
        agent_rows.truncate(filters.limit);

        let mut gap_notes = taxonomy.gap_notes.clone();
        if let Some(readiness) = task_readiness.as_ref() {
            gap_notes.extend(readiness.missing_gap_notes.iter().cloned());
        }
        gap_notes.extend(stale_drift.gap_notes.iter().cloned());
        gap_notes.extend(similar.gap_notes.iter().cloned());
        gap_notes.extend(
            capability_rows
                .iter()
                .flat_map(|row| row.gap_notes.iter().cloned()),
        );
        gap_notes.sort();
        gap_notes.dedup();
        gap_notes.truncate(16);

        let mut blocker_notes = taxonomy.blocker_notes.clone();
        if let Some(readiness) = task_readiness.as_ref() {
            blocker_notes.extend(readiness.blocker_risk_notes.iter().cloned());
        }
        blocker_notes.extend(stale_drift.blocker_notes.iter().cloned());
        blocker_notes.extend(similar.blocker_notes.iter().cloned());
        blocker_notes.extend(
            agent_rows
                .iter()
                .flat_map(|row| row.notes.iter().cloned())
                .filter(|note| note.contains("blocked") || note.contains("disabled")),
        );
        blocker_notes.sort();
        blocker_notes.dedup();
        blocker_notes.truncate(16);

        let prompt_instance_ids = visible_details
            .iter()
            .take(12)
            .map(|detail| detail.id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = workspace_readiness_summary(WorkspaceReadinessSummaryInput {
            project_root: raw_project_root.as_deref(),
            visible_details: &visible_details,
            taxonomy: &taxonomy,
            readiness_rows: &readiness_rows,
            agent_rows: &agent_rows,
            capability_rows: &capability_rows,
            gap_notes: &gap_notes,
            blocker_notes: &blocker_notes,
        });

        Ok(WorkspaceReadinessResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            readiness_rows,
            checklist_rows,
            agent_rows,
            capability_rows,
            gap_notes,
            blocker_notes,
            evidence_references: evidence_by_id.into_values().collect(),
            prompt_request: WorkspaceReadinessPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "workspace_readiness",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::WorkspaceReadiness,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic workspace readiness using only local catalog evidence."
                                .to_string(),
                        )
                    }),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; workspace.checkReadiness never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces workspace readiness rows."
                        .to_string()
                },
            },
            safety_flags: workspace_readiness_safety_flags(),
        })
    }
}
