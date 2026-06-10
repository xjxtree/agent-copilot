CREATE TABLE IF NOT EXISTS finding_triage (
    triage_key     TEXT PRIMARY KEY,
    triage_context TEXT NOT NULL,
    status         TEXT NOT NULL CHECK (status IN ('reviewed', 'ignored', 'needs-follow-up')),
    note           TEXT,
    updated_at     INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_finding_triage_status
    ON finding_triage(status, updated_at);
