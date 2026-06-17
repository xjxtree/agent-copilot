use super::protocol_fixtures::*;
use super::*;

#[test]
fn task_check_readiness_returns_local_read_only_candidates() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-readiness-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-readiness-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
    seed_catalog_with_llm_skill(&host, &skill_path);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("readiness-check".to_string()),
        method: "task.checkReadiness".to_string(),
        params: json!({
            "task": "Analyze local skill posture and execution safety",
            "agent": "claude-code",
            "candidate_instance_ids": ["llm-skill-id"],
            "limit": 4
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task readiness result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert!(result
        .get("score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score <= 100));
    assert!(result
        .get("candidate_skills")
        .and_then(Value::as_array)
        .is_some_and(|candidates| candidates.len() == 1));
    assert_eq!(
        result
            .pointer("/candidate_skills/0/instance_id")
            .and_then(Value::as_str),
        Some("llm-skill-id")
    );
    assert!(result
        .pointer("/candidate_skills/0/quality_score")
        .and_then(Value::as_u64)
        .is_some());
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/write_back_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/script_execution_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/config_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/snapshot_created")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/triage_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/prompt_request/action")
            .and_then(Value::as_str),
        Some("task_readiness")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("task_readiness")
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

    let serialized = serde_json::to_string(&result).expect("serialize readiness result");
    assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
    assert!(!serialized.contains("fixture-redacted-value"));
    assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_check_readiness_rejects_empty_task_without_creating_catalog() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-readiness-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("readiness-empty".to_string()),
        method: "task.checkReadiness".to_string(),
        params: json!({ "task": "   " }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty task error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty task"));
    assert!(
        !app_data_dir.exists(),
        "empty readiness request must not initialize app data"
    );
}

#[test]
fn task_check_readiness_missing_catalog_returns_empty_read_only_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-readiness-missing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("readiness-missing".to_string()),
        method: "task.checkReadiness".to_string(),
        params: json!({ "task": "Prepare a release readiness report" }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing catalog readiness result");
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(result.get("score").and_then(Value::as_u64), Some(0));
    assert!(result
        .get("candidate_skills")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(
        !host.catalog_path().exists(),
        "missing-catalog readiness must not initialize catalog.sqlite"
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
}

#[test]
fn task_check_readiness_bounds_large_candidate_scan_with_metadata() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-readiness-bounded-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_many_task_skills(&host, 90);

    let response = host.handle(ServiceRequest {
        id: Some("readiness-bounded".to_string()),
        method: "task.checkReadiness".to_string(),
        params: json!({
            "task": "Validate release readiness privacy evidence",
            "agent": "codex",
            "limit": 4
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("bounded readiness result");
    assert_eq!(
        result
            .pointer("/aggregation/status")
            .and_then(Value::as_str),
        Some("partial")
    );
    assert_eq!(
        result
            .pointer("/aggregation/partial")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert!(
        result
            .pointer("/aggregation/scanned_count")
            .and_then(Value::as_u64)
            < result
                .pointer("/aggregation/total_count")
                .and_then(Value::as_u64)
    );
    assert!(result
        .pointer("/aggregation/skipped_stages")
        .and_then(Value::as_array)
        .is_some_and(|stages| stages
            .iter()
            .any(|stage| stage.as_str() == Some("candidate-scan-overflow"))));
    assert!(result
        .get("candidate_skills")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() <= 4));
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn task_rank_skill_routes_returns_local_read_only_ranking() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-routing-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
    seed_catalog_with_llm_skill(&host, &skill_path);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("routing-rank".to_string()),
        method: "task.rankSkillRoutes".to_string(),
        params: json!({
            "task": "Analyze local skill posture and execution safety",
            "agent": "claude-code",
            "candidate_instance_ids": ["llm-skill-id"],
            "limit": 4
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("routing confidence result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert!(result
        .get("overall_confidence_score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score <= 100));
    assert_eq!(
        result
            .pointer("/route_candidates/0/rank")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/route_candidates/0/instance_id")
            .and_then(Value::as_str),
        Some("llm-skill-id")
    );
    assert!(result
        .pointer("/route_candidates/0/confidence_rationale")
        .and_then(Value::as_array)
        .is_some_and(|rationale| !rationale.is_empty()));
    assert!(result
        .get("likely_wrong_pick_risks")
        .and_then(Value::as_array)
        .is_some());
    assert!(result
        .get("likely_miss_risks")
        .and_then(Value::as_array)
        .is_some());
    assert_eq!(
        result
            .pointer("/prompt_request/action")
            .and_then(Value::as_str),
        Some("routing_confidence")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("routing_confidence")
    );
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/write_back_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/script_execution_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/config_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/snapshot_created")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/triage_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/credential_accessed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/raw_prompt_persisted")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/raw_response_persisted")
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

    let serialized = serde_json::to_string(&result).expect("serialize routing result");
    assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
    assert!(!serialized.contains("fixture-redacted-value"));
    assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_rank_skill_routes_rejects_empty_task_without_creating_catalog() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("routing-empty".to_string()),
        method: "task.rankSkillRoutes".to_string(),
        params: json!({ "task": "   " }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty routing error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty task"));
    assert!(
        !app_data_dir.exists(),
        "empty routing request must not initialize app data"
    );
}

#[test]
fn task_rank_skill_routes_missing_catalog_returns_empty_read_only_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-missing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("routing-missing".to_string()),
        method: "task.rankSkillRoutes".to_string(),
        params: json!({ "task": "Prepare a release readiness report" }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing catalog routing result");
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .get("overall_confidence_score")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert!(result
        .get("route_candidates")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(
        !host.catalog_path().exists(),
        "missing-catalog routing must not initialize catalog.sqlite"
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
}

#[test]
fn task_compare_agent_readiness_rejects_empty_task_without_writes() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("agent-readiness-empty".to_string()),
        method: "task.compareAgentReadiness".to_string(),
        params: json!({ "task": "   " }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty compare error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty task"));
    assert!(
        !app_data_dir.exists(),
        "empty cross-agent readiness request must not initialize app data"
    );
}

#[test]
fn task_compare_agent_readiness_missing_catalog_returns_safe_empty_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-missing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("agent-readiness-missing".to_string()),
        method: "task.compareAgentReadiness".to_string(),
        params: json!({
            "task_text": "Prepare a release readiness report",
            "agents": ["claude-code", "codex"]
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing catalog comparison");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/summary/agent_count")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert!(result
        .get("agent_rows")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert!(result.get("recommended_agent").is_some_and(Value::is_null));
    assert!(result
        .get("gap_issue_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() == 1));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_agent_readiness_safety(&result);
    assert!(
        !host.catalog_path().exists(),
        "missing-catalog cross-agent readiness must not initialize catalog.sqlite"
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
}

#[test]
fn task_compare_agent_readiness_ranks_multiple_agents_and_recommends_one() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-multi-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-multi-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_cleanup_queue_fixture(&host);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("agent-readiness-multi".to_string()),
        method: "task.compareAgentReadiness".to_string(),
        params: json!({
            "user_intent": "Review the shared fixture skill and local cleanup posture",
            "agents": ["codex", "claude-code"],
            "limit_per_agent": 2
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("multi-agent comparison");
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/summary/agent_count")
            .and_then(Value::as_u64),
        Some(2)
    );
    assert!(result
        .pointer("/summary/candidate_count")
        .and_then(Value::as_u64)
        .is_some_and(|count| count >= 2));
    assert!(result
        .get("agent_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() == 2));
    assert!(result
        .pointer("/agent_rows/0/comparison_score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score <= 100));
    assert!(result
        .pointer("/agent_rows/0/best_candidate/skill_name")
        .and_then(Value::as_str)
        .is_some());
    assert!(result
        .pointer("/recommended_agent/agent")
        .and_then(Value::as_str)
        .is_some_and(|agent| matches!(agent, "claude-code" | "codex")));
    assert_eq!(
        result
            .pointer("/prompt_request/action")
            .and_then(Value::as_str),
        Some("task_readiness")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("task_readiness")
    );
    assert_agent_readiness_safety(&result);

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

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_compare_agent_readiness_includes_optional_accuracy_context_read_only() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-accuracy-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-agent-readiness-accuracy-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
    let save = host.handle(ServiceRequest {
        id: Some("agent-readiness-benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "agent-readiness-routing-fixture",
            "title": "Agent readiness routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"],
            "acceptable_agents": ["claude-code"]
        }),
    });
    assert!(save.ok, "{:?}", save.error);
    let import = host.handle(ServiceRequest {
            id: Some("agent-readiness-trace-import".to_string()),
            method: "trace.importLocal".to_string(),
            params: json!({
                "title": "Agent readiness trace fixture",
                "content": "The agent selected llm-skill-id for Analyze local skill posture and execution safety.",
                "task": "Analyze local skill posture and execution safety",
                "agent": "claude-code",
                "expected_skill_refs": ["llm-skill-id"]
            }),
        });
    assert!(import.ok, "{:?}", import.error);

    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("agent-readiness-accuracy".to_string()),
        method: "task.compareAgentReadiness".to_string(),
        params: json!({
            "task": "Analyze local skill posture and execution safety",
            "agents": ["claude-code"],
            "include_routing_accuracy": true,
            "include_benchmarks": true
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("accuracy comparison");
    assert_eq!(
        result
            .pointer("/filters/include_routing_accuracy")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/filters/include_benchmarks")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert!(result
        .pointer("/agent_rows/0/routing_accuracy_context/benchmark_count")
        .and_then(Value::as_u64)
        .is_some());
    assert!(result
        .pointer("/agent_rows/0/benchmark_context/evaluated_count")
        .and_then(Value::as_u64)
        .is_some());
    assert_agent_readiness_safety(&result);

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

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_cockpit_aggregates_local_evidence_read_only() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-task-cockpit-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-task-cockpit-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_cleanup_queue_fixture(&host);
    let trace = host.handle(ServiceRequest {
        id: Some("task-cockpit-trace".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "title": "Task cockpit trace fixture",
            "content": "The agent selected shared-fixture-skill for local cleanup posture.",
            "task": "Review the shared fixture skill and local cleanup posture",
            "agent": "codex",
            "expected_skill_refs": ["shared-fixture-skill"]
        }),
    });
    assert!(trace.ok, "{:?}", trace.error);
    let review = host.handle(ServiceRequest {
        id: Some("task-cockpit-review".to_string()),
        method: "session.reviewAgentSkillUse".to_string(),
        params: json!({
            "content": "The agent selected shared-fixture-skill for local cleanup posture.",
            "title": "Task cockpit session review fixture",
            "task": "Review the shared fixture skill and local cleanup posture",
            "agent": "codex",
            "expected_skill_refs": ["shared-fixture-skill"]
        }),
    });
    assert!(review.ok, "{:?}", review.error);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");
    let before_reviews =
        fs::read_to_string(host.agent_session_reviews_path()).expect("reviews before");
    let before_traces = fs::read_to_string(host.trace_imports_path()).expect("traces before");

    let response = host.handle(ServiceRequest {
        id: Some("task-cockpit".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task_text": "Review the shared fixture skill and local cleanup posture",
            "agent": "codex",
            "limit": 4,
            "timeout_ms": 30000
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task cockpit result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.73")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.pointer("/filters/agent").and_then(Value::as_str),
        Some("codex")
    );
    assert!(result
        .get("cockpit_sections")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() >= 5));
    assert!(result
        .get("task_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() == 1));
    assert!(result
        .get("skill_candidate_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| !rows.is_empty()));
    assert!(result
        .get("agent_route_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| !rows.is_empty()));
    assert!(result
        .get("session_review_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| !rows.is_empty()));
    assert!(result
        .get("provider_observability_rows")
        .and_then(Value::as_array)
        .is_some());
    assert!(result
        .get("remediation_next_steps")
        .and_then(Value::as_array)
        .is_some());
    assert_eq!(
        result
            .pointer("/prompt_request/action")
            .and_then(Value::as_str),
        Some("task_cockpit")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("task_cockpit")
    );
    assert_eq!(
        result
            .pointer("/aggregation/status")
            .and_then(Value::as_str),
        Some("complete")
    );
    assert!(result
        .pointer("/aggregation/completed_stages")
        .and_then(Value::as_array)
        .is_some_and(|stages| stages
            .iter()
            .any(|stage| stage.as_str() == Some("task-readiness"))));
    assert_eq!(result.get("partial").and_then(Value::as_bool), Some(false));
    assert_agent_readiness_safety(&result);

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
    assert_eq!(
        fs::read_to_string(host.agent_session_reviews_path()).expect("reviews after"),
        before_reviews
    );
    assert_eq!(
        fs::read_to_string(host.trace_imports_path()).expect("traces after"),
        before_traces
    );
    assert!(!host.script_execution_audit_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
    assert!(!user_home.join(".claude/settings.json").exists());
    assert!(!user_home.join(".codex/config.toml").exists());

    let serialized = serde_json::to_string(&result).expect("serialize cockpit result");
    assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
    assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_cockpit_rejects_empty_task_without_creating_catalog() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-task-cockpit-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("task-cockpit-empty".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({ "task": "   " }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty cockpit error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty task"));
    assert!(
        !app_data_dir.exists(),
        "empty task cockpit request must not initialize app data"
    );
}

#[test]
fn task_cockpit_missing_catalog_returns_safe_empty_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-task-cockpit-missing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("task-cockpit-missing".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({ "task": "Prepare a release readiness report", "limit": 4 }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing catalog cockpit");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.73")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/summary/readiness_score")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert!(result
        .get("skill_candidate_rows")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/aggregation/status")
            .and_then(Value::as_str),
        Some("complete")
    );
    assert_eq!(result.get("partial").and_then(Value::as_bool), Some(false));
    assert_agent_readiness_safety(&result);
    assert!(
        !host.catalog_path().exists(),
        "missing-catalog task cockpit must not initialize catalog.sqlite"
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
}

#[test]
fn task_cockpit_skipped_context_returns_partial_diagnostics() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-task-cockpit-partial-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_cleanup_queue_fixture(&host);

    let response = host.handle(ServiceRequest {
        id: Some("task-cockpit-partial".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task_text": "Review the shared fixture skill and local cleanup posture",
            "agent": "codex",
            "include_remediation_context": false,
            "limit": 4
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("partial task cockpit");
    assert_eq!(result.get("partial").and_then(Value::as_bool), Some(true));
    assert!(result
        .get("fallback_reason")
        .and_then(Value::as_str)
        .is_some_and(|reason| reason.contains("Remediation context was skipped")));
    assert!(result
        .pointer("/aggregation/skipped_stages")
        .and_then(Value::as_array)
        .is_some_and(|stages| stages
            .iter()
            .any(|stage| stage.as_str() == Some("remediation-plan"))));
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
    assert_eq!(
        result
            .pointer("/safety_flags/script_execution_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn skill_lifecycle_timeline_filters_local_evidence() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-lifecycle-filter-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-lifecycle-filter-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_cleanup_queue_fixture(&host);

    let review = host.handle(ServiceRequest {
        id: Some("lifecycle-review".to_string()),
        method: "session.reviewAgentSkillUse".to_string(),
        params: json!({
            "content": "The agent selected codex-alpha for local cleanup posture.",
            "title": "Lifecycle session review fixture",
            "task": "Review codex-alpha lifecycle",
            "agent": "codex",
            "expected_skill_refs": ["codex-alpha"]
        }),
    });
    assert!(review.ok, "{:?}", review.error);
    let history = host.handle(ServiceRequest {
        id: Some("lifecycle-history".to_string()),
        method: "remediation.recordHistory".to_string(),
        params: json!({
            "id": "lifecycle-history-codex-alpha",
            "title": "Lifecycle history fixture",
            "decision": "reviewed",
            "status": "recorded",
            "source_method": "remediation.batchReview",
            "source_item_refs": ["codex-alpha"],
            "agent": "codex",
            "task": "Review codex-alpha lifecycle",
            "evidence_refs": ["skill:codex-alpha"]
        }),
    });
    assert!(history.ok, "{:?}", history.error);
    host.save_llm_prompt_runs(&[LlmPromptRunRecord {
        id: "prompt-run-lifecycle-fixture".to_string(),
        preview_id: "prompt-preview-lifecycle-fixture".to_string(),
        confirmation_id: "confirmation-lifecycle-fixture".to_string(),
        action: "skill_lifecycle_timeline".to_string(),
        request_kind: "skill_lifecycle_timeline".to_string(),
        analysis_kind: None,
        scope: Some("selected".to_string()),
        instance_id: Some("codex-alpha".to_string()),
        instance_ids: vec!["codex-alpha".to_string()],
        definition_id: Some("shared-fixture".to_string()),
        agent: Some("codex".to_string()),
        task: Some("Review codex-alpha lifecycle".to_string()),
        profile_id: "fixture-profile".to_string(),
        provider: "openai-compatible".to_string(),
        model: "fixture-model".to_string(),
        destination_host: "example.invalid".to_string(),
        status: "succeeded".to_string(),
        error_code: None,
        error_message: None,
        duration_ms: 12,
        estimated_input_tokens: 10,
        estimated_output_tokens: 5,
        estimated_total_tokens: 15,
        estimated_cost_usd: 0.0,
        draft_output: Some("Draft-only lifecycle wording.".to_string()),
        draft_requires_user_copy: true,
        provider_request_sent: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        redaction_summary: LlmPromptRunRedactionSummary {
            status: "redacted-local-only".to_string(),
            redacted_value_count: 0,
            redacted_fields: Vec::new(),
            placeholders: Vec::new(),
            raw_prompt_persisted: false,
            raw_response_persisted: false,
            raw_trace_persisted: false,
            raw_secret_returned: false,
        },
        created_at: 10,
        completed_at: 11,
        safety_flags: llm_prompt_run_safety_flags(false, false),
    }])
    .expect("save prompt run fixture");

    let response = host.handle(ServiceRequest {
        id: Some("lifecycle".to_string()),
        method: "skill.lifecycleTimeline".to_string(),
        params: json!({
            "agent": "codex",
            "selected_skill_id": "codex-alpha",
            "task": "Review codex-alpha lifecycle",
            "limit": 50
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("lifecycle result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.66")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/filters/selected_skill_id")
            .and_then(Value::as_str),
        Some("codex-alpha")
    );
    assert_eq!(
        result.pointer("/filters/agent").and_then(Value::as_str),
        Some("codex")
    );
    assert!(result
        .get("timeline_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows
            .iter()
            .any(|row| row.get("event_type").and_then(Value::as_str) == Some("finding"))));
    assert!(result
        .get("timeline_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows
            .iter()
            .any(|row| row.get("event_type").and_then(Value::as_str) == Some("session_review"))));
    assert!(result
        .get("timeline_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows
            .iter()
            .any(|row| row.get("event_type").and_then(Value::as_str) == Some("prompt_run"))));
    assert!(result
        .get("timeline_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.iter().any(
            |row| row.get("event_type").and_then(Value::as_str) == Some("remediation_history")
        )));
    assert_eq!(
        result
            .pointer("/summary/skill_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/summary/selected_agent")
            .and_then(Value::as_str),
        Some("codex")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/action")
            .and_then(Value::as_str),
        Some("skill_lifecycle_timeline")
    );
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("skill_lifecycle_timeline")
    );
    assert_agent_readiness_safety(&result);

    let serialized = serde_json::to_string(&result).expect("serialize lifecycle");
    assert!(!serialized.contains(&app_data_dir.to_string_lossy().to_string()));
    assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
    assert!(!serialized.contains("OPENAI_API_KEY"));

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn skill_lifecycle_timeline_missing_catalog_returns_safe_empty_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-lifecycle-missing-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("lifecycle-missing".to_string()),
        method: "skill.lifecycleTimeline".to_string(),
        params: json!({ "selected_skill_id": "missing-skill", "limit": 4 }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing lifecycle result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.66")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/summary/total_event_count")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert!(result
        .get("timeline_rows")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert!(result
        .get("skill_rows")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert!(result
        .get("agent_rows")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_agent_readiness_safety(&result);
    assert!(
        !host.catalog_path().exists(),
        "missing-catalog lifecycle timeline must not initialize catalog.sqlite"
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
}

#[test]
fn skill_lifecycle_timeline_preserves_read_only_boundaries() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-lifecycle-read-only-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-lifecycle-read-only-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_cleanup_queue_fixture(&host);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("lifecycle-read-only".to_string()),
        method: "skill.lifecycleTimeline".to_string(),
        params: json!({
            "agent": "codex",
            "include_prompt_runs": true,
            "include_session_reviews": true,
            "include_remediation_history": true,
            "include_stale_drift": true,
            "limit": 12
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("read-only lifecycle result");
    assert_agent_readiness_safety(&result);
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
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
    assert!(!host.llm_prompt_runs_path().exists());
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!host.remediation_history_path().exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_benchmark_save_list_delete_roundtrip_is_app_local() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-benchmark-roundtrip-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-benchmark-roundtrip-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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

    let save = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"],
            "expected_skill_names": ["llm-fixture"],
            "acceptable_agents": ["claude-code"],
            "acceptable_scopes": ["agent-global"],
            "success_criteria": ["Top deterministic route matches the fixture skill."]
        }),
    });
    assert!(save.ok, "{:?}", save.error);
    let saved = save.result.expect("save benchmark result");
    assert_eq!(
        saved.pointer("/benchmark/id").and_then(Value::as_str),
        Some("local-routing-fixture")
    );
    assert_eq!(saved.get("created").and_then(Value::as_bool), Some(true));
    assert_eq!(
        saved.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        saved.get("agent_config_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert!(app_data_dir.join("task-benchmarks.json").exists());
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
    assert!(!user_home.join(".claude/settings.json").exists());
    assert!(!user_home.join(".codex/config.toml").exists());

    let list = host.handle(ServiceRequest {
        id: Some("benchmark-list".to_string()),
        method: "task.listBenchmarks".to_string(),
        params: json!({}),
    });
    assert!(list.ok, "{:?}", list.error);
    let listed = list.result.expect("list benchmark result");
    assert_eq!(listed.get("count").and_then(Value::as_u64), Some(1));
    assert_eq!(
        listed.pointer("/benchmarks/0/id").and_then(Value::as_str),
        Some("local-routing-fixture")
    );
    assert_eq!(
        listed.pointer("/benchmarks/0/task").and_then(Value::as_str),
        Some("Analyze local skill posture and execution safety")
    );
    assert_eq!(
        listed.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        listed.get("raw_prompt_persisted").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        listed
            .get("raw_response_persisted")
            .and_then(Value::as_bool),
        Some(false)
    );

    let delete = host.handle(ServiceRequest {
        id: Some("benchmark-delete".to_string()),
        method: "task.deleteBenchmark".to_string(),
        params: json!({ "id": "local-routing-fixture" }),
    });
    assert!(delete.ok, "{:?}", delete.error);
    let deleted = delete.result.expect("delete benchmark result");
    assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
    assert_eq!(
        deleted.get("remaining_count").and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        deleted
            .get("provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        deleted.get("agent_config_mutated").and_then(Value::as_bool),
        Some(false)
    );

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_benchmark_evaluate_returns_deterministic_read_only_results() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-benchmark-evaluate-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-benchmark-evaluate-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    let skill_path = app_data_dir.join("fixture-skill").join("SKILL.md");
    seed_catalog_with_llm_skill(&host, &skill_path);
    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let save = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"],
            "acceptable_agents": ["claude-code"],
            "acceptable_scopes": ["agent-global"]
        }),
    });
    assert!(save.ok, "{:?}", save.error);

    let response = host.handle(ServiceRequest {
        id: Some("benchmark-evaluate".to_string()),
        method: "task.evaluateBenchmarks".to_string(),
        params: json!({ "ids": ["local-routing-fixture"] }),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("benchmark evaluation result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.get("evaluated_count").and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/benchmark_results/0/expected_match_status")
            .and_then(Value::as_str),
        Some("expected_match")
    );
    assert_eq!(
        result
            .pointer("/benchmark_results/0/top_route/instance_id")
            .and_then(Value::as_str),
        Some("llm-skill-id")
    );
    assert!(result
        .pointer("/benchmark_results/0/score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score <= 100));
    assert_eq!(
        result
            .pointer("/prompt_request/request/action")
            .and_then(Value::as_str),
        Some("routing_confidence")
    );
    for path in [
        "/safety_flags/read_only",
        "/benchmark_results/0/safety_flags/read_only",
    ] {
        assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(true));
    }
    for path in [
        "/safety_flags/provider_request_sent",
        "/safety_flags/write_back_allowed",
        "/safety_flags/script_execution_allowed",
        "/safety_flags/config_mutation_allowed",
        "/safety_flags/snapshot_created",
        "/safety_flags/triage_mutation_allowed",
        "/safety_flags/credential_accessed",
        "/safety_flags/raw_prompt_persisted",
        "/safety_flags/raw_response_persisted",
        "/benchmark_results/0/safety_flags/provider_request_sent",
        "/benchmark_results/0/safety_flags/write_back_allowed",
        "/benchmark_results/0/safety_flags/script_execution_allowed",
        "/benchmark_results/0/safety_flags/config_mutation_allowed",
        "/benchmark_results/0/safety_flags/snapshot_created",
        "/benchmark_results/0/safety_flags/triage_mutation_allowed",
        "/benchmark_results/0/safety_flags/credential_accessed",
        "/benchmark_results/0/safety_flags/raw_prompt_persisted",
        "/benchmark_results/0/safety_flags/raw_response_persisted",
    ] {
        assert_eq!(result.pointer(path).and_then(Value::as_bool), Some(false));
    }

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

    let serialized = serde_json::to_string(&result).expect("serialize benchmark result");
    assert!(!serialized.contains("OPENAI_API_KEY=<redacted>"));
    assert!(!serialized.contains("fixture-redacted-value"));
    assert!(!serialized.contains(&skill_path.to_string_lossy().to_string()));

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn task_benchmark_evaluate_missing_catalog_returns_safe_blocker_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-benchmark-missing-catalog-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let save = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "missing-catalog-fixture",
            "title": "Missing catalog fixture",
            "task": "Prepare a release readiness report",
            "expected_skill_refs": ["missing-skill-id"]
        }),
    });
    assert!(save.ok, "{:?}", save.error);
    assert!(!host.catalog_path().exists());

    let response = host.handle(ServiceRequest {
        id: Some("benchmark-evaluate".to_string()),
        method: "task.evaluateBenchmarks".to_string(),
        params: json!({}),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing catalog benchmark result");
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("evaluated_count").and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/benchmark_results/0/expected_match_status")
            .and_then(Value::as_str),
        Some("blocked_no_route")
    );
    assert_eq!(
        result
            .pointer("/benchmark_results/0/score")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/write_back_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/script_execution_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/config_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/snapshot_created")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/triage_mutation_allowed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/credential_accessed")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn routing_regression_detect_missing_baseline_is_read_only() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-missing-baseline-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-missing-baseline-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
    let save = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(save.ok, "{:?}", save.error);

    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("routing-regression-detect".to_string()),
        method: "task.detectRoutingRegression".to_string(),
        params: json!({}),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("missing baseline detection result");
    assert_eq!(
        result.get("status").and_then(Value::as_str),
        Some("baseline_missing")
    );
    assert_eq!(
        result.get("baseline_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .get("current_evaluated_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result.get("regression_count").and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!host.routing_regression_baseline_path().exists());

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

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn routing_regression_baseline_save_is_app_local() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-save-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-save-home-{}-{}",
        std::process::id(),
        unique_suffix(),
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
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
    let save_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(save_benchmark.ok, "{:?}", save_benchmark.error);

    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");

    let response = host.handle(ServiceRequest {
        id: Some("routing-baseline-save".to_string()),
        method: "task.saveRoutingBaseline".to_string(),
        params: json!({ "ids": ["local-routing-fixture"] }),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("baseline save result");
    assert_eq!(
        result.get("app_local_only").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.get("baseline_file").and_then(Value::as_str),
        Some("task-routing-baseline.json")
    );
    assert_eq!(
        result.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("agent_config_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("skill_files_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/baseline/benchmark_results/0/benchmark_id")
            .and_then(Value::as_str),
        Some("local-routing-fixture")
    );
    assert!(host.routing_regression_baseline_path().exists());
    assert!(app_data_dir.join("task-routing-baseline.json").exists());

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

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn routing_regression_detect_after_baseline_reports_no_regression_when_unchanged() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-unchanged-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
    let save_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
    let save_baseline = host.handle(ServiceRequest {
        id: Some("routing-baseline-save".to_string()),
        method: "task.saveRoutingBaseline".to_string(),
        params: json!({}),
    });
    assert!(save_baseline.ok, "{:?}", save_baseline.error);

    let response = host.handle(ServiceRequest {
        id: Some("routing-regression-detect".to_string()),
        method: "task.detectRoutingRegression".to_string(),
        params: json!({}),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("unchanged detection result");
    assert_eq!(
        result.get("status").and_then(Value::as_str),
        Some("no_regressions")
    );
    assert_eq!(
        result.get("baseline_available").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.get("regression_count").and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result.pointer("/items/0/status").and_then(Value::as_str),
        Some("unchanged")
    );
    assert_eq!(
        result
            .pointer("/items/0/regression")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn routing_regression_detect_reports_worse_benchmark_expectation() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-regression-worse-expectation-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));
    let save_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
    let save_baseline = host.handle(ServiceRequest {
        id: Some("routing-baseline-save".to_string()),
        method: "task.saveRoutingBaseline".to_string(),
        params: json!({}),
    });
    assert!(save_baseline.ok, "{:?}", save_baseline.error);

    let update_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-update".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["other-skill-id"]
        }),
    });
    assert!(update_benchmark.ok, "{:?}", update_benchmark.error);

    let response = host.handle(ServiceRequest {
        id: Some("routing-regression-detect".to_string()),
        method: "task.detectRoutingRegression".to_string(),
        params: json!({ "score_drop_threshold": 1, "confidence_drop_threshold": 1 }),
    });
    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("regression detection result");
    assert_eq!(
        result.get("status").and_then(Value::as_str),
        Some("regressions_detected")
    );
    assert_eq!(
        result.get("regression_count").and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result.pointer("/items/0/status").and_then(Value::as_str),
        Some("regression")
    );
    assert_eq!(
        result
            .pointer("/items/0/regression")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/items/0/baseline/expected_match_status")
            .and_then(Value::as_str),
        Some("expected_match")
    );
    assert_eq!(
        result
            .pointer("/items/0/current/expected_match_status")
            .and_then(Value::as_str),
        Some("mismatch")
    );
    assert!(result
        .pointer("/items/0/reasons")
        .and_then(Value::as_array)
        .is_some_and(|reasons| reasons.iter().any(|reason| reason
            .as_str()
            .is_some_and(|reason| reason.contains("Expected match status worsened")))));
    assert_eq!(
        result
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn remediation_history_rejects_empty_decision_without_writing() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-remediation-history-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("remediation-history-empty".to_string()),
        method: "remediation.recordHistory".to_string(),
        params: json!({
            "decision": "   ",
            "title": "Empty decision fixture"
        }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty remediation history error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty decision"));
    assert!(!host.remediation_history_path().exists());
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn remediation_history_record_persists_redacted_app_local_metadata_only() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-remediation-history-redaction-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-remediation-history-home-{}-{unique}",
        std::process::id(),
    ));
    let project_root = app_data_dir.join("project-root");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: Some(project_root.clone()),
            project_cwd: Some(project_root.clone()),
            extra_roots: Vec::new(),
        },
    };
    let raw_secret = "history-secret-value";
    let key_label = ["API", "_", "KEY"].join("");

    let response = host.handle(ServiceRequest {
            id: Some("remediation-history-record".to_string()),
            method: "remediation.recordHistory".to_string(),
            params: json!({
                "id": "local-history-redaction",
                "title": format!("Review blocked fix at {}", user_home.join(".agent/config.toml").display()),
                "decision": "Needs follow-up",
                "status": "Reopened",
                "source_kind": "batch-review",
                "source_method": "remediation.batchReview",
                "batch_review_item_ids": ["batch-risk-1"],
                "source_item_refs": [format!("finding:{}", project_root.join("SKILL.md").display())],
                "agent": "codex",
                "workspace": project_root.to_string_lossy(),
                "task": format!("Repair policy without storing {key_label}={raw_secret}"),
                "rule_ids": ["permissions.network-declared"],
                "risk_levels": ["High"],
                "recurrence_key": format!("permissions.network-declared:{}", project_root.display()),
                "reopened": true,
                "readiness_improvement_notes": ["Task readiness should improve after the permission copy is clarified."],
                "routing_improvement_notes": ["Routing ambiguity should drop for policy review tasks."],
                "blocker_notes": [format!("Blocked by {key_label}={raw_secret}")],
                "gap_notes": ["Missing declared network permission."],
                "evidence_refs": [format!("path:{}", user_home.join(".agent/config.toml").display())],
                "notes": format!("Do not persist raw {key_label}={raw_secret}.")
            }),
        });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("remediation history record result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.60")
    );
    assert_eq!(
        result.pointer("/record/id").and_then(Value::as_str),
        Some("local-history-redaction")
    );
    assert_eq!(
        result.pointer("/record/decision").and_then(Value::as_str),
        Some("needs-follow-up")
    );
    assert_eq!(
        result.pointer("/record/status").and_then(Value::as_str),
        Some("reopened")
    );
    assert_eq!(
        result
            .pointer("/record/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("skill_files_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("agent_config_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("snapshot_created").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("rollback_performed").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("triage_mutated").and_then(Value::as_bool),
        Some(false)
    );

    assert!(host.remediation_history_path().exists());
    let persisted = fs::read_to_string(host.remediation_history_path()).expect("read history file");
    assert!(persisted.contains("$HOME"));
    assert!(persisted.contains("<project-root>"));
    assert!(persisted.contains("<redacted>"));
    assert!(!persisted.contains(raw_secret));
    assert!(!persisted.contains(&key_label));
    assert!(!persisted.contains(&user_home.to_string_lossy().to_string()));
    assert!(!persisted.contains(&project_root.to_string_lossy().to_string()));
    assert!(!host.catalog_path().exists());
    assert!(!host.script_execution_audit_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
    assert!(!user_home.join(".claude/settings.json").exists());
    assert!(!user_home.join(".codex/config.toml").exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn remediation_history_list_delete_summarizes_recurrence_read_only() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-remediation-history-roundtrip-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    for (id, decision, status, reopened) in [
        ("history-first", "reviewed", "recorded", false),
        ("history-second", "deferred", "reopened", true),
    ] {
        let response = host.handle(ServiceRequest {
                id: Some(format!("record-{id}")),
                method: "remediation.recordHistory".to_string(),
                params: json!({
                    "id": id,
                    "title": format!("History {id}"),
                    "decision": decision,
                    "status": status,
                    "source_method": "remediation.batchReview",
                    "batch_review_item_ids": ["batch-risk-1"],
                    "recurrence_key": "risk:permissions.network-declared",
                    "agent": "codex",
                    "readiness_improvement_notes": ["Readiness improved after review."],
                    "routing_improvement_notes": if reopened { vec!["Routing confidence still needs review."] } else { Vec::<&str>::new() },
                    "blocker_notes": if reopened { vec!["Writable action remains blocked."] } else { Vec::<&str>::new() },
                    "evidence_refs": ["finding:permissions.network-declared"],
                    "reopened": reopened
                }),
            });
        assert!(response.ok, "{:?}", response.error);
    }

    let list = host.handle(ServiceRequest {
        id: Some("history-list".to_string()),
        method: "remediation.listHistory".to_string(),
        params: json!({
            "agent": "codex",
            "include_recurrence_rows": true,
            "limit": 10
        }),
    });
    assert!(list.ok, "{:?}", list.error);
    let listed = list.result.expect("history list result");
    assert_eq!(
        listed.get("generated_by").and_then(Value::as_str),
        Some("local-v2.60")
    );
    assert_eq!(
        listed
            .pointer("/summary/returned_count")
            .and_then(Value::as_u64),
        Some(2)
    );
    assert_eq!(
        listed
            .pointer("/summary/reopened_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        listed
            .pointer("/summary/recurrence_group_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        listed
            .pointer("/summary/readiness_improvement_count")
            .and_then(Value::as_u64),
        Some(2)
    );
    assert_eq!(
        listed
            .pointer("/summary/routing_improvement_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        listed
            .pointer("/summary/blocker_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        listed
            .pointer("/recurrence_rows/0/record_count")
            .and_then(Value::as_u64),
        Some(2)
    );
    assert_eq!(
        listed
            .pointer("/recurrence_rows/0/reopened_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        listed
            .pointer("/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );

    let delete = host.handle(ServiceRequest {
        id: Some("history-delete".to_string()),
        method: "remediation.deleteHistory".to_string(),
        params: json!({ "id": "history-first" }),
    });
    assert!(delete.ok, "{:?}", delete.error);
    let deleted = delete.result.expect("history delete result");
    assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
    assert_eq!(
        deleted.get("remaining_count").and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        deleted
            .get("provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        deleted.get("skill_files_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        deleted.get("agent_config_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert!(!host.catalog_path().exists());
    assert!(!host.script_execution_audit_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn trace_import_rejects_empty_content_without_writing() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-trace-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("trace-empty".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({ "content": "   " }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty trace error");
    assert_eq!(error.code, "invalid_request");
    assert!(error.message.contains("non-empty trace content"));
    assert!(!host.trace_imports_path().exists());
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn local_session_preview_requires_explicit_authorized_roots() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-local-session-preview-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("session-preview-empty".to_string()),
        method: "session.previewLocalSessions".to_string(),
        params: json!({}),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("local session preview result");
    assert_eq!(
        result
            .get("authorization_required")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(result.get("count").and_then(Value::as_u64), Some(0));
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    assert!(!host.trace_imports_path().exists());
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn local_session_preview_reads_authorized_roots_with_redaction_only() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-local-session-preview-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-local-session-preview-home-{}-{unique}",
        std::process::id(),
    ));
    let project_root = app_data_dir.join("project-root");
    let session_root = user_home.join(".codex/sessions");
    fs::create_dir_all(&session_root).expect("create session root");
    let raw_secret = "session-secret-value";
    let key_label = ["API", "_", "KEY"].join("");
    let session_path = session_root.join("fixture-session.jsonl");
    fs::write(
        &session_path,
        format!(
            "{{\"role\":\"assistant\",\"content\":\"Used llm-skill-id for local task at {} with {key_label}={raw_secret}\"}}\n",
            project_root.display()
        ),
    )
    .expect("write session");
    fs::write(session_root.join("ignored.bin"), raw_secret).expect("write ignored binary");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: Some(project_root.clone()),
            project_cwd: Some(project_root.clone()),
            extra_roots: Vec::new(),
        },
    };

    let response = host.handle(ServiceRequest {
        id: Some("session-preview".to_string()),
        method: "session.previewLocalSessions".to_string(),
        params: json!({
            "authorized_roots": [session_root.to_string_lossy().to_string()],
            "limit": 10,
            "max_excerpt_chars": 800
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("local session preview result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.87")
    );
    assert_eq!(
        result.get("authorized").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .get("authorization_required")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(result.get("count").and_then(Value::as_u64), Some(1));
    assert_eq!(
        result
            .pointer("/session_rows/0/agent")
            .and_then(Value::as_str),
        Some("codex")
    );
    assert_eq!(
        result
            .pointer("/session_rows/0/source_kind")
            .and_then(Value::as_str),
        Some("authorized-local-session")
    );
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    let serialized = serde_json::to_string(&result).expect("serialize result");
    assert!(serialized.contains("$HOME"));
    assert!(serialized.contains("<project-root>"));
    assert!(serialized.contains("<redacted>"));
    assert!(!serialized.contains(raw_secret));
    assert!(!serialized.contains(&key_label));
    assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
    assert!(!serialized.contains(&project_root.to_string_lossy().to_string()));
    assert!(!host.trace_imports_path().exists());
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn mcp_server_preview_requires_explicit_authorized_config_paths() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-mcp-preview-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("mcp-preview-empty".to_string()),
        method: "evidence.previewMcpServers".to_string(),
        params: json!({}),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("mcp preview result");
    assert_eq!(
        result
            .get("authorization_required")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result.get("authorized").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(result.get("count").and_then(Value::as_u64), Some(0));
    assert_eq!(
        result.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    assert!(result
        .get("gap_notes")
        .and_then(Value::as_array)
        .is_some_and(|notes| notes.iter().any(|note| note
            .as_str()
            .is_some_and(|text| text.contains("does not scan default")))));
    assert!(!host.catalog_path().exists());
    assert!(!host.trace_imports_path().exists());
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn mcp_server_preview_reads_authorized_configs_with_redaction_only() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-mcp-preview-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-mcp-preview-home-{}-{unique}",
        std::process::id(),
    ));
    let project_root = app_data_dir.join("project-root");
    let config_dir = user_home.join(".config/agent");
    fs::create_dir_all(&config_dir).expect("create config dir");
    let raw_secret = "mcp-secret-value";
    let config_path = config_dir.join("mcp.json");
    fs::write(
        &config_path,
        format!(
            r#"{{
  "mcpServers": {{
    "filesystem": {{
      "command": "{}/bin/mcp-filesystem",
      "args": ["--root", "{}"],
      "env": {{
        "MCP_TOKEN": "{raw_secret}"
      }}
    }},
    "remote-search": {{
      "transport": "sse",
      "url": "https://example.invalid/mcp"
    }}
  }}
}}"#,
            user_home.display(),
            project_root.display(),
        ),
    )
    .expect("write mcp config");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: Some(project_root.clone()),
            project_cwd: Some(project_root.clone()),
            extra_roots: Vec::new(),
        },
    };

    let response = host.handle(ServiceRequest {
        id: Some("mcp-preview".to_string()),
        method: "evidence.previewMcpServers".to_string(),
        params: json!({
            "authorized_config_paths": [config_path.to_string_lossy().to_string()],
            "limit": 10
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("mcp preview result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.87")
    );
    assert_eq!(
        result.get("authorized").and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .get("authorization_required")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(result.get("count").and_then(Value::as_u64), Some(2));
    assert_eq!(
        result
            .pointer("/server_rows/0/source_path")
            .and_then(Value::as_str),
        Some("$HOME/.config/agent/mcp.json")
    );
    assert_eq!(
        result.get("provider_request_sent").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("credential_accessed").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    let serialized = serde_json::to_string(&result).expect("serialize result");
    assert!(serialized.contains("$HOME"));
    assert!(serialized.contains("mcp.server:filesystem"));
    assert!(serialized.contains("\"env_key_count\":1"));
    assert!(!serialized.contains(raw_secret));
    assert!(!serialized.contains("MCP_TOKEN"));
    assert!(!serialized.contains(&user_home.to_string_lossy().to_string()));
    assert!(!serialized.contains(&project_root.to_string_lossy().to_string()));
    assert!(!host.catalog_path().exists());
    assert!(!host.trace_imports_path().exists());
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn trace_import_persists_redacted_only_app_local_record() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-trace-import-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-trace-import-home-{}-{unique}",
        std::process::id(),
    ));
    let project_root = app_data_dir.join("project-root");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: Some(project_root.clone()),
            project_cwd: Some(project_root.clone()),
            extra_roots: Vec::new(),
        },
    };
    seed_catalog_with_llm_skill(&host, &project_root.join("fixture-skill").join("SKILL.md"));
    let raw_secret = "trace-secret-value";
    let key_label = ["API", "_", "KEY"].join("");
    let auth_label = ["Author", "ization"].join("");
    let raw_content = format!(
            "Agent selected llm-skill-id for local task.\n{key_label}={raw_secret}\nPath: {}\n{auth_label}: Bearer {raw_secret}",
            user_home.join(".local/share/app.log").display()
        );

    let response = host.handle(ServiceRequest {
        id: Some("trace-import".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "content": raw_content,
            "title": "Trace with local path",
            "source_kind": "pasted-transcript",
            "agent": "claude-code",
            "task": "Analyze local skill posture",
            "expected_skill_refs": ["llm-skill-id"],
            "expected_skill_names": ["llm-fixture"],
            "max_excerpt_chars": 1200
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("trace import result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result
            .pointer("/import/analysis/outcome")
            .and_then(Value::as_str),
        Some("hit")
    );
    assert_eq!(
        result
            .pointer("/import/analysis/detected_skills/0/instance_id")
            .and_then(Value::as_str),
        Some("llm-skill-id")
    );
    assert_eq!(
        result
            .pointer("/import/safety_flags/raw_trace_persisted")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    assert!(host.trace_imports_path().exists());
    let persisted =
        fs::read_to_string(host.trace_imports_path()).expect("read persisted trace import");
    assert!(persisted.contains("<redacted>"));
    assert!(persisted.contains("$HOME"));
    assert!(!persisted.contains(raw_secret));
    assert!(!persisted.contains(&key_label));
    assert!(!persisted.contains(&user_home.to_string_lossy().to_string()));
    assert!(!persisted.contains(&project_root.to_string_lossy().to_string()));
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
    assert!(!user_home.join(".claude/settings.json").exists());
    assert!(!user_home.join(".codex/config.toml").exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn trace_import_list_delete_roundtrip_is_app_local() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-trace-roundtrip-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

    let import = host.handle(ServiceRequest {
        id: Some("trace-import".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "trace_text": "Trace routed to llm-fixture using llm-skill-id.",
            "title": "Trace roundtrip",
            "expected_skill_names": ["llm-fixture"]
        }),
    });
    assert!(import.ok, "{:?}", import.error);
    let import_id = import
        .result
        .as_ref()
        .and_then(|result| result.pointer("/import/id"))
        .and_then(Value::as_str)
        .expect("import id")
        .to_string();

    let list = host.handle(ServiceRequest {
        id: Some("trace-list".to_string()),
        method: "trace.listImports".to_string(),
        params: json!({}),
    });
    assert!(list.ok, "{:?}", list.error);
    let listed = list.result.expect("trace list result");
    assert_eq!(listed.get("count").and_then(Value::as_u64), Some(1));
    assert_eq!(
        listed.pointer("/imports/0/id").and_then(Value::as_str),
        Some(import_id.as_str())
    );
    assert_eq!(
        listed.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );

    let delete = host.handle(ServiceRequest {
        id: Some("trace-delete".to_string()),
        method: "trace.deleteImport".to_string(),
        params: json!({ "id": import_id }),
    });
    assert!(delete.ok, "{:?}", delete.error);
    let deleted = delete.result.expect("trace delete result");
    assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
    assert_eq!(
        deleted.get("remaining_count").and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        deleted
            .get("provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn trace_import_missing_catalog_remains_read_only_unknown() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-trace-missing-catalog-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    assert!(!host.catalog_path().exists());

    let response = host.handle(ServiceRequest {
        id: Some("trace-missing-catalog".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "transcript": "Trace mentioned expected local routing but the catalog is absent.",
            "title": "Missing catalog trace",
            "expected_skill_refs": ["missing-local-skill"]
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response
        .result
        .expect("missing catalog trace import result");
    assert_eq!(
        result
            .pointer("/import/analysis/catalog_available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/import/analysis/outcome")
            .and_then(Value::as_str),
        Some("unknown")
    );
    assert_eq!(
        result
            .pointer("/import/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/import/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(host.trace_imports_path().exists());
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn agent_session_review_rejects_empty_input_without_writing() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-session-review-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());

    let response = host.handle(ServiceRequest {
        id: Some("session-review-empty".to_string()),
        method: "session.reviewAgentSkillUse".to_string(),
        params: json!({ "content": "   ", "trace_import_ids": [] }),
    });

    assert!(!response.ok);
    let error = response.error.expect("empty session review error");
    assert_eq!(error.code, "invalid_request");
    assert!(error
        .message
        .contains("transcript content or trace_import_ids"));
    assert!(!host.agent_session_reviews_path().exists());
    assert!(!host.catalog_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn agent_session_review_persists_redacted_only_app_local_record() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-session-review-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-session-review-home-{}-{unique}",
        std::process::id(),
    ));
    let project_root = app_data_dir.join("project-root");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: Some(project_root.clone()),
            project_cwd: Some(project_root.clone()),
            extra_roots: Vec::new(),
        },
    };
    seed_catalog_with_llm_skill(&host, &project_root.join("fixture-skill").join("SKILL.md"));
    let raw_secret = "session-secret-value";
    let key_label = ["API", "_", "KEY"].join("");
    let auth_label = ["Author", "ization"].join("");
    let raw_content = format!(
            "Assistant selected llm-skill-id and llm-fixture for the task.\n{key_label}={raw_secret}\nPath: {}\n{auth_label}: Bearer {raw_secret}",
            user_home.join(".local/share/session.log").display()
        );

    let response = host.handle(ServiceRequest {
        id: Some("session-review".to_string()),
        method: "session.reviewAgentSkillUse".to_string(),
        params: json!({
            "transcript_text": raw_content,
            "title": "Session review with local path",
            "agent": "claude-code",
            "task": "Analyze local skill posture",
            "expected_skill_refs": ["llm-skill-id"],
            "expected_skill_names": ["llm-fixture"],
            "max_excerpt_chars": 1600
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("session review result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("local-v2.62")
    );
    assert_eq!(
        result
            .pointer("/review/analysis/outcome")
            .and_then(Value::as_str),
        Some("hit")
    );
    assert_eq!(
        result
            .pointer("/review/analysis/detected_skills/0/instance_id")
            .and_then(Value::as_str),
        Some("llm-skill-id")
    );
    assert_eq!(
        result
            .pointer("/review/safety_flags/read_only")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_eq!(
        result
            .pointer("/review/safety_flags/provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result.get("skill_files_mutated").and_then(Value::as_bool),
        Some(false)
    );
    assert!(host.agent_session_reviews_path().exists());
    let persisted = fs::read_to_string(host.agent_session_reviews_path())
        .expect("read persisted session review");
    assert!(persisted.contains("<redacted>"));
    assert!(persisted.contains("$HOME"));
    assert!(!persisted.contains(raw_secret));
    assert!(!persisted.contains(&key_label));
    assert!(!persisted.contains(&user_home.to_string_lossy().to_string()));
    assert!(!persisted.contains(&project_root.to_string_lossy().to_string()));
    assert!(!provider_call_metadata_path(&app_data_dir).exists());
    assert!(!user_home.join(".claude/settings.json").exists());
    assert!(!user_home.join(".codex/config.toml").exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}

#[test]
fn agent_session_review_trace_reference_list_delete_roundtrip_is_app_local() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-session-review-roundtrip-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

    let import = host.handle(ServiceRequest {
        id: Some("trace-import-for-session".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "content": "Trace routed to llm-fixture using llm-skill-id.",
            "title": "Session source trace",
            "agent": "claude-code",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(import.ok, "{:?}", import.error);
    let import_id = import
        .result
        .as_ref()
        .and_then(|result| result.pointer("/import/id"))
        .and_then(Value::as_str)
        .expect("import id")
        .to_string();

    let review = host.handle(ServiceRequest {
        id: Some("session-review-from-trace".to_string()),
        method: "session.reviewAgentSkillUse".to_string(),
        params: json!({
            "trace_import_ids": [import_id],
            "title": "Trace-backed session review"
        }),
    });
    assert!(review.ok, "{:?}", review.error);
    let review_result = review.result.expect("trace-backed review result");
    let review_id = review_result
        .pointer("/review/id")
        .and_then(Value::as_str)
        .expect("review id")
        .to_string();
    assert_eq!(
        review_result
            .pointer("/review/analysis/outcome")
            .and_then(Value::as_str),
        Some("hit")
    );
    assert_eq!(
        review_result
            .pointer("/review/analysis/referenced_traces/0/outcome")
            .and_then(Value::as_str),
        Some("hit")
    );
    assert_eq!(
        review_result
            .get("provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );

    let list = host.handle(ServiceRequest {
        id: Some("session-review-list".to_string()),
        method: "session.listSkillReviews".to_string(),
        params: json!({ "limit": 10 }),
    });
    assert!(list.ok, "{:?}", list.error);
    let listed = list.result.expect("session review list result");
    assert_eq!(listed.get("count").and_then(Value::as_u64), Some(1));
    assert_eq!(
        listed.pointer("/reviews/0/id").and_then(Value::as_str),
        Some(review_id.as_str())
    );
    assert_eq!(
        listed.get("raw_trace_persisted").and_then(Value::as_bool),
        Some(false)
    );

    let delete = host.handle(ServiceRequest {
        id: Some("session-review-delete".to_string()),
        method: "session.deleteSkillReview".to_string(),
        params: json!({ "id": review_id }),
    });
    assert!(delete.ok, "{:?}", delete.error);
    let deleted = delete.result.expect("session review delete result");
    assert_eq!(deleted.get("deleted").and_then(Value::as_bool), Some(true));
    assert_eq!(
        deleted.get("remaining_count").and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        deleted
            .get("provider_request_sent")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn routing_accuracy_dashboard_empty_evidence_returns_safe_empty_result() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-accuracy-empty-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    assert!(!host.catalog_path().exists());
    assert!(!host.task_benchmarks_path().exists());
    assert!(!host.routing_regression_baseline_path().exists());
    assert!(!host.trace_imports_path().exists());

    let response = host.handle(ServiceRequest {
        id: Some("routing-accuracy-empty".to_string()),
        method: "routing.accuracyDashboard".to_string(),
        params: json!({
            "window_days": 30,
            "include_history": true,
            "include_recent_evidence": true
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("empty dashboard result");
    assert_eq!(
        result.get("generated_by").and_then(Value::as_str),
        Some("deterministic-service")
    );
    assert_eq!(
        result.get("catalog_available").and_then(Value::as_bool),
        Some(false)
    );
    assert_eq!(
        result
            .pointer("/summary/trace_count")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result
            .pointer("/summary/benchmark_count")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result
            .pointer("/summary/regression_count")
            .and_then(Value::as_u64),
        Some(0)
    );
    assert_eq!(
        result
            .pointer("/agent_rows")
            .and_then(Value::as_array)
            .map(Vec::len),
        Some(0)
    );
    assert!(result
        .pointer("/blocker_notes")
        .and_then(Value::as_array)
        .is_some_and(|notes| notes.iter().any(|note| note
            .as_str()
            .is_some_and(|note| note.contains("No app-local trace imports")))));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(false)
    );
    assert_routing_accuracy_dashboard_safety(&result);
    assert!(!host.catalog_path().exists());
    assert!(!host.task_benchmarks_path().exists());
    assert!(!host.routing_regression_baseline_path().exists());
    assert!(!host.trace_imports_path().exists());
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn routing_accuracy_dashboard_trace_imports_produce_counts_and_agent_rows() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-accuracy-trace-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

    let hit = host.handle(ServiceRequest {
        id: Some("trace-hit".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "content": "Assistant selected llm-fixture with id llm-skill-id.",
            "title": "Hit trace",
            "agent": "claude-code",
            "task": "Analyze local skill posture",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(hit.ok, "{:?}", hit.error);
    let wrong_pick = host.handle(ServiceRequest {
        id: Some("trace-wrong-pick".to_string()),
        method: "trace.importLocal".to_string(),
        params: json!({
            "content": "Assistant selected llm-fixture with id llm-skill-id.",
            "title": "Wrong pick trace",
            "agent": "claude-code",
            "task": "Route release notes",
            "expected_skill_refs": ["other-skill-id"]
        }),
    });
    assert!(wrong_pick.ok, "{:?}", wrong_pick.error);

    let response = host.handle(ServiceRequest {
        id: Some("routing-accuracy-traces".to_string()),
        method: "routing.accuracyDashboard".to_string(),
        params: json!({
            "agent": "claude-code",
            "include_history": true,
            "include_recent_evidence": true,
            "limit": 10
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("trace dashboard result");
    assert_eq!(
        result
            .pointer("/summary/trace_count")
            .and_then(Value::as_u64),
        Some(2)
    );
    assert_eq!(
        result.pointer("/summary/hit_count").and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/summary/wrong_pick_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/summary/accuracy_rate")
            .and_then(Value::as_f64),
        Some(0.5)
    );
    assert_eq!(
        result
            .pointer("/agent_rows/0/agent")
            .and_then(Value::as_str),
        Some("claude-code")
    );
    assert_eq!(
        result
            .pointer("/agent_rows/0/outcomes/hit")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/agent_rows/0/outcomes/wrong_pick")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert!(result
        .pointer("/history_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() == 1));
    assert!(result
        .pointer("/recent_evidence_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.len() >= 2));
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_routing_accuracy_dashboard_safety(&result);
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn routing_accuracy_dashboard_includes_benchmark_regression_and_recent_evidence() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-routing-accuracy-regression-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_llm_skill(&host, &app_data_dir.join("fixture-skill").join("SKILL.md"));

    let save_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-save".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["llm-skill-id"]
        }),
    });
    assert!(save_benchmark.ok, "{:?}", save_benchmark.error);
    let save_baseline = host.handle(ServiceRequest {
        id: Some("routing-baseline-save".to_string()),
        method: "task.saveRoutingBaseline".to_string(),
        params: json!({}),
    });
    assert!(save_baseline.ok, "{:?}", save_baseline.error);
    let update_benchmark = host.handle(ServiceRequest {
        id: Some("benchmark-update".to_string()),
        method: "task.saveBenchmark".to_string(),
        params: json!({
            "id": "local-routing-fixture",
            "title": "Local routing fixture",
            "task": "Analyze local skill posture and execution safety",
            "expected_skill_refs": ["other-skill-id"]
        }),
    });
    assert!(update_benchmark.ok, "{:?}", update_benchmark.error);

    let before_catalog = Catalog::open(&host.catalog_path()).expect("open catalog before");
    let before_records = before_catalog.list_skill_records().expect("records before");
    let before_findings = before_catalog
        .list_rule_findings()
        .expect("findings before");
    let before_snapshots = before_catalog
        .list_all_config_snapshots()
        .expect("snapshots before");
    let baseline_before =
        fs::read_to_string(host.routing_regression_baseline_path()).expect("baseline before");

    let response = host.handle(ServiceRequest {
        id: Some("routing-accuracy-regression".to_string()),
        method: "routing.accuracyDashboard".to_string(),
        params: json!({
            "include_recent_evidence": true,
            "limit": 10
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("regression dashboard result");
    assert_eq!(
        result
            .pointer("/summary/benchmark_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/summary/benchmark_gap_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/summary/regression_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert!(result
        .pointer("/gap_issue_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows
            .iter()
            .any(|row| row.get("source").and_then(Value::as_str)
                == Some("task.detectRoutingRegression"))));
    assert!(result
        .pointer("/recent_evidence_rows")
        .and_then(Value::as_array)
        .is_some_and(|rows| rows.iter().any(
            |row| row.get("source").and_then(Value::as_str) == Some("task.evaluateBenchmarks")
        )));
    assert_eq!(
        result
            .pointer("/agent_rows/0/regression_count")
            .and_then(Value::as_u64),
        Some(1)
    );
    assert_eq!(
        result
            .pointer("/prompt_request/available")
            .and_then(Value::as_bool),
        Some(true)
    );
    assert_routing_accuracy_dashboard_safety(&result);

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
    let baseline_after =
        fs::read_to_string(host.routing_regression_baseline_path()).expect("baseline after");
    assert_eq!(baseline_after, baseline_before);
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
}
