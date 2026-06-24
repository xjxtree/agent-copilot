use super::*;

impl ServiceHost {
    pub fn from_env() -> Result<Self, ServiceError> {
        let user_home = env::var_os("SKILLS_COPILOT_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(PathBuf::from))
            .ok_or_else(|| ServiceError::InvalidRequest("HOME is not set".to_string()))?;
        let app_data_dir = env::var_os("SKILLS_COPILOT_APP_DATA_DIR")
            .map(PathBuf::from)
            .map(Ok)
            .unwrap_or_else(|| resolve_default_app_data_dir(&user_home))?;
        let project_cwd = env::var_os("SKILLS_COPILOT_PROJECT_CWD").map(PathBuf::from);
        let project_root = env::var_os("SKILLS_COPILOT_PROJECT_ROOT")
            .map(PathBuf::from)
            .or_else(|| project_cwd.as_deref().map(infer_project_root));
        let adapter_ctx = AdapterContext {
            user_home,
            project_root: project_root.clone(),
            project_cwd: project_cwd.or(project_root),
            extra_roots: extra_claude_roots_from_env(),
        };
        Ok(Self {
            app_data_dir,
            adapter_ctx,
        })
    }

    pub fn handle(&self, request: ServiceRequest) -> ServiceResponse {
        let id = request.id.clone();
        match self.handle_result(request) {
            Ok(result) => ServiceResponse {
                id,
                ok: true,
                result: Some(result),
                error: None,
            },
            Err(error) => ServiceResponse {
                id,
                ok: false,
                result: None,
                error: Some(ServiceErrorRecord {
                    code: error.code().to_string(),
                    message: error.to_string(),
                }),
            },
        }
    }

    pub(crate) fn handle_result(&self, request: ServiceRequest) -> Result<Value, ServiceError> {
        match request.method.as_str() {
            "app.version" => serde_json::to_value(self.app_version()).map_err(Into::into),
            "app.stateSnapshot" => {
                serde_json::to_value(self.app_state_snapshot()?).map_err(Into::into)
            }
            "service.status" => serde_json::to_value(self.status()).map_err(Into::into),
            "adapter.listCapabilities" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                serde_json::to_value(list_adapter_capabilities(&adapter_ctx)).map_err(Into::into)
            }
            "adapter.listDiagnostics" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                serde_json::to_value(list_adapter_diagnostics(&adapter_ctx)).map_err(Into::into)
            }
            "evidence.previewMcpServers" => {
                let params: McpServerPreviewParams = if request.params.is_null() {
                    McpServerPreviewParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.preview_mcp_servers(params)?).map_err(Into::into)
            }
            "evidence.piWritableHarness" => {
                let params: PiWritableHarnessParams = if request.params.is_null() {
                    PiWritableHarnessParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                let report: PiWritableHarnessReport =
                    run_pi_writable_evidence_harness(&self.pi_writable_harness_root(params))?;
                serde_json::to_value(report).map_err(Into::into)
            }
            "analysis.scoreSkillQuality" => {
                let params: ScoreSkillQualityParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.score_skill_quality(params)?).map_err(Into::into)
            }
            "analysis.detectStaleDrift" => {
                let params: DetectStaleDriftParams = if request.params.is_null() {
                    DetectStaleDriftParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.detect_stale_drift(params)?).map_err(Into::into)
            }
            "knowledge.search" => {
                let params: KnowledgeSearchParams = if request.params.is_null() {
                    KnowledgeSearchParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.search_knowledge(params)?).map_err(Into::into)
            }
            "knowledge.groupSimilarSkills" => {
                let params: SimilarSkillGroupingParams = if request.params.is_null() {
                    SimilarSkillGroupingParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.group_similar_skills(params)?).map_err(Into::into)
            }
            "knowledge.buildCapabilityTaxonomy" => {
                let params: CapabilityTaxonomyParams = if request.params.is_null() {
                    CapabilityTaxonomyParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.build_capability_taxonomy(params)?).map_err(Into::into)
            }
            "knowledge.buildLocalSkillMap" => {
                let params: LocalSkillMapParams = if request.params.is_null() {
                    LocalSkillMapParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.build_local_skill_map(params)?).map_err(Into::into)
            }
            "workspace.checkReadiness" => {
                let params: WorkspaceReadinessParams = if request.params.is_null() {
                    WorkspaceReadinessParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.check_workspace_readiness(params)?).map_err(Into::into)
            }
            "remediation.plan" => {
                let params: RemediationPlanParams = if request.params.is_null() {
                    RemediationPlanParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.plan_remediation(params)?).map_err(Into::into)
            }
            "remediation.previewDrafts" => {
                let params: RemediationPreviewDraftsParams = if request.params.is_null() {
                    RemediationPreviewDraftsParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.preview_remediation_drafts(params)?).map_err(Into::into)
            }
            "remediation.previewImpact" => {
                let params: RemediationPreviewImpactParams = if request.params.is_null() {
                    RemediationPreviewImpactParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.preview_remediation_impact(params)?).map_err(Into::into)
            }
            "remediation.batchReview" => {
                let params: RemediationBatchReviewParams = if request.params.is_null() {
                    RemediationBatchReviewParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.batch_review_remediation(params)?).map_err(Into::into)
            }
            "remediation.listHistory" => {
                let params: RemediationHistoryListParams = if request.params.is_null() {
                    RemediationHistoryListParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_remediation_history(params)?).map_err(Into::into)
            }
            "remediation.recordHistory" => {
                let params: RemediationHistoryRecordParams =
                    serde_json::from_value(request.params)?;
                serde_json::to_value(self.record_remediation_history(params)?).map_err(Into::into)
            }
            "remediation.deleteHistory" => {
                let params: RemediationHistoryDeleteParams =
                    serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_remediation_history(params)?).map_err(Into::into)
            }
            "task.checkReadiness" => {
                let params: TaskReadinessParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.check_task_readiness(params)?).map_err(Into::into)
            }
            "task.rankSkillRoutes" => {
                let params: RankSkillRoutesParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.rank_skill_routes(params)?).map_err(Into::into)
            }
            "task.compareAgentReadiness" => {
                let params: CompareAgentReadinessParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.compare_agent_readiness(params)?).map_err(Into::into)
            }
            "task.buildCockpit" => {
                let params: TaskCockpitParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.build_task_cockpit(params)?).map_err(Into::into)
            }
            "task.listBenchmarks" => {
                let params: ListTaskBenchmarksParams = if request.params.is_null() {
                    ListTaskBenchmarksParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_task_benchmarks(params)?).map_err(Into::into)
            }
            "task.saveBenchmark" => {
                let params: SaveTaskBenchmarkParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.save_task_benchmark(params)?).map_err(Into::into)
            }
            "task.deleteBenchmark" => {
                let params: DeleteTaskBenchmarkParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_task_benchmark(params)?).map_err(Into::into)
            }
            "task.evaluateBenchmarks" => {
                let params: EvaluateTaskBenchmarksParams = if request.params.is_null() {
                    EvaluateTaskBenchmarksParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.evaluate_task_benchmarks(params)?).map_err(Into::into)
            }
            "task.saveRoutingBaseline" => {
                let params: SaveRoutingBaselineParams = if request.params.is_null() {
                    SaveRoutingBaselineParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.save_routing_baseline(params)?).map_err(Into::into)
            }
            "task.detectRoutingRegression" => {
                let params: DetectRoutingRegressionParams = if request.params.is_null() {
                    DetectRoutingRegressionParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.detect_routing_regression(params)?).map_err(Into::into)
            }
            "routing.accuracyDashboard" => {
                let params: RoutingAccuracyDashboardParams = if request.params.is_null() {
                    RoutingAccuracyDashboardParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.routing_accuracy_dashboard(params)?).map_err(Into::into)
            }
            "skill.lifecycleTimeline" => {
                let params: SkillLifecycleTimelineParams = if request.params.is_null() {
                    SkillLifecycleTimelineParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.build_skill_lifecycle_timeline(params)?)
                    .map_err(Into::into)
            }
            "session.previewLocalSessions" => {
                let params: LocalSessionPreviewParams = if request.params.is_null() {
                    LocalSessionPreviewParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.preview_local_sessions(params)?).map_err(Into::into)
            }
            "session.reviewAgentSkillUse" => {
                let params: AgentSessionSkillReviewParams = if request.params.is_null() {
                    AgentSessionSkillReviewParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.review_agent_skill_use(params)?).map_err(Into::into)
            }
            "session.listSkillReviews" => {
                let params: AgentSessionListSkillReviewsParams = if request.params.is_null() {
                    AgentSessionListSkillReviewsParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_agent_skill_reviews(params)?).map_err(Into::into)
            }
            "session.deleteSkillReview" => {
                let params: AgentSessionDeleteSkillReviewParams =
                    serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_agent_skill_review(params)?).map_err(Into::into)
            }
            "trace.importLocal" => {
                let params: TraceImportLocalParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.import_local_trace(params)?).map_err(Into::into)
            }
            "trace.listImports" => {
                let params: TraceListImportsParams = if request.params.is_null() {
                    TraceListImportsParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_trace_imports(params)?).map_err(Into::into)
            }
            "trace.deleteImport" => {
                let params: TraceDeleteImportParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_trace_import(params)?).map_err(Into::into)
            }
            "llm.status" => serde_json::to_value(self.llm_status()).map_err(Into::into),
            "llm.listProviderProfiles" => {
                serde_json::to_value(self.list_llm_provider_profiles()?).map_err(Into::into)
            }
            "llm.saveProviderProfile" => {
                let params: SaveProviderProfileParams = serde_json::from_value(request.params)?;
                serde_json::to_value(save_provider_profile(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.deleteProviderProfile" => {
                let params: DeleteProviderProfileParams = serde_json::from_value(request.params)?;
                serde_json::to_value(delete_provider_profile(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.testProviderConnection" => {
                let params: TestProviderConnectionParams = serde_json::from_value(request.params)?;
                serde_json::to_value(test_provider_connection(&self.app_data_dir, params)?)
                    .map_err(Into::into)
            }
            "llm.previewPrompt" => {
                let params: LlmPreviewPromptParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.preview_llm_prompt(params)?).map_err(Into::into)
            }
            "llm.confirmPromptAndSend" => {
                let params: LlmConfirmPromptAndSendParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.confirm_llm_prompt_and_send(params)?).map_err(Into::into)
            }
            "llm.listPromptRuns" => {
                let params: LlmPromptRunListParams = if request.params.is_null() {
                    LlmPromptRunListParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_llm_prompt_runs(params)?).map_err(Into::into)
            }
            "llm.providerObservability" => {
                let params: LlmProviderObservabilityParams = if request.params.is_null() {
                    LlmProviderObservabilityParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.llm_provider_observability(params)?).map_err(Into::into)
            }
            "llm.listModelTaskMatches" => {
                let params: ModelTaskMatchListParams = if request.params.is_null() {
                    ModelTaskMatchListParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.list_model_task_matches(params)?).map_err(Into::into)
            }
            "llm.recordModelTaskMatch" => {
                let params: ModelTaskMatchRecordParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.record_model_task_match(params)?).map_err(Into::into)
            }
            "llm.deleteModelTaskMatch" => {
                let params: ModelTaskMatchDeleteParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.delete_model_task_match(params)?).map_err(Into::into)
            }
            "llm.prepareAction" => {
                let params: LlmPrepareActionParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.prepare_llm_action(params)?).map_err(Into::into)
            }
            "llm.prepareSkillAnalysis" => {
                let params: LlmPrepareSkillAnalysisParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.prepare_llm_skill_analysis(params)?).map_err(Into::into)
            }
            "cleanup.listQueue" => {
                let params: CleanupListQueueParams = if request.params.is_null() {
                    CleanupListQueueParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.cleanup_list_queue(params)?).map_err(Into::into)
            }
            "cleanup.planGuidedFlow" => {
                let params: GuidedCleanupPlanParams = if request.params.is_null() {
                    GuidedCleanupPlanParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.plan_guided_cleanup_flow(params)?).map_err(Into::into)
            }
            "cleanup.recordGuidedStep" => {
                let params: GuidedCleanupRecordStepParams = serde_json::from_value(request.params)?;
                serde_json::to_value(self.record_guided_cleanup_step(params)?).map_err(Into::into)
            }
            "comparison.listCrossAgent" => {
                let params: ListCrossAgentComparisonParams = if request.params.is_null() {
                    ListCrossAgentComparisonParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                let Some(catalog) = self.open_existing_catalog_read_only()? else {
                    return serde_json::to_value(empty_cross_agent_comparison(
                        params.selected_instance_id.as_deref(),
                    ))
                    .map_err(Into::into);
                };
                let adapter_ctx = self.effective_adapter_ctx()?;
                let comparisons: CrossAgentComparisonRecord = list_cross_agent_comparisons(
                    &catalog,
                    &adapter_ctx,
                    params.selected_instance_id.as_deref(),
                    params.agent.as_deref(),
                    params.query.as_deref(),
                    params.limit,
                )?;
                serde_json::to_value(comparisons).map_err(Into::into)
            }
            "report.exportLocal" => {
                let params: ReportExportLocalParams = if request.params.is_null() {
                    ReportExportLocalParams::default()
                } else {
                    serde_json::from_value(request.params)?
                };
                serde_json::to_value(self.export_local_report(params)?).map_err(Into::into)
            }
            "rules.listTuning" => {
                let catalog = self.open_catalog()?;
                let tuning: Vec<RuleTuningRecord> = list_rule_tuning(&catalog)?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.setSeverityOverride" => {
                let params: SetSeverityOverrideParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let tuning: RuleTuningRecord = set_rule_severity_override(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                    &params.severity,
                )?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.clearSeverityOverride" => {
                let params: RuleTuningScopeParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_rule_severity_override(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                )?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "rules.setSuppression" => {
                let params: SetSuppressionParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let tuning: RuleTuningRecord = set_rule_suppression(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                    &params.reason,
                    params.note.as_deref(),
                )?;
                serde_json::to_value(tuning).map_err(Into::into)
            }
            "rules.clearSuppression" => {
                let params: RuleTuningScopeParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_rule_suppression(
                    &catalog,
                    &params.rule_id,
                    params.agent.as_deref(),
                    params.scope.as_deref(),
                )?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "batch.previewSkillToggles" => {
                let params: BatchPreviewSkillTogglesParams =
                    serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let preview: BatchTogglePreviewRecord = preview_skill_toggles(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_ids,
                    params.target_enabled,
                )?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "batch.applySkillToggles" => {
                let params: BatchApplySkillTogglesParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let applied: BatchToggleApplyRecord = apply_skill_toggles(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_ids,
                    params.target_enabled,
                    &params.preview_token,
                )?;
                serde_json::to_value(applied).map_err(Into::into)
            }
            "script.previewExecution" => {
                let params: ScriptExecutionRequest = serde_json::from_value(request.params)?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let preview: ScriptExecutionPreviewRecord =
                    preview_script_execution(&adapter_ctx, &params)?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "script.execute" => {
                let params: ScriptExecutionRequest = serde_json::from_value(request.params)?;
                if !params.confirmed {
                    return Err(ServiceError::ConfirmationRequired(
                        "script.execute requires confirmed=true on each request; use script.previewExecution to inspect the command, cwd, env, network, files, risks, and confirmation fields before confirming.".to_string(),
                    ));
                }
                let adapter_ctx = self.effective_adapter_ctx()?;
                let attempt: ScriptExecutionAttemptRecord = record_blocked_script_execution(
                    &adapter_ctx,
                    &self.app_data_dir.join("audit"),
                    &self.script_execution_audit_path(),
                    &params,
                )?;
                serde_json::to_value(attempt).map_err(Into::into)
            }
            "project.getContext" => {
                let state: ProjectContextState = load_project_context_state(&self.app_data_dir)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.setContext" => {
                let params: ProjectContextParams = serde_json::from_value(request.params)?;
                let state: ProjectContextState = set_project_context(&self.app_data_dir, params)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.clearContext" => {
                let state: ProjectContextState = clear_project_context(&self.app_data_dir)?;
                serde_json::to_value(state).map_err(Into::into)
            }
            "project.validateContext" => {
                let params: ProjectContextParams = serde_json::from_value(request.params)?;
                let context: ProjectContext = validate_project_context_for_response(params);
                serde_json::to_value(context).map_err(Into::into)
            }
            "catalog.listSkills" => {
                let catalog = self.open_catalog()?;
                serde_json::to_value(self.list_visible_skill_records(&catalog)?).map_err(Into::into)
            }
            "catalog.getSkill" => {
                let params: GetSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let detail: SkillDetailRecord = get_skill(&catalog, &params.instance_id)?;
                serde_json::to_value(detail).map_err(Into::into)
            }
            "catalog.analysis" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let analysis: CrossAgentAnalysisRecord = analyze_catalog(&catalog, &adapter_ctx)?;
                serde_json::to_value(analysis).map_err(Into::into)
            }
            "skill.listEvents" => {
                let params: ListSkillEventsParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let events: Vec<SkillEventRecord> =
                    list_skill_events(&catalog, &params.instance_id, params.limit)?;
                serde_json::to_value(events).map_err(Into::into)
            }
            "catalog.listFindings" => {
                let catalog = self.open_catalog()?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                serde_json::to_value(findings).map_err(Into::into)
            }
            "catalog.listFindingTriage" => {
                let catalog = self.open_catalog()?;
                let triage: Vec<FindingTriageRecord> = list_finding_triage(&catalog)?;
                serde_json::to_value(triage).map_err(Into::into)
            }
            "catalog.setFindingTriage" => {
                let params: SetFindingTriageParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let triage: FindingTriageRecord = set_finding_triage(
                    &catalog,
                    &params.triage_key,
                    &params.status,
                    params.note.as_deref(),
                )?;
                serde_json::to_value(triage).map_err(Into::into)
            }
            "catalog.clearFindingTriage" => {
                let params: ClearFindingTriageParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let cleared: bool = clear_finding_triage(&catalog, &params.triage_key)?;
                serde_json::to_value(cleared).map_err(Into::into)
            }
            "catalog.listConflicts" => {
                let catalog = self.open_catalog()?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                serde_json::to_value(conflicts).map_err(Into::into)
            }
            "catalog.importSkill" => {
                let params: ImportSkillParams = serde_json::from_value(request.params)?;
                if let Some(github_url) = params.github_url.as_deref() {
                    import_github_skill_to_tool_global_deferred(github_url)?;
                }
                let source_path = params.source_path.ok_or_else(|| {
                    ServiceError::InvalidRequest(
                        "catalog.importSkill requires source_path for local imports".to_string(),
                    )
                })?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let result: ToolGlobalImportResult = import_local_skill_to_tool_global(
                    &catalog,
                    &adapter_ctx,
                    &self.tool_global_staging_root(),
                    Path::new(&source_path),
                )?;
                serde_json::to_value(result).map_err(Into::into)
            }
            "catalog.scanClaude" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let started_at = unix_timestamp_millis();
                let scanned_count = scan_claude_to_catalog(&adapter_ctx, &catalog)?;
                let skills = self.list_visible_skill_records(&catalog)?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                let activity = self.scan_activity(
                    "catalog.scanClaude",
                    "Claude Code",
                    self.claude_root_paths(),
                    started_at,
                    ScanActivityCounts {
                        scanned_count,
                        skill_count: skills.len(),
                        finding_count: findings.len(),
                        conflict_count: conflicts.len(),
                        snapshot_count: snapshots.len(),
                    },
                    None,
                );
                serde_json::to_value(ScanResult {
                    scanned_count,
                    skills,
                    activity,
                })
                .map_err(Into::into)
            }
            "catalog.scanAll" => {
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let started_at = unix_timestamp_millis();
                let scan_report = scan_all_catalog_report(&adapter_ctx, &catalog)?;
                let scanned_count = scan_report.scanned_count;
                let skills = self.list_visible_skill_records(&catalog)?;
                let findings: Vec<RuleFindingRecord> = list_findings(&catalog)?;
                let conflicts: Vec<ConflictGroupRecord> = list_conflicts(&catalog)?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                let adapter_diagnostics = list_adapter_diagnostics(&adapter_ctx);
                let agent_summaries = self.agent_refresh_summaries(
                    &scan_report.agents,
                    &skills,
                    &adapter_diagnostics,
                );
                let roots = scan_report
                    .agents
                    .iter()
                    .flat_map(|agent| agent.roots_considered.iter().cloned())
                    .collect();
                let scan_label = scan_all_label(&scan_report.agents);
                let activity = self.scan_activity(
                    "catalog.scanAll",
                    &scan_label,
                    roots,
                    started_at,
                    ScanActivityCounts {
                        scanned_count,
                        skill_count: skills.len(),
                        finding_count: findings.len(),
                        conflict_count: conflicts.len(),
                        snapshot_count: snapshots.len(),
                    },
                    Some(agent_summaries),
                );
                serde_json::to_value(ScanResult {
                    scanned_count,
                    skills,
                    activity,
                })
                .map_err(Into::into)
            }
            "skill.exportBundle" => {
                let params: ExportSkillBundleParams = serde_json::from_value(request.params)?;
                let output_dir = params
                    .output_dir
                    .unwrap_or_else(|| self.app_data_dir.join("exports"));
                let exported: ExportedSkillBundle =
                    match (params.instance_id.as_deref(), params.source_path.as_deref()) {
                        (Some(instance_id), None) => {
                            let catalog = self.open_catalog()?;
                            export_skill_bundle(&catalog, instance_id, &output_dir)?
                        }
                        (None, Some(source_path)) => {
                            export_staging_skill_bundle(source_path, &output_dir)?
                        }
                        _ => {
                            return Err(ServiceError::InvalidRequest(
                            "skill.exportBundle requires exactly one of instance_id or source_path"
                                .to_string(),
                        ));
                        }
                    };
                serde_json::to_value(exported).map_err(Into::into)
            }
            "config.toggleSkill" => {
                let params: ToggleSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let record: SkillRecord =
                    toggle_skill(&catalog, &adapter_ctx, &params.instance_id, params.on)?;
                serde_json::to_value(record).map_err(Into::into)
            }
            "skill.install" => {
                let params: InstallSkillParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let target_agent = parse_agent_param(&params.target_agent)?;
                let target_scope = parse_scope_param(&params.target_scope)?;
                let preview: SkillInstallPreviewRecord = install_skill_from_tool_global(
                    &catalog,
                    &adapter_ctx,
                    &params.instance_id,
                    target_agent,
                    target_scope,
                    params.project_path.as_deref(),
                    params.confirmed,
                )?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "config.readClaudeSettings" => {
                let adapter_ctx = self.effective_adapter_ctx()?;
                let document: ConfigDocumentRecord = read_claude_settings(&adapter_ctx)?;
                serde_json::to_value(document).map_err(Into::into)
            }
            "config.saveClaudeSettings" => {
                let params: SaveClaudeSettingsParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let document: ConfigDocumentRecord =
                    save_claude_settings(&catalog, &adapter_ctx, &params.content)?;
                serde_json::to_value(document).map_err(Into::into)
            }
            "snapshot.list" => {
                let catalog = self.open_catalog()?;
                let snapshots: Vec<ConfigSnapshotRecord> = list_snapshots(&catalog)?;
                serde_json::to_value(snapshots).map_err(Into::into)
            }
            "snapshot.listAgentConfig" => {
                let params: ListAgentConfigSnapshotsParams =
                    serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let scope = params.scope.as_deref().filter(|scope| !scope.is_empty());
                let snapshots: Vec<ConfigSnapshotRecord> =
                    list_agent_config_snapshots(&catalog, &params.agent, scope)?;
                serde_json::to_value(snapshots).map_err(Into::into)
            }
            "snapshot.previewRollback" => {
                let params: SnapshotParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let preview: SnapshotRollbackPreviewRecord =
                    preview_snapshot_rollback(&catalog, &params.snapshot_id)?;
                serde_json::to_value(preview).map_err(Into::into)
            }
            "snapshot.rollback" => {
                let params: SnapshotParams = serde_json::from_value(request.params)?;
                let catalog = self.open_catalog()?;
                let adapter_ctx = self.effective_adapter_ctx()?;
                let scanned_count = rollback_snapshot(&catalog, &adapter_ctx, &params.snapshot_id)?;
                serde_json::to_value(scanned_count).map_err(Into::into)
            }
            method => Err(ServiceError::UnknownMethod(method.to_string())),
        }
    }

    pub fn app_version(&self) -> AppVersion {
        AppVersion {
            protocol_version: SERVICE_PROTOCOL_VERSION,
            version: skills_copilot_commands::app_version(),
        }
    }

    pub fn app_state_snapshot(&self) -> Result<AppStateSnapshot, ServiceError> {
        let catalog = self.open_catalog()?;
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let health = skill_health_summary(&catalog, &adapter_ctx)?;
        Ok(AppStateSnapshot {
            status: self.status(),
            skills,
            findings,
            conflicts,
            analysis,
            health,
            snapshots: list_snapshots(&catalog)?,
        })
    }

    pub(crate) fn list_visible_skill_records(
        &self,
        catalog: &Catalog,
    ) -> Result<Vec<SkillRecord>, ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills =
            catalog.list_skill_records_for_project_context(adapter_ctx.project_root.as_deref())?;
        Ok(skills
            .into_iter()
            .filter(|skill| !is_pi_plain_markdown_catalog_noise(skill))
            .collect())
    }

    pub fn status(&self) -> ServiceStatus {
        let adapter_ctx = self.status_adapter_ctx();
        ServiceStatus {
            protocol_version: SERVICE_PROTOCOL_VERSION,
            version: skills_copilot_commands::app_version(),
            app_data_dir: display_path(&self.app_data_dir),
            catalog_path: display_path(&self.catalog_path()),
            user_home: display_path(&adapter_ctx.user_home),
            supported_methods: supported_methods(),
            refresh: RefreshStatus {
                scan_progress: "summary-only",
                watcher_state: "manual-refresh",
                watcher_detail: "The current stdio sidecar reports completed refresh summaries; native automatic watcher events are not running in this process.",
                recovery_actions: vec!["Retry the last refresh", "Run Scan to rebuild the agent catalog"],
            },
            project_context: project_context_summary(&self.app_data_dir, self.env_project_context()),
            adapter_capabilities: list_adapter_capabilities(&adapter_ctx),
            adapter_diagnostics: list_adapter_diagnostics(&adapter_ctx),
            llm: self.llm_status(),
            trace_imports: self.trace_import_status(),
            session_reviews: self.agent_session_review_status(),
            script_execution: self.script_execution_status(),
        }
    }

    pub(crate) fn pi_writable_harness_root(&self, params: PiWritableHarnessParams) -> PathBuf {
        let label = params
            .run_label
            .as_deref()
            .map(sanitize_harness_label)
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| format!("run-{}", unix_timestamp_millis()));
        self.app_data_dir
            .join("evidence")
            .join("pi-writable-harness")
            .join(label)
    }

    pub(crate) fn open_catalog(&self) -> Result<Catalog, ServiceError> {
        create_private_dir_all(&self.app_data_dir)?;
        let catalog = Catalog::open(&self.catalog_path())?;
        catalog.init()?;
        Ok(catalog)
    }

    pub(crate) fn open_existing_catalog_read_only(&self) -> Result<Option<Catalog>, ServiceError> {
        let catalog_path = self.catalog_path();
        if !catalog_path.exists() {
            return Ok(None);
        }
        Ok(Some(Catalog::open_read_only(&catalog_path)?))
    }

    pub(crate) fn catalog_path(&self) -> PathBuf {
        self.app_data_dir.join("catalog.sqlite")
    }

    pub(crate) fn script_execution_audit_path(&self) -> PathBuf {
        self.app_data_dir
            .join("audit")
            .join("script-execution.jsonl")
    }

    pub(crate) fn task_benchmarks_path(&self) -> PathBuf {
        self.app_data_dir.join("task-benchmarks.json")
    }

    pub(crate) fn routing_regression_baseline_path(&self) -> PathBuf {
        self.app_data_dir.join("task-routing-baseline.json")
    }

    pub(crate) fn trace_imports_path(&self) -> PathBuf {
        self.app_data_dir.join("trace-imports.json")
    }

    pub(crate) fn agent_session_reviews_path(&self) -> PathBuf {
        self.app_data_dir.join("agent-session-reviews.json")
    }

    pub(crate) fn llm_prompt_runs_path(&self) -> PathBuf {
        self.app_data_dir.join("prompt-runs.json")
    }

    pub(crate) fn model_task_matches_path(&self) -> PathBuf {
        self.app_data_dir.join("model-task-matches.json")
    }

    pub(crate) fn remediation_history_path(&self) -> PathBuf {
        self.app_data_dir.join("remediation-history.json")
    }

    pub(crate) fn guided_cleanup_steps_path(&self) -> PathBuf {
        self.app_data_dir.join("guided-cleanup-steps.json")
    }

    pub(crate) fn load_task_benchmarks(&self) -> Result<Vec<TaskBenchmarkRecord>, ServiceError> {
        let path = self.task_benchmarks_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut benchmarks: Vec<TaskBenchmarkRecord> = serde_json::from_str(&content)?;
        benchmarks.sort_by(|left, right| {
            left.title
                .cmp(&right.title)
                .then_with(|| left.id.cmp(&right.id))
        });
        Ok(benchmarks)
    }

    pub(crate) fn save_task_benchmarks(
        &self,
        benchmarks: &[TaskBenchmarkRecord],
    ) -> Result<(), ServiceError> {
        let path = self.task_benchmarks_path();
        let content = serde_json::to_string_pretty(benchmarks)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_routing_regression_baseline(
        &self,
    ) -> Result<Option<RoutingRegressionBaseline>, ServiceError> {
        let path = self.routing_regression_baseline_path();
        if !path.exists() {
            return Ok(None);
        }
        let content = fs::read_to_string(path)?;
        let baseline: RoutingRegressionBaseline = serde_json::from_str(&content)?;
        Ok(Some(baseline))
    }

    pub(crate) fn save_routing_regression_baseline(
        &self,
        baseline: &RoutingRegressionBaseline,
    ) -> Result<(), ServiceError> {
        let path = self.routing_regression_baseline_path();
        let content = serde_json::to_string_pretty(baseline)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_trace_imports(&self) -> Result<Vec<TraceImportRecord>, ServiceError> {
        let path = self.trace_imports_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut imports: Vec<TraceImportRecord> = serde_json::from_str(&content)?;
        imports.sort_by(|left, right| {
            right
                .imported_at
                .cmp(&left.imported_at)
                .then_with(|| left.title.cmp(&right.title))
                .then_with(|| left.id.cmp(&right.id))
        });
        Ok(imports)
    }

    pub(crate) fn save_trace_imports(
        &self,
        imports: &[TraceImportRecord],
    ) -> Result<(), ServiceError> {
        let path = self.trace_imports_path();
        let mut sorted = imports.to_vec();
        sorted.sort_by(|left, right| {
            right
                .imported_at
                .cmp(&left.imported_at)
                .then_with(|| left.title.cmp(&right.title))
                .then_with(|| left.id.cmp(&right.id))
        });
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_agent_session_reviews(
        &self,
    ) -> Result<Vec<AgentSessionSkillReviewRecord>, ServiceError> {
        let path = self.agent_session_reviews_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut reviews: Vec<AgentSessionSkillReviewRecord> = serde_json::from_str(&content)?;
        reviews.sort_by(agent_session_review_record_sort);
        Ok(reviews)
    }

    pub(crate) fn save_agent_session_reviews(
        &self,
        reviews: &[AgentSessionSkillReviewRecord],
    ) -> Result<(), ServiceError> {
        let path = self.agent_session_reviews_path();
        let mut sorted = reviews.to_vec();
        sorted.sort_by(agent_session_review_record_sort);
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_llm_prompt_runs(&self) -> Result<Vec<LlmPromptRunRecord>, ServiceError> {
        let path = self.llm_prompt_runs_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut runs: Vec<LlmPromptRunRecord> = serde_json::from_str(&content)?;
        runs.sort_by(llm_prompt_run_record_sort);
        Ok(runs)
    }

    pub(crate) fn load_model_task_matches(
        &self,
    ) -> Result<Vec<ModelTaskMatchRecord>, ServiceError> {
        let path = self.model_task_matches_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut records: Vec<ModelTaskMatchRecord> = serde_json::from_str(&content)?;
        records.sort_by(model_task_match_record_sort);
        Ok(records)
    }

    pub(crate) fn save_model_task_matches(
        &self,
        records: &[ModelTaskMatchRecord],
    ) -> Result<(), ServiceError> {
        let path = self.model_task_matches_path();
        let mut sorted = records.to_vec();
        sorted.sort_by(model_task_match_record_sort);
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_llm_prompt_runs_for_observability(
        &self,
        redaction_roots: &[(String, &'static str)],
    ) -> (
        Vec<LlmPromptRunRecord>,
        Vec<LlmProviderObservabilityStatusRow>,
    ) {
        let path = self.llm_prompt_runs_path();
        if !path.exists() {
            return (
                Vec::new(),
                vec![provider_observability_status_row(
                    "file:prompt-runs",
                    "prompt-runs.json",
                    "absent",
                    "info",
                    "No app-local prompt run history file exists yet.",
                    0,
                    vec!["app-data:prompt-runs.json".to_string()],
                )],
            );
        }
        let content = match fs::read_to_string(&path) {
            Ok(content) => content,
            Err(error) => {
                return (
                    Vec::new(),
                    vec![provider_observability_status_row(
                        "file:prompt-runs",
                        "prompt-runs.json",
                        "read_error",
                        "warning",
                        format!(
                            "Could not read app-local prompt run history: {}",
                            observability_redact(&error.to_string(), redaction_roots, 300)
                        ),
                        0,
                        vec!["app-data:prompt-runs.json".to_string()],
                    )],
                );
            }
        };
        match serde_json::from_str::<Vec<LlmPromptRunRecord>>(&content) {
            Ok(mut runs) => {
                runs.sort_by(llm_prompt_run_record_sort);
                let count = runs.len();
                (
                    runs,
                    vec![provider_observability_status_row(
                        "file:prompt-runs",
                        "prompt-runs.json",
                        "loaded",
                        "info",
                        format!("Loaded {count} app-local prompt run metadata record(s)."),
                        count,
                        vec!["app-data:prompt-runs.json".to_string()],
                    )],
                )
            }
            Err(error) => (
                Vec::new(),
                vec![provider_observability_status_row(
                    "file:prompt-runs",
                    "prompt-runs.json",
                    "parse_error",
                    "warning",
                    format!(
                        "Could not parse app-local prompt run history: {}",
                        observability_redact(&error.to_string(), redaction_roots, 300)
                    ),
                    0,
                    vec!["app-data:prompt-runs.json".to_string()],
                )],
            ),
        }
    }

    pub(crate) fn load_provider_call_metadata_for_observability(
        &self,
        redaction_roots: &[(String, &'static str)],
    ) -> (
        Vec<ProviderCallMetadata>,
        Vec<LlmProviderObservabilityStatusRow>,
    ) {
        let path = provider_call_metadata_path(&self.app_data_dir);
        if !path.exists() {
            return (
                Vec::new(),
                vec![provider_observability_status_row(
                    "file:provider-call-metadata",
                    "provider-call-metadata.jsonl",
                    "absent",
                    "info",
                    "No app-local provider call metadata file exists yet.",
                    0,
                    vec!["app-data:llm/provider-call-metadata.jsonl".to_string()],
                )],
            );
        }
        let content = match fs::read_to_string(&path) {
            Ok(content) => content,
            Err(error) => {
                return (
                    Vec::new(),
                    vec![provider_observability_status_row(
                        "file:provider-call-metadata",
                        "provider-call-metadata.jsonl",
                        "read_error",
                        "warning",
                        format!(
                            "Could not read app-local provider call metadata: {}",
                            observability_redact(&error.to_string(), redaction_roots, 300)
                        ),
                        0,
                        vec!["app-data:llm/provider-call-metadata.jsonl".to_string()],
                    )],
                );
            }
        };
        let mut rows = Vec::new();
        let mut parse_error_count = 0usize;
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            match serde_json::from_str::<ProviderCallMetadata>(trimmed) {
                Ok(metadata) => rows.push(metadata),
                Err(_) => {
                    parse_error_count += 1;
                }
            }
        }
        rows.sort_by(|left, right| {
            right
                .timestamp
                .cmp(&left.timestamp)
                .then_with(|| left.profile_id.cmp(&right.profile_id))
                .then_with(|| left.action_type.cmp(&right.action_type))
        });
        let mut status_rows = vec![provider_observability_status_row(
            "file:provider-call-metadata",
            "provider-call-metadata.jsonl",
            "loaded",
            "info",
            format!(
                "Loaded {} app-local provider call metadata record(s).",
                rows.len()
            ),
            rows.len(),
            vec!["app-data:llm/provider-call-metadata.jsonl".to_string()],
        )];
        if parse_error_count > 0 {
            status_rows.push(provider_observability_status_row(
                "file:provider-call-metadata:parse-errors",
                "provider-call-metadata.jsonl",
                "parse_error",
                "warning",
                format!("Skipped {parse_error_count} malformed provider call metadata line(s)."),
                parse_error_count,
                vec!["app-data:llm/provider-call-metadata.jsonl".to_string()],
            ));
        }
        (rows, status_rows)
    }

    pub(crate) fn load_provider_profiles_for_observability(
        &self,
        redaction_roots: &[(String, &'static str)],
    ) -> (
        Vec<ProviderProfileRecord>,
        Vec<LlmProviderObservabilityStatusRow>,
    ) {
        let path = provider_profiles_path(&self.app_data_dir);
        match list_provider_profiles(&self.app_data_dir) {
            Ok(result) => {
                let status = if path.exists() { "loaded" } else { "absent" };
                let message = if path.exists() {
                    format!(
                        "Loaded {} configured provider profile metadata record(s) without reading credentials.",
                        result.profiles.len()
                    )
                } else {
                    "No provider profile metadata file exists yet.".to_string()
                };
                let count = result.profiles.len();
                (
                    result.profiles,
                    vec![provider_observability_status_row(
                        "file:provider-profiles",
                        "provider-profiles.json",
                        status,
                        "info",
                        message,
                        count,
                        vec!["app-data:llm/provider-profiles.json".to_string()],
                    )],
                )
            }
            Err(error) => (
                Vec::new(),
                vec![provider_observability_status_row(
                    "file:provider-profiles",
                    "provider-profiles.json",
                    "parse_error",
                    "warning",
                    format!(
                        "Could not read provider profile metadata without credential access: {}",
                        observability_redact(&error.to_string(), redaction_roots, 300)
                    ),
                    0,
                    vec!["app-data:llm/provider-profiles.json".to_string()],
                )],
            ),
        }
    }

    pub(crate) fn save_llm_prompt_runs(
        &self,
        runs: &[LlmPromptRunRecord],
    ) -> Result<(), ServiceError> {
        let path = self.llm_prompt_runs_path();
        let mut sorted = runs.to_vec();
        sorted.sort_by(llm_prompt_run_record_sort);
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn record_llm_prompt_run(
        &self,
        params: &LlmConfirmPromptAndSendParams,
        preview: &LlmPreviewPromptResult,
        send: &provider::SendProviderPromptResult,
    ) -> Result<(), ServiceError> {
        let adapter_ctx = self.effective_adapter_ctx()?;
        let roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&roots);
        let task = params
            .request
            .user_intent
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| truncate_chars(&redactor.redact(value), 500));
        let error_message = send
            .error_message
            .as_deref()
            .map(|value| truncate_chars(&redactor.redact(value), 500));
        let draft_output = send
            .output_text
            .as_deref()
            .map(|value| truncate_chars(&redactor.redact(value), 12_000));
        let request_redaction = redactor.summary();
        let completed_at = unix_timestamp_millis();
        let estimated_total_tokens = preview
            .estimated_input_tokens
            .saturating_add(preview.estimated_output_tokens);
        let mut instance_ids = params.request.instance_ids.clone();
        if let Some(instance_id) = params.request.skill_instance_id.as_deref() {
            if !instance_id.trim().is_empty() && !instance_ids.iter().any(|id| id == instance_id) {
                instance_ids.push(instance_id.to_string());
            }
        }
        instance_ids = normalize_string_list(instance_ids);

        let record = LlmPromptRunRecord {
            id: generated_llm_prompt_run_id(
                &params.preview_id,
                &params.confirmation_id,
                completed_at,
            ),
            preview_id: params.preview_id.clone(),
            confirmation_id: params.confirmation_id.clone(),
            action: params.request.action.as_str().to_string(),
            request_kind: params.request.action.as_str().to_string(),
            analysis_kind: params
                .request
                .analysis_kind
                .map(|kind| kind.as_str().to_string()),
            scope: inferred_llm_prompt_scope(&params.request),
            instance_id: params
                .request
                .skill_instance_id
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned),
            instance_ids,
            definition_id: None,
            agent: None,
            task,
            profile_id: send.profile_id.clone(),
            provider: send.provider_type.as_str().to_string(),
            model: send.model.clone(),
            destination_host: send.destination_host.clone(),
            status: send.status.clone(),
            error_code: send.error_code.clone(),
            error_message,
            duration_ms: u64::try_from(send.duration_ms).unwrap_or(u64::MAX),
            estimated_input_tokens: preview.estimated_input_tokens,
            estimated_output_tokens: preview.estimated_output_tokens,
            estimated_total_tokens,
            estimated_cost_usd: preview.estimated_cost_usd,
            draft_output,
            draft_requires_user_copy: true,
            provider_request_sent: send.provider_request_sent,
            credential_accessed: send.credential_accessed,
            raw_secret_returned: false,
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            redaction_summary: llm_prompt_run_redaction_summary_from(
                preview.redaction.clone(),
                request_redaction,
            ),
            created_at: completed_at,
            completed_at,
            safety_flags: llm_prompt_run_safety_flags(
                send.provider_request_sent,
                send.credential_accessed,
            ),
        };

        let mut runs = self.load_llm_prompt_runs()?;
        runs.push(record);
        self.save_llm_prompt_runs(&runs)?;
        Ok(())
    }

    pub(crate) fn load_remediation_history(
        &self,
    ) -> Result<Vec<RemediationHistoryRecord>, ServiceError> {
        let path = self.remediation_history_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut records: Vec<RemediationHistoryRecord> = serde_json::from_str(&content)?;
        records.sort_by(remediation_history_record_sort);
        Ok(records)
    }

    pub(crate) fn save_remediation_history(
        &self,
        records: &[RemediationHistoryRecord],
    ) -> Result<(), ServiceError> {
        let path = self.remediation_history_path();
        let mut sorted = records.to_vec();
        sorted.sort_by(remediation_history_record_sort);
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn load_guided_cleanup_steps(
        &self,
    ) -> Result<Vec<GuidedCleanupStepRecord>, ServiceError> {
        let path = self.guided_cleanup_steps_path();
        if !path.exists() {
            return Ok(Vec::new());
        }
        let content = fs::read_to_string(path)?;
        let mut records: Vec<GuidedCleanupStepRecord> = serde_json::from_str(&content)?;
        records.sort_by(guided_cleanup_record_sort);
        Ok(records)
    }

    pub(crate) fn save_guided_cleanup_steps(
        &self,
        records: &[GuidedCleanupStepRecord],
    ) -> Result<(), ServiceError> {
        let path = self.guided_cleanup_steps_path();
        let mut sorted = records.to_vec();
        sorted.sort_by(guided_cleanup_record_sort);
        let content = serde_json::to_string_pretty(&sorted)?;
        write_private_text_file(&path, &content)?;
        Ok(())
    }

    pub(crate) fn trace_redaction_roots(
        &self,
        adapter_ctx: &AdapterContext,
    ) -> Vec<(String, &'static str)> {
        let mut roots = self.redaction_roots(adapter_ctx);
        roots.push((env::temp_dir().to_string_lossy().to_string(), "<temp-dir>"));
        roots.sort_by_key(|right| std::cmp::Reverse(right.0.len()));
        roots.dedup_by(|left, right| left.0 == right.0);
        roots
    }

    pub(crate) fn analyze_imported_trace(
        &self,
        content: &str,
        expected_skill_refs: &[String],
        expected_skill_names: &[String],
        agent_filter: Option<&str>,
    ) -> Result<TraceImportAnalysis, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            let mut reasons = vec![
                "No local catalog is available; imported trace was stored as redacted app-local metadata only."
                    .to_string(),
            ];
            if !expected_skill_refs.is_empty() || !expected_skill_names.is_empty() {
                reasons.push(
                    "Expected skill refs/names were provided but could not be checked without catalog evidence."
                        .to_string(),
                );
            }
            return Ok(TraceImportAnalysis {
                generated_by: "deterministic-service".to_string(),
                catalog_available: false,
                outcome: "unknown".to_string(),
                reasons,
                detected_skills: Vec::new(),
                evidence_refs: Vec::new(),
            });
        };

        let content_lower = content.to_ascii_lowercase();
        let expected_refs = expected_skill_refs
            .iter()
            .map(|value| value.to_ascii_lowercase())
            .collect::<Vec<_>>();
        let expected_names = expected_skill_names
            .iter()
            .map(|value| value.to_ascii_lowercase())
            .collect::<Vec<_>>();
        let mut detected = Vec::new();
        for skill in self.list_visible_skill_records(&catalog)? {
            if agent_filter.is_some_and(|agent| !agent.is_empty() && skill.agent != agent) {
                continue;
            }
            let mut match_terms = Vec::new();
            for term in [
                skill.id.as_str(),
                skill.definition_id.as_str(),
                skill.name.as_str(),
            ] {
                let normalized = term.trim();
                if normalized.len() < 3 {
                    continue;
                }
                let normalized_lower = normalized.to_ascii_lowercase();
                if content_lower.contains(&normalized_lower)
                    && !match_terms.iter().any(|item| item == normalized)
                {
                    match_terms.push(normalized.to_string());
                }
            }
            if !match_terms.is_empty() {
                detected.push(TraceDetectedSkill {
                    instance_id: skill.id.clone(),
                    definition_id: skill.definition_id.clone(),
                    skill_name: skill.name.clone(),
                    agent: skill.agent.clone(),
                    scope: skill.scope.clone(),
                    evidence_refs: vec![format!("skill:{}", skill.id)],
                    match_terms,
                });
            }
        }
        detected.sort_by(|left, right| {
            left.agent
                .cmp(&right.agent)
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });

        let expected_present = !expected_refs.is_empty() || !expected_names.is_empty();
        let matching_expected = detected
            .iter()
            .filter(|skill| {
                expected_refs.iter().any(|expected| {
                    expected == &skill.instance_id.to_ascii_lowercase()
                        || expected == &skill.definition_id.to_ascii_lowercase()
                }) || expected_names
                    .iter()
                    .any(|expected| expected == &skill.skill_name.to_ascii_lowercase())
            })
            .count();
        let unexpected_detected = detected.len().saturating_sub(matching_expected);
        let outcome = if !expected_present {
            if detected.len() > 1 {
                "ambiguous"
            } else {
                "unknown"
            }
        } else if detected.is_empty() {
            "miss"
        } else if matching_expected == 0 {
            "wrong_pick"
        } else if unexpected_detected > 0 {
            "ambiguous"
        } else {
            "hit"
        };
        let reasons = trace_outcome_reasons(
            outcome,
            detected.len(),
            matching_expected,
            unexpected_detected,
            expected_present,
            agent_filter,
        );
        let mut evidence_refs = detected
            .iter()
            .flat_map(|skill| skill.evidence_refs.clone())
            .collect::<Vec<_>>();
        evidence_refs.sort();
        evidence_refs.dedup();
        Ok(TraceImportAnalysis {
            generated_by: "deterministic-service".to_string(),
            catalog_available: true,
            outcome: outcome.to_string(),
            reasons,
            detected_skills: detected,
            evidence_refs,
        })
    }

    pub(crate) fn analyze_agent_session_skill_use(
        &self,
        content: &str,
        expected_skill_refs: &[String],
        expected_skill_names: &[String],
        agent_filter: Option<&str>,
        referenced_imports: &[TraceImportRecord],
        missing_trace_import_ids: &[String],
    ) -> Result<AgentSessionSkillReviewAnalysis, ServiceError> {
        let trace_analysis = self.analyze_imported_trace(
            content,
            expected_skill_refs,
            expected_skill_names,
            agent_filter,
        )?;
        let mut detected = trace_analysis.detected_skills;
        for import in referenced_imports {
            detected.extend(import.analysis.detected_skills.clone());
        }
        detected.sort_by(|left, right| {
            left.agent
                .cmp(&right.agent)
                .then_with(|| left.skill_name.cmp(&right.skill_name))
                .then_with(|| left.instance_id.cmp(&right.instance_id))
        });
        detected.dedup_by(|left, right| {
            left.instance_id == right.instance_id && left.definition_id == right.definition_id
        });

        let catalog_available = trace_analysis.catalog_available
            || referenced_imports
                .iter()
                .any(|import| import.analysis.catalog_available);
        let expected_present = !expected_skill_refs.is_empty() || !expected_skill_names.is_empty();
        let matching_expected = detected
            .iter()
            .filter(|skill| {
                expected_skill_refs.iter().any(|expected| {
                    skill.instance_id.eq_ignore_ascii_case(expected)
                        || skill.definition_id.eq_ignore_ascii_case(expected)
                }) || expected_skill_names
                    .iter()
                    .any(|expected| skill.skill_name.eq_ignore_ascii_case(expected))
            })
            .count();
        let unexpected_detected = detected.len().saturating_sub(matching_expected);
        let outcome = if !catalog_available {
            "unknown"
        } else if !expected_present {
            if detected.len() > 1 {
                "ambiguous"
            } else {
                "unknown"
            }
        } else if detected.is_empty() {
            "miss"
        } else if matching_expected == 0 {
            "wrong_pick"
        } else if unexpected_detected > 0 {
            "ambiguous"
        } else {
            "hit"
        };

        let mut reasons = trace_outcome_reasons(
            outcome,
            detected.len(),
            matching_expected,
            unexpected_detected,
            expected_present,
            agent_filter,
        );
        if referenced_imports.is_empty() {
            reasons.push("Review used pasted session transcript text only.".to_string());
        } else {
            reasons.push(format!(
                "Review reused {} app-local trace import reference(s); only their redacted excerpts and deterministic analysis were read.",
                referenced_imports.len()
            ));
        }
        if !missing_trace_import_ids.is_empty() {
            reasons.push(format!(
                "{} requested trace import reference(s) were not found in app-local history.",
                missing_trace_import_ids.len()
            ));
        }
        reasons.sort();
        reasons.dedup();

        let mut evidence_refs = detected
            .iter()
            .flat_map(|skill| skill.evidence_refs.clone())
            .collect::<Vec<_>>();
        evidence_refs.extend(
            referenced_imports
                .iter()
                .map(|import| format!("trace-import:{}", import.id)),
        );
        evidence_refs.extend(
            referenced_imports
                .iter()
                .flat_map(|import| import.analysis.evidence_refs.clone()),
        );
        evidence_refs.sort();
        evidence_refs.dedup();

        let expected_skill_signals = agent_session_expected_skill_signals(
            expected_skill_refs,
            expected_skill_names,
            &detected,
        );
        let referenced_traces = referenced_imports
            .iter()
            .map(|import| AgentSessionReferencedTrace {
                id: import.id.clone(),
                title: import.title.clone(),
                outcome: import.analysis.outcome.clone(),
                imported_at: import.imported_at,
                detected_skill_count: import.analysis.detected_skills.len(),
                evidence_refs: import.analysis.evidence_refs.clone(),
            })
            .collect::<Vec<_>>();

        Ok(AgentSessionSkillReviewAnalysis {
            generated_by: "deterministic-service".to_string(),
            catalog_available,
            outcome: outcome.to_string(),
            summary: agent_session_review_summary(
                outcome,
                detected.len(),
                expected_skill_signals.len(),
                referenced_traces.len(),
                missing_trace_import_ids.len(),
            ),
            reasons,
            detected_skills: detected,
            expected_skill_signals,
            referenced_traces,
            evidence_refs,
        })
    }

    pub(crate) fn tool_global_staging_root(&self) -> PathBuf {
        self.app_data_dir.join("tool-global")
    }

    pub(crate) fn redaction_roots(
        &self,
        adapter_ctx: &AdapterContext,
    ) -> Vec<(String, &'static str)> {
        fn push_root(
            roots: &mut Vec<(String, &'static str)>,
            path: &Path,
            placeholder: &'static str,
        ) {
            roots.push((path.to_string_lossy().to_string(), placeholder));
            if let Ok(canonical) = path.canonicalize() {
                roots.push((canonical.to_string_lossy().to_string(), placeholder));
            }
        }

        let mut roots = Vec::new();
        push_root(&mut roots, &self.app_data_dir, "<app-data-dir>");
        push_root(&mut roots, &adapter_ctx.user_home, "$HOME");
        if let Some(project_root) = adapter_ctx.project_root.as_ref() {
            push_root(&mut roots, project_root, "<project-root>");
        }
        if let Some(project_cwd) = adapter_ctx.project_cwd.as_ref() {
            push_root(&mut roots, project_cwd, "<project-cwd>");
        }
        roots.sort_by_key(|right| std::cmp::Reverse(right.0.len()));
        roots.dedup_by(|left, right| left.0 == right.0);
        roots
    }

    pub(crate) fn effective_adapter_ctx(&self) -> Result<AdapterContext, ServiceError> {
        if self.has_env_project_context() {
            return Ok(self.adapter_ctx.clone());
        }

        let Some((root_path, current_cwd)) = stored_active_adapter_paths(&self.app_data_dir)?
        else {
            return Ok(self.adapter_ctx.clone());
        };

        let mut ctx = self.adapter_ctx.clone();
        ctx.project_root = Some(root_path);
        ctx.project_cwd = Some(current_cwd);
        Ok(ctx)
    }

    pub(crate) fn has_env_project_context(&self) -> bool {
        self.adapter_ctx.project_root.is_some() || self.adapter_ctx.project_cwd.is_some()
    }

    pub(crate) fn env_project_context(&self) -> Option<ProjectContext> {
        let root = self.adapter_ctx.project_root.as_ref()?;
        let cwd = self.adapter_ctx.project_cwd.as_deref().unwrap_or(root);
        Some(context_from_paths(root, cwd, true))
    }

    pub(crate) fn status_adapter_ctx(&self) -> AdapterContext {
        self.effective_adapter_ctx()
            .unwrap_or_else(|_| self.adapter_ctx.clone())
    }

    pub(crate) fn scan_activity(
        &self,
        operation: &'static str,
        scan_label: &str,
        roots: Vec<PathBuf>,
        started_at: i64,
        counts: ScanActivityCounts,
        agent_summaries: Option<Vec<AgentRefreshSummary>>,
    ) -> RefreshActivity {
        let roots_count = roots.len();
        let mut log_entries = vec![
            RefreshLogEntry {
                level: "info",
                message: format!("Queued {scan_label} scan across {roots_count} root(s)."),
            },
            RefreshLogEntry {
                level: "info",
                message: format!(
                    "Catalog refresh completed with {} skill(s), {} finding(s), and {} conflict group(s).",
                    counts.skill_count, counts.finding_count, counts.conflict_count
                ),
            },
        ];
        if counts.scanned_count == 0 {
            log_entries.push(RefreshLogEntry {
                level: "warning",
                message: format!(
                    "No skills were discovered for {scan_label}. Check the configured roots, then retry Scan."
                ),
            });
        }
        if let Some(summaries) = &agent_summaries {
            log_entries.extend(summaries.iter().map(|summary| {
                let level = if summary.roots_scanned.is_empty() {
                    "warning"
                } else {
                    "info"
                };
                let skipped_detail = skipped_roots_detail(&summary.roots_skipped);
                RefreshLogEntry {
                    level,
                    message: format!(
                        "{} discovered {} skill(s); catalog now has {} skill(s), {} broken, across {} scanned root(s) and {} skipped root(s){}.",
                        summary.display_label,
                        summary.scanned_count,
                        summary.catalog_count,
                        summary.broken_count,
                        summary.roots_scanned.len(),
                        summary.roots_skipped.len(),
                        skipped_detail
                    ),
                }
            }));
        }

        RefreshActivity {
            operation,
            status: "completed",
            started_at,
            finished_at: unix_timestamp_millis(),
            scanned_count: counts.scanned_count,
            skill_count: counts.skill_count,
            finding_count: counts.finding_count,
            conflict_count: counts.conflict_count,
            snapshot_count: counts.snapshot_count,
            roots: roots.into_iter().map(|path| display_path(&path)).collect(),
            log_entries,
            recovery_actions: vec![
                "Retry Scan if the catalog looks stale.".to_string(),
                "Use Reload to re-read the current catalog without touching agent files."
                    .to_string(),
            ],
            agent_summaries,
        }
    }

    pub(crate) fn agent_refresh_summaries(
        &self,
        agent_reports: &[AgentCatalogScanReport],
        skills: &[SkillRecord],
        adapter_diagnostics: &[AdapterDiagnosticsRecord],
    ) -> Vec<AgentRefreshSummary> {
        agent_reports
            .iter()
            .map(|agent_report| {
                let agent = agent_report.agent.as_str();
                let diagnostics = adapter_diagnostics
                    .iter()
                    .find(|diagnostics| diagnostics.agent == agent);
                let catalog_count = skills.iter().filter(|skill| skill.agent == agent).count();
                let broken_count = skills
                    .iter()
                    .filter(|skill| skill.agent == agent && skill.state == "broken")
                    .count();
                let recovery_actions = if agent_report.scanned_roots.is_empty() {
                    vec![format!(
                        "Create a {} skills root or check skipped-root permissions, then retry Scan.",
                        agent_report.display_name
                    )]
                } else {
                    Vec::new()
                };
                AgentRefreshSummary {
                    agent: agent.to_string(),
                    display_label: agent_report.display_name.to_string(),
                    status: if agent_report.scanned_roots.is_empty() {
                        "completed-no-roots-scanned"
                    } else {
                        "completed"
                    },
                    scanned_count: agent_report.scanned_count,
                    catalog_count,
                    broken_count,
                    roots_considered: agent_report
                        .roots_considered
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    roots_scanned: agent_report
                        .scanned_roots
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    roots_skipped: agent_report
                        .skipped_roots
                        .iter()
                        .map(|path| display_path(path))
                        .collect(),
                    config_detected: diagnostics
                        .is_some_and(|diagnostics| diagnostics.config.detected_count > 0),
                    config_paths: diagnostics
                        .map(|diagnostics| {
                            diagnostics
                                .config
                                .paths
                                .iter()
                                .map(|path| path.path.clone())
                                .collect()
                        })
                        .unwrap_or_default(),
                    writable_status: diagnostics
                        .map(|diagnostics| diagnostics.access.writable_status.to_string())
                        .unwrap_or_else(|| "unknown".to_string()),
                    writable_reason: diagnostics
                        .and_then(|diagnostics| diagnostics.access.writable_reason)
                        .map(str::to_string),
                    read_only_reason: diagnostics
                        .map(|diagnostics| diagnostics.access.read_only_reason.clone())
                        .unwrap_or_else(|| "Adapter diagnostics were unavailable.".to_string()),
                    blockers: diagnostics
                        .map(|diagnostics| {
                            diagnostics
                                .blockers
                                .iter()
                                .map(|blocker| (*blocker).to_string())
                                .collect()
                        })
                        .unwrap_or_default(),
                    recovery_actions,
                }
            })
            .collect()
    }

    pub(crate) fn claude_root_paths(&self) -> Vec<PathBuf> {
        let mut roots = vec![self.adapter_ctx.user_home.join(".claude").join("skills")];
        roots.extend(
            self.adapter_ctx
                .extra_roots
                .iter()
                .map(|root| root.path.clone()),
        );
        roots
    }
}
