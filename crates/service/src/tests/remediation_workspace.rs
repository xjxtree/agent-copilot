    #[test]
    fn remediation_plan_returns_prioritized_local_read_only_items() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-plan-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .plan_remediation(RemediationPlanParams {
                agent: None,
                task: Some("Validate release readiness and privacy evidence".to_string()),
                project_root: None,
                focus: None,
                focus_areas: Vec::new(),
                limit: Some(10),
                candidate_instance_ids: Vec::new(),
                include_deferred: true,
            })
            .expect("remediation plan");

        assert_eq!(result.generated_by, "deterministic-service");
        assert!(result.catalog_available);
        assert!(!result.plan_items.is_empty());
        assert_eq!(result.summary.returned_item_count, result.plan_items.len());
        assert!(result.summary.total_item_count >= result.summary.returned_item_count);
        assert!(result.summary.finding_item_count > 0);
        assert!(result.summary.ambiguity_item_count > 0 || result.summary.drift_item_count > 0);
        assert!(!result.priority_rows.is_empty());
        assert_eq!(result.prompt_request.action, "remediation_plan");
        assert_eq!(
            result.prompt_request.request.action,
            LlmPromptActionKind::RemediationPlan
        );
        assert_agent_readiness_safety_flags(&WireAgentReadinessSafetyFlags {
            read_only: result.safety_flags.read_only,
            app_local_only: result.safety_flags.app_local_only,
            provider_request_sent: result.safety_flags.provider_request_sent,
            write_back_allowed: result.safety_flags.write_back_allowed,
            write_actions_available: result.safety_flags.write_actions_available,
            skill_files_mutated: result.safety_flags.skill_files_mutated,
            agent_config_mutated: result.safety_flags.agent_config_mutated,
            script_execution_allowed: result.safety_flags.script_execution_allowed,
            execution_actions_available: result.safety_flags.execution_actions_available,
            config_mutation_allowed: result.safety_flags.config_mutation_allowed,
            snapshot_created: result.safety_flags.snapshot_created,
            triage_mutation_allowed: result.safety_flags.triage_mutation_allowed,
            credential_accessed: result.safety_flags.credential_accessed,
            raw_secret_returned: result.safety_flags.raw_secret_returned,
            raw_prompt_persisted: result.safety_flags.raw_prompt_persisted,
            raw_response_persisted: result.safety_flags.raw_response_persisted,
            raw_trace_persisted: result.safety_flags.raw_trace_persisted,
            cloud_sync_performed: result.safety_flags.cloud_sync_performed,
            telemetry_emitted: result.safety_flags.telemetry_emitted,
        });
        assert!(result.plan_items.iter().all(|item| {
            item.rank > 0
                && item.safety_flags.read_only
                && !item.safety_flags.provider_request_sent
                && !item.safety_flags.write_back_allowed
                && item
                    .side_effect_flags
                    .contains(&"skill_files_mutated=false")
        }));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_plan_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let result = host
            .plan_remediation(RemediationPlanParams::default())
            .expect("empty remediation plan");

        assert!(!result.catalog_available);
        assert_eq!(result.summary.returned_item_count, 0);
        assert!(result.plan_items.is_empty());
        assert!(!result.prompt_request.available);
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.script_execution_allowed);
        assert!(!result.safety_flags.credential_accessed);
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_plan_bounds_large_detail_scan_with_metadata() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-bounded-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_many_task_skills(&host, 90);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .plan_remediation(RemediationPlanParams {
                agent: Some("codex".to_string()),
                task: Some("Validate release readiness privacy evidence".to_string()),
                project_root: None,
                focus: None,
                focus_areas: Vec::new(),
                limit: Some(4),
                candidate_instance_ids: Vec::new(),
                include_deferred: true,
            })
            .expect("bounded remediation plan");

        assert_eq!(result.aggregation.status, "partial");
        assert!(result.aggregation.partial);
        assert!(result.aggregation.scanned_count < result.aggregation.total_count);
        assert!(result
            .aggregation
            .skipped_stages
            .contains(&"detail-scan-overflow"));
        assert!(result.plan_items.len() <= 4);
        assert!(result.safety_flags.read_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_plan_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("remediation-invalid".to_string()),
            method: "remediation.plan".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid remediation error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid remediation request must not initialize app data"
        );
    }

    #[test]
    fn remediation_plan_preserves_provider_write_and_privacy_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-safety-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-remediation-safety-home-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("remediation-safety".to_string()),
            method: "remediation.plan".to_string(),
            params: json!({
                "task_text": "release readiness token=fixture-redacted-value",
                "focus_areas": ["finding", "drift", "ambiguity"],
                "candidate_instance_ids": ["similar-claude-a", "similar-codex-a"],
                "limit": 8
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("remediation safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_actions_available")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize remediation result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn remediation_plan_prompt_preview_is_redacted_and_preview_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-prompt-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("remediation-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "remediation_plan",
                "user_intent": "Plan local remediation for /tmp/home/private-project with secret-token=fixture-redacted-value",
                "instance_ids": ["similar-claude-a", "similar-codex-a"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let preview: WireLlmPreviewPromptResult =
            serde_json::from_value(response.result.expect("preview result"))
                .expect("decode remediation prompt preview");
        assert_eq!(preview.action, "remediation_plan");
        assert!(preview.prompt_preview.contains("Remediation plan evidence"));
        assert!(!preview.prompt_preview.contains("fixture-redacted-value"));
        assert!(!preview.provider_request_sent);
        assert!(!preview.write_back_allowed);
        assert!(preview.draft_requires_user_copy);
        assert!(!preview.raw_prompt_persisted);
        assert!(!preview.raw_response_persisted);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_drafts_returns_copy_only_local_drafts() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_preview_draft_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .preview_remediation_drafts(RemediationPreviewDraftsParams {
                agent: None,
                task: Some("Draft release readiness fixes".to_string()),
                skill_ids: Vec::new(),
                finding_ids: Vec::new(),
                draft_types: Vec::new(),
                limit: Some(10),
                include_policy_drafts: true,
            })
            .expect("preview drafts");

        assert_eq!(result.generated_by, "local-v2.57");
        assert!(result.catalog_available);
        assert_eq!(
            result.summary.returned_draft_count,
            result.draft_items.len()
        );
        assert!(result.summary.frontmatter_count > 0);
        assert!(result.summary.description_count > 0);
        assert!(result.summary.permissions_count > 0);
        assert!(result.summary.dependency_count > 0);
        assert!(result.summary.policy_count > 0);
        assert_eq!(result.prompt_request.action, "remediation_preview_drafts");
        assert_eq!(
            result.prompt_request.request.action,
            LlmPromptActionKind::RemediationPreviewDrafts
        );
        assert!(result.safety_flags.read_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(result.draft_items.iter().all(|item| {
            item.rank > 0
                && !item.proposed_text.is_empty()
                && item.patch_like_snippet.contains("Copy-only")
                && item.safety_flags.read_only
                && !item.safety_flags.write_back_allowed
                && item.side_effect_flags.contains(&"write_back_allowed=false")
        }));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_drafts_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let result = host
            .preview_remediation_drafts(RemediationPreviewDraftsParams::default())
            .expect("empty draft preview");

        assert!(!result.catalog_available);
        assert_eq!(result.summary.returned_draft_count, 0);
        assert!(result.draft_items.is_empty());
        assert!(!result.prompt_request.available);
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.script_execution_allowed);
        assert!(!result.safety_flags.credential_accessed);
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_drafts_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("remediation-drafts-invalid".to_string()),
            method: "remediation.previewDrafts".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid draft preview error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid draft preview request must not initialize app data"
        );
    }

    #[test]
    fn remediation_preview_drafts_preserves_provider_write_and_privacy_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-safety-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-safety-home-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_preview_draft_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("remediation-drafts-safety".to_string()),
            method: "remediation.previewDrafts".to_string(),
            params: json!({
                "task_text": "draft fixes token=fixture-redacted-value",
                "skill_ids": ["similar-claude-a", "similar-codex-a", "similar-codex-research"],
                "draft_types": ["frontmatter", "permissions", "dependency", "policy"],
                "limit": 8,
                "include_policy_drafts": true
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("draft preview safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_actions_available")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize draft preview result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn remediation_preview_drafts_prompt_preview_is_redacted_and_copy_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-drafts-prompt-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_preview_draft_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("remediation-drafts-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "remediation_preview_drafts",
                "user_intent": "Explain drafts for /tmp/home/private-project with secret-token=fixture-redacted-value",
                "instance_ids": ["similar-claude-a", "similar-codex-a"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let preview: WireLlmPreviewPromptResult =
            serde_json::from_value(response.result.expect("preview result"))
                .expect("decode remediation draft prompt preview");
        assert_eq!(preview.action, "remediation_preview_drafts");
        assert!(preview
            .prompt_preview
            .contains("Fix preview draft evidence"));
        assert!(!preview.prompt_preview.contains("fixture-redacted-value"));
        assert!(!preview.provider_request_sent);
        assert!(!preview.write_back_allowed);
        assert!(preview.draft_requires_user_copy);
        assert!(!preview.raw_prompt_persisted);
        assert!(!preview.raw_response_persisted);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_impact_returns_local_read_only_rows() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .preview_remediation_impact(RemediationPreviewImpactParams {
                action: Some("remediate".to_string()),
                task: Some("Validate release readiness and privacy evidence".to_string()),
                agent: None,
                project_root: None,
                skill_ids: Vec::new(),
                candidate_instance_ids: vec![
                    "similar-claude-a".to_string(),
                    "similar-codex-a".to_string(),
                ],
                draft_ids: Vec::new(),
                plan_item_ids: Vec::new(),
                limit: Some(8),
                include_snapshot_plan: true,
                include_rollback_plan: true,
                include_risk_impact: true,
                include_task_impact: true,
            })
            .expect("impact preview");

        assert_eq!(result.generated_by, "local-v2.58");
        assert!(result.catalog_available);
        assert_eq!(
            result.summary.returned_impact_count,
            result.impact_rows.len()
        );
        assert!(!result.impact_rows.is_empty());
        assert!(!result.skill_impact_rows.is_empty());
        assert!(!result.agent_impact_rows.is_empty());
        assert!(!result.risk_delta_rows.is_empty());
        assert!(!result.snapshot_rollback_plan_rows.is_empty());
        assert!(result
            .snapshot_rollback_plan_rows
            .iter()
            .all(|row| row.plan_only));
        assert_eq!(result.prompt_request.action, "remediation_preview_impact");
        assert_eq!(
            result.prompt_request.request.action,
            LlmPromptActionKind::RemediationPreviewImpact
        );
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.snapshot_created);
        assert!(result.impact_rows.iter().all(|row| {
            row.rank > 0
                && row.safety_flags.read_only
                && !row.safety_flags.provider_request_sent
                && !row.safety_flags.write_back_allowed
                && row
                    .side_effect_flags
                    .contains(&"provider_request_sent=false")
                && row.side_effect_flags.contains(&"snapshot_created=false")
        }));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_impact_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let result = host
            .preview_remediation_impact(RemediationPreviewImpactParams::default())
            .expect("empty impact preview");

        assert!(!result.catalog_available);
        assert_eq!(result.summary.returned_impact_count, 0);
        assert!(result.impact_rows.is_empty());
        assert!(!result.prompt_request.available);
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.snapshot_created);
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_preview_impact_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("remediation-impact-invalid".to_string()),
            method: "remediation.previewImpact".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid impact preview error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid impact preview request must not initialize app data"
        );
    }

    #[test]
    fn remediation_preview_impact_preserves_provider_write_and_privacy_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-safety-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-safety-home-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("remediation-impact-safety".to_string()),
            method: "remediation.previewImpact".to_string(),
            params: json!({
                "action": "disable",
                "task_text": "impact token=fixture-redacted-value",
                "candidate_instance_ids": ["similar-claude-a", "similar-codex-a"],
                "limit": 8,
                "include_snapshot_plan": true,
                "include_rollback_plan": true,
                "include_risk_impact": true,
                "include_task_impact": true
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("impact preview safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/snapshot_created")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize impact preview result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn remediation_preview_impact_prompt_preview_is_redacted_and_copy_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-impact-prompt-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("remediation-impact-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "remediation_preview_impact",
                "user_intent": "Explain impact for /tmp/home/private-project with secret-token=fixture-redacted-value",
                "instance_ids": ["similar-claude-a", "similar-codex-a"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let preview: WireLlmPreviewPromptResult =
            serde_json::from_value(response.result.expect("preview result"))
                .expect("decode remediation impact prompt preview");
        assert_eq!(preview.action, "remediation_preview_impact");
        assert!(preview.prompt_preview.contains("Impact preview evidence"));
        assert!(!preview.prompt_preview.contains("fixture-redacted-value"));
        assert!(!preview.provider_request_sent);
        assert!(!preview.write_back_allowed);
        assert!(preview.draft_requires_user_copy);
        assert!(!preview.raw_prompt_persisted);
        assert!(!preview.raw_response_persisted);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_batch_review_returns_grouped_read_only_queue() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_preview_draft_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .batch_review_remediation(RemediationBatchReviewParams {
                task: Some("Review release readiness remediation batch".to_string()),
                agent: None,
                project_root: None,
                workspace_label: Some("fixture-workspace".to_string()),
                rule_id: None,
                severity: None,
                status: None,
                triage_status: None,
                candidate_instance_ids: Vec::new(),
                group_by: vec![
                    "risk".to_string(),
                    "rule".to_string(),
                    "agent".to_string(),
                    "workspace".to_string(),
                    "task".to_string(),
                ],
                limit: Some(12),
            })
            .expect("batch review");

        assert_eq!(result.generated_by, "local-v2.59");
        assert!(result.catalog_available);
        assert_eq!(
            result.summary.returned_item_count,
            result.review_items.len()
        );
        assert_eq!(result.summary.group_count, result.review_groups.len());
        assert!(!result.review_items.is_empty());
        assert!(!result.review_groups.is_empty());
        assert!(result
            .review_groups
            .iter()
            .any(|group| group.group_type == "risk"));
        assert!(result
            .review_groups
            .iter()
            .any(|group| group.group_type == "rule"));
        assert_eq!(result.prompt_request.action, "remediation_batch_review");
        assert_eq!(
            result.prompt_request.request.action,
            LlmPromptActionKind::RemediationBatchReview
        );
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.snapshot_created);
        assert!(result.review_items.iter().all(|item| {
            item.rank > 0
                && item.safety_flags.read_only
                && !item.safety_flags.provider_request_sent
                && !item.safety_flags.write_back_allowed
                && item
                    .side_effect_flags
                    .contains(&"provider_request_sent=false")
                && item.side_effect_flags.contains(&"write_back_allowed=false")
        }));

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_batch_review_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let result = host
            .batch_review_remediation(RemediationBatchReviewParams::default())
            .expect("empty batch review");

        assert!(!result.catalog_available);
        assert_eq!(result.summary.returned_item_count, 0);
        assert!(result.review_items.is_empty());
        assert!(result.review_groups.is_empty());
        assert!(!result.prompt_request.available);
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.snapshot_created);
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn remediation_batch_review_rejects_invalid_limit_without_writes() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-invalid-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let response = host.handle(ServiceRequest {
            id: Some("remediation-batch-review-invalid".to_string()),
            method: "remediation.batchReview".to_string(),
            params: json!({ "limit": 0 }),
        });

        assert!(!response.ok);
        let error = response.error.expect("invalid batch review error");
        assert_eq!(error.code, "invalid_request");
        assert!(error.message.contains("limit"));
        assert!(
            !app_data_dir.exists(),
            "invalid batch review request must not initialize app data"
        );
    }

    #[test]
    fn remediation_batch_review_preserves_provider_write_and_privacy_boundaries() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-safety-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let user_home = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-safety-home-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = ServiceHost {
            app_data_dir: app_data_dir.clone(),
            adapter_ctx: AdapterContext {
                user_home: user_home.clone(),
                project_root: None,
                project_cwd: None,
                extra_roots: Vec::new(),
            },
        };
        seed_catalog_with_preview_draft_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let response = host.handle(ServiceRequest {
            id: Some("remediation-batch-review-safety".to_string()),
            method: "remediation.batchReview".to_string(),
            params: json!({
                "task_text": "batch review token=fixture-redacted-value",
                "workspace": "fixture-workspace",
                "candidate_instance_ids": ["similar-claude-a", "similar-codex-a", "similar-codex-research"],
                "group_by": ["risk", "rule", "agent", "workspace", "task"],
                "limit": 10
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let result = response.result.expect("batch review safety result");
        assert_agent_readiness_safety(&result);
        assert_eq!(
            result
                .pointer("/safety_flags/provider_request_sent")
                .and_then(Value::as_bool),
            Some(false)
        );
        assert_eq!(
            result
                .pointer("/safety_flags/write_actions_available")
                .and_then(Value::as_bool),
            Some(false)
        );

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!host.script_execution_audit_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());
        assert!(!user_home.join(".claude/settings.json").exists());
        assert!(!user_home.join(".codex/config.toml").exists());

        let serialized = serde_json::to_string(&result).expect("serialize batch review result");
        assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
        assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
        assert!(!serialized.contains("fixture-redacted-value"));

        let _ = fs::remove_dir_all(app_data_dir);
        let _ = fs::remove_dir_all(user_home);
    }

    #[test]
    fn remediation_batch_review_prompt_preview_is_redacted_and_copy_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-remediation-batch-review-prompt-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_preview_draft_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("remediation-batch-review-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "remediation_batch_review",
                "user_intent": "Explain batch review for /tmp/home/private-project with secret-token=fixture-redacted-value",
                "instance_ids": ["similar-claude-a", "similar-codex-a"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let preview: WireLlmPreviewPromptResult =
            serde_json::from_value(response.result.expect("preview result"))
                .expect("decode batch review prompt preview");
        assert_eq!(preview.action, "remediation_batch_review");
        assert!(preview.prompt_preview.contains("Batch review evidence"));
        assert!(!preview.prompt_preview.contains("fixture-redacted-value"));
        assert!(!preview.provider_request_sent);
        assert!(!preview.write_back_allowed);
        assert!(preview.draft_requires_user_copy);
        assert!(!preview.raw_prompt_persisted);
        assert!(!preview.raw_response_persisted);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn workspace_check_readiness_returns_local_read_only_checklist() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-workspace-readiness-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);
        let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
        let before_records = before_catalog.list_skill_records().expect("records before");
        let before_findings = before_catalog
            .list_rule_findings()
            .expect("findings before");
        let before_snapshots = before_catalog
            .list_all_config_snapshots()
            .expect("snapshots before");

        let result = host
            .check_workspace_readiness(WorkspaceReadinessParams {
                agent: None,
                task: Some("Validate release readiness and privacy evidence".to_string()),
                project_root: None,
                expected_capabilities: vec![
                    "Release & Validation".to_string(),
                    "Security & Privacy".to_string(),
                ],
                limit: Some(8),
                candidate_instance_ids: Vec::new(),
            })
            .expect("workspace readiness");

        assert_eq!(result.generated_by, "deterministic-service");
        assert!(result.catalog_available);
        assert!(result.summary.workspace_available);
        assert!(result.summary.visible_skill_count >= 3);
        assert!(!result.readiness_rows.is_empty());
        assert_eq!(result.readiness_rows.len(), result.checklist_rows.len());
        assert!(result
            .readiness_rows
            .iter()
            .any(|row| row.category == "capability_coverage"));
        assert!(result
            .readiness_rows
            .iter()
            .any(|row| row.category == "routing_ambiguity"));
        assert!(!result.agent_rows.is_empty());
        assert!(!result.capability_rows.is_empty());
        assert!(result
            .capability_rows
            .iter()
            .any(|row| row.expected && row.capability == "Release & Validation"));
        assert_eq!(result.prompt_request.action, "workspace_readiness");
        assert_eq!(
            result.prompt_request.request.action,
            LlmPromptActionKind::WorkspaceReadiness
        );
        assert_agent_readiness_safety_flags(&WireAgentReadinessSafetyFlags {
            read_only: result.safety_flags.read_only,
            app_local_only: result.safety_flags.app_local_only,
            provider_request_sent: result.safety_flags.provider_request_sent,
            write_back_allowed: result.safety_flags.write_back_allowed,
            write_actions_available: result.safety_flags.write_actions_available,
            skill_files_mutated: result.safety_flags.skill_files_mutated,
            agent_config_mutated: result.safety_flags.agent_config_mutated,
            script_execution_allowed: result.safety_flags.script_execution_allowed,
            execution_actions_available: result.safety_flags.execution_actions_available,
            config_mutation_allowed: result.safety_flags.config_mutation_allowed,
            snapshot_created: result.safety_flags.snapshot_created,
            triage_mutation_allowed: result.safety_flags.triage_mutation_allowed,
            credential_accessed: result.safety_flags.credential_accessed,
            raw_secret_returned: result.safety_flags.raw_secret_returned,
            raw_prompt_persisted: result.safety_flags.raw_prompt_persisted,
            raw_response_persisted: result.safety_flags.raw_response_persisted,
            raw_trace_persisted: result.safety_flags.raw_trace_persisted,
            cloud_sync_performed: result.safety_flags.cloud_sync_performed,
            telemetry_emitted: result.safety_flags.telemetry_emitted,
        });

        let after_catalog = Catalog::open(&host.catalog_path()).expect("open catalog after");
        assert_eq!(
            after_catalog.list_skill_records().expect("records after"),
            before_records
        );
        assert_eq!(
            after_catalog.list_rule_findings().expect("findings after"),
            before_findings
        );
        assert_eq!(
            after_catalog
                .list_all_config_snapshots()
                .expect("snapshots after"),
            before_snapshots
        );
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn workspace_check_readiness_missing_catalog_returns_safe_empty_result() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-workspace-readiness-empty-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());

        let result = host
            .check_workspace_readiness(WorkspaceReadinessParams::default())
            .expect("empty workspace readiness");

        assert!(!result.catalog_available);
        assert!(!result.summary.workspace_available);
        assert_eq!(result.summary.visible_skill_count, 0);
        assert_eq!(result.summary.blocked_count, 1);
        assert_eq!(result.prompt_request.action, "workspace_readiness");
        assert!(!result.prompt_request.available);
        assert!(result.safety_flags.read_only);
        assert!(result.safety_flags.app_local_only);
        assert!(!result.safety_flags.provider_request_sent);
        assert!(!result.safety_flags.write_back_allowed);
        assert!(!result.safety_flags.skill_files_mutated);
        assert!(!result.safety_flags.agent_config_mutated);
        assert!(!result.safety_flags.script_execution_allowed);
        assert!(!result.safety_flags.credential_accessed);
        assert!(!host.catalog_path().exists());
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }

    #[test]
    fn workspace_readiness_prompt_preview_is_redacted_and_preview_only() {
        let app_data_dir = env::temp_dir().join(format!(
            "skills-copilot-workspace-readiness-prompt-test-{}-{}",
            std::process::id(),
            unique_suffix()
        ));
        let host = test_host(app_data_dir.clone());
        seed_catalog_with_similar_grouping_fixture(&host);

        let response = host.handle(ServiceRequest {
            id: Some("workspace-preview".to_string()),
            method: "llm.previewPrompt".to_string(),
            params: json!({
                "action": "workspace_readiness",
                "user_intent": "Validate release readiness using /tmp/home/private-project and token=secret-fixture-value",
                "instance_ids": ["similar-claude-a", "similar-codex-a"]
            }),
        });

        assert!(response.ok, "{:?}", response.error);
        let preview: WireLlmPreviewPromptResult =
            serde_json::from_value(response.result.expect("preview result"))
                .expect("decode prompt preview");
        assert_eq!(preview.action, "workspace_readiness");
        assert!(preview
            .prompt_preview
            .contains("Workspace readiness evidence"));
        assert!(!preview.prompt_preview.contains("secret-fixture-value"));
        assert!(!preview.provider_request_sent);
        assert!(!preview.write_back_allowed);
        assert!(preview.draft_requires_user_copy);
        assert!(!preview.raw_prompt_persisted);
        assert!(!preview.raw_response_persisted);
        assert!(!provider_call_metadata_path(&app_data_dir).exists());

        let _ = fs::remove_dir_all(app_data_dir);
    }
