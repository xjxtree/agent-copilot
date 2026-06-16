use std::{
    collections::{HashMap, HashSet},
    convert::TryFrom,
    path::{Path, PathBuf},
};

use rusqlite::{params, Connection, OpenFlags, Row};
use serde::Serialize;
use sha2::{Digest, Sha256};
use skills_copilot_core::{
    AgentId, NetworkAccess, PermissionRequest, Scope, SkillInstance, SkillState,
};
use thiserror::Error;

mod schema;

#[derive(Debug)]
pub struct Catalog {
    conn: Connection,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct SkillRecord {
    pub id: String,
    pub agent: String,
    pub scope: String,
    pub path: PathBuf,
    pub display_path: PathBuf,
    pub definition_id: String,
    pub name: String,
    pub state: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct SkillDetailRecord {
    pub id: String,
    pub agent: String,
    pub scope: String,
    pub path: PathBuf,
    pub display_path: PathBuf,
    pub definition_id: String,
    pub name: String,
    pub description: String,
    pub state: String,
    pub enabled: bool,
    pub frontmatter_raw: String,
    pub body: String,
    pub permissions: serde_json::Value,
    pub fingerprint: String,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct RuleFindingRecord {
    pub id: String,
    pub triage_key: String,
    pub triage_context: String,
    pub instance_id: Option<String>,
    pub definition_id: Option<String>,
    pub rule_id: String,
    pub severity: String,
    pub effective_severity: String,
    pub severity_override: Option<String>,
    pub message: String,
    pub suggestion: Option<String>,
    pub created_at: i64,
    pub suppressed: bool,
    pub suppression_reason: Option<String>,
    pub suppression_note: Option<String>,
    pub rule_tuning_updated_at: Option<i64>,
    pub triage_status: String,
    pub triage_note: Option<String>,
    pub triage_updated_at: Option<i64>,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct FindingTriageRecord {
    pub triage_key: String,
    pub triage_context: String,
    pub status: String,
    pub note: Option<String>,
    pub updated_at: i64,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct RuleTuningRecord {
    pub rule_id: String,
    pub agent: Option<String>,
    pub scope: Option<String>,
    pub severity_override: Option<String>,
    pub suppression_reason: Option<String>,
    pub suppression_note: Option<String>,
    pub updated_at: i64,
}

struct RuleTuningUpdate<'a> {
    rule_id: &'a str,
    agent: Option<&'a str>,
    scope: Option<&'a str>,
    severity_override: Option<&'a str>,
    suppression_reason: Option<&'a str>,
    suppression_note: Option<&'a str>,
    updated_at: i64,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct SkillEventRecord {
    pub id: i64,
    pub instance_id: String,
    pub kind: String,
    pub payload: serde_json::Value,
    pub occurred_at: i64,
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct ConflictGroupRecord {
    pub id: String,
    pub definition_id: String,
    pub reason: String,
    pub winner_id: Option<String>,
    pub instance_ids: Vec<String>,
}

/// Slim view of a skill instance sufficient for config-patch operations
/// (e.g. toggling skillOverrides). Avoids materialising the full
/// `SkillInstance` (frontmatter, body, scripts) when only a few fields are
/// needed.
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillInstanceMeta {
    pub id: String,
    pub agent: AgentId,
    pub scope: Scope,
    pub project_root: Option<PathBuf>,
    pub path: PathBuf,
    pub name: String,
    pub enabled: bool,
}

#[derive(Debug, Error)]
pub enum CatalogError {
    #[error("sqlite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
}

impl Catalog {
    pub fn open(path: &Path) -> Result<Self, CatalogError> {
        Ok(Self {
            conn: Connection::open(path)?,
        })
    }

    pub fn open_read_only(path: &Path) -> Result<Self, CatalogError> {
        Ok(Self {
            conn: Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY)?,
        })
    }

    pub fn in_memory() -> Result<Self, CatalogError> {
        Ok(Self {
            conn: Connection::open_in_memory()?,
        })
    }

    pub fn init(&self) -> Result<(), CatalogError> {
        schema::init_schema(&self.conn)?;
        self.canonicalize_legacy_paths()?;
        Ok(())
    }

    fn run_refresh_transaction<F>(&self, operation: F) -> Result<(), CatalogError>
    where
        F: FnOnce() -> Result<(), CatalogError>,
    {
        self.conn.execute_batch("BEGIN IMMEDIATE TRANSACTION")?;
        match operation() {
            Ok(()) => match self.conn.execute_batch("COMMIT") {
                Ok(()) => Ok(()),
                Err(error) => {
                    let _ = self.conn.execute_batch("ROLLBACK");
                    Err(CatalogError::Sqlite(error))
                }
            },
            Err(error) => {
                let _ = self.conn.execute_batch("ROLLBACK");
                Err(error)
            }
        }
    }

    /// Migrate records whose `path` was stored as a display path (pre-refactor)
    /// to the canonical path. When a canonical path already exists for the same
    /// (agent, scope) the non-canonical duplicate is deleted.
    fn canonicalize_legacy_paths(&self) -> Result<usize, CatalogError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, agent, scope, path FROM skill_instance")?;
        let rows: Vec<(String, String, String, String)> = stmt
            .query_map([], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        let mut fixed = 0usize;
        for (id, agent, scope, current_path) in &rows {
            let canonical = match PathBuf::from(current_path).canonicalize() {
                Ok(p) => p,
                Err(_) => continue,
            };
            let canonical_str = canonical.to_string_lossy().to_string();
            if &canonical_str == current_path {
                continue;
            }
            // Does another record already occupy the canonical path?
            let conflict: Option<String> = self
                .conn
                .query_row(
                    "SELECT id FROM skill_instance WHERE agent = ?1 AND scope = ?2 AND path = ?3",
                    params![agent, scope, canonical_str],
                    |row| row.get(0),
                )
                .ok();
            if let Some(conflict_id) = conflict {
                if conflict_id != *id {
                    // Merge: drop the non-canonical duplicate.
                    self.conn
                        .execute("DELETE FROM skill_instance WHERE id = ?1", params![id])?;
                    fixed += 1;
                }
            } else {
                self.conn.execute(
                    "UPDATE skill_instance SET path = ?1 WHERE id = ?2",
                    params![canonical_str, id],
                )?;
                fixed += 1;
            }
        }
        Ok(fixed)
    }

    pub fn upsert_skill_instance(&self, inst: &SkillInstance) -> Result<(), CatalogError> {
        self.conn.execute(
            r#"
            INSERT INTO skill_instance (
                id, agent, scope, project_root, path, display_path, definition_id, name, description,
                version, state, enabled, frontmatter, frontmatter_raw, body, scripts,
                permissions, fingerprint, mtime, first_seen, last_seen
            )
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21)
            ON CONFLICT(agent, scope, path) DO UPDATE SET
                id = excluded.id,
                agent = excluded.agent,
                scope = excluded.scope,
                project_root = excluded.project_root,
                display_path = excluded.display_path,
                definition_id = excluded.definition_id,
                name = excluded.name,
                description = excluded.description,
                version = excluded.version,
                state = excluded.state,
                enabled = excluded.enabled,
                frontmatter = excluded.frontmatter,
                frontmatter_raw = excluded.frontmatter_raw,
                body = excluded.body,
                scripts = excluded.scripts,
                permissions = excluded.permissions,
                fingerprint = excluded.fingerprint,
                mtime = excluded.mtime,
                last_seen = excluded.last_seen
            "#,
            params![
                inst.id,
                inst.agent.as_str(),
                inst.scope.as_str(),
                inst.project_root
                    .as_ref()
                    .map(|path| path.to_string_lossy().to_string()),
                inst.path.to_string_lossy(),
                inst.display_path.to_string_lossy(),
                inst.definition_id,
                inst.name,
                inst.description,
                inst.version,
                inst.state.as_str(),
                i64::from(inst.enabled),
                "{}",
                inst.frontmatter_raw,
                inst.body,
                "[]",
                permissions_json(inst)?,
                inst.fingerprint,
                inst.mtime,
                inst.first_seen,
                inst.last_seen,
            ],
        )?;
        Ok(())
    }

    pub fn upsert_skill_instances(&self, instances: &[SkillInstance]) -> Result<(), CatalogError> {
        for inst in instances {
            self.upsert_skill_instance(inst)?;
        }
        Ok(())
    }

    pub fn instance_fingerprints(&self) -> Result<HashMap<String, String>, CatalogError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, fingerprint FROM skill_instance")?;
        let rows = stmt.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?;
        let mut fingerprints = HashMap::new();
        for row in rows {
            let (id, fingerprint) = row?;
            fingerprints.insert(id, fingerprint);
        }
        Ok(fingerprints)
    }

    pub fn list_skill_records(&self) -> Result<Vec<SkillRecord>, CatalogError> {
        self.list_skill_records_with_project_context(None)
    }

    pub fn list_skill_instances_for_project_context(
        &self,
        current_project_root: Option<&Path>,
    ) -> Result<Vec<SkillInstance>, CatalogError> {
        self.list_skill_instances_with_project_context(Some(current_project_root))
    }

    fn list_skill_instances_with_project_context(
        &self,
        project_context: Option<Option<&Path>>,
    ) -> Result<Vec<SkillInstance>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, project_root, path, COALESCE(display_path, path),
                    definition_id, name, description, version, state, enabled,
                    frontmatter_raw, body, permissions, fingerprint, mtime, first_seen, last_seen
             FROM skill_instance
             ORDER BY agent, scope, name",
        )?;
        let rows = stmt.query_map([], skill_instance_from_row)?;

        let mut instances = Vec::new();
        for row in rows {
            let instance = row?;
            if record_matches_project_context(
                instance.scope.as_str(),
                instance.project_root.as_deref().and_then(Path::to_str),
                project_context,
            ) && catalog_path_has_skill_shape(instance.agent.as_str(), &instance.path)
            {
                instances.push(instance);
            }
        }
        Ok(dedup_skill_instances(instances))
    }

    /// List skill records visible for the current project context.
    ///
    /// Agent-global and tool-global rows are always visible. Agent-project rows
    /// are visible only when their recorded `project_root` matches the active
    /// project context. In no-project mode, project rows remain in the catalog
    /// but are hidden from current UI/service views.
    pub fn list_skill_records_for_project_context(
        &self,
        current_project_root: Option<&Path>,
    ) -> Result<Vec<SkillRecord>, CatalogError> {
        self.list_skill_records_with_project_context(Some(current_project_root))
    }

    fn list_skill_records_with_project_context(
        &self,
        project_context: Option<Option<&Path>>,
    ) -> Result<Vec<SkillRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, project_root, path, COALESCE(display_path, path), definition_id, name, state, enabled FROM skill_instance ORDER BY agent, scope, name",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((
                SkillRecord {
                    id: row.get(0)?,
                    agent: row.get(1)?,
                    scope: row.get(2)?,
                    path: PathBuf::from(row.get::<_, String>(4)?),
                    display_path: PathBuf::from(row.get::<_, String>(5)?),
                    definition_id: row.get(6)?,
                    name: row.get(7)?,
                    state: row.get(8)?,
                    enabled: row.get::<_, i64>(9)? != 0,
                },
                row.get::<_, Option<String>>(3)?,
            ))
        })?;

        let mut records = Vec::new();
        for row in rows {
            let (record, project_root) = row?;
            if record_matches_project_context(
                &record.scope,
                project_root.as_deref(),
                project_context,
            ) && catalog_path_has_skill_shape(&record.agent, &record.path)
            {
                records.push(record);
            }
        }
        Ok(dedup_skill_records(records))
    }

    /// Mark every record for `agent` whose path is under one of `scanned_roots`
    /// but not present in `seen` as `state = 'missing'`. Records whose path is
    /// outside all `scanned_roots` are left untouched — they belong to scopes
    /// the scanner did not visit this round and should not be penalised for it.
    ///
    /// `scanned_roots` and the record paths in the database are expected to be
    /// canonical (resolved through symlinks). The scanner is responsible for
    /// canonicalising both before this call.
    ///
    /// Returns the number of records transitioned to `missing`.
    pub fn mark_missing_except(
        &self,
        agent: &str,
        scanned_roots: &[PathBuf],
        seen: &[(String, PathBuf)],
    ) -> Result<usize, CatalogError> {
        self.mark_missing_except_with_project_context(agent, None, scanned_roots, seen)
    }

    /// Project-aware variant of [`Catalog::mark_missing_except`]. AgentProject
    /// rows are eligible for a missing sweep only when their stored
    /// `project_root` matches the current project context. This keeps scans for
    /// one selected project, or no selected project, from changing catalog state
    /// for records that belong to another project.
    pub fn mark_missing_except_for_project_context(
        &self,
        agent: &str,
        current_project_root: Option<&Path>,
        scanned_roots: &[PathBuf],
        seen: &[(String, PathBuf)],
    ) -> Result<usize, CatalogError> {
        self.mark_missing_except_with_project_context(
            agent,
            Some(current_project_root),
            scanned_roots,
            seen,
        )
    }

    fn mark_missing_except_with_project_context(
        &self,
        agent: &str,
        project_context: Option<Option<&Path>>,
        scanned_roots: &[PathBuf],
        seen: &[(String, PathBuf)],
    ) -> Result<usize, CatalogError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, scope, project_root, path FROM skill_instance WHERE agent = ?1")?;
        let rows = stmt.query_map(params![agent], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
            ))
        })?;

        let mut existing: Vec<(String, String, Option<String>, String)> = Vec::new();
        for row in rows {
            existing.push(row?);
        }

        let seen_set: HashSet<(String, String)> = seen
            .iter()
            .map(|(scope, path)| (scope.clone(), path.to_string_lossy().to_string()))
            .collect();

        let to_mark: Vec<String> = existing
            .into_iter()
            .filter(|(_, scope, project_root, path)| {
                if scope == Scope::ToolGlobal.as_str() {
                    return false;
                }
                if seen_set.contains(&(scope.clone(), path.clone())) {
                    return false;
                }
                if !record_matches_project_context(scope, project_root.as_deref(), project_context)
                {
                    return false;
                }
                let record_path = PathBuf::from(path);
                scanned_roots
                    .iter()
                    .any(|root| record_path.starts_with(root))
            })
            .map(|(id, _, _, _)| id)
            .collect();

        let count = to_mark.len();
        if count > 0 {
            let mut update = self
                .conn
                .prepare("UPDATE skill_instance SET state = 'missing' WHERE id = ?1")?;
            for id in &to_mark {
                update.execute(params![id])?;
            }
        }
        Ok(count)
    }

    pub fn get_skill_instance_meta(
        &self,
        id: &str,
    ) -> Result<Option<SkillInstanceMeta>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, project_root, path, name, enabled
             FROM skill_instance WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            let agent_str: String = row.get(1)?;
            let scope_str: String = row.get(2)?;
            let agent = parse_agent_id(&agent_str).ok_or_else(|| {
                rusqlite::Error::InvalidParameterName(format!("unknown agent: {agent_str}"))
            })?;
            let scope = parse_scope(&scope_str).ok_or_else(|| {
                rusqlite::Error::InvalidParameterName(format!("unknown scope: {scope_str}"))
            })?;
            Ok(SkillInstanceMeta {
                id: row.get(0)?,
                agent,
                scope,
                project_root: row.get::<_, Option<String>>(3)?.map(PathBuf::from),
                path: PathBuf::from(row.get::<_, String>(4)?),
                name: row.get(5)?,
                enabled: row.get::<_, i64>(6)? != 0,
            })
        })?;
        match rows.next() {
            Some(row) => Ok(Some(row?)),
            None => Ok(None),
        }
    }

    pub fn get_skill_record(&self, id: &str) -> Result<Option<SkillRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, path, COALESCE(display_path, path), definition_id, name, state, enabled
             FROM skill_instance WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            Ok(SkillRecord {
                id: row.get(0)?,
                agent: row.get(1)?,
                scope: row.get(2)?,
                path: PathBuf::from(row.get::<_, String>(3)?),
                display_path: PathBuf::from(row.get::<_, String>(4)?),
                definition_id: row.get(5)?,
                name: row.get(6)?,
                state: row.get(7)?,
                enabled: row.get::<_, i64>(8)? != 0,
            })
        })?;
        match rows.next() {
            Some(row) => Ok(Some(row?)),
            None => Ok(None),
        }
    }

    pub fn get_skill_detail(&self, id: &str) -> Result<Option<SkillDetailRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, path, COALESCE(display_path, path), definition_id,
                    name, description, state, enabled, frontmatter_raw, body, permissions, fingerprint
             FROM skill_instance WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            let permissions_raw: String = row.get(12)?;
            Ok(SkillDetailRecord {
                id: row.get(0)?,
                agent: row.get(1)?,
                scope: row.get(2)?,
                path: PathBuf::from(row.get::<_, String>(3)?),
                display_path: PathBuf::from(row.get::<_, String>(4)?),
                definition_id: row.get(5)?,
                name: row.get(6)?,
                description: row.get(7)?,
                state: row.get(8)?,
                enabled: row.get::<_, i64>(9)? != 0,
                frontmatter_raw: row.get(10)?,
                body: row.get(11)?,
                permissions: serde_json::from_str(&permissions_raw)
                    .unwrap_or_else(|_| serde_json::json!({})),
                fingerprint: row.get(13)?,
            })
        })?;
        match rows.next() {
            Some(row) => Ok(Some(row?)),
            None => Ok(None),
        }
    }

    /// Update the `enabled` flag and the human-facing `state` for a skill
    /// instance in a single transaction. The state should be either `"loaded"`
    /// (on) or `"disabled"` (off).
    pub fn set_skill_toggle(
        &self,
        id: &str,
        enabled: bool,
        state: &str,
    ) -> Result<(), CatalogError> {
        self.conn.execute(
            "UPDATE skill_instance SET enabled = ?1, state = ?2 WHERE id = ?3",
            params![i64::from(enabled), state, id],
        )?;
        Ok(())
    }

    pub fn create_skill_event(&self, draft: SkillEventDraft<'_>) -> Result<(), CatalogError> {
        self.conn.execute(
            "INSERT INTO skill_event (instance_id, kind, payload, occurred_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                draft.instance_id,
                draft.kind,
                draft.payload,
                draft.occurred_at_ms,
            ],
        )?;
        Ok(())
    }

    pub fn list_skill_events(
        &self,
        instance_id: &str,
        limit: Option<usize>,
    ) -> Result<Vec<SkillEventRecord>, CatalogError> {
        if let Some(limit) = limit {
            let limit_i64 = i64::try_from(limit).unwrap_or(i64::MAX);
            let mut stmt = self.conn.prepare(
                "SELECT id, instance_id, kind, payload, occurred_at
                 FROM skill_event
                 WHERE instance_id = ?1
                 ORDER BY occurred_at DESC, id DESC
                 LIMIT ?2",
            )?;
            let rows = stmt.query_map(params![instance_id, limit_i64], skill_event_from_row)?;
            let mut events = Vec::new();
            for row in rows {
                events.push(row?);
            }
            Ok(events)
        } else {
            let mut stmt = self.conn.prepare(
                "SELECT id, instance_id, kind, payload, occurred_at
                 FROM skill_event
                 WHERE instance_id = ?1
                 ORDER BY occurred_at DESC, id DESC",
            )?;
            let rows = stmt.query_map(params![instance_id], skill_event_from_row)?;
            let mut events = Vec::new();
            for row in rows {
                events.push(row?);
            }
            Ok(events)
        }
    }

    pub fn refresh_rule_findings(&self, findings: &[RuleFindingDraft]) -> Result<(), CatalogError> {
        self.run_refresh_transaction(|| {
            self.conn.execute("DELETE FROM rule_finding", [])?;
            for finding in findings {
                let triage_context = self.finding_triage_context(finding)?;
                let triage_key = finding_triage_key(finding, &triage_context);
                self.conn.execute(
                    "INSERT INTO rule_finding (
                        id, triage_key, triage_context, instance_id, definition_id,
                        rule_id, severity, message, suggestion, created_at
                     )
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
                    params![
                        finding.id,
                        triage_key,
                        triage_context,
                        finding.instance_id.as_deref(),
                        finding.definition_id.as_deref(),
                        finding.rule_id,
                        finding.severity,
                        finding.message,
                        finding.suggestion.as_deref(),
                        finding.created_at,
                    ],
                )?;
            }
            Ok(())
        })
    }

    pub fn list_rule_findings(&self) -> Result<Vec<RuleFindingRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "WITH finding_targets AS (
                SELECT
                    f.*,
                    COALESCE(i.agent, di.agent, '') AS target_agent,
                    COALESCE(i.scope, di.scope, '') AS target_scope
                FROM rule_finding f
                LEFT JOIN skill_instance i ON i.id = f.instance_id
                LEFT JOIN skill_instance di ON di.id = (
                    SELECT si.id
                    FROM skill_instance si
                    WHERE si.definition_id = f.definition_id
                    ORDER BY si.id
                    LIMIT 1
                )
             )
             SELECT
                f.id, f.triage_key, f.triage_context, f.instance_id, f.definition_id,
                f.rule_id, f.severity,
                COALESCE((
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = f.target_scope
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = ''
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = ''
                      AND t.scope = ''
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                ), f.severity) AS effective_severity,
                COALESCE((
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = f.target_scope
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = ''
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.severity_override
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = ''
                      AND t.scope = ''
                      AND t.severity_override IS NOT NULL
                    LIMIT 1
                )) AS severity_override,
                f.message, f.suggestion, f.created_at,
                COALESCE((
                    SELECT t.suppression_reason
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = f.target_scope
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.suppression_reason
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = ''
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.suppression_reason
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = ''
                      AND t.scope = ''
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                )) AS suppression_reason,
                COALESCE((
                    SELECT t.suppression_note
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = f.target_scope
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.suppression_note
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = ''
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                ), (
                    SELECT t.suppression_note
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = ''
                      AND t.scope = ''
                      AND t.suppression_reason IS NOT NULL
                    LIMIT 1
                )) AS suppression_note,
                COALESCE((
                    SELECT t.updated_at
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = f.target_scope
                      AND (t.severity_override IS NOT NULL OR t.suppression_reason IS NOT NULL)
                    LIMIT 1
                ), (
                    SELECT t.updated_at
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = f.target_agent
                      AND t.scope = ''
                      AND (t.severity_override IS NOT NULL OR t.suppression_reason IS NOT NULL)
                    LIMIT 1
                ), (
                    SELECT t.updated_at
                    FROM rule_tuning t
                    WHERE t.rule_id = f.rule_id
                      AND t.agent = ''
                      AND t.scope = ''
                      AND (t.severity_override IS NOT NULL OR t.suppression_reason IS NOT NULL)
                    LIMIT 1
                )) AS rule_tuning_updated_at,
                COALESCE(t.status, 'open') AS triage_status,
                t.note,
                t.updated_at
             FROM finding_targets f
             LEFT JOIN finding_triage t
                ON t.triage_key = f.triage_key
               AND t.triage_context = f.triage_context
             ORDER BY
                CASE effective_severity
                    WHEN 'error' THEN 0
                    WHEN 'warn' THEN 1
                    WHEN 'warning' THEN 1
                    WHEN 'info' THEN 2
                    ELSE 3
                END,
                rule_id,
                instance_id",
        )?;
        let rows = stmt.query_map([], |row| {
            let suppression_reason: Option<String> = row.get(12)?;
            Ok(RuleFindingRecord {
                id: row.get(0)?,
                triage_key: row.get(1)?,
                triage_context: row.get(2)?,
                instance_id: row.get(3)?,
                definition_id: row.get(4)?,
                rule_id: row.get(5)?,
                severity: row.get(6)?,
                effective_severity: row.get(7)?,
                severity_override: row.get(8)?,
                message: row.get(9)?,
                suggestion: row.get(10)?,
                created_at: row.get(11)?,
                suppressed: suppression_reason.is_some(),
                suppression_reason,
                suppression_note: row.get(13)?,
                rule_tuning_updated_at: row.get(14)?,
                triage_status: row.get(15)?,
                triage_note: row.get(16)?,
                triage_updated_at: row.get(17)?,
            })
        })?;
        let mut findings = Vec::new();
        for row in rows {
            findings.push(row?);
        }
        Ok(findings)
    }

    pub fn set_finding_triage(
        &self,
        triage_key: &str,
        status: &str,
        note: Option<&str>,
        updated_at: i64,
    ) -> Result<Option<FindingTriageRecord>, CatalogError> {
        let Some(triage_context) = self.current_finding_triage_context(triage_key)? else {
            return Ok(None);
        };
        self.conn.execute(
            "INSERT INTO finding_triage (triage_key, triage_context, status, note, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(triage_key) DO UPDATE SET
                triage_context = excluded.triage_context,
                status = excluded.status,
                note = excluded.note,
                updated_at = excluded.updated_at",
            params![
                triage_key,
                triage_context.as_str(),
                status,
                note,
                updated_at
            ],
        )?;
        Ok(Some(FindingTriageRecord {
            triage_key: triage_key.to_string(),
            triage_context,
            status: status.to_string(),
            note: note.map(str::to_string),
            updated_at,
        }))
    }

    pub fn clear_finding_triage(&self, triage_key: &str) -> Result<bool, CatalogError> {
        Ok(self.conn.execute(
            "DELETE FROM finding_triage WHERE triage_key = ?1",
            params![triage_key],
        )? > 0)
    }

    pub fn list_finding_triage(&self) -> Result<Vec<FindingTriageRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT triage_key, triage_context, status, note, updated_at
             FROM finding_triage
             ORDER BY updated_at DESC, triage_key",
        )?;
        let rows = stmt.query_map([], finding_triage_from_row)?;
        let mut triage = Vec::new();
        for row in rows {
            triage.push(row?);
        }
        Ok(triage)
    }

    pub fn list_rule_tuning(&self) -> Result<Vec<RuleTuningRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT rule_id, agent, scope, severity_override, suppression_reason, suppression_note, updated_at
             FROM rule_tuning
             ORDER BY rule_id, agent, scope",
        )?;
        let rows = stmt.query_map([], rule_tuning_from_row)?;
        let mut tuning = Vec::new();
        for row in rows {
            tuning.push(row?);
        }
        Ok(tuning)
    }

    pub fn set_rule_severity_override(
        &self,
        rule_id: &str,
        agent: Option<&str>,
        scope: Option<&str>,
        severity: &str,
        updated_at: i64,
    ) -> Result<RuleTuningRecord, CatalogError> {
        self.upsert_rule_tuning(RuleTuningUpdate {
            rule_id,
            agent,
            scope,
            severity_override: Some(severity),
            suppression_reason: None,
            suppression_note: None,
            updated_at,
        })?;
        self.get_rule_tuning(rule_id, agent, scope)
    }

    pub fn clear_rule_severity_override(
        &self,
        rule_id: &str,
        agent: Option<&str>,
        scope: Option<&str>,
        updated_at: i64,
    ) -> Result<bool, CatalogError> {
        let key = rule_tuning_key(agent, scope);
        if self.conn.execute(
            "DELETE FROM rule_tuning
             WHERE rule_id = ?1 AND agent = ?2 AND scope = ?3
               AND severity_override IS NOT NULL
               AND suppression_reason IS NULL",
            params![rule_id, key.0, key.1],
        )? > 0
        {
            return Ok(true);
        }
        Ok(self.conn.execute(
            "UPDATE rule_tuning
             SET severity_override = NULL, updated_at = ?4
             WHERE rule_id = ?1 AND agent = ?2 AND scope = ?3
               AND severity_override IS NOT NULL",
            params![rule_id, key.0, key.1, updated_at],
        )? > 0)
    }

    pub fn set_rule_suppression(
        &self,
        rule_id: &str,
        agent: Option<&str>,
        scope: Option<&str>,
        reason: &str,
        note: Option<&str>,
        updated_at: i64,
    ) -> Result<RuleTuningRecord, CatalogError> {
        self.upsert_rule_tuning(RuleTuningUpdate {
            rule_id,
            agent,
            scope,
            severity_override: None,
            suppression_reason: Some(reason),
            suppression_note: note,
            updated_at,
        })?;
        self.get_rule_tuning(rule_id, agent, scope)
    }

    pub fn clear_rule_suppression(
        &self,
        rule_id: &str,
        agent: Option<&str>,
        scope: Option<&str>,
        updated_at: i64,
    ) -> Result<bool, CatalogError> {
        let key = rule_tuning_key(agent, scope);
        if self.conn.execute(
            "DELETE FROM rule_tuning
             WHERE rule_id = ?1 AND agent = ?2 AND scope = ?3
               AND severity_override IS NULL
               AND suppression_reason IS NOT NULL",
            params![rule_id, key.0, key.1],
        )? > 0
        {
            return Ok(true);
        }
        Ok(self.conn.execute(
            "UPDATE rule_tuning
             SET suppression_reason = NULL, suppression_note = NULL, updated_at = ?4
             WHERE rule_id = ?1 AND agent = ?2 AND scope = ?3
               AND suppression_reason IS NOT NULL",
            params![rule_id, key.0, key.1, updated_at],
        )? > 0)
    }

    fn upsert_rule_tuning(&self, update: RuleTuningUpdate<'_>) -> Result<(), CatalogError> {
        let key = rule_tuning_key(update.agent, update.scope);
        self.conn.execute(
            "INSERT INTO rule_tuning (
                rule_id, agent, scope, severity_override, suppression_reason, suppression_note, updated_at
             )
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(rule_id, agent, scope) DO UPDATE SET
                severity_override = COALESCE(excluded.severity_override, rule_tuning.severity_override),
                suppression_reason = COALESCE(excluded.suppression_reason, rule_tuning.suppression_reason),
                suppression_note = CASE
                    WHEN excluded.suppression_reason IS NOT NULL THEN excluded.suppression_note
                    ELSE rule_tuning.suppression_note
                END,
                updated_at = excluded.updated_at",
            params![
                update.rule_id,
                key.0,
                key.1,
                update.severity_override,
                update.suppression_reason,
                update.suppression_note,
                update.updated_at
            ],
        )?;
        Ok(())
    }

    fn get_rule_tuning(
        &self,
        rule_id: &str,
        agent: Option<&str>,
        scope: Option<&str>,
    ) -> Result<RuleTuningRecord, CatalogError> {
        let key = rule_tuning_key(agent, scope);
        self.conn.query_row(
            "SELECT rule_id, agent, scope, severity_override, suppression_reason, suppression_note, updated_at
             FROM rule_tuning
             WHERE rule_id = ?1 AND agent = ?2 AND scope = ?3",
            params![rule_id, key.0, key.1],
            rule_tuning_from_row,
        ).map_err(Into::into)
    }

    fn current_finding_triage_context(
        &self,
        triage_key: &str,
    ) -> Result<Option<String>, CatalogError> {
        Ok(self
            .conn
            .query_row(
                "SELECT triage_context FROM rule_finding WHERE triage_key = ?1 LIMIT 1",
                params![triage_key],
                |row| row.get(0),
            )
            .ok())
    }

    fn finding_triage_context(&self, finding: &RuleFindingDraft) -> Result<String, CatalogError> {
        let mut members = Vec::new();
        if let Some(definition_id) = finding.definition_id.as_deref() {
            let mut stmt = self.conn.prepare(
                "SELECT id, fingerprint FROM skill_instance
                 WHERE definition_id = ?1
                 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![definition_id], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })?;
            for row in rows {
                members.push(row?);
            }
        } else if let Some(instance_id) = finding.instance_id.as_deref() {
            let mut stmt = self.conn.prepare(
                "SELECT id, fingerprint FROM skill_instance
                 WHERE id = ?1
                 ORDER BY id",
            )?;
            let rows = stmt.query_map(params![instance_id], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })?;
            for row in rows {
                members.push(row?);
            }
        }

        let raw = members
            .into_iter()
            .map(|(id, fingerprint)| format!("{id}\x1f{fingerprint}"))
            .collect::<Vec<_>>()
            .join("\x1e");
        Ok(stable_hash(&raw))
    }

    pub fn refresh_definitions_and_conflicts(
        &self,
        definitions: &[SkillDefinitionDraft],
        conflicts: &[ConflictGroupDraft],
    ) -> Result<(), CatalogError> {
        self.run_refresh_transaction(|| {
            self.conn.execute("DELETE FROM conflict_group_member", [])?;
            self.conn.execute("DELETE FROM conflict_group", [])?;
            self.conn.execute("DELETE FROM skill_definition", [])?;

            for definition in definitions {
                self.conn.execute(
                    "INSERT INTO skill_definition (
                        id, canonical_name, description, active_instance,
                        has_multiple_instances, has_conflict
                     )
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                    params![
                        definition.id,
                        definition.canonical_name,
                        definition.description,
                        definition.active_instance.as_deref(),
                        i64::from(definition.has_multiple_instances),
                        i64::from(definition.has_conflict),
                    ],
                )?;
            }

            for conflict in conflicts {
                self.conn.execute(
                    "INSERT INTO conflict_group (id, definition_id, reason, winner_id)
                     VALUES (?1, ?2, ?3, ?4)",
                    params![
                        conflict.id,
                        conflict.definition_id,
                        conflict.reason,
                        conflict.winner_id.as_deref(),
                    ],
                )?;
                for instance_id in &conflict.instance_ids {
                    self.conn.execute(
                        "INSERT INTO conflict_group_member (group_id, instance_id)
                         VALUES (?1, ?2)",
                        params![conflict.id, instance_id],
                    )?;
                }
            }
            Ok(())
        })
    }

    pub fn list_conflict_groups(&self) -> Result<Vec<ConflictGroupRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, definition_id, reason, winner_id
             FROM conflict_group
             ORDER BY definition_id, reason",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, Option<String>>(3)?,
            ))
        })?;
        let mut groups = Vec::new();
        for row in rows {
            let (id, definition_id, reason, winner_id) = row?;
            let mut member_stmt = self.conn.prepare(
                "SELECT instance_id
                 FROM conflict_group_member
                 WHERE group_id = ?1
                 ORDER BY instance_id",
            )?;
            let member_rows = member_stmt.query_map(params![&id], |row| row.get(0))?;
            let mut instance_ids = Vec::new();
            for member in member_rows {
                instance_ids.push(member?);
            }
            groups.push(ConflictGroupRecord {
                id,
                definition_id,
                reason,
                winner_id,
                instance_ids,
            });
        }
        Ok(groups)
    }

    /// Record a pre-write snapshot of a config file. Caller supplies a unique
    /// id (e.g. `"snap-<nanos>"`). The `draft` bundles the snapshot fields so
    /// the call site stays readable.
    pub fn create_config_snapshot(
        &self,
        draft: ConfigSnapshotDraft<'_>,
    ) -> Result<(), CatalogError> {
        self.conn.execute(
            "INSERT INTO config_snapshot (id, agent, scope, target, content, reason, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                draft.id,
                draft.agent,
                draft.scope,
                draft.target,
                draft.content,
                draft.reason,
                draft.created_at_ms,
            ],
        )?;
        Ok(())
    }

    /// List snapshots for a given (agent, target) pair, newest first. The
    /// `LIST-SKILLS` UI can render this for the rollback view.
    pub fn list_config_snapshots(
        &self,
        agent: &str,
        target: &str,
    ) -> Result<Vec<ConfigSnapshotRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, target, content, reason, created_at
             FROM config_snapshot
             WHERE agent = ?1 AND target = ?2
               AND reason IN ('pre-toggle', 'pre-batch-toggle', 'pre-config-edit')
             ORDER BY created_at DESC, id DESC",
        )?;
        let rows = stmt.query_map(params![agent, target], |row| {
            Ok(ConfigSnapshotRecord {
                id: row.get(0)?,
                agent: row.get(1)?,
                scope: row.get(2)?,
                target: row.get(3)?,
                content: row.get(4)?,
                reason: row.get(5)?,
                created_at: row.get(6)?,
            })
        })?;
        let mut snapshots = Vec::new();
        for row in rows {
            snapshots.push(row?);
        }
        Ok(snapshots)
    }

    pub fn list_agent_config_snapshots(
        &self,
        agent: &str,
        scope: Option<&str>,
    ) -> Result<Vec<ConfigSnapshotRecord>, CatalogError> {
        if let Some(scope) = scope {
            let mut stmt = self.conn.prepare(
                "SELECT id, agent, scope, target, content, reason, created_at
                 FROM config_snapshot
                 WHERE agent = ?1 AND scope = ?2
                   AND reason IN ('pre-toggle', 'pre-batch-toggle', 'pre-config-edit')
                 ORDER BY created_at DESC, id DESC",
            )?;
            let rows = stmt.query_map(params![agent, scope], |row| {
                Ok(ConfigSnapshotRecord {
                    id: row.get(0)?,
                    agent: row.get(1)?,
                    scope: row.get(2)?,
                    target: row.get(3)?,
                    content: row.get(4)?,
                    reason: row.get(5)?,
                    created_at: row.get(6)?,
                })
            })?;
            let mut snapshots = Vec::new();
            for row in rows {
                snapshots.push(row?);
            }
            Ok(snapshots)
        } else {
            let mut stmt = self.conn.prepare(
                "SELECT id, agent, scope, target, content, reason, created_at
                 FROM config_snapshot
                 WHERE agent = ?1
                   AND reason IN ('pre-toggle', 'pre-batch-toggle', 'pre-config-edit')
                 ORDER BY created_at DESC, id DESC",
            )?;
            let rows = stmt.query_map(params![agent], |row| {
                Ok(ConfigSnapshotRecord {
                    id: row.get(0)?,
                    agent: row.get(1)?,
                    scope: row.get(2)?,
                    target: row.get(3)?,
                    content: row.get(4)?,
                    reason: row.get(5)?,
                    created_at: row.get(6)?,
                })
            })?;
            let mut snapshots = Vec::new();
            for row in rows {
                snapshots.push(row?);
            }
            Ok(snapshots)
        }
    }

    pub fn list_all_config_snapshots(&self) -> Result<Vec<ConfigSnapshotRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, target, content, reason, created_at
             FROM config_snapshot
             WHERE reason IN ('pre-toggle', 'pre-batch-toggle', 'pre-config-edit')
             ORDER BY created_at DESC, id DESC",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(ConfigSnapshotRecord {
                id: row.get(0)?,
                agent: row.get(1)?,
                scope: row.get(2)?,
                target: row.get(3)?,
                content: row.get(4)?,
                reason: row.get(5)?,
                created_at: row.get(6)?,
            })
        })?;
        let mut snapshots = Vec::new();
        for row in rows {
            snapshots.push(row?);
        }
        Ok(snapshots)
    }

    pub fn get_config_snapshot(
        &self,
        id: &str,
    ) -> Result<Option<ConfigSnapshotRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, target, content, reason, created_at
             FROM config_snapshot
             WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            Ok(ConfigSnapshotRecord {
                id: row.get(0)?,
                agent: row.get(1)?,
                scope: row.get(2)?,
                target: row.get(3)?,
                content: row.get(4)?,
                reason: row.get(5)?,
                created_at: row.get(6)?,
            })
        })?;
        match rows.next() {
            Some(row) => Ok(Some(row?)),
            None => Ok(None),
        }
    }
}

fn record_matches_project_context(
    scope: &str,
    record_project_root: Option<&str>,
    project_context: Option<Option<&Path>>,
) -> bool {
    let Some(current_project_root) = project_context else {
        return true;
    };
    if scope != Scope::AgentProject.as_str() {
        return true;
    }
    let (Some(record_project_root), Some(current_project_root)) =
        (record_project_root, current_project_root)
    else {
        return false;
    };
    same_project_root(Path::new(record_project_root), current_project_root)
}

fn same_project_root(record_project_root: &Path, current_project_root: &Path) -> bool {
    if record_project_root == current_project_root {
        return true;
    }
    match (
        record_project_root.canonicalize(),
        current_project_root.canonicalize(),
    ) {
        (Ok(record), Ok(current)) => record == current,
        _ => false,
    }
}

#[derive(Debug, Clone, Eq, PartialEq, Serialize)]
pub struct ConfigSnapshotRecord {
    pub id: String,
    pub agent: String,
    pub scope: String,
    pub target: String,
    pub content: String,
    pub reason: String,
    pub created_at: i64,
}

/// Bundled parameters for [`Catalog::create_config_snapshot`]. Avoids a
/// long parameter list at the call site and keeps the snapshot payload
/// self-describing.
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct ConfigSnapshotDraft<'a> {
    pub id: &'a str,
    pub agent: &'a str,
    pub scope: &'a str,
    pub target: &'a str,
    pub content: &'a str,
    pub reason: &'a str,
    pub created_at_ms: i64,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillEventDraft<'a> {
    pub instance_id: &'a str,
    pub kind: &'a str,
    pub payload: &'a str,
    pub occurred_at_ms: i64,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct RuleFindingDraft {
    pub id: String,
    pub instance_id: Option<String>,
    pub definition_id: Option<String>,
    pub rule_id: String,
    pub severity: String,
    pub message: String,
    pub suggestion: Option<String>,
    pub created_at: i64,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SkillDefinitionDraft {
    pub id: String,
    pub canonical_name: String,
    pub description: String,
    pub active_instance: Option<String>,
    pub has_multiple_instances: bool,
    pub has_conflict: bool,
}

#[derive(Debug, Clone, Eq, PartialEq)]
pub struct ConflictGroupDraft {
    pub id: String,
    pub definition_id: String,
    pub reason: String,
    pub winner_id: Option<String>,
    pub instance_ids: Vec<String>,
}

fn parse_agent_id(s: &str) -> Option<AgentId> {
    match s {
        "tool-global" => Some(AgentId::ToolGlobal),
        "claude-code" => Some(AgentId::ClaudeCode),
        "codex" => Some(AgentId::Codex),
        "pi" => Some(AgentId::Pi),
        "hermes" => Some(AgentId::Hermes),
        "openclaw" => Some(AgentId::Openclaw),
        "opencode" => Some(AgentId::Opencode),
        _ => None,
    }
}

fn parse_scope(s: &str) -> Option<Scope> {
    match s {
        "tool-global" => Some(Scope::ToolGlobal),
        "agent-global" => Some(Scope::AgentGlobal),
        "agent-project" => Some(Scope::AgentProject),
        _ => None,
    }
}

fn parse_skill_state(s: &str) -> SkillState {
    match s {
        "loaded" => SkillState::Loaded,
        "disabled" => SkillState::Disabled,
        "shadowed" => SkillState::Shadowed,
        "missing" => SkillState::Missing,
        _ => SkillState::Broken,
    }
}

fn skill_instance_from_row(row: &Row<'_>) -> rusqlite::Result<SkillInstance> {
    let agent_str: String = row.get(1)?;
    let scope_str: String = row.get(2)?;
    let state_str: String = row.get(10)?;
    let permissions_raw: String = row.get(14)?;
    let agent = parse_agent_id(&agent_str).ok_or_else(|| {
        rusqlite::Error::InvalidParameterName(format!("unknown agent: {agent_str}"))
    })?;
    let scope = parse_scope(&scope_str).ok_or_else(|| {
        rusqlite::Error::InvalidParameterName(format!("unknown scope: {scope_str}"))
    })?;
    let name: String = row.get(7)?;

    Ok(SkillInstance {
        id: row.get(0)?,
        agent,
        scope,
        project_root: row.get::<_, Option<String>>(3)?.map(PathBuf::from),
        path: PathBuf::from(row.get::<_, String>(4)?),
        display_path: PathBuf::from(row.get::<_, String>(5)?),
        definition_id: row.get(6)?,
        name: name.clone(),
        display_name: name,
        description: row.get(8)?,
        version: row.get(9)?,
        state: parse_skill_state(&state_str),
        enabled: row.get::<_, i64>(11)? != 0,
        frontmatter_raw: row.get(12)?,
        body: row.get(13)?,
        scripts: Vec::new(),
        permissions: parse_permissions_json(&permissions_raw),
        fingerprint: row.get(15)?,
        mtime: row.get(16)?,
        first_seen: row.get(17)?,
        last_seen: row.get(18)?,
    })
}

fn catalog_path_has_skill_shape(agent: &str, path: &Path) -> bool {
    match agent {
        "pi" => {
            if path.file_name().and_then(|name| name.to_str()) != Some("SKILL.md") {
                return false;
            }
            if path
                .parent()
                .and_then(Path::file_name)
                .and_then(|name| name.to_str())
                == Some("skills")
            {
                return false;
            }
            !path
                .components()
                .any(|component| component.as_os_str().to_str() == Some("references"))
        }
        "hermes" | "openclaw" | "opencode" => {
            path.file_name().and_then(|name| name.to_str()) == Some("SKILL.md")
        }
        _ => true,
    }
}

fn dedup_skill_records(records: Vec<SkillRecord>) -> Vec<SkillRecord> {
    let mut by_identity: HashMap<(String, String, String), usize> = HashMap::new();
    let mut deduped: Vec<SkillRecord> = Vec::new();

    for record in records {
        let key = (
            record.agent.clone(),
            record.scope.clone(),
            record.path.to_string_lossy().into_owned(),
        );
        if let Some(&index) = by_identity.get(&key) {
            if catalog_state_rank(&record.state) < catalog_state_rank(&deduped[index].state) {
                deduped[index] = record;
            }
            continue;
        }

        by_identity.insert(key, deduped.len());
        deduped.push(record);
    }

    deduped
}

fn dedup_skill_instances(instances: Vec<SkillInstance>) -> Vec<SkillInstance> {
    let mut by_identity: HashMap<(String, String, String), usize> = HashMap::new();
    let mut deduped: Vec<SkillInstance> = Vec::new();

    for instance in instances {
        let key = (
            instance.agent.as_str().to_string(),
            instance.scope.as_str().to_string(),
            instance.path.to_string_lossy().into_owned(),
        );
        if let Some(&index) = by_identity.get(&key) {
            if skill_state_rank(&instance.state) < skill_state_rank(&deduped[index].state) {
                deduped[index] = instance;
            }
            continue;
        }

        by_identity.insert(key, deduped.len());
        deduped.push(instance);
    }

    deduped
}

fn catalog_state_rank(state: &str) -> usize {
    match state {
        "loaded" | "disabled" => 0,
        "broken" => 1,
        "shadowed" => 2,
        "missing" => 3,
        _ => 4,
    }
}

fn skill_state_rank(state: &SkillState) -> usize {
    match state {
        SkillState::Loaded | SkillState::Disabled => 0,
        SkillState::Broken => 1,
        SkillState::Shadowed => 2,
        SkillState::Missing => 3,
    }
}

fn skill_event_from_row(row: &Row<'_>) -> rusqlite::Result<SkillEventRecord> {
    let payload_raw: String = row.get(3)?;
    Ok(SkillEventRecord {
        id: row.get(0)?,
        instance_id: row.get(1)?,
        kind: row.get(2)?,
        payload: serde_json::from_str(&payload_raw).unwrap_or_else(|_| {
            serde_json::json!({
                "raw": payload_raw,
                "parse_error": true
            })
        }),
        occurred_at: row.get(4)?,
    })
}

fn finding_triage_from_row(row: &Row<'_>) -> rusqlite::Result<FindingTriageRecord> {
    Ok(FindingTriageRecord {
        triage_key: row.get(0)?,
        triage_context: row.get(1)?,
        status: row.get(2)?,
        note: row.get(3)?,
        updated_at: row.get(4)?,
    })
}

fn rule_tuning_from_row(row: &Row<'_>) -> rusqlite::Result<RuleTuningRecord> {
    let agent: String = row.get(1)?;
    let scope: String = row.get(2)?;
    Ok(RuleTuningRecord {
        rule_id: row.get(0)?,
        agent: empty_string_as_none(agent),
        scope: empty_string_as_none(scope),
        severity_override: row.get(3)?,
        suppression_reason: row.get(4)?,
        suppression_note: row.get(5)?,
        updated_at: row.get(6)?,
    })
}

fn rule_tuning_key(agent: Option<&str>, scope: Option<&str>) -> (String, String) {
    (
        agent.unwrap_or_default().trim().to_string(),
        scope.unwrap_or_default().trim().to_string(),
    )
}

fn empty_string_as_none(value: String) -> Option<String> {
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

pub fn migration_count() -> usize {
    5
}

fn finding_triage_key(finding: &RuleFindingDraft, triage_context: &str) -> String {
    stable_hash(&format!(
        "{}\x1f{}\x1f{}\x1f{}\x1f{}\x1f{}",
        finding.instance_id.as_deref().unwrap_or(""),
        finding.definition_id.as_deref().unwrap_or(""),
        finding.rule_id,
        finding.message,
        finding.suggestion.as_deref().unwrap_or(""),
        triage_context
    ))
}

fn stable_hash(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn permissions_json(inst: &SkillInstance) -> Result<String, serde_json::Error> {
    let mut value = serde_json::Map::new();
    if !inst.permissions.tools.is_empty() {
        value.insert(
            "tools".to_string(),
            serde_json::Value::Array(
                inst.permissions
                    .tools
                    .iter()
                    .cloned()
                    .map(serde_json::Value::String)
                    .collect(),
            ),
        );
    }
    if !inst.permissions.files.is_empty() {
        value.insert(
            "files".to_string(),
            serde_json::Value::Array(
                inst.permissions
                    .files
                    .iter()
                    .cloned()
                    .map(serde_json::Value::String)
                    .collect(),
            ),
        );
    }
    if inst.permissions.network_declared {
        value.insert(
            "network".to_string(),
            serde_json::Value::String(network_access_key(&inst.permissions.network).to_string()),
        );
    }
    if inst.permissions.exec_declared || inst.permissions.exec {
        value.insert("exec".to_string(), inst.permissions.exec.into());
    }
    if inst.permissions.requires_human_declared {
        value.insert(
            "requires_human".to_string(),
            inst.permissions.requires_human.into(),
        );
    }
    serde_json::to_string(&serde_json::Value::Object(value))
}

fn parse_permissions_json(raw: &str) -> PermissionRequest {
    let value = match serde_json::from_str::<serde_json::Value>(raw) {
        Ok(serde_json::Value::Object(value)) => value,
        _ => return PermissionRequest::default(),
    };

    let mut permissions = PermissionRequest::default();
    if let Some(tools) = parse_string_array(value.get("tools")) {
        permissions.tools = tools;
    }
    if let Some(files) = parse_string_array(value.get("files")) {
        permissions.files = files;
    }
    if let Some(network_value) = value.get("network") {
        permissions.network_declared = true;
        permissions.network = match network_value.as_str() {
            Some(raw) => {
                parse_network_access(raw).unwrap_or_else(|| NetworkAccess::Unknown(raw.to_string()))
            }
            None => NetworkAccess::Unknown(network_value.to_string()),
        };
    }
    if let Some(exec) = value.get("exec").and_then(serde_json::Value::as_bool) {
        permissions.exec = exec;
        permissions.exec_declared = true;
    }
    if let Some(requires_human) = value
        .get("requires_human")
        .and_then(serde_json::Value::as_bool)
    {
        permissions.requires_human = requires_human;
        permissions.requires_human_declared = true;
    }
    permissions
}

fn parse_string_array(value: Option<&serde_json::Value>) -> Option<Vec<String>> {
    value?
        .as_array()?
        .iter()
        .map(|item| item.as_str().map(ToString::to_string))
        .collect()
}

fn parse_network_access(value: &str) -> Option<NetworkAccess> {
    match value {
        "none" => Some(NetworkAccess::None),
        "read-only" => Some(NetworkAccess::ReadOnly),
        "full" => Some(NetworkAccess::Full),
        _ => None,
    }
}

fn network_access_key(access: &NetworkAccess) -> &str {
    match access {
        NetworkAccess::None => "none",
        NetworkAccess::ReadOnly => "read-only",
        NetworkAccess::Full => "full",
        NetworkAccess::Unknown(raw) => raw.as_str(),
    }
}

#[cfg(test)]
mod tests {
    use skills_copilot_adapters::ClaudeCodeAdapter;
    use skills_copilot_core::{
        AgentAdapter, AgentId, NetworkAccess, PermissionRequest, Scope, SkillState,
    };

    use super::*;

    fn catalog_test_instance(
        agent: AgentId,
        scope: Scope,
        path: &str,
        name: &str,
        state: SkillState,
    ) -> SkillInstance {
        SkillInstance {
            id: format!("{}:{path}", agent.as_str()),
            agent,
            scope,
            project_root: None,
            path: PathBuf::from(path),
            display_path: PathBuf::from(path),
            definition_id: name.to_ascii_lowercase(),
            name: name.to_string(),
            display_name: name.to_string(),
            description: "catalog test fixture".to_string(),
            version: None,
            enabled: matches!(state, SkillState::Loaded | SkillState::Disabled),
            state,
            frontmatter_raw: format!("name: {name}\ndescription: catalog test fixture"),
            body: "body".to_string(),
            scripts: Vec::new(),
            permissions: PermissionRequest::default(),
            fingerprint: String::new(),
            mtime: 0,
            first_seen: 0,
            last_seen: 0,
        }
    }

    #[test]
    fn initializes_and_upserts_skill_records() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let skill = ClaudeCodeAdapter
            .parse(&fixture_path(
                "fixtures/claude-code/personal/valid-summarize/SKILL.md",
            ))
            .expect("skill parses");

        catalog
            .upsert_skill_instance(&skill)
            .expect("skill upserts");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(records.len(), 1);
        assert_eq!(records[0].name, "summarize-changes");
    }

    #[test]
    fn list_skill_records_keeps_same_agent_same_name_different_paths() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let native = catalog_test_instance(
            AgentId::Opencode,
            Scope::AgentGlobal,
            "/tmp/home/.config/opencode/skills/shared-review/SKILL.md",
            "shared-review",
            SkillState::Loaded,
        );
        let duplicate_missing = catalog_test_instance(
            AgentId::Opencode,
            Scope::AgentGlobal,
            "/tmp/home/.agents/skills/shared-review/SKILL.md",
            "shared-review",
            SkillState::Missing,
        );

        catalog
            .upsert_skill_instances(&[duplicate_missing, native])
            .expect("upsert duplicate records");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(records.len(), 2);
        assert!(records
            .iter()
            .any(|record| record.name == "shared-review" && record.state == "loaded"));
        assert!(records
            .iter()
            .any(|record| record.name == "shared-review" && record.state == "missing"));
    }

    #[test]
    fn list_skill_records_filters_pi_historical_markdown_noise() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let real = catalog_test_instance(
            AgentId::Pi,
            Scope::AgentGlobal,
            "/tmp/home/.pi/agent/skills/global-pdf/SKILL.md",
            "global-pdf",
            SkillState::Loaded,
        );
        let root_markdown = catalog_test_instance(
            AgentId::Pi,
            Scope::AgentGlobal,
            "/tmp/home/.pi/agent/skills/root-note.md",
            "root-note",
            SkillState::Missing,
        );
        let root_skill_md = catalog_test_instance(
            AgentId::Pi,
            Scope::AgentGlobal,
            "/tmp/home/.pi/agent/skills/SKILL.md",
            "root-noise",
            SkillState::Missing,
        );
        let reference_skill_md = catalog_test_instance(
            AgentId::Pi,
            Scope::AgentGlobal,
            "/tmp/home/.pi/agent/skills/global-pdf/references/SKILL.md",
            "reference-noise",
            SkillState::Missing,
        );

        catalog
            .upsert_skill_instances(&[real, root_markdown, root_skill_md, reference_skill_md])
            .expect("upsert Pi records");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(records.len(), 1);
        assert_eq!(records[0].name, "global-pdf");
    }

    #[test]
    fn skill_instances_roundtrip_permissions_from_catalog_rows() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let mut skill = ClaudeCodeAdapter
            .parse(&fixture_path(
                "fixtures/claude-code/personal/valid-summarize/SKILL.md",
            ))
            .expect("skill parses");
        skill.scope = Scope::AgentGlobal;
        skill.permissions = PermissionRequest {
            tools: vec!["Bash(git status:*)".to_string(), "Read".to_string()],
            files: vec!["/tmp/report.md".to_string()],
            network: NetworkAccess::ReadOnly,
            network_declared: true,
            exec: true,
            exec_declared: true,
            requires_human: false,
            requires_human_declared: true,
        };

        catalog
            .upsert_skill_instance(&skill)
            .expect("skill upserts");
        let instances = catalog
            .list_skill_instances_for_project_context(None)
            .expect("instances list");

        assert_eq!(instances.len(), 1);
        assert_eq!(instances[0].permissions, skill.permissions);
        assert_eq!(parse_permissions_json("{"), PermissionRequest::default());
        assert_eq!(
            parse_permissions_json(
                r#"{"tools":[],"files":[],"network":"internet","exec":false,"requires_human":true}"#
            ),
            PermissionRequest {
                network: NetworkAccess::Unknown("internet".to_string()),
                network_declared: true,
                exec: false,
                exec_declared: true,
                requires_human: true,
                requires_human_declared: true,
                ..PermissionRequest::default()
            }
        );
        assert_eq!(
            network_access_key(&NetworkAccess::Unknown("raw".to_string())),
            "raw"
        );
    }

    #[test]
    fn mark_missing_except_moves_unseen_records_to_missing_state() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let path_a = fixture_path("fixtures/claude-code/personal/valid-summarize/SKILL.md");
        let path_b = fixture_path("fixtures/claude-code/project/valid-review/SKILL.md");
        let mut inst_a = ClaudeCodeAdapter.parse(&path_a).expect("skill a parses");
        inst_a.scope = Scope::AgentGlobal;
        inst_a.path = path_a.clone();
        let mut inst_b = ClaudeCodeAdapter.parse(&path_b).expect("skill b parses");
        inst_b.scope = Scope::AgentProject;
        inst_b.path = path_b.clone();

        catalog.upsert_skill_instance(&inst_a).expect("upsert a");
        catalog.upsert_skill_instance(&inst_b).expect("upsert b");
        assert_eq!(catalog.list_skill_records().expect("list").len(), 2);

        let scanned_roots = vec![
            path_a.parent().expect("a parent").to_path_buf(),
            path_b.parent().expect("b parent").to_path_buf(),
        ];
        let seen = vec![("agent-global".to_string(), path_a.clone())];
        let marked = catalog
            .mark_missing_except("claude-code", &scanned_roots, &seen)
            .expect("sweep succeeds");
        assert_eq!(marked, 1);

        let records = catalog.list_skill_records().expect("records after sweep");
        let loaded = records
            .iter()
            .find(|r| r.path == path_a)
            .expect("seen record still present");
        let missing = records
            .iter()
            .find(|r| r.path == path_b)
            .expect("unseen record retained");
        assert_eq!(loaded.state, "loaded");
        assert_eq!(missing.state, "missing");
    }

    #[test]
    fn mark_missing_except_leaves_records_outside_scanned_roots_alone() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let scanned_root = fixture_path("fixtures/claude-code/personal");
        let inside_path = fixture_path("fixtures/claude-code/personal/valid-summarize/SKILL.md");
        let outside_path = fixture_path("fixtures/claude-code/project/valid-review/SKILL.md");

        let mut inside = ClaudeCodeAdapter
            .parse(&inside_path)
            .expect("inside parses");
        inside.scope = Scope::AgentGlobal;
        inside.path = inside_path.clone();
        let mut outside = ClaudeCodeAdapter
            .parse(&outside_path)
            .expect("outside parses");
        outside.scope = Scope::AgentProject;
        outside.path = outside_path.clone();

        catalog
            .upsert_skill_instance(&inside)
            .expect("upsert inside");
        catalog
            .upsert_skill_instance(&outside)
            .expect("upsert outside");

        let seen = vec![("agent-global".to_string(), inside_path.clone())];
        let marked = catalog
            .mark_missing_except("claude-code", std::slice::from_ref(&scanned_root), &seen)
            .expect("sweep succeeds");
        assert_eq!(marked, 0, "outside record is not under scanned_root");

        let records = catalog.list_skill_records().expect("records");
        let outside_record = records
            .iter()
            .find(|r| r.path == outside_path)
            .expect("outside record still present");
        assert_eq!(
            outside_record.state, "loaded",
            "records outside any scanned_root are not swept"
        );
    }

    #[test]
    fn tool_global_records_roundtrip_and_are_not_swept_by_adapter_missing_cleanup() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let staging_path = fixture_path("fixtures/claude-code/personal/valid-summarize/SKILL.md");
        let mut tool_global = ClaudeCodeAdapter
            .parse(&staging_path)
            .expect("tool-global skill parses");
        tool_global.id = "tool-global-instance".to_string();
        tool_global.agent = AgentId::ToolGlobal;
        tool_global.scope = Scope::ToolGlobal;
        tool_global.project_root = None;
        tool_global.path = staging_path.clone();
        tool_global.display_path = staging_path.clone();
        tool_global.definition_id = "shared-definition".to_string();

        catalog
            .upsert_skill_instance(&tool_global)
            .expect("tool-global upserts");
        let records = catalog.list_skill_records().expect("records list");
        assert_eq!(records.len(), 1);
        assert_eq!(records[0].agent, "tool-global");
        assert_eq!(records[0].scope, "tool-global");

        let detail = catalog
            .get_skill_detail("tool-global-instance")
            .expect("detail lookup succeeds")
            .expect("detail exists");
        assert_eq!(detail.agent, "tool-global");
        assert_eq!(detail.scope, "tool-global");

        let marked = catalog
            .mark_missing_except(
                "tool-global",
                &[staging_path.parent().expect("parent").to_path_buf()],
                &[],
            )
            .expect("sweep succeeds");
        assert_eq!(marked, 0, "tool-global rows are not adapter-owned");
        let after = catalog
            .get_skill_record("tool-global-instance")
            .expect("record lookup succeeds")
            .expect("record exists");
        assert_eq!(after.state, "loaded");
    }

    #[test]
    fn tool_global_and_agent_global_same_name_remain_distinct_catalog_rows() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let path = fixture_path("fixtures/claude-code/personal/valid-summarize/SKILL.md");
        let mut agent_global = ClaudeCodeAdapter.parse(&path).expect("agent skill parses");
        agent_global.id = "agent-global-same-name".to_string();
        agent_global.agent = AgentId::ClaudeCode;
        agent_global.scope = Scope::AgentGlobal;
        agent_global.path = path.clone();
        agent_global.display_path = path.clone();
        agent_global.definition_id = "shared-definition".to_string();

        let mut tool_global = agent_global.clone();
        tool_global.id = "tool-global-same-name".to_string();
        tool_global.agent = AgentId::ToolGlobal;
        tool_global.scope = Scope::ToolGlobal;
        tool_global.path = path
            .parent()
            .expect("parent")
            .join("tool-global-copy")
            .join("SKILL.md");
        tool_global.display_path = tool_global.path.clone();

        catalog
            .upsert_skill_instances(&[agent_global, tool_global])
            .expect("both rows upsert");
        let records = catalog.list_skill_records().expect("records list");

        assert_eq!(records.len(), 2);
        assert!(records.iter().any(|record| {
            record.id == "agent-global-same-name" && record.agent == "claude-code"
        }));
        assert!(records.iter().any(|record| {
            record.id == "tool-global-same-name" && record.agent == "tool-global"
        }));
        assert_eq!(
            records
                .iter()
                .map(|record| record.definition_id.as_str())
                .collect::<std::collections::HashSet<_>>()
                .len(),
            1,
            "same-name records share a definition for conflict presentation"
        );
    }

    #[test]
    fn project_context_sweep_skips_other_project_records_under_scanned_roots() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let scanned_root = fixture_path("fixtures/claude-code/project")
            .canonicalize()
            .expect("canonical scanned root");
        let current_project = scanned_root.join("project-a");
        let other_project = scanned_root.join("project-b");
        let current_path = fixture_path("fixtures/claude-code/project/valid-review/SKILL.md")
            .canonicalize()
            .expect("canonical current skill");
        let other_path = fixture_path("fixtures/claude-code/project/content-drift-a/SKILL.md")
            .canonicalize()
            .expect("canonical other skill");

        let mut current = ClaudeCodeAdapter
            .parse(&current_path)
            .expect("current parses");
        current.id = "current-project-record".to_string();
        current.scope = Scope::AgentProject;
        current.project_root = Some(current_project.clone());
        current.path = current_path.clone();
        let mut other = ClaudeCodeAdapter.parse(&other_path).expect("other parses");
        other.id = "other-project-record".to_string();
        other.scope = Scope::AgentProject;
        other.project_root = Some(other_project);
        other.path = other_path.clone();

        catalog
            .upsert_skill_instance(&current)
            .expect("upsert current");
        catalog.upsert_skill_instance(&other).expect("upsert other");

        let marked = catalog
            .mark_missing_except_for_project_context(
                "claude-code",
                Some(&current_project),
                std::slice::from_ref(&scanned_root),
                &[],
            )
            .expect("sweep succeeds");

        assert_eq!(marked, 1, "only the current project record is swept");
        let records = catalog.list_skill_records().expect("records");
        let current_record = records
            .iter()
            .find(|record| record.path == current_path)
            .expect("current record");
        let other_record = records
            .iter()
            .find(|record| record.path == other_path)
            .expect("other record");
        assert_eq!(current_record.state, "missing");
        assert_eq!(
            other_record.state, "loaded",
            "other project record under the scanned root is left alone"
        );
    }

    #[test]
    fn refreshes_rule_findings_and_conflict_groups() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "finding-1".to_string(),
                instance_id: Some("inst-1".to_string()),
                definition_id: Some("def-1".to_string()),
                rule_id: "name.collision".to_string(),
                severity: "info".to_string(),
                message: "duplicate name".to_string(),
                suggestion: Some("review duplicates".to_string()),
                created_at: 42,
            }])
            .expect("findings refresh");
        let findings = catalog.list_rule_findings().expect("findings list");
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].rule_id, "name.collision");
        assert_eq!(findings[0].triage_status, "open");
        assert!(!findings[0].triage_key.is_empty());

        catalog
            .refresh_definitions_and_conflicts(
                &[SkillDefinitionDraft {
                    id: "def-1".to_string(),
                    canonical_name: "demo".to_string(),
                    description: "demo skill".to_string(),
                    active_instance: Some("inst-1".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                }],
                &[ConflictGroupDraft {
                    id: "def-1:name-collision".to_string(),
                    definition_id: "def-1".to_string(),
                    reason: "name-collision".to_string(),
                    winner_id: None,
                    instance_ids: vec!["inst-1".to_string(), "inst-2".to_string()],
                }],
            )
            .expect("conflicts refresh");
        let conflicts = catalog.list_conflict_groups().expect("conflicts list");
        assert_eq!(conflicts.len(), 1);
        assert_eq!(conflicts[0].instance_ids.len(), 2);
    }

    #[test]
    fn refresh_rule_findings_rolls_back_on_insert_failure() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        let original = RuleFindingDraft {
            id: "finding-original".to_string(),
            instance_id: Some("inst-1".to_string()),
            definition_id: Some("def-1".to_string()),
            rule_id: "name.collision".to_string(),
            severity: "info".to_string(),
            message: "original finding".to_string(),
            suggestion: Some("keep original".to_string()),
            created_at: 42,
        };
        catalog
            .refresh_rule_findings(std::slice::from_ref(&original))
            .expect("seed finding");

        let duplicate = RuleFindingDraft {
            id: "finding-duplicate".to_string(),
            message: "replacement finding".to_string(),
            ..original
        };
        let result = catalog.refresh_rule_findings(&[duplicate.clone(), duplicate]);
        assert!(result.is_err(), "duplicate IDs should fail the refresh");

        let findings = catalog
            .list_rule_findings()
            .expect("findings list after failed refresh");
        assert_eq!(findings.len(), 1);
        assert_eq!(findings[0].id, "finding-original");
        assert_eq!(findings[0].message, "original finding");
    }

    #[test]
    fn refresh_definitions_and_conflicts_rolls_back_on_insert_failure() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        catalog
            .refresh_definitions_and_conflicts(
                &[SkillDefinitionDraft {
                    id: "def-original".to_string(),
                    canonical_name: "original".to_string(),
                    description: "original definition".to_string(),
                    active_instance: Some("inst-1".to_string()),
                    has_multiple_instances: true,
                    has_conflict: true,
                }],
                &[ConflictGroupDraft {
                    id: "conflict-original".to_string(),
                    definition_id: "def-original".to_string(),
                    reason: "name-collision".to_string(),
                    winner_id: None,
                    instance_ids: vec!["inst-1".to_string(), "inst-2".to_string()],
                }],
            )
            .expect("seed definitions");

        let duplicate = SkillDefinitionDraft {
            id: "def-duplicate".to_string(),
            canonical_name: "duplicate".to_string(),
            description: "duplicate definition".to_string(),
            active_instance: None,
            has_multiple_instances: false,
            has_conflict: false,
        };
        let result =
            catalog.refresh_definitions_and_conflicts(&[duplicate.clone(), duplicate], &[]);
        assert!(result.is_err(), "duplicate IDs should fail the refresh");

        let conflicts = catalog
            .list_conflict_groups()
            .expect("conflicts list after failed refresh");
        assert_eq!(conflicts.len(), 1);
        assert_eq!(conflicts[0].id, "conflict-original");
        assert_eq!(conflicts[0].instance_ids, vec!["inst-1", "inst-2"]);
    }

    #[test]
    fn list_rule_findings_orders_by_severity_rank_then_rule_and_instance() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");

        catalog
            .refresh_rule_findings(&[
                RuleFindingDraft {
                    id: "finding-info".to_string(),
                    instance_id: Some("inst-1".to_string()),
                    definition_id: None,
                    rule_id: "aaa.info".to_string(),
                    severity: "info".to_string(),
                    message: "info".to_string(),
                    suggestion: None,
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "finding-warning".to_string(),
                    instance_id: Some("inst-2".to_string()),
                    definition_id: None,
                    rule_id: "bbb.warn".to_string(),
                    severity: "warning".to_string(),
                    message: "warning".to_string(),
                    suggestion: None,
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "finding-error-b".to_string(),
                    instance_id: Some("inst-2".to_string()),
                    definition_id: None,
                    rule_id: "zzz.error".to_string(),
                    severity: "error".to_string(),
                    message: "error b".to_string(),
                    suggestion: None,
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "finding-warn".to_string(),
                    instance_id: Some("inst-1".to_string()),
                    definition_id: None,
                    rule_id: "bbb.warn".to_string(),
                    severity: "warn".to_string(),
                    message: "warn".to_string(),
                    suggestion: None,
                    created_at: 1,
                },
                RuleFindingDraft {
                    id: "finding-error-a".to_string(),
                    instance_id: Some("inst-1".to_string()),
                    definition_id: None,
                    rule_id: "aaa.error".to_string(),
                    severity: "error".to_string(),
                    message: "error a".to_string(),
                    suggestion: None,
                    created_at: 1,
                },
            ])
            .expect("findings refresh");

        let ids = catalog
            .list_rule_findings()
            .expect("findings list")
            .into_iter()
            .map(|finding| finding.id)
            .collect::<Vec<_>>();

        assert_eq!(
            ids,
            vec![
                "finding-error-a",
                "finding-error-b",
                "finding-warn",
                "finding-warning",
                "finding-info",
            ]
        );
    }

    #[test]
    fn rule_tuning_applies_effective_severity_and_suppression_locally() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let skill = catalog_test_instance(
            AgentId::Codex,
            Scope::AgentGlobal,
            "/tmp/home/.codex/skills/review/SKILL.md",
            "review",
            SkillState::Loaded,
        );
        catalog
            .upsert_skill_instance(&skill)
            .expect("skill upserts");
        catalog
            .refresh_rule_findings(&[RuleFindingDraft {
                id: "finding-1".to_string(),
                instance_id: Some(skill.id.clone()),
                definition_id: Some(skill.definition_id.clone()),
                rule_id: "body.too-long".to_string(),
                severity: "warn".to_string(),
                message: "long body".to_string(),
                suggestion: Some("split references".to_string()),
                created_at: 1,
            }])
            .expect("findings refresh");

        catalog
            .set_rule_severity_override("body.too-long", Some("codex"), None, "info", 10)
            .expect("severity override");
        catalog
            .set_rule_suppression(
                "body.too-long",
                Some("codex"),
                None,
                "accepted local policy",
                Some("fixture note"),
                11,
            )
            .expect("suppression");

        let finding = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");
        assert_eq!(finding.severity, "warn");
        assert_eq!(finding.effective_severity, "info");
        assert_eq!(finding.severity_override.as_deref(), Some("info"));
        assert!(finding.suppressed);
        assert_eq!(
            finding.suppression_reason.as_deref(),
            Some("accepted local policy")
        );
        assert_eq!(finding.suppression_note.as_deref(), Some("fixture note"));
        assert_eq!(finding.rule_tuning_updated_at, Some(11));

        assert!(catalog
            .clear_rule_suppression("body.too-long", Some("codex"), None, 12)
            .expect("clear suppression"));
        let unsuppressed = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");
        assert!(!unsuppressed.suppressed);
        assert_eq!(unsuppressed.effective_severity, "info");
        assert!(catalog
            .clear_rule_severity_override("body.too-long", Some("codex"), None, 13)
            .expect("clear severity"));
        assert!(catalog.list_rule_tuning().expect("tuning list").is_empty());
    }

    #[test]
    fn finding_triage_persists_for_same_finding_identity() {
        let path = std::env::temp_dir().join(format!(
            "skills-copilot-triage-persist-{}-{}.sqlite",
            std::process::id(),
            current_time_for_test()
        ));
        {
            let catalog = Catalog::open(&path).expect("catalog opens");
            catalog.init().expect("schema initializes");
            let skill = catalog_test_instance(
                AgentId::ClaudeCode,
                Scope::AgentGlobal,
                "/tmp/home/.claude/skills/review/SKILL.md",
                "review",
                SkillState::Loaded,
            );
            catalog
                .upsert_skill_instance(&skill)
                .expect("skill upserts");
            catalog
                .refresh_rule_findings(&[RuleFindingDraft {
                    id: "finding-1".to_string(),
                    instance_id: Some(skill.id.clone()),
                    definition_id: Some(skill.definition_id.clone()),
                    rule_id: "body.too-long".to_string(),
                    severity: "warn".to_string(),
                    message: "long body".to_string(),
                    suggestion: Some("split references".to_string()),
                    created_at: 1,
                }])
                .expect("findings refresh");
            let finding = catalog
                .list_rule_findings()
                .expect("findings list")
                .pop()
                .expect("finding exists");
            catalog
                .set_finding_triage(&finding.triage_key, "reviewed", Some("checked"), 10)
                .expect("set triage")
                .expect("current finding key");
        }
        {
            let catalog = Catalog::open(&path).expect("catalog reopens");
            catalog.init().expect("schema initializes again");
            let finding = catalog
                .list_rule_findings()
                .expect("findings list")
                .pop()
                .expect("finding exists");
            assert_eq!(finding.triage_status, "reviewed");
            assert_eq!(finding.triage_note.as_deref(), Some("checked"));
            assert_eq!(finding.triage_updated_at, Some(10));
        }
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn finding_triage_reopens_when_instance_fingerprint_changes() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let mut skill = catalog_test_instance(
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "/tmp/home/.claude/skills/review/SKILL.md",
            "review",
            SkillState::Loaded,
        );
        skill.fingerprint = "fingerprint-a".to_string();
        catalog
            .upsert_skill_instance(&skill)
            .expect("skill upserts");
        let finding = RuleFindingDraft {
            id: "finding-1".to_string(),
            instance_id: Some(skill.id.clone()),
            definition_id: Some(skill.definition_id.clone()),
            rule_id: "fingerprint.changed".to_string(),
            severity: "info".to_string(),
            message: "Skill content fingerprint changed since the previous scan.".to_string(),
            suggestion: Some(
                "Review the skill details before relying on this version.".to_string(),
            ),
            created_at: 1,
        };
        catalog
            .refresh_rule_findings(std::slice::from_ref(&finding))
            .expect("findings refresh");
        let first = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");
        catalog
            .set_finding_triage(&first.triage_key, "ignored", None, 11)
            .expect("set triage");

        skill.fingerprint = "fingerprint-b".to_string();
        catalog
            .upsert_skill_instance(&skill)
            .expect("skill upserts with new fingerprint");
        catalog
            .refresh_rule_findings(&[finding])
            .expect("findings refresh after fingerprint change");
        let reopened = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");

        assert_ne!(reopened.triage_key, first.triage_key);
        assert_eq!(reopened.triage_status, "open");
        assert_eq!(catalog.list_finding_triage().expect("triage list").len(), 1);
    }

    #[test]
    fn finding_triage_reopens_when_definition_instance_set_changes() {
        let catalog = Catalog::in_memory().expect("catalog opens");
        catalog.init().expect("schema initializes");
        let first = catalog_test_instance(
            AgentId::ClaudeCode,
            Scope::AgentGlobal,
            "/tmp/home/.claude/skills/review-a/SKILL.md",
            "review",
            SkillState::Loaded,
        );
        let mut second = catalog_test_instance(
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "/tmp/project/.claude/skills/review/SKILL.md",
            "review",
            SkillState::Loaded,
        );
        second.definition_id = first.definition_id.clone();
        catalog
            .upsert_skill_instances(&[first.clone(), second.clone()])
            .expect("skills upsert");
        let finding = RuleFindingDraft {
            id: "finding-1".to_string(),
            instance_id: None,
            definition_id: Some(first.definition_id.clone()),
            rule_id: "name.collision".to_string(),
            severity: "warn".to_string(),
            message: "runtime sees skill name in multiple locations".to_string(),
            suggestion: Some("compare copies".to_string()),
            created_at: 1,
        };
        catalog
            .refresh_rule_findings(std::slice::from_ref(&finding))
            .expect("findings refresh");
        let original = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");
        catalog
            .set_finding_triage(&original.triage_key, "reviewed", None, 12)
            .expect("set triage");

        let mut third = catalog_test_instance(
            AgentId::ClaudeCode,
            Scope::AgentProject,
            "/tmp/other/.claude/skills/review/SKILL.md",
            "review",
            SkillState::Loaded,
        );
        third.definition_id = first.definition_id.clone();
        catalog.upsert_skill_instance(&third).expect("third upsert");
        catalog
            .refresh_rule_findings(&[finding])
            .expect("findings refresh after member change");
        let reopened = catalog
            .list_rule_findings()
            .expect("findings list")
            .pop()
            .expect("finding exists");

        assert_ne!(reopened.triage_key, original.triage_key);
        assert_eq!(reopened.triage_status, "open");
    }

    fn current_time_for_test() -> u128 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock")
            .as_nanos()
    }

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
