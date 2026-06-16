use super::*;

pub(super) fn test_host(app_data_dir: PathBuf) -> ServiceHost {
    ServiceHost {
        app_data_dir,
        adapter_ctx: AdapterContext {
            user_home: PathBuf::from("/tmp/home"),
            project_root: None,
            project_cwd: None,
            extra_roots: Vec::new(),
        },
    }
}

pub(super) fn spawn_mock_openai_server() -> (String, std::thread::JoinHandle<String>) {
    spawn_mock_openai_server_with_content("Draft-only review from mock provider.")
}

pub(super) fn spawn_mock_openai_server_with_content(
    content: impl Into<String>,
) -> (String, std::thread::JoinHandle<String>) {
    let content = content.into();
    let listener = std::net::TcpListener::bind("127.0.0.1:0").expect("bind mock provider listener");
    let port = listener
        .local_addr()
        .expect("mock provider local addr")
        .port();
    let handle = std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept mock provider request");
        let mut bytes = Vec::new();
        let mut buffer = [0u8; 1024];
        let mut header_end = None;
        while header_end.is_none() {
            let read =
                std::io::Read::read(&mut stream, &mut buffer).expect("read mock provider headers");
            assert!(read > 0, "mock provider request closed before headers");
            bytes.extend_from_slice(&buffer[..read]);
            header_end = find_header_end(&bytes);
        }
        let header_end = header_end.expect("header end");
        let headers = String::from_utf8_lossy(&bytes[..header_end]).to_string();
        let content_length = headers
            .lines()
            .find_map(|line| {
                let (name, value) = line.split_once(':')?;
                if name.eq_ignore_ascii_case("content-length") {
                    value.trim().parse::<usize>().ok()
                } else {
                    None
                }
            })
            .unwrap_or(0);
        let body_start = header_end + 4;
        while bytes.len().saturating_sub(body_start) < content_length {
            let read =
                std::io::Read::read(&mut stream, &mut buffer).expect("read mock provider body");
            assert!(read > 0, "mock provider request closed before body");
            bytes.extend_from_slice(&buffer[..read]);
        }
        let request_text = String::from_utf8_lossy(&bytes).to_string();
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "content": content
                }
            }],
            "usage": {
                "prompt_tokens": 32,
                "completion_tokens": 8,
                "total_tokens": 40
            }
        })
        .to_string();
        let response = format!(
                "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                body.len(),
                body
            );
        std::io::Write::write_all(&mut stream, response.as_bytes())
            .expect("write mock provider response");
        request_text
    });
    (format!("http://localhost:{port}/v1"), handle)
}

pub(super) fn find_header_end(bytes: &[u8]) -> Option<usize> {
    bytes.windows(4).position(|window| window == b"\r\n\r\n")
}

pub(super) fn seed_catalog_with_llm_skill(host: &ServiceHost, path: &Path) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create skill parent");
    }
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let instance = SkillInstance {
        id: "llm-skill-id".to_string(),
        agent: AgentId::ClaudeCode,
        scope: Scope::AgentGlobal,
        project_root: None,
        path: path.to_path_buf(),
        display_path: path.to_path_buf(),
        definition_id: "llm-definition-id".to_string(),
        name: "llm-fixture".to_string(),
        display_name: "llm-fixture".to_string(),
        description: "Fixture skill for local LLM planning.".to_string(),
        version: None,
        state: SkillState::Loaded,
        enabled: true,
        frontmatter_raw: "name: llm-fixture\ndescription: Fixture skill\n".to_string(),
        body: "Analyze local skill posture. OPENAI_API_KEY=<redacted>".to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: "llm-fingerprint".to_string(),
        mtime: 1,
        first_seen: 1,
        last_seen: 1,
    };
    catalog
        .upsert_skill_instance(&instance)
        .expect("upsert llm fixture skill");
    catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "llm-finding-id".to_string(),
                instance_id: Some("llm-skill-id".to_string()),
                definition_id: Some("llm-definition-id".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message: "Execution-like behavior needs human review; sample-key=fixture-redacted-value must not leak.".to_string(),
                suggestion: Some(
                    "Keep execution disabled and require explicit human confirmation.".to_string(),
                ),
                created_at: 1,
            }])
            .expect("upsert llm fixture finding");
}

pub(super) fn seed_catalog_with_cleanup_queue_fixture(host: &ServiceHost) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let instances = vec![
        cleanup_skill(
            "claude-alpha",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "shared-fixture",
            "Shared Fixture",
            SkillState::Loaded,
            true,
        ),
        cleanup_skill(
            "codex-alpha",
            AgentId::Codex,
            Scope::AgentGlobal,
            "shared-fixture",
            "Shared Fixture",
            SkillState::Loaded,
            true,
        ),
        cleanup_skill(
            "codex-conflict-a",
            AgentId::Codex,
            Scope::AgentGlobal,
            "codex-conflict-definition",
            "Codex Conflict",
            SkillState::Loaded,
            true,
        ),
        cleanup_skill(
            "codex-conflict-b",
            AgentId::Codex,
            Scope::AgentProject,
            "codex-conflict-definition",
            "Codex Conflict",
            SkillState::Loaded,
            true,
        ),
        cleanup_skill(
            "broken-skill",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "broken-definition",
            "Broken Fixture",
            SkillState::Broken,
            false,
        ),
    ];
    catalog
        .upsert_skill_instances(&instances)
        .expect("upsert cleanup skills");
    catalog
        .refresh_rule_findings(&[
            RuleFindingDraft {
                id: "error-finding".to_string(),
                instance_id: Some("codex-alpha".to_string()),
                definition_id: Some("shared-fixture".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message: "Execution permission needs human review.".to_string(),
                suggestion: Some("Keep execution disabled unless explicitly reviewed.".to_string()),
                created_at: 1,
            },
            RuleFindingDraft {
                id: "warn-finding".to_string(),
                instance_id: Some("claude-alpha".to_string()),
                definition_id: Some("shared-fixture".to_string()),
                rule_id: "body.too-long".to_string(),
                severity: "warn".to_string(),
                message: "Skill body is long.".to_string(),
                suggestion: Some("Move reference content into references/.".to_string()),
                created_at: 2,
            },
            RuleFindingDraft {
                id: "ignored-finding".to_string(),
                instance_id: Some("claude-alpha".to_string()),
                definition_id: Some("shared-fixture".to_string()),
                rule_id: "fingerprint.changed".to_string(),
                severity: "info".to_string(),
                message: "Fingerprint changed.".to_string(),
                suggestion: Some("Review the changed skill.".to_string()),
                created_at: 3,
            },
        ])
        .expect("refresh cleanup findings");
    let ignored_key = catalog
        .list_rule_findings()
        .expect("list seeded findings")
        .into_iter()
        .find(|finding| finding.id == "ignored-finding")
        .expect("ignored finding")
        .triage_key;
    catalog
        .set_finding_triage(&ignored_key, "ignored", Some("not actionable"), 4)
        .expect("ignore fixture finding");
    catalog
        .refresh_definitions_and_conflicts(
            &[SkillDefinitionDraft {
                id: "codex-conflict-definition".to_string(),
                canonical_name: "codex-conflict".to_string(),
                description: "Codex conflict fixture.".to_string(),
                active_instance: Some("codex-conflict-a".to_string()),
                has_multiple_instances: true,
                has_conflict: true,
            }],
            &[ConflictGroupDraft {
                id: "codex-runtime-conflict".to_string(),
                definition_id: "codex-conflict-definition".to_string(),
                reason: "content-drift".to_string(),
                winner_id: Some("codex-conflict-a".to_string()),
                instance_ids: vec![
                    "codex-conflict-a".to_string(),
                    "codex-conflict-b".to_string(),
                ],
            }],
        )
        .expect("refresh cleanup conflicts");
}

pub(super) fn seed_catalog_with_stale_drift_fixture(host: &ServiceHost) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let instances = vec![
        stale_drift_skill(
            "stale-drift-alpha",
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "stale-drift-definition",
            "Stale Drift Alpha",
            1,
        ),
        stale_drift_skill(
            "stale-drift-beta",
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "stale-drift-definition",
            "Stale Drift Alpha",
            unix_timestamp_millis(),
        ),
    ];
    catalog
        .upsert_skill_instances(&instances)
        .expect("upsert stale drift skills");
    catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "stale-drift-fingerprint".to_string(),
                    instance_id: Some("stale-drift-alpha".to_string()),
                    definition_id: Some("stale-drift-definition".to_string()),
                    rule_id: "fingerprint.changed".to_string(),
                    severity: "warning".to_string(),
                    message:
                        "Skill content fingerprint changed since the previous scan; token=fixture-redacted-value."
                            .to_string(),
                    suggestion: Some("Review the changed skill before routing to it.".to_string()),
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "stale-drift-warning".to_string(),
                    instance_id: Some("stale-drift-alpha".to_string()),
                    definition_id: Some("stale-drift-definition".to_string()),
                    rule_id: "body.too-long".to_string(),
                    severity: "warn".to_string(),
                    message: "Skill body is long enough to require review.".to_string(),
                    suggestion: Some("Move durable details into references/.".to_string()),
                    created_at: 2,
                },
            ])
            .expect("refresh stale drift findings");
    catalog
        .refresh_definitions_and_conflicts(
            &[SkillDefinitionDraft {
                id: "stale-drift-definition".to_string(),
                canonical_name: "stale-drift-alpha".to_string(),
                description: "Stale drift fixture definition.".to_string(),
                active_instance: Some("stale-drift-alpha".to_string()),
                has_multiple_instances: true,
                has_conflict: true,
            }],
            &[ConflictGroupDraft {
                id: "stale-drift-conflict".to_string(),
                definition_id: "stale-drift-definition".to_string(),
                reason: "content-drift".to_string(),
                winner_id: Some("stale-drift-alpha".to_string()),
                instance_ids: vec![
                    "stale-drift-alpha".to_string(),
                    "stale-drift-beta".to_string(),
                ],
            }],
        )
        .expect("refresh stale drift conflicts");
}

pub(super) fn seed_catalog_with_knowledge_fixture(host: &ServiceHost) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let release_path = host
        .adapter_ctx
        .user_home
        .join(".claude/skills/release-readiness/SKILL.md");
    let disabled_path = host
        .adapter_ctx
        .user_home
        .join(".codex/skills/disabled-research/SKILL.md");
    let instances = vec![
            SkillInstance {
                id: "knowledge-release".to_string(),
                agent: AgentId::ClaudeCode,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: release_path.clone(),
                display_path: release_path,
                definition_id: "knowledge-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local app validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and validation notes."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: false,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "knowledge-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "knowledge-disabled".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: disabled_path.clone(),
                display_path: disabled_path,
                definition_id: "knowledge-disabled-definition".to_string(),
                name: "disabled-research-helper".to_string(),
                display_name: "disabled-research-helper".to_string(),
                description: "Disabled research helper fixture.".to_string(),
                version: None,
                state: SkillState::Broken,
                enabled: false,
                frontmatter_raw:
                    "name: disabled-research-helper\ndescription: Disabled research helper\n"
                        .to_string(),
                body: "Research helper body for listing tests.".to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest::default(),
                fingerprint: "knowledge-disabled-fingerprint".to_string(),
                mtime: unix_timestamp_millis(),
                first_seen: 1,
                last_seen: unix_timestamp_millis(),
            },
        ];
    catalog
        .upsert_skill_instances(&instances)
        .expect("upsert knowledge skills");
    catalog
        .refresh_rule_findings(&[
            RuleFindingDraft {
                id: "knowledge-release-risk".to_string(),
                instance_id: Some("knowledge-release".to_string()),
                definition_id: Some("knowledge-release-definition".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message:
                    "Release readiness fixture requires human review; token=fixture-redacted-value."
                        .to_string(),
                suggestion: Some("Keep release audit actions read-only.".to_string()),
                created_at: 1,
            },
            RuleFindingDraft {
                id: "knowledge-release-drift".to_string(),
                instance_id: Some("knowledge-release".to_string()),
                definition_id: Some("knowledge-release-definition".to_string()),
                rule_id: "fingerprint.changed".to_string(),
                severity: "warning".to_string(),
                message: "Release readiness fingerprint drift fixture.".to_string(),
                suggestion: Some("Review changed release readiness guidance.".to_string()),
                created_at: 2,
            },
        ])
        .expect("refresh knowledge findings");
    catalog
        .refresh_definitions_and_conflicts(
            &[SkillDefinitionDraft {
                id: "knowledge-release-definition".to_string(),
                canonical_name: "release-readiness-audit".to_string(),
                description: "Knowledge release readiness fixture.".to_string(),
                active_instance: Some("knowledge-release".to_string()),
                has_multiple_instances: true,
                has_conflict: true,
            }],
            &[ConflictGroupDraft {
                id: "knowledge-release-conflict".to_string(),
                definition_id: "knowledge-release-definition".to_string(),
                reason: "content-drift".to_string(),
                winner_id: Some("knowledge-release".to_string()),
                instance_ids: vec!["knowledge-release".to_string()],
            }],
        )
        .expect("refresh knowledge conflicts");
}

pub(super) fn seed_catalog_with_similar_grouping_fixture(host: &ServiceHost) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let claude_path = host
        .adapter_ctx
        .user_home
        .join(".claude/skills/release-readiness/SKILL.md");
    let codex_path = host
        .adapter_ctx
        .user_home
        .join(".codex/skills/release-readiness/SKILL.md");
    let research_path = host
        .adapter_ctx
        .user_home
        .join(".codex/skills/release-research/SKILL.md");
    let unrelated_path = host
        .adapter_ctx
        .user_home
        .join(".codex/skills/theme-helper/SKILL.md");
    let instances = vec![
            SkillInstance {
                id: "similar-claude-a".to_string(),
                agent: AgentId::ClaudeCode,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: claude_path.clone(),
                display_path: claude_path,
                definition_id: "similar-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and privacy checks."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-codex-a".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: codex_path.clone(),
                display_path: codex_path,
                definition_id: "similar-release-definition".to_string(),
                name: "release-readiness-audit".to_string(),
                display_name: "release-readiness-audit".to_string(),
                description: "Release readiness audit for local validation and privacy review."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw:
                    "name: release-readiness-audit\ndescription: Release readiness audit\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Prepare release readiness evidence from local catalog findings and privacy checks."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-release-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-codex-research".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: research_path.clone(),
                display_path: research_path,
                definition_id: "similar-research-definition".to_string(),
                name: "release-research-readiness".to_string(),
                display_name: "release-research-readiness".to_string(),
                description:
                    "Research release readiness evidence, validation notes, and privacy findings."
                        .to_string(),
                version: None,
                state: SkillState::Broken,
                enabled: false,
                frontmatter_raw:
                    "name: release-research-readiness\ndescription: Release research readiness\nallowed-tools:\n  - Read\n  - Bash\n"
                        .to_string(),
                body:
                    "Research local release evidence and compare readiness findings for review."
                        .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest {
                    tools: vec!["Read".to_string(), "Bash".to_string()],
                    files: vec!["docs/**".to_string()],
                    network: NetworkAccess::None,
                    network_declared: true,
                    exec: true,
                    exec_declared: true,
                    requires_human: true,
                    requires_human_declared: true,
                },
                fingerprint: "similar-research-fingerprint".to_string(),
                mtime: 1,
                first_seen: 1,
                last_seen: 1,
            },
            SkillInstance {
                id: "similar-unrelated".to_string(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: unrelated_path.clone(),
                display_path: unrelated_path,
                definition_id: "similar-theme-definition".to_string(),
                name: "theme-helper".to_string(),
                display_name: "theme-helper".to_string(),
                description: "Theme helper fixture for unrelated grouping coverage.".to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw: "name: theme-helper\ndescription: Theme helper\n".to_string(),
                body: "Theme helper body for unrelated singleton tests.".to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest::default(),
                fingerprint: "similar-theme-fingerprint".to_string(),
                mtime: unix_timestamp_millis(),
                first_seen: 1,
                last_seen: unix_timestamp_millis(),
            },
        ];
    catalog
        .upsert_skill_instances(&instances)
        .expect("upsert similar grouping skills");
    catalog
        .refresh_rule_findings(&[
            RuleFindingDraft {
                id: "similar-release-exec".to_string(),
                instance_id: Some("similar-claude-a".to_string()),
                definition_id: Some("similar-release-definition".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message:
                    "Release readiness fixture requires human review; token=fixture-redacted-value."
                        .to_string(),
                suggestion: Some("Keep release audit actions read-only.".to_string()),
                created_at: 1,
            },
            RuleFindingDraft {
                id: "similar-research-drift".to_string(),
                instance_id: Some("similar-codex-research".to_string()),
                definition_id: Some("similar-research-definition".to_string()),
                rule_id: "fingerprint.changed".to_string(),
                severity: "warning".to_string(),
                message: "Research readiness fingerprint drift fixture.".to_string(),
                suggestion: Some("Review changed release research guidance.".to_string()),
                created_at: 2,
            },
        ])
        .expect("refresh similar grouping findings");
    catalog
        .refresh_definitions_and_conflicts(
            &[
                SkillDefinitionDraft {
                    id: "similar-release-definition".to_string(),
                    canonical_name: "release-readiness-audit".to_string(),
                    description: "Similar release readiness fixture.".to_string(),
                    active_instance: Some("similar-claude-a".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                },
                SkillDefinitionDraft {
                    id: "similar-research-definition".to_string(),
                    canonical_name: "release-research-readiness".to_string(),
                    description: "Similar release research fixture.".to_string(),
                    active_instance: Some("similar-codex-research".to_string()),
                    has_multiple_instances: false,
                    has_conflict: false,
                },
            ],
            &[ConflictGroupDraft {
                id: "similar-release-conflict".to_string(),
                definition_id: "similar-release-definition".to_string(),
                reason: "duplicate-canonical-name".to_string(),
                winner_id: Some("similar-claude-a".to_string()),
                instance_ids: vec![
                    "similar-claude-a".to_string(),
                    "similar-codex-a".to_string(),
                ],
            }],
        )
        .expect("refresh similar grouping conflicts");
}

pub(super) fn seed_catalog_with_preview_draft_fixture(host: &ServiceHost) {
    seed_catalog_with_similar_grouping_fixture(host);
    let catalog = Catalog::open(&host.catalog_path()).expect("open preview catalog");
    catalog
        .refresh_rule_findings(&[
            RuleFindingDraft {
                id: "preview-frontmatter".to_string(),
                instance_id: Some("similar-claude-a".to_string()),
                definition_id: Some("similar-release-definition".to_string()),
                rule_id: "frontmatter.required-fields".to_string(),
                severity: "warning".to_string(),
                message: "Frontmatter needs normalized required fields.".to_string(),
                suggestion: Some("Add canonical name and clearer description.".to_string()),
                created_at: 1,
            },
            RuleFindingDraft {
                id: "preview-description".to_string(),
                instance_id: Some("similar-codex-a".to_string()),
                definition_id: Some("similar-release-definition".to_string()),
                rule_id: "body.too-long".to_string(),
                severity: "info".to_string(),
                message: "Description should summarize the long release guidance.".to_string(),
                suggestion: Some(
                    "Use a concise task-centered release readiness description.".to_string(),
                ),
                created_at: 2,
            },
            RuleFindingDraft {
                id: "preview-permissions".to_string(),
                instance_id: Some("similar-claude-a".to_string()),
                definition_id: Some("similar-release-definition".to_string()),
                rule_id: "permissions.exec-needs-human".to_string(),
                severity: "error".to_string(),
                message:
                    "Release readiness fixture requires human review; token=fixture-redacted-value."
                        .to_string(),
                suggestion: Some("Keep release audit actions read-only.".to_string()),
                created_at: 3,
            },
            RuleFindingDraft {
                id: "preview-dependency".to_string(),
                instance_id: Some("similar-codex-research".to_string()),
                definition_id: Some("similar-research-definition".to_string()),
                rule_id: "dependency.unknown".to_string(),
                severity: "warning".to_string(),
                message: "Unknown dependency reference needs review.".to_string(),
                suggestion: Some("Document or remove the unknown dependency.".to_string()),
                created_at: 4,
            },
        ])
        .expect("refresh preview draft findings");
}

pub(super) fn seed_catalog_with_many_task_skills(host: &ServiceHost, count: usize) {
    fs::create_dir_all(&host.app_data_dir).expect("create app data");
    let catalog = Catalog::open(&host.catalog_path()).expect("open catalog");
    catalog.init().expect("init catalog");
    let instances = (0..count)
        .map(|index| {
            let id = format!("bulk-readiness-{index:03}");
            let path = PathBuf::from(format!("/tmp/skills-copilot-bulk/{id}/SKILL.md"));
            SkillInstance {
                id: id.clone(),
                agent: AgentId::Codex,
                scope: Scope::AgentGlobal,
                project_root: None,
                path: path.clone(),
                display_path: path,
                definition_id: format!("bulk-readiness-definition-{index:03}"),
                name: format!("release-readiness-bulk-{index:03}"),
                display_name: format!("release-readiness-bulk-{index:03}"),
                description: "Release readiness validation fixture for bounded task aggregation."
                    .to_string(),
                version: None,
                state: SkillState::Loaded,
                enabled: true,
                frontmatter_raw: "name: release-readiness-bulk\ndescription: Release readiness\n"
                    .to_string(),
                body: "Validate release readiness, privacy evidence, and local catalog posture."
                    .to_string(),
                scripts: Vec::new(),
                permissions: PermissionRequest::default(),
                fingerprint: format!("bulk-fingerprint-{index:03}"),
                mtime: index as i64 + 1,
                first_seen: 1,
                last_seen: index as i64 + 1,
            }
        })
        .collect::<Vec<_>>();
    catalog
        .upsert_skill_instances(&instances)
        .expect("upsert bulk readiness skills");
}

pub(super) fn cleanup_skill(
    id: &str,
    agent: AgentId,
    scope: Scope,
    definition_id: &str,
    name: &str,
    state: SkillState,
    enabled: bool,
) -> SkillInstance {
    SkillInstance {
        id: id.to_string(),
        agent,
        scope,
        project_root: None,
        path: PathBuf::from(format!("/tmp/skills-copilot-cleanup/{id}/SKILL.md")),
        display_path: PathBuf::from(format!("/tmp/skills-copilot-cleanup/{id}/SKILL.md")),
        definition_id: definition_id.to_string(),
        name: name.to_string(),
        display_name: name.to_string(),
        description: "Cleanup queue fixture skill.".to_string(),
        version: None,
        state,
        enabled,
        frontmatter_raw: format!("name: {name}\ndescription: Cleanup queue fixture\n"),
        body: "Cleanup queue fixture body.".to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: format!("fingerprint-{id}"),
        mtime: 1,
        first_seen: 1,
        last_seen: 1,
    }
}

pub(super) fn stale_drift_skill(
    id: &str,
    agent: AgentId,
    scope: Scope,
    definition_id: &str,
    name: &str,
    mtime: i64,
) -> SkillInstance {
    SkillInstance {
        id: id.to_string(),
        agent,
        scope,
        project_root: None,
        path: PathBuf::from(format!("/tmp/skills-copilot-stale-drift/{id}/SKILL.md")),
        display_path: PathBuf::from(format!("/tmp/skills-copilot-stale-drift/{id}/SKILL.md")),
        definition_id: definition_id.to_string(),
        name: name.to_string(),
        display_name: name.to_string(),
        description: "Stale drift fixture skill.".to_string(),
        version: None,
        state: SkillState::Loaded,
        enabled: true,
        frontmatter_raw: format!("name: {name}\ndescription: Stale drift fixture\n"),
        body: "Stale drift fixture body.".to_string(),
        scripts: Vec::new(),
        permissions: PermissionRequest::default(),
        fingerprint: format!("fingerprint-{id}"),
        mtime,
        first_seen: 1,
        last_seen: if mtime > 1 { mtime } else { 1 },
    }
}

pub(super) fn unique_suffix() -> u128 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("system clock")
        .as_nanos()
}

pub(super) fn provider_test_secret_env_name(profile_id: &str) -> String {
    let account = format!("provider:{profile_id}");
    let suffix = account
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() {
                ch.to_ascii_uppercase()
            } else {
                '_'
            }
        })
        .collect::<String>();
    format!("SKILLS_COPILOT_TEST_SECRET_{suffix}")
}
