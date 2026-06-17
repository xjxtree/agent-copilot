use super::*;

impl ServiceHost {
    pub fn preview_mcp_servers(
        &self,
        params: McpServerPreviewParams,
    ) -> Result<McpServerPreviewResult, ServiceError> {
        let limit = params.limit.unwrap_or(50).clamp(1, 200);
        let requested_paths = normalize_string_list(params.authorized_config_paths);
        let adapter_ctx = self.effective_adapter_ctx()?;
        let redaction_roots = self.trace_redaction_roots(&adapter_ctx);
        let mut redactor = PromptRedactor::new(&redaction_roots);

        if requested_paths.is_empty() {
            return Ok(mcp_preview_result(
                McpPreviewResultParts {
                    authorized: false,
                    authorization_required: true,
                    evidence_available: false,
                    evidence_insufficient: true,
                    authorized_paths: Vec::new(),
                    server_rows: Vec::new(),
                    gap_notes: vec![
                    "No MCP config path was authorized; evidence.previewMcpServers does not scan default agent or desktop config locations."
                        .to_string(),
                ],
                    blocker_notes: Vec::new(),
                    redactor,
                },
            ));
        }

        let mut authorized_paths = Vec::new();
        let mut server_rows = Vec::new();
        let mut gap_notes = Vec::new();
        let mut blocker_notes = Vec::new();

        for path in requested_paths {
            let redacted_path = redactor.redact(&path);
            let config_path = PathBuf::from(&path);
            if !config_path.is_absolute() {
                let blocker = "Authorized MCP config paths must be absolute paths.".to_string();
                blocker_notes.push(format!("{redacted_path}: {blocker}"));
                authorized_paths.push(McpServerPreviewPath {
                    path: redacted_path,
                    status: "blocked".to_string(),
                    server_count: 0,
                    blocker: Some(blocker),
                });
                continue;
            }
            if !config_path.exists() {
                let blocker = "Authorized MCP config path does not exist.".to_string();
                blocker_notes.push(format!("{redacted_path}: {blocker}"));
                authorized_paths.push(McpServerPreviewPath {
                    path: redacted_path,
                    status: "blocked".to_string(),
                    server_count: 0,
                    blocker: Some(blocker),
                });
                continue;
            }
            if !config_path.is_file() {
                let blocker = "Authorized MCP config path is not a file.".to_string();
                blocker_notes.push(format!("{redacted_path}: {blocker}"));
                authorized_paths.push(McpServerPreviewPath {
                    path: redacted_path,
                    status: "blocked".to_string(),
                    server_count: 0,
                    blocker: Some(blocker),
                });
                continue;
            }

            let canonical = match config_path.canonicalize() {
                Ok(path) => path,
                Err(error) => {
                    let blocker = redactor.redact(&format!(
                        "Authorized MCP config path could not be resolved: {error}"
                    ));
                    blocker_notes.push(format!("{redacted_path}: {blocker}"));
                    authorized_paths.push(McpServerPreviewPath {
                        path: redacted_path,
                        status: "blocked".to_string(),
                        server_count: 0,
                        blocker: Some(blocker),
                    });
                    continue;
                }
            };
            let canonical_redacted = redactor.redact(&canonical.to_string_lossy());
            let content = match fs::read_to_string(&canonical) {
                Ok(content) => content,
                Err(error) => {
                    let blocker = redactor.redact(&format!(
                        "Authorized MCP config path could not be read: {error}"
                    ));
                    blocker_notes.push(format!("{canonical_redacted}: {blocker}"));
                    authorized_paths.push(McpServerPreviewPath {
                        path: canonical_redacted,
                        status: "blocked".to_string(),
                        server_count: 0,
                        blocker: Some(blocker),
                    });
                    continue;
                }
            };
            let value: Value = match serde_json::from_str(&content) {
                Ok(value) => value,
                Err(error) => {
                    let note = redactor.redact(&format!(
                        "{canonical_redacted}: unsupported or invalid MCP JSON config: {error}"
                    ));
                    gap_notes.push(note);
                    authorized_paths.push(McpServerPreviewPath {
                        path: canonical_redacted,
                        status: "unsupported".to_string(),
                        server_count: 0,
                        blocker: None,
                    });
                    continue;
                }
            };
            let Some(servers) = mcp_servers_object(&value) else {
                gap_notes.push(format!(
                    "{canonical_redacted}: no mcpServers object was found."
                ));
                authorized_paths.push(McpServerPreviewPath {
                    path: canonical_redacted,
                    status: "no-evidence".to_string(),
                    server_count: 0,
                    blocker: None,
                });
                continue;
            };

            let mut server_count = 0usize;
            for (name, server) in servers {
                if server_rows.len() >= limit {
                    gap_notes.push(format!(
                        "MCP server preview stopped after {} server row(s) for bounded read latency.",
                        limit
                    ));
                    break;
                }
                server_count += 1;
                server_rows.push(mcp_server_row(
                    name,
                    server,
                    &canonical_redacted,
                    &mut redactor,
                ));
            }
            authorized_paths.push(McpServerPreviewPath {
                path: canonical_redacted,
                status: "authorized-read-only".to_string(),
                server_count,
                blocker: None,
            });
        }

        let evidence_available = !server_rows.is_empty();
        Ok(mcp_preview_result(McpPreviewResultParts {
            authorized: true,
            authorization_required: false,
            evidence_available,
            evidence_insufficient: !evidence_available,
            authorized_paths,
            server_rows,
            gap_notes,
            blocker_notes,
            redactor,
        }))
    }
}

struct McpPreviewResultParts<'a> {
    authorized: bool,
    authorization_required: bool,
    evidence_available: bool,
    evidence_insufficient: bool,
    authorized_paths: Vec<McpServerPreviewPath>,
    server_rows: Vec<McpServerPreviewRow>,
    gap_notes: Vec<String>,
    blocker_notes: Vec<String>,
    redactor: PromptRedactor<'a>,
}

fn mcp_preview_result(parts: McpPreviewResultParts<'_>) -> McpServerPreviewResult {
    let count = parts.server_rows.len();
    McpServerPreviewResult {
        generated_by: "local-v2.87",
        authorized: parts.authorized,
        authorization_required: parts.authorization_required,
        evidence_available: parts.evidence_available,
        evidence_insufficient: parts.evidence_insufficient,
        count,
        authorized_paths: parts.authorized_paths,
        server_rows: parts.server_rows,
        gap_notes: parts.gap_notes,
        blocker_notes: parts.blocker_notes,
        redaction_summary: agent_session_review_redaction_summary_from(parts.redactor.summary()),
        safety_flags: agent_session_review_safety_flags(),
        read_only: true,
        provider_request_sent: false,
        skill_files_mutated: false,
        agent_config_mutated: false,
        snapshot_created: false,
        triage_mutated: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
        raw_trace_persisted: false,
        credential_accessed: false,
    }
}

fn mcp_servers_object(value: &Value) -> Option<&serde_json::Map<String, Value>> {
    value
        .get("mcpServers")
        .or_else(|| value.pointer("/mcp/servers"))
        .or_else(|| value.get("servers"))
        .and_then(Value::as_object)
}

fn mcp_server_row(
    name: &str,
    server: &Value,
    source_path: &str,
    redactor: &mut PromptRedactor<'_>,
) -> McpServerPreviewRow {
    let command = server
        .get("command")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(&redactor.redact(value), 180));
    let args_count = server
        .get("args")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or(0);
    let env_key_count = server
        .get("env")
        .and_then(Value::as_object)
        .map(serde_json::Map::len)
        .unwrap_or(0);
    let transport = server
        .get("transport")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(&redactor.redact(value), 80))
        .or_else(|| {
            server
                .get("url")
                .and_then(Value::as_str)
                .map(|_| "http".to_string())
        })
        .unwrap_or_else(|| {
            if command.is_some() {
                "stdio".to_string()
            } else {
                "unknown".to_string()
            }
        });
    let redacted_name = truncate_chars(&redactor.redact(name), 120);
    let id_hash = trace_content_hash(&format!("{source_path}\0{redacted_name}"));
    let short_hash = id_hash.chars().take(12).collect::<String>();

    McpServerPreviewRow {
        id: format!("mcp-server-{short_hash}"),
        name: redacted_name.clone(),
        source_path: source_path.to_string(),
        transport,
        command,
        args_count,
        env_key_count,
        evidence_refs: vec![
            format!("mcp.config:{source_path}"),
            format!("mcp.server:{redacted_name}"),
        ],
    }
}
