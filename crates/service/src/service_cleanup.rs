use super::*;

impl ServiceHost {
    pub fn plan_guided_cleanup_flow(
        &self,
        params: GuidedCleanupPlanParams,
    ) -> Result<GuidedCleanupFlowResult, ServiceError> {
        if matches!(params.limit, Some(0)) {
            return Err(ServiceError::InvalidRequest(
                "cleanup.planGuidedFlow limit must be greater than zero".to_string(),
            ));
        }

        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let filters = guided_cleanup_filters(&params, &adapter_ctx, &roots);
        let recorded_steps = if filters.include_recorded_steps {
            self.load_guided_cleanup_steps()?
                .into_iter()
                .filter(|record| guided_cleanup_record_matches(&filters, record))
                .take(filters.limit)
                .collect::<Vec<_>>()
        } else {
            Vec::new()
        };

        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(empty_guided_cleanup_flow_result(
                filters,
                false,
                recorded_steps,
            ));
        };

        let skills = self.list_visible_skill_records(&catalog)?;
        let visible_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        let candidate_instance_ids =
            guided_cleanup_candidate_ids(&params, &filters, &visible_by_id);
        let agent = filters
            .selected_skill_agent
            .clone()
            .or_else(|| filters.agent.clone());
        let task = filters.task.clone();
        let evidence_limit = filters.limit.saturating_mul(2).max(filters.limit);

        let batch_review = self.batch_review_remediation(RemediationBatchReviewParams {
            task: task.clone(),
            agent: agent.clone(),
            project_root: params.project_root.clone(),
            workspace_label: filters.workspace.clone(),
            rule_id: None,
            severity: None,
            status: None,
            triage_status: None,
            candidate_instance_ids: candidate_instance_ids.clone(),
            group_by: Vec::new(),
            limit: Some(evidence_limit),
        })?;
        let lifecycle = self.build_skill_lifecycle_timeline(SkillLifecycleTimelineParams {
            task: task.clone(),
            agent: agent.clone(),
            selected_skill_id: filters.selected_skill_id.clone(),
            selected_skill_name: filters.selected_skill_name.clone(),
            selected_skill_agent: filters.selected_skill_agent.clone(),
            definition_id: None,
            project_root: params.project_root.clone(),
            current_cwd: params.current_cwd.clone(),
            workspace: params.workspace.clone(),
            limit: Some(evidence_limit.clamp(12, 100)),
            include_prompt_runs: true,
            include_session_reviews: true,
            include_remediation_history: true,
            include_stale_drift: true,
        })?;
        let cockpit = if let Some(task) = task.as_ref() {
            Some(self.build_task_cockpit(TaskCockpitParams {
                task: task.clone(),
                agent: agent.clone(),
                candidate_instance_ids: candidate_instance_ids.clone(),
                limit: Some(filters.limit.min(12)),
                include_session_review: Some(true),
                include_provider_observability: Some(true),
                include_remediation_context: Some(true),
                timeout_ms: None,
            })?)
        } else {
            None
        };

        let mut evidence_references = Vec::new();
        extend_evidence_references(
            &mut evidence_references,
            batch_review.evidence_references.clone(),
        );
        extend_evidence_references(
            &mut evidence_references,
            lifecycle.evidence_references.clone(),
        );
        if let Some(cockpit) = cockpit.as_ref() {
            extend_evidence_references(
                &mut evidence_references,
                cockpit.evidence_references.clone(),
            );
        }

        let mut flow_steps = Vec::new();
        for item in &batch_review.review_items {
            flow_steps.push(guided_cleanup_step_from_batch_item(item));
        }
        for next in &batch_review.recommended_next_step_labels {
            if flow_steps.len() >= evidence_limit {
                break;
            }
            flow_steps.push(guided_cleanup_step_from_next_label(next, &task));
        }
        for row in lifecycle.timeline_rows.iter().take(filters.limit.min(8)) {
            flow_steps.push(guided_cleanup_step_from_lifecycle(row));
        }
        if let Some(cockpit) = cockpit.as_ref() {
            for next in cockpit
                .remediation_next_steps
                .iter()
                .take(filters.limit.min(8))
            {
                flow_steps.push(guided_cleanup_step_from_cockpit(next));
            }
        }

        guided_cleanup_sort_steps(&mut flow_steps, filters.limit);
        let issue_groups = guided_cleanup_issue_groups(&flow_steps, filters.limit);
        let safe_next_actions = guided_cleanup_safe_next_actions(&flow_steps);

        let mut gap_notes = batch_review.gap_notes.clone();
        gap_notes.extend(lifecycle.gap_notes.clone());
        if let Some(cockpit) = cockpit.as_ref() {
            gap_notes.extend(cockpit.gap_notes.clone());
        }
        if flow_steps.is_empty() {
            gap_notes.push(
                "No deterministic local guided cleanup steps matched the selected filters."
                    .to_string(),
            );
        }
        normalize_note_list(&mut gap_notes);
        gap_notes.truncate(18);

        let mut blocker_notes = batch_review.blocker_notes.clone();
        blocker_notes.extend(lifecycle.blocker_notes.clone());
        if let Some(cockpit) = cockpit.as_ref() {
            blocker_notes.extend(cockpit.blocker_notes.clone());
        }
        blocker_notes.push(
            "Guided cleanup flow is read-only planning; it does not write skill files, mutate agent config, change triage, create snapshots, execute scripts, or send provider requests."
                .to_string(),
        );
        blocker_notes.push(
            "Enable/disable/edit/remediation actions remain outside this flow and must use existing preview-first, explicit-confirm safe methods."
                .to_string(),
        );
        normalize_note_list(&mut blocker_notes);
        blocker_notes.truncate(18);

        dedupe_evidence_references(&mut evidence_references);
        let prompt_instance_ids = flow_steps
            .iter()
            .filter_map(|step| step.instance_id.clone())
            .collect::<BTreeSet<_>>()
            .into_iter()
            .take(12)
            .collect::<Vec<_>>();
        let summary = guided_cleanup_summary(
            flow_steps.len(),
            &flow_steps,
            issue_groups.len(),
            safe_next_actions.len(),
            recorded_steps.len(),
        );

        Ok(GuidedCleanupFlowResult {
            generated_by: "local-v2.67",
            catalog_available: true,
            filters: filters.clone(),
            summary,
            flow_steps,
            issue_groups,
            safe_next_actions,
            recorded_steps,
            gap_notes,
            blocker_notes,
            evidence_references,
            prompt_request: GuidedCleanupPromptRequest {
                available: !prompt_instance_ids.is_empty(),
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                action: "guided_cleanup_flow",
                request: LlmPreviewPromptParams {
                    action: LlmPromptActionKind::GuidedCleanupFlow,
                    profile_id: None,
                    app_language: None,
                    skill_instance_id: filters.selected_skill_id.clone(),
                    instance_ids: prompt_instance_ids,
                    analysis_kind: None,
                    user_intent: filters.task.clone().or_else(|| {
                        Some(
                            "Explain deterministic guided cleanup flow steps using only local redacted evidence."
                                .to_string(),
                        )
                    }),
                },
                note: "Optional provider-backed guided cleanup wording must be requested through prompt preview and explicit confirmation; cleanup.planGuidedFlow never sends provider traffic and remains copy-only."
                    .to_string(),
            },
            safety_flags: guided_cleanup_safety_flags(),
        })
    }

    pub fn record_guided_cleanup_step(
        &self,
        params: GuidedCleanupRecordStepParams,
    ) -> Result<GuidedCleanupRecordStepResult, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&roots);
        let flow_step_id = params
            .flow_step_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 180))
            .ok_or_else(|| {
                ServiceError::InvalidRequest(
                    "cleanup.recordGuidedStep requires a non-empty flow_step_id".to_string(),
                )
            })?;
        let decision = params
            .decision
            .as_deref()
            .or(params.status.as_deref())
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(normalize_history_token)
            .unwrap_or_else(|| "recorded".to_string());
        if decision.is_empty() {
            return Err(ServiceError::InvalidRequest(
                "cleanup.recordGuidedStep requires a valid decision or status".to_string(),
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
                "cleanup.recordGuidedStep requires a valid status".to_string(),
            ));
        }

        let now = unix_timestamp_millis();
        let title = params
            .title
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 180))
            .unwrap_or_else(|| format!("Guided cleanup step: {flow_step_id}"));
        let note = params
            .note
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 500));
        let task = params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 320));
        let agent = params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 80));
        let instance_id = params
            .instance_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 160));
        let definition_id = params
            .definition_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 160));
        let skill_name = params
            .skill_name
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 180));
        let source_refs = redact_history_string_list(params.source_refs, &mut redactor, 180, 80);
        let evidence_refs =
            redact_history_string_list(params.evidence_refs, &mut redactor, 180, 80);
        let redaction_summary = remediation_history_redaction_summary_from(redactor.summary());
        let id = params
            .id
            .as_deref()
            .map(sanitize_guided_cleanup_record_id)
            .filter(|id| !id.is_empty())
            .unwrap_or_else(|| generated_guided_cleanup_record_id(&flow_step_id, &decision, now));

        let mut records = self.load_guided_cleanup_steps()?;
        let created = !records.iter().any(|record| record.id == id);
        let record = GuidedCleanupStepRecord {
            id: id.clone(),
            flow_step_id,
            title,
            decision,
            status,
            note,
            task,
            agent,
            instance_id,
            definition_id,
            skill_name,
            source_refs,
            evidence_refs,
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
            safety_flags: guided_cleanup_safety_flags(),
        };
        records.retain(|existing| existing.id != id);
        records.push(record.clone());
        self.save_guided_cleanup_steps(&records)?;

        Ok(GuidedCleanupRecordStepResult {
            generated_by: "local-v2.67",
            record,
            created,
            count: records.len(),
            app_local_only: true,
            record_file: "guided-cleanup-steps.json",
            provider_request_sent: false,
            skill_files_mutated: false,
            agent_config_mutated: false,
            snapshot_created: false,
            rollback_performed: false,
            triage_mutated: false,
            script_executed: false,
            credential_accessed: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
            safety_flags: guided_cleanup_safety_flags(),
        })
    }

    pub fn export_local_report(
        &self,
        params: ReportExportLocalParams,
    ) -> Result<ReportExportLocalResult, ServiceError> {
        let generated_at = unix_timestamp_millis();
        let export_id = format!("local-report-{generated_at}");
        let output_dir = self.app_data_dir.join("report-exports").join(&export_id);
        create_private_dir_all(&output_dir)?;

        let formats = report_export_formats(params.formats.clone());
        let adapter_ctx = self.effective_adapter_ctx()?;
        let catalog = self.open_existing_catalog_read_only()?;
        let catalog_available = catalog.is_some();

        let (skills, findings, triage, conflicts, health, analysis, cleanup, comparison) =
            if let Some(catalog) = catalog.as_ref() {
                let skills =
                    report_filter_skills(self.list_visible_skill_records(catalog)?, &params);
                let findings = report_filter_findings(list_findings(catalog)?, &skills);
                let triage = list_finding_triage(catalog)?;
                let conflicts = report_filter_conflicts(list_conflicts(catalog)?, &skills);
                let health = serde_json::to_value(skill_health_summary(catalog, &adapter_ctx)?)?;
                let analysis = serde_json::to_value(analyze_catalog(catalog, &adapter_ctx)?)?;
                let cleanup = self.cleanup_list_queue(CleanupListQueueParams::default())?;
                let comparison = list_cross_agent_comparisons(
                    catalog,
                    &adapter_ctx,
                    params.instance_id.as_deref(),
                    params.agent.as_deref(),
                    params.search.as_deref(),
                    Some(50),
                )?;
                (
                    skills,
                    findings,
                    triage,
                    conflicts,
                    health,
                    analysis,
                    serde_json::to_value(cleanup)?,
                    serde_json::to_value(comparison)?,
                )
            } else {
                (
                    Vec::new(),
                    Vec::new(),
                    Vec::new(),
                    Vec::new(),
                    empty_health_summary_json(),
                    serde_json::to_value(empty_cross_agent_analysis_json())?,
                    serde_json::to_value(cleanup_queue_response(Vec::new(), None))?,
                    serde_json::to_value(empty_cross_agent_comparison(None))?,
                )
            };

        let legacy_skills = serde_json::to_value(&skills)?;
        let legacy_findings = serde_json::to_value(&findings)?;
        let legacy_triage = serde_json::to_value(&triage)?;
        let legacy_comparison = comparison.clone();
        let result_summary = report_export_summary(
            &legacy_skills,
            &legacy_findings,
            &legacy_triage,
            &cleanup,
            &legacy_comparison,
        );
        let agent = report_agent_scope(&params, &skills, catalog_available);
        let skill_usage = report_skill_usage(&skills, &findings, &conflicts);
        let issues = report_issue_rows(&findings, &conflicts, &skills);
        let recommended_usage = report_recommended_usage(&skills, &issues);
        let task_preflight = report_task_preflight();
        let analysis_results = report_analysis_results(&health, &analysis, &cleanup, &comparison);
        let usage_summary = report_usage_summary(&skills, &issues, &conflicts, &analysis_results);
        let sections = report_usage_sections(&usage_summary);
        let mut report = json!({
            "schema_version": 2,
            "export_id": export_id,
            "generated_at": generated_at,
            "catalog_available": catalog_available,
            "safety": {
                "read_only": true,
                "writes_allowed": false,
                "provider_request_sent": false,
                "script_execution_allowed": false,
                "credential_accessed": false,
                "scope": "local-redacted-report-export"
            },
            "redaction": report_export_redaction(),
            "summary": usage_summary,
            "agent": agent,
            "skills": skill_usage,
            "recommended_usage": recommended_usage,
            "issues": issues,
            "task_preflight": task_preflight,
            "analysis_results": analysis_results,
            "source_evidence": {
                "status": self.status(),
                "health": health,
                "triage": legacy_triage,
                "legacy_cleanup_queue": cleanup,
                "analysis": analysis,
                "comparison": comparison
            }
        });
        redact_report_value(&mut report, &self.redaction_roots(&adapter_ctx));

        let mut files = Vec::new();
        for format in formats {
            let path = output_dir.join(format!("report.{}", format.extension()));
            match format {
                ReportExportFormat::Json => {
                    let content = serde_json::to_string_pretty(&report)?;
                    write_private_text_file(&path, &content)?;
                }
                ReportExportFormat::Markdown => {
                    write_private_text_file(&path, &render_report_markdown(&report))?;
                }
            }
            files.push(ReportExportedFile {
                format: format.label(),
                path: redact_path_string(&path, &self.redaction_roots(&adapter_ctx)),
            });
        }

        Ok(ReportExportLocalResult {
            export_id,
            generated_at,
            output_dir: redact_path_string(&output_dir, &self.redaction_roots(&adapter_ctx)),
            files,
            catalog_available,
            summary: result_summary,
            sections,
            redaction: report_export_redaction(),
            read_only: true,
            writes_allowed: false,
            provider_request_sent: false,
            script_execution_allowed: false,
            credential_accessed: false,
        })
    }
}
