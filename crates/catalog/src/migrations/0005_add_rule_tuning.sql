CREATE TABLE IF NOT EXISTS rule_tuning (
    rule_id             TEXT NOT NULL,
    agent               TEXT NOT NULL DEFAULT '',
    scope               TEXT NOT NULL DEFAULT '',
    severity_override   TEXT CHECK (
        severity_override IS NULL
        OR severity_override IN ('critical', 'error', 'warn', 'warning', 'info')
    ),
    suppression_reason  TEXT,
    suppression_note    TEXT,
    updated_at          INTEGER NOT NULL,
    PRIMARY KEY (rule_id, agent, scope),
    CHECK (severity_override IS NOT NULL OR suppression_reason IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_rule_tuning_rule
    ON rule_tuning(rule_id, agent, scope);
