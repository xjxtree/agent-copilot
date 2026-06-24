use super::*;

#[test]
fn task_cockpit_routes_chinese_alibaba_alert_query_to_cms_skill() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-cockpit-alibaba-alert-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_many_task_skills(&host, 90);
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    let skill_path =
        PathBuf::from("/tmp/skills-copilot-alibaba/alibabacloud-cms-alert-rule-create/SKILL.md");
    let alert_skill = SkillInstance {
        id: "alibabacloud-cms-alert-rule-create".to_string(),
        agent: AgentId::ClaudeCode,
        scope: Scope::AgentGlobal,
        project_root: None,
        path: skill_path.clone(),
        display_path: skill_path,
        definition_id: "alibabacloud-cms-alert-rule-create".to_string(),
        name: "alibabacloud-cms-alert-rule-create".to_string(),
        display_name: "alibabacloud-cms-alert-rule-create".to_string(),
        description: "Create and query Alibaba Cloud alert rules via CLI. Supports CMS cloud resource monitoring, ECS/RDS/SLB alert, list alerts, query rules, 告警规则, 监控报警, 查看告警."
            .to_string(),
        version: None,
        state: SkillState::Loaded,
        enabled: true,
        frontmatter_raw: "name: alibabacloud-cms-alert-rule-create\ndescription: Create and query Alibaba Cloud alert rules via CLI. Supports CMS, SLB alert, 查看告警.\n"
            .to_string(),
        body: "Query Alibaba Cloud CMS alert rules for cloud resource monitoring. Use for SLB/ALB load balancer alert history, 告警规则, 监控报警, 查看告警."
            .to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: "alibaba-alert-fingerprint".to_string(),
        mtime: 100,
        first_seen: 100,
        last_seen: 100,
    };
    catalog
        .upsert_skill_instance(&alert_skill)
        .expect("upsert alibaba alert skill");

    let response = host.handle(ServiceRequest {
        id: Some("cockpit-alibaba-alert".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task": "查看阿里云 ALB 报警历史",
            "limit": 5,
            "include_session_review": false,
            "include_provider_observability": false,
            "include_remediation_context": false,
            "include_evidence": false
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task cockpit result");
    assert_eq!(
        result
            .pointer("/summary/recommended_agent")
            .and_then(Value::as_str),
        Some("claude-code")
    );
    assert_eq!(
        result
            .pointer("/summary/top_skill_name")
            .and_then(Value::as_str),
        Some("alibabacloud-cms-alert-rule-create")
    );
    assert_eq!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-cms-alert-rule-create")
    );
    assert!(result
        .pointer("/summary/routing_confidence_score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score > 0));
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
fn task_cockpit_routes_chinese_ecs_disk_load_analysis_to_disk_metric_skill() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-cockpit-ecs-disk-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_many_task_skills(&host, 90);
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    let skill_path =
        PathBuf::from("/tmp/skills-copilot-alibaba/alibabacloud-ebs-disk-metric-analyzer/SKILL.md");
    let disk_skill = SkillInstance {
        id: "alibabacloud-ebs-disk-metric-analyzer".to_string(),
        agent: AgentId::ClaudeCode,
        scope: Scope::AgentGlobal,
        project_root: None,
        path: skill_path.clone(),
        display_path: skill_path,
        definition_id: "alibabacloud-ebs-disk-metric-analyzer".to_string(),
        name: "alibabacloud-ebs-disk-metric-analyzer".to_string(),
        display_name: "alibabacloud-ebs-disk-metric-analyzer".to_string(),
        description: "Analyze Alibaba Cloud ECS and EBS disk metrics, disk load, disk usage, utilization, volume storage, 磁盘负载, 磁盘使用率, 云服务器磁盘分析."
            .to_string(),
        version: None,
        state: SkillState::Loaded,
        enabled: true,
        frontmatter_raw: "name: alibabacloud-ebs-disk-metric-analyzer\ndescription: Analyze Alibaba Cloud ECS/EBS disk metrics and 磁盘负载.\n"
            .to_string(),
        body: "Use this skill for Alibaba Cloud ECS disk load analysis, EBS volume metrics, disk utilization, storage pressure, 磁盘负载情况分析, 云服务器磁盘诊断."
            .to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: "alibaba-ecs-disk-fingerprint".to_string(),
        mtime: 100,
        first_seen: 100,
        last_seen: 100,
    };
    catalog
        .upsert_skill_instance(&disk_skill)
        .expect("upsert alibaba disk skill");

    let response = host.handle(ServiceRequest {
        id: Some("cockpit-ecs-disk".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task": "阿里云 ECS 磁盘负载情况分析",
            "limit": 5,
            "include_session_review": false,
            "include_provider_observability": false,
            "include_remediation_context": false,
            "include_evidence": false
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task cockpit result");
    assert_eq!(
        result
            .pointer("/summary/recommended_agent")
            .and_then(Value::as_str),
        Some("claude-code")
    );
    assert_eq!(
        result
            .pointer("/summary/top_skill_name")
            .and_then(Value::as_str),
        Some("alibabacloud-ebs-disk-metric-analyzer")
    );
    assert_eq!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-ebs-disk-metric-analyzer")
    );
    assert!(result
        .pointer("/summary/routing_confidence_score")
        .and_then(Value::as_u64)
        .is_some_and(|score| score > 0));
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
fn task_cockpit_does_not_route_alb_metrics_to_analyticdb_spark_skill() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-cockpit-alb-no-analyticdb-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_many_task_skills(&host, 90);
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog
        .upsert_skill_instances(&[
            alibaba_task_skill(
                "alibabacloud-analyticdb-spark-application-analysis-helper",
                "Alibaba Cloud AnalyticDB Spark application analysis helper. Reviews Spark application metrics, load, errors, and status.",
                "Use for AnalyticDB Spark job diagnostics, Spark SQL applications, application load analysis, metrics, errors, and 阿里云 分析 情况.",
            ),
            alibaba_task_skill(
                "alibabacloud-cms-manage",
                "Manage Alibaba Cloud CMS and CloudMonitor metrics. Supports ALB/SLB load balancer metrics, error status, 指标, 错误, 监控.",
                "Use for Alibaba Cloud ALB and SLB metrics, CloudMonitor/CMS status, error counts, 负载均衡 指标 与 错误 情况.",
            ),
        ])
        .expect("upsert alibaba alb routing skills");

    let response = host.handle(ServiceRequest {
        id: Some("cockpit-alb-no-analyticdb".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task": "查看下阿里云 ALB 指标与错误情况",
            "limit": 5,
            "include_session_review": false,
            "include_provider_observability": false,
            "include_remediation_context": false,
            "include_evidence": false
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task cockpit result");
    assert_eq!(
        result
            .pointer("/summary/top_skill_name")
            .and_then(Value::as_str),
        Some("alibabacloud-cms-manage")
    );
    assert_eq!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-cms-manage")
    );
    assert_ne!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-analyticdb-spark-application-analysis-helper")
    );
    let route_reason_text = result
        .pointer("/skill_candidate_rows/0/match_reasons")
        .and_then(Value::as_array)
        .map(|reasons| {
            reasons
                .iter()
                .filter_map(Value::as_str)
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default();
    assert!(
        route_reason_text.contains("Matched product/resource scope"),
        "{route_reason_text}"
    );

    let _ = fs::remove_dir_all(app_data_dir);
}

#[test]
fn task_cockpit_does_not_route_ecs_load_to_analyticdb_spark_skill() {
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-cockpit-ecs-no-analyticdb-test-{}-{}",
        std::process::id(),
        unique_suffix(),
    ));
    let host = test_host(app_data_dir.clone());
    seed_catalog_with_many_task_skills(&host, 90);
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog
        .upsert_skill_instances(&[
            alibaba_task_skill(
                "alibabacloud-analyticdb-spark-application-analysis-helper",
                "Alibaba Cloud AnalyticDB Spark application analysis helper. Reviews Spark application metrics, load, errors, and status.",
                "Use for AnalyticDB Spark job diagnostics, Spark SQL applications, application load analysis, metrics, errors, and 阿里云 分析 情况.",
            ),
            alibaba_task_skill(
                "alibabacloud-ecs-diagnose",
                "Diagnose Alibaba Cloud ECS instances. Supports ECS load, CPU, memory, instance metrics, 云服务器负载, 服务器状态.",
                "Use for Alibaba Cloud ECS instance load checks, compute utilization, CPU/memory metrics, 云服务器 负载 情况 分析.",
            ),
        ])
        .expect("upsert alibaba ecs routing skills");

    let response = host.handle(ServiceRequest {
        id: Some("cockpit-ecs-no-analyticdb".to_string()),
        method: "task.buildCockpit".to_string(),
        params: json!({
            "task": "查看下阿里云 ECS 负载情况",
            "limit": 5,
            "include_session_review": false,
            "include_provider_observability": false,
            "include_remediation_context": false,
            "include_evidence": false
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("task cockpit result");
    assert_eq!(
        result
            .pointer("/summary/top_skill_name")
            .and_then(Value::as_str),
        Some("alibabacloud-ecs-diagnose")
    );
    assert_eq!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-ecs-diagnose")
    );
    assert_ne!(
        result
            .pointer("/skill_candidate_rows/0/instance_id")
            .and_then(Value::as_str),
        Some("alibabacloud-analyticdb-spark-application-analysis-helper")
    );

    let _ = fs::remove_dir_all(app_data_dir);
}

fn alibaba_task_skill(id: &str, description: &str, body: &str) -> SkillInstance {
    let skill_path = PathBuf::from(format!("/tmp/skills-copilot-alibaba/{id}/SKILL.md"));
    SkillInstance {
        id: id.to_string(),
        agent: AgentId::ClaudeCode,
        scope: Scope::AgentGlobal,
        project_root: None,
        path: skill_path.clone(),
        display_path: skill_path,
        definition_id: id.to_string(),
        name: id.to_string(),
        display_name: id.to_string(),
        description: description.to_string(),
        version: None,
        state: SkillState::Loaded,
        enabled: true,
        frontmatter_raw: format!("name: {id}\ndescription: {description}\n"),
        body: body.to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: format!("{id}-fingerprint"),
        mtime: 100,
        first_seen: 100,
        last_seen: 100,
    }
}
