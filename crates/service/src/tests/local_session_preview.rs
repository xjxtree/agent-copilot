use super::*;

#[test]
fn local_session_preview_handles_non_ascii_skill_invocation_text() {
    let unique = unique_suffix();
    let app_data_dir = env::temp_dir().join(format!(
        "skills-copilot-local-session-preview-non-ascii-skill-test-{}-{unique}",
        std::process::id(),
    ));
    let user_home = env::temp_dir().join(format!(
        "skills-copilot-local-session-preview-non-ascii-skill-home-{}-{unique}",
        std::process::id(),
    ));
    let session_root = user_home.join(".codex/sessions/2026/06/22");
    fs::create_dir_all(&session_root).expect("create codex session root");
    fs::write(
        session_root.join("rollout-2026-06-22T08-00-00-non-ascii-skill-fixture.jsonl"),
        "{\"role\":\"user\",\"content\":\"Use skill:配置检查 then skill:fixture-session-skill for diagnostics\"}\n",
    )
    .expect("write codex session");
    let host = ServiceHost {
        app_data_dir: app_data_dir.clone(),
        adapter_ctx: AdapterContext {
            user_home: user_home.clone(),
            project_root: None,
            project_cwd: None,
            extra_roots: Vec::new(),
        },
    };

    let response = host.handle(ServiceRequest {
        id: Some("session-preview-non-ascii-skill".to_string()),
        method: "session.previewLocalSessions".to_string(),
        params: json!({
            "agent": "codex",
            "limit": 10,
            "max_excerpt_chars": 800
        }),
    });

    assert!(response.ok, "{:?}", response.error);
    let result = response.result.expect("local session preview result");
    assert_eq!(result.get("count").and_then(Value::as_u64), Some(1));
    assert_eq!(
        result.get("skill_call_count").and_then(Value::as_u64),
        Some(1)
    );
    assert!(result
        .pointer("/session_rows/0/content_items")
        .and_then(Value::as_array)
        .is_some_and(|items| items.iter().any(|item| {
            item.get("kind").and_then(Value::as_str) == Some("skill_call")
                && item
                    .get("text")
                    .and_then(Value::as_str)
                    .is_some_and(|text| text.contains("fixture-session-skill"))
        })));
    assert!(!provider_call_metadata_path(&app_data_dir).exists());

    let _ = fs::remove_dir_all(app_data_dir);
    let _ = fs::remove_dir_all(user_home);
}
