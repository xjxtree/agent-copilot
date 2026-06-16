use rusqlite::Connection;

use super::CatalogError;

const INITIAL_SCHEMA: &str = include_str!("migrations/0001_initial.sql");
const MIGRATION_0002: &str = include_str!("migrations/0002_add_display_path.sql");
const MIGRATION_0003: &str = include_str!("migrations/0003_add_rule_findings.sql");
const MIGRATION_0004: &str = include_str!("migrations/0004_add_finding_triage.sql");
const MIGRATION_0005: &str = include_str!("migrations/0005_add_rule_tuning.sql");

pub(crate) fn init_schema(conn: &Connection) -> Result<(), CatalogError> {
    conn.execute_batch(INITIAL_SCHEMA)?;
    apply_column_migration_if_missing(conn, "skill_instance", "display_path", MIGRATION_0002)?;
    conn.execute_batch(MIGRATION_0003)?;
    ensure_rule_finding_triage_columns(conn)?;
    conn.execute_batch(MIGRATION_0004)?;
    conn.execute_batch(MIGRATION_0005)?;
    Ok(())
}

fn apply_column_migration_if_missing(
    conn: &Connection,
    table: &str,
    column: &str,
    migration_sql: &str,
) -> Result<(), CatalogError> {
    if !table_has_column(conn, table, column)? {
        conn.execute_batch(migration_sql)?;
    }
    Ok(())
}

fn ensure_rule_finding_triage_columns(conn: &Connection) -> Result<(), CatalogError> {
    if !table_has_column(conn, "rule_finding", "triage_key")? {
        conn.execute(
            "ALTER TABLE rule_finding ADD COLUMN triage_key TEXT NOT NULL DEFAULT ''",
            [],
        )?;
    }
    if !table_has_column(conn, "rule_finding", "triage_context")? {
        conn.execute(
            "ALTER TABLE rule_finding ADD COLUMN triage_context TEXT NOT NULL DEFAULT ''",
            [],
        )?;
    }
    Ok(())
}

fn table_has_column(conn: &Connection, table: &str, column: &str) -> Result<bool, CatalogError> {
    let mut stmt = conn.prepare(&format!("PRAGMA table_info({table})"))?;
    let rows = stmt.query_map([], |row| row.get::<_, String>(1))?;
    for row in rows {
        if row? == column {
            return Ok(true);
        }
    }
    Ok(false)
}
