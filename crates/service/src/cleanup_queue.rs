use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use skills_copilot_commands::{analyze_catalog, list_conflicts, list_findings};

use crate::{agent_matches, severity_rank_for_queue, ServiceError, ServiceHost};

#[derive(Debug, Clone, Default, Deserialize)]
pub struct CleanupListQueueParams {
    #[serde(default)]
    pub agent: Option<String>,
    #[serde(default)]
    pub limit: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueue {
    pub summary: CleanupQueueSummary,
    pub items: Vec<CleanupQueueItem>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueueSummary {
    pub total_count: usize,
    pub counts_by_kind: BTreeMap<String, usize>,
    pub counts_by_priority: BTreeMap<String, usize>,
    pub read_only: bool,
    pub writes_allowed: bool,
    pub provider_request_sent: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct CleanupQueueItem {
    pub id: String,
    pub kind: String,
    pub severity: String,
    pub priority: String,
    pub agent: Option<String>,
    pub scope: Option<String>,
    pub skill_id: Option<String>,
    pub definition_id: Option<String>,
    pub skill_name: Option<String>,
    pub title: String,
    pub detail: String,
    pub recommended_next_action_label: String,
    pub source_id: String,
    pub read_only: bool,
    pub writes_allowed: bool,
    pub provider_request_sent: bool,
}

impl ServiceHost {
    pub fn cleanup_list_queue(
        &self,
        params: CleanupListQueueParams,
    ) -> Result<CleanupQueue, ServiceError> {
        let Some(catalog) = self.open_existing_catalog_read_only()? else {
            return Ok(cleanup_queue_response(Vec::new(), params.limit));
        };
        let adapter_ctx = self.effective_adapter_ctx()?;
        let skills = self.list_visible_skill_records(&catalog)?;
        let findings = list_findings(&catalog)?;
        let conflicts = list_conflicts(&catalog)?;
        let analysis = analyze_catalog(&catalog, &adapter_ctx)?;
        let agent_filter = params.agent.as_deref().filter(|agent| !agent.is_empty());
        let mut items = Vec::new();

        let skill_by_id = skills
            .iter()
            .map(|skill| (skill.id.as_str(), skill))
            .collect::<BTreeMap<_, _>>();
        let skills_by_definition = skills.iter().fold(
            BTreeMap::<&str, Vec<_>>::new(),
            |mut by_definition, skill| {
                by_definition
                    .entry(skill.definition_id.as_str())
                    .or_default()
                    .push(skill);
                by_definition
            },
        );

        for skill in &skills {
            if !agent_matches(agent_filter, Some(skill.agent.as_str())) {
                continue;
            }
            if matches!(skill.state.as_str(), "broken" | "missing") {
                let severity = if skill.state == "missing" {
                    "error"
                } else {
                    "critical"
                };
                items.push(CleanupQueueItem {
                    id: format!("cleanup:integrity:{}:{}", skill.state, skill.id),
                    kind: "integrity".to_string(),
                    severity: severity.to_string(),
                    priority: priority_for(severity).to_string(),
                    agent: Some(skill.agent.clone()),
                    scope: Some(skill.scope.clone()),
                    skill_id: Some(skill.id.clone()),
                    definition_id: Some(skill.definition_id.clone()),
                    skill_name: Some(skill.name.clone()),
                    title: format!("{} skill record: {}", skill.state, skill.name),
                    detail: "This catalog row is not currently loaded cleanly. Inspect the source and rescan before relying on it.".to_string(),
                    recommended_next_action_label: "Inspect skill details".to_string(),
                    source_id: skill.id.clone(),
                    read_only: true,
                    writes_allowed: false,
                    provider_request_sent: false,
                });
            }
        }

        for conflict in &conflicts {
            let members = conflict
                .instance_ids
                .iter()
                .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                .collect::<Vec<_>>();
            if let Some(agent) = agent_filter {
                let matching_member_count =
                    members.iter().filter(|skill| skill.agent == agent).count();
                if matching_member_count < 2 {
                    continue;
                }
            }
            let first = members.first().copied();
            items.push(CleanupQueueItem {
                id: format!("cleanup:conflict:{}", conflict.id),
                kind: "conflict".to_string(),
                severity: "error".to_string(),
                priority: "high".to_string(),
                agent: first.map(|skill| skill.agent.clone()),
                scope: first.map(|skill| skill.scope.clone()),
                skill_id: conflict
                    .winner_id
                    .clone()
                    .or_else(|| first.map(|skill| skill.id.clone())),
                definition_id: Some(conflict.definition_id.clone()),
                skill_name: first.map(|skill| skill.name.clone()),
                title: format!("Same-agent conflict: {}", conflict.reason),
                detail: format!(
                    "{} skill records share a runtime conflict for definition {}.",
                    conflict.instance_ids.len(),
                    conflict.definition_id
                ),
                recommended_next_action_label: "Review conflict details".to_string(),
                source_id: conflict.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        for finding in &findings {
            if finding.triage_status == "ignored" || finding.suppressed {
                continue;
            }
            let skill = finding
                .instance_id
                .as_deref()
                .and_then(|instance_id| skill_by_id.get(instance_id).copied())
                .or_else(|| {
                    finding
                        .definition_id
                        .as_deref()
                        .and_then(|definition_id| skills_by_definition.get(definition_id))
                        .and_then(|skills| skills.first().copied())
                });
            if !agent_matches(agent_filter, skill.map(|skill| skill.agent.as_str())) {
                continue;
            }
            items.push(CleanupQueueItem {
                id: format!("cleanup:finding:{}", finding.id),
                kind: "finding".to_string(),
                severity: finding.effective_severity.clone(),
                priority: priority_for(&finding.effective_severity).to_string(),
                agent: skill.map(|skill| skill.agent.clone()),
                scope: skill.map(|skill| skill.scope.clone()),
                skill_id: finding
                    .instance_id
                    .clone()
                    .or_else(|| skill.map(|skill| skill.id.clone())),
                definition_id: finding.definition_id.clone(),
                skill_name: skill.map(|skill| skill.name.clone()),
                title: format!("{} finding: {}", finding.rule_id, finding.message),
                detail: finding.suggestion.clone().unwrap_or_else(|| {
                    "Review this rule finding before relying on the skill.".to_string()
                }),
                recommended_next_action_label: "Review finding".to_string(),
                source_id: finding.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        for group in &analysis.groups {
            if let Some(agent) = agent_filter {
                if !group.agents.iter().any(|group_agent| group_agent == agent) {
                    continue;
                }
            }
            let first = group
                .instance_ids
                .iter()
                .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                .find(|skill| agent_matches(agent_filter, Some(skill.agent.as_str())))
                .or_else(|| {
                    group
                        .instance_ids
                        .iter()
                        .filter_map(|instance_id| skill_by_id.get(instance_id.as_str()).copied())
                        .next()
                });
            items.push(CleanupQueueItem {
                id: format!("cleanup:analysis:{}", group.id),
                kind: "analysis".to_string(),
                severity: group.severity.clone(),
                priority: priority_for(&group.severity).to_string(),
                agent: first.map(|skill| skill.agent.clone()),
                scope: first.map(|skill| skill.scope.clone()),
                skill_id: first.map(|skill| skill.id.clone()),
                definition_id: None,
                skill_name: group
                    .canonical_name
                    .clone()
                    .or_else(|| first.map(|skill| skill.name.clone())),
                title: group.title.clone(),
                detail: group.explanation.clone(),
                recommended_next_action_label: "Inspect analysis insight".to_string(),
                source_id: group.id.clone(),
                read_only: true,
                writes_allowed: false,
                provider_request_sent: false,
            });
        }

        Ok(cleanup_queue_response(items, params.limit))
    }
}

pub(crate) fn cleanup_queue_response(
    mut items: Vec<CleanupQueueItem>,
    limit: Option<usize>,
) -> CleanupQueue {
    items.sort_by(|left, right| {
        cleanup_kind_rank(&left.kind)
            .cmp(&cleanup_kind_rank(&right.kind))
            .then_with(|| {
                severity_rank_for_queue(&left.severity)
                    .cmp(&severity_rank_for_queue(&right.severity))
            })
            .then_with(|| left.agent.cmp(&right.agent))
            .then_with(|| left.skill_name.cmp(&right.skill_name))
            .then_with(|| left.skill_id.cmp(&right.skill_id))
            .then_with(|| left.id.cmp(&right.id))
    });
    if let Some(limit) = limit {
        items.truncate(limit);
    }

    let mut counts_by_kind = BTreeMap::new();
    let mut counts_by_priority = BTreeMap::new();
    for item in &items {
        *counts_by_kind.entry(item.kind.clone()).or_insert(0) += 1;
        *counts_by_priority.entry(item.priority.clone()).or_insert(0) += 1;
    }

    CleanupQueue {
        summary: CleanupQueueSummary {
            total_count: items.len(),
            counts_by_kind,
            counts_by_priority,
            read_only: true,
            writes_allowed: false,
            provider_request_sent: false,
        },
        items,
    }
}

fn cleanup_kind_rank(kind: &str) -> u8 {
    match kind {
        "integrity" => 0,
        "conflict" => 1,
        "finding" => 2,
        "analysis" => 3,
        _ => 4,
    }
}

fn priority_for(severity: &str) -> &'static str {
    match severity {
        "critical" => "critical",
        "error" => "high",
        "warn" | "warning" => "medium",
        "info" => "low",
        _ => "low",
    }
}
