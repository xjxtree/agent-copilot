CREATE TABLE IF NOT EXISTS rule_finding (
    id            TEXT PRIMARY KEY,
    instance_id   TEXT,
    definition_id TEXT,
    rule_id       TEXT NOT NULL,
    severity      TEXT NOT NULL,
    message       TEXT NOT NULL,
    suggestion    TEXT,
    created_at    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rule_finding_instance
    ON rule_finding(instance_id);

CREATE INDEX IF NOT EXISTS idx_rule_finding_definition
    ON rule_finding(definition_id);
