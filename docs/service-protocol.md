# Service Protocol

The native app talks to the Rust service through typed JSON request/response
messages over stdio. `crates/service/src/protocol.rs` is the source of truth for
method names and typed payloads; this document is the human-readable contract
index.

## Runtime Shape

Request:

```json
{"id":"req-1","method":"catalog.listSkills","params":{}}
```

Success response:

```json
{"id":"req-1","ok":true,"result":[]}
```

Error response:

```json
{"id":"req-1","ok":false,"error":{"code":"unknown_method","message":"unknown method: x"}}
```

The stdio transport may change in the future, but method names, payloads,
fixtures, and stable error codes must remain synchronized with protocol drift
verification.

## Protocol Rules

- UI shells must call service methods instead of importing scanner/catalog
  internals.
- Provider calls require preview, redaction, destination visibility, and
  explicit confirmation.
- Skill scripts remain default-denied.
- App-local metadata writes must be redacted.
- Adapter config writes must use the guarded paths documented in
  `docs/adapters/agent-adapters.md`.
- Service method changes must update fixtures and pass
  `pnpm verify:service-protocol-drift`.

## Methods

| Method | Mutates local state |
| --- | --- |
| `app.version` | No |
| `app.stateSnapshot` | No |
| `service.status` | No |
| `adapter.listCapabilities` | No |
| `adapter.listDiagnostics` | No |
| `evidence.previewMcpServers` | No |
| `evidence.piWritableHarness` | No |
| `llm.status` | No |
| `llm.listProviderProfiles` | No |
| `llm.saveProviderProfile` | Yes, writes provider metadata and Keychain secret when supplied |
| `llm.deleteProviderProfile` | Yes, updates app-local provider metadata |
| `llm.testProviderConnection` | Yes, records minimal redacted call metadata |
| `llm.previewPrompt` | No |
| `llm.confirmPromptAndSend` | Yes, records redacted prompt-run metadata |
| `llm.listPromptRuns` | No |
| `llm.prepareAction` | No |
| `llm.prepareSkillAnalysis` | No |
| `llm.providerObservability` | No |
| `llm.listModelTaskMatches` | No |
| `llm.recordModelTaskMatch` | Yes, writes app-local redacted metadata only |
| `llm.deleteModelTaskMatch` | Yes, updates app-local redacted metadata only |
| `script.previewExecution` | No |
| `script.execute` | No |
| `project.getContext` | No |
| `project.setContext` | Yes, writes app state |
| `project.clearContext` | Yes, writes app state |
| `project.validateContext` | No |
| `catalog.listSkills` | No |
| `catalog.getSkill` | No |
| `catalog.analysis` | No |
| `catalog.listFindings` | No |
| `catalog.listFindingTriage` | No |
| `catalog.setFindingTriage` | Yes, writes app-local triage metadata only |
| `catalog.clearFindingTriage` | Yes, clears app-local triage metadata only |
| `catalog.listConflicts` | No |
| `catalog.importSkill` | Yes, writes app-controlled staging/catalog only |
| `catalog.scanAll` | Yes, refreshes catalog |
| `catalog.scanClaude` | Yes, refreshes catalog |
| `skill.exportBundle` | Yes, writes app-controlled export files |
| `skill.install` | Yes, after confirmation |
| `skill.listEvents` | No |
| `skill.lifecycleTimeline` | No |
| `config.toggleSkill` | Yes, writes agent config |
| `config.readClaudeSettings` | No |
| `config.saveClaudeSettings` | Yes, writes Claude settings and rescans |
| `snapshot.list` | No |
| `snapshot.listAgentConfig` | No |
| `snapshot.previewRollback` | No |
| `snapshot.rollback` | Yes, writes agent config snapshot content and rescans |
| `trace.importLocal` | Yes, writes app-data metadata |
| `trace.listImports` | No |
| `trace.deleteImport` | Yes, updates app-data metadata |
| `session.previewLocalSessions` | No |
| `session.reviewAgentSkillUse` | Yes, writes app-data metadata |
| `session.listSkillReviews` | No |
| `session.deleteSkillReview` | Yes, updates app-data metadata |
| `routing.accuracyDashboard` | No |
| `task.checkReadiness` | No |
| `task.rankSkillRoutes` | No |
| `task.compareAgentReadiness` | No |
| `task.buildCockpit` | No |
| `task.listBenchmarks` | No |
| `task.saveBenchmark` | Yes, writes app-local benchmark metadata |
| `task.deleteBenchmark` | Yes, updates app-local benchmark metadata |
| `task.evaluateBenchmarks` | No |
| `task.saveRoutingBaseline` | Yes, writes app-local routing baseline metadata |
| `task.detectRoutingRegression` | No |
| `analysis.scoreSkillQuality` | No |
| `analysis.detectStaleDrift` | No |
| `knowledge.search` | No |
| `knowledge.groupSimilarSkills` | No |
| `knowledge.buildCapabilityTaxonomy` | No |
| `knowledge.buildLocalSkillMap` | No |
| `workspace.checkReadiness` | No |
| `remediation.plan` | No |
| `remediation.previewDrafts` | No |
| `remediation.previewImpact` | No |
| `remediation.batchReview` | No |
| `remediation.listHistory` | No |
| `remediation.recordHistory` | Yes, writes app-local remediation history metadata |
| `remediation.deleteHistory` | Yes, updates app-local remediation history metadata |
| `rules.listTuning` | No |
| `rules.setSeverityOverride` | Yes, writes app-local rule tuning metadata only |
| `rules.clearSeverityOverride` | Yes, clears app-local rule tuning metadata only |
| `rules.setSuppression` | Yes, writes app-local rule tuning metadata only |
| `rules.clearSuppression` | Yes, clears app-local rule tuning metadata only |
| `batch.previewSkillToggles` | No |
| `batch.applySkillToggles` | Yes, writes through verified per-agent toggle paths after confirmation |
| `cleanup.listQueue` | No |
| `cleanup.planGuidedFlow` | No |
| `cleanup.recordGuidedStep` | Yes, writes app-data metadata only |
| `comparison.listCrossAgent` | No |
| `report.exportLocal` | Yes, writes app-controlled redacted report files |

## Environment Overrides

| Variable | Purpose |
| --- | --- |
| `SKILLS_COPILOT_APP_DATA_DIR` | Override app data/catalog directory for tests and screenshots |
| `SKILLS_COPILOT_HOME` | Override user home used by adapters |
| `SKILLS_COPILOT_PROJECT_CWD` | Provide current project working directory |
| `SKILLS_COPILOT_PROJECT_ROOT` | Provide project safety root |
| `SKILLS_COPILOT_CLAUDE_EXTRA_ROOTS` | Add fixture Claude skill roots |
| `SKILLS_COPILOT_SERVICE_PATH` | Override sidecar path for local debugging |
| `CODEX_HOME` | Override Codex user config home when safe for the active context |

## Fixtures

Protocol fixtures live under `fixtures/service-protocol/`. Each supported method
must have dispatch coverage, status fixture coverage, and request/response
fixture coverage where applicable.
