# Service Protocol Brief

## Scope

Create the first product UI boundary between the native macOS shell and Rust core.

## Decisions

- Use a short-lived stdio sidecar for V1 bootstrap.
- Support `service.status`, `catalog.listSkills`, `catalog.getSkill`, `catalog.listFindings`, `catalog.listConflicts`, `catalog.scanAll`, `catalog.scanClaude`, `config.toggleSkill`, `config.readClaudeSettings`, `config.saveClaudeSettings`, `snapshot.list`, `snapshot.previewRollback`, `snapshot.rollback`, `llm.status`, `llm.prepareAction`, `script.previewExecution`, and `script.execute`.
- Keep native macOS UI code behind the service client only; scan, reload, detail, findings, conflicts, snapshots, toggle, settings read/write, preview, and rollback all call typed service methods.

## Acceptance

- Rust service crate builds and has unit coverage for status, unknown method errors, and missing write params.
- The sidecar can be bundled into the SwiftPM macOS app.
- Native macOS app can decode `SkillRecord[]`, `SkillDetailRecord`, `RuleFindingRecord[]`, `ConflictGroupRecord[]`, `ConfigSnapshotRecord[]`, `ScanResult`, `ConfigDocumentRecord`, and `SnapshotRollbackPreviewRecord` through the service client.
