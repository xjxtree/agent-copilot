use std::{
    collections::{HashMap, HashSet},
    path::{Path, PathBuf},
};

use rusqlite::{params, Connection, OpenFlags, Row};
use serde::Serialize;
use skills_copilot_core::{
    AgentId, NetworkAccess, PermissionRequest, Scope, SkillInstance, SkillState,
};
use thiserror::Error;

pub const INITIAL_SCHEMA: &str = include_str!("migrations/0001_initial.sql");
pub const MIGRATION_0002: &str = include_str!("migrations/0002_add_display_path.sql");
pub const MIGRATION_0003: &str = include_str!("migrations/0003_add_rule_findings.sql");

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
    pub instance_id: Option<String>,
    pub definition_id: Option<String>,
    pub rule_id: String,
    pub severity: String,
    pub message: String,
    pub suggestion: Option<String>,
    pub created_at: i64,
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
        self.conn.execute_batch(INITIAL_SCHEMA)?;
        // Migration 0002 is not idempotent (ALTER TABLE ADD COLUMN fails if
        // the column already exists). Ignore the "duplicate column" error so
        // init() is safe to call on every startup.
        match self.conn.execute_batch(MIGRATION_0002) {
            Ok(()) => {}
            Err(rusqlite::Error::SqliteFailure(_, ref msg))
                if msg.as_ref().is_some_and(|m| m.contains("duplicate column")) => {}
            Err(e) => return Err(CatalogError::Sqlite(e)),
        }
        self.conn.execute_batch(MIGRATION_0003)?;
        self.canonicalize_legacy_paths()?;
        Ok(())
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
            ) {
                instances.push(instance);
            }
        }
        Ok(instances)
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
            ) {
                records.push(record);
            }
        }
        Ok(records)
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

    pub fn refresh_rule_findings(&self, findings: &[RuleFindingDraft]) -> Result<(), CatalogError> {
        self.conn.execute("DELETE FROM rule_finding", [])?;
        for finding in findings {
            self.conn.execute(
                "INSERT INTO rule_finding (
                    id, instance_id, definition_id, rule_id, severity, message, suggestion, created_at
                 )
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                params![
                    finding.id,
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
    }

    pub fn list_rule_findings(&self) -> Result<Vec<RuleFindingRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, instance_id, definition_id, rule_id, severity, message, suggestion, created_at
             FROM rule_finding
             ORDER BY
                CASE severity
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
            Ok(RuleFindingRecord {
                id: row.get(0)?,
                instance_id: row.get(1)?,
                definition_id: row.get(2)?,
                rule_id: row.get(3)?,
                severity: row.get(4)?,
                message: row.get(5)?,
                suggestion: row.get(6)?,
                created_at: row.get(7)?,
            })
        })?;
        let mut findings = Vec::new();
        for row in rows {
            findings.push(row?);
        }
        Ok(findings)
    }

    pub fn refresh_definitions_and_conflicts(
        &self,
        definitions: &[SkillDefinitionDraft],
        conflicts: &[ConflictGroupDraft],
    ) -> Result<(), CatalogError> {
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
             ORDER BY created_at DESC",
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

    pub fn list_all_config_snapshots(&self) -> Result<Vec<ConfigSnapshotRecord>, CatalogError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent, scope, target, content, reason, created_at
             FROM config_snapshot
             ORDER BY created_at DESC",
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

pub fn migration_count() -> usize {
    3
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
    use skills_copilot_core::{AgentAdapter, AgentId, NetworkAccess, PermissionRequest, Scope};

    use super::*;

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

    fn fixture_path(relative: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(relative)
    }
}
