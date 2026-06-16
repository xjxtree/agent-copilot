use super::*;

pub(crate) fn llm_prompt_run_record_sort(
    left: &LlmPromptRunRecord,
    right: &LlmPromptRunRecord,
) -> std::cmp::Ordering {
    right
        .completed_at
        .cmp(&left.completed_at)
        .then_with(|| right.created_at.cmp(&left.created_at))
        .then_with(|| left.action.cmp(&right.action))
        .then_with(|| left.id.cmp(&right.id))
}

pub(crate) fn generated_llm_prompt_run_id(
    preview_id: &str,
    confirmation_id: &str,
    completed_at: i64,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(preview_id.as_bytes());
    hasher.update(b"\0");
    hasher.update(confirmation_id.as_bytes());
    hasher.update(b"\0");
    hasher.update(completed_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("prompt-run-{}", hex_prefix(&digest, 12))
}

pub(crate) fn trace_content_hash(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    let digest = hasher.finalize();
    hex_prefix(&digest, 16)
}

pub(crate) fn generated_trace_import_id(
    title: &str,
    content_hash: &str,
    imported_at: i64,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(content_hash.as_bytes());
    hasher.update(b"\0");
    hasher.update(imported_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("trace-import-{}", hex_prefix(&digest, 12))
}

pub(crate) fn generated_agent_session_review_id(
    title: &str,
    content_hash: &str,
    reviewed_at: i64,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(content_hash.as_bytes());
    hasher.update(b"\0");
    hasher.update(reviewed_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("agent-session-review-{}", hex_prefix(&digest, 12))
}

pub(crate) fn sanitize_trace_import_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

pub(crate) fn sanitize_agent_session_review_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

pub(crate) fn agent_session_review_record_sort(
    left: &AgentSessionSkillReviewRecord,
    right: &AgentSessionSkillReviewRecord,
) -> std::cmp::Ordering {
    right
        .reviewed_at
        .cmp(&left.reviewed_at)
        .then_with(|| left.title.cmp(&right.title))
        .then_with(|| left.id.cmp(&right.id))
}

pub(crate) fn single_referenced_trace_agent(imports: &[TraceImportRecord]) -> Option<String> {
    let mut agents = imports
        .iter()
        .filter_map(|import| import.agent.as_deref())
        .filter(|agent| !agent.is_empty())
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>();
    agents.sort();
    agents.dedup();
    if agents.len() == 1 {
        agents.pop()
    } else {
        None
    }
}

pub(crate) fn agent_session_expected_skill_signals(
    expected_skill_refs: &[String],
    expected_skill_names: &[String],
    detected: &[TraceDetectedSkill],
) -> Vec<AgentSessionExpectedSkillSignal> {
    let mut signals = Vec::new();
    for expected in expected_skill_refs {
        let mut matched_instance_ids = detected
            .iter()
            .filter(|skill| {
                skill.instance_id.eq_ignore_ascii_case(expected)
                    || skill.definition_id.eq_ignore_ascii_case(expected)
            })
            .map(|skill| skill.instance_id.clone())
            .collect::<Vec<_>>();
        matched_instance_ids.sort();
        matched_instance_ids.dedup();
        signals.push(AgentSessionExpectedSkillSignal {
            kind: "skill_ref".to_string(),
            value: expected.clone(),
            matched: !matched_instance_ids.is_empty(),
            matched_instance_ids,
        });
    }
    for expected in expected_skill_names {
        let mut matched_instance_ids = detected
            .iter()
            .filter(|skill| skill.skill_name.eq_ignore_ascii_case(expected))
            .map(|skill| skill.instance_id.clone())
            .collect::<Vec<_>>();
        matched_instance_ids.sort();
        matched_instance_ids.dedup();
        signals.push(AgentSessionExpectedSkillSignal {
            kind: "skill_name".to_string(),
            value: expected.clone(),
            matched: !matched_instance_ids.is_empty(),
            matched_instance_ids,
        });
    }
    signals
}

pub(crate) fn agent_session_review_summary(
    outcome: &str,
    detected_count: usize,
    expected_signal_count: usize,
    referenced_trace_count: usize,
    missing_trace_count: usize,
) -> String {
    format!(
        "Session skill-use review outcome is {outcome}; detected {detected_count} skill signal(s), checked {expected_signal_count} expected signal(s), reused {referenced_trace_count} trace import(s), and missed {missing_trace_count} requested trace reference(s)."
    )
}

pub(crate) fn generated_remediation_history_id(
    title: &str,
    decision: &str,
    recorded_at: i64,
) -> String {
    let mut hasher = Sha256::new();
    hasher.update(title.as_bytes());
    hasher.update(b"\0");
    hasher.update(decision.as_bytes());
    hasher.update(b"\0");
    hasher.update(recorded_at.to_string().as_bytes());
    let digest = hasher.finalize();
    format!("rem-history-{}", hex_prefix(&digest, 12))
}

pub(crate) fn sanitize_remediation_history_id(id: &str) -> String {
    id.chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_'))
        .take(96)
        .collect()
}

pub(crate) fn normalize_history_token(value: &str) -> String {
    let token = redact_for_llm_preview(value)
        .trim()
        .to_lowercase()
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() || matches!(ch, '-' | '_') {
                ch
            } else if ch.is_whitespace() || matches!(ch, '/' | ':' | '.') {
                '-'
            } else {
                '\0'
            }
        })
        .filter(|ch| *ch != '\0')
        .collect::<String>();
    token
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-")
        .chars()
        .take(80)
        .collect()
}

pub(crate) fn redact_history_string_list(
    values: Vec<String>,
    redactor: &mut PromptRedactor<'_>,
    max_chars: usize,
    limit: usize,
) -> Vec<String> {
    let mut normalized = values
        .into_iter()
        .map(|value| truncate_chars(&redactor.redact(value.trim()), max_chars))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    normalized.sort();
    normalized.dedup();
    normalized.truncate(limit);
    normalized
}

pub(crate) fn redact_normalized_string_list(
    values: Vec<String>,
    roots: &[(String, &'static str)],
) -> Vec<String> {
    let mut redactor = PromptRedactor::new(roots);
    normalize_string_list(
        values
            .into_iter()
            .map(|value| redactor.redact(&value))
            .collect(),
    )
}

pub(crate) fn truncate_chars(value: &str, max_chars: usize) -> String {
    let mut truncated = value.chars().take(max_chars).collect::<String>();
    if value.chars().count() > max_chars {
        truncated.push_str("...");
    }
    truncated
}

pub(crate) fn trace_outcome_reasons(
    outcome: &str,
    detected_count: usize,
    matching_expected: usize,
    unexpected_detected: usize,
    expected_present: bool,
    agent_filter: Option<&str>,
) -> Vec<String> {
    let mut reasons = Vec::new();
    match outcome {
        "hit" => reasons.push(format!(
            "Detected {} skill reference(s) and all matched expected skill refs/names.",
            detected_count
        )),
        "miss" => reasons.push(
            "Expected skill refs/names were provided, but no matching local catalog skill was detected in the trace."
                .to_string(),
        ),
        "wrong_pick" => reasons.push(format!(
            "Detected {} local catalog skill reference(s), but none matched expected skill refs/names.",
            detected_count
        )),
        "ambiguous" => {
            if matching_expected > 0 {
                reasons.push(format!(
                    "Detected {} expected skill reference(s) plus {} other local catalog skill reference(s).",
                    matching_expected, unexpected_detected
                ));
            } else {
                reasons.push(format!(
                    "Detected {} local catalog skill reference(s), so the trace is ambiguous without expected skill refs/names.",
                    detected_count
                ));
            }
        }
        _ => {
            if expected_present {
                reasons.push(
                    "Local catalog evidence was insufficient to classify the imported trace."
                        .to_string(),
                );
            } else {
                reasons.push(
                    "No expected skill refs/names were provided; routing accuracy cannot be classified deterministically."
                        .to_string(),
                );
            }
        }
    }
    if let Some(agent) = agent_filter.filter(|agent| !agent.is_empty()) {
        reasons.push(format!("Detection was filtered to agent `{}`.", agent));
    }
    reasons
}

pub(crate) fn task_benchmark_evaluation_item(
    benchmark: &TaskBenchmarkRecord,
    ranking: SkillRouteRankingResult,
) -> TaskBenchmarkEvaluationItem {
    let top_route = ranking.route_candidates.first();
    let (expected_match_status, expected_match_reasons) =
        task_benchmark_match_status(benchmark, top_route);
    let route_confidence_score = top_route
        .map(|candidate| candidate.confidence_score)
        .unwrap_or(ranking.overall_confidence_score);
    let route_confidence_band = top_route
        .map(|candidate| candidate.confidence_band)
        .unwrap_or(ranking.overall_confidence_band);
    let score = task_benchmark_score(route_confidence_score, expected_match_status);
    let mut gap_notes = ranking.likely_miss_risks.clone();
    if gap_notes.is_empty() {
        gap_notes.push(
            "No benchmark-level miss risk was detected from local routing evidence.".to_string(),
        );
    }
    let mut blocker_notes = ranking.likely_wrong_pick_risks.clone();
    blocker_notes.extend(ranking.ambiguity_warnings.clone());
    if blocker_notes.is_empty() {
        blocker_notes.push(
            "No benchmark-level blocker was detected from local routing evidence.".to_string(),
        );
    }
    let evidence_refs = top_route
        .map(|candidate| candidate.evidence_refs.clone())
        .unwrap_or_default();
    TaskBenchmarkEvaluationItem {
        benchmark_id: benchmark.id.clone(),
        title: benchmark.title.clone(),
        task: ranking.task,
        score,
        band: task_benchmark_band(score),
        expected_match_status,
        expected_match_reasons,
        top_route: top_route.map(task_benchmark_route_summary),
        route_confidence_score,
        route_confidence_band,
        gap_notes,
        blocker_notes,
        evidence_refs,
        safety_flags: task_benchmark_safety_flags(),
    }
}

pub(crate) fn task_benchmark_match_status(
    benchmark: &TaskBenchmarkRecord,
    top_route: Option<&SkillRouteCandidate>,
) -> (&'static str, Vec<String>) {
    let Some(route) = top_route else {
        return (
            "blocked_no_route",
            vec!["No local route candidate was available for this benchmark.".to_string()],
        );
    };
    let expected_refs = benchmark
        .expected_skill_refs
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let expected_names = benchmark
        .expected_skill_names
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let acceptable_agents = benchmark
        .acceptable_agents
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();
    let acceptable_scopes = benchmark
        .acceptable_scopes
        .iter()
        .map(|value| value.to_ascii_lowercase())
        .collect::<Vec<_>>();

    let route_refs = [
        route.instance_id.to_ascii_lowercase(),
        route.definition_id.to_ascii_lowercase(),
    ];
    if expected_refs
        .iter()
        .any(|expected| route_refs.iter().any(|actual| actual == expected))
    {
        return (
            "expected_match",
            vec![format!(
                "Top route `{}` matched an expected skill reference.",
                route.skill_name
            )],
        );
    }
    if expected_names
        .iter()
        .any(|expected| expected == &route.skill_name.to_ascii_lowercase())
    {
        return (
            "expected_match",
            vec![format!(
                "Top route `{}` matched an expected skill name.",
                route.skill_name
            )],
        );
    }

    let agent_ok = acceptable_agents.is_empty()
        || acceptable_agents
            .iter()
            .any(|agent| agent == &route.agent.to_ascii_lowercase());
    let scope_ok = acceptable_scopes.is_empty()
        || acceptable_scopes
            .iter()
            .any(|scope| scope == &route.scope.to_ascii_lowercase());
    if (agent_ok && scope_ok) && (!acceptable_agents.is_empty() || !acceptable_scopes.is_empty()) {
        return (
            "acceptable_match",
            vec![format!(
                "Top route `{}` matched acceptable agent/scope constraints.",
                route.skill_name
            )],
        );
    }
    if expected_refs.is_empty()
        && expected_names.is_empty()
        && acceptable_agents.is_empty()
        && acceptable_scopes.is_empty()
    {
        return (
            "no_expectation",
            vec![
                "Benchmark has no expected skill refs/names or acceptable agent/scope constraints."
                    .to_string(),
            ],
        );
    }

    (
        "mismatch",
        vec![format!(
            "Top route `{}` ({}, {}) did not match benchmark expectations.",
            route.skill_name, route.agent, route.scope
        )],
    )
}

pub(crate) fn task_benchmark_route_summary(
    candidate: &SkillRouteCandidate,
) -> TaskBenchmarkRouteSummary {
    TaskBenchmarkRouteSummary {
        instance_id: candidate.instance_id.clone(),
        definition_id: candidate.definition_id.clone(),
        skill_name: candidate.skill_name.clone(),
        agent: candidate.agent.clone(),
        scope: candidate.scope.clone(),
        confidence_score: candidate.confidence_score,
        confidence_band: candidate.confidence_band,
        readiness_score: candidate.readiness_score,
        readiness_band: candidate.readiness_band,
    }
}

pub(crate) fn task_benchmark_score(route_confidence_score: u8, expected_match_status: &str) -> u8 {
    match expected_match_status {
        "expected_match" => route_confidence_score,
        "acceptable_match" => route_confidence_score.saturating_sub(8),
        "no_expectation" => route_confidence_score.min(60),
        "mismatch" => route_confidence_score / 2,
        _ => 0,
    }
}

pub(crate) fn task_benchmark_band(score: u8) -> &'static str {
    match score {
        80..=100 => "pass",
        60..=79 => "mostly_pass",
        35..=59 => "partial",
        1..=34 => "fail",
        _ => "blocked",
    }
}

pub(crate) fn task_benchmark_summary(
    results: &[TaskBenchmarkEvaluationItem],
    catalog_available: bool,
) -> String {
    if results.is_empty() {
        if catalog_available {
            return "No task benchmarks are saved in app-local storage.".to_string();
        }
        return "No task benchmarks were evaluated and no local catalog is available.".to_string();
    }
    let passing = results
        .iter()
        .filter(|result| {
            matches!(
                result.expected_match_status,
                "expected_match" | "acceptable_match"
            )
        })
        .count();
    let average = results
        .iter()
        .map(|result| u16::from(result.score))
        .sum::<u16>()
        / u16::try_from(results.len()).unwrap_or(1);
    format!(
        "Evaluated {} app-local task benchmark(s); {} matched expected or acceptable routes with average score {}/100.",
        results.len(),
        passing,
        average
    )
}

pub(crate) fn task_benchmark_blocker_notes(
    results: &[TaskBenchmarkEvaluationItem],
    catalog_available: bool,
) -> Vec<String> {
    let mut notes = Vec::new();
    if !catalog_available {
        notes.push(
            "No local catalog is available; run a local scan before relying on benchmark results."
                .to_string(),
        );
    }
    if results.is_empty() {
        notes.push("No app-local benchmarks were selected for evaluation.".to_string());
    }
    notes.extend(
        results
            .iter()
            .filter(|result| result.expected_match_status != "expected_match")
            .map(|result| {
                format!(
                    "Benchmark `{}` status is {}.",
                    result.title, result.expected_match_status
                )
            }),
    );
    notes.sort();
    notes.dedup();
    notes
}

pub(crate) fn task_benchmark_prompt_request(
    results: &[TaskBenchmarkEvaluationItem],
) -> TaskBenchmarkPromptRequest {
    let first = results.iter().find(|result| result.top_route.is_some());
    let (available, instance_ids, task, note) = match first {
        Some(result) => (
            true,
            result
                .top_route
                .as_ref()
                .map(|route| vec![route.instance_id.clone()])
                .unwrap_or_default(),
            Some(result.task.clone()),
            "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.evaluateBenchmarks never sends provider traffic.".to_string(),
        ),
        None => (
            false,
            Vec::new(),
            None,
            "Prompt preview is unavailable until local benchmark evaluation produces a route candidate.".to_string(),
        ),
    };
    TaskBenchmarkPromptRequest {
        available,
        preview_method: "llm.previewPrompt",
        confirm_method: "llm.confirmPromptAndSend",
        action: "routing_confidence",
        request: LlmPreviewPromptParams {
            action: LlmPromptActionKind::RoutingConfidence,
            profile_id: None,
            app_language: None,
            skill_instance_id: None,
            instance_ids,
            analysis_kind: None,
            user_intent: task,
        },
        note,
    }
}

pub(crate) fn routing_regression_baseline_from_evaluation(
    evaluation: TaskBenchmarkEvaluationResult,
) -> RoutingRegressionBaseline {
    RoutingRegressionBaseline {
        schema_version: 1,
        generated_by: "deterministic-service".to_string(),
        generated_at: unix_timestamp_millis(),
        catalog_available: evaluation.catalog_available,
        evaluated_count: evaluation.evaluated_count,
        benchmark_results: evaluation
            .benchmark_results
            .iter()
            .map(routing_regression_baseline_item)
            .collect(),
        safety_flags: task_benchmark_safety_flags(),
    }
}

pub(crate) fn routing_regression_baseline_item(
    item: &TaskBenchmarkEvaluationItem,
) -> RoutingRegressionBaselineItem {
    RoutingRegressionBaselineItem {
        benchmark_id: item.benchmark_id.clone(),
        title: item.title.clone(),
        task: item.task.clone(),
        score: item.score,
        band: item.band.to_string(),
        expected_match_status: item.expected_match_status.to_string(),
        top_route: item
            .top_route
            .as_ref()
            .map(routing_regression_route_snapshot),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.to_string(),
        gap_count: item.gap_notes.len(),
        blocker_count: item.blocker_notes.len(),
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

pub(crate) fn routing_regression_route_snapshot(
    route: &TaskBenchmarkRouteSummary,
) -> RoutingRegressionRouteSnapshot {
    RoutingRegressionRouteSnapshot {
        instance_id: route.instance_id.clone(),
        definition_id: route.definition_id.clone(),
        skill_name: route.skill_name.clone(),
        agent: route.agent.clone(),
        scope: route.scope.clone(),
        confidence_score: route.confidence_score,
        confidence_band: route.confidence_band.to_string(),
        readiness_score: route.readiness_score,
        readiness_band: route.readiness_band.to_string(),
    }
}

pub(crate) fn routing_regression_compare(
    baseline: &RoutingRegressionBaseline,
    current: &TaskBenchmarkEvaluationResult,
    score_drop_threshold: u8,
    confidence_drop_threshold: u8,
) -> Vec<RoutingRegressionItem> {
    let current_by_id = current
        .benchmark_results
        .iter()
        .map(|item| (item.benchmark_id.as_str(), item))
        .collect::<BTreeMap<_, _>>();
    let baseline_by_id = baseline
        .benchmark_results
        .iter()
        .map(|item| (item.benchmark_id.as_str(), item))
        .collect::<BTreeMap<_, _>>();

    let mut items = Vec::new();
    for baseline_item in &baseline.benchmark_results {
        let current_item = current_by_id
            .get(baseline_item.benchmark_id.as_str())
            .copied();
        items.push(routing_regression_compare_item(
            Some(baseline_item),
            current_item,
            score_drop_threshold,
            confidence_drop_threshold,
        ));
    }
    for current_item in &current.benchmark_results {
        if !baseline_by_id.contains_key(current_item.benchmark_id.as_str()) {
            items.push(routing_regression_compare_item(
                None,
                Some(current_item),
                score_drop_threshold,
                confidence_drop_threshold,
            ));
        }
    }
    items.sort_by(|left, right| {
        left.title
            .cmp(&right.title)
            .then_with(|| left.benchmark_id.cmp(&right.benchmark_id))
    });
    items
}

pub(crate) fn routing_regression_compare_item(
    baseline: Option<&RoutingRegressionBaselineItem>,
    current: Option<&TaskBenchmarkEvaluationItem>,
    score_drop_threshold: u8,
    confidence_drop_threshold: u8,
) -> RoutingRegressionItem {
    let benchmark_id = baseline
        .map(|item| item.benchmark_id.clone())
        .or_else(|| current.map(|item| item.benchmark_id.clone()))
        .unwrap_or_default();
    let title = baseline
        .map(|item| item.title.clone())
        .or_else(|| current.map(|item| item.title.clone()))
        .unwrap_or_else(|| benchmark_id.clone());
    let mut reasons = Vec::new();
    let mut evidence_refs = Vec::new();
    let mut regression = false;

    let status = match (baseline, current) {
        (Some(baseline), Some(current)) => {
            evidence_refs.extend(baseline.evidence_refs.clone());
            evidence_refs.extend(current.evidence_refs.clone());
            let score_drop = i16::from(baseline.score) - i16::from(current.score);
            if score_drop > i16::from(score_drop_threshold) {
                regression = true;
                reasons.push(format!(
                    "Benchmark score dropped by {} point(s), above the configured threshold of {}.",
                    score_drop, score_drop_threshold
                ));
            }
            let confidence_drop = i16::from(baseline.route_confidence_score)
                - i16::from(current.route_confidence_score);
            if confidence_drop > i16::from(confidence_drop_threshold) {
                regression = true;
                reasons.push(format!(
                    "Route confidence dropped by {} point(s), above the configured threshold of {}.",
                    confidence_drop, confidence_drop_threshold
                ));
            }
            if routing_match_rank(current.expected_match_status)
                < routing_match_rank(&baseline.expected_match_status)
            {
                regression = true;
                reasons.push(format!(
                    "Expected match status worsened from {} to {}.",
                    baseline.expected_match_status, current.expected_match_status
                ));
            }
            let current_route = current
                .top_route
                .as_ref()
                .map(routing_regression_route_snapshot);
            if baseline.top_route != current_route {
                regression = true;
                reasons.push(routing_route_change_reason(
                    baseline.top_route.as_ref(),
                    current_route.as_ref(),
                ));
            }
            if current.gap_notes.len() > baseline.gap_count {
                regression = true;
                reasons.push(format!(
                    "Gap note count increased from {} to {}.",
                    baseline.gap_count,
                    current.gap_notes.len()
                ));
            }
            if current.blocker_notes.len() > baseline.blocker_count {
                regression = true;
                reasons.push(format!(
                    "Blocker note count increased from {} to {}.",
                    baseline.blocker_count,
                    current.blocker_notes.len()
                ));
            }
            if regression {
                "regression"
            } else {
                reasons.push(
                    "Current routing result matches the saved baseline within configured thresholds."
                        .to_string(),
                );
                "unchanged"
            }
        }
        (Some(baseline), None) => {
            regression = true;
            evidence_refs.extend(baseline.evidence_refs.clone());
            reasons.push(
                "Benchmark existed in the saved baseline but was not present in the current evaluation."
                    .to_string(),
            );
            "missing_current_benchmark"
        }
        (None, Some(current)) => {
            evidence_refs.extend(current.evidence_refs.clone());
            reasons.push(
                "Benchmark is present in the current evaluation but has no saved baseline."
                    .to_string(),
            );
            "new_current_benchmark"
        }
        (None, None) => "unchanged",
    };
    evidence_refs.sort();
    evidence_refs.dedup();

    RoutingRegressionItem {
        benchmark_id,
        title,
        status,
        regression,
        reasons,
        evidence_refs,
        score_delta: match (baseline, current) {
            (Some(baseline), Some(current)) => {
                Some(i16::from(current.score) - i16::from(baseline.score))
            }
            _ => None,
        },
        confidence_delta: match (baseline, current) {
            (Some(baseline), Some(current)) => Some(
                i16::from(current.route_confidence_score)
                    - i16::from(baseline.route_confidence_score),
            ),
            _ => None,
        },
        baseline: baseline.map(routing_regression_baseline_fields),
        current: current.map(routing_regression_current_fields),
        safety_flags: task_benchmark_safety_flags(),
    }
}

pub(crate) fn routing_regression_baseline_fields(
    item: &RoutingRegressionBaselineItem,
) -> RoutingRegressionComparisonFields {
    RoutingRegressionComparisonFields {
        task: item.task.clone(),
        expected_match_status: item.expected_match_status.clone(),
        score: item.score,
        band: item.band.clone(),
        top_route: item.top_route.clone(),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.clone(),
        gap_count: item.gap_count,
        blocker_count: item.blocker_count,
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

pub(crate) fn routing_regression_current_fields(
    item: &TaskBenchmarkEvaluationItem,
) -> RoutingRegressionComparisonFields {
    RoutingRegressionComparisonFields {
        task: item.task.clone(),
        expected_match_status: item.expected_match_status.to_string(),
        score: item.score,
        band: item.band.to_string(),
        top_route: item
            .top_route
            .as_ref()
            .map(routing_regression_route_snapshot),
        route_confidence_score: item.route_confidence_score,
        route_confidence_band: item.route_confidence_band.to_string(),
        gap_count: item.gap_notes.len(),
        blocker_count: item.blocker_notes.len(),
        gap_notes: item.gap_notes.clone(),
        blocker_notes: item.blocker_notes.clone(),
        evidence_refs: item.evidence_refs.clone(),
    }
}

pub(crate) fn routing_match_rank(status: &str) -> u8 {
    match status {
        "expected_match" => 4,
        "acceptable_match" => 3,
        "no_expectation" => 2,
        "mismatch" => 1,
        "blocked_no_route" => 0,
        _ => 0,
    }
}

pub(crate) fn routing_route_change_reason(
    baseline: Option<&RoutingRegressionRouteSnapshot>,
    current: Option<&RoutingRegressionRouteSnapshot>,
) -> String {
    match (baseline, current) {
        (Some(baseline), Some(current)) => format!(
            "Top route changed from `{}` ({}, {}) to `{}` ({}, {}).",
            baseline.skill_name,
            baseline.agent,
            baseline.scope,
            current.skill_name,
            current.agent,
            current.scope
        ),
        (Some(baseline), None) => format!(
            "Top route `{}` ({}, {}) is no longer available.",
            baseline.skill_name, baseline.agent, baseline.scope
        ),
        (None, Some(current)) => format!(
            "Top route `{}` ({}, {}) is newly available.",
            current.skill_name, current.agent, current.scope
        ),
        (None, None) => "Top route availability changed.".to_string(),
    }
}

pub(crate) fn routing_regression_status(
    regression_count: usize,
    missing_benchmark_count: usize,
    catalog_available: bool,
) -> &'static str {
    if !catalog_available {
        return "catalog_missing";
    }
    if regression_count > 0 {
        return "regressions_detected";
    }
    if missing_benchmark_count > 0 {
        return "missing_benchmarks";
    }
    "no_regressions"
}

pub(crate) fn routing_regression_summary(
    regression_count: usize,
    missing_benchmark_count: usize,
    compared_count: usize,
    catalog_available: bool,
) -> String {
    if !catalog_available {
        return format!(
            "Compared {} benchmark(s), but no local catalog is available; {} regression item(s) require attention.",
            compared_count, regression_count
        );
    }
    if regression_count == 0 {
        return format!(
            "Compared {} benchmark(s) against the saved app-local baseline; no routing regressions were detected.",
            compared_count
        );
    }
    format!(
        "Compared {} benchmark(s) against the saved app-local baseline; detected {} routing regression(s) and {} missing benchmark(s).",
        compared_count, regression_count, missing_benchmark_count
    )
}

pub(crate) fn skill_route_ranking_from_readiness(
    readiness: TaskReadinessResult,
) -> SkillRouteRankingResult {
    let aggregation = aggregation_with_completed_stage(readiness.aggregation.clone(), "routing");
    let top_score = readiness
        .candidate_skills
        .first()
        .map(|candidate| candidate.score)
        .unwrap_or(0);
    let mut route_candidates = Vec::new();
    for (index, candidate) in readiness.candidate_skills.iter().enumerate() {
        let next_score = readiness
            .candidate_skills
            .get(index + 1)
            .map(|candidate| candidate.score);
        let confidence_score = route_confidence_score(candidate, index, top_score, next_score);
        let confidence_band = routing_confidence_band(confidence_score);
        let confidence_rationale =
            route_confidence_rationale(candidate, index, confidence_score, next_score);
        let ambiguity_warnings =
            route_candidate_ambiguity_warnings(candidate, index, top_score, next_score);
        let likely_wrong_pick_risks =
            route_candidate_wrong_pick_risks(candidate, index, next_score, &ambiguity_warnings);
        let likely_miss_risks = route_candidate_miss_risks(candidate);
        route_candidates.push(SkillRouteCandidate {
            rank: index + 1,
            instance_id: candidate.instance_id.clone(),
            definition_id: candidate.definition_id.clone(),
            skill_name: candidate.skill_name.clone(),
            agent: candidate.agent.clone(),
            scope: candidate.scope.clone(),
            enabled: candidate.enabled,
            state: candidate.state.clone(),
            confidence_score,
            confidence_band,
            readiness_score: candidate.score,
            readiness_band: candidate.band,
            quality_score: candidate.quality_score,
            match_reasons: candidate.match_reasons.clone(),
            confidence_rationale,
            ambiguity_warnings,
            likely_wrong_pick_risks,
            likely_miss_risks,
            enabled_scope_risk_state: candidate.enabled_scope_risk_state.clone(),
            evidence_refs: candidate.evidence_refs.clone(),
        });
    }

    let ambiguity_warnings = routing_ambiguity_warnings(&route_candidates);
    let likely_wrong_pick_risks = routing_wrong_pick_risks(&route_candidates);
    let likely_miss_risks = routing_miss_risks(&route_candidates, &readiness);
    let overall_confidence_score = routing_overall_confidence_score(&route_candidates);
    let overall_confidence_band = routing_confidence_band(overall_confidence_score);
    let prompt_instance_ids = route_candidates
        .iter()
        .take(8)
        .map(|candidate| candidate.instance_id.clone())
        .collect::<Vec<_>>();
    let prompt_available = readiness.catalog_available && !route_candidates.is_empty();

    SkillRouteRankingResult {
        task: readiness.task.clone(),
        overall_confidence_score,
        overall_confidence_band,
        summary: routing_confidence_summary(
            overall_confidence_score,
            overall_confidence_band,
            &route_candidates,
            &ambiguity_warnings,
            &likely_miss_risks,
        ),
        generated_by: "deterministic-service",
        catalog_available: readiness.catalog_available,
        filters: readiness.filters,
        route_candidates,
        ambiguity_warnings,
        likely_wrong_pick_risks,
        likely_miss_risks,
        evidence_references: readiness.evidence_references,
        prompt_request: RoutingConfidencePromptRequest {
            available: prompt_available,
            preview_method: "llm.previewPrompt",
            confirm_method: "llm.confirmPromptAndSend",
            action: "routing_confidence",
            request: LlmPreviewPromptParams {
                action: LlmPromptActionKind::RoutingConfidence,
                profile_id: None,
                app_language: None,
                skill_instance_id: None,
                instance_ids: prompt_instance_ids,
                analysis_kind: None,
                user_intent: Some(readiness.task),
            },
            note: if prompt_available {
                "Optional provider-backed explanation must be requested through prompt preview and explicit confirmation; task.rankSkillRoutes never sends provider traffic."
                    .to_string()
            } else {
                "Prompt preview is unavailable until local catalog evidence produces route candidates."
                    .to_string()
            },
        },
        aggregation,
        safety_flags: routing_confidence_safety_flags(),
    }
}

pub(crate) fn route_confidence_score(
    candidate: &TaskReadinessCandidate,
    index: usize,
    top_score: u8,
    next_score: Option<u8>,
) -> u8 {
    let quality_component = candidate.quality_score.unwrap_or(50) as i16 / 10;
    let mut score = candidate.score as i16 + quality_component - 5;
    if index == 0 {
        let margin = candidate.score.saturating_sub(next_score.unwrap_or(0));
        score += match margin {
            20..=u8::MAX => 8,
            10..=19 => 4,
            6..=9 => 0,
            1..=5 => -8,
            0 => -12,
        };
    } else {
        let gap = top_score.saturating_sub(candidate.score);
        score -= (index as i16 * 5).min(20);
        if gap <= 5 {
            score += 4;
        }
    }
    score -= match candidate.enabled_scope_risk_state.risk_level {
        "blocked" => 18,
        "high" => 12,
        "medium" => 6,
        _ => 0,
    };
    if !candidate.enabled {
        score -= 12;
    }
    if candidate.state != "loaded" {
        score -= 12;
    }
    score.clamp(0, 100) as u8
}

pub(crate) fn routing_confidence_band(score: u8) -> &'static str {
    match score {
        80..=100 => "high",
        60..=79 => "medium",
        35..=59 => "low",
        1..=34 => "weak",
        _ => "blocked",
    }
}

pub(crate) fn route_confidence_rationale(
    candidate: &TaskReadinessCandidate,
    index: usize,
    confidence_score: u8,
    next_score: Option<u8>,
) -> Vec<String> {
    let mut rationale = vec![format!(
        "Rank {} combines readiness score {} ({}) with local quality score {} and risk level {}.",
        index + 1,
        candidate.score,
        candidate.band,
        candidate
            .quality_score
            .map(|score| score.to_string())
            .unwrap_or_else(|| "n/a".to_string()),
        candidate.enabled_scope_risk_state.risk_level
    )];
    if index == 0 {
        match next_score {
            Some(next) => rationale.push(format!(
                "Top route leads the next visible candidate by {} readiness point(s).",
                candidate.score.saturating_sub(next)
            )),
            None => rationale.push("Only one visible route candidate was ranked.".to_string()),
        }
    }
    if confidence_score < candidate.score {
        rationale.push(
            "Confidence is below readiness because ambiguity, risk, or enablement state reduces selection certainty."
                .to_string(),
        );
    }
    rationale
}

pub(crate) fn route_candidate_ambiguity_warnings(
    candidate: &TaskReadinessCandidate,
    index: usize,
    top_score: u8,
    next_score: Option<u8>,
) -> Vec<String> {
    let mut warnings = Vec::new();
    if index == 0 {
        if let Some(next) = next_score {
            let margin = candidate.score.saturating_sub(next);
            if margin <= 8 {
                warnings.push(format!(
                    "Top route is separated from the next candidate by only {margin} readiness point(s)."
                ));
            }
        }
    } else if top_score.saturating_sub(candidate.score) <= 8 {
        warnings.push(
            "This candidate is close enough to the top route to create deterministic routing ambiguity."
                .to_string(),
        );
    }
    if candidate
        .blocker_risk_notes
        .iter()
        .any(|note| note.contains("conflict") || note.contains("duplicate_name"))
    {
        warnings.push(
            "Conflict or duplicate-name evidence may make runtime route selection ambiguous."
                .to_string(),
        );
    }
    warnings
}

pub(crate) fn route_candidate_wrong_pick_risks(
    candidate: &TaskReadinessCandidate,
    index: usize,
    next_score: Option<u8>,
    ambiguity_warnings: &[String],
) -> Vec<String> {
    let mut risks = Vec::new();
    if index == 0 && !ambiguity_warnings.is_empty() {
        risks.push("The top local route has close or overlapping alternatives.".to_string());
    }
    if index == 0 && next_score.is_some_and(|score| candidate.score.saturating_sub(score) <= 5) {
        risks.push(
            "A small score margin means wording changes could pick a different skill.".to_string(),
        );
    }
    if candidate.enabled_scope_risk_state.risk_level == "high" {
        risks.push(
            "High local risk evidence could make this route a poor default pick.".to_string(),
        );
    }
    if candidate
        .match_reasons
        .iter()
        .any(|reason| reason.contains("No direct lexical overlap"))
    {
        risks.push("Task fit is weak, so selecting this skill may be a wrong pick.".to_string());
    }
    risks
}

pub(crate) fn route_candidate_miss_risks(candidate: &TaskReadinessCandidate) -> Vec<String> {
    let mut risks = candidate.missing_gap_notes.clone();
    if !candidate.enabled {
        risks.push("Disabled state means this skill may be missed by runtime routing.".to_string());
    }
    if candidate.state != "loaded" {
        risks.push(format!(
            "State `{}` means this skill may be unavailable when routing.",
            redact_for_llm_preview(&candidate.state)
        ));
    }
    risks
}

pub(crate) fn routing_overall_confidence_score(candidates: &[SkillRouteCandidate]) -> u8 {
    let Some(best) = candidates.first() else {
        return 0;
    };
    let second = candidates
        .get(1)
        .map(|candidate| candidate.confidence_score)
        .unwrap_or(0);
    let margin_bonus = best.confidence_score.saturating_sub(second).min(15) / 3;
    ((u16::from(best.confidence_score) * 4 + u16::from(second)) / 5)
        .saturating_add(u16::from(margin_bonus))
        .min(100) as u8
}

pub(crate) fn routing_ambiguity_warnings(candidates: &[SkillRouteCandidate]) -> Vec<String> {
    let mut warnings = candidates
        .iter()
        .flat_map(|candidate| candidate.ambiguity_warnings.iter().cloned())
        .collect::<Vec<_>>();
    if let (Some(first), Some(second)) = (candidates.first(), candidates.get(1)) {
        let margin = first
            .confidence_score
            .saturating_sub(second.confidence_score);
        if margin <= 8 {
            warnings.push(format!(
                "Top two route candidates are within {margin} confidence point(s)."
            ));
        }
    }
    warnings.sort();
    warnings.dedup();
    warnings.truncate(10);
    warnings
}

pub(crate) fn routing_wrong_pick_risks(candidates: &[SkillRouteCandidate]) -> Vec<String> {
    let mut risks = candidates
        .iter()
        .flat_map(|candidate| candidate.likely_wrong_pick_risks.iter().cloned())
        .collect::<Vec<_>>();
    if risks.is_empty() && !candidates.is_empty() {
        risks.push(
            "No likely wrong-pick risk was detected beyond normal lexical matching uncertainty."
                .to_string(),
        );
    }
    risks.sort();
    risks.dedup();
    risks.truncate(10);
    risks
}

pub(crate) fn routing_miss_risks(
    candidates: &[SkillRouteCandidate],
    readiness: &TaskReadinessResult,
) -> Vec<String> {
    let mut risks = candidates
        .iter()
        .flat_map(|candidate| candidate.likely_miss_risks.iter().cloned())
        .collect::<Vec<_>>();
    risks.extend(readiness.missing_gap_notes.iter().cloned());
    if candidates.is_empty() {
        risks.push("No route candidates were available from local catalog evidence.".to_string());
    } else if candidates
        .iter()
        .all(|candidate| candidate.confidence_score < 60)
    {
        risks.push(
            "All visible route candidates have low confidence, so the task may miss the intended skill."
                .to_string(),
        );
    }
    risks.sort();
    risks.dedup();
    risks.truncate(10);
    risks
}

pub(crate) fn routing_confidence_summary(
    score: u8,
    band: &'static str,
    candidates: &[SkillRouteCandidate],
    ambiguity_warnings: &[String],
    miss_risks: &[String],
) -> String {
    match candidates.first() {
        Some(best) => format!(
            "Routing confidence is {band} ({score}/100). Top route is #{} `{}` for {} with confidence {} and {} ambiguity warning(s).",
            best.rank,
            best.skill_name,
            best.agent,
            best.confidence_score,
            ambiguity_warnings.len()
        ),
        None if miss_risks.is_empty() => {
            "Routing confidence is blocked because no local route candidates were available."
                .to_string()
        }
        None => format!(
            "Routing confidence is blocked because no local route candidates were available. {}",
            miss_risks.join(" ")
        ),
    }
}

pub(crate) fn push_task_readiness_evidence(
    evidence: &mut Vec<TaskReadinessEvidenceReference>,
    source_type: &'static str,
    source_id: &str,
    label: String,
    severity: Option<String>,
    related_instance_id: Option<String>,
) -> String {
    let id = format!("{source_type}:{source_id}");
    evidence.push(TaskReadinessEvidenceReference {
        id: id.clone(),
        source_type,
        source_id: redact_for_llm_preview(source_id),
        label,
        severity,
        related_instance_id,
    });
    id
}

pub(crate) fn quality_metadata_component(
    skill: &SkillDetailRecord,
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let mut score = 25i16;
    let mut missing = Vec::new();
    let mut suggestions = Vec::new();
    if skill.name.trim().is_empty() {
        score -= 8;
        missing.push("name");
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Add a clear skill name".to_string(),
            detail:
                "Provide a stable, canonical name so agents and reviewers can identify the skill."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.description.trim().is_empty() {
        score -= 8;
        missing.push("description");
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Add a concise description".to_string(),
            detail:
                "Describe the task fit, expected inputs, and safe usage boundaries in metadata."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.frontmatter_raw.trim().is_empty() {
        score -= 5;
        missing.push("frontmatter");
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Restore frontmatter metadata".to_string(),
            detail: "Use structured frontmatter so deterministic rules can evaluate the skill."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.body.trim().chars().count() < 40 {
        score -= 4;
        missing.push("body detail");
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Expand the skill guidance".to_string(),
            detail: "Add enough task-specific instructions for an agent to understand when and how to use the skill."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if missing.is_empty() {
        "Metadata has the expected local name, description, frontmatter, and body guidance."
            .to_string()
    } else {
        format!("Metadata needs attention for: {}.", missing.join(", "))
    };
    (score.clamp(0, 25) as u8, summary, suggestions)
}

pub(crate) fn quality_permission_component(
    skill: &SkillDetailRecord,
) -> (u8, String, Vec<String>, Vec<SkillQualitySuggestion>) {
    let mut score = 20i16;
    let mut risks = Vec::new();
    let mut suggestions = Vec::new();
    let permissions = &skill.permissions;
    let normalized = permissions.get("normalized").unwrap_or(permissions);
    if permissions
        .as_object()
        .is_none_or(|object| object.is_empty())
    {
        score -= 8;
        risks.push("Permission metadata is empty or unavailable.".to_string());
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Declare permission intent".to_string(),
            detail: "Add explicit tools/files/network/exec expectations so risk checks do not rely on unknown-safe defaults."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let tools = normalized
        .get("tools")
        .and_then(Value::as_array)
        .map(Vec::len)
        .unwrap_or(0);
    if tools == 0 {
        score -= 4;
        risks.push("No explicit tool allow-list was found in normalized permissions.".to_string());
    }
    if normalized
        .get("network")
        .and_then(Value::as_str)
        .is_none_or(|network| network == "unknown")
    {
        score -= 3;
        risks.push("Network access intent is unknown.".to_string());
    }
    let exec = normalized
        .get("exec")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let requires_human = normalized
        .get("requires_human")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if exec && !requires_human {
        score -= 8;
        risks.push(
            "Execution permission is declared without a human-review requirement.".to_string(),
        );
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Require human review for execution".to_string(),
            detail: "Execution-like skills should declare an explicit human confirmation boundary."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if risks.is_empty() {
        "Permission metadata is explicit enough for local risk checks.".to_string()
    } else {
        format!("Permission clarity deductions: {}", risks.join(" "))
    };
    (score.clamp(0, 20) as u8, summary, risks, suggestions)
}

pub(crate) fn quality_risk_component(
    skill: &SkillDetailRecord,
    findings: &[RuleFindingRecord],
) -> (u8, String, Vec<String>, Vec<SkillQualitySuggestion>) {
    let mut deduction = 0i16;
    let mut risks = Vec::new();
    for finding in findings {
        let points = match finding.effective_severity.as_str() {
            "critical" => 15,
            "error" => 10,
            "warning" | "warn" => 6,
            "info" => 2,
            _ => 1,
        };
        deduction += points;
        risks.push(format!(
            "{} finding `{}` affects this score.",
            redact_for_llm_preview(&finding.effective_severity),
            redact_for_llm_preview(&finding.rule_id)
        ));
    }
    let combined = format!("{}\n{}", skill.frontmatter_raw, skill.body).to_lowercase();
    let mut suggestions = Vec::new();
    if combined.contains("#!") || combined.contains("exec") || combined.contains("command") {
        deduction += 5;
        risks.push(
            "Skill text contains execution-related terms; this service still exposes no execution path."
                .to_string(),
        );
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Clarify execution boundaries".to_string(),
            detail:
                "Document whether command-like instructions are examples, manual steps, or blocked automation."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if combined.contains("http") || combined.contains("api") || combined.contains("network") {
        deduction += 4;
        risks.push("Skill text contains network/API-related terms.".to_string());
    }
    if combined.contains("key") || combined.contains("token") || combined.contains("secret") {
        deduction += 4;
        risks.push(
            "Skill text contains secret-like terms; responses redact such tokens.".to_string(),
        );
    }
    let score = (25i16 - deduction.min(25)).clamp(0, 25) as u8;
    let summary = if findings.is_empty() && risks.is_empty() {
        "No related findings or high-risk body signals were detected locally.".to_string()
    } else {
        format!(
            "{} related finding(s) and local text signals reduced the risk component.",
            findings.len()
        )
    };
    (score, summary, risks, suggestions)
}

pub(crate) fn quality_conflict_component(
    conflicts: &[ConflictGroupRecord],
    analysis_groups: &[CrossAgentAnalysisGroup],
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let conflict_deduction = (conflicts.len() as i16 * 12).min(15);
    let analysis_deduction = (analysis_groups.len() as i16 * 5).min(10);
    let score = (15i16 - (conflict_deduction + analysis_deduction).min(15)).clamp(0, 15) as u8;
    let mut suggestions = Vec::new();
    if !conflicts.is_empty() {
        suggestions.push(SkillQualitySuggestion {
            priority: "high",
            title: "Review same-agent conflicts".to_string(),
            detail: "Resolve current-agent name/runtime collisions through the existing conflict review flow."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if !analysis_groups.is_empty() {
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Compare cross-agent overlap".to_string(),
            detail: "Use read-only comparison to decide whether similar skills improve coverage or create routing ambiguity."
                .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    let summary = if conflicts.is_empty() && analysis_groups.is_empty() {
        "No same-agent conflict or cross-agent overlap currently involves this skill.".to_string()
    } else {
        format!(
            "{} same-agent conflict(s) and {} cross-agent analysis group(s) involve this skill.",
            conflicts.len(),
            analysis_groups.len()
        )
    };
    (score, summary, suggestions)
}

pub(crate) fn quality_adapter_component(
    skill: &SkillDetailRecord,
    diagnostic: Option<&AdapterDiagnosticsRecord>,
) -> (u8, String, Vec<SkillQualitySuggestion>) {
    let mut score = 15i16;
    let mut notes = Vec::new();
    let mut suggestions = Vec::new();
    if !skill.enabled {
        score -= 8;
        notes.push("Skill is disabled in the catalog state.".to_string());
        suggestions.push(SkillQualitySuggestion {
            priority: "medium",
            title: "Review enablement state".to_string(),
            detail:
                "If this skill is expected to route tasks, review enablement through the existing safe toggle flow."
                    .to_string(),
            evidence_refs: Vec::new(),
        });
    }
    if skill.state != "loaded" {
        score -= 10;
        notes.push(format!(
            "Skill state is `{}` instead of loaded.",
            redact_for_llm_preview(&skill.state)
        ));
    }
    match diagnostic {
        Some(diagnostic) => {
            if diagnostic.status != "available" {
                score -= 3;
                notes.push(format!(
                    "Adapter diagnostic status is `{}`.",
                    diagnostic.status
                ));
            }
            if diagnostic.roots.iter().all(|root| !root.exists) {
                score -= 3;
                notes.push(
                    "Adapter diagnostics found no existing scanned root for this agent."
                        .to_string(),
                );
            }
        }
        None => {
            score -= 3;
            notes.push("No adapter diagnostics entry matched this skill agent.".to_string());
        }
    }
    let summary = if notes.is_empty() {
        "Adapter diagnostics and catalog state support read-only analysis for this skill."
            .to_string()
    } else {
        notes.join(" ")
    };
    (score.clamp(0, 15) as u8, summary, suggestions)
}

pub(crate) fn quality_grade_and_band(score: u8) -> (&'static str, &'static str) {
    match score {
        90..=100 => ("A", "excellent"),
        75..=89 => ("B", "good"),
        60..=74 => ("C", "fair"),
        40..=59 => ("D", "poor"),
        _ => ("F", "blocked"),
    }
}

pub(crate) fn quality_priority_for_severity(severity: &str) -> &'static str {
    match severity {
        "critical" | "error" => "high",
        "warning" | "warn" => "medium",
        _ => "low",
    }
}

pub(crate) fn push_quality_evidence(
    evidence: &mut Vec<SkillQualityEvidenceReference>,
    source_type: &'static str,
    source_id: &str,
    label: String,
    severity: Option<String>,
    related_instance_id: Option<String>,
) -> String {
    let id = format!("{source_type}:{source_id}");
    evidence.push(SkillQualityEvidenceReference {
        id: id.clone(),
        source_type,
        source_id: redact_for_llm_preview(source_id),
        label,
        severity,
        related_instance_id,
    });
    id
}

pub(crate) fn quality_refs_or_skill(refs: &[String], skill_ref: &str) -> Vec<String> {
    if refs.is_empty() {
        vec![skill_ref.to_string()]
    } else {
        refs.to_vec()
    }
}

pub(crate) fn dedupe_quality_suggestions(suggestions: &mut Vec<SkillQualitySuggestion>) {
    let mut seen = BTreeMap::new();
    suggestions.retain(|suggestion| {
        let key = format!("{}\x1f{}", suggestion.title, suggestion.detail);
        if let std::collections::btree_map::Entry::Vacant(entry) = seen.entry(key) {
            entry.insert(());
            true
        } else {
            false
        }
    });
}

pub(crate) fn render_quality_score_prompt_section(
    score: &SkillQualityScoreResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let components = score
        .components
        .iter()
        .map(|component| {
            format!(
                "- {}: {}/{}; {}",
                component.id,
                component.score,
                component.max_score,
                redactor.redact(&component.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = score
        .evidence_references
        .iter()
        .take(12)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let suggestions = score
        .suggested_improvements
        .iter()
        .take(8)
        .map(|suggestion| {
            format!(
                "- {}: {} - {}",
                suggestion.priority,
                redactor.redact(&suggestion.title),
                redactor.redact(&suggestion.detail)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Quality score evidence:\n- skill id: {}\n- name: {}\n- agent: {}\n- scope: {}\n- score: {} / 100\n- grade: {}\n- band: {}\n\nComponents:\n{}\n\nEvidence references:\n{}\n\nSuggested improvements:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&score.instance_id),
        redactor.redact(&score.skill_name),
        redactor.redact(&score.agent),
        redactor.redact(&score.scope),
        score.score,
        score.grade,
        score.band,
        if components.is_empty() { "none" } else { &components },
        if evidence.is_empty() { "none" } else { &evidence },
        if suggestions.is_empty() { "none" } else { &suggestions },
    )
}

pub(crate) fn render_stale_drift_prompt_section(
    detection: &StaleDriftDetectionResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let rows = detection
        .stale_drift_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): score={} band={} fingerprint_drift={} finding_drift={} source_drift={} age_days={}; reasons={}",
                row.rank,
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                redactor.redact(&row.scope),
                row.enabled,
                redactor.redact(&row.state),
                row.stale_drift_score,
                row.stale_drift_band,
                row.drift_signals.fingerprint_drift,
                row.drift_signals.finding_drift,
                row.drift_signals.source_drift,
                row.drift_signals
                    .modified_age_days
                    .map(|days| days.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                row.reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let impacts = detection
        .readiness_impact_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} impact={} score={}: {}",
                redactor.redact(&row.skill_name),
                row.impact_level,
                row.stale_drift_score,
                row.notes
                    .iter()
                    .take(2)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = detection
        .evidence_references
        .iter()
        .take(12)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Stale/drift detection evidence:\n- catalog_available: {}\n- scanned_skill_count: {}\n- returned_row_count: {}\n- stale_count: {}\n- drift_count: {}\n- high_risk_count: {}\n- stale_days_threshold: {}\n- summary: {}\n\nRows:\n{}\n\nReadiness impact:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        detection.catalog_available,
        detection.summary.scanned_skill_count,
        detection.summary.returned_row_count,
        detection.summary.stale_count,
        detection.summary.drift_count,
        detection.summary.high_risk_count,
        detection.filters.stale_days,
        redactor.redact(&detection.summary.summary),
        if rows.is_empty() { "none" } else { &rows },
        if impacts.is_empty() { "none" } else { &impacts },
        if detection.gap_notes.is_empty() {
            "none".to_string()
        } else {
            detection
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if detection.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            detection
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_knowledge_search_prompt_section(
    result: &KnowledgeSearchResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let rows = result
        .rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): matched_fields={}; quality={}; readiness={}; stale_drift={}; reasons={}",
                row.rank,
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                redactor.redact(&row.scope),
                row.enabled,
                redactor.redact(&row.state),
                row.matched_fields.join(", "),
                row.quality_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100)", context.band, context.score))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.readiness_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100, risk={})", context.band, context.score, context.risk_level))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.stale_drift_context
                    .as_ref()
                    .map(|context| format!("{} ({}/100)", context.band, context.score))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.match_reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Knowledge search evidence:\n- catalog_available: {}\n- query: {}\n- normalized_terms: {}\n- indexed_skill_count: {}\n- matched_row_count: {}\n- returned_row_count: {}\n- enabled_count: {}\n- high_risk_count: {}\n- stale_or_drift_count: {}\n- summary: {}\n\nRows:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .query
            .as_deref()
            .map(|query| redactor.redact(query))
            .unwrap_or_else(|| "none".to_string()),
        if result.filters.normalized_terms.is_empty() {
            "none".to_string()
        } else {
            result.filters.normalized_terms.join(", ")
        },
        result.summary.indexed_skill_count,
        result.summary.matched_row_count,
        result.summary.returned_row_count,
        result.summary.enabled_count,
        result.summary.high_risk_count,
        result.summary.stale_or_drift_count,
        redactor.redact(&result.summary.summary),
        if rows.is_empty() { "none" } else { &rows },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_similar_skill_grouping_prompt_section(
    result: &SimilarSkillGroupingResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let groups = result
        .groups
        .iter()
        .take(8)
        .map(|group| {
            let members = group
                .members
                .iter()
                .take(6)
                .map(|member| {
                    format!(
                        "{} ({}, {}, enabled={}, state={}, quality={}, stale_drift={})",
                        redactor.redact(&member.skill_name),
                        redactor.redact(&member.agent),
                        redactor.redact(&member.scope),
                        member.enabled,
                        redactor.redact(&member.state),
                        member
                            .quality_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                        member
                            .stale_drift_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                    )
                })
                .collect::<Vec<_>>()
                .join("; ");
            format!(
                "- #{} {} type={} score={} ambiguity_risk={} coverage_redundancy={} routing_ambiguity={}; shared_terms={}; shared_tools={}; shared_rules={}; shared_risk={}; why={}; members={}",
                group.rank,
                redactor.redact(&group.title),
                group.group_type,
                group.similarity_score,
                group.ambiguity_risk,
                group.coverage_redundancy,
                group.routing_ambiguity,
                group.shared_terms.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_tools.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_rules.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group.shared_risk_tags.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                group
                    .why_grouped
                    .iter()
                    .take(4)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" "),
                members
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Similar skill grouping evidence:\n- catalog_available: {}\n- agent: {}\n- min_score: {}\n- indexed_skill_count: {}\n- candidate_skill_count: {}\n- matched_group_count: {}\n- returned_group_count: {}\n- duplicate_group_count: {}\n- coverage_redundancy_group_count: {}\n- routing_ambiguity_count: {}\n- summary: {}\n\nGroups:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "all".to_string()),
        result.filters.min_score,
        result.summary.indexed_skill_count,
        result.summary.candidate_skill_count,
        result.summary.matched_group_count,
        result.summary.returned_group_count,
        result.summary.duplicate_group_count,
        result.summary.coverage_redundancy_group_count,
        result.summary.routing_ambiguity_count,
        redactor.redact(&result.summary.summary),
        if groups.is_empty() { "none" } else { &groups },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_capability_taxonomy_prompt_section(
    result: &CapabilityTaxonomyResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let domains = result
        .domains
        .iter()
        .take(8)
        .map(|domain| {
            let representatives = domain
                .representative_skills
                .iter()
                .take(6)
                .map(|skill| {
                    format!(
                        "{} ({}, {}, enabled={}, state={}, quality={}, stale_drift={}, groups={})",
                        redactor.redact(&skill.skill_name),
                        redactor.redact(&skill.agent),
                        redactor.redact(&skill.scope),
                        skill.enabled,
                        redactor.redact(&skill.state),
                        skill
                            .quality_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                        skill
                            .stale_drift_context
                            .as_ref()
                            .map(|context| format!("{} ({}/100)", context.band, context.score))
                            .unwrap_or_else(|| "n/a".to_string()),
                        if skill.similarity_group_ids.is_empty() {
                            "none".to_string()
                        } else {
                            skill.similarity_group_ids.join(", ")
                        }
                    )
                })
                .collect::<Vec<_>>()
                .join("; ");
            format!(
                "- #{} {} key={} coverage={} score={} skills={} agents={} workspaces={} duplicate_or_redundant={} routing_ambiguity={}; tools={}; rules={}; risk={}; gaps={}; blockers={}; representatives={}",
                domain.rank,
                redactor.redact(&domain.domain_name),
                redactor.redact(&domain.domain_key),
                domain.coverage_level,
                domain.coverage_score,
                domain.skill_count,
                domain.agent_count,
                domain.workspace_count,
                domain.duplicate_or_redundant_count,
                domain.routing_ambiguity_count,
                domain.tools.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                domain.rules.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                domain.risk_tags.iter().take(8).cloned().collect::<Vec<_>>().join(", "),
                domain
                    .gap_notes
                    .iter()
                    .take(4)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" "),
                domain
                    .blocker_notes
                    .iter()
                    .take(4)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" "),
                representatives
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Capability taxonomy evidence:\n- catalog_available: {}\n- agent: {}\n- indexed_skill_count: {}\n- candidate_skill_count: {}\n- domain_count: {}\n- returned_domain_count: {}\n- agent_count: {}\n- workspace_count: {}\n- duplicate_or_redundant_domain_count: {}\n- routing_ambiguity_domain_count: {}\n- summary: {}\n\nDomains:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "all".to_string()),
        result.summary.indexed_skill_count,
        result.summary.candidate_skill_count,
        result.summary.domain_count,
        result.summary.returned_domain_count,
        result.summary.agent_count,
        result.summary.workspace_count,
        result.summary.duplicate_or_redundant_domain_count,
        result.summary.routing_ambiguity_domain_count,
        redactor.redact(&result.summary.summary),
        if domains.is_empty() { "none" } else { &domains },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_local_skill_map_prompt_section(
    result: &LocalSkillMapResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let nodes = result
        .nodes
        .iter()
        .take(12)
        .map(|node| {
            format!(
                "- #{} {} {} weight={} risk={} agent={} summary={}",
                node.rank,
                node.node_type,
                redactor.redact(&node.label),
                node.weight,
                node.risk_level.as_deref().unwrap_or("n/a"),
                node.agent
                    .as_deref()
                    .map(|agent| redactor.redact(agent))
                    .unwrap_or_else(|| "n/a".to_string()),
                redactor.redact(&node.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let edges = result
        .edges
        .iter()
        .take(16)
        .map(|edge| {
            format!(
                "- {} {} -> {} weight={} label={} reasons={}",
                edge.edge_type,
                redactor.redact(&edge.source),
                redactor.redact(&edge.target),
                edge.weight,
                redactor.redact(&edge.label),
                edge.reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let clusters = result
        .clusters
        .iter()
        .take(8)
        .map(|cluster| {
            format!(
                "- {} {} score={} risk={} nodes={} edges={} summary={}",
                cluster.cluster_type,
                redactor.redact(&cluster.label),
                cluster.score,
                redactor.redact(&cluster.risk_level),
                cluster.node_ids.len(),
                cluster.edge_ids.len(),
                redactor.redact(&cluster.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let domains = result
        .domains
        .iter()
        .take(8)
        .map(|domain| {
            format!(
                "- {} key={} coverage={} score={} skills={} enabled={} agents={} gaps={} blockers={}",
                redactor.redact(&domain.domain_name),
                redactor.redact(&domain.domain_key),
                domain.coverage_level,
                domain.coverage_score,
                domain.skill_count,
                domain.enabled_skill_count,
                domain.agent_count,
                domain
                    .gap_notes
                    .iter()
                    .take(3)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" "),
                domain
                    .blocker_notes
                    .iter()
                    .take(3)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Local Skill Map evidence:\n- catalog_available: {}\n- agent: {}\n- task: {}\n- indexed_skill_count: {}\n- candidate_skill_count: {}\n- returned_node_count: {}\n- returned_edge_count: {}\n- returned_cluster_count: {}\n- domain_count: {}\n- skill_node_count: {}\n- conflict_node_count: {}\n- risk_node_count: {}\n- task_coverage_edge_count: {}\n- cross_agent_edge_count: {}\n- summary: {}\n\nNodes:\n{}\n\nEdges:\n{}\n\nClusters:\n{}\n\nDomains:\n{}\n\nRisk notes:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result
            .filters
            .agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "all".to_string()),
        result
            .filters
            .task
            .as_deref()
            .map(|task| redactor.redact(task))
            .unwrap_or_else(|| "none".to_string()),
        result.summary.indexed_skill_count,
        result.summary.candidate_skill_count,
        result.summary.returned_node_count,
        result.summary.returned_edge_count,
        result.summary.returned_cluster_count,
        result.summary.domain_count,
        result.summary.skill_node_count,
        result.summary.conflict_node_count,
        result.summary.risk_node_count,
        result.summary.task_coverage_edge_count,
        result.summary.cross_agent_edge_count,
        redactor.redact(&result.summary.summary),
        if nodes.is_empty() { "none" } else { &nodes },
        if edges.is_empty() { "none" } else { &edges },
        if clusters.is_empty() { "none" } else { &clusters },
        if domains.is_empty() { "none" } else { &domains },
        if result.risk_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .risk_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_task_readiness_prompt_section(
    readiness: &TaskReadinessResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let candidates = readiness
        .candidate_skills
        .iter()
        .take(8)
        .map(|candidate| {
            format!(
                "- {} ({}, {}, enabled={}, state={}): score={} band={} risk={} quality={}; reasons={}",
                redactor.redact(&candidate.skill_name),
                redactor.redact(&candidate.agent),
                redactor.redact(&candidate.scope),
                candidate.enabled,
                redactor.redact(&candidate.state),
                candidate.score,
                candidate.band,
                candidate.enabled_scope_risk_state.risk_level,
                candidate
                    .quality_score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                candidate
                    .match_reasons
                    .iter()
                    .take(3)
                    .map(|reason| redactor.redact(reason))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let gaps = readiness
        .missing_gap_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let blockers = readiness
        .blocker_risk_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = readiness
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Task readiness evidence:\n- task: {}\n- score: {} / 100\n- band: {}\n- summary: {}\n- catalog_available: {}\n\nCandidate skills:\n{}\n\nMissing/gap notes:\n{}\n\nBlocker/risk notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&readiness.task),
        readiness.score,
        readiness.band,
        redactor.redact(&readiness.summary),
        readiness.catalog_available,
        if candidates.is_empty() { "none" } else { &candidates },
        if gaps.is_empty() { "none" } else { &gaps },
        if blockers.is_empty() { "none" } else { &blockers },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_workspace_readiness_prompt_section(
    result: &WorkspaceReadinessResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let checklist = result
        .readiness_rows
        .iter()
        .take(10)
        .map(|row| {
            format!(
                "- {} status={} score={} category={} detail={}",
                redactor.redact(&row.title),
                row.status,
                row.score,
                row.category,
                redactor.redact(&row.detail)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let agents = result
        .agent_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} status={} score={} visible={} enabled={} project={} adapter={} writable={} best={}",
                redactor.redact(&row.display_name),
                row.status,
                row.score,
                row.visible_skill_count,
                row.enabled_skill_count,
                row.project_skill_count,
                row.adapter_status
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.writable_status
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                row.best_candidate
                    .as_ref()
                    .map(|candidate| redactor.redact(&candidate.skill_name))
                    .unwrap_or_else(|| "none".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let capabilities = result
        .capability_rows
        .iter()
        .take(10)
        .map(|row| {
            format!(
                "- {} status={} coverage={} score={} expected={} skills={} enabled={} gaps={}; blockers={}",
                redactor.redact(&row.capability),
                row.status,
                row.coverage_level,
                row.coverage_score,
                row.expected,
                row.skill_count,
                row.enabled_skill_count,
                row.gap_notes
                    .iter()
                    .take(3)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" "),
                row.blocker_notes
                    .iter()
                    .take(3)
                    .map(|note| redactor.redact(note))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Workspace readiness evidence:\n- catalog_available: {}\n- workspace_available: {}\n- project_available: {}\n- visible_skill_count: {}\n- enabled_skill_count: {}\n- agent_count: {}\n- domain_count: {}\n- capability_count: {}\n- ready_count: {}\n- partial_count: {}\n- blocked_count: {}\n- gap_count: {}\n- blocker_count: {}\n- summary: {}\n\nChecklist rows:\n{}\n\nAgent rows:\n{}\n\nCapability rows:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.summary.workspace_available,
        result.summary.project_available,
        result.summary.visible_skill_count,
        result.summary.enabled_skill_count,
        result.summary.agent_count,
        result.summary.domain_count,
        result.summary.capability_count,
        result.summary.ready_count,
        result.summary.partial_count,
        result.summary.blocked_count,
        result.summary.gap_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if checklist.is_empty() { "none" } else { &checklist },
        if agents.is_empty() { "none" } else { &agents },
        if capabilities.is_empty() { "none" } else { &capabilities },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_remediation_plan_prompt_section(
    result: &RemediationPlanResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let items = result
        .plan_items
        .iter()
        .take(10)
        .map(|item| {
            format!(
                "- #{} {} priority={} severity={} category={} affected_agent={} affected_skill={} deferred={} summary={} safe_next_action={} blockers={}",
                item.rank,
                redactor.redact(&item.title),
                item.priority,
                item.severity,
                item.category,
                item.affected_agent
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                item.affected_skill
                    .as_ref()
                    .map(|skill| redactor.redact(&skill.skill_name))
                    .unwrap_or_else(|| "none".to_string()),
                item.deferred,
                redactor.redact(&item.summary),
                redactor.redact(&item.suggested_safe_next_action),
                item.blockers
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let priority_rows = result
        .priority_rows
        .iter()
        .map(|row| {
            format!(
                "- {} severity={} count={} categories={:?} top={}",
                row.priority,
                row.severity,
                row.item_count,
                row.category_counts,
                row.top_item_ids
                    .iter()
                    .map(|id| redactor.redact(id))
                    .collect::<Vec<_>>()
                    .join(", ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Remediation plan evidence:\n- catalog_available: {}\n- total_item_count: {}\n- returned_item_count: {}\n- high_priority_count: {}\n- medium_priority_count: {}\n- low_priority_count: {}\n- deferred_count: {}\n- finding_item_count: {}\n- gap_item_count: {}\n- ambiguity_item_count: {}\n- drift_item_count: {}\n- readiness_item_count: {}\n- policy_item_count: {}\n- blocker_count: {}\n- summary: {}\n\nPlan items:\n{}\n\nPriority rows:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.summary.total_item_count,
        result.summary.returned_item_count,
        result.summary.high_priority_count,
        result.summary.medium_priority_count,
        result.summary.low_priority_count,
        result.summary.deferred_count,
        result.summary.finding_item_count,
        result.summary.gap_item_count,
        result.summary.ambiguity_item_count,
        result.summary.drift_item_count,
        result.summary.readiness_item_count,
        result.summary.policy_item_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if items.is_empty() { "none" } else { &items },
        if priority_rows.is_empty() {
            "none"
        } else {
            &priority_rows
        },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_remediation_preview_drafts_prompt_section(
    result: &RemediationPreviewDraftsResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let drafts = result
        .draft_items
        .iter()
        .take(10)
        .map(|item| {
            format!(
                "- #{} {} type={} confidence={} band={} affected_agent={} affected_skill={} rule={} proposed={} guidance={} blockers={}",
                item.rank,
                redactor.redact(&item.title),
                item.draft_type,
                item.confidence,
                item.confidence_band,
                item.agent
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                item.affected_skill
                    .as_ref()
                    .map(|skill| redactor.redact(&skill.skill_name))
                    .unwrap_or_else(|| "none".to_string()),
                item.rule_id
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                redactor.redact(&item.proposed_text),
                redactor.redact(&item.edit_guidance),
                item.blocker_notes
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Fix preview draft evidence:\n- catalog_available: {}\n- total_draft_count: {}\n- returned_draft_count: {}\n- frontmatter_count: {}\n- description_count: {}\n- permissions_count: {}\n- dependency_count: {}\n- policy_count: {}\n- high_confidence_count: {}\n- medium_confidence_count: {}\n- low_confidence_count: {}\n- blocker_count: {}\n- summary: {}\n\nDraft items:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.summary.total_draft_count,
        result.summary.returned_draft_count,
        result.summary.frontmatter_count,
        result.summary.description_count,
        result.summary.permissions_count,
        result.summary.dependency_count,
        result.summary.policy_count,
        result.summary.high_confidence_count,
        result.summary.medium_confidence_count,
        result.summary.low_confidence_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if drafts.is_empty() { "none" } else { &drafts },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_remediation_preview_impact_prompt_section(
    result: &RemediationPreviewImpactResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let impacts = result
        .impact_rows
        .iter()
        .take(10)
        .map(|row| {
            format!(
                "- #{} area={} direction={} confidence={} band={} title={} summary={} blockers={}",
                row.rank,
                row.area,
                row.expected_direction,
                row.confidence,
                row.confidence_band,
                redactor.redact(&row.title),
                redactor.redact(&row.summary),
                row.blockers
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let snapshots = result
        .snapshot_rollback_plan_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} agent={} snapshot_required={} rollback_available={} verified_writable={} plan_only={} blocked={}",
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                row.snapshot_required,
                row.rollback_available,
                row.verified_writable,
                row.plan_only,
                row.blocked_reason
                    .as_deref()
                    .map(|reason| redactor.redact(reason))
                    .unwrap_or_else(|| "none".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let risks = result
        .risk_delta_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} severity={} current={} expected_after={} direction={} blockers={}",
                redactor.redact(&row.title),
                redactor.redact(&row.severity),
                row.current_risk,
                row.expected_risk_after,
                row.expected_direction,
                row.blockers
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Impact preview evidence:\n- catalog_available: {}\n- action: {}\n- total_impact_count: {}\n- returned_impact_count: {}\n- task_impact_count: {}\n- agent_impact_count: {}\n- skill_impact_count: {}\n- risk_delta_count: {}\n- snapshot_plan_count: {}\n- rollback_plan_count: {}\n- blocker_count: {}\n- summary: {}\n\nImpact rows:\n{}\n\nSnapshot/rollback plans:\n{}\n\nRisk deltas:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.filters.action,
        result.summary.total_impact_count,
        result.summary.returned_impact_count,
        result.summary.task_impact_count,
        result.summary.agent_impact_count,
        result.summary.skill_impact_count,
        result.summary.risk_delta_count,
        result.summary.snapshot_plan_count,
        result.summary.rollback_plan_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if impacts.is_empty() { "none" } else { &impacts },
        if snapshots.is_empty() { "none" } else { &snapshots },
        if risks.is_empty() { "none" } else { &risks },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_remediation_batch_review_prompt_section(
    result: &RemediationBatchReviewResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let groups = result
        .review_groups
        .iter()
        .take(10)
        .map(|group| {
            format!(
                "- {} label={} count={} high={} medium={} low={} next={} blockers={}",
                group.group_type,
                redactor.redact(&group.label),
                group.item_count,
                group.high_risk_count,
                group.medium_risk_count,
                group.low_risk_count,
                redactor.redact(&group.recommended_next_step_label),
                group
                    .blocker_notes
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let items = result
        .review_items
        .iter()
        .take(12)
        .map(|item| {
            format!(
                "- #{} source={} risk={} severity={} status={} rule={} agent={} skill={} title={} next={} blockers={}",
                item.rank,
                item.source,
                item.risk,
                redactor.redact(&item.severity),
                redactor.redact(&item.status),
                item.rule_id
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                item.agent
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "n/a".to_string()),
                item.affected_skill
                    .as_ref()
                    .map(|skill| redactor.redact(&skill.skill_name))
                    .unwrap_or_else(|| "none".to_string()),
                redactor.redact(&item.title),
                redactor.redact(&item.recommended_next_step_label),
                item.blocker_notes
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Batch review evidence:\n- catalog_available: {}\n- total_item_count: {}\n- returned_item_count: {}\n- group_count: {}\n- high_risk_count: {}\n- medium_risk_count: {}\n- low_risk_count: {}\n- task_group_count: {}\n- agent_group_count: {}\n- workspace_group_count: {}\n- rule_group_count: {}\n- blocker_count: {}\n- summary: {}\n\nReview groups:\n{}\n\nReview items:\n{}\n\nRecommended next steps:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.summary.total_item_count,
        result.summary.returned_item_count,
        result.summary.group_count,
        result.summary.high_risk_count,
        result.summary.medium_risk_count,
        result.summary.low_risk_count,
        result.summary.task_group_count,
        result.summary.agent_group_count,
        result.summary.workspace_group_count,
        result.summary.rule_group_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if groups.is_empty() { "none" } else { &groups },
        if items.is_empty() { "none" } else { &items },
        if result.recommended_next_step_labels.is_empty() {
            "none".to_string()
        } else {
            result
                .recommended_next_step_labels
                .iter()
                .take(10)
                .map(|label| redactor.redact(label))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_guided_cleanup_flow_prompt_section(
    result: &GuidedCleanupFlowResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let steps = result
        .flow_steps
        .iter()
        .take(10)
        .map(|step| {
            format!(
                "- #{} type={} phase={} risk={} status={} method={} skill={} title={} next={} blockers={}",
                step.rank,
                step.step_type,
                step.phase,
                step.risk,
                redactor.redact(&step.status),
                step.source_method,
                step.skill_name
                    .as_deref()
                    .map(|value| redactor.redact(value))
                    .unwrap_or_else(|| "none".to_string()),
                redactor.redact(&step.title),
                redactor.redact(&step.recommended_action_label),
                step.blocker_notes
                    .iter()
                    .take(3)
                    .map(|blocker| redactor.redact(blocker))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let groups = result
        .issue_groups
        .iter()
        .take(8)
        .map(|group| {
            format!(
                "- {} label={} steps={} high={} medium={} low={}",
                group.group_type,
                redactor.redact(&group.label),
                group.step_count,
                group.high_risk_count,
                group.medium_risk_count,
                group.low_risk_count
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let safe_actions = result
        .safe_next_actions
        .iter()
        .take(8)
        .map(|action| {
            format!(
                "- {} via {} preview={} confirmation={} copy_only={} description={}",
                redactor.redact(&action.label),
                action.entry_method,
                action.requires_preview,
                action.requires_confirmation,
                action.copy_only,
                redactor.redact(&action.description)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let recorded = result
        .recorded_steps
        .iter()
        .take(6)
        .map(|record| {
            format!(
                "- {} decision={} status={} flow_step={}",
                redactor.redact(&record.title),
                redactor.redact(&record.decision),
                redactor.redact(&record.status),
                redactor.redact(&record.flow_step_id)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = result
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Guided cleanup flow evidence:\n- catalog_available: {}\n- total_step_count: {}\n- returned_step_count: {}\n- issue_group_count: {}\n- safe_next_action_count: {}\n- recorded_step_count: {}\n- high_risk_count: {}\n- medium_risk_count: {}\n- low_risk_count: {}\n- blocker_count: {}\n- summary: {}\n\nFlow steps:\n{}\n\nIssue groups:\n{}\n\nSafe next actions:\n{}\n\nRecorded step metadata:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, rollback_performed=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        result.catalog_available,
        result.summary.total_step_count,
        result.summary.returned_step_count,
        result.summary.issue_group_count,
        result.summary.safe_next_action_count,
        result.summary.recorded_step_count,
        result.summary.high_risk_count,
        result.summary.medium_risk_count,
        result.summary.low_risk_count,
        result.summary.blocker_count,
        redactor.redact(&result.summary.summary),
        if steps.is_empty() { "none" } else { &steps },
        if groups.is_empty() { "none" } else { &groups },
        if safe_actions.is_empty() {
            "none"
        } else {
            &safe_actions
        },
        if recorded.is_empty() { "none" } else { &recorded },
        if result.gap_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .gap_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if result.blocker_notes.is_empty() {
            "none".to_string()
        } else {
            result
                .blocker_notes
                .iter()
                .take(10)
                .map(|note| redactor.redact(note))
                .collect::<Vec<_>>()
                .join(" ")
        },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_routing_confidence_prompt_section(
    ranking: &SkillRouteRankingResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let candidates = ranking
        .route_candidates
        .iter()
        .take(8)
        .map(|candidate| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): confidence={} band={} readiness={} quality={} risk={}; rationale={}; ambiguity={}",
                candidate.rank,
                redactor.redact(&candidate.skill_name),
                redactor.redact(&candidate.agent),
                redactor.redact(&candidate.scope),
                candidate.enabled,
                redactor.redact(&candidate.state),
                candidate.confidence_score,
                candidate.confidence_band,
                candidate.readiness_score,
                candidate
                    .quality_score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                candidate.enabled_scope_risk_state.risk_level,
                candidate
                    .confidence_rationale
                    .iter()
                    .take(3)
                    .map(|rationale| redactor.redact(rationale))
                    .collect::<Vec<_>>()
                    .join(" "),
                candidate
                    .ambiguity_warnings
                    .iter()
                    .take(2)
                    .map(|warning| redactor.redact(warning))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let ambiguity = ranking
        .ambiguity_warnings
        .iter()
        .take(8)
        .map(|warning| format!("- {}", redactor.redact(warning)))
        .collect::<Vec<_>>()
        .join("\n");
    let wrong_pick = ranking
        .likely_wrong_pick_risks
        .iter()
        .take(8)
        .map(|risk| format!("- {}", redactor.redact(risk)))
        .collect::<Vec<_>>()
        .join("\n");
    let miss = ranking
        .likely_miss_risks
        .iter()
        .take(8)
        .map(|risk| format!("- {}", redactor.redact(risk)))
        .collect::<Vec<_>>()
        .join("\n");
    let evidence = ranking
        .evidence_references
        .iter()
        .take(16)
        .map(|reference| {
            format!(
                "- {} {} {}",
                reference.source_type,
                redactor.redact(&reference.source_id),
                redactor.redact(&reference.label)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Routing confidence evidence:\n- task: {}\n- overall_confidence_score: {} / 100\n- overall_confidence_band: {}\n- summary: {}\n- catalog_available: {}\n\nRoute candidates:\n{}\n\nAmbiguity warnings:\n{}\n\nLikely wrong-pick risks:\n{}\n\nLikely miss risks:\n{}\n\nEvidence references:\n{}\n\nSafety flags: read_only=true, provider_request_sent=false, write_back_allowed=false, script_execution_allowed=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, credential_accessed=false, raw_prompt_persisted=false, raw_response_persisted=false.",
        redactor.redact(&ranking.task),
        ranking.overall_confidence_score,
        ranking.overall_confidence_band,
        redactor.redact(&ranking.summary),
        ranking.catalog_available,
        if candidates.is_empty() { "none" } else { &candidates },
        if ambiguity.is_empty() { "none" } else { &ambiguity },
        if wrong_pick.is_empty() { "none" } else { &wrong_pick },
        if miss.is_empty() { "none" } else { &miss },
        if evidence.is_empty() { "none" } else { &evidence },
    )
}

pub(crate) fn render_skill_lifecycle_timeline_prompt_section(
    timeline: &SkillLifecycleTimelineResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let events = timeline
        .timeline_rows
        .iter()
        .take(12)
        .map(|row| {
            format!(
                "- {} stage={} status={} severity={} skill={} agent={} summary={}",
                row.event_type,
                row.lifecycle_stage,
                row.status
                    .as_deref()
                    .map(|status| redactor.redact(status))
                    .unwrap_or_else(|| "none".to_string()),
                row.severity
                    .as_deref()
                    .map(|severity| redactor.redact(severity))
                    .unwrap_or_else(|| "none".to_string()),
                row.skill_name
                    .as_deref()
                    .map(|skill| redactor.redact(skill))
                    .unwrap_or_else(|| "none".to_string()),
                row.agent
                    .as_deref()
                    .map(|agent| redactor.redact(agent))
                    .unwrap_or_else(|| "none".to_string()),
                redactor.redact(&row.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let skills = timeline
        .skill_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} ({}, {}, enabled={}, state={}) events={} findings={} drift={} remediation={} prompt={} session={}",
                redactor.redact(&row.skill_name),
                redactor.redact(&row.agent),
                redactor.redact(&row.scope),
                row.enabled,
                redactor.redact(&row.state),
                row.event_count,
                row.finding_event_count,
                row.drift_event_count,
                row.remediation_event_count,
                row.prompt_event_count,
                row.session_review_event_count
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let agents = timeline
        .agent_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- {} skills={} events={} findings={} drift={} remediation={} prompt={} session={}",
                redactor.redact(&row.agent),
                row.skill_count,
                row.event_count,
                row.finding_event_count,
                row.drift_event_count,
                row.remediation_event_count,
                row.prompt_event_count,
                row.session_review_event_count
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let gaps = timeline
        .gap_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let blockers = timeline
        .blocker_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Skill lifecycle timeline evidence:\n- total_event_count: {}\n- skill_count: {}\n- agent_count: {}\n- finding_event_count: {}\n- drift_event_count: {}\n- remediation_event_count: {}\n- prompt_event_count: {}\n- session_review_event_count: {}\n- selected_skill_name: {}\n- selected_agent: {}\n- summary: {}\n\nTimeline rows:\n{}\n\nSkill rows:\n{}\n\nAgent rows:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, credential_accessed=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, raw_secret_returned=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        timeline.summary.total_event_count,
        timeline.summary.skill_count,
        timeline.summary.agent_count,
        timeline.summary.finding_event_count,
        timeline.summary.drift_event_count,
        timeline.summary.remediation_event_count,
        timeline.summary.prompt_event_count,
        timeline.summary.session_review_event_count,
        timeline
            .summary
            .selected_skill_name
            .as_deref()
            .map(|skill| redactor.redact(skill))
            .unwrap_or_else(|| "none".to_string()),
        timeline
            .summary
            .selected_agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "none".to_string()),
        redactor.redact(&timeline.summary.summary),
        if events.is_empty() { "none" } else { &events },
        if skills.is_empty() { "none" } else { &skills },
        if agents.is_empty() { "none" } else { &agents },
        if gaps.is_empty() { "none" } else { &gaps },
        if blockers.is_empty() { "none" } else { &blockers },
    )
}

pub(crate) fn render_task_cockpit_prompt_section(
    cockpit: &TaskCockpitResult,
    redactor: &mut PromptRedactor<'_>,
) -> String {
    let sections = cockpit
        .cockpit_sections
        .iter()
        .take(8)
        .map(|section| {
            format!(
                "- {} status={} score={} rows={} summary={}",
                section.id,
                section.status,
                section
                    .score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string()),
                section.row_count,
                redactor.redact(&section.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let candidates = cockpit
        .skill_candidate_rows
        .iter()
        .take(8)
        .map(|candidate| {
            format!(
                "- #{} {} ({}, {}, enabled={}, state={}): readiness={} {}, routing={} {}, quality={}",
                candidate.rank,
                redactor.redact(&candidate.skill_name),
                redactor.redact(&candidate.agent),
                redactor.redact(&candidate.scope),
                candidate.enabled,
                redactor.redact(&candidate.state),
                candidate.readiness_score,
                candidate.readiness_band,
                candidate.routing_confidence_score,
                candidate.routing_confidence_band,
                candidate
                    .quality_score
                    .map(|score| score.to_string())
                    .unwrap_or_else(|| "n/a".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let agents = cockpit
        .agent_route_rows
        .iter()
        .take(8)
        .map(|row| {
            format!(
                "- #{} {} readiness={} {} routing={} {} best_skill={}",
                row.rank,
                redactor.redact(&row.agent),
                row.readiness_score,
                row.readiness_band,
                row.routing_confidence_score,
                row.routing_confidence_band,
                row.best_skill_name
                    .as_deref()
                    .map(|skill| redactor.redact(skill))
                    .unwrap_or_else(|| "none".to_string())
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let sessions = cockpit
        .session_review_rows
        .iter()
        .take(5)
        .map(|row| {
            format!(
                "- {} outcome={} detected={} expected={} summary={}",
                redactor.redact(&row.title),
                redactor.redact(&row.outcome),
                row.detected_skill_count,
                row.expected_skill_signal_count,
                redactor.redact(&row.summary)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let providers = cockpit
        .provider_observability_rows
        .iter()
        .take(5)
        .map(|row| {
            format!(
                "- {} status={} provider={} model={} count={} message={}",
                row.source,
                redactor.redact(&row.status),
                row.provider
                    .as_deref()
                    .map(|provider| redactor.redact(provider))
                    .unwrap_or_else(|| "none".to_string()),
                row.model
                    .as_deref()
                    .map(|model| redactor.redact(model))
                    .unwrap_or_else(|| "none".to_string()),
                row.count,
                redactor.redact(&row.message)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let remediation = cockpit
        .remediation_next_steps
        .iter()
        .take(8)
        .map(|step| {
            format!(
                "- {} priority={} action={}",
                redactor.redact(&step.title),
                step.priority,
                redactor.redact(&step.suggested_safe_next_action)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let gaps = cockpit
        .gap_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    let blockers = cockpit
        .blocker_notes
        .iter()
        .take(8)
        .map(|note| format!("- {}", redactor.redact(note)))
        .collect::<Vec<_>>()
        .join("\n");
    format!(
        "Task-first cockpit evidence:\n- task: {}\n- readiness_score: {} / 100 ({})\n- routing_confidence_score: {} / 100 ({})\n- recommended_agent: {}\n- top_skill_name: {}\n- candidate_count: {}\n- gap_count: {}\n- blocker_count: {}\n- summary: {}\n\nCockpit sections:\n{}\n\nSkill candidates:\n{}\n\nAgent routes:\n{}\n\nSession review rows:\n{}\n\nProvider observability rows:\n{}\n\nRemediation next steps:\n{}\n\nGap notes:\n{}\n\nBlocker notes:\n{}\n\nSafety flags: read_only=true, app_local_only=true, provider_request_sent=false, credential_accessed=false, write_back_allowed=false, write_actions_available=false, skill_files_mutated=false, agent_config_mutated=false, script_execution_allowed=false, execution_actions_available=false, config_mutation_allowed=false, snapshot_created=false, triage_mutation_allowed=false, raw_secret_returned=false, raw_prompt_persisted=false, raw_response_persisted=false, raw_trace_persisted=false, cloud_sync_performed=false, telemetry_emitted=false.",
        redactor.redact(&cockpit.filters.task),
        cockpit.summary.readiness_score,
        cockpit.summary.readiness_band,
        cockpit.summary.routing_confidence_score,
        cockpit.summary.routing_confidence_band,
        cockpit
            .summary
            .recommended_agent
            .as_deref()
            .map(|agent| redactor.redact(agent))
            .unwrap_or_else(|| "none".to_string()),
        cockpit
            .summary
            .top_skill_name
            .as_deref()
            .map(|skill| redactor.redact(skill))
            .unwrap_or_else(|| "none".to_string()),
        cockpit.summary.candidate_count,
        cockpit.summary.gap_count,
        cockpit.summary.blocker_count,
        redactor.redact(&cockpit.summary.summary),
        if sections.is_empty() { "none" } else { &sections },
        if candidates.is_empty() { "none" } else { &candidates },
        if agents.is_empty() { "none" } else { &agents },
        if sessions.is_empty() { "none" } else { &sessions },
        if providers.is_empty() { "none" } else { &providers },
        if remediation.is_empty() { "none" } else { &remediation },
        if gaps.is_empty() { "none" } else { &gaps },
        if blockers.is_empty() { "none" } else { &blockers },
    )
}

pub(crate) fn llm_skill_analysis_safety_flags() -> LlmSkillAnalysisSafetyFlags {
    LlmSkillAnalysisSafetyFlags {
        write_back_enabled: false,
        script_execution_enabled: false,
        credential_storage_enabled: false,
        confirmation_required: true,
    }
}

pub(crate) fn skill_analysis_prompt_draft(
    analysis_kind: LlmSkillAnalysisKind,
    selected_skill_count: usize,
    included_skills: &[LlmSkillAnalysisIncludedSkill],
    excluded_missing_count: usize,
) -> String {
    let included = skill_analysis_included_summary(included_skills);
    format!(
        "Prepare a read-only {kind} analysis for {selected_skill_count} selected skill instance(s). Included skills: {included}. Missing or excluded selections: {excluded_missing_count}. Do not write files, change agent config, execute scripts, store credentials, create snapshots, or call tools.",
        kind = analysis_kind.as_str()
    )
}

pub(crate) fn skill_analysis_summary_draft(
    analysis_kind: LlmSkillAnalysisKind,
    selected_skill_count: usize,
    included_skills: &[LlmSkillAnalysisIncludedSkill],
    excluded_missing_count: usize,
) -> String {
    let disabled_count = included_skills
        .iter()
        .filter(|skill| !skill.enabled)
        .count();
    format!(
        "Local preview only: {kind} analysis queued for {selected_skill_count} selected skill instance(s), with {} included, {excluded_missing_count} missing or excluded, and {disabled_count} currently disabled. Provider calls, write-back, script execution, credential storage, and snapshots are disabled.",
        included_skills.len(),
        kind = analysis_kind.as_str()
    )
}

pub(crate) fn skill_analysis_included_summary(
    included_skills: &[LlmSkillAnalysisIncludedSkill],
) -> String {
    if included_skills.is_empty() {
        return "none".to_string();
    }
    included_skills
        .iter()
        .map(|skill| {
            format!(
                "{} ({}, {}, enabled={})",
                redact_for_llm_preview(&skill.name),
                redact_for_llm_preview(&skill.agent),
                redact_for_llm_preview(&skill.scope),
                skill.enabled
            )
        })
        .collect::<Vec<_>>()
        .join("; ")
}

pub(crate) fn redact_for_llm_preview(value: &str) -> String {
    let mut redacted = value
        .split_whitespace()
        .map(|token| {
            let lower = token.to_lowercase();
            if lower.contains("key")
                || lower.contains("token")
                || lower.contains("secret")
                || lower.contains("credential")
                || lower.contains("password")
            {
                "<redacted>"
            } else {
                token
            }
        })
        .collect::<Vec<_>>()
        .join(" ");
    const MAX_PREVIEW_CHARS: usize = 220;
    if redacted.chars().count() > MAX_PREVIEW_CHARS {
        redacted = redacted.chars().take(MAX_PREVIEW_CHARS).collect::<String>();
        redacted.push_str("...");
    }
    redacted
}
