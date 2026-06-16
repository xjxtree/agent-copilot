use super::*;

impl ServiceHost {
    pub fn check_task_readiness(
        &self,
        params: TaskReadinessParams,
    ) -> Result<TaskReadinessResult, ServiceError> {
        let started_at = Instant::now();
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.checkReadiness requires a non-empty task".to_string(),
            ));
        }
        let adapter_ctx = self.effective_adapter_ctx()?;
        let task = redact_string(
            &redact_for_llm_preview(task),
            &self.redaction_roots(&adapter_ctx),
        );
        let limit = params.limit.unwrap_or(8).clamp(1, 20);
        let candidate_instance_ids = normalize_string_list(params.candidate_instance_ids.clone());
        let filters = TaskReadinessFilters {
            agent: params.agent.clone(),
            candidate_instance_ids: candidate_instance_ids.clone(),
            limit,
        };
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_task_readiness_result(task, filters, false));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let requested_ids = candidate_instance_ids
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>();
        let task_terms = task_readiness_terms(&task);

        let mut missing_gap_notes = Vec::new();
        let visible_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        for requested_id in &requested_ids {
            if !visible_by_id.contains_key(requested_id) {
                missing_gap_notes.push(format!(
                    "Requested candidate `{}` is not visible in the current catalog/project scope.",
                    redact_for_llm_preview(requested_id)
                ));
            }
        }

        let mut candidate_records = skills
            .into_iter()
            .filter(|skill| {
                agent_filter.is_none_or(|agent| skill.agent == agent)
                    && (requested_ids.is_empty() || requested_ids.contains(&skill.id.as_str()))
            })
            .collect::<Vec<_>>();
        let total_candidate_count = candidate_records.len();
        let scan_limit = task_readiness_candidate_scan_limit(limit, requested_ids.len());
        let mut skipped_stages = Vec::new();
        let mut blocker_codes = Vec::new();
        let mut aggregation_notes = Vec::new();
        if candidate_records.len() > scan_limit {
            candidate_records.sort_by(|left, right| {
                task_readiness_record_affinity(right, &task_terms)
                    .cmp(&task_readiness_record_affinity(left, &task_terms))
                    .then_with(|| right.enabled.cmp(&left.enabled))
                    .then_with(|| left.agent.cmp(&right.agent))
                    .then_with(|| left.name.cmp(&right.name))
                    .then_with(|| left.id.cmp(&right.id))
            });
            candidate_records.truncate(scan_limit);
            skipped_stages.push("candidate-scan-overflow");
            blocker_codes.push("bounded-candidate-scan");
            let note = format!(
                "Task readiness evaluated the top {} of {} visible candidate(s) using deterministic prefiltering.",
                candidate_records.len(),
                total_candidate_count
            );
            missing_gap_notes.push(note.clone());
            aggregation_notes.push(note);
        }

        let findings_by_instance = task_readiness_findings_by_instance(&findings);
        let findings_by_definition = task_readiness_findings_by_definition(&findings);
        let conflicts_by_instance = task_readiness_conflicts_by_instance(&conflicts);
        let conflicts_by_definition = task_readiness_conflicts_by_definition(&conflicts);
        let analysis_by_instance = task_readiness_analysis_by_instance(&analysis.groups);

        let mut evidence = Vec::new();
        let mut candidates = Vec::new();
        for skill in &candidate_records {
            let Some(detail) = catalog.get_skill_detail(&skill.id)? else {
                missing_gap_notes.push(format!(
                    "Catalog row `{}` did not have detail evidence available.",
                    redact_for_llm_preview(&skill.id)
                ));
                continue;
            };
            let related_findings = task_readiness_related_findings(
                &detail,
                &findings_by_instance,
                &findings_by_definition,
            );
            let related_conflicts = task_readiness_related_conflicts(
                &detail,
                &conflicts_by_instance,
                &conflicts_by_definition,
            );
            let related_analysis = task_readiness_related_analysis(&detail, &analysis_by_instance);
            let diagnostic = adapter_diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == detail.agent);
            let quality = task_readiness_quality_signal(
                &detail,
                &related_findings,
                &related_conflicts,
                &related_analysis,
                diagnostic,
            );
            let candidate = task_readiness_candidate(
                &task_terms,
                &detail,
                TaskReadinessCandidateSignals {
                    findings: &related_findings,
                    conflicts: &related_conflicts,
                    analysis_groups: &related_analysis,
                    diagnostic,
                    quality: Some(&quality),
                },
                &mut evidence,
            );
            candidates.push(candidate);
        }

        candidates.sort_by(|left, right| {
            right
                .score
                .cmp(&left.score)
                .then_with(|| left.agent.cmp(&right.agent))
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        candidates.truncate(limit);

        if candidates.is_empty() {
            if agent_filter.is_some() {
                missing_gap_notes.push(
                    "No visible skill candidates matched the requested agent/filter scope."
                        .to_string(),
                );
            } else {
                missing_gap_notes.push(
                    "No visible skill candidates matched the task in the current catalog."
                        .to_string(),
                );
            }
        }

        let blocker_risk_notes = task_readiness_blocker_notes(&candidates);
        let score = task_readiness_overall_score(&candidates);
        let band = task_readiness_band(score);
        let summary = task_readiness_summary(score, band, &candidates, &missing_gap_notes);
        let prompt_instance_ids = candidates
            .iter()
            .take(8)
            .map(|candidate| candidate.instance_id.clone())
            .collect::<Vec<_>>();

        Ok(TaskReadinessResult {
            task: task.clone(),
            score,
            band,
            summary,
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            candidate_skills: candidates,
            missing_gap_notes,
            blocker_risk_notes,
            evidence_references: evidence,
            prompt_request: TaskReadinessPromptRequest {
                available: true,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "task_readiness",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::TaskReadiness,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(task.clone()),
                },
                note: "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.checkReadiness never sends provider traffic."
                    .to_string(),
            },
            aggregation: aggregation_runtime_metadata(AggregationRuntimeInput {
                started_at,
                timeout_ms: TASK_AGGREGATION_TIMEOUT_MS,
                limit,
                scanned_count: candidate_records.len(),
                total_count: total_candidate_count,
                completed_stages: vec![
                    "catalog",
                    "finding-index",
                    "conflict-index",
                    "analysis-index",
                    "candidate-scan",
                    "quality-signal",
                ],
                skipped_stages,
                blocker_codes,
                fallback_used: !aggregation_notes.is_empty(),
                notes: aggregation_notes,
            }),
            safety_flags: task_readiness_safety_flags(),
        })
    }

    pub fn rank_skill_routes(
        &self,
        params: RankSkillRoutesParams,
    ) -> Result<SkillRouteRankingResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.rankSkillRoutes requires a non-empty task".to_string(),
            ));
        }
        let readiness = self.check_task_readiness(TaskReadinessParams {
            task: task.to_string(),
            agent: params.agent,
            candidate_instance_ids: params.candidate_instance_ids,
            limit: params.limit,
        })?;
        Ok(skill_route_ranking_from_readiness(readiness))
    }

    pub fn compare_agent_readiness(
        &self,
        params: CompareAgentReadinessParams,
    ) -> Result<AgentReadinessComparisonResult, ServiceError> {
        let started_at = Instant::now();
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.compareAgentReadiness requires a non-empty task".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let task = redact_string(
            &redact_for_llm_preview(task),
            &self.redaction_roots(&adapter_ctx),
        );
        let limit_per_agent = params.limit_per_agent.unwrap_or(3).clamp(1, 10);
        let requested_agents = normalize_agent_filter_list(params.agents);
        let filters = AgentReadinessComparisonFilters {
            agents: requested_agents.clone(),
            limit_per_agent,
            include_routing_accuracy: params.include_routing_accuracy,
            include_benchmarks: params.include_benchmarks,
        };

        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_agent_readiness_comparison(
                task,
                filters,
                false,
                "No local catalog is available; cross-agent readiness comparison has no candidate evidence.",
            ));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let agents =
            agent_readiness_agents_for_comparison(&skills, &adapter_ctx, &requested_agents);
        let total_agent_count = agents.len();
        if agents.is_empty() {
            return Ok(empty_agent_readiness_comparison(
                task,
                filters,
                true,
                "No supported agent skills matched the selected filters in the current catalog.",
            ));
        }

        let accuracy_by_agent = if params.include_routing_accuracy {
            Some(agent_readiness_accuracy_context(
                self.routing_accuracy_dashboard(RoutingAccuracyDashboardParams {
                    agent: None,
                    window_days: Some(30),
                    limit: Some(100),
                    include_history: false,
                    include_recent_evidence: true,
                })?,
            ))
        } else {
            None
        };
        let benchmark_by_agent = if params.include_benchmarks {
            Some(agent_readiness_benchmark_context(
                self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
                    ids: Vec::new(),
                    limit: Some(25),
                })?,
            ))
        } else {
            None
        };

        let mut evidence_by_id = BTreeMap::new();
        let mut rows = Vec::new();
        let mut gap_issue_rows = Vec::new();
        for agent in agents {
            let readiness = self.check_task_readiness(TaskReadinessParams {
                task: task.clone(),
                agent: Some(agent.clone()),
                candidate_instance_ids: Vec::new(),
                limit: Some(limit_per_agent),
            })?;
            let ranking = skill_route_ranking_from_readiness(readiness.clone());
            for evidence in readiness.evidence_references.iter().cloned() {
                evidence_by_id
                    .entry(evidence.id.clone())
                    .or_insert(evidence);
            }
            let accuracy_context = accuracy_by_agent
                .as_ref()
                .and_then(|by_agent| by_agent.get(&agent).cloned());
            let benchmark_context = benchmark_by_agent
                .as_ref()
                .and_then(|by_agent| by_agent.get(&agent).cloned());
            let row = agent_readiness_row_from_results(
                &agent,
                &readiness,
                &ranking,
                accuracy_context,
                benchmark_context,
            );
            gap_issue_rows.extend(agent_readiness_gap_issue_rows(&row));
            rows.push(row);
        }

        rows.sort_by(|left, right| {
            right
                .comparison_score
                .cmp(&left.comparison_score)
                .then_with(|| right.readiness_score.cmp(&left.readiness_score))
                .then_with(|| {
                    right
                        .routing_confidence_score
                        .cmp(&left.routing_confidence_score)
                })
                .then_with(|| left.agent.cmp(&right.agent))
        });
        for (index, row) in rows.iter_mut().enumerate() {
            row.rank = index + 1;
        }
        let recommended_agent = rows
            .iter()
            .find(|row| row.candidate_count > 0 && row.comparison_score > 0)
            .map(agent_readiness_recommendation);
        let prompt_instance_ids = rows
            .iter()
            .filter_map(|row| row.best_candidate.as_ref())
            .take(8)
            .map(|candidate| candidate.instance_id.clone())
            .collect::<Vec<_>>();
        let prompt_available = !prompt_instance_ids.is_empty();
        let summary = agent_readiness_summary(&rows, &gap_issue_rows, &recommended_agent);
        let evidence_references = evidence_by_id.into_values().collect::<Vec<_>>();
        let returned_agent_count = rows.len();
        let mut completed_stages = vec!["catalog", "agent-readiness", "agent-ranking"];
        if params.include_routing_accuracy {
            completed_stages.push("routing-accuracy-context");
        }
        if params.include_benchmarks {
            completed_stages.push("benchmark-context");
        }
        let aggregation_notes = if params.include_benchmarks {
            vec![
                "Benchmark context is capped at 25 app-local benchmark rows for bounded comparison latency."
                    .to_string(),
            ]
        } else {
            Vec::new()
        };

        Ok(AgentReadinessComparisonResult {
            generated_by: "deterministic-service",
            catalog_available: true,
            filters,
            summary,
            agent_rows: rows,
            recommended_agent,
            gap_issue_rows,
            evidence_references,
            prompt_request: AgentReadinessPromptRequest {
                available: prompt_available,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "task_readiness",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::TaskReadiness,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(task),
                },
                note: if prompt_available {
                    "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.compareAgentReadiness never sends provider traffic."
                        .to_string()
                } else {
                    "Prompt preview is unavailable until local catalog evidence produces cross-agent candidates."
                        .to_string()
                },
            },
            aggregation: aggregation_runtime_metadata(AggregationRuntimeInput {
                started_at,
                timeout_ms: TASK_AGGREGATION_TIMEOUT_MS,
                limit: limit_per_agent,
                scanned_count: returned_agent_count,
                total_count: total_agent_count,
                completed_stages,
                skipped_stages: Vec::new(),
                blocker_codes: Vec::new(),
                fallback_used: false,
                notes: aggregation_notes,
            }),
            safety_flags: agent_readiness_safety_flags(),
        })
    }

    pub fn build_task_cockpit(
        &self,
        params: TaskCockpitParams,
    ) -> Result<TaskCockpitResult, ServiceError> {
        const MIN_TIMEOUT_MS: u64 = 500;
        const MAX_TIMEOUT_MS: u64 = 30_000;

        let started_at = Instant::now();
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.buildCockpit requires a non-empty task".to_string(),
            ));
        }

        let limit = params.limit.unwrap_or(8).clamp(1, 25);
        let timeout_ms = params
            .timeout_ms
            .unwrap_or(TASK_COCKPIT_TIMEOUT_MS)
            .clamp(MIN_TIMEOUT_MS, MAX_TIMEOUT_MS);
        let budget = Duration::from_millis(timeout_ms);
        let include_session_review = params.include_session_review.unwrap_or(true);
        let include_provider_observability = params.include_provider_observability.unwrap_or(true);
        let include_remediation_context = params.include_remediation_context.unwrap_or(true);
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned);
        let candidate_instance_ids = normalize_string_list(params.candidate_instance_ids);
        let mut fallback_reasons = Vec::new();

        let readiness = self.check_task_readiness(TaskReadinessParams {
            task: task.to_string(),
            agent: agent.clone(),
            candidate_instance_ids: candidate_instance_ids.clone(),
            limit: Some(limit),
        })?;
        let ranking = skill_route_ranking_from_readiness(readiness.clone());
        let comparison = self.compare_agent_readiness(CompareAgentReadinessParams {
            task: readiness.task.clone(),
            agents: agent.clone().into_iter().collect(),
            limit_per_agent: Some(limit.min(3)),
            include_routing_accuracy: false,
            include_benchmarks: false,
        })?;
        let session_review_rows = if include_session_review
            && readiness.catalog_available
            && !task_cockpit_budget_reached(started_at, budget)
        {
            self.list_agent_skill_reviews(AgentSessionListSkillReviewsParams {
                agent: agent.clone(),
                outcome: None,
                trace_import_id: None,
                limit: Some(limit),
            })?
            .reviews
            .iter()
            .take(limit)
            .map(task_cockpit_session_review_row)
            .collect::<Vec<_>>()
        } else {
            if !include_session_review {
                fallback_reasons.push(
                    "Session-review context was skipped by the cockpit request filters."
                        .to_string(),
                );
            } else if task_cockpit_budget_reached(started_at, budget) {
                fallback_reasons.push(
                    "Task cockpit reached its bounded time budget before session-review context."
                        .to_string(),
                );
            }
            Vec::new()
        };
        let provider_observability = if include_provider_observability
            && readiness.catalog_available
            && !task_cockpit_budget_reached(started_at, budget)
        {
            Some(
                self.llm_provider_observability(LlmProviderObservabilityParams {
                    profile_id: None,
                    provider: None,
                    model: None,
                    status: None,
                    action: None,
                    limit: Some(limit),
                })?,
            )
        } else {
            if !include_provider_observability {
                fallback_reasons.push(
                    "Provider-observability context was skipped by the cockpit request filters."
                        .to_string(),
                );
            } else if task_cockpit_budget_reached(started_at, budget) {
                fallback_reasons.push(
                    "Task cockpit reached its bounded time budget before provider-observability context."
                        .to_string(),
                );
            }
            None
        };
        let remediation_candidate_ids = if candidate_instance_ids.is_empty() {
            ranking
                .route_candidates
                .iter()
                .take(limit.min(5))
                .map(|candidate| candidate.instance_id.clone())
                .collect::<Vec<_>>()
        } else {
            candidate_instance_ids.clone()
        };
        let remediation_plan = if include_remediation_context
            && readiness.catalog_available
            && !task_cockpit_budget_reached(started_at, budget)
        {
            Some(self.plan_remediation(RemediationPlanParams {
                agent: agent.clone(),
                task: Some(readiness.task.clone()),
                project_root: None,
                focus: None,
                focus_areas: vec![
                    "finding".to_string(),
                    "gap".to_string(),
                    "ambiguity".to_string(),
                    "drift".to_string(),
                    "readiness".to_string(),
                ],
                limit: Some(limit.min(5)),
                candidate_instance_ids: remediation_candidate_ids.clone(),
                include_deferred: false,
            })?)
        } else {
            if !include_remediation_context {
                fallback_reasons.push(
                    "Remediation context was skipped by the cockpit request filters.".to_string(),
                );
            } else if task_cockpit_budget_reached(started_at, budget) {
                fallback_reasons.push(
                    "Task cockpit reached its bounded time budget before remediation planning."
                        .to_string(),
                );
            }
            None
        };
        let batch_review = if include_remediation_context
            && remediation_plan.is_some()
            && !task_cockpit_budget_reached(started_at, budget)
        {
            Some(self.batch_review_remediation(RemediationBatchReviewParams {
                task: Some(readiness.task.clone()),
                agent: agent.clone(),
                project_root: None,
                workspace_label: None,
                rule_id: None,
                severity: None,
                status: None,
                triage_status: None,
                candidate_instance_ids: remediation_candidate_ids,
                group_by: vec![
                    "risk".to_string(),
                    "rule".to_string(),
                    "agent".to_string(),
                    "task".to_string(),
                ],
                limit: Some(limit.min(3)),
            })?)
        } else {
            if include_remediation_context
                && remediation_plan.is_some()
                && task_cockpit_budget_reached(started_at, budget)
            {
                fallback_reasons.push(
                    "Task cockpit returned remediation plan rows and skipped batch review after reaching its bounded time budget."
                        .to_string(),
                );
            }
            None
        };

        let mut evidence_references = Vec::new();
        evidence_references.extend(readiness.evidence_references.clone());
        evidence_references.extend(ranking.evidence_references.clone());
        evidence_references.extend(comparison.evidence_references.clone());
        if let Some(remediation_plan) = remediation_plan.as_ref() {
            evidence_references.extend(remediation_plan.evidence_references.clone());
        }
        if let Some(batch_review) = batch_review.as_ref() {
            evidence_references.extend(batch_review.evidence_references.clone());
        }
        if let Some(provider_observability) = provider_observability.as_ref() {
            evidence_references.extend(provider_observability_evidence_as_task_refs(
                &provider_observability.evidence_references,
            ));
        }
        dedupe_evidence_references(&mut evidence_references);

        let mut gap_notes = Vec::new();
        gap_notes.extend(readiness.missing_gap_notes.clone());
        gap_notes.extend(ranking.likely_miss_risks.clone());
        gap_notes.extend(
            comparison
                .gap_issue_rows
                .iter()
                .filter(|row| row.severity != "blocker")
                .map(|row| row.detail.clone()),
        );
        if let Some(provider_observability) = provider_observability.as_ref() {
            gap_notes.extend(provider_observability.gap_notes.clone());
        }
        if let Some(remediation_plan) = remediation_plan.as_ref() {
            gap_notes.extend(remediation_plan.gap_notes.clone());
        }
        if let Some(batch_review) = batch_review.as_ref() {
            gap_notes.extend(batch_review.gap_notes.clone());
        }
        normalize_note_list(&mut gap_notes);

        let mut blocker_notes = Vec::new();
        blocker_notes.extend(readiness.blocker_risk_notes.clone());
        blocker_notes.extend(ranking.likely_wrong_pick_risks.clone());
        blocker_notes.extend(
            comparison
                .gap_issue_rows
                .iter()
                .filter(|row| row.severity == "blocker")
                .map(|row| row.detail.clone()),
        );
        if let Some(provider_observability) = provider_observability.as_ref() {
            blocker_notes.extend(provider_observability.blocker_notes.clone());
        }
        if let Some(remediation_plan) = remediation_plan.as_ref() {
            blocker_notes.extend(remediation_plan.blocker_notes.clone());
        }
        if let Some(batch_review) = batch_review.as_ref() {
            blocker_notes.extend(batch_review.blocker_notes.clone());
        }
        blocker_notes.extend(fallback_reasons.iter().cloned());
        normalize_note_list(&mut blocker_notes);

        let task_rows = vec![TaskCockpitTaskRow {
            id: "task",
            task: readiness.task.clone(),
            readiness_score: readiness.score,
            readiness_band: readiness.band,
            routing_confidence_score: ranking.overall_confidence_score,
            routing_confidence_band: ranking.overall_confidence_band,
            recommended_agent: comparison
                .recommended_agent
                .as_ref()
                .map(|recommendation| recommendation.agent.clone()),
            top_skill_name: ranking
                .route_candidates
                .first()
                .map(|candidate| candidate.skill_name.clone()),
            candidate_count: readiness.candidate_skills.len(),
            gap_count: gap_notes.len(),
            blocker_count: blocker_notes.len(),
            evidence_refs: evidence_references
                .iter()
                .take(limit)
                .map(|evidence| evidence.id.clone())
                .collect(),
        }];
        let agent_route_rows = comparison
            .agent_rows
            .iter()
            .take(limit)
            .map(task_cockpit_agent_route_row)
            .collect::<Vec<_>>();
        let skill_candidate_rows = ranking
            .route_candidates
            .iter()
            .take(limit)
            .map(|candidate| {
                task_cockpit_skill_candidate_row(
                    candidate,
                    readiness
                        .candidate_skills
                        .iter()
                        .find(|ready| ready.instance_id == candidate.instance_id),
                )
            })
            .collect::<Vec<_>>();
        let readiness_rows = task_cockpit_readiness_rows(&readiness, &ranking, &comparison, limit);
        let provider_observability_rows = provider_observability
            .as_ref()
            .map(|observability| task_cockpit_provider_observability_rows(observability, limit))
            .unwrap_or_default();
        let remediation_next_steps = task_cockpit_remediation_next_steps(
            remediation_plan.as_ref(),
            batch_review.as_ref(),
            limit,
        );

        let safety_flags = task_cockpit_safety_flags();
        let cockpit_sections = task_cockpit_sections(
            &readiness,
            &ranking,
            &comparison,
            &session_review_rows,
            &provider_observability_rows,
            &remediation_next_steps,
            safety_flags,
        );
        let summary = task_cockpit_summary(
            &readiness,
            &ranking,
            &comparison,
            TaskCockpitSummaryCounts {
                session_review_count: session_review_rows.len(),
                provider_observability_row_count: provider_observability_rows.len(),
                remediation_next_step_count: remediation_next_steps.len(),
                gap_count: gap_notes.len(),
                blocker_count: blocker_notes.len(),
            },
        );
        let prompt_instance_ids = skill_candidate_rows
            .iter()
            .take(8)
            .map(|candidate| candidate.instance_id.clone())
            .collect::<Vec<_>>();
        let elapsed_ms = task_cockpit_elapsed_ms(started_at);
        if elapsed_ms >= timeout_ms && fallback_reasons.is_empty() {
            fallback_reasons.push(
                "Task cockpit completed after its bounded time budget; results are shown with timeout diagnostics."
                    .to_string(),
            );
        }
        let partial = !fallback_reasons.is_empty();
        let fallback_reason = if partial {
            Some(fallback_reasons.join(" "))
        } else {
            None
        };
        let mut completed_stages = vec!["task-readiness", "routing", "agent-comparison"];
        if !session_review_rows.is_empty() {
            completed_stages.push("session-review");
        }
        if provider_observability.is_some() {
            completed_stages.push("provider-observability");
        }
        if remediation_plan.is_some() {
            completed_stages.push("remediation-plan");
        }
        if batch_review.is_some() {
            completed_stages.push("batch-review");
        }
        let mut skipped_stages = Vec::new();
        if (!include_session_review || session_review_rows.is_empty()) && partial {
            skipped_stages.push("session-review");
        }
        if (!include_provider_observability || provider_observability.is_none()) && partial {
            skipped_stages.push("provider-observability");
        }
        if (!include_remediation_context || remediation_plan.is_none()) && partial {
            skipped_stages.push("remediation-plan");
        }
        if (!include_remediation_context || (remediation_plan.is_some() && batch_review.is_none()))
            && partial
        {
            skipped_stages.push("batch-review");
        }
        let blocker_codes = if partial {
            vec!["task-cockpit-partial"]
        } else {
            Vec::new()
        };

        Ok(TaskCockpitResult {
            generated_by: "local-v2.73",
            catalog_available: readiness.catalog_available || comparison.catalog_available,
            partial,
            elapsed_ms,
            fallback_reason,
            filters: TaskCockpitFilters {
                task: readiness.task.clone(),
                agent,
                candidate_instance_ids,
                limit,
                include_session_review,
                include_provider_observability,
                include_remediation_context,
                timeout_ms,
            },
            summary,
            cockpit_sections,
            task_rows,
            agent_route_rows,
            skill_candidate_rows,
            readiness_rows,
            session_review_rows,
            provider_observability_rows,
            remediation_next_steps,
            gap_notes,
            blocker_notes,
            evidence_references,
            prompt_request: AgentReadinessPromptRequest {
                available: !prompt_instance_ids.is_empty(),
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "task_cockpit",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::TaskCockpit,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(readiness.task),
                },
                note: "Optional provider-backed cockpit explanation must be requested through prompt preview and explicit confirmation; task.buildCockpit never sends provider traffic."
                    .to_string(),
            },
            aggregation: aggregation_runtime_metadata(AggregationRuntimeInput {
                started_at,
                timeout_ms,
                limit,
                scanned_count: readiness.aggregation.scanned_count,
                total_count: readiness.aggregation.total_count,
                completed_stages,
                skipped_stages,
                blocker_codes,
                fallback_used: partial,
                notes: fallback_reasons,
            }),
            safety_flags,
        })
    }

    pub fn build_skill_lifecycle_timeline(
        &self,
        params: SkillLifecycleTimelineParams,
    ) -> Result<SkillLifecycleTimelineResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "skill.lifecycleTimeline limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let filters = skill_lifecycle_filters(&params, &adapter_ctx, &roots);
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_skill_lifecycle_timeline_result(filters, false));
        };

        let mut evidence_references = Vec::new();
        let mut gap_notes = Vec::new();
        let mut blocker_notes = Vec::new();
        let skills = catalog
            .list_skill_instances_for_project_context(adapter_ctx.project_root.as_deref())?
            .into_iter()
            .filter(|skill| !is_pi_plain_markdown_instance_noise(skill))
            .map(skill_lifecycle_meta_from_instance)
            .collect::<Vec<_>>();
        let skill_by_id = skills
            .iter()
            .map(|skill| (skill.instance_id.clone(), skill.clone()))
            .collect::<BTreeMap<_, _>>();
        let visible_ids = skill_lifecycle_visible_ids(&filters, &skills);

        if !skill_lifecycle_has_skill_filter(&filters) && skills.is_empty() {
            gap_notes.push(
                "No visible local skill rows are available for the current project context."
                    .to_string(),
            );
        }
        if skill_lifecycle_has_skill_filter(&filters) && visible_ids.is_empty() {
            gap_notes
                .push("No visible local skill matched the selected lifecycle filters.".to_string());
        }

        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let mut rows = Vec::new();

        for skill in &skills {
            if !visible_ids.contains(&skill.instance_id) {
                continue;
            }
            let evidence_id = push_task_readiness_evidence(
                &mut evidence_references,
                "skill",
                &skill.instance_id,
                format!(
                    "Catalog lifecycle metadata for `{}` ({}, {}, enabled={})",
                    redact_for_llm_preview(&skill.skill_name),
                    redact_for_llm_preview(&skill.agent),
                    redact_for_llm_preview(&skill.scope),
                    skill.enabled
                ),
                None,
                Some(skill.instance_id.clone()),
            );
            rows.push(skill_lifecycle_skill_seen_row(skill, &evidence_id));
            if skill.last_seen != skill.first_seen {
                rows.push(skill_lifecycle_skill_observed_row(skill, &evidence_id));
            }
        }

        for finding in findings
            .iter()
            .filter(|finding| skill_lifecycle_finding_matches(&filters, finding, &skill_by_id))
        {
            let skill = skill_lifecycle_finding_skill(finding, &skill_by_id);
            let evidence_id = push_task_readiness_evidence(
                &mut evidence_references,
                "finding",
                &finding.id,
                format!(
                    "{} finding `{}`: {}",
                    redact_for_llm_preview(&finding.effective_severity),
                    redact_for_llm_preview(&finding.rule_id),
                    redact_for_llm_preview(&finding.message)
                ),
                Some(finding.effective_severity.clone()),
                skill
                    .map(|skill| skill.instance_id.clone())
                    .or_else(|| finding.instance_id.clone()),
            );
            rows.push(skill_lifecycle_finding_row(finding, skill, &evidence_id));
            if let Some(updated_at) = finding.triage_updated_at {
                rows.push(skill_lifecycle_finding_triage_row(
                    finding,
                    skill,
                    updated_at,
                    &evidence_id,
                ));
            }
        }

        for conflict in conflicts
            .iter()
            .filter(|conflict| skill_lifecycle_conflict_matches(&filters, conflict, &skill_by_id))
        {
            let skill = skill_lifecycle_conflict_skill(conflict, &skill_by_id, &visible_ids);
            let evidence_id = push_task_readiness_evidence(
                &mut evidence_references,
                "conflict",
                &conflict.id,
                format!(
                    "Same-agent conflict `{}` covers {} instance(s)",
                    redact_for_llm_preview(&conflict.reason),
                    conflict.instance_ids.len()
                ),
                Some("warning".to_string()),
                skill
                    .map(|skill| skill.instance_id.clone())
                    .or_else(|| conflict.winner_id.clone()),
            );
            rows.push(skill_lifecycle_conflict_row(conflict, skill, &evidence_id));
        }

        for group in analysis.groups.iter().filter(|group| {
            skill_lifecycle_analysis_matches(&filters, group, &skill_by_id, &visible_ids)
        }) {
            let skill = skill_lifecycle_analysis_skill(group, &skill_by_id, &visible_ids);
            let evidence_id = push_task_readiness_evidence(
                &mut evidence_references,
                "analysis",
                &group.id,
                format!(
                    "{} analysis `{}`: {}",
                    redact_for_llm_preview(&group.severity),
                    redact_for_llm_preview(&group.kind),
                    redact_for_llm_preview(&group.title)
                ),
                Some(group.severity.clone()),
                skill.map(|skill| skill.instance_id.clone()),
            );
            rows.push(skill_lifecycle_analysis_row(group, skill, &evidence_id));
        }

        if filters.include_stale_drift {
            let stale = self.detect_stale_drift(DetectStaleDriftParams {
                agent: filters
                    .selected_skill_agent
                    .clone()
                    .or_else(|| filters.agent.clone()),
                candidate_instance_ids: if visible_ids.is_empty() {
                    Vec::new()
                } else {
                    visible_ids.iter().cloned().collect()
                },
                limit: Some(filters.limit.clamp(50, 100)),
                stale_days: None,
                thresholds: StaleDriftThresholds::default(),
            })?;
            extend_evidence_references(&mut evidence_references, stale.evidence_references);
            gap_notes.extend(stale.gap_notes);
            blocker_notes.extend(stale.blocker_notes);
            for stale_row in stale.stale_drift_rows.iter().filter(|row| {
                skill_lifecycle_stale_row_matches(&filters, row, &skill_by_id, &visible_ids)
            }) {
                if stale_row.stale_drift_score == 0 {
                    continue;
                }
                rows.push(skill_lifecycle_stale_drift_row(stale_row));
            }
        }

        if filters.include_remediation_history {
            if !self.remediation_history_path().exists() {
                gap_notes.push("No app-local remediation history records are saved.".to_string());
            }
            for record in self.load_remediation_history()?.iter().filter(|record| {
                skill_lifecycle_remediation_history_matches(
                    &filters,
                    record,
                    &skill_by_id,
                    &visible_ids,
                )
            }) {
                let related_instance_id = skill_lifecycle_related_instance_for_strings(
                    record
                        .source_item_refs
                        .iter()
                        .chain(record.batch_review_item_ids.iter())
                        .chain(record.evidence_refs.iter()),
                    &skill_by_id,
                );
                let evidence_id = push_task_readiness_evidence(
                    &mut evidence_references,
                    "remediation_history",
                    &record.id,
                    format!(
                        "App-local remediation history `{}` with decision `{}` and status `{}`",
                        redact_for_llm_preview(&record.title),
                        redact_for_llm_preview(&record.decision),
                        redact_for_llm_preview(&record.status)
                    ),
                    Some(record.status.clone()),
                    related_instance_id.clone(),
                );
                rows.push(skill_lifecycle_remediation_history_row(
                    record,
                    related_instance_id
                        .as_deref()
                        .and_then(|id| skill_by_id.get(id)),
                    &evidence_id,
                ));
            }
        }

        if filters.include_prompt_runs {
            if !self.llm_prompt_runs_path().exists() {
                gap_notes.push("No app-local prompt run metadata records are saved.".to_string());
            }
            for run in self.load_llm_prompt_runs()?.iter().filter(|run| {
                skill_lifecycle_prompt_run_matches(&filters, run, &skill_by_id, &visible_ids)
            }) {
                let related_instance_id = skill_lifecycle_related_instance_for_strings(
                    run.instance_ids
                        .iter()
                        .chain(run.instance_id.iter())
                        .chain(run.definition_id.iter()),
                    &skill_by_id,
                );
                let evidence_id = push_task_readiness_evidence(
                    &mut evidence_references,
                    "prompt_run",
                    &run.id,
                    format!(
                        "App-local prompt run metadata `{}` action `{}` status `{}`",
                        redact_for_llm_preview(&run.id),
                        redact_for_llm_preview(&run.action),
                        redact_for_llm_preview(&run.status)
                    ),
                    Some(run.status.clone()),
                    related_instance_id,
                );
                rows.push(skill_lifecycle_prompt_run_row(
                    run,
                    &skill_by_id,
                    &evidence_id,
                ));
            }
        }

        if filters.include_session_reviews {
            if !self.agent_session_reviews_path().exists() {
                gap_notes.push("No app-local agent session skill reviews are saved.".to_string());
            }
            for review in self.load_agent_session_reviews()?.iter().filter(|review| {
                skill_lifecycle_session_review_matches(&filters, review, &skill_by_id, &visible_ids)
            }) {
                let related_instance_id = review
                    .analysis
                    .detected_skills
                    .iter()
                    .find(|skill| skill_by_id.contains_key(&skill.instance_id))
                    .map(|skill| skill.instance_id.clone())
                    .or_else(|| {
                        skill_lifecycle_related_instance_for_strings(
                            review
                                .expected_skill_refs
                                .iter()
                                .chain(review.analysis.evidence_refs.iter()),
                            &skill_by_id,
                        )
                    });
                let evidence_id = push_task_readiness_evidence(
                    &mut evidence_references,
                    "session_review",
                    &review.id,
                    format!(
                        "App-local session review `{}` outcome `{}`",
                        redact_for_llm_preview(&review.title),
                        redact_for_llm_preview(&review.analysis.outcome)
                    ),
                    Some(review.analysis.outcome.clone()),
                    related_instance_id,
                );
                rows.push(skill_lifecycle_session_review_row(
                    review,
                    &skill_by_id,
                    &evidence_id,
                ));
            }
        }

        rows.sort_by(skill_lifecycle_row_sort);
        rows.truncate(filters.limit);
        if rows.is_empty() {
            gap_notes.push(
                "No deterministic local lifecycle events matched the current filters.".to_string(),
            );
        }
        blocker_notes.push(
            "Skill lifecycle timeline is read-only; it does not write skills, mutate agent config, create snapshots, execute scripts, send provider requests, or change triage."
                .to_string(),
        );
        normalize_note_list(&mut gap_notes);
        normalize_note_list(&mut blocker_notes);
        dedupe_evidence_references(&mut evidence_references);

        let skill_rows = skill_lifecycle_skill_rows(&rows, &skill_by_id);
        let agent_rows = skill_lifecycle_agent_rows(&rows, &skill_by_id);
        let summary = skill_lifecycle_summary(&rows, &skill_rows, &agent_rows, &filters);
        let prompt_instance_ids = skill_rows
            .iter()
            .take(12)
            .map(|row| row.instance_id.clone())
            .collect::<Vec<_>>();

        Ok(SkillLifecycleTimelineResult {
            generated_by: "local-v2.66",
            catalog_available: true,
            filters,
            summary,
            timeline_rows: rows,
            skill_rows,
            agent_rows,
            gap_notes,
            blocker_notes,
            evidence_references,
            prompt_request: AgentReadinessPromptRequest {
                available: !prompt_instance_ids.is_empty(),
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "skill_lifecycle_timeline",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::SkillLifecycleTimeline,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: None,
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: Some(
                        "Explain deterministic skill lifecycle timeline rows using only local redacted evidence."
                            .to_string(),
                    ),
                },
                note: "Optional provider-backed lifecycle wording must be requested through prompt preview and explicit confirmation; skill.lifecycleTimeline never sends provider traffic and remains copy-only."
                    .to_string(),
            },
            safety_flags: skill_lifecycle_timeline_safety_flags(),
        })
    }

    pub fn list_task_benchmarks(
        &self,
        params: ListTaskBenchmarksParams,
    ) -> Result<TaskBenchmarkListResult, ServiceError> {
        let mut benchmarks = self.load_task_benchmarks()?;
        if let Some(limit) = params.limit {
            benchmarks.truncate(limit);
        }
        Ok(TaskBenchmarkListResult {
            count: benchmarks.len(),
            benchmarks,
            app_local_only: true,
            provider_request_sent: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn save_task_benchmark(
        &self,
        params: SaveTaskBenchmarkParams,
    ) -> Result<SaveTaskBenchmarkResult, ServiceError> {
        let task = params.task.trim();
        if task.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.saveBenchmark requires a non-empty task".to_string(),
            ));
        }
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .map(ToOwned::to_owned)
            .unwrap_or_else(|| task.chars().take(72).collect::<String>());
        let id = params
            .id
            .as_deref()
            .map(str::trim)
            .filter(|id| !id.is_empty())
            .map(sanitize_benchmark_id)
            .unwrap_or_else(|| generated_benchmark_id(&title, task));
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.saveBenchmark requires a benchmark id containing letters, numbers, '-' or '_'"
                    .to_string(),
            ));
        }

        let mut benchmarks = self.load_task_benchmarks()?;
        let now = unix_timestamp_millis();
        let existing_index = benchmarks.iter().position(|benchmark| benchmark.id == id);
        let created_at = existing_index
            .and_then(|index| benchmarks.get(index).map(|benchmark| benchmark.created_at))
            .unwrap_or(now);
        let benchmark = TaskBenchmarkRecord {
            id: id.clone(),
            title,
            task: task.to_string(),
            expected_skill_refs: normalize_string_list(params.expected_skill_refs),
            expected_skill_names: normalize_string_list(params.expected_skill_names),
            acceptable_agents: normalize_string_list(params.acceptable_agents),
            acceptable_scopes: normalize_string_list(params.acceptable_scopes),
            success_criteria: normalize_string_list(params.success_criteria),
            created_at,
            updated_at: now,
        };
        let created = if let Some(index) = existing_index {
            benchmarks[index] = benchmark.clone();
            false
        } else {
            benchmarks.push(benchmark.clone());
            true
        };
        self.save_task_benchmarks(&benchmarks)?;
        Ok(SaveTaskBenchmarkResult {
            benchmark,
            created,
            app_local_only: true,
            provider_request_sent: false,
            agent_config_mutated: false,
        })
    }

    pub fn delete_task_benchmark(
        &self,
        params: DeleteTaskBenchmarkParams,
    ) -> Result<DeleteTaskBenchmarkResult, ServiceError> {
        let id = sanitize_benchmark_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "task.deleteBenchmark requires a benchmark id".to_string(),
            ));
        }
        let mut benchmarks = self.load_task_benchmarks()?;
        let before = benchmarks.len();
        benchmarks.retain(|benchmark| benchmark.id != id);
        let deleted = benchmarks.len() != before;
        if deleted {
            self.save_task_benchmarks(&benchmarks)?;
        }
        Ok(DeleteTaskBenchmarkResult {
            benchmark_id: id,
            deleted,
            remaining_count: benchmarks.len(),
            app_local_only: true,
            provider_request_sent: false,
            agent_config_mutated: false,
        })
    }

    pub fn evaluate_task_benchmarks(
        &self,
        params: EvaluateTaskBenchmarksParams,
    ) -> Result<TaskBenchmarkEvaluationResult, ServiceError> {
        let requested_ids = params
            .ids
            .iter()
            .map(|id| sanitize_benchmark_id(id.trim()))
            .filter(|id| !id.is_empty())
            .collect::<Vec<_>>();
        let mut benchmarks = self.load_task_benchmarks()?;
        if !requested_ids.is_empty() {
            benchmarks.retain(|benchmark| requested_ids.contains(&benchmark.id));
        }
        if let Some(limit) = params.limit {
            benchmarks.truncate(limit);
        }

        let mut benchmark_results = Vec::new();
        let mut catalog_available = self.catalog_path().exists();
        for benchmark in &benchmarks {
            let ranking = self.rank_skill_routes(RankSkillRoutesParams {
                task: benchmark.task.clone(),
                agent: None,
                candidate_instance_ids: Vec::new(),
                limit: Some(8),
            })?;
            catalog_available &= ranking.catalog_available;
            benchmark_results.push(task_benchmark_evaluation_item(benchmark, ranking));
        }
        if benchmarks.is_empty() {
            catalog_available = self.catalog_path().exists();
        }

        let blocker_notes = task_benchmark_blocker_notes(&benchmark_results, catalog_available);
        let prompt_request = task_benchmark_prompt_request(&benchmark_results);
        Ok(TaskBenchmarkEvaluationResult {
            generated_by: "deterministic-service",
            catalog_available,
            evaluated_count: benchmark_results.len(),
            summary: task_benchmark_summary(&benchmark_results, catalog_available),
            benchmark_results,
            blocker_notes,
            prompt_request,
            safety_flags: task_benchmark_safety_flags(),
        })
    }

    pub fn save_routing_baseline(
        &self,
        params: SaveRoutingBaselineParams,
    ) -> Result<SaveRoutingBaselineResult, ServiceError> {
        let evaluation = self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
            ids: params.ids,
            limit: params.limit,
        })?;
        let baseline = routing_regression_baseline_from_evaluation(evaluation);
        self.save_routing_regression_baseline(&baseline)?;
        Ok(SaveRoutingBaselineResult {
            benchmark_count: baseline.evaluated_count,
            baseline,
            generated_by: "deterministic-service",
            app_local_only: true,
            baseline_file: "task-routing-baseline.json",
            provider_request_sent: false,
            agent_config_mutated: false,
            skill_files_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn detect_routing_regression(
        &self,
        params: DetectRoutingRegressionParams,
    ) -> Result<RoutingRegressionDetectionResult, ServiceError> {
        let current_evaluation = self.evaluate_task_benchmarks(EvaluateTaskBenchmarksParams {
            ids: params.ids,
            limit: params.limit,
        })?;
        let baseline = self.load_routing_regression_baseline()?;
        let Some(baseline) = baseline else {
            let blocker_notes = vec![
                "No app-local routing baseline is saved; run task.saveRoutingBaseline before regression detection."
                    .to_string(),
            ];
            return Ok(RoutingRegressionDetectionResult {
                generated_by: "deterministic-service",
                status: "baseline_missing",
                baseline_available: false,
                catalog_available: current_evaluation.catalog_available,
                baseline_evaluated_count: 0,
                current_evaluated_count: current_evaluation.evaluated_count,
                regression_count: 0,
                missing_benchmark_count: 0,
                summary: format!(
                    "No app-local routing baseline was available; evaluated {} current benchmark(s) without writing a baseline.",
                    current_evaluation.evaluated_count
                ),
                items: Vec::new(),
                blocker_notes,
                baseline: None,
                current_evaluation,
                safety_flags: task_benchmark_safety_flags(),
            });
        };

        let comparison = routing_regression_compare(
            &baseline,
            &current_evaluation,
            params.score_drop_threshold.unwrap_or(10),
            params.confidence_drop_threshold.unwrap_or(10),
        );
        let regression_count = comparison.iter().filter(|item| item.regression).count();
        let missing_benchmark_count = comparison
            .iter()
            .filter(|item| item.status == "missing_current_benchmark")
            .count();
        let mut blocker_notes = current_evaluation.blocker_notes.clone();
        if !current_evaluation.catalog_available {
            blocker_notes.push(
                "No local catalog is available; routing regression detection cannot verify current routes."
                    .to_string(),
            );
        }
        if baseline.benchmark_results.is_empty() {
            blocker_notes.push("Saved routing baseline contains no benchmark results.".to_string());
        }
        blocker_notes.sort();
        blocker_notes.dedup();
        let status = routing_regression_status(
            regression_count,
            missing_benchmark_count,
            current_evaluation.catalog_available,
        );
        Ok(RoutingRegressionDetectionResult {
            generated_by: "deterministic-service",
            status,
            baseline_available: true,
            catalog_available: current_evaluation.catalog_available,
            baseline_evaluated_count: baseline.evaluated_count,
            current_evaluated_count: current_evaluation.evaluated_count,
            regression_count,
            missing_benchmark_count,
            summary: routing_regression_summary(
                regression_count,
                missing_benchmark_count,
                comparison.len(),
                current_evaluation.catalog_available,
            ),
            items: comparison,
            blocker_notes,
            baseline: Some(baseline),
            current_evaluation,
            safety_flags: task_benchmark_safety_flags(),
        })
    }

    pub fn routing_accuracy_dashboard(
        &self,
        params: RoutingAccuracyDashboardParams,
    ) -> Result<RoutingAccuracyDashboardResult, ServiceError> {
        let now = unix_timestamp_millis();
        let window_days = params.window_days.unwrap_or(30).clamp(1, 365);
        let limit = params.limit.unwrap_or(25).clamp(1, 250);
        let window_start_millis = now.saturating_sub(i64::from(window_days) * 86_400_000);
        let agent_filter = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(str::to_string);

        let imports_file_available = self.trace_imports_path().exists();
        let benchmark_file_available = self.task_benchmarks_path().exists();
        let baseline_file_available = self.routing_regression_baseline_path().exists();
        let mut imports = self.load_trace_imports()?;
        imports.retain(|import| {
            import.imported_at >= window_start_millis
                && import.imported_at <= now
                && routing_accuracy_agent_matches_import(&agent_filter, import)
        });

        let detection = self.detect_routing_regression(DetectRoutingRegressionParams {
            ids: Vec::new(),
            limit: None,
            score_drop_threshold: None,
            confidence_drop_threshold: None,
        })?;

        let mut summary = RoutingAccuracyDashboardSummary::default();
        let mut agent_rows: BTreeMap<String, RoutingAccuracyAgentAggregate> = BTreeMap::new();
        let mut history_rows: BTreeMap<i64, RoutingAccuracyOutcomeCounts> = BTreeMap::new();
        let mut gap_issue_rows = Vec::new();
        let mut recent_evidence_rows = Vec::new();

        for import in &imports {
            let outcome = routing_accuracy_normalize_outcome(&import.analysis.outcome);
            routing_accuracy_increment_summary(&mut summary, outcome);
            let agent = routing_accuracy_trace_agent(import);
            agent_rows
                .entry(agent.clone())
                .or_default()
                .record_trace(outcome);
            if params.include_history {
                let unix_day = import.imported_at.div_euclid(86_400_000);
                routing_accuracy_increment_counts(
                    history_rows.entry(unix_day).or_default(),
                    outcome,
                );
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "trace.importLocal",
                    agent: Some(agent),
                    title: import.title.clone(),
                    outcome: Some(outcome.to_string()),
                    detail: routing_accuracy_trace_detail(import),
                    evidence_refs: import.analysis.evidence_refs.clone(),
                    observed_at: Some(import.imported_at),
                });
            }
        }

        let benchmark_results = &detection.current_evaluation.benchmark_results;
        for item in benchmark_results
            .iter()
            .filter(|item| routing_accuracy_agent_matches_benchmark(&agent_filter, item))
        {
            summary.benchmark_count += 1;
            if matches!(
                item.expected_match_status,
                "expected_match" | "acceptable_match"
            ) {
                summary.benchmark_matched_count += 1;
            } else {
                summary.benchmark_gap_count += 1;
            }
            let agent = routing_accuracy_benchmark_agent(item);
            let agent_row = agent_rows.entry(agent.clone()).or_default();
            agent_row.benchmark_count += 1;
            if matches!(
                item.expected_match_status,
                "expected_match" | "acceptable_match"
            ) {
                agent_row.benchmark_matched_count += 1;
            } else {
                agent_row.benchmark_gap_count += 1;
            }
            if item.expected_match_status != "expected_match"
                || !item.gap_notes.is_empty()
                || !item.blocker_notes.is_empty()
            {
                gap_issue_rows.push(RoutingAccuracyIssueRow {
                    source: "task.evaluateBenchmarks",
                    severity: routing_accuracy_benchmark_severity(item),
                    agent: Some(agent.clone()),
                    title: item.title.clone(),
                    detail: routing_accuracy_benchmark_issue_detail(item),
                    evidence_refs: item.evidence_refs.clone(),
                });
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "task.evaluateBenchmarks",
                    agent: Some(agent),
                    title: item.title.clone(),
                    outcome: Some(item.expected_match_status.to_string()),
                    detail: format!(
                        "Benchmark score {}/100 with route confidence {}/100.",
                        item.score, item.route_confidence_score
                    ),
                    evidence_refs: item.evidence_refs.clone(),
                    observed_at: None,
                });
            }
        }

        for item in detection
            .items
            .iter()
            .filter(|item| routing_accuracy_agent_matches_regression(&agent_filter, item))
        {
            if item.regression {
                summary.regression_count += 1;
                let agent = routing_accuracy_regression_agent(item);
                let agent_key = agent.clone().unwrap_or_else(|| "unknown".to_string());
                agent_rows.entry(agent_key).or_default().regression_count += 1;
                gap_issue_rows.push(RoutingAccuracyIssueRow {
                    source: "task.detectRoutingRegression",
                    severity: "critical",
                    agent,
                    title: item.title.clone(),
                    detail: item.reasons.join(" "),
                    evidence_refs: item.evidence_refs.clone(),
                });
            }
            if item.status == "missing_current_benchmark" {
                summary.missing_benchmark_count += 1;
            }
            if params.include_recent_evidence {
                recent_evidence_rows.push(RoutingAccuracyEvidenceRow {
                    source: "task.detectRoutingRegression",
                    agent: routing_accuracy_regression_agent(item),
                    title: item.title.clone(),
                    outcome: Some(item.status.to_string()),
                    detail: routing_accuracy_regression_detail(item),
                    evidence_refs: item.evidence_refs.clone(),
                    observed_at: None,
                });
            }
        }

        summary.trace_count = imports.len();
        summary.accuracy_rate = routing_accuracy_rate(
            summary.hit_count,
            summary.hit_count
                + summary.miss_count
                + summary.wrong_pick_count
                + summary.ambiguous_count,
        );
        summary.known_outcome_rate = routing_accuracy_rate(
            summary.hit_count
                + summary.miss_count
                + summary.wrong_pick_count
                + summary.ambiguous_count,
            summary.trace_count,
        );
        summary.summary = routing_accuracy_summary_text(&summary, detection.catalog_available);

        let mut blocker_notes = detection.blocker_notes.clone();
        if !detection.catalog_available {
            blocker_notes.push(
                "No local catalog is available; dashboard metrics are limited to app-local trace metadata and saved benchmark records."
                    .to_string(),
            );
        }
        if !imports_file_available {
            blocker_notes.push("No app-local trace imports are saved.".to_string());
        }
        if !benchmark_file_available {
            blocker_notes.push("No app-local task benchmarks are saved.".to_string());
        }
        if !baseline_file_available {
            blocker_notes.push(
                "No app-local routing regression baseline is saved; regression evidence is unavailable."
                    .to_string(),
            );
        }
        if imports.is_empty() && benchmark_results.is_empty() {
            blocker_notes
                .push("No routing accuracy evidence matched the current filters.".to_string());
        }
        blocker_notes.sort();
        blocker_notes.dedup();

        gap_issue_rows.sort_by(|left, right| {
            routing_accuracy_severity_rank(left.severity)
                .cmp(&routing_accuracy_severity_rank(right.severity))
                .then_with(|| left.source.cmp(right.source))
                .then_with(|| left.title.cmp(&right.title))
        });
        gap_issue_rows.truncate(limit);
        recent_evidence_rows.sort_by(|left, right| {
            right
                .observed_at
                .cmp(&left.observed_at)
                .then_with(|| left.source.cmp(right.source))
                .then_with(|| left.title.cmp(&right.title))
        });
        recent_evidence_rows.truncate(limit);

        let agent_rows = agent_rows
            .into_iter()
            .map(|(agent, aggregate)| aggregate.into_row(agent))
            .collect::<Vec<_>>();
        let history_rows = if params.include_history {
            history_rows
                .into_iter()
                .map(|(unix_day, outcomes)| {
                    let known =
                        outcomes.hit + outcomes.miss + outcomes.wrong_pick + outcomes.ambiguous;
                    RoutingAccuracyHistoryRow {
                        unix_day,
                        trace_count: known + outcomes.unknown,
                        accuracy_rate: routing_accuracy_rate(outcomes.hit, known),
                        outcomes,
                    }
                })
                .collect()
        } else {
            Vec::new()
        };

        Ok(RoutingAccuracyDashboardResult {
            generated_by: "deterministic-service",
            catalog_available: detection.catalog_available,
            filters: RoutingAccuracyDashboardFilters {
                agent: agent_filter,
                window_days,
                limit,
                include_history: params.include_history,
                include_recent_evidence: params.include_recent_evidence,
                window_start_millis,
                window_end_millis: now,
            },
            summary,
            agent_rows,
            history_rows,
            gap_issue_rows,
            recent_evidence_rows,
            blocker_notes,
            prompt_request: routing_accuracy_prompt_request(&imports, benchmark_results),
            safety_flags: routing_accuracy_safety_flags(),
        })
    }

    pub fn review_agent_skill_use(
        &self,
        params: AgentSessionSkillReviewParams,
    ) -> Result<AgentSessionSkillReviewResult, ServiceError> {
        let content = params.content.trim().to_string();
        let requested_trace_import_ids = normalize_string_list(
            params
                .trace_import_ids
                .into_iter()
                .map(|id| sanitize_trace_import_id(id.trim()))
                .filter(|id| !id.is_empty())
                .collect(),
        );
        if content.is_empty() && requested_trace_import_ids.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "session.reviewAgentSkillUse requires transcript content or trace_import_ids"
                    .to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let redaction_roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&redaction_roots);
        let imports = self.load_trace_imports()?;
        let mut referenced_imports = Vec::new();
        let mut missing_trace_import_ids = Vec::new();
        for trace_id in &requested_trace_import_ids {
            if let Some(import) = imports.iter().find(|import| import.id == *trace_id) {
                referenced_imports.push(import.clone());
            } else {
                missing_trace_import_ids.push(trace_id.clone());
            }
        }

        let mut expected_refs = params.expected_skill_refs;
        let mut expected_names = params.expected_skill_names;
        for import in &referenced_imports {
            expected_refs.extend(import.expected_skill_refs.clone());
            expected_names.extend(import.expected_skill_names.clone());
        }
        let expected_skill_refs = redact_normalized_string_list(expected_refs, &redaction_roots);
        let expected_skill_names = redact_normalized_string_list(expected_names, &redaction_roots);

        let task = params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| truncate_chars(&redactor.redact(task), 320))
            .or_else(|| {
                referenced_imports
                    .iter()
                    .find_map(|import| import.task.clone())
            });
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .map(|title| truncate_chars(&redactor.redact(title), 180))
            .or_else(|| task.clone())
            .or_else(|| {
                referenced_imports
                    .first()
                    .map(|import| format!("Session review: {}", import.title))
            })
            .unwrap_or_else(|| "Agent session skill review".to_string());
        let source_kind = params
            .source_kind
            .as_deref()
            .map(str::trim)
            .filter(|source_kind| !source_kind.is_empty())
            .map(|source_kind| truncate_chars(&redactor.redact(source_kind), 100))
            .unwrap_or_else(|| {
                if content.is_empty() {
                    "trace-import-reference".to_string()
                } else {
                    "agent-session-transcript".to_string()
                }
            });
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(|agent| truncate_chars(&redactor.redact(agent), 80))
            .or_else(|| single_referenced_trace_agent(&referenced_imports));

        let max_excerpt_chars = params.max_excerpt_chars.unwrap_or(1_200).clamp(120, 6_000);
        let mut excerpt_parts = Vec::new();
        if !content.is_empty() {
            excerpt_parts.push(redactor.redact(&content));
        }
        excerpt_parts.extend(
            referenced_imports
                .iter()
                .map(|import| import.excerpt.clone()),
        );
        if excerpt_parts.is_empty() {
            excerpt_parts.push("No matching trace import excerpt was available.".to_string());
        }
        let excerpt = truncate_chars(&excerpt_parts.join("\n\n"), max_excerpt_chars);
        let excerpt_char_count = excerpt.chars().count();

        let mut analysis_parts = Vec::new();
        if !content.is_empty() {
            analysis_parts.push(content.clone());
        }
        analysis_parts.extend(
            referenced_imports
                .iter()
                .map(|import| import.excerpt.clone()),
        );
        let analysis_content = analysis_parts.join("\n\n");
        let analysis = self.analyze_agent_session_skill_use(
            &analysis_content,
            &expected_skill_refs,
            &expected_skill_names,
            agent.as_deref(),
            &referenced_imports,
            &missing_trace_import_ids,
        )?;
        let content_hash = trace_content_hash(&format!(
            "{}\0{}",
            content,
            requested_trace_import_ids.join("\0")
        ));
        let reviewed_at = unix_timestamp_millis();
        let redaction_summary = agent_session_review_redaction_summary_from(redactor.summary());
        let record = AgentSessionSkillReviewRecord {
            id: generated_agent_session_review_id(&title, &content_hash, reviewed_at),
            title,
            source_kind,
            agent,
            task,
            trace_import_ids: referenced_imports
                .iter()
                .map(|import| import.id.clone())
                .collect(),
            missing_trace_import_ids,
            expected_skill_refs,
            expected_skill_names,
            excerpt,
            excerpt_char_count,
            content_hash,
            redaction_summary,
            reviewed_at,
            analysis,
            safety_flags: agent_session_review_safety_flags(),
        };

        let mut reviews = self.load_agent_session_reviews()?;
        reviews.push(record.clone());
        self.save_agent_session_reviews(&reviews)?;
        Ok(AgentSessionSkillReviewResult {
            generated_by: "local-v2.62",
            review: record,
            count: reviews.len(),
            app_local_only: true,
            review_file: "agent-session-reviews.json",
            provider_request_sent: false,
            skill_files_mutated: false,
            agent_config_mutated: false,
            snapshot_created: false,
            triage_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
        })
    }

    pub fn list_agent_skill_reviews(
        &self,
        params: AgentSessionListSkillReviewsParams,
    ) -> Result<AgentSessionSkillReviewListResult, ServiceError> {
        let limit = params.limit.unwrap_or(50).clamp(1, 500);
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string);
        let outcome = params
            .outcome
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase());
        let trace_import_id = params
            .trace_import_id
            .as_deref()
            .map(str::trim)
            .map(sanitize_trace_import_id)
            .filter(|value| !value.is_empty());
        let mut reviews = self.load_agent_session_reviews()?;
        reviews.retain(|review| {
            let agent_matches = agent
                .as_deref()
                .is_none_or(|filter| review.agent.as_deref() == Some(filter));
            let outcome_matches = outcome
                .as_deref()
                .is_none_or(|filter| review.analysis.outcome.eq_ignore_ascii_case(filter));
            let trace_matches = trace_import_id.as_deref().is_none_or(|filter| {
                review
                    .trace_import_ids
                    .iter()
                    .any(|trace_id| trace_id == filter)
            });
            agent_matches && outcome_matches && trace_matches
        });
        let total_count = reviews.len();
        reviews.truncate(limit);
        Ok(AgentSessionSkillReviewListResult {
            generated_by: "local-v2.62",
            count: reviews.len(),
            total_count,
            reviews,
            app_local_only: true,
            review_file: "agent-session-reviews.json",
            provider_request_sent: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
            safety_flags: agent_session_review_safety_flags(),
        })
    }

    pub fn delete_agent_skill_review(
        &self,
        params: AgentSessionDeleteSkillReviewParams,
    ) -> Result<AgentSessionSkillReviewDeleteResult, ServiceError> {
        let id = sanitize_agent_session_review_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "session.deleteSkillReview requires a review id".to_string(),
            ));
        }
        let mut reviews = self.load_agent_session_reviews()?;
        let before = reviews.len();
        reviews.retain(|review| review.id != id);
        let deleted = reviews.len() != before;
        if deleted {
            self.save_agent_session_reviews(&reviews)?;
        }
        Ok(AgentSessionSkillReviewDeleteResult {
            review_id: id,
            deleted,
            remaining_count: reviews.len(),
            app_local_only: true,
            provider_request_sent: false,
            skill_files_mutated: false,
            agent_config_mutated: false,
            snapshot_created: false,
            triage_mutated: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
        })
    }

    pub fn import_local_trace(
        &self,
        params: TraceImportLocalParams,
    ) -> Result<TraceImportLocalResult, ServiceError> {
        let content = params.content.trim();
        if content.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "trace.importLocal requires non-empty trace content".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let redaction_roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&redaction_roots);
        let max_excerpt_chars = params.max_excerpt_chars.unwrap_or(800).clamp(80, 4_000);
        let excerpt = truncate_chars(&redactor.redact(content), max_excerpt_chars);
        let excerpt_char_count = excerpt.chars().count();
        let expected_skill_refs =
            redact_normalized_string_list(params.expected_skill_refs, &redaction_roots);
        let expected_skill_names =
            redact_normalized_string_list(params.expected_skill_names, &redaction_roots);
        let task = params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(|task| redactor.redact(task));
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .map(|title| redactor.redact(title))
            .or_else(|| task.clone())
            .unwrap_or_else(|| "Imported local trace".to_string());
        let source_kind = params
            .source_kind
            .as_deref()
            .map(str::trim)
            .filter(|source_kind| !source_kind.is_empty())
            .map(|source_kind| redactor.redact(source_kind))
            .unwrap_or_else(|| "local-transcript".to_string());
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(|agent| redactor.redact(agent));
        let redaction_summary = trace_import_redaction_summary_from(redactor.summary());
        let content_hash = trace_content_hash(content);
        let imported_at = unix_timestamp_millis();
        let analysis = self.analyze_imported_trace(
            content,
            &expected_skill_refs,
            &expected_skill_names,
            agent.as_deref(),
        )?;
        let record = TraceImportRecord {
            id: generated_trace_import_id(&title, &content_hash, imported_at),
            title,
            source_kind,
            agent,
            task,
            expected_skill_refs,
            expected_skill_names,
            excerpt,
            excerpt_char_count,
            redaction_summary,
            content_hash,
            imported_at,
            analysis,
            safety_flags: trace_import_safety_flags(),
        };

        let mut imports = self.load_trace_imports()?;
        imports.push(record.clone());
        self.save_trace_imports(&imports)?;
        Ok(TraceImportLocalResult {
            generated_by: "deterministic-service",
            import: record,
            count: imports.len(),
            app_local_only: true,
            import_file: "trace-imports.json",
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }

    pub fn list_trace_imports(
        &self,
        params: TraceListImportsParams,
    ) -> Result<TraceImportListResult, ServiceError> {
        let mut imports = self.load_trace_imports()?;
        if let Some(limit) = params.limit {
            imports.truncate(limit);
        }
        Ok(TraceImportListResult {
            count: imports.len(),
            imports,
            app_local_only: true,
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }

    pub fn delete_trace_import(
        &self,
        params: TraceDeleteImportParams,
    ) -> Result<TraceDeleteImportResult, ServiceError> {
        let id = sanitize_trace_import_id(params.id.trim());
        if id.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "trace.deleteImport requires an import id".to_string(),
            ));
        }
        let mut imports = self.load_trace_imports()?;
        let before = imports.len();
        imports.retain(|record| record.id != id);
        let deleted = imports.len() != before;
        if deleted {
            self.save_trace_imports(&imports)?;
        }
        Ok(TraceDeleteImportResult {
            import_id: id,
            deleted,
            remaining_count: imports.len(),
            app_local_only: true,
            provider_request_sent: false,
            raw_trace_persisted: false,
        })
    }
}
