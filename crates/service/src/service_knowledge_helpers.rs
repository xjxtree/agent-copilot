fn skill_quality_safety_flags() -> SkillQualitySafetyFlags {
    SkillQualitySafetyFlags {
        read_only: true,
        provider_request_sent: false,
        write_back_allowed: false,
        script_execution_allowed: false,
        config_mutation_allowed: false,
        snapshot_created: false,
        triage_mutation_allowed: false,
        credential_accessed: false,
        raw_secret_returned: false,
        raw_prompt_persisted: false,
        raw_response_persisted: false,
    }
}

fn stale_drift_safety_flags() -> StaleDriftSafetyFlags {
    agent_readiness_safety_flags()
}

fn empty_stale_drift_result(
    filters: StaleDriftFilters,
    catalog_available: bool,
) -> StaleDriftDetectionResult {
    StaleDriftDetectionResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters,
        summary: StaleDriftSummary {
            scanned_skill_count: 0,
            returned_row_count: 0,
            stale_count: 0,
            drift_count: 0,
            high_risk_count: 0,
            medium_risk_count: 0,
            low_risk_count: 0,
            missing_history_count: 0,
            summary:
                "No local catalog is available, so stale/drift detection has no skill evidence."
                    .to_string(),
        },
        stale_drift_rows: Vec::new(),
        readiness_impact_rows: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on stale/drift detection for skill governance."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: StaleDriftPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "stale_drift_detection",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::StaleDriftDetection,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic stale/drift signals using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: stale_drift_safety_flags(),
    }
}

struct StaleDriftRowSignals<'a> {
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    stale_days: u32,
    now_ms: i64,
}

fn stale_drift_row(
    skill: &SkillInstance,
    signals: StaleDriftRowSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> StaleDriftRow {
    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog metadata for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(skill.agent.as_str()),
            redact_for_llm_preview(skill.scope.as_str()),
            skill.enabled,
            redact_for_llm_preview(skill.state.as_str())
        ),
        None,
        Some(skill.id.clone()),
    );
    let modified_age_days = stale_drift_modified_age_days(skill.mtime, signals.now_ms);
    let stale_by_mtime = modified_age_days
        .map(|age| age >= i64::from(signals.stale_days))
        .unwrap_or(false);
    let missing_mtime = skill.mtime <= 0;
    let fingerprint_drift = signals.findings.iter().any(|finding| {
        finding.rule_id == "fingerprint.changed"
            && !finding.suppressed
            && finding.triage_status != "ignored"
    });
    let finding_drift = signals.findings.iter().any(|finding| {
        !finding.suppressed
            && finding.triage_status != "ignored"
            && matches!(
                finding.effective_severity.as_str(),
                "critical" | "error" | "warn" | "warning"
            )
    });
    let source_drift = signals.conflicts.iter().any(|conflict| {
        conflict.reason.contains("drift")
            || conflict.reason.contains("shadow")
            || conflict.reason.contains("collision")
    }) || signals.analysis_groups.iter().any(|group| {
        matches!(
            group.kind.as_str(),
            "source_path_overlap"
                | "enabled_mismatch"
                | "duplicate_name"
                | "canonical_name"
                | "precedence"
                | "malformed"
        )
    });
    let missing_previous_scan = !fingerprint_drift
        && skill.first_seen == skill.last_seen
        && signals
            .findings
            .iter()
            .all(|finding| finding.rule_id != "fingerprint.changed");

    let mut reasons = Vec::new();
    let mut gap_notes = Vec::new();
    let mut evidence_refs = vec![skill_ref];
    if fingerprint_drift {
        reasons.push(
            "Current local findings include explicit fingerprint drift evidence.".to_string(),
        );
    } else {
        gap_notes.push(
            "No explicit previous-scan fingerprint drift finding is available for this skill."
                .to_string(),
        );
    }
    if finding_drift {
        reasons.push(format!(
            "{} open warning/error finding(s) may indicate behavior or metadata drift.",
            signals
                .findings
                .iter()
                .filter(|finding| {
                    !finding.suppressed
                        && finding.triage_status != "ignored"
                        && matches!(
                            finding.effective_severity.as_str(),
                            "critical" | "error" | "warn" | "warning"
                        )
                })
                .count()
        ));
    }
    if source_drift {
        reasons.push(
            "Current conflicts or cross-agent analysis indicate source/identity drift.".to_string(),
        );
    }
    if stale_by_mtime {
        if let Some(age) = modified_age_days {
            reasons.push(format!(
                "Catalog mtime is {age} day(s) old, meeting the {} day stale threshold.",
                signals.stale_days
            ));
        }
    } else if let Some(age) = modified_age_days {
        reasons.push(format!(
            "Catalog mtime age is {age} day(s), below the {} day stale threshold.",
            signals.stale_days
        ));
    } else {
        gap_notes
            .push("Catalog mtime is unavailable, so staleness age is not derived.".to_string());
    }
    if missing_previous_scan {
        gap_notes.push(
            "Previous-scan comparison history is limited; drift is inferred only from current local evidence."
                .to_string(),
        );
    }

    for finding in signals.findings {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        );
        evidence_refs.push(evidence_id);
    }
    for conflict in signals.conflicts {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    for group in signals.analysis_groups {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    if let Some(diagnostic) = signals.diagnostic {
        let evidence_id = push_task_readiness_evidence(
            evidence,
            "adapter_diagnostics",
            diagnostic.agent,
            format!(
                "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                redact_for_llm_preview(diagnostic.display_name),
                redact_for_llm_preview(diagnostic.status),
                redact_for_llm_preview(diagnostic.access.writable_status),
                redact_for_llm_preview(diagnostic.access.install_status)
            ),
            None,
            Some(skill.id.clone()),
        );
        evidence_refs.push(evidence_id);
    }
    reasons.sort();
    reasons.dedup();
    gap_notes.sort();
    gap_notes.dedup();

    let drift_signals = StaleDriftSignals {
        fingerprint_drift,
        finding_drift,
        source_drift,
        modified_age_days,
        stale_by_mtime,
        missing_mtime,
        missing_previous_scan,
        related_finding_count: signals.findings.len(),
        related_conflict_count: signals.conflicts.len(),
        related_analysis_count: signals.analysis_groups.len(),
    };
    let score = stale_drift_score(&drift_signals, skill);
    let readiness_impact = stale_drift_readiness_impact(score, &drift_signals, skill);

    StaleDriftRow {
        rank: 0,
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.as_str().to_string(),
        scope: skill.scope.as_str().to_string(),
        enabled: skill.enabled,
        state: skill.state.as_str().to_string(),
        stale_drift_score: score,
        stale_drift_band: stale_drift_band(score),
        drift_signals,
        readiness_impact,
        reasons,
        gap_notes,
        evidence_refs,
        safety_flags: stale_drift_safety_flags(),
    }
}

fn stale_drift_modified_age_days(mtime: i64, now_ms: i64) -> Option<i64> {
    if mtime <= 0 || now_ms <= 0 || mtime > now_ms {
        return None;
    }
    Some((now_ms - mtime) / 86_400_000)
}

fn stale_drift_score(signals: &StaleDriftSignals, skill: &SkillInstance) -> u8 {
    let mut score = 0i16;
    if signals.fingerprint_drift {
        score += 35;
    }
    if signals.finding_drift {
        score += 20;
    }
    if signals.source_drift {
        score += 25;
    }
    if signals.stale_by_mtime {
        score += 20;
    } else if signals.missing_mtime {
        score += 6;
    }
    if !skill.enabled {
        score += 4;
    }
    if skill.state.as_str() != "loaded" {
        score += 10;
    }
    if signals.missing_previous_scan {
        score += 4;
    }
    score.clamp(0, 100) as u8
}

fn stale_drift_band(score: u8) -> &'static str {
    match score {
        80..=100 => "high",
        45..=79 => "medium",
        1..=44 => "low",
        _ => "clear",
    }
}

fn stale_drift_readiness_impact(
    score: u8,
    signals: &StaleDriftSignals,
    skill: &SkillInstance,
) -> Option<StaleDriftReadinessImpact> {
    let mut notes = Vec::new();
    if signals.fingerprint_drift {
        notes.push(
            "Fingerprint drift should be reviewed before treating this skill as a stable routing target."
                .to_string(),
        );
    }
    if signals.source_drift {
        notes.push("Source or identity drift may make cross-agent routing ambiguous.".to_string());
    }
    if signals.finding_drift {
        notes.push(
            "Open warning/error findings can reduce deterministic task readiness.".to_string(),
        );
    }
    if signals.stale_by_mtime {
        notes.push("Stale mtime may indicate skill instructions have not kept pace with current task expectations.".to_string());
    }
    if !skill.enabled || skill.state.as_str() != "loaded" {
        notes.push(
            "Disabled or non-loaded state can block readiness regardless of match quality."
                .to_string(),
        );
    }
    if notes.is_empty() {
        return None;
    }
    Some(StaleDriftReadinessImpact {
        impact_level: stale_drift_band(score),
        readiness_risk_score: score,
        notes,
    })
}

fn stale_drift_readiness_impact_row(row: &StaleDriftRow) -> Option<StaleDriftReadinessImpactRow> {
    row.readiness_impact
        .as_ref()
        .map(|impact| StaleDriftReadinessImpactRow {
            instance_id: row.instance_id.clone(),
            skill_name: row.skill_name.clone(),
            agent: row.agent.clone(),
            impact_level: impact.impact_level,
            stale_drift_score: row.stale_drift_score,
            notes: impact.notes.clone(),
            evidence_refs: row.evidence_refs.clone(),
        })
}

fn stale_drift_summary(scanned_skill_count: usize, rows: &[StaleDriftRow]) -> StaleDriftSummary {
    let stale_count = rows
        .iter()
        .filter(|row| row.drift_signals.stale_by_mtime)
        .count();
    let drift_count = rows
        .iter()
        .filter(|row| {
            row.drift_signals.fingerprint_drift
                || row.drift_signals.finding_drift
                || row.drift_signals.source_drift
        })
        .count();
    let high_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "high")
        .count();
    let medium_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "medium")
        .count();
    let low_risk_count = rows
        .iter()
        .filter(|row| row.stale_drift_band == "low")
        .count();
    let missing_history_count = rows
        .iter()
        .filter(|row| row.drift_signals.missing_previous_scan || row.drift_signals.missing_mtime)
        .count();
    let summary = if rows.is_empty() {
        "No visible skills matched the stale/drift detection filters.".to_string()
    } else {
        format!(
            "Detected {stale_count} stale skill row(s), {drift_count} drift row(s), and {high_risk_count} high-risk row(s) from deterministic local catalog evidence."
        )
    };
    StaleDriftSummary {
        scanned_skill_count,
        returned_row_count: rows.len(),
        stale_count,
        drift_count,
        high_risk_count,
        medium_risk_count,
        low_risk_count,
        missing_history_count,
        summary,
    }
}

fn stale_drift_blocker_notes(rows: &[StaleDriftRow]) -> Vec<String> {
    let mut notes = Vec::new();
    if rows.iter().any(|row| row.drift_signals.fingerprint_drift) {
        notes.push(
            "Fingerprint drift evidence is present; review before relying on affected skills for routing."
                .to_string(),
        );
    }
    if rows.iter().any(|row| row.drift_signals.source_drift) {
        notes.push(
            "Source or identity drift evidence is present; cross-agent routing may be ambiguous."
                .to_string(),
        );
    }
    if rows.iter().any(|row| row.stale_drift_band == "high") {
        notes.push(
            "High stale/drift risk is based on local evidence only and does not enable writes or automatic cleanup."
                .to_string(),
        );
    }
    notes
}

fn knowledge_search_safety_flags() -> KnowledgeSearchSafetyFlags {
    agent_readiness_safety_flags()
}

fn knowledge_search_filters(params: &KnowledgeSearchParams) -> KnowledgeSearchFilters {
    let query = params
        .query
        .as_deref()
        .map(str::trim)
        .filter(|query| !query.is_empty())
        .map(redact_for_llm_preview);
    let mut normalized_terms = query
        .as_deref()
        .map(task_readiness_terms)
        .unwrap_or_default();
    if let Some(keyword) = params.keyword.as_deref().map(str::trim) {
        if !keyword.is_empty() {
            normalized_terms.extend(task_readiness_terms(keyword));
        }
    }
    normalized_terms.sort();
    normalized_terms.dedup();
    KnowledgeSearchFilters {
        query,
        normalized_terms,
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        limit: params.limit.unwrap_or(25).clamp(1, 100),
        risk: params
            .risk
            .as_deref()
            .map(normalize_filter_value)
            .filter(|risk| !risk.is_empty()),
        scope: params
            .scope
            .as_deref()
            .map(normalize_filter_value)
            .filter(|scope| !scope.is_empty()),
        enabled: params.enabled,
        tool: params
            .tool
            .as_deref()
            .map(normalize_filter_value)
            .filter(|tool| !tool.is_empty()),
        keyword: params
            .keyword
            .as_deref()
            .map(normalize_filter_value)
            .filter(|keyword| !keyword.is_empty()),
    }
}

fn normalize_filter_value(value: &str) -> String {
    value.trim().to_ascii_lowercase().replace(['_', ' '], "-")
}

fn empty_knowledge_search_result(
    filters: KnowledgeSearchFilters,
    catalog_available: bool,
) -> KnowledgeSearchResult {
    KnowledgeSearchResult {
        generated_by: "deterministic-service",
        catalog_available,
        summary: KnowledgeSearchSummary {
            indexed_skill_count: 0,
            matched_row_count: 0,
            returned_row_count: 0,
            enabled_count: 0,
            disabled_count: 0,
            high_risk_count: 0,
            stale_or_drift_count: 0,
            summary: "No local catalog is available, so knowledge search has no skill evidence."
                .to_string(),
        },
        filters,
        rows: Vec::new(),
        facets: KnowledgeSearchFacets::default(),
        gap_notes: vec![
            "Run a local scan before relying on knowledge search for skill discovery.".to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: KnowledgeSearchPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "knowledge_search",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::KnowledgeSearch,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic local knowledge search results.".to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: knowledge_search_safety_flags(),
    }
}

struct KnowledgeSearchRowSignals<'a> {
    query_terms: &'a [String],
    filters: &'a KnowledgeSearchFilters,
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    quality: Option<&'a SkillQualityScoreResult>,
    readiness: Option<&'a TaskReadinessCandidate>,
    stale: Option<&'a StaleDriftRow>,
    redaction_roots: &'a [(String, &'static str)],
}

fn knowledge_search_row(
    skill: &SkillDetailRecord,
    signals: KnowledgeSearchRowSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> Option<KnowledgeSearchRow> {
    if let Some(scope) = signals.filters.scope.as_deref() {
        if normalize_filter_value(&skill.scope) != scope {
            return None;
        }
    }
    if let Some(enabled) = signals.filters.enabled {
        if skill.enabled != enabled {
            return None;
        }
    }

    let tools = knowledge_tools(&skill.permissions);
    if let Some(tool) = signals.filters.tool.as_deref() {
        if !tools
            .iter()
            .any(|candidate| normalize_filter_value(candidate) == tool)
        {
            return None;
        }
    }

    let keywords = knowledge_keywords(skill, &tools, signals.findings);
    if let Some(keyword) = signals.filters.keyword.as_deref() {
        if !keywords
            .iter()
            .any(|candidate| normalize_filter_value(candidate).contains(keyword))
        {
            return None;
        }
    }

    let risk_level = signals
        .readiness
        .map(|readiness| readiness.enabled_scope_risk_state.risk_level)
        .unwrap_or_else(|| {
            task_readiness_risk_level(
                signals.findings,
                signals.conflicts,
                signals.analysis_groups,
                skill,
            )
        });
    if let Some(risk) = signals.filters.risk.as_deref() {
        if risk_level != risk
            && !signals.findings.iter().any(|finding| {
                normalize_filter_value(&finding.effective_severity) == risk
                    || normalize_filter_value(&finding.rule_id).contains(risk)
            })
        {
            return None;
        }
    }

    let (matched_fields, matched_terms) =
        knowledge_match_terms(skill, &tools, &keywords, signals.query_terms);
    if !signals.query_terms.is_empty() && matched_terms.is_empty() {
        return None;
    }

    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog knowledge row for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(&skill.agent),
            redact_for_llm_preview(&skill.scope),
            skill.enabled,
            redact_for_llm_preview(&skill.state)
        ),
        None,
        Some(skill.id.clone()),
    );
    let mut evidence_refs = vec![skill_ref];
    for finding in signals.findings {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        ));
    }
    for conflict in signals.conflicts {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        ));
    }
    for group in signals.analysis_groups {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        ));
    }
    if let Some(diagnostic) = signals.diagnostic {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "adapter_diagnostics",
            diagnostic.agent,
            format!(
                "{} adapter diagnostics: status={}, writable_status={}, install_status={}",
                redact_for_llm_preview(diagnostic.display_name),
                redact_for_llm_preview(diagnostic.status),
                redact_for_llm_preview(diagnostic.access.writable_status),
                redact_for_llm_preview(diagnostic.access.install_status)
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(quality) = signals.quality {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "quality_score",
            &skill.id,
            format!(
                "V2.43 quality score {} / 100 ({})",
                quality.score, quality.band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(stale) = signals.stale {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "stale_drift",
            &skill.id,
            format!(
                "V2.51 stale/drift score {} / 100 ({})",
                stale.stale_drift_score, stale.stale_drift_band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    evidence_refs.sort();
    evidence_refs.dedup();

    let mut match_reasons = Vec::new();
    if matched_terms.is_empty() {
        match_reasons.push(
            "Listed from local catalog evidence without a lexical query constraint.".to_string(),
        );
    } else {
        match_reasons.push(format!(
            "Matched query term(s): {}.",
            matched_terms
                .iter()
                .take(8)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !skill.description.trim().is_empty() {
        match_reasons.push(format!(
            "Description evidence: {}",
            redact_for_llm_preview(&knowledge_snippet(&skill.description, signals.query_terms))
        ));
    }
    if let Some(readiness) = signals.readiness {
        match_reasons.push(format!(
            "Task readiness context is {} ({}/100) with risk {}.",
            readiness.band, readiness.score, readiness.enabled_scope_risk_state.risk_level
        ));
    }
    if let Some(stale) = signals.stale {
        match_reasons.push(format!(
            "Stale/drift context is {} ({}/100).",
            stale.stale_drift_band, stale.stale_drift_score
        ));
    }

    let rules = signals
        .findings
        .iter()
        .map(|finding| finding.rule_id.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let capability_tags = knowledge_capability_tags(skill, signals.diagnostic);
    let risk_tags = knowledge_risk_tags(risk_level, signals.findings, signals.stale);

    Some(KnowledgeSearchRow {
        rank: 0,
        instance_id: skill.id.clone(),
        definition_id: skill.definition_id.clone(),
        skill_name: redact_for_llm_preview(&skill.name),
        agent: skill.agent.clone(),
        scope: skill.scope.clone(),
        enabled: skill.enabled,
        state: skill.state.clone(),
        source: KnowledgeSearchSource {
            source_path: redact_path_string(&skill.path, signals.redaction_roots),
            display_path: redact_path_string(&skill.display_path, signals.redaction_roots),
            root_provenance: knowledge_root_provenance(skill),
            fingerprint: redact_for_llm_preview(&skill.fingerprint),
        },
        purpose_snippet: knowledge_optional_snippet(&skill.body, signals.query_terms),
        description_snippet: knowledge_optional_snippet(&skill.description, signals.query_terms),
        matched_fields,
        match_reasons,
        keywords,
        tools,
        rules,
        capability_tags,
        risk_tags,
        quality_context: signals.quality.map(|quality| KnowledgeQualityContext {
            score: quality.score,
            grade: quality.grade,
            band: quality.band,
            reasons: quality.reasons.iter().take(3).cloned().collect(),
        }),
        readiness_context: signals
            .readiness
            .map(|readiness| KnowledgeReadinessContext {
                score: readiness.score,
                band: readiness.band,
                risk_level: readiness.enabled_scope_risk_state.risk_level,
                risk_summary: readiness.enabled_scope_risk_state.risk_summary.clone(),
                gap_count: readiness.missing_gap_notes.len(),
                blocker_count: readiness.blocker_risk_notes.len(),
            }),
        stale_drift_context: signals.stale.map(|stale| KnowledgeStaleDriftContext {
            score: stale.stale_drift_score,
            band: stale.stale_drift_band,
            fingerprint_drift: stale.drift_signals.fingerprint_drift,
            finding_drift: stale.drift_signals.finding_drift,
            source_drift: stale.drift_signals.source_drift,
            stale_by_mtime: stale.drift_signals.stale_by_mtime,
            readiness_impact_level: stale
                .readiness_impact
                .as_ref()
                .map(|impact| impact.impact_level),
        }),
        evidence_refs,
        safety_flags: knowledge_search_safety_flags(),
    })
}

fn knowledge_related_findings(
    findings: &[RuleFindingRecord],
    skill: &SkillDetailRecord,
) -> Vec<RuleFindingRecord> {
    findings
        .iter()
        .filter(|finding| {
            finding.instance_id.as_deref() == Some(skill.id.as_str())
                || finding.definition_id.as_deref() == Some(skill.definition_id.as_str())
        })
        .cloned()
        .collect()
}

fn knowledge_related_conflicts(
    conflicts: &[ConflictGroupRecord],
    skill: &SkillDetailRecord,
) -> Vec<ConflictGroupRecord> {
    conflicts
        .iter()
        .filter(|conflict| {
            conflict.definition_id == skill.definition_id
                || conflict
                    .instance_ids
                    .iter()
                    .any(|instance_id| instance_id == &skill.id)
        })
        .cloned()
        .collect()
}

fn knowledge_related_analysis(
    groups: &[CrossAgentAnalysisGroup],
    skill: &SkillDetailRecord,
) -> Vec<CrossAgentAnalysisGroup> {
    groups
        .iter()
        .filter(|group| {
            group
                .instance_ids
                .iter()
                .any(|instance_id| instance_id == &skill.id)
        })
        .cloned()
        .collect()
}

fn knowledge_tools(permissions: &Value) -> Vec<String> {
    let normalized = permissions.get("normalized").unwrap_or(permissions);
    let mut tools = normalized
        .get("tools")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::trim)
        .filter(|tool| !tool.is_empty())
        .map(redact_for_llm_preview)
        .collect::<Vec<_>>();
    tools.sort();
    tools.dedup();
    tools
}

fn knowledge_keywords(
    skill: &SkillDetailRecord,
    tools: &[String],
    findings: &[RuleFindingRecord],
) -> Vec<String> {
    let mut terms = BTreeSet::new();
    for value in [
        skill.name.as_str(),
        skill.description.as_str(),
        skill.frontmatter_raw.as_str(),
        skill.body.as_str(),
    ] {
        for term in task_readiness_terms(value).into_iter().take(20) {
            terms.insert(term);
        }
    }
    for tool in tools {
        terms.insert(tool.to_ascii_lowercase());
    }
    for finding in findings {
        terms.insert(finding.rule_id.clone());
    }
    terms.into_iter().take(30).collect()
}

fn knowledge_match_terms(
    skill: &SkillDetailRecord,
    tools: &[String],
    keywords: &[String],
    query_terms: &[String],
) -> (Vec<String>, Vec<String>) {
    let fields = [
        ("name", skill.name.as_str()),
        ("description", skill.description.as_str()),
        ("frontmatter", skill.frontmatter_raw.as_str()),
        ("body", skill.body.as_str()),
        ("agent", skill.agent.as_str()),
        ("scope", skill.scope.as_str()),
    ];
    let tools_joined = tools.join(" ");
    let keywords_joined = keywords.join(" ");
    let derived_fields = [
        ("tools", tools_joined.as_str()),
        ("keywords", keywords_joined.as_str()),
    ];
    let mut matched_fields = BTreeSet::new();
    let mut matched_terms = BTreeSet::new();
    for term in query_terms {
        for (field, value) in fields.iter().chain(derived_fields.iter()) {
            if value.to_ascii_lowercase().contains(term) {
                matched_fields.insert((*field).to_string());
                matched_terms.insert(term.clone());
            }
        }
    }
    (
        matched_fields.into_iter().collect(),
        matched_terms.into_iter().collect(),
    )
}

fn knowledge_optional_snippet(value: &str, query_terms: &[String]) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(knowledge_snippet(trimmed, query_terms))
    }
}

fn knowledge_snippet(value: &str, query_terms: &[String]) -> String {
    let compact = value.split_whitespace().collect::<Vec<_>>().join(" ");
    let start = query_terms
        .iter()
        .filter_map(|term| compact.to_ascii_lowercase().find(term))
        .min()
        .unwrap_or(0);
    let start = start.saturating_sub(40);
    let mut snippet = compact.chars().skip(start).take(180).collect::<String>();
    if start > 0 {
        snippet.insert_str(0, "...");
    }
    if compact.chars().count() > start + snippet.chars().count() {
        snippet.push_str("...");
    }
    redact_for_llm_preview(&snippet)
}

fn knowledge_capability_tags(
    skill: &SkillDetailRecord,
    diagnostic: Option<&AdapterDiagnosticsRecord>,
) -> Vec<String> {
    let mut tags = BTreeSet::new();
    tags.insert(skill.agent.clone());
    tags.insert(skill.scope.clone());
    tags.insert(if skill.enabled { "enabled" } else { "disabled" }.to_string());
    tags.insert(skill.state.clone());
    tags.insert("local-catalog".to_string());
    tags.insert("read-only".to_string());
    if let Some(diagnostic) = diagnostic {
        tags.insert(format!("adapter-{}", diagnostic.status));
        tags.insert(format!("writable-{}", diagnostic.access.writable_status));
        tags.insert(format!("install-{}", diagnostic.access.install_status));
    }
    tags.into_iter().collect()
}

fn knowledge_risk_tags(
    risk_level: &'static str,
    findings: &[RuleFindingRecord],
    stale: Option<&StaleDriftRow>,
) -> Vec<String> {
    let mut tags = BTreeSet::new();
    tags.insert(format!("risk-{risk_level}"));
    for finding in findings {
        tags.insert(format!("severity-{}", finding.effective_severity));
        tags.insert(format!("rule-{}", finding.rule_id));
    }
    if let Some(stale) = stale {
        tags.insert(format!("stale-drift-{}", stale.stale_drift_band));
        if stale.drift_signals.fingerprint_drift {
            tags.insert("fingerprint-drift".to_string());
        }
        if stale.drift_signals.source_drift {
            tags.insert("source-drift".to_string());
        }
        if stale.drift_signals.stale_by_mtime {
            tags.insert("mtime-stale".to_string());
        }
    }
    tags.into_iter().collect()
}

fn knowledge_root_provenance(skill: &SkillDetailRecord) -> String {
    if skill.scope == Scope::AgentProject.as_str() {
        "project-scope catalog evidence".to_string()
    } else if skill.scope == Scope::ToolGlobal.as_str() {
        "tool-global catalog evidence".to_string()
    } else {
        "agent-scope catalog evidence".to_string()
    }
}

fn knowledge_row_rank_score(row: &KnowledgeSearchRow) -> i16 {
    let mut score = 0i16;
    score += (row.matched_fields.len() as i16 * 12).min(48);
    if let Some(readiness) = &row.readiness_context {
        score += i16::from(readiness.score) / 4;
    }
    if let Some(quality) = &row.quality_context {
        score += i16::from(quality.score) / 5;
    }
    if row.enabled {
        score += 8;
    }
    if row.state == "loaded" {
        score += 5;
    }
    if let Some(stale) = &row.stale_drift_context {
        score -= i16::from(stale.score) / 8;
    }
    score
}

fn knowledge_search_facets(rows: &[KnowledgeSearchRow]) -> KnowledgeSearchFacets {
    let mut facets = KnowledgeSearchFacets::default();
    for row in rows {
        *facets.agents.entry(row.agent.clone()).or_insert(0) += 1;
        *facets.scopes.entry(row.scope.clone()).or_insert(0) += 1;
        *facets.states.entry(row.state.clone()).or_insert(0) += 1;
        *facets
            .enabled
            .entry(if row.enabled { "true" } else { "false" }.to_string())
            .or_insert(0) += 1;
        if let Some(readiness) = &row.readiness_context {
            *facets
                .risks
                .entry(readiness.risk_level.to_string())
                .or_insert(0) += 1;
        } else if let Some(tag) = row
            .risk_tags
            .iter()
            .find_map(|tag| tag.strip_prefix("risk-").map(ToOwned::to_owned))
        {
            *facets.risks.entry(tag).or_insert(0) += 1;
        }
        for tool in row.tools.iter().take(12) {
            *facets.tools.entry(tool.clone()).or_insert(0) += 1;
        }
        for keyword in row.keywords.iter().take(12) {
            *facets.keywords.entry(keyword.clone()).or_insert(0) += 1;
        }
    }
    facets
}

fn knowledge_search_blocker_notes(rows: &[KnowledgeSearchRow]) -> Vec<String> {
    let mut notes = Vec::new();
    if rows.iter().any(|row| !row.enabled || row.state != "loaded") {
        notes.push(
            "Some matched knowledge rows are disabled or not loaded; discovery does not make them ready routing targets."
                .to_string(),
        );
    }
    if rows.iter().any(|row| {
        row.risk_tags
            .iter()
            .any(|tag| tag == "risk-high" || tag == "risk-blocked")
    }) {
        notes.push(
            "High or blocked risk rows are included for inspection only; no write or execution action is enabled."
                .to_string(),
        );
    }
    if rows.iter().any(|row| {
        row.stale_drift_context
            .as_ref()
            .is_some_and(|context| context.score > 0)
    }) {
        notes.push(
            "Stale/drift context comes from current local catalog evidence and does not create an index artifact."
                .to_string(),
        );
    }
    if notes.is_empty() {
        notes.push(
            "Knowledge search used local catalog evidence only and found no matched-row blockers."
                .to_string(),
        );
    }
    notes
}

fn knowledge_search_summary(
    indexed_skill_count: usize,
    matched_row_count: usize,
    rows: &[KnowledgeSearchRow],
) -> KnowledgeSearchSummary {
    let enabled_count = rows.iter().filter(|row| row.enabled).count();
    let disabled_count = rows.len().saturating_sub(enabled_count);
    let high_risk_count = rows
        .iter()
        .filter(|row| {
            row.risk_tags
                .iter()
                .any(|tag| tag == "risk-high" || tag == "risk-blocked")
        })
        .count();
    let stale_or_drift_count = rows
        .iter()
        .filter(|row| {
            row.stale_drift_context
                .as_ref()
                .is_some_and(|context| context.score > 0)
        })
        .count();
    let summary = if rows.is_empty() {
        "No local knowledge rows matched the selected search filters.".to_string()
    } else {
        format!(
            "Returned {} of {} matched local knowledge row(s) from {} indexed visible skill(s); {} row(s) are enabled and {} row(s) carry high/blocking risk.",
            rows.len(),
            matched_row_count,
            indexed_skill_count,
            enabled_count,
            high_risk_count
        )
    };
    KnowledgeSearchSummary {
        indexed_skill_count,
        matched_row_count,
        returned_row_count: rows.len(),
        enabled_count,
        disabled_count,
        high_risk_count,
        stale_or_drift_count,
        summary,
    }
}

fn similar_skill_grouping_safety_flags() -> SimilarSkillGroupingSafetyFlags {
    agent_readiness_safety_flags()
}

fn similar_skill_grouping_filters(
    params: &SimilarSkillGroupingParams,
) -> SimilarSkillGroupingFilters {
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();
    let min_score = params.min_score.unwrap_or(45.0).clamp(0.0, 100.0).round() as u8;
    SimilarSkillGroupingFilters {
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        limit: params.limit.unwrap_or(25).clamp(1, 100),
        min_score,
        include_singletons: params.include_singletons,
        candidate_instance_ids,
    }
}

fn empty_similar_skill_grouping_result(
    filters: SimilarSkillGroupingFilters,
    catalog_available: bool,
) -> SimilarSkillGroupingResult {
    SimilarSkillGroupingResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters: filters.clone(),
        summary: SimilarSkillGroupingSummary {
            indexed_skill_count: 0,
            candidate_skill_count: 0,
            matched_group_count: 0,
            returned_group_count: 0,
            duplicate_group_count: 0,
            confusable_group_count: 0,
            coverage_redundancy_group_count: 0,
            routing_ambiguity_count: 0,
            summary: "No local catalog is available, so similar skill grouping has no skill evidence."
                .to_string(),
        },
        groups: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on similar skill grouping for dedupe or routing review."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: SimilarSkillGroupingPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "similar_skill_grouping",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::SimilarSkillGrouping,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic similar skill grouping using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: similar_skill_grouping_safety_flags(),
    }
}

struct SimilarSkillCandidateSignals<'a> {
    findings: &'a [RuleFindingRecord],
    conflicts: &'a [ConflictGroupRecord],
    analysis_groups: &'a [CrossAgentAnalysisGroup],
    diagnostic: Option<&'a AdapterDiagnosticsRecord>,
    quality: Option<&'a SkillQualityScoreResult>,
    stale: Option<&'a StaleDriftRow>,
    redaction_roots: &'a [(String, &'static str)],
}

#[derive(Debug, Clone)]
struct SimilarSkillCandidate {
    detail: SkillDetailRecord,
    member: SimilarSkillMember,
    canonical_key: String,
    terms: Vec<String>,
    tools: Vec<String>,
    rules: Vec<String>,
    capability_tags: Vec<String>,
    risk_tags: Vec<String>,
    source_signals: Vec<String>,
}

#[derive(Debug, Clone)]
struct SimilarSkillPair {
    left: usize,
    right: usize,
    score: u8,
    group_type: &'static str,
    coverage_redundancy: &'static str,
    routing_ambiguity: &'static str,
    ambiguity_risk: &'static str,
    why_grouped: Vec<String>,
    shared_terms: Vec<String>,
    shared_tools: Vec<String>,
    shared_rules: Vec<String>,
    shared_capability_tags: Vec<String>,
    shared_risk_tags: Vec<String>,
    shared_source_signals: Vec<String>,
}

fn similar_skill_candidate(
    skill: &SkillDetailRecord,
    signals: SimilarSkillCandidateSignals<'_>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> SimilarSkillCandidate {
    let tools = knowledge_tools(&skill.permissions);
    let keywords = knowledge_keywords(skill, &tools, signals.findings);
    let rules = signals
        .findings
        .iter()
        .map(|finding| finding.rule_id.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let risk_level = task_readiness_risk_level(
        signals.findings,
        signals.conflicts,
        signals.analysis_groups,
        skill,
    );
    let capability_tags = knowledge_capability_tags(skill, signals.diagnostic);
    let risk_tags = knowledge_risk_tags(risk_level, signals.findings, signals.stale);
    let mut source_signals = BTreeSet::new();
    source_signals.insert(knowledge_root_provenance(skill));
    source_signals.insert(format!(
        "source-path:{}",
        redact_path_string(&skill.display_path, signals.redaction_roots)
    ));
    source_signals.insert(format!(
        "fingerprint:{}",
        redact_for_llm_preview(&skill.fingerprint)
    ));
    let parent = Path::new(&skill.display_path)
        .parent()
        .map(|path| redact_path_string(path, signals.redaction_roots));
    if let Some(parent) = parent {
        source_signals.insert(format!("source-root:{parent}"));
    }

    let skill_ref = push_task_readiness_evidence(
        evidence,
        "skill",
        &skill.id,
        format!(
            "Catalog similar-skill member for `{}` ({}, {}, enabled={}, state={})",
            redact_for_llm_preview(&skill.name),
            redact_for_llm_preview(&skill.agent),
            redact_for_llm_preview(&skill.scope),
            skill.enabled,
            redact_for_llm_preview(&skill.state)
        ),
        None,
        Some(skill.id.clone()),
    );
    let mut evidence_refs = vec![skill_ref];
    for finding in signals.findings {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "finding",
            &finding.id,
            format!(
                "{} finding `{}`: {}",
                redact_for_llm_preview(&finding.effective_severity),
                redact_for_llm_preview(&finding.rule_id),
                redact_for_llm_preview(&finding.message)
            ),
            Some(finding.effective_severity.clone()),
            finding.instance_id.clone(),
        ));
    }
    for conflict in signals.conflicts {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "conflict",
            &conflict.id,
            format!(
                "Same-agent conflict `{}` covers {} instance(s)",
                redact_for_llm_preview(&conflict.reason),
                conflict.instance_ids.len()
            ),
            Some("warning".to_string()),
            Some(skill.id.clone()),
        ));
    }
    for group in signals.analysis_groups {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "analysis",
            &group.id,
            format!(
                "{} analysis `{}`: {}",
                redact_for_llm_preview(&group.severity),
                redact_for_llm_preview(&group.kind),
                redact_for_llm_preview(&group.title)
            ),
            Some(group.severity.clone()),
            Some(skill.id.clone()),
        ));
    }
    if let Some(quality) = signals.quality {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "quality_score",
            &skill.id,
            format!(
                "V2.43 quality score {} / 100 ({})",
                quality.score, quality.band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    if let Some(stale) = signals.stale {
        evidence_refs.push(push_task_readiness_evidence(
            evidence,
            "stale_drift",
            &skill.id,
            format!(
                "V2.51 stale/drift score {} / 100 ({})",
                stale.stale_drift_score, stale.stale_drift_band
            ),
            None,
            Some(skill.id.clone()),
        ));
    }
    evidence_refs.sort();
    evidence_refs.dedup();

    let canonical_key = normalize_similarity_key(&skill.name);
    let match_reasons = vec![
        format!(
            "Local catalog member has canonical key `{}` and {} derived keyword(s).",
            redact_for_llm_preview(&canonical_key),
            keywords.len()
        ),
        format!(
            "Risk context is `{}`; risk affects ambiguity notes but never creates write actions.",
            risk_level
        ),
    ];

    SimilarSkillCandidate {
        detail: skill.clone(),
        member: SimilarSkillMember {
            instance_id: skill.id.clone(),
            definition_id: skill.definition_id.clone(),
            skill_name: redact_for_llm_preview(&skill.name),
            agent: skill.agent.clone(),
            scope: skill.scope.clone(),
            enabled: skill.enabled,
            state: skill.state.clone(),
            source: KnowledgeSearchSource {
                source_path: redact_path_string(&skill.path, signals.redaction_roots),
                display_path: redact_path_string(&skill.display_path, signals.redaction_roots),
                root_provenance: knowledge_root_provenance(skill),
                fingerprint: redact_for_llm_preview(&skill.fingerprint),
            },
            quality_context: signals.quality.map(|quality| KnowledgeQualityContext {
                score: quality.score,
                grade: quality.grade,
                band: quality.band,
                reasons: quality.reasons.iter().take(3).cloned().collect(),
            }),
            readiness_context: None,
            stale_drift_context: signals.stale.map(|stale| KnowledgeStaleDriftContext {
                score: stale.stale_drift_score,
                band: stale.stale_drift_band,
                fingerprint_drift: stale.drift_signals.fingerprint_drift,
                finding_drift: stale.drift_signals.finding_drift,
                source_drift: stale.drift_signals.source_drift,
                stale_by_mtime: stale.drift_signals.stale_by_mtime,
                readiness_impact_level: stale
                    .readiness_impact
                    .as_ref()
                    .map(|impact| impact.impact_level),
            }),
            match_reasons,
            similarity_reasons: Vec::new(),
            evidence_refs,
        },
        canonical_key,
        terms: keywords,
        tools,
        rules,
        capability_tags,
        risk_tags,
        source_signals: source_signals.into_iter().collect(),
    }
}

fn similar_skill_groups_from_candidates(
    candidates: Vec<SimilarSkillCandidate>,
    min_score: u8,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> Vec<SimilarSkillGroup> {
    let mut pairs = Vec::new();
    for left in 0..candidates.len() {
        for right in (left + 1)..candidates.len() {
            let pair = similar_skill_pair(&candidates[left], &candidates[right], left, right);
            if pair.score >= min_score {
                pairs.push(pair);
            }
        }
    }

    let mut adjacency = vec![Vec::<usize>::new(); candidates.len()];
    for pair in &pairs {
        adjacency[pair.left].push(pair.right);
        adjacency[pair.right].push(pair.left);
    }

    let mut seen = vec![false; candidates.len()];
    let mut components = Vec::new();
    for index in 0..candidates.len() {
        if seen[index] {
            continue;
        }
        let mut stack = vec![index];
        let mut component = Vec::new();
        seen[index] = true;
        while let Some(current) = stack.pop() {
            component.push(current);
            for next in &adjacency[current] {
                if !seen[*next] {
                    seen[*next] = true;
                    stack.push(*next);
                }
            }
        }
        component.sort();
        components.push(component);
    }

    let mut groups = Vec::new();
    for component in components {
        let related_pairs = pairs
            .iter()
            .filter(|pair| component.contains(&pair.left) && component.contains(&pair.right))
            .cloned()
            .collect::<Vec<_>>();
        if component.len() > 1 && related_pairs.is_empty() {
            continue;
        }
        groups.push(similar_skill_group_from_component(
            &candidates,
            &component,
            &related_pairs,
            evidence,
        ));
    }
    groups
}

fn similar_skill_pair(
    left: &SimilarSkillCandidate,
    right: &SimilarSkillCandidate,
    left_index: usize,
    right_index: usize,
) -> SimilarSkillPair {
    let shared_terms = sorted_intersection(&left.terms, &right.terms, 12);
    let shared_tools = sorted_intersection(&left.tools, &right.tools, 12);
    let shared_rules = sorted_intersection(&left.rules, &right.rules, 12);
    let shared_capability_tags =
        sorted_intersection(&left.capability_tags, &right.capability_tags, 12);
    let shared_risk_tags = sorted_intersection(&left.risk_tags, &right.risk_tags, 12);
    let shared_source_signals = sorted_intersection(&left.source_signals, &right.source_signals, 8);
    let same_definition = left.detail.definition_id == right.detail.definition_id;
    let same_canonical = left.canonical_key == right.canonical_key;
    let same_agent = left.detail.agent == right.detail.agent;
    let same_fingerprint = left.detail.fingerprint == right.detail.fingerprint;
    let same_source_path = left.detail.display_path == right.detail.display_path;

    let mut score = 0u16;
    let mut why_grouped = Vec::new();
    if same_definition {
        score += 35;
        why_grouped
            .push("Shared catalog definition id indicates same local skill identity.".to_string());
    }
    if same_canonical {
        score += 30;
        why_grouped
            .push("Same canonical skill name/key creates high duplicate likelihood.".to_string());
    }
    if same_source_path {
        score += 25;
        why_grouped.push("Shared source path is treated as source overlap evidence.".to_string());
    } else if shared_source_signals
        .iter()
        .any(|signal| signal.starts_with("source-root:"))
    {
        score += 10;
        why_grouped.push("Shared source root suggests overlapping provenance.".to_string());
    }
    if same_fingerprint {
        score += 20;
        why_grouped.push(
            "Shared content fingerprint indicates near-identical catalog evidence.".to_string(),
        );
    }
    if !shared_tools.is_empty() {
        score += (shared_tools.len() as u16 * 8).min(24);
        why_grouped.push(format!(
            "Shared tool coverage: {}.",
            shared_tools
                .iter()
                .take(6)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_rules.is_empty() {
        score += (shared_rules.len() as u16 * 6).min(18);
        why_grouped.push(format!(
            "Shared rule/finding signals: {}.",
            shared_rules
                .iter()
                .take(6)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_terms.is_empty() {
        score += (shared_terms.len() as u16 * 4).min(20);
        why_grouped.push(format!(
            "Shared purpose/keyword terms: {}.",
            shared_terms
                .iter()
                .take(8)
                .map(|term| redact_for_llm_preview(term))
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }
    if !shared_capability_tags.is_empty() {
        score += (shared_capability_tags.len() as u16 * 3).min(12);
    }
    if !shared_risk_tags.is_empty() {
        score += (shared_risk_tags.len() as u16 * 2).min(8);
    }
    if same_agent {
        score += 5;
    }

    let score = score.min(100) as u8;
    let coverage_redundancy = if same_canonical || shared_tools.len() >= 3 || score >= 80 {
        "high"
    } else if shared_tools.len() >= 2 || shared_terms.len() >= 4 || score >= 55 {
        "medium"
    } else {
        "low"
    };
    let routing_ambiguity = if same_canonical && left.detail.enabled && right.detail.enabled {
        "high"
    } else if shared_terms.len() >= 5 && shared_tools.len() >= 2 {
        "medium"
    } else {
        "low"
    };
    let ambiguity_risk = if routing_ambiguity == "high"
        || left.detail.state != "loaded"
        || right.detail.state != "loaded"
        || !left.detail.enabled
        || !right.detail.enabled
        || shared_risk_tags
            .iter()
            .any(|tag| tag == "risk-high" || tag == "risk-blocked")
    {
        "high"
    } else if routing_ambiguity == "medium" || coverage_redundancy == "medium" {
        "medium"
    } else {
        "low"
    };
    let group_type = if same_canonical || same_definition || same_fingerprint {
        "duplicate"
    } else if same_source_path || shared_source_signals.len() > 1 {
        "source_overlap"
    } else if coverage_redundancy == "high" {
        "coverage_redundancy"
    } else if routing_ambiguity != "low" || ambiguity_risk == "high" {
        "confusable"
    } else {
        "similar"
    };

    SimilarSkillPair {
        left: left_index,
        right: right_index,
        score,
        group_type,
        coverage_redundancy,
        routing_ambiguity,
        ambiguity_risk,
        why_grouped,
        shared_terms,
        shared_tools,
        shared_rules,
        shared_capability_tags,
        shared_risk_tags,
        shared_source_signals,
    }
}

fn similar_skill_group_from_component(
    candidates: &[SimilarSkillCandidate],
    component: &[usize],
    pairs: &[SimilarSkillPair],
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> SimilarSkillGroup {
    let best_pair = pairs.iter().max_by(|left, right| {
        left.score
            .cmp(&right.score)
            .then_with(|| left.group_type.cmp(right.group_type))
    });
    let mut members = component
        .iter()
        .map(|index| candidates[*index].member.clone())
        .collect::<Vec<_>>();
    let reasons_by_member = similar_skill_member_reasons(component, pairs);
    for (member_index, member) in members.iter_mut().enumerate() {
        if let Some(reasons) = reasons_by_member.get(&member_index) {
            member.similarity_reasons = reasons.clone();
        } else {
            member.similarity_reasons.push(
                "Singleton retained by include_singletons without a peer above threshold."
                    .to_string(),
            );
        }
    }
    members.sort_by(|left, right| {
        left.agent
            .cmp(&right.agent)
            .then_with(|| left.skill_name.cmp(&right.skill_name))
            .then_with(|| left.instance_id.cmp(&right.instance_id))
    });

    let canonical_name = members
        .iter()
        .map(|member| member.skill_name.clone())
        .min()
        .unwrap_or_else(|| "unknown-skill".to_string());
    let canonical_key = normalize_similarity_key(&canonical_name);
    let member_ids = members
        .iter()
        .map(|member| member.instance_id.clone())
        .collect::<Vec<_>>();
    let group_id = stable_similar_group_id(&member_ids);
    let mut evidence_refs = members
        .iter()
        .flat_map(|member| member.evidence_refs.clone())
        .collect::<Vec<_>>();
    let group_ref = push_task_readiness_evidence(
        evidence,
        "similar_skill_group",
        &group_id,
        format!(
            "Similar skill group `{}` with {} member(s) and score {}",
            redact_for_llm_preview(&canonical_key),
            members.len(),
            best_pair.map(|pair| pair.score).unwrap_or(0)
        ),
        None,
        members.first().map(|member| member.instance_id.clone()),
    );
    evidence_refs.push(group_ref);
    evidence_refs.sort();
    evidence_refs.dedup();

    let shared_terms = union_pair_values(pairs, |pair| &pair.shared_terms);
    let shared_tools = union_pair_values(pairs, |pair| &pair.shared_tools);
    let shared_rules = union_pair_values(pairs, |pair| &pair.shared_rules);
    let shared_capability_tags = union_pair_values(pairs, |pair| &pair.shared_capability_tags);
    let shared_risk_tags = union_pair_values(pairs, |pair| &pair.shared_risk_tags);
    let shared_source_signals = union_pair_values(pairs, |pair| &pair.shared_source_signals);
    let mut why_grouped = pairs
        .iter()
        .flat_map(|pair| pair.why_grouped.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    if why_grouped.is_empty() {
        why_grouped
            .push("Singleton retained for review; no peer met the selected threshold.".to_string());
    }
    why_grouped.truncate(8);

    let group_type = best_pair.map(|pair| pair.group_type).unwrap_or("similar");
    let similarity_score = best_pair.map(|pair| pair.score).unwrap_or(0);
    let ambiguity_risk = max_band(pairs.iter().map(|pair| pair.ambiguity_risk)).unwrap_or("low");
    let coverage_redundancy =
        max_band(pairs.iter().map(|pair| pair.coverage_redundancy)).unwrap_or("low");
    let routing_ambiguity =
        max_band(pairs.iter().map(|pair| pair.routing_ambiguity)).unwrap_or("low");
    let title = format!(
        "{}: {} member(s), {} similarity",
        canonical_name,
        members.len(),
        similarity_score
    );
    let summary = format!(
        "{} local skill member(s) grouped as {}. Coverage redundancy is {}; routing ambiguity is {}; ambiguity risk is {}.",
        members.len(),
        group_type,
        coverage_redundancy,
        routing_ambiguity,
        ambiguity_risk
    );

    SimilarSkillGroup {
        group_id,
        rank: 0,
        group_type,
        similarity_score,
        ambiguity_risk,
        coverage_redundancy,
        routing_ambiguity,
        canonical_name,
        canonical_key,
        title,
        summary,
        why_grouped,
        shared_terms,
        shared_tools,
        shared_rules,
        shared_capability_tags,
        shared_risk_tags,
        shared_source_signals,
        members,
        evidence_refs,
        safety_flags: similar_skill_grouping_safety_flags(),
    }
}

fn similar_skill_member_reasons(
    component: &[usize],
    pairs: &[SimilarSkillPair],
) -> BTreeMap<usize, Vec<String>> {
    let component_position = component
        .iter()
        .enumerate()
        .map(|(position, original)| (*original, position))
        .collect::<BTreeMap<_, _>>();
    let mut reasons: BTreeMap<usize, BTreeSet<String>> = BTreeMap::new();
    for pair in pairs {
        let reason = format!(
            "Paired above threshold with score {} via {} evidence.",
            pair.score, pair.group_type
        );
        if let Some(position) = component_position.get(&pair.left) {
            reasons.entry(*position).or_default().insert(reason.clone());
        }
        if let Some(position) = component_position.get(&pair.right) {
            reasons.entry(*position).or_default().insert(reason);
        }
    }
    reasons
        .into_iter()
        .map(|(key, value)| (key, value.into_iter().collect()))
        .collect()
}

fn similar_skill_grouping_blocker_notes(groups: &[SimilarSkillGroup]) -> Vec<String> {
    let mut notes = Vec::new();
    if groups.iter().any(|group| group.routing_ambiguity == "high") {
        notes.push(
            "High routing ambiguity means humans should inspect candidates before selecting a route; no automatic rerouting is performed."
                .to_string(),
        );
    }
    if groups
        .iter()
        .any(|group| group.coverage_redundancy == "high")
    {
        notes.push(
            "High coverage redundancy is advisory only and does not disable, merge, or delete skills."
                .to_string(),
        );
    }
    if groups.iter().any(|group| {
        group
            .members
            .iter()
            .any(|member| !member.enabled || member.state != "loaded")
    }) {
        notes.push(
            "Disabled or non-loaded members are included for confusability review but are not made routable."
                .to_string(),
        );
    }
    if groups.iter().any(|group| group.ambiguity_risk == "high") {
        notes.push(
            "High ambiguity risk is derived from local state, risk, stale/drift, and overlap signals only."
                .to_string(),
        );
    }
    if notes.is_empty() {
        notes.push(
            "Similar skill grouping used local catalog evidence only and found no returned-group blockers."
                .to_string(),
        );
    }
    notes
}

fn similar_skill_grouping_summary(
    indexed_skill_count: usize,
    candidate_skill_count: usize,
    matched_group_count: usize,
    groups: &[SimilarSkillGroup],
) -> SimilarSkillGroupingSummary {
    let duplicate_group_count = groups
        .iter()
        .filter(|group| group.group_type == "duplicate")
        .count();
    let confusable_group_count = groups
        .iter()
        .filter(|group| group.group_type == "confusable")
        .count();
    let coverage_redundancy_group_count = groups
        .iter()
        .filter(|group| group.coverage_redundancy == "high")
        .count();
    let routing_ambiguity_count = groups
        .iter()
        .filter(|group| group.routing_ambiguity != "low")
        .count();
    let summary = if groups.is_empty() {
        "No deterministic similar skill groups matched the selected filters.".to_string()
    } else {
        format!(
            "Returned {} of {} similar skill group(s) from {} candidate skill(s) across {} indexed visible skill(s); {} duplicate group(s), {} high coverage redundancy group(s), and {} routing ambiguity group(s).",
            groups.len(),
            matched_group_count,
            candidate_skill_count,
            indexed_skill_count,
            duplicate_group_count,
            coverage_redundancy_group_count,
            routing_ambiguity_count
        )
    };
    SimilarSkillGroupingSummary {
        indexed_skill_count,
        candidate_skill_count,
        matched_group_count,
        returned_group_count: groups.len(),
        duplicate_group_count,
        confusable_group_count,
        coverage_redundancy_group_count,
        routing_ambiguity_count,
        summary,
    }
}

fn capability_taxonomy_safety_flags() -> CapabilityTaxonomySafetyFlags {
    agent_readiness_safety_flags()
}

fn capability_taxonomy_filters(params: &CapabilityTaxonomyParams) -> CapabilityTaxonomyFilters {
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();
    CapabilityTaxonomyFilters {
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        limit: params.limit.unwrap_or(25).clamp(1, 100),
        include_single_skill_domains: params.include_single_skill_domains,
        candidate_instance_ids,
    }
}

fn empty_capability_taxonomy_result(
    filters: CapabilityTaxonomyFilters,
    catalog_available: bool,
) -> CapabilityTaxonomyResult {
    CapabilityTaxonomyResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters: filters.clone(),
        summary: CapabilityTaxonomySummary {
            indexed_skill_count: 0,
            candidate_skill_count: 0,
            domain_count: 0,
            returned_domain_count: 0,
            total_representative_skill_count: 0,
            agent_count: 0,
            workspace_count: 0,
            duplicate_or_redundant_domain_count: 0,
            routing_ambiguity_domain_count: 0,
            gap_count: 1,
            summary: "No local catalog is available, so capability taxonomy has no skill evidence."
                .to_string(),
        },
        domains: Vec::new(),
        coverage_rows: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on capability taxonomy for coverage review."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: CapabilityTaxonomyPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "capability_taxonomy",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::CapabilityTaxonomy,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic capability taxonomy using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: capability_taxonomy_safety_flags(),
    }
}

#[derive(Debug, Clone)]
struct CapabilityTaxonomyCandidate {
    detail: SkillDetailRecord,
    domain_key: String,
    domain_name: String,
    workspace: String,
    representative: CapabilityRepresentativeSkill,
    keywords: Vec<String>,
    tools: Vec<String>,
    rules: Vec<String>,
    capability_tags: Vec<String>,
    risk_tags: Vec<String>,
    similarity_group_ids: Vec<String>,
}

#[derive(Debug, Clone)]
struct CapabilitySimilaritySignal {
    group_id: String,
    coverage_redundancy: &'static str,
    routing_ambiguity: &'static str,
}

fn capability_similarity_by_member(
    groups: &[SimilarSkillGroup],
) -> BTreeMap<String, Vec<CapabilitySimilaritySignal>> {
    let mut by_member: BTreeMap<String, Vec<CapabilitySimilaritySignal>> = BTreeMap::new();
    for group in groups {
        for member in &group.members {
            by_member
                .entry(member.instance_id.clone())
                .or_default()
                .push(CapabilitySimilaritySignal {
                    group_id: group.group_id.clone(),
                    coverage_redundancy: group.coverage_redundancy,
                    routing_ambiguity: group.routing_ambiguity,
                });
        }
    }
    by_member
}

fn capability_taxonomy_candidate(
    candidate: SimilarSkillCandidate,
    similar_by_member: &BTreeMap<String, Vec<CapabilitySimilaritySignal>>,
    redaction_roots: &[(String, &'static str)],
) -> CapabilityTaxonomyCandidate {
    let (domain_key, domain_name) = capability_domain_for_candidate(&candidate);
    let workspace = capability_workspace_label(&candidate.detail, redaction_roots);
    let similarity_signals = similar_by_member.get(&candidate.detail.id);
    let similarity_group_ids = similarity_signals
        .map(|signals| {
            signals
                .iter()
                .map(|signal| signal.group_id.clone())
                .collect::<BTreeSet<_>>()
                .into_iter()
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let redundancy_signal_count = similarity_signals
        .map(|signals| {
            signals
                .iter()
                .filter(|signal| signal.coverage_redundancy != "low")
                .count()
        })
        .unwrap_or(0);
    let ambiguity_signal_count = similarity_signals
        .map(|signals| {
            signals
                .iter()
                .filter(|signal| signal.routing_ambiguity != "low")
                .count()
        })
        .unwrap_or(0);
    let mut match_reasons = vec![format!(
        "Classified into `{}` from deterministic name, description, keyword, tool, rule, and capability-tag evidence.",
        domain_name
    )];
    if !similarity_group_ids.is_empty() {
        match_reasons.push(format!(
            "Similar-group evidence contributes {} group(s), {} redundancy signal(s), and {} routing ambiguity signal(s).",
            similarity_group_ids.len(),
            redundancy_signal_count,
            ambiguity_signal_count
        ));
    }
    let representative = CapabilityRepresentativeSkill {
        instance_id: candidate.member.instance_id.clone(),
        definition_id: candidate.member.definition_id.clone(),
        skill_name: candidate.member.skill_name.clone(),
        agent: candidate.member.agent.clone(),
        scope: candidate.member.scope.clone(),
        enabled: candidate.member.enabled,
        state: candidate.member.state.clone(),
        source: candidate.member.source.clone(),
        quality_context: candidate.member.quality_context.clone(),
        stale_drift_context: candidate.member.stale_drift_context.clone(),
        similarity_group_ids: similarity_group_ids.clone(),
        match_reasons,
        evidence_refs: candidate.member.evidence_refs.clone(),
    };
    CapabilityTaxonomyCandidate {
        detail: candidate.detail,
        domain_key,
        domain_name,
        workspace,
        representative,
        keywords: candidate.terms,
        tools: candidate.tools,
        rules: candidate.rules,
        capability_tags: candidate.capability_tags,
        risk_tags: candidate.risk_tags,
        similarity_group_ids,
    }
}

fn capability_domain_for_candidate(candidate: &SimilarSkillCandidate) -> (String, String) {
    let searchable = format!(
        "{} {} {} {} {} {} {}",
        candidate.detail.name,
        candidate.detail.description,
        candidate.detail.frontmatter_raw,
        candidate.detail.body,
        candidate.terms.join(" "),
        candidate.tools.join(" "),
        candidate.rules.join(" ")
    )
    .to_ascii_lowercase();
    let (key, name) = if contains_any(
        &searchable,
        &[
            "research",
            "knowledge",
            "search",
            "index",
            "retrieval",
            "rag",
            "docs",
            "documentation",
        ],
    ) {
        ("research-knowledge", "Research & Knowledge")
    } else if contains_any(
        &searchable,
        &[
            "release",
            "readiness",
            "validation",
            "smoke",
            "test",
            "regression",
            "quality",
            "benchmark",
        ],
    ) {
        ("release-validation", "Release & Validation")
    } else if contains_any(
        &searchable,
        &[
            "security",
            "privacy",
            "credential",
            "redaction",
            "permission",
            "risk",
            "safety",
            "audit",
        ],
    ) {
        ("security-privacy", "Security & Privacy")
    } else if contains_any(
        &searchable,
        &[
            "agent",
            "adapter",
            "routing",
            "skill",
            "taxonomy",
            "capability",
            "governance",
        ],
    ) {
        ("agent-skills-governance", "Agent Skills Governance")
    } else if contains_any(
        &searchable,
        &[
            "build", "code", "rust", "swift", "macos", "ios", "web", "frontend", "backend",
        ],
    ) {
        ("software-delivery", "Software Delivery")
    } else if contains_any(
        &searchable,
        &[
            "data",
            "analytics",
            "sql",
            "chart",
            "dashboard",
            "report",
            "metric",
        ],
    ) {
        ("data-analytics", "Data & Analytics")
    } else if contains_any(
        &searchable,
        &[
            "design",
            "ui",
            "ux",
            "theme",
            "visual",
            "product",
            "prototype",
        ],
    ) {
        ("product-design", "Product Design")
    } else if contains_any(
        &searchable,
        &["automation", "script", "ops", "cli", "workflow", "deploy"],
    ) {
        ("automation-ops", "Automation & Ops")
    } else {
        ("general-utility", "General Utility")
    };
    (key.to_string(), name.to_string())
}

fn contains_any(value: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| value.contains(needle))
}

fn capability_workspace_label(
    skill: &SkillDetailRecord,
    redaction_roots: &[(String, &'static str)],
) -> String {
    if skill.scope == Scope::ToolGlobal.as_str() {
        "tool-global".to_string()
    } else if skill.scope == Scope::AgentProject.as_str() {
        let parent = Path::new(&skill.display_path)
            .parent()
            .map(|path| redact_path_string(path, redaction_roots))
            .unwrap_or_else(|| "project".to_string());
        format!("{}:project:{parent}", skill.agent)
    } else {
        format!("{}:global", skill.agent)
    }
}

fn capability_domains_from_candidates(
    candidates: Vec<CapabilityTaxonomyCandidate>,
    include_single_skill_domains: bool,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> Vec<CapabilityDomainRow> {
    let mut by_domain: BTreeMap<String, Vec<CapabilityTaxonomyCandidate>> = BTreeMap::new();
    for candidate in candidates {
        by_domain
            .entry(candidate.domain_key.clone())
            .or_default()
            .push(candidate);
    }

    by_domain
        .into_values()
        .filter_map(|mut candidates| {
            if !include_single_skill_domains && candidates.len() == 1 {
                return None;
            }
            candidates.sort_by(|left, right| {
                right
                    .detail
                    .enabled
                    .cmp(&left.detail.enabled)
                    .then_with(|| left.detail.agent.cmp(&right.detail.agent))
                    .then_with(|| left.detail.name.cmp(&right.detail.name))
                    .then_with(|| left.detail.id.cmp(&right.detail.id))
            });
            Some(capability_domain_from_candidates(candidates, evidence))
        })
        .collect()
}

fn capability_domain_from_candidates(
    candidates: Vec<CapabilityTaxonomyCandidate>,
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
) -> CapabilityDomainRow {
    let domain_key = candidates
        .first()
        .map(|candidate| candidate.domain_key.clone())
        .unwrap_or_else(|| "general-utility".to_string());
    let domain_name = candidates
        .first()
        .map(|candidate| candidate.domain_name.clone())
        .unwrap_or_else(|| "General Utility".to_string());
    let domain_id = stable_capability_domain_id(&domain_key);
    let mut agents = BTreeMap::new();
    let mut workspaces = BTreeMap::new();
    let mut tools = BTreeSet::new();
    let mut rules = BTreeSet::new();
    let mut keywords = BTreeSet::new();
    let mut capability_tags = BTreeSet::new();
    let mut risk_tags = BTreeSet::new();
    let mut evidence_refs = BTreeSet::new();
    let mut duplicate_or_redundant_count = 0usize;
    let mut routing_ambiguity_count = 0usize;
    let enabled_skill_count = candidates
        .iter()
        .filter(|candidate| candidate.detail.enabled)
        .count();
    for candidate in &candidates {
        *agents.entry(candidate.detail.agent.clone()).or_insert(0) += 1;
        *workspaces.entry(candidate.workspace.clone()).or_insert(0) += 1;
        tools.extend(candidate.tools.iter().take(12).cloned());
        rules.extend(candidate.rules.iter().take(12).cloned());
        keywords.extend(candidate.keywords.iter().take(16).cloned());
        capability_tags.extend(candidate.capability_tags.iter().take(16).cloned());
        risk_tags.extend(candidate.risk_tags.iter().take(16).cloned());
        evidence_refs.extend(candidate.representative.evidence_refs.iter().cloned());
        if !candidate.similarity_group_ids.is_empty() {
            duplicate_or_redundant_count += 1;
        }
    }
    let mut seen_similarity_groups = BTreeSet::new();
    for candidate in &candidates {
        for group_id in &candidate.similarity_group_ids {
            if seen_similarity_groups.insert(group_id.clone()) {
                duplicate_or_redundant_count += 1;
            }
        }
    }
    routing_ambiguity_count += risk_tags
        .iter()
        .filter(|tag| tag.as_str() == "risk-high" || tag.as_str() == "risk-blocked")
        .count();
    routing_ambiguity_count += candidates
        .iter()
        .filter(|candidate| !candidate.detail.enabled || candidate.detail.state != "loaded")
        .count();

    let domain_ref = push_task_readiness_evidence(
        evidence,
        "capability_domain",
        &domain_id,
        format!(
            "Capability domain `{}` has {} local skill member(s) across {} agent(s) and {} workspace(s)",
            redact_for_llm_preview(&domain_name),
            candidates.len(),
            agents.len(),
            workspaces.len()
        ),
        None,
        candidates
            .first()
            .map(|candidate| candidate.detail.id.clone()),
    );
    evidence_refs.insert(domain_ref);

    let representative_skills = candidates
        .iter()
        .take(8)
        .map(|candidate| candidate.representative.clone())
        .collect::<Vec<_>>();
    let coverage_score = capability_coverage_score(
        candidates.len(),
        enabled_skill_count,
        agents.len(),
        workspaces.len(),
        duplicate_or_redundant_count,
        routing_ambiguity_count,
    );
    let coverage_level = capability_coverage_level(coverage_score);
    let gap_notes = capability_domain_gap_notes(
        &domain_name,
        candidates.len(),
        enabled_skill_count,
        agents.len(),
        workspaces.len(),
    );
    let blocker_notes = capability_domain_blocker_notes(
        &domain_name,
        &candidates,
        duplicate_or_redundant_count,
        routing_ambiguity_count,
    );

    CapabilityDomainRow {
        domain_id,
        rank: 0,
        domain_key,
        domain_name,
        coverage_level,
        coverage_score,
        skill_count: candidates.len(),
        enabled_skill_count,
        disabled_skill_count: candidates.len().saturating_sub(enabled_skill_count),
        agent_count: agents.len(),
        workspace_count: workspaces.len(),
        agents,
        workspaces,
        duplicate_or_redundant_count,
        routing_ambiguity_count,
        representative_skills,
        capability_tags: capability_tags.into_iter().take(24).collect(),
        risk_tags: risk_tags.into_iter().take(24).collect(),
        tools: tools.into_iter().take(24).collect(),
        rules: rules.into_iter().take(24).collect(),
        keywords: keywords.into_iter().take(24).collect(),
        gap_notes,
        blocker_notes,
        evidence_refs: evidence_refs.into_iter().collect(),
        safety_flags: capability_taxonomy_safety_flags(),
    }
}

fn capability_coverage_score(
    skill_count: usize,
    enabled_count: usize,
    agent_count: usize,
    workspace_count: usize,
    duplicate_or_redundant_count: usize,
    routing_ambiguity_count: usize,
) -> u8 {
    let mut score = 20i16;
    score += (skill_count as i16 * 12).min(30);
    score += (enabled_count as i16 * 12).min(24);
    score += (agent_count as i16 * 10).min(24);
    score += (workspace_count as i16 * 6).min(18);
    score -= (duplicate_or_redundant_count as i16 * 5).min(20);
    score -= (routing_ambiguity_count as i16 * 7).min(28);
    score.clamp(0, 100) as u8
}

fn capability_coverage_level(score: u8) -> &'static str {
    match score {
        80..=100 => "broad",
        55..=79 => "moderate",
        25..=54 => "thin",
        _ => "gap",
    }
}

fn capability_domain_gap_notes(
    domain_name: &str,
    skill_count: usize,
    enabled_count: usize,
    agent_count: usize,
    workspace_count: usize,
) -> Vec<String> {
    let mut notes = Vec::new();
    if skill_count < 2 {
        notes.push(format!(
            "`{}` has only one visible local skill; coverage may be thin.",
            redact_for_llm_preview(domain_name)
        ));
    }
    if enabled_count == 0 {
        notes.push(format!(
            "`{}` has no enabled local skills.",
            redact_for_llm_preview(domain_name)
        ));
    }
    if agent_count < 2 {
        notes.push(format!(
            "`{}` is visible in fewer than two agents.",
            redact_for_llm_preview(domain_name)
        ));
    }
    if workspace_count < 2 {
        notes.push(format!(
            "`{}` is concentrated in one workspace/scope.",
            redact_for_llm_preview(domain_name)
        ));
    }
    notes
}

fn capability_domain_blocker_notes(
    domain_name: &str,
    candidates: &[CapabilityTaxonomyCandidate],
    duplicate_or_redundant_count: usize,
    routing_ambiguity_count: usize,
) -> Vec<String> {
    let mut notes = Vec::new();
    if candidates
        .iter()
        .any(|candidate| !candidate.detail.enabled || candidate.detail.state != "loaded")
    {
        notes.push(format!(
            "`{}` includes disabled or non-loaded skills; taxonomy does not make them routable.",
            redact_for_llm_preview(domain_name)
        ));
    }
    if duplicate_or_redundant_count > 0 {
        notes.push(format!(
            "`{}` has duplicate/redundancy signals from similar-skill grouping; no merge or delete action is enabled.",
            redact_for_llm_preview(domain_name)
        ));
    }
    if routing_ambiguity_count > 0 {
        notes.push(format!(
            "`{}` has routing ambiguity or high-risk signals and should be reviewed before use.",
            redact_for_llm_preview(domain_name)
        ));
    }
    notes
}

fn capability_coverage_rows(domains: &[CapabilityDomainRow]) -> Vec<CapabilityCoverageRow> {
    domains
        .iter()
        .map(|domain| CapabilityCoverageRow {
            domain_key: domain.domain_key.clone(),
            domain_name: domain.domain_name.clone(),
            coverage_level: domain.coverage_level,
            coverage_score: domain.coverage_score,
            skill_count: domain.skill_count,
            enabled_skill_count: domain.enabled_skill_count,
            agent_count: domain.agent_count,
            workspace_count: domain.workspace_count,
            agents: domain.agents.clone(),
            gaps: domain.gap_notes.clone(),
            duplicates_redundancy: if domain.duplicate_or_redundant_count > 0 {
                "present"
            } else {
                "none"
            },
            routing_ambiguity: if domain.routing_ambiguity_count > 0 {
                "present"
            } else {
                "none"
            },
            evidence_refs: domain.evidence_refs.clone(),
        })
        .collect()
}

fn capability_taxonomy_blocker_notes(domains: &[CapabilityDomainRow]) -> Vec<String> {
    let mut notes = Vec::new();
    if domains
        .iter()
        .any(|domain| domain.routing_ambiguity_count > 0)
    {
        notes.push(
            "Routing ambiguity is advisory and does not trigger automatic route changes."
                .to_string(),
        );
    }
    if domains
        .iter()
        .any(|domain| domain.duplicate_or_redundant_count > 0)
    {
        notes.push(
            "Duplicate or redundant capability coverage is reported for review only; no skills are merged, disabled, or deleted."
                .to_string(),
        );
    }
    if domains.iter().any(|domain| domain.disabled_skill_count > 0) {
        notes.push(
            "Disabled or non-loaded skills remain disabled/non-loaded; taxonomy is read-only."
                .to_string(),
        );
    }
    if notes.is_empty() {
        notes.push(
            "Capability taxonomy used local catalog evidence only and found no returned-domain blockers."
                .to_string(),
        );
    }
    notes
}

fn capability_taxonomy_summary(
    indexed_skill_count: usize,
    candidate_skill_count: usize,
    domain_count: usize,
    domains: &[CapabilityDomainRow],
) -> CapabilityTaxonomySummary {
    let total_representative_skill_count = domains
        .iter()
        .map(|domain| domain.representative_skills.len())
        .sum();
    let agents = domains
        .iter()
        .flat_map(|domain| domain.agents.keys().cloned())
        .collect::<BTreeSet<_>>();
    let workspaces = domains
        .iter()
        .flat_map(|domain| domain.workspaces.keys().cloned())
        .collect::<BTreeSet<_>>();
    let duplicate_or_redundant_domain_count = domains
        .iter()
        .filter(|domain| domain.duplicate_or_redundant_count > 0)
        .count();
    let routing_ambiguity_domain_count = domains
        .iter()
        .filter(|domain| domain.routing_ambiguity_count > 0)
        .count();
    let gap_count = domains.iter().map(|domain| domain.gap_notes.len()).sum();
    let summary = if domains.is_empty() {
        "No deterministic capability domains matched the selected filters.".to_string()
    } else {
        format!(
            "Returned {} of {} capability domain(s) from {} candidate skill(s) across {} indexed visible skill(s); {} domain(s) have duplicate/redundancy signals and {} domain(s) have routing ambiguity.",
            domains.len(),
            domain_count,
            candidate_skill_count,
            indexed_skill_count,
            duplicate_or_redundant_domain_count,
            routing_ambiguity_domain_count
        )
    };
    CapabilityTaxonomySummary {
        indexed_skill_count,
        candidate_skill_count,
        domain_count,
        returned_domain_count: domains.len(),
        total_representative_skill_count,
        agent_count: agents.len(),
        workspace_count: workspaces.len(),
        duplicate_or_redundant_domain_count,
        routing_ambiguity_domain_count,
        gap_count,
        summary,
    }
}

fn stable_capability_domain_id(domain_key: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(domain_key.as_bytes());
    let digest = hasher.finalize();
    format!("cap-domain-{}", hex_prefix(&digest, 12))
}

fn normalize_similarity_key(value: &str) -> String {
    task_readiness_terms(value).join("-")
}

fn sorted_intersection(left: &[String], right: &[String], limit: usize) -> Vec<String> {
    let right = right.iter().collect::<BTreeSet<_>>();
    left.iter()
        .filter(|value| right.contains(value))
        .cloned()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .take(limit)
        .collect()
}

fn union_pair_values<'a>(
    pairs: &'a [SimilarSkillPair],
    values: impl Fn(&'a SimilarSkillPair) -> &'a Vec<String>,
) -> Vec<String> {
    pairs
        .iter()
        .flat_map(values)
        .cloned()
        .collect::<BTreeSet<_>>()
        .into_iter()
        .take(16)
        .collect()
}

fn max_band<'a>(bands: impl Iterator<Item = &'a str>) -> Option<&'static str> {
    let mut max = None;
    let mut score = 0u8;
    for band in bands {
        let band_score = match band {
            "high" => 3,
            "medium" => 2,
            _ => 1,
        };
        if band_score > score {
            score = band_score;
            max = Some(match band_score {
                3 => "high",
                2 => "medium",
                _ => "low",
            });
        }
    }
    max
}

fn stable_similar_group_id(member_ids: &[String]) -> String {
    let mut sorted = member_ids.to_vec();
    sorted.sort();
    let mut hasher = Sha256::new();
    for id in &sorted {
        hasher.update(id.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("similar-group-{:x}", digest)[..26].to_string()
}

fn local_skill_map_safety_flags() -> LocalSkillMapSafetyFlags {
    agent_readiness_safety_flags()
}

fn local_skill_map_filters(
    params: &LocalSkillMapParams,
    redaction_roots: &[(String, &'static str)],
) -> LocalSkillMapFilters {
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();
    let task = params
        .task
        .as_deref()
        .map(str::trim)
        .filter(|task| !task.is_empty())
        .map(|task| redact_string(&redact_for_llm_preview(task), redaction_roots));
    let limit = params.limit.unwrap_or(30).clamp(1, 100);
    LocalSkillMapFilters {
        agent: params
            .agent
            .as_deref()
            .map(str::trim)
            .filter(|agent| !agent.is_empty())
            .map(ToOwned::to_owned),
        task: task.clone(),
        limit,
        node_limit: params
            .node_limit
            .unwrap_or(limit.saturating_mul(4))
            .clamp(1, 200),
        edge_limit: params
            .edge_limit
            .unwrap_or(limit.saturating_mul(6))
            .clamp(1, 400),
        cluster_limit: params.cluster_limit.unwrap_or(20).clamp(1, 100),
        candidate_instance_ids,
        include_task_context: params.include_task_context || task.is_some(),
    }
}

fn empty_local_skill_map_result(
    filters: LocalSkillMapFilters,
    catalog_available: bool,
) -> LocalSkillMapResult {
    LocalSkillMapResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters: filters.clone(),
        summary: LocalSkillMapSummary {
            indexed_skill_count: 0,
            candidate_skill_count: 0,
            returned_node_count: 0,
            returned_edge_count: 0,
            cluster_count: 0,
            returned_cluster_count: 0,
            domain_count: 0,
            skill_node_count: 0,
            capability_node_count: 0,
            similar_group_node_count: 0,
            conflict_node_count: 0,
            risk_node_count: 0,
            task_coverage_edge_count: 0,
            cross_agent_edge_count: 0,
            summary: "No local catalog is available, so local skill map has no graph evidence."
                .to_string(),
        },
        nodes: Vec::new(),
        edges: Vec::new(),
        clusters: Vec::new(),
        domains: Vec::new(),
        risk_notes: vec![
            "No local risk relationships can be mapped until a catalog scan exists.".to_string(),
        ],
        gap_notes: vec![
            "Run a local scan before relying on Local Skill Map for routing or cleanup review."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: LocalSkillMapPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "local_skill_map",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::LocalSkillMap,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic local skill map using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn local_skill_map_skill_node(row: &KnowledgeSearchRow, risk_level: &str) -> LocalSkillMapNode {
    let mut tags = row
        .capability_tags
        .iter()
        .chain(row.risk_tags.iter())
        .take(24)
        .cloned()
        .collect::<Vec<_>>();
    tags.extend(row.tools.iter().take(8).map(|tool| format!("tool-{tool}")));
    tags.sort();
    tags.dedup();
    LocalSkillMapNode {
        id: local_skill_map_skill_node_id(&row.instance_id),
        node_type: "skill".to_string(),
        rank: row.rank,
        label: row.skill_name.clone(),
        summary: row
            .description_snippet
            .clone()
            .or_else(|| row.purpose_snippet.clone())
            .unwrap_or_else(|| {
                format!(
                    "{} skill in {} ({}, enabled={}).",
                    row.agent, row.scope, row.state, row.enabled
                )
            }),
        weight: local_skill_map_skill_weight(row, risk_level),
        agent: Some(row.agent.clone()),
        scope: Some(row.scope.clone()),
        enabled: Some(row.enabled),
        state: Some(row.state.clone()),
        source: Some(row.source.clone()),
        risk_level: Some(risk_level.to_string()),
        tags,
        evidence_refs: row.evidence_refs.clone(),
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn local_skill_map_agent_node(agent: &str) -> LocalSkillMapNode {
    LocalSkillMapNode {
        id: local_skill_map_agent_node_id(agent),
        node_type: "agent".to_string(),
        rank: 0,
        label: agent.to_string(),
        summary: format!("{agent} local skill surface from catalog evidence."),
        weight: 50,
        agent: Some(agent.to_string()),
        scope: None,
        enabled: None,
        state: None,
        source: None,
        risk_level: None,
        tags: vec!["agent".to_string(), "local-catalog".to_string()],
        evidence_refs: Vec::new(),
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn local_skill_map_source_node(source: &KnowledgeSearchSource) -> LocalSkillMapNode {
    LocalSkillMapNode {
        id: local_skill_map_source_node_id(source),
        node_type: "source".to_string(),
        rank: 0,
        label: source.root_provenance.clone(),
        summary: format!("Source evidence at {}", source.display_path),
        weight: 45,
        agent: None,
        scope: None,
        enabled: None,
        state: None,
        source: Some(source.clone()),
        risk_level: None,
        tags: vec![
            "source".to_string(),
            source.root_provenance.clone(),
            format!("fingerprint-{}", source.fingerprint),
        ],
        evidence_refs: Vec::new(),
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn local_skill_map_risk_node(risk_level: &str) -> LocalSkillMapNode {
    LocalSkillMapNode {
        id: local_skill_map_risk_node_id(risk_level),
        node_type: "risk".to_string(),
        rank: 0,
        label: risk_level.to_string(),
        summary: format!("Risk bucket `{risk_level}` derived from local findings, conflicts, analysis, and stale/drift signals."),
        weight: local_skill_map_risk_weight(risk_level),
        agent: None,
        scope: None,
        enabled: None,
        state: None,
        source: None,
        risk_level: Some(risk_level.to_string()),
        tags: vec![format!("risk-{risk_level}")],
        evidence_refs: Vec::new(),
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn local_skill_map_edge(
    edge_type: &str,
    source: &str,
    target: &str,
    label: &str,
    weight: u8,
    reasons: Vec<String>,
    evidence_refs: Vec<String>,
) -> LocalSkillMapEdge {
    LocalSkillMapEdge {
        id: stable_local_skill_map_edge_id(edge_type, source, target),
        edge_type: edge_type.to_string(),
        source: source.to_string(),
        target: target.to_string(),
        label: label.to_string(),
        weight,
        reasons: reasons.into_iter().take(8).collect(),
        evidence_refs,
        safety_flags: local_skill_map_safety_flags(),
    }
}

fn upsert_local_skill_map_node(
    nodes: &mut BTreeMap<String, LocalSkillMapNode>,
    mut node: LocalSkillMapNode,
) {
    node.tags.sort();
    node.tags.dedup();
    node.evidence_refs.sort();
    node.evidence_refs.dedup();
    nodes
        .entry(node.id.clone())
        .and_modify(|existing| {
            existing.weight = existing.weight.max(node.weight);
            existing.tags.extend(node.tags.clone());
            existing.tags.sort();
            existing.tags.dedup();
            existing.evidence_refs.extend(node.evidence_refs.clone());
            existing.evidence_refs.sort();
            existing.evidence_refs.dedup();
        })
        .or_insert(node);
}

fn upsert_local_skill_map_edge(
    edges: &mut BTreeMap<String, LocalSkillMapEdge>,
    mut edge: LocalSkillMapEdge,
) {
    edge.reasons.sort();
    edge.reasons.dedup();
    edge.evidence_refs.sort();
    edge.evidence_refs.dedup();
    edges
        .entry(edge.id.clone())
        .and_modify(|existing| {
            existing.weight = existing.weight.max(edge.weight);
            existing.reasons.extend(edge.reasons.clone());
            existing.reasons.sort();
            existing.reasons.dedup();
            existing.evidence_refs.extend(edge.evidence_refs.clone());
            existing.evidence_refs.sort();
            existing.evidence_refs.dedup();
        })
        .or_insert(edge);
}

fn extend_evidence_references(
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
    references: Vec<TaskReadinessEvidenceReference>,
) {
    evidence.extend(references);
    dedupe_evidence_references(evidence);
}

fn dedupe_evidence_references(evidence: &mut Vec<TaskReadinessEvidenceReference>) {
    let mut by_id = BTreeMap::<String, TaskReadinessEvidenceReference>::new();
    for item in evidence.drain(..) {
        by_id.entry(item.id.clone()).or_insert(item);
    }
    evidence.extend(by_id.into_values());
}

fn normalize_note_list(notes: &mut Vec<String>) {
    notes.retain(|note| !note.trim().is_empty());
    notes.sort();
    notes.dedup();
}

fn stable_slug(value: &str) -> String {
    let mut slug = value
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() {
                ch.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>();
    while slug.contains("--") {
        slug = slug.replace("--", "-");
    }
    slug.trim_matches('-').chars().take(64).collect()
}

fn local_skill_map_skill_weight(row: &KnowledgeSearchRow, risk_level: &str) -> u8 {
    let mut weight = 35i16;
    if row.enabled {
        weight += 15;
    }
    if row.state == "loaded" {
        weight += 12;
    }
    weight += row.tools.len().min(6) as i16 * 4;
    weight += row.match_reasons.len().min(4) as i16 * 3;
    weight += match risk_level {
        "blocked" => 25,
        "high" => 18,
        "medium" => 8,
        _ => 0,
    };
    weight.clamp(1, 100) as u8
}

fn local_skill_map_risk_level(risk_tags: &[String]) -> String {
    if risk_tags.iter().any(|tag| tag == "risk-blocked") {
        "blocked".to_string()
    } else if risk_tags.iter().any(|tag| tag == "risk-high") {
        "high".to_string()
    } else if risk_tags.iter().any(|tag| tag == "risk-medium") {
        "medium".to_string()
    } else {
        "low".to_string()
    }
}

fn local_skill_map_risk_weight(risk_level: &str) -> u8 {
    match risk_level {
        "blocked" => 100,
        "high" => 90,
        "medium" => 65,
        _ => 35,
    }
}

fn local_skill_map_severity_weight(severity: &str) -> u8 {
    match normalize_filter_value(severity).as_str() {
        "error" | "critical" | "high" => 90,
        "warning" | "warn" | "medium" => 70,
        "info" | "low" => 45,
        _ => 55,
    }
}

fn local_skill_map_node_sort(
    left: &LocalSkillMapNode,
    right: &LocalSkillMapNode,
) -> std::cmp::Ordering {
    local_skill_map_node_type_order(&left.node_type)
        .cmp(&local_skill_map_node_type_order(&right.node_type))
        .then_with(|| right.weight.cmp(&left.weight))
        .then_with(|| left.label.cmp(&right.label))
        .then_with(|| left.id.cmp(&right.id))
}

fn local_skill_map_edge_sort(
    left: &LocalSkillMapEdge,
    right: &LocalSkillMapEdge,
) -> std::cmp::Ordering {
    local_skill_map_edge_type_order(&left.edge_type)
        .cmp(&local_skill_map_edge_type_order(&right.edge_type))
        .then_with(|| right.weight.cmp(&left.weight))
        .then_with(|| left.source.cmp(&right.source))
        .then_with(|| left.target.cmp(&right.target))
        .then_with(|| left.id.cmp(&right.id))
}

fn local_skill_map_cluster_sort(
    left: &LocalSkillMapCluster,
    right: &LocalSkillMapCluster,
) -> std::cmp::Ordering {
    local_skill_map_cluster_type_order(&left.cluster_type)
        .cmp(&local_skill_map_cluster_type_order(&right.cluster_type))
        .then_with(|| right.score.cmp(&left.score))
        .then_with(|| left.label.cmp(&right.label))
        .then_with(|| left.id.cmp(&right.id))
}

fn local_skill_map_node_type_order(node_type: &str) -> u8 {
    match node_type {
        "task_coverage" => 0,
        "skill" => 1,
        "capability" => 2,
        "similar_group" => 3,
        "conflict" => 4,
        "cross_agent_analysis" => 5,
        "agent" => 6,
        "source" => 7,
        "risk" => 8,
        _ => 9,
    }
}

fn local_skill_map_edge_type_order(edge_type: &str) -> u8 {
    match edge_type {
        "task_route_candidate" => 0,
        "task_readiness" => 1,
        "skill_capability" => 2,
        "similar_group_member" => 3,
        "same_agent_conflict" => 4,
        "cross_agent_analysis" => 5,
        "skill_agent" => 6,
        "skill_source" => 7,
        "skill_risk" => 8,
        _ => 9,
    }
}

fn local_skill_map_cluster_type_order(cluster_type: &str) -> u8 {
    match cluster_type {
        "capability_domain" => 0,
        "similar_group" => 1,
        "conflict" => 2,
        _ => 3,
    }
}

fn local_skill_map_risk_notes(
    nodes: &[LocalSkillMapNode],
    edges: &[LocalSkillMapEdge],
    readiness: Option<&TaskReadinessResult>,
    routing: Option<&SkillRouteRankingResult>,
) -> Vec<String> {
    let mut notes = Vec::new();
    let high_or_blocked = nodes
        .iter()
        .filter(|node| {
            node.node_type == "skill"
                && matches!(node.risk_level.as_deref(), Some("high" | "blocked"))
        })
        .count();
    if high_or_blocked > 0 {
        notes.push(format!(
            "{high_or_blocked} mapped skill node(s) carry high or blocked risk signals from local evidence."
        ));
    }
    let conflict_edges = edges
        .iter()
        .filter(|edge| edge.edge_type == "same_agent_conflict")
        .count();
    if conflict_edges > 0 {
        notes.push(
            "Same-agent conflict edges are advisory and never select winners or mutate config."
                .to_string(),
        );
    }
    if let Some(readiness) = readiness {
        notes.extend(readiness.blocker_risk_notes.iter().take(6).cloned());
    }
    if let Some(routing) = routing {
        notes.extend(routing.ambiguity_warnings.iter().take(6).cloned());
    }
    if notes.is_empty() {
        notes.push(
            "Local Skill Map did not find high-risk returned nodes; risk buckets remain review-only."
                .to_string(),
        );
    }
    normalize_note_list(&mut notes);
    notes
}

fn local_skill_map_summary(
    indexed_skill_count: usize,
    candidate_skill_count: usize,
    cluster_count: usize,
    nodes: &[LocalSkillMapNode],
    edges: &[LocalSkillMapEdge],
    clusters: &[LocalSkillMapCluster],
    domains: &[LocalSkillMapDomain],
) -> LocalSkillMapSummary {
    let skill_node_count = nodes
        .iter()
        .filter(|node| node.node_type == "skill")
        .count();
    let capability_node_count = nodes
        .iter()
        .filter(|node| node.node_type == "capability")
        .count();
    let similar_group_node_count = nodes
        .iter()
        .filter(|node| node.node_type == "similar_group")
        .count();
    let conflict_node_count = nodes
        .iter()
        .filter(|node| node.node_type == "conflict")
        .count();
    let risk_node_count = nodes.iter().filter(|node| node.node_type == "risk").count();
    let task_coverage_edge_count = edges
        .iter()
        .filter(|edge| {
            edge.edge_type == "task_readiness" || edge.edge_type == "task_route_candidate"
        })
        .count();
    let cross_agent_edge_count = edges
        .iter()
        .filter(|edge| edge.edge_type == "cross_agent_analysis")
        .count();
    let summary = if nodes.is_empty() {
        "No deterministic local skill map nodes matched the selected filters.".to_string()
    } else {
        format!(
            "Returned {} node(s), {} edge(s), and {} cluster(s) from {} candidate skill(s) across {} indexed visible skill(s).",
            nodes.len(),
            edges.len(),
            clusters.len(),
            candidate_skill_count,
            indexed_skill_count
        )
    };
    LocalSkillMapSummary {
        indexed_skill_count,
        candidate_skill_count,
        returned_node_count: nodes.len(),
        returned_edge_count: edges.len(),
        cluster_count,
        returned_cluster_count: clusters.len(),
        domain_count: domains.len(),
        skill_node_count,
        capability_node_count,
        similar_group_node_count,
        conflict_node_count,
        risk_node_count,
        task_coverage_edge_count,
        cross_agent_edge_count,
        summary,
    }
}

fn local_skill_map_skill_node_id(instance_id: &str) -> String {
    format!("skill:{}", redact_for_llm_preview(instance_id))
}

fn local_skill_map_agent_node_id(agent: &str) -> String {
    format!("agent:{}", redact_for_llm_preview(agent))
}

fn local_skill_map_source_node_id(source: &KnowledgeSearchSource) -> String {
    stable_local_skill_map_node_id(
        "source",
        &[
            source.root_provenance.as_str(),
            source.display_path.as_str(),
            source.fingerprint.as_str(),
        ],
    )
}

fn local_skill_map_risk_node_id(risk_level: &str) -> String {
    format!("risk:{risk_level}")
}

fn local_skill_map_capability_node_id(domain_id: &str) -> String {
    format!("capability:{}", redact_for_llm_preview(domain_id))
}

fn local_skill_map_similar_group_node_id(group_id: &str) -> String {
    format!("similar_group:{}", redact_for_llm_preview(group_id))
}

fn local_skill_map_conflict_node_id(conflict_id: &str) -> String {
    format!("conflict:{}", redact_for_llm_preview(conflict_id))
}

fn local_skill_map_analysis_node_id(analysis_id: &str) -> String {
    format!("analysis:{}", redact_for_llm_preview(analysis_id))
}

fn stable_local_skill_map_node_id(prefix: &str, parts: &[&str]) -> String {
    let mut hasher = Sha256::new();
    for part in parts {
        hasher.update(part.as_bytes());
        hasher.update(b"\0");
    }
    let digest = hasher.finalize();
    format!("{prefix}:{}", hex_prefix(&digest, 16))
}

fn stable_local_skill_map_edge_id(edge_type: &str, source: &str, target: &str) -> String {
    stable_local_skill_map_node_id("edge", &[edge_type, source, target])
}

fn workspace_readiness_safety_flags() -> WorkspaceReadinessSafetyFlags {
    agent_readiness_safety_flags()
}

fn workspace_readiness_filters(
    params: &WorkspaceReadinessParams,
    redaction_roots: &[(String, &'static str)],
) -> WorkspaceReadinessFilters {
    let mut expected_capabilities = params
        .expected_capabilities
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    expected_capabilities.sort();
    let mut candidate_instance_ids = params
        .candidate_instance_ids
        .iter()
        .map(|value| redact_for_llm_preview(value.trim()))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    candidate_instance_ids.sort();
    candidate_instance_ids.dedup();
    WorkspaceReadinessFilters {
        agent: params.agent.as_deref().and_then(normalize_agent_label),
        task: params
            .task
            .as_deref()
            .map(str::trim)
            .filter(|task| !task.is_empty())
            .map(redact_for_llm_preview),
        project_root: params
            .project_root
            .as_deref()
            .map(str::trim)
            .filter(|path| !path.is_empty())
            .map(|path| redact_string(&redact_for_llm_preview(path), redaction_roots)),
        expected_capabilities,
        limit: params.limit.unwrap_or(12).clamp(1, 50),
        candidate_instance_ids,
    }
}

fn empty_workspace_readiness_result(
    filters: WorkspaceReadinessFilters,
    catalog_available: bool,
) -> WorkspaceReadinessResult {
    WorkspaceReadinessResult {
        generated_by: "deterministic-service",
        catalog_available,
        filters: filters.clone(),
        summary: WorkspaceReadinessSummary {
            workspace_available: false,
            project_available: false,
            visible_skill_count: 0,
            enabled_skill_count: 0,
            agent_count: 0,
            domain_count: 0,
            capability_count: 0,
            ready_count: 0,
            partial_count: 0,
            blocked_count: 1,
            gap_count: 1,
            blocker_count: 1,
            summary: "No local catalog is available, so workspace readiness has no skill evidence."
                .to_string(),
        },
        readiness_rows: vec![WorkspaceReadinessChecklistRow {
            id: "workspace-readiness-catalog".to_string(),
            category: "catalog",
            status: "blocked",
            score: 0,
            title: "Local catalog unavailable".to_string(),
            detail: "Run a local scan before relying on workspace readiness.".to_string(),
            agent: None,
            capability: None,
            evidence_refs: Vec::new(),
        }],
        checklist_rows: vec![WorkspaceReadinessChecklistRow {
            id: "workspace-readiness-catalog".to_string(),
            category: "catalog",
            status: "blocked",
            score: 0,
            title: "Local catalog unavailable".to_string(),
            detail: "Run a local scan before relying on workspace readiness.".to_string(),
            agent: None,
            capability: None,
            evidence_refs: Vec::new(),
        }],
        agent_rows: Vec::new(),
        capability_rows: Vec::new(),
        gap_notes: vec![
            "Run a local scan before relying on workspace readiness for project coverage review."
                .to_string(),
        ],
        blocker_notes: vec![
            "No provider request was sent and no fallback network lookup was attempted."
                .to_string(),
        ],
        evidence_references: Vec::new(),
        prompt_request: WorkspaceReadinessPromptRequest {
            available: false,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "workspace_readiness",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::WorkspaceReadiness,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: Vec::new(),
                analysis_kind: None,
                user_intent: Some(
                    "Explain deterministic workspace readiness using only local catalog evidence."
                        .to_string(),
                ),
            },
            note: "Prompt preview is unavailable until local catalog evidence exists.".to_string(),
        },
        safety_flags: workspace_readiness_safety_flags(),
    }
}

fn workspace_detail_matches(project_root: Option<&Path>, detail: &SkillDetailRecord) -> bool {
    let Some(project_root) = project_root else {
        return true;
    };
    detail.scope == Scope::AgentProject.as_str()
        || detail.path.starts_with(project_root)
        || detail.display_path.starts_with(project_root)
}

fn workspace_status_for_score(score: u8) -> &'static str {
    match score {
        80..=100 => "ready",
        45..=79 => "partial",
        _ => "blocked",
    }
}

fn workspace_status_counts<'a>(
    statuses: impl IntoIterator<Item = &'a str>,
) -> (usize, usize, usize) {
    let mut ready = 0usize;
    let mut partial = 0usize;
    let mut blocked = 0usize;
    for status in statuses {
        match status {
            "ready" => ready += 1,
            "partial" => partial += 1,
            _ => blocked += 1,
        }
    }
    (ready, partial, blocked)
}

fn workspace_capability_rows(
    expected_capabilities: &[String],
    taxonomy: &CapabilityTaxonomyResult,
) -> Vec<WorkspaceReadinessCapabilityRow> {
    let expected_keys = expected_capabilities
        .iter()
        .map(|capability| capability_key(capability))
        .collect::<BTreeSet<_>>();
    let mut rows = taxonomy
        .coverage_rows
        .iter()
        .map(|coverage| {
            let expected = expected_keys.is_empty()
                || expected_keys.contains(&capability_key(&coverage.domain_name))
                || expected_keys.contains(&coverage.domain_key);
            let blocker_notes = if coverage.routing_ambiguity != "low" {
                vec![format!(
                    "`{}` has routing ambiguity signals.",
                    redact_for_llm_preview(&coverage.domain_name)
                )]
            } else if coverage.duplicates_redundancy != "low" {
                vec![format!(
                    "`{}` has duplicate or redundancy signals.",
                    redact_for_llm_preview(&coverage.domain_name)
                )]
            } else {
                Vec::new()
            };
            WorkspaceReadinessCapabilityRow {
                capability: coverage.domain_name.clone(),
                domain_key: coverage.domain_key.clone(),
                domain_name: coverage.domain_name.clone(),
                status: workspace_status_for_score(coverage.coverage_score),
                coverage_level: coverage.coverage_level,
                coverage_score: coverage.coverage_score,
                expected,
                skill_count: coverage.skill_count,
                enabled_skill_count: coverage.enabled_skill_count,
                agent_count: coverage.agent_count,
                gap_notes: coverage.gaps.clone(),
                blocker_notes,
                evidence_refs: coverage.evidence_refs.clone(),
            }
        })
        .collect::<Vec<_>>();

    for expected in expected_capabilities {
        let key = capability_key(expected);
        if rows
            .iter()
            .any(|row| row.domain_key == key || capability_key(&row.capability) == key)
        {
            continue;
        }
        rows.push(WorkspaceReadinessCapabilityRow {
            capability: expected.clone(),
            domain_key: key.clone(),
            domain_name: expected.clone(),
            status: "blocked",
            coverage_level: "gap",
            coverage_score: 0,
            expected: true,
            skill_count: 0,
            enabled_skill_count: 0,
            agent_count: 0,
            gap_notes: vec![format!(
                "Expected capability `{}` has no matching local capability-domain evidence.",
                redact_for_llm_preview(expected)
            )],
            blocker_notes: vec![format!(
                "Expected capability `{}` is not covered by visible local skills.",
                redact_for_llm_preview(expected)
            )],
            evidence_refs: Vec::new(),
        });
    }
    rows.sort_by(|left, right| {
        right
            .expected
            .cmp(&left.expected)
            .then_with(|| right.coverage_score.cmp(&left.coverage_score))
            .then_with(|| left.domain_name.cmp(&right.domain_name))
    });
    rows
}

fn capability_key(value: &str) -> String {
    value
        .to_ascii_lowercase()
        .chars()
        .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

#[allow(clippy::too_many_arguments)]
fn workspace_checklist_rows(
    filters: &WorkspaceReadinessFilters,
    visible_details: &[SkillDetailRecord],
    findings: &[RuleFindingRecord],
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
    diagnostics: &[AdapterDiagnosticsRecord],
    taxonomy: &CapabilityTaxonomyResult,
    task_readiness: Option<&TaskReadinessResult>,
    route_ranking: Option<&SkillRouteRankingResult>,
    stale_drift: &StaleDriftDetectionResult,
    similar: &SimilarSkillGroupingResult,
) -> Vec<WorkspaceReadinessChecklistRow> {
    let mut rows = Vec::new();
    let visible_count = visible_details.len();
    let enabled_count = visible_details.iter().filter(|skill| skill.enabled).count();
    let project_count = visible_details
        .iter()
        .filter(|skill| skill.scope == Scope::AgentProject.as_str())
        .count();
    let coverage_score = if taxonomy.summary.domain_count == 0 {
        0
    } else {
        taxonomy
            .coverage_rows
            .iter()
            .map(|row| usize::from(row.coverage_score))
            .sum::<usize>()
            .checked_div(taxonomy.coverage_rows.len().max(1))
            .unwrap_or(0)
            .min(100) as u8
    };
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-capability-coverage".to_string(),
        category: "capability_coverage",
        status: workspace_status_for_score(coverage_score),
        score: coverage_score,
        title: "Capability coverage".to_string(),
        detail: format!(
            "{} capability domain(s) are visible across {} local skill(s).",
            taxonomy.summary.domain_count, visible_count
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: taxonomy
            .coverage_rows
            .iter()
            .flat_map(|row| row.evidence_refs.iter().cloned())
            .take(8)
            .collect(),
    });

    let enabled_score = enabled_count
        .checked_mul(100)
        .and_then(|score| score.checked_div(visible_count))
        .unwrap_or(0)
        .min(100) as u8;
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-enabled-scope".to_string(),
        category: "enabled_scoped_state",
        status: workspace_status_for_score(enabled_score),
        score: enabled_score,
        title: "Enabled and scoped skills".to_string(),
        detail: format!(
            "{} of {} visible skill(s) are enabled; {} are project-scoped.",
            enabled_count, visible_count, project_count
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: Vec::new(),
    });

    let blocking_finding_count = findings
        .iter()
        .filter(|finding| matches!(finding.effective_severity.as_str(), "critical" | "error"))
        .count();
    let risk_score = (100i16
        - (blocking_finding_count as i16 * 18).min(54)
        - (conflicts.len() as i16 * 16).min(32)
        - (analysis_groups.len() as i16 * 4).min(20))
    .clamp(0, 100) as u8;
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-risk-findings".to_string(),
        category: "risk_finding_state",
        status: workspace_status_for_score(risk_score),
        score: risk_score,
        title: "Risk and finding state".to_string(),
        detail: format!(
            "{} blocking finding(s), {} same-agent conflict(s), and {} cross-agent analysis group(s) are visible.",
            blocking_finding_count,
            conflicts.len(),
            analysis_groups.len()
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: Vec::new(),
    });

    let stale_score = (100i16
        - (stale_drift.summary.high_risk_count as i16 * 20).min(60)
        - (stale_drift.summary.medium_risk_count as i16 * 10).min(30)
        - (stale_drift.summary.drift_count as i16 * 6).min(24))
    .clamp(0, 100) as u8;
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-stale-drift".to_string(),
        category: "stale_drift",
        status: workspace_status_for_score(stale_score),
        score: stale_score,
        title: "Stale and drift signals".to_string(),
        detail: format!(
            "{} stale/drift row(s), {} high-risk row(s), and {} drift signal(s) were derived locally.",
            stale_drift.summary.returned_row_count,
            stale_drift.summary.high_risk_count,
            stale_drift.summary.drift_count
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: stale_drift
            .stale_drift_rows
            .iter()
            .flat_map(|row| row.evidence_refs.iter().cloned())
            .take(8)
            .collect(),
    });

    let ambiguity_count = similar.summary.routing_ambiguity_count
        + route_ranking
            .map(|ranking| ranking.ambiguity_warnings.len())
            .unwrap_or(0);
    let ambiguity_score = (100i16 - (ambiguity_count as i16 * 18).min(72)).clamp(0, 100) as u8;
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-routing-ambiguity".to_string(),
        category: "routing_ambiguity",
        status: workspace_status_for_score(ambiguity_score),
        score: ambiguity_score,
        title: "Routing ambiguity".to_string(),
        detail: format!(
            "{} similar-skill group(s) and {} routing ambiguity signal(s) are visible.",
            similar.summary.returned_group_count, ambiguity_count
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: similar
            .groups
            .iter()
            .flat_map(|group| group.evidence_refs.iter().cloned())
            .take(8)
            .collect(),
    });

    let blocked_adapter_count = diagnostics
        .iter()
        .filter(|diagnostic| {
            diagnostic.status == "blocked" || diagnostic.access.writable_status == "blocked"
        })
        .count();
    let adapter_score = (100i16 - (blocked_adapter_count as i16 * 12).min(60)).clamp(0, 100) as u8;
    rows.push(WorkspaceReadinessChecklistRow {
        id: "workspace-readiness-adapter-capability".to_string(),
        category: "adapter_capability",
        status: workspace_status_for_score(adapter_score),
        score: adapter_score,
        title: "Adapter capability".to_string(),
        detail: format!(
            "{} adapter diagnostic row(s) are available; {} have blocked status.",
            diagnostics.len(),
            blocked_adapter_count
        ),
        agent: filters.agent.clone(),
        capability: None,
        evidence_refs: Vec::new(),
    });

    if let Some(readiness) = task_readiness {
        rows.push(WorkspaceReadinessChecklistRow {
            id: "workspace-readiness-task-fit".to_string(),
            category: "task_fit",
            status: workspace_status_for_score(readiness.score),
            score: readiness.score,
            title: "Task readiness".to_string(),
            detail: readiness.summary.clone(),
            agent: filters.agent.clone(),
            capability: None,
            evidence_refs: readiness
                .candidate_skills
                .iter()
                .flat_map(|candidate| candidate.evidence_refs.iter().cloned())
                .take(8)
                .collect(),
        });
    }

    rows.sort_by(|left, right| {
        workspace_status_rank(left.status)
            .cmp(&workspace_status_rank(right.status))
            .then_with(|| left.score.cmp(&right.score))
            .then_with(|| left.category.cmp(right.category))
    });
    rows
}

fn workspace_status_rank(status: &str) -> u8 {
    match status {
        "blocked" => 0,
        "partial" => 1,
        "ready" => 2,
        _ => 3,
    }
}

fn workspace_agent_rows_from_comparison(
    comparison: &AgentReadinessComparisonResult,
    visible_details: &[SkillDetailRecord],
    diagnostics: &[AdapterDiagnosticsRecord],
) -> Vec<WorkspaceReadinessAgentRow> {
    comparison
        .agent_rows
        .iter()
        .map(|row| {
            let diagnostic = diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == row.agent);
            let visible_skill_count = visible_details
                .iter()
                .filter(|skill| skill.agent == row.agent)
                .count();
            let enabled_skill_count = visible_details
                .iter()
                .filter(|skill| skill.agent == row.agent && skill.enabled)
                .count();
            let project_skill_count = visible_details
                .iter()
                .filter(|skill| {
                    skill.agent == row.agent && skill.scope == Scope::AgentProject.as_str()
                })
                .count();
            WorkspaceReadinessAgentRow {
                agent: row.agent.clone(),
                display_name: row.display_name.clone(),
                status: workspace_status_for_score(row.comparison_score),
                score: row.comparison_score,
                visible_skill_count,
                enabled_skill_count,
                project_skill_count,
                best_candidate: row.best_candidate.clone(),
                adapter_status: diagnostic.map(|diagnostic| diagnostic.status.to_string()),
                writable_status: diagnostic
                    .map(|diagnostic| diagnostic.access.writable_status.to_string()),
                install_status: diagnostic
                    .map(|diagnostic| diagnostic.access.install_status.to_string()),
                gap_count: row.gap_count,
                blocker_count: row.blocker_count,
                notes: row
                    .gap_notes
                    .iter()
                    .chain(row.blocker_notes.iter())
                    .take(8)
                    .cloned()
                    .collect(),
                evidence_refs: row.evidence_refs.clone(),
            }
        })
        .collect()
}

fn workspace_agent_rows_from_catalog(
    visible_details: &[SkillDetailRecord],
    diagnostics: &[AdapterDiagnosticsRecord],
    agent_filter: Option<&str>,
) -> Vec<WorkspaceReadinessAgentRow> {
    let mut agents = visible_details
        .iter()
        .filter_map(|skill| normalize_agent_label(&skill.agent))
        .collect::<BTreeSet<_>>();
    for diagnostic in diagnostics {
        if agent_matches(agent_filter, Some(diagnostic.agent)) {
            agents.insert(diagnostic.agent.to_string());
        }
    }
    agents
        .into_iter()
        .filter(|agent| agent_matches(agent_filter, Some(agent.as_str())))
        .map(|agent| {
            let diagnostic = diagnostics
                .iter()
                .find(|diagnostic| diagnostic.agent == agent);
            let visible_skill_count = visible_details
                .iter()
                .filter(|skill| skill.agent == agent)
                .count();
            let enabled_skill_count = visible_details
                .iter()
                .filter(|skill| skill.agent == agent && skill.enabled)
                .count();
            let project_skill_count = visible_details
                .iter()
                .filter(|skill| skill.agent == agent && skill.scope == Scope::AgentProject.as_str())
                .count();
            let enabled_portion = enabled_skill_count
                .checked_mul(45)
                .and_then(|score| score.checked_div(visible_skill_count))
                .unwrap_or(0)
                .min(45) as i16;
            let mut score = if visible_skill_count == 0 {
                0i16
            } else {
                35 + enabled_portion + (project_skill_count.min(2) as i16 * 5)
            };
            if diagnostic
                .map(|diagnostic| diagnostic.status == "blocked")
                .unwrap_or(false)
            {
                score -= 25;
            }
            let score = score.clamp(0, 100) as u8;
            let mut notes = Vec::new();
            if visible_skill_count == 0 {
                notes.push("No visible skills were found for this agent.".to_string());
            }
            if enabled_skill_count < visible_skill_count {
                notes.push(format!(
                    "{} of {} visible skill(s) are disabled.",
                    visible_skill_count.saturating_sub(enabled_skill_count),
                    visible_skill_count
                ));
            }
            if let Some(diagnostic) = diagnostic {
                notes.push(format!(
                    "Adapter diagnostics status={}, writable_status={}, install_status={}.",
                    diagnostic.status,
                    diagnostic.access.writable_status,
                    diagnostic.access.install_status
                ));
            }
            WorkspaceReadinessAgentRow {
                agent: agent.clone(),
                display_name: agent_readiness_display_name(&agent),
                status: workspace_status_for_score(score),
                score,
                visible_skill_count,
                enabled_skill_count,
                project_skill_count,
                best_candidate: None,
                adapter_status: diagnostic.map(|diagnostic| diagnostic.status.to_string()),
                writable_status: diagnostic
                    .map(|diagnostic| diagnostic.access.writable_status.to_string()),
                install_status: diagnostic
                    .map(|diagnostic| diagnostic.access.install_status.to_string()),
                gap_count: usize::from(visible_skill_count == 0),
                blocker_count: usize::from(score < 45),
                notes,
                evidence_refs: Vec::new(),
            }
        })
        .collect()
}

struct WorkspaceReadinessSummaryInput<'a> {
    project_root: Option<&'a Path>,
    visible_details: &'a [SkillDetailRecord],
    taxonomy: &'a CapabilityTaxonomyResult,
    readiness_rows: &'a [WorkspaceReadinessChecklistRow],
    agent_rows: &'a [WorkspaceReadinessAgentRow],
    capability_rows: &'a [WorkspaceReadinessCapabilityRow],
    gap_notes: &'a [String],
    blocker_notes: &'a [String],
}

fn workspace_readiness_summary(
    input: WorkspaceReadinessSummaryInput<'_>,
) -> WorkspaceReadinessSummary {
    let agent_count = input
        .visible_details
        .iter()
        .filter_map(|skill| normalize_agent_label(&skill.agent))
        .collect::<BTreeSet<_>>()
        .len()
        .max(input.agent_rows.len());
    let visible_skill_count = input.visible_details.len();
    let enabled_skill_count = input
        .visible_details
        .iter()
        .filter(|skill| skill.enabled)
        .count();
    let statuses = input
        .readiness_rows
        .iter()
        .map(|row| row.status)
        .chain(input.agent_rows.iter().map(|row| row.status))
        .chain(input.capability_rows.iter().map(|row| row.status))
        .collect::<Vec<_>>();
    let (ready_count, partial_count, blocked_count) = workspace_status_counts(statuses);
    let project_available = input.project_root.is_some()
        || input
            .visible_details
            .iter()
            .any(|skill| skill.scope == Scope::AgentProject.as_str());
    let summary = if visible_skill_count == 0 {
        "Workspace readiness is blocked because no visible local skills matched the selected workspace filters."
            .to_string()
    } else if blocked_count > 0 {
        format!(
            "Workspace readiness is partial: {} visible skill(s), {} capability row(s), and {} blocker row(s) need review.",
            visible_skill_count,
            input.capability_rows.len(),
            blocked_count
        )
    } else {
        format!(
            "Workspace readiness is ready across {} visible skill(s), {} agent(s), and {} capability row(s).",
            visible_skill_count,
            agent_count,
            input.capability_rows.len()
        )
    };
    WorkspaceReadinessSummary {
        workspace_available: visible_skill_count > 0,
        project_available,
        visible_skill_count,
        enabled_skill_count,
        agent_count,
        domain_count: input.taxonomy.summary.domain_count,
        capability_count: input.capability_rows.len(),
        ready_count,
        partial_count,
        blocked_count,
        gap_count: input.gap_notes.len(),
        blocker_count: input.blocker_notes.len(),
        summary,
    }
}
