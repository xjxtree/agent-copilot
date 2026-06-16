use super::*;

impl ServiceHost {
    pub fn llm_status(&self) -> LlmStatus {
        let profiles = self.list_llm_provider_profiles().ok();
        let default_profile = profiles.as_ref().and_then(|profiles| {
            profiles
                .default_profile_id
                .as_ref()
                .and_then(|default_id| {
                    profiles
                        .profiles
                        .iter()
                        .find(|profile| profile.id == *default_id)
                })
                .or_else(|| profiles.profiles.iter().find(|profile| profile.enabled))
        });
        let configured = default_profile
            .is_some_and(|profile| profile.enabled && profile.credential_status.secret_available);
        let profile_count = profiles
            .as_ref()
            .map(|profiles| profiles.profiles.len())
            .unwrap_or(0);
        let reason = match default_profile {
            Some(profile) if configured => {
                format!(
                    "Provider profile `{}` is configured; provider calls remain user-triggered and confirmation-gated.",
                    profile.id
                )
            }
            Some(profile) if !profile.enabled => {
                format!("Provider profile `{}` exists but is disabled.", profile.id)
            }
            Some(profile) => format!(
                "Provider profile `{}` exists but its API key is unavailable from the OS credential store.",
                profile.id
            ),
            None if profile_count > 0 => {
                "Provider profiles exist, but none is enabled as the default provider.".to_string()
            }
            None => "LLM actions are disabled by default; no local provider is configured."
                .to_string(),
        };
        LlmStatus {
            enabled: configured,
            configured,
            provider: default_profile.map(|profile| profile.provider_type.as_str().to_string()),
            model: default_profile.map(|profile| profile.model.clone()),
            reason,
            single_request_token_limit: default_profile
                .map(|profile| profile.single_request_token_limit)
                .unwrap_or_else(default_token_limit),
            monthly_budget_usd: default_profile
                .map(|profile| profile.monthly_budget_usd)
                .unwrap_or_else(default_monthly_budget_usd),
            credentials_storage: if profile_count == 0 {
                "none".to_string()
            } else {
                "keychain".to_string()
            },
            credential_persistence_allowed: profile_count > 0,
            provider_profile_count: profile_count,
            default_profile_id: default_profile.map(|profile| profile.id.clone()),
            profiles_path: display_path(&provider_profiles_path(&self.app_data_dir)),
            call_metadata_path: display_path(&provider_call_metadata_path(&self.app_data_dir)),
            raw_prompt_persistence_allowed: false,
            raw_response_persistence_allowed: false,
        }
    }

    pub fn trace_import_status(&self) -> TraceImportStatus {
        TraceImportStatus {
            count: self
                .load_trace_imports()
                .map(|imports| imports.len())
                .unwrap_or_default(),
            imports_path: display_path(&self.trace_imports_path()),
            app_local_only: true,
            raw_trace_persistence_allowed: false,
            provider_request_allowed: false,
        }
    }

    pub fn agent_session_review_status(&self) -> AgentSessionSkillReviewStatus {
        AgentSessionSkillReviewStatus {
            count: self
                .load_agent_session_reviews()
                .map(|reviews| reviews.len())
                .unwrap_or_default(),
            reviews_path: display_path(&self.agent_session_reviews_path()),
            app_local_only: true,
            raw_trace_persistence_allowed: false,
            provider_request_allowed: false,
        }
    }

    pub(crate) fn list_llm_provider_profiles(
        &self,
    ) -> Result<ListProviderProfilesResult, ServiceError> {
        list_provider_profiles(&self.app_data_dir).map_err(Into::into)
    }

    pub fn preview_llm_prompt(
        &self,
        params: LlmPreviewPromptParams,
    ) -> Result<LlmPreviewPromptResult, ServiceError> {
        let profile = self.resolve_llm_prompt_profile(params.profile_id.as_deref())?;
        let built = self.build_llm_prompt(&params)?;
        let provider = profile
            .as_ref()
            .map(|profile| profile.provider_type.as_str().to_string());
        let model = profile.as_ref().map(|profile| profile.model.clone());
        let profile_id = profile.as_ref().map(|profile| profile.id.clone());
        let destination_host = profile
            .as_ref()
            .map(|profile| destination_host_for_url(&profile.base_url));
        let single_request_token_limit = profile
            .as_ref()
            .map(|profile| profile.single_request_token_limit)
            .unwrap_or_else(default_token_limit);
        let monthly_budget_usd = profile
            .as_ref()
            .map(|profile| profile.monthly_budget_usd)
            .unwrap_or_else(default_monthly_budget_usd);
        let estimated_input_tokens = estimate_tokens(&[&built.prompt_preview]);
        let estimated_output_tokens = built.estimated_output_tokens;
        let estimated_total_tokens = estimated_input_tokens.saturating_add(estimated_output_tokens);
        let estimated_cost_usd = profile
            .as_ref()
            .map(|profile| estimate_prompt_cost_usd(profile.provider_type, estimated_total_tokens))
            .unwrap_or(0.0);
        let (allowed, reason) = match profile.as_ref() {
            None => (
                false,
                "No enabled provider profile is configured; no provider request can be sent."
                    .to_string(),
            ),
            Some(profile) if !profile.enabled => (
                false,
                format!("Provider profile `{}` is disabled.", profile.id),
            ),
            Some(profile) if profile.monthly_budget_usd <= 0.0 => (
                false,
                "Monthly provider budget is 0; provider requests are disabled.".to_string(),
            ),
            Some(profile) if profile.single_request_token_limit < estimated_total_tokens => (
                false,
                "Single request token limit is lower than the redacted prompt estimate."
                    .to_string(),
            ),
            Some(_) => (
                true,
                "Redacted prompt preview is ready for explicit confirmation.".to_string(),
            ),
        };
        let preview_id = llm_preview_id(
            &params,
            profile.as_ref(),
            &built.prompt_preview,
            estimated_input_tokens,
            estimated_output_tokens,
        );

        Ok(LlmPreviewPromptResult {
            preview_id,
            status: if allowed { "ready" } else { "blocked" }.to_string(),
            allowed,
            reason,
            action: params.action.as_str(),
            profile_id,
            provider,
            model,
            destination_host,
            prompt_scope: built.prompt_scope,
            included_fields: built.included_fields,
            excluded_fields: built.excluded_fields,
            redaction: built.redaction,
            prompt_preview: built.prompt_preview,
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            estimated_cost_usd,
            single_request_token_limit,
            monthly_budget_usd,
            requires_confirmation: true,
            confirmation: LlmConfirmationRequirement {
                required: true,
                message:
                    "Confirm to send only this redacted prompt to the displayed provider endpoint."
                        .to_string(),
                display_fields: vec![
                    "preview_id",
                    "provider",
                    "model",
                    "destination_host",
                    "prompt_scope",
                    "included_fields",
                    "excluded_fields",
                    "redaction",
                    "estimated_total_tokens",
                    "estimated_cost_usd",
                ],
            },
            write_back_allowed: false,
            draft_requires_user_copy: true,
            provider_request_sent: false,
            raw_secret_returned: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
        })
    }

    pub fn confirm_llm_prompt_and_send(
        &self,
        params: LlmConfirmPromptAndSendParams,
    ) -> Result<LlmConfirmPromptAndSendResult, ServiceError> {
        if params.confirmation_id.trim().is_empty() {
            return Err(ServiceError::ConfirmationRequired(
                "llm.confirmPromptAndSend requires an explicit confirmation_id".to_string(),
            ));
        }
        let preview = self.preview_llm_prompt(params.request.clone())?;
        if preview.preview_id != params.preview_id {
            return Err(ServiceError::InvalidRequest(
                "preview_id does not match the current redacted prompt preview".to_string(),
            ));
        }
        let profile_id = preview.profile_id.clone().ok_or_else(|| {
            ServiceError::InvalidRequest(
                "No provider profile is available for the confirmed prompt.".to_string(),
            )
        })?;
        let send = send_provider_prompt(
            &self.app_data_dir,
            SendProviderPromptParams {
                profile_id: profile_id.clone(),
                confirmation_id: params.confirmation_id.clone(),
                action_type: llm_prompt_action_type(&params.request),
                prompt: preview.prompt_preview.clone(),
                estimated_input_tokens: preview.estimated_input_tokens,
                estimated_output_tokens: preview.estimated_output_tokens,
                estimated_cost_usd: preview.estimated_cost_usd,
                redaction_status: preview.redaction.status.clone(),
                timeout_ms: params.timeout_ms,
            },
        )?;
        self.record_llm_prompt_run(&params, &preview, &send)?;

        Ok(LlmConfirmPromptAndSendResult {
            preview_id: params.preview_id,
            confirmation_id: params.confirmation_id,
            status: send.status,
            action: params.request.action.as_str(),
            profile_id,
            provider: send.provider_type.as_str().to_string(),
            model: send.model,
            destination_host: send.destination_host,
            provider_request_sent: send.provider_request_sent,
            credential_accessed: send.credential_accessed,
            draft_output: send.output_text,
            draft_requires_user_copy: true,
            write_back_allowed: false,
            script_execution_allowed: false,
            config_mutation_allowed: false,
            snapshot_created: false,
            triage_mutation_allowed: false,
            audit: send.audit,
            raw_secret_returned: send.raw_secret_returned,
            raw_prompt_persisted: send.raw_prompt_persisted,
            raw_response_persisted: send.raw_response_persisted,
        })
    }

    pub fn list_llm_prompt_runs(
        &self,
        params: LlmPromptRunListParams,
    ) -> Result<LlmPromptRunListResult, ServiceError> {
        let limit = params.limit.unwrap_or(50).clamp(1, 500);
        let action = params
            .action
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase());
        let request_kind = params
            .request_kind
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase());
        let instance_id = params
            .skill_instance_id
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned);
        let mut runs = self
            .load_llm_prompt_runs()?
            .into_iter()
            .filter(|run| {
                let action_matches = action
                    .as_deref()
                    .is_none_or(|filter| run.action.eq_ignore_ascii_case(filter));
                let request_matches = request_kind
                    .as_deref()
                    .is_none_or(|filter| run.request_kind.eq_ignore_ascii_case(filter));
                let instance_matches = instance_id.as_deref().is_none_or(|filter| {
                    run.instance_id.as_deref() == Some(filter)
                        || run.instance_ids.iter().any(|id| id == filter)
                });
                action_matches && request_matches && instance_matches
            })
            .collect::<Vec<_>>();
        runs.truncate(limit);
        Ok(LlmPromptRunListResult {
            generated_by: "local-v2.61",
            count: runs.len(),
            runs,
            app_local_only: true,
            runs_file: "prompt-runs.json",
            provider_request_sent: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_secret_returned: false,
            safety_flags: llm_prompt_run_safety_flags(false, false),
        })
    }

    pub fn llm_provider_observability(
        &self,
        params: LlmProviderObservabilityParams,
    ) -> Result<LlmProviderObservabilityResult, ServiceError> {
        let limit = params.limit.unwrap_or(50).clamp(1, 500);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let redaction_roots = self.trace_redaction_roots(&adapter_ctx);
        let filters = ProviderObservabilityFilters::from_params(&params);

        let (prompt_runs, mut status_rows) =
            self.load_llm_prompt_runs_for_observability(&redaction_roots);
        let (call_metadata, call_status_rows) =
            self.load_provider_call_metadata_for_observability(&redaction_roots);
        status_rows.extend(call_status_rows);
        let (profiles, profile_status_rows) =
            self.load_provider_profiles_for_observability(&redaction_roots);
        status_rows.extend(profile_status_rows);

        let matched_prompt_runs = prompt_runs
            .iter()
            .filter(|run| filters.matches_prompt_run(run))
            .collect::<Vec<_>>();
        let matched_call_metadata = call_metadata
            .iter()
            .filter(|metadata| filters.matches_provider_call(metadata))
            .collect::<Vec<_>>();

        let mut history_rows = matched_prompt_runs
            .iter()
            .enumerate()
            .map(|(index, run)| provider_observability_history_row(run, index, &redaction_roots))
            .collect::<Vec<_>>();
        history_rows.truncate(limit);

        let mut call_rows = matched_call_metadata
            .iter()
            .enumerate()
            .map(|(index, metadata)| {
                provider_observability_call_row(metadata, index, &redaction_roots)
            })
            .collect::<Vec<_>>();
        call_rows.truncate(limit);

        let grouping_rows = provider_observability_grouping_rows(&history_rows, &call_rows, limit);
        let budget_usage_hints = provider_observability_budget_usage_hints(
            &profiles,
            &matched_prompt_runs,
            &matched_call_metadata,
            &filters,
            &redaction_roots,
            limit,
        );
        let mut status_rows = provider_observability_status_rows(
            status_rows,
            &matched_prompt_runs,
            &matched_call_metadata,
            limit,
        );
        let blocker_notes = provider_observability_blocker_notes(&status_rows);
        let gap_notes = provider_observability_gap_notes(
            profiles.len(),
            matched_prompt_runs.len(),
            matched_call_metadata.len(),
        );
        let retention_recommendations = provider_observability_retention_recommendations(
            prompt_runs.len(),
            call_metadata.len(),
        );
        let evidence_references = provider_observability_evidence_references(
            &history_rows,
            &call_rows,
            &grouping_rows,
            &budget_usage_hints,
        );
        status_rows.truncate(limit.saturating_mul(2));

        let summary = provider_observability_summary(
            prompt_runs.len(),
            call_metadata.len(),
            &history_rows,
            &call_rows,
            profiles.len(),
            profiles.iter().filter(|profile| profile.enabled).count(),
            grouping_rows.len(),
        );
        let status = if blocker_notes.is_empty() {
            "ready".to_string()
        } else {
            "partial".to_string()
        };

        Ok(LlmProviderObservabilityResult {
            generated_by: "local-v2.64",
            status,
            summary,
            call_rows,
            history_rows,
            grouping_rows,
            status_rows,
            budget_usage_hints,
            retention_recommendations,
            gap_notes,
            blocker_notes,
            evidence_references,
            prompt_metadata: LlmProviderObservabilityPromptMetadata {
                available: false,
                preview_method: "llm.previewPrompt",
                confirm_method: "llm.confirmPromptAndSend",
                provider_request_sent: false,
                copy_only: true,
                note: "Provider observability is a deterministic local read model; this method never sends provider traffic or reads credentials.".to_string(),
            },
            safety_flags: llm_provider_observability_safety_flags(),
        })
    }

    pub fn script_execution_status(&self) -> ScriptExecutionStatus {
        ScriptExecutionStatus {
            enabled: false,
            default_enabled: false,
            reason: SCRIPT_EXECUTION_DISABLED_REASON.to_string(),
            audit_scope: "app-data/session-local".to_string(),
            audit_path: display_path(&self.script_execution_audit_path()),
            llm_initiation_allowed: false,
        }
    }

    pub(crate) fn resolve_llm_prompt_profile(
        &self,
        requested_profile_id: Option<&str>,
    ) -> Result<Option<ProviderProfileRecord>, ServiceError> {
        let profiles = list_provider_profiles(&self.app_data_dir)?;
        if let Some(profile_id) = requested_profile_id.filter(|id| !id.trim().is_empty()) {
            return profiles
                .profiles
                .into_iter()
                .find(|profile| profile.id == profile_id)
                .map(Some)
                .ok_or_else(|| ProviderError::ProfileNotFound(profile_id.to_string()).into());
        }
        Ok(profiles
            .default_profile_id
            .as_deref()
            .and_then(|default_id| {
                profiles
                    .profiles
                    .iter()
                    .find(|profile| profile.id == default_id)
            })
            .or_else(|| profiles.profiles.iter().find(|profile| profile.enabled))
            .cloned())
    }

    pub(crate) fn build_llm_prompt(
        &self,
        params: &LlmPreviewPromptParams,
    ) -> Result<BuiltLlmPrompt, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&roots);
        let mut prompt_scope = vec![
            "operation metadata".to_string(),
            "app output language preference".to_string(),
            "safety boundaries".to_string(),
        ];
        let mut included_fields = vec![
            "action kind".to_string(),
            "app language code".to_string(),
            "draft-only safety instructions".to_string(),
        ];
        let mut excluded_fields = vec![
            "source paths".to_string(),
            "credential values".to_string(),
            "provider API key".to_string(),
            "agent config mutation instructions".to_string(),
            "script execution instructions".to_string(),
        ];
        let mut sections = vec![
            "You are assisting with AI agent skill governance.".to_string(),
            format!("Action: {}", params.action.as_str()),
            llm_output_language_instruction(params.app_language.as_deref()),
            "Return draft-only analysis. Do not write files, mutate agent config, execute scripts, change triage, create snapshots, call tools, or request secrets.".to_string(),
        ];
        if let Some(intent) = params
            .user_intent
            .as_deref()
            .filter(|intent| !intent.trim().is_empty())
        {
            prompt_scope.push("user intent".to_string());
            included_fields.push("redacted user intent".to_string());
            sections.push(format!("User intent: {}", redactor.redact(intent)));
        }

        match params.action {
            LlmPromptActionKind::Analyze | LlmPromptActionKind::DraftFrontmatter => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(format!(
                        "llm.previewPrompt {} requires skill_instance_id",
                        params.action.as_str()
                    ))
                })?;
                let skill = self.get_llm_skill_detail(instance_id)?;
                prompt_scope.extend([
                    "selected skill metadata".to_string(),
                    "selected skill redacted frontmatter".to_string(),
                    "selected skill redacted body".to_string(),
                    "related finding summaries".to_string(),
                ]);
                included_fields.extend([
                    "skill id".to_string(),
                    "skill name".to_string(),
                    "agent".to_string(),
                    "scope".to_string(),
                    "enabled state".to_string(),
                    "redacted description".to_string(),
                    "redacted frontmatter".to_string(),
                    "redacted skill body".to_string(),
                    "rule finding ids and messages".to_string(),
                ]);
                sections.push(self.render_skill_prompt_section(&skill, &mut redactor)?);
            }
            LlmPromptActionKind::Recommend => {
                prompt_scope.extend([
                    "user intent".to_string(),
                    "catalog recommendation constraints".to_string(),
                ]);
                included_fields.push("recommendation constraints".to_string());
                excluded_fields.push("raw skill bodies".to_string());
                sections.push(
                    "Recommendation constraints: use current catalog evidence only when available; ask for clarification instead of inventing unavailable skills."
                        .to_string(),
                );
            }
            LlmPromptActionKind::ExplainConflict => {
                prompt_scope.extend([
                    "current conflict summaries".to_string(),
                    "current rule finding summaries".to_string(),
                ]);
                included_fields.extend([
                    "conflict ids".to_string(),
                    "definition ids".to_string(),
                    "rule ids".to_string(),
                    "finding severities".to_string(),
                ]);
                excluded_fields.push("raw skill bodies".to_string());
                let summary = self.llm_conflict_summary()?;
                sections.push(format!(
                    "Conflict and finding summary:\n{}",
                    redactor.redact(&summary)
                ));
            }
            LlmPromptActionKind::SkillAnalysis => {
                let analysis_kind = params
                    .analysis_kind
                    .unwrap_or(LlmSkillAnalysisKind::Overview);
                prompt_scope.extend([
                    "selected skill metadata".to_string(),
                    "selected skill redacted frontmatter".to_string(),
                    "selected skill redacted body".to_string(),
                    "related finding summaries".to_string(),
                    "missing selection count".to_string(),
                ]);
                included_fields.extend([
                    "analysis kind".to_string(),
                    "selected skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "redacted descriptions".to_string(),
                    "redacted frontmatter".to_string(),
                    "redacted skill bodies".to_string(),
                    "rule finding ids and messages".to_string(),
                ]);
                sections.push(format!("Analysis kind: {}", analysis_kind.as_str()));
                sections.push(self.render_skill_analysis_prompt_sections(params, &mut redactor)?);
            }
            LlmPromptActionKind::QualityScore => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt quality_score requires skill_instance_id".to_string(),
                    )
                })?;
                let score = self.score_skill_quality(ScoreSkillQualityParams {
                    instance_id: instance_id.to_string(),
                    agent: None,
                    definition_id: None,
                })?;
                prompt_scope.extend([
                    "deterministic quality score".to_string(),
                    "score components".to_string(),
                    "evidence reference summaries".to_string(),
                    "suggested improvements".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "skill id".to_string(),
                    "skill name".to_string(),
                    "agent".to_string(),
                    "scope".to_string(),
                    "quality score".to_string(),
                    "quality grade and band".to_string(),
                    "component scores and summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "suggested improvement titles and details".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                ]);
                sections.push(render_quality_score_prompt_section(&score, &mut redactor));
            }
            LlmPromptActionKind::StaleDriftDetection => {
                let detection = self.detect_stale_drift(DetectStaleDriftParams {
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                    stale_days: None,
                    thresholds: StaleDriftThresholds::default(),
                })?;
                prompt_scope.extend([
                    "deterministic stale and drift signals".to_string(),
                    "skill identity summaries".to_string(),
                    "readiness impact notes".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "stale/drift scores and bands".to_string(),
                    "fingerprint, finding, source, and mtime-derived signals".to_string(),
                    "readiness impact summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_stale_drift_prompt_section(&detection, &mut redactor));
            }
            LlmPromptActionKind::KnowledgeSearch => {
                let result = self.search_knowledge(KnowledgeSearchParams {
                    query: params.user_intent.clone(),
                    agent: None,
                    limit: Some(8),
                    risk: None,
                    scope: None,
                    enabled: None,
                    tool: None,
                    keyword: None,
                })?;
                prompt_scope.extend([
                    "deterministic local knowledge rows".to_string(),
                    "search filters and facets".to_string(),
                    "quality/readiness/stale-drift context".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted search query".to_string(),
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "matched fields and match reasons".to_string(),
                    "keywords, tools, rules, capability tags, and risk tags".to_string(),
                    "quality/readiness/stale-drift summaries".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response artifacts".to_string(),
                ]);
                sections.push(render_knowledge_search_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::SimilarSkillGrouping => {
                let result = self.group_similar_skills(SimilarSkillGroupingParams {
                    agent: None,
                    limit: Some(8),
                    min_score: None,
                    include_singletons: false,
                    candidate_instance_ids: params.instance_ids.clone(),
                })?;
                prompt_scope.extend([
                    "deterministic similar skill groups".to_string(),
                    "group similarity and ambiguity signals".to_string(),
                    "member quality and stale-drift context".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "group ids and group types".to_string(),
                    "canonical names and keys".to_string(),
                    "similarity, ambiguity, redundancy, and routing ambiguity bands".to_string(),
                    "shared terms, tools, rules, capability, risk, and source signals".to_string(),
                    "member skill names, agents, scopes, enabled states, and local contexts"
                        .to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_similar_skill_grouping_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::CapabilityTaxonomy => {
                let result = self.build_capability_taxonomy(CapabilityTaxonomyParams {
                    agent: None,
                    limit: Some(8),
                    include_single_skill_domains: true,
                    candidate_instance_ids: params.instance_ids.clone(),
                })?;
                prompt_scope.extend([
                    "deterministic capability taxonomy domains".to_string(),
                    "agent and workspace coverage summaries".to_string(),
                    "duplicate/redundancy and routing ambiguity signals".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "domain ids, keys, names, and coverage levels".to_string(),
                    "agent and workspace coverage counts".to_string(),
                    "representative skill names, agents, scopes, enabled states, and local contexts"
                        .to_string(),
                    "tools, rules, keywords, capability tags, and risk tags".to_string(),
                    "similar-group duplicate/redundancy and routing ambiguity metadata".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_capability_taxonomy_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::LocalSkillMap => {
                let result = self.build_local_skill_map(LocalSkillMapParams {
                    agent: None,
                    task: params.user_intent.clone(),
                    limit: Some(12),
                    node_limit: Some(48),
                    edge_limit: Some(96),
                    cluster_limit: Some(12),
                    candidate_instance_ids: params.instance_ids.clone(),
                    include_task_context: params.user_intent.is_some(),
                })?;
                prompt_scope.extend([
                    "deterministic local skill map graph".to_string(),
                    "skill, capability, similar-group, conflict, agent, source, risk, and task coverage nodes".to_string(),
                    "relationship edges and clusters".to_string(),
                    "local risk, gap, and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "candidate skill ids".to_string(),
                    "node ids, types, labels, weights, and summaries".to_string(),
                    "edge ids, types, labels, weights, and reasons".to_string(),
                    "cluster ids, types, scores, risk levels, and member node ids".to_string(),
                    "capability domain coverage summaries".to_string(),
                    "risk, gap, blocker, and evidence reference summaries".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_local_skill_map_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::WorkspaceReadiness => {
                let result = self.check_workspace_readiness(WorkspaceReadinessParams {
                    agent: None,
                    task: params.user_intent.clone(),
                    project_root: None,
                    expected_capabilities: Vec::new(),
                    limit: Some(8),
                    candidate_instance_ids: params.instance_ids.clone(),
                })?;
                prompt_scope.extend([
                    "deterministic workspace readiness checklist".to_string(),
                    "agent readiness summaries".to_string(),
                    "capability readiness rows".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or workspace intent".to_string(),
                    "readiness checklist categories, statuses, and scores".to_string(),
                    "agent names, enabled counts, adapter status, and best local candidates"
                        .to_string(),
                    "capability names, coverage levels, and gap/blocker notes".to_string(),
                    "finding/conflict/analysis/stale/routing evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                ]);
                sections.push(render_workspace_readiness_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RemediationPlan => {
                let result = self.plan_remediation(RemediationPlanParams {
                    agent: None,
                    task: params.user_intent.clone(),
                    project_root: None,
                    focus: None,
                    focus_areas: Vec::new(),
                    limit: Some(8),
                    candidate_instance_ids: params.instance_ids.clone(),
                    include_deferred: false,
                })?;
                prompt_scope.extend([
                    "deterministic remediation plan items".to_string(),
                    "prioritized local finding/gap/ambiguity/drift/readiness evidence".to_string(),
                    "safe next-action guidance".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or remediation intent".to_string(),
                    "plan item ids, ranks, priorities, severities, and categories".to_string(),
                    "affected skill ids, names, agents, scopes, enabled states, and states"
                        .to_string(),
                    "affected capabilities and task refs".to_string(),
                    "read-only suggested safe next actions".to_string(),
                    "prerequisites, blockers, and evidence ids".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                    "write/apply instructions".to_string(),
                ]);
                sections.push(render_remediation_plan_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RemediationPreviewDrafts => {
                let result = self.preview_remediation_drafts(RemediationPreviewDraftsParams {
                    agent: None,
                    task: params.user_intent.clone(),
                    skill_ids: params.instance_ids.clone(),
                    finding_ids: Vec::new(),
                    draft_types: Vec::new(),
                    limit: Some(8),
                    include_policy_drafts: true,
                })?;
                prompt_scope.extend([
                    "deterministic fix preview drafts".to_string(),
                    "copy-only proposed text and patch-like snippets".to_string(),
                    "finding/rule and remediation evidence".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or draft intent".to_string(),
                    "draft item ids, ranks, types, titles, and confidence bands".to_string(),
                    "affected skill ids, names, agents, scopes, enabled states, and states"
                        .to_string(),
                    "finding ids and rule ids".to_string(),
                    "copy-only current/proposed snippets".to_string(),
                    "rationale, copy labels, edit guidance, blockers, and evidence ids".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "write/apply instructions".to_string(),
                ]);
                sections.push(render_remediation_preview_drafts_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RemediationPreviewImpact => {
                let result = self.preview_remediation_impact(RemediationPreviewImpactParams {
                    action: Some("review".to_string()),
                    task: params.user_intent.clone(),
                    agent: None,
                    project_root: None,
                    skill_ids: params.instance_ids.clone(),
                    candidate_instance_ids: Vec::new(),
                    draft_ids: Vec::new(),
                    plan_item_ids: Vec::new(),
                    limit: Some(8),
                    include_snapshot_plan: true,
                    include_rollback_plan: true,
                    include_risk_impact: true,
                    include_task_impact: true,
                })?;
                prompt_scope.extend([
                    "deterministic impact preview rows".to_string(),
                    "task, agent, skill, risk, snapshot, and rollback impact summaries".to_string(),
                    "plan-only snapshot and rollback rows".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or impact intent".to_string(),
                    "impact row ids, areas, confidence, direction, and blockers".to_string(),
                    "affected skill ids, names, agents, scopes, enabled states, and estimates"
                        .to_string(),
                    "task readiness and routing score estimates".to_string(),
                    "plan-only snapshot and rollback statuses".to_string(),
                    "risk delta rows and local evidence ids".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "write/apply instructions".to_string(),
                    "snapshot creation or rollback commands".to_string(),
                ]);
                sections.push(render_remediation_preview_impact_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RemediationBatchReview => {
                let result = self.batch_review_remediation(RemediationBatchReviewParams {
                    task: params.user_intent.clone(),
                    agent: None,
                    project_root: None,
                    workspace_label: None,
                    rule_id: None,
                    severity: None,
                    status: None,
                    triage_status: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    group_by: Vec::new(),
                    limit: Some(12),
                })?;
                prompt_scope.extend([
                    "deterministic batch review queue items".to_string(),
                    "grouped local task, risk, rule, agent, and workspace evidence".to_string(),
                    "recommended safe next-step labels".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or batch review intent".to_string(),
                    "review group ids, labels, risk counts, and top item ids".to_string(),
                    "review item ids, sources, severities, statuses, and rule ids".to_string(),
                    "affected skill ids, names, agents, scopes, enabled states, and states"
                        .to_string(),
                    "read-only recommended next-step labels".to_string(),
                    "blockers, gaps, and evidence ids".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw prompt or response persistence".to_string(),
                    "raw skill body".to_string(),
                    "raw frontmatter".to_string(),
                    "write/apply instructions".to_string(),
                    "snapshot creation or rollback commands".to_string(),
                ]);
                sections.push(render_remediation_batch_review_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::GuidedCleanupFlow => {
                let result = self.plan_guided_cleanup_flow(GuidedCleanupPlanParams {
                    task: params.user_intent.clone(),
                    agent: None,
                    selected_skill_id: params
                        .skill_instance_id
                        .clone()
                        .or_else(|| params.instance_ids.first().cloned()),
                    selected_skill_name: None,
                    selected_skill_agent: None,
                    project_root: None,
                    current_cwd: None,
                    workspace: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(12),
                    include_recorded_steps: true,
                })?;
                prompt_scope.extend([
                    "deterministic guided cleanup flow steps".to_string(),
                    "issue groups and safe next action labels".to_string(),
                    "app-local recorded guided step metadata when available".to_string(),
                    "gap, blocker, evidence, and safety summaries".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or cleanup intent".to_string(),
                    "flow step ids, phases, risk bands, statuses, and source methods".to_string(),
                    "candidate skill ids, names, agents, and definition ids".to_string(),
                    "safe next action entry methods and confirmation requirements".to_string(),
                    "recorded guided step metadata without raw prompt, response, trace, secrets, or unredacted paths"
                        .to_string(),
                    "evidence ids and read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider prompt".to_string(),
                    "raw provider response".to_string(),
                    "provider API keys or credentials".to_string(),
                    "raw trace content".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                    "write/apply instructions".to_string(),
                    "snapshot creation or rollback commands".to_string(),
                ]);
                sections.push(render_guided_cleanup_flow_prompt_section(
                    &result,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::TaskReadiness => {
                let task = params.user_intent.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt task_readiness requires user_intent/task".to_string(),
                    )
                })?;
                let readiness = self.check_task_readiness(TaskReadinessParams {
                    task: task.to_string(),
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                })?;
                prompt_scope.extend([
                    "deterministic task readiness score".to_string(),
                    "candidate skill summaries".to_string(),
                    "local gap and blocker notes".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task intent".to_string(),
                    "candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "readiness scores and bands".to_string(),
                    "quality score summaries".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                ]);
                sections.push(render_task_readiness_prompt_section(
                    &readiness,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::RoutingConfidence => {
                let task = params.user_intent.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt routing_confidence requires user_intent/task"
                            .to_string(),
                    )
                })?;
                let ranking = self.rank_skill_routes(RankSkillRoutesParams {
                    task: task.to_string(),
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                })?;
                prompt_scope.extend([
                    "deterministic routing confidence score".to_string(),
                    "ordered route candidates".to_string(),
                    "confidence rationale".to_string(),
                    "ambiguity and wrong-pick risks".to_string(),
                    "miss risks".to_string(),
                    "evidence reference summaries".to_string(),
                    "safety flags".to_string(),
                ]);
                included_fields.extend([
                    "redacted task intent".to_string(),
                    "ranked candidate skill ids".to_string(),
                    "skill names".to_string(),
                    "agents".to_string(),
                    "scopes".to_string(),
                    "enabled states".to_string(),
                    "routing confidence scores and bands".to_string(),
                    "readiness and quality score summaries".to_string(),
                    "ambiguity, wrong-pick, and miss risks".to_string(),
                    "finding/conflict/analysis evidence ids and labels".to_string(),
                    "read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider response".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                ]);
                sections.push(render_routing_confidence_prompt_section(
                    &ranking,
                    &mut redactor,
                ));
            }
            LlmPromptActionKind::TaskCockpit => {
                let task = params.user_intent.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "llm.previewPrompt task_cockpit requires user_intent/task".to_string(),
                    )
                })?;
                let cockpit = self.build_task_cockpit(TaskCockpitParams {
                    task: task.to_string(),
                    agent: None,
                    candidate_instance_ids: params.instance_ids.clone(),
                    limit: Some(8),
                    include_session_review: Some(true),
                    include_provider_observability: Some(true),
                    include_remediation_context: Some(true),
                    timeout_ms: None,
                })?;
                prompt_scope.extend([
                    "deterministic task-first cockpit summary".to_string(),
                    "task readiness and routing rows".to_string(),
                    "cross-agent route rows".to_string(),
                    "app-local session review rows".to_string(),
                    "app-local provider observability metadata".to_string(),
                    "read-only remediation next steps".to_string(),
                    "gap, blocker, evidence, and safety summaries".to_string(),
                ]);
                included_fields.extend([
                    "redacted task intent".to_string(),
                    "readiness and routing scores".to_string(),
                    "candidate skill ids, names, agents, scopes, enabled states, and states"
                        .to_string(),
                    "session review outcomes and detected/expected counts".to_string(),
                    "provider/model/status/count metadata without raw prompts or responses"
                        .to_string(),
                    "read-only remediation next-step labels".to_string(),
                    "evidence ids and safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider prompt".to_string(),
                    "raw provider response".to_string(),
                    "provider API keys or credentials".to_string(),
                    "raw trace content".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                    "write/apply instructions".to_string(),
                    "snapshot creation or rollback commands".to_string(),
                ]);
                sections.push(render_task_cockpit_prompt_section(&cockpit, &mut redactor));
            }
            LlmPromptActionKind::SkillLifecycleTimeline => {
                let timeline =
                    self.build_skill_lifecycle_timeline(SkillLifecycleTimelineParams {
                        task: params.user_intent.clone(),
                        agent: None,
                        selected_skill_id: params
                            .skill_instance_id
                            .clone()
                            .or_else(|| params.instance_ids.first().cloned()),
                        selected_skill_name: None,
                        selected_skill_agent: None,
                        definition_id: None,
                        project_root: None,
                        current_cwd: None,
                        workspace: None,
                        limit: Some(12),
                        include_prompt_runs: true,
                        include_session_reviews: true,
                        include_remediation_history: true,
                        include_stale_drift: true,
                    })?;
                prompt_scope.extend([
                    "deterministic skill lifecycle timeline rows".to_string(),
                    "skill and agent lifecycle aggregates".to_string(),
                    "local finding, drift, remediation, prompt, and session-review event counts"
                        .to_string(),
                    "gap, blocker, evidence, and safety summaries".to_string(),
                ]);
                included_fields.extend([
                    "redacted task or lifecycle intent".to_string(),
                    "timeline event ids, types, stages, statuses, and severities".to_string(),
                    "candidate skill ids, names, agents, scopes, enabled states, and states"
                        .to_string(),
                    "app-local remediation/prompt/session metadata without raw prompt, response, or trace content"
                        .to_string(),
                    "evidence ids and read-only safety flags".to_string(),
                ]);
                excluded_fields.extend([
                    "raw source paths".to_string(),
                    "raw provider prompt".to_string(),
                    "raw provider response".to_string(),
                    "provider API keys or credentials".to_string(),
                    "raw trace content".to_string(),
                    "agent config contents".to_string(),
                    "raw skill body".to_string(),
                    "write/apply instructions".to_string(),
                    "snapshot creation or rollback commands".to_string(),
                ]);
                sections.push(render_skill_lifecycle_timeline_prompt_section(
                    &timeline,
                    &mut redactor,
                ));
            }
        }

        sections.push("Required output: concise Markdown draft guidance in the requested output language, with evidence notes, uncertainty, and safe next steps. Mark all suggestions copy-only.".to_string());
        let estimated_output_tokens = match params.action {
            LlmPromptActionKind::Analyze => 700,
            LlmPromptActionKind::Recommend => 500,
            LlmPromptActionKind::ExplainConflict => 650,
            LlmPromptActionKind::DraftFrontmatter => 450,
            LlmPromptActionKind::SkillAnalysis => params
                .analysis_kind
                .unwrap_or(LlmSkillAnalysisKind::Overview)
                .output_token_estimate(),
            LlmPromptActionKind::QualityScore => 650,
            LlmPromptActionKind::StaleDriftDetection => 750,
            LlmPromptActionKind::KnowledgeSearch => 750,
            LlmPromptActionKind::SimilarSkillGrouping => 850,
            LlmPromptActionKind::CapabilityTaxonomy => 850,
            LlmPromptActionKind::LocalSkillMap => 900,
            LlmPromptActionKind::WorkspaceReadiness => 900,
            LlmPromptActionKind::RemediationPlan => 900,
            LlmPromptActionKind::RemediationPreviewDrafts => 850,
            LlmPromptActionKind::RemediationPreviewImpact => 850,
            LlmPromptActionKind::RemediationBatchReview => 900,
            LlmPromptActionKind::GuidedCleanupFlow => 900,
            LlmPromptActionKind::TaskReadiness => 750,
            LlmPromptActionKind::RoutingConfidence => 850,
            LlmPromptActionKind::TaskCockpit => 950,
            LlmPromptActionKind::SkillLifecycleTimeline => 850,
        };
        let prompt_preview = sections.join("\n\n");
        let redaction = redactor.summary();

        Ok(BuiltLlmPrompt {
            prompt_preview,
            prompt_scope,
            included_fields,
            excluded_fields,
            redaction,
            estimated_output_tokens,
        })
    }

    pub(crate) fn render_skill_prompt_section(
        &self,
        skill: &SkillDetailRecord,
        redactor: &mut PromptRedactor<'_>,
    ) -> Result<String, ServiceError> {
        let findings = self.llm_findings_for_skill(skill)?;
        let finding_lines = if findings.is_empty() {
            "none".to_string()
        } else {
            findings
                .iter()
                .take(12)
                .map(|finding| {
                    format!(
                        "- {} severity={} message={} suggestion={}",
                        redactor.redact(&finding.rule_id),
                        redactor.redact(&finding.severity),
                        redactor.redact(&finding.message),
                        finding
                            .suggestion
                            .as_deref()
                            .map(|suggestion| redactor.redact(suggestion))
                            .unwrap_or_else(|| "none".to_string())
                    )
                })
                .collect::<Vec<_>>()
                .join("\n")
        };
        Ok(format!(
            "Selected skill:\n- id: {}\n- name: {}\n- agent: {}\n- scope: {}\n- enabled: {}\n- description: {}\n\nRedacted frontmatter:\n{}\n\nRedacted body:\n{}\n\nRelated findings:\n{}",
            redactor.redact(&skill.id),
            redactor.redact(&skill.name),
            redactor.redact(&skill.agent),
            redactor.redact(&skill.scope),
            skill.enabled,
            redactor.redact(&skill.description),
            redactor.redact(&skill.frontmatter_raw),
            redactor.redact(&skill.body),
            finding_lines
        ))
    }

    pub(crate) fn render_skill_analysis_prompt_sections(
        &self,
        params: &LlmPreviewPromptParams,
        redactor: &mut PromptRedactor<'_>,
    ) -> Result<String, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(format!(
                "Selected skill count: {}\nIncluded skills: 0\nMissing or excluded selections: {}",
                params.instance_ids.len(),
                params.instance_ids.len()
            ));
        };
        let mut sections = Vec::new();
        let mut included_count = 0usize;
        for instance_id in &params.instance_ids {
            let Some(skill) = catalog.get_skill_detail(instance_id)? else {
                continue;
            };
            included_count += 1;
            sections.push(self.render_skill_prompt_section(&skill, redactor)?);
        }
        let missing_count = params.instance_ids.len().saturating_sub(included_count);
        let mut header = format!(
            "Selected skill count: {}\nIncluded skills: {included_count}\nMissing or excluded selections: {missing_count}",
            params.instance_ids.len()
        );
        if sections.is_empty() {
            header.push_str("\nNo selected skill details were available.");
            Ok(header)
        } else {
            Ok(format!("{header}\n\n{}", sections.join("\n\n---\n\n")))
        }
    }

    pub(crate) fn llm_findings_for_skill(
        &self,
        skill: &SkillDetailRecord,
    ) -> Result<Vec<RuleFindingRecord>, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(Vec::new());
        };
        Ok(catalog
            .list_rule_findings()?
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect())
    }

    pub fn prepare_llm_action(
        &self,
        params: LlmPrepareActionParams,
    ) -> Result<LlmPrepareActionResult, ServiceError> {
        let status = self.llm_status();
        let action = params.kind;
        let mut prompt_scope = vec!["operation metadata".to_string()];
        let (estimated_input_tokens, review_preview) = match action {
            LlmActionKind::Analyze | LlmActionKind::DraftFrontmatter => {
                let instance_id = params.skill_instance_id.as_deref().ok_or_else(|| {
                    ServiceError::InvalidRequest(format!(
                        "llm.prepareAction {} requires skill_instance_id",
                        action.as_str()
                    ))
                })?;
                let skill = self.get_llm_skill_detail(instance_id)?;
                prompt_scope.extend([
                    "selected skill name".to_string(),
                    "selected skill description".to_string(),
                    "selected skill frontmatter".to_string(),
                    "selected skill body".to_string(),
                ]);
                let review_preview = self.llm_skill_review_preview(&skill)?;
                (
                    estimate_tokens(&[
                        action.as_str(),
                        &skill.name,
                        &skill.description,
                        &skill.frontmatter_raw,
                        &skill.body,
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    review_preview,
                )
            }
            LlmActionKind::Recommend => {
                prompt_scope.extend([
                    "user intent".to_string(),
                    "catalog recommendation constraints".to_string(),
                ]);
                (
                    estimate_tokens(&[
                        action.as_str(),
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    self.llm_recommendation_review_preview(params.user_intent.as_deref()),
                )
            }
            LlmActionKind::ExplainConflict => {
                prompt_scope.extend([
                    "current conflict summaries".to_string(),
                    "current rule finding summaries".to_string(),
                ]);
                let summary = self.llm_conflict_summary()?;
                (
                    estimate_tokens(&[
                        action.as_str(),
                        &summary,
                        params.user_intent.as_deref().unwrap_or_default(),
                    ]),
                    self.llm_conflict_review_preview(&summary),
                )
            }
        };
        let estimated_output_tokens = match action {
            LlmActionKind::Analyze => 700,
            LlmActionKind::Recommend => 500,
            LlmActionKind::ExplainConflict => 650,
            LlmActionKind::DraftFrontmatter => 450,
        };
        let estimated_total_tokens = estimated_input_tokens
            .saturating_add(estimated_output_tokens)
            .min(status.single_request_token_limit);
        let reason = status.reason.clone();

        Ok(LlmPrepareActionResult {
            action: action.as_str(),
            allowed: status.enabled && status.configured,
            reason: reason.clone(),
            disabled_reason: Some(reason.clone()),
            requires_confirmation: true,
            write_back_allowed: false,
            draft_requires_user_copy: true,
            provider: status.provider.clone(),
            model: status.model.clone(),
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            estimated_cost_usd: 0.0,
            single_request_token_limit: status.single_request_token_limit,
            monthly_budget_usd: status.monthly_budget_usd,
            credentials_storage: status.credentials_storage.clone(),
            credential_persistence_allowed: status.credential_persistence_allowed,
            prompt_scope,
            privacy_notes: vec![
                "No credentials are read, logged, stored in SQLite, or written to the project directory.".to_string(),
                "This method does not execute a provider request and performs no network I/O.".to_string(),
                "Any future LLM output must remain a draft; writes require explicit user copy or a separate non-LLM write action.".to_string(),
            ],
            confirmation: LlmConfirmationRequirement {
                required: true,
                message: "User confirmation is required before any future LLM provider request."
                    .to_string(),
                display_fields: vec![
                    "provider",
                    "model",
                    "estimated_total_tokens",
                    "estimated_cost_usd",
                    "prompt_scope",
                ],
            },
            review_preview,
        })
    }

    pub fn prepare_llm_skill_analysis(
        &self,
        params: LlmPrepareSkillAnalysisParams,
    ) -> Result<LlmPrepareSkillAnalysisResult, ServiceError> {
        let status = self.llm_status();
        let selected_skill_count = params.instance_ids.len();
        let mut included_skills = Vec::new();
        let mut estimate_parts = vec![params.analysis_kind.as_str().to_string()];
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            let disabled_reason = status.reason.clone();
            let prompt_draft = skill_analysis_prompt_draft(
                params.analysis_kind,
                selected_skill_count,
                &included_skills,
                selected_skill_count,
            );
            let summary_draft = skill_analysis_summary_draft(
                params.analysis_kind,
                selected_skill_count,
                &included_skills,
                selected_skill_count,
            );
            let estimated_input_tokens = estimate_tokens(&[&prompt_draft, &summary_draft]);
            let estimated_output_tokens = params.analysis_kind.output_token_estimate();
            let estimated_total_tokens = estimated_input_tokens
                .saturating_add(estimated_output_tokens)
                .min(status.single_request_token_limit);
            return Ok(LlmPrepareSkillAnalysisResult {
                enabled: false,
                disabled_reason,
                analysis_kind: params.analysis_kind.as_str(),
                selected_skill_count,
                included_skill_count: 0,
                excluded_missing_count: selected_skill_count,
                included_skills,
                prompt_draft,
                summary_draft,
                safety_flags: llm_skill_analysis_safety_flags(),
                estimated_input_tokens,
                estimated_output_tokens,
                estimated_total_tokens,
                provider_request_sent: false,
                generated_by: "deterministic-service",
            });
        };

        for instance_id in &params.instance_ids {
            let Some(detail) = catalog.get_skill_detail(instance_id)? else {
                continue;
            };
            estimate_parts.extend([
                detail.name.clone(),
                detail.agent.clone(),
                detail.scope.clone(),
                detail.description.clone(),
                detail.frontmatter_raw.clone(),
                detail.body.clone(),
            ]);
            included_skills.push(LlmSkillAnalysisIncludedSkill {
                instance_id: detail.id,
                name: detail.name,
                agent: detail.agent,
                scope: detail.scope,
                enabled: detail.enabled,
                disabled_reason: if detail.enabled {
                    None
                } else {
                    Some("Skill is disabled in the current catalog state.".to_string())
                },
            });
        }

        let excluded_missing_count = selected_skill_count.saturating_sub(included_skills.len());
        let prompt_draft = skill_analysis_prompt_draft(
            params.analysis_kind,
            selected_skill_count,
            &included_skills,
            excluded_missing_count,
        );
        let summary_draft = skill_analysis_summary_draft(
            params.analysis_kind,
            selected_skill_count,
            &included_skills,
            excluded_missing_count,
        );
        estimate_parts.extend([prompt_draft.clone(), summary_draft.clone()]);
        let estimate_refs = estimate_parts
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>();
        let estimated_input_tokens = estimate_tokens(&estimate_refs);
        let estimated_output_tokens = params.analysis_kind.output_token_estimate();
        let estimated_total_tokens = estimated_input_tokens
            .saturating_add(estimated_output_tokens)
            .min(status.single_request_token_limit);

        Ok(LlmPrepareSkillAnalysisResult {
            enabled: false,
            disabled_reason: status.reason,
            analysis_kind: params.analysis_kind.as_str(),
            selected_skill_count,
            included_skill_count: included_skills.len(),
            excluded_missing_count,
            included_skills,
            prompt_draft,
            summary_draft,
            safety_flags: llm_skill_analysis_safety_flags(),
            estimated_input_tokens,
            estimated_output_tokens,
            estimated_total_tokens,
            provider_request_sent: false,
            generated_by: "deterministic-service",
        })
    }

    pub(crate) fn llm_skill_review_preview(
        &self,
        skill: &SkillDetailRecord,
    ) -> Result<LlmReviewPreview, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(LlmReviewPreview::unavailable());
        };
        let findings = catalog.list_rule_findings()?;
        let related_findings: Vec<RuleFindingRecord> = findings
            .into_iter()
            .filter(|finding| {
                finding.instance_id.as_deref() == Some(skill.id.as_str())
                    || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
            })
            .collect();
        let records = catalog.list_skill_records()?;
        let comparable_instance_count = records
            .iter()
            .filter(|record| record.definition_id == skill.definition_id && record.id != skill.id)
            .count();
        let finding_explanations = related_findings
            .iter()
            .take(8)
            .map(|finding| LlmReviewFindingExplanation {
                rule_id: finding.rule_id.clone(),
                severity: finding.severity.clone(),
                explanation: redact_for_llm_preview(&finding.message),
                suggested_next_step: finding.suggestion.as_deref().map(redact_for_llm_preview),
            })
            .collect::<Vec<_>>();
        let risk = llm_review_risk(&related_findings, &skill.frontmatter_raw, &skill.body);
        let description = redact_for_llm_preview(&skill.description);
        let purpose = if description.is_empty() {
            format!(
                "Offline review preview for `{}`. No body text is returned; purpose is inferred from catalog name and metadata only.",
                redact_for_llm_preview(&skill.name)
            )
        } else {
            format!(
                "{} Offline review only; no provider request was sent and skill body content is not returned.",
                description
            )
        };
        let cross_summary = if comparable_instance_count == 0 {
            "No other cataloged agent instance shares this definition id in the current catalog."
                .to_string()
        } else {
            format!(
                "{comparable_instance_count} other cataloged instance(s) share this definition id; review adapter-specific permissions and enablement before copying behavior across agents."
            )
        };
        Ok(LlmReviewPreview {
            status: "offline-preview",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose,
            risk,
            finding_explanations,
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: skill.agent.clone(),
                scope: skill.scope.clone(),
                comparable_instance_count,
                summary: cross_summary,
                notes: vec![
                    "Cross-agent fit is advisory and read-only; this response cannot install, import, toggle, or edit skills.".to_string(),
                    "Adapter compatibility is based only on current catalog metadata, not provider-generated recommendations.".to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        })
    }

    pub(crate) fn llm_recommendation_review_preview(
        &self,
        user_intent: Option<&str>,
    ) -> LlmReviewPreview {
        let intent = redact_for_llm_preview(user_intent.unwrap_or_default());
        let purpose = if intent.is_empty() {
            "Prepared an offline recommendation preflight without reading skill bodies or calling a provider.".to_string()
        } else {
            format!(
                "Prepared an offline recommendation preflight for the supplied intent: {intent}"
            )
        };
        LlmReviewPreview {
            status: "prepared-unavailable",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose,
            risk: LlmReviewRisk {
                level: "unknown",
                summary: "No selected skill was reviewed, so risk is not assessed.".to_string(),
                signals: vec![
                    "Recommendation prepare does not read arbitrary skill files or return catalog paths."
                        .to_string(),
                ],
            },
            finding_explanations: Vec::new(),
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: "catalog".to_string(),
                scope: "read-only-preflight".to_string(),
                comparable_instance_count: 0,
                summary:
                    "Cross-agent fit requires a selected catalog skill or current analysis groups."
                        .to_string(),
                notes: vec![
                    "No provider request was sent and no recommendation output was generated."
                        .to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        }
    }

    pub(crate) fn llm_conflict_review_preview(&self, summary: &str) -> LlmReviewPreview {
        LlmReviewPreview {
            status: "offline-preview",
            generated_by: "deterministic-service",
            provider_request_sent: false,
            write_actions_available: false,
            execution_actions_available: false,
            purpose: "Prepared an offline conflict/finding explanation from catalog summaries only."
                .to_string(),
            risk: LlmReviewRisk {
                level: if summary.contains("severity=error") || summary.contains("severity=critical")
                {
                    "high"
                } else if summary.contains("finding rule=") {
                    "medium"
                } else {
                    "low"
                },
                summary: redact_for_llm_preview(summary),
                signals: vec![
                    "Conflict explain prepare uses rule ids, severity labels, definition ids, and counts; it does not return skill body text."
                        .to_string(),
                ],
            },
            finding_explanations: Vec::new(),
            cross_agent_fit: LlmReviewCrossAgentFit {
                agent: "catalog".to_string(),
                scope: "conflict-summary".to_string(),
                comparable_instance_count: 0,
                summary: "Cross-agent fit is represented by current conflict groups and definition ids only."
                    .to_string(),
                notes: vec![
                    "Resolve conflicts through existing explicit user actions; no Apply/Write path exists in this preview."
                        .to_string(),
                ],
            },
            redaction: llm_review_redaction(),
        }
    }

    pub(crate) fn get_llm_skill_detail(
        &self,
        instance_id: &str,
    ) -> Result<SkillDetailRecord, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Err(ServiceError::SkillNotFound(instance_id.to_string()));
        };
        catalog
            .get_skill_detail(instance_id)?
            .ok_or_else(|| ServiceError::SkillNotFound(instance_id.to_string()))
    }

    pub(crate) fn llm_conflict_summary(&self) -> Result<String, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(
                "No catalog is available; no conflicts or findings were loaded.".to_string(),
            );
        };
        let conflicts = catalog.list_conflict_groups()?;
        let findings = catalog.list_rule_findings()?;
        let mut lines = Vec::new();
        for conflict in conflicts.iter().take(20) {
            lines.push(format!(
                "conflict reason={} definition_id={} instances={}",
                conflict.reason,
                conflict.definition_id,
                conflict.instance_ids.len()
            ));
        }
        for finding in findings.iter().take(20) {
            lines.push(format!(
                "finding rule={} severity={} has_instance={} has_suggestion={}",
                finding.rule_id,
                finding.severity,
                finding.instance_id.is_some(),
                finding.suggestion.is_some()
            ));
        }
        if lines.is_empty() {
            Ok("No current conflicts or findings were loaded.".to_string())
        } else {
            Ok(lines.join("\n"))
        }
    }
}
