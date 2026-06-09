# Service Protocol Fixtures

These fixtures are the shared contract examples for native macOS and future Windows/Linux UI shells.

Rules:

- `*.request.json` must decode as `ServiceRequest`.
- `*.response.json` must decode as `ServiceResponse`.
- Fixture methods should stay additive and match `service.status.supported_methods`.
- `service.status.response.json` must include the current `protocol_version`.
- Use temporary paths in examples; do not encode a contributor's real home directory.

V2.5 opencode note:

- `catalog.scanAll.response.json` includes the three-agent response shape for Claude Code, Codex, and read-only opencode native roots.
- V2.5 did not add a separate opencode scan method; `catalog.scanAll` remained the single multi-agent scan method at that stage.
- Fixture and smoke coverage must keep opencode visible for global no-project scans, visible for project scans after project context is active, and rejected for write toggles.

V2.9 local export note:

- `skill.exportBundle.response.json` includes local response paths, but the bundle manifest itself must keep reproducible metadata path-relative.
- Export fixtures cover directory-form bundles only; signed or zipped distribution artifacts are intentionally out of scope.

V2.9 tool-global import note:

- `catalog.importSkill` imports a local directory containing `SKILL.md` into the app-controlled tool-global staging area and returns the imported `SkillRecord`, `instance_id`, `staging_path`, import findings, and audit summary.
- Imported tool-global content is read-only preview content; installing or writing to an agent config remains a separate confirmed adapter write flow.
- GitHub repo import is explicitly deferred in the service contract. The `catalog.importSkill.github.error.*` fixtures document the unsupported path; callers must provide a local `source_path` after any user-controlled clone or unpack step.

V2.11 adapter capability matrix note:

- `adapter.listCapabilities.response.json` is the direct capability matrix fixture for Claude Code, Codex, opencode, Pi, Hermes, and OpenClaw.
- `service.status.response.json` and `app.stateSnapshot.response.json` include `adapter_capabilities` so native UI shells can render adapter status without guessing from agent names.
- The matrix is descriptive for unsupported write paths: opencode is writable for native roots after V2.12 validation, Pi is read-only after V2.13 validation, OpenClaw is read-only after V2.16 validation, and Hermes is read-only after V2.17 validation while unsupported write/install paths stay blocked.

V2.13 Pi blocker note:

- `adapter.listCapabilities` and `service.status` fixtures keep Pi as read-only scan and blocked config/snapshot/install; no Pi writable claim is made.
- Pi fixtures under `fixtures/pi/` are read-only parser/scan contract samples until disposable local `agentDir` + project round-trip verifies mutation, rollback, and trust behavior.
- `config.toggleSkill` and install UX for Pi must remain disabled in the matrix until Pi write evidence is completed.

V2.17 Hermes read-only note:

- Hermes is `read-only` / `verified-read-only` in `adapter.listCapabilities`, `service.status`, and `app.stateSnapshot`.
- Hermes generic project scan remains blocked; active/profile home is the only first-slice scope, with `skills.external_dirs` reserved for future explicit external roots.
- The Hermes fixture directory contains active-home scanner contract fixtures plus evidence-only cron samples.
- `catalog.scanAll` includes Hermes after the read-only scanner implementation lands.

OpenClaw read-only scanner note:

- OpenClaw is `read-only` / supported scan in `adapter.listCapabilities`, `service.status`, and `app.stateSnapshot`.
- OpenClaw project scan is workspace-scoped only for confirmed OpenClaw workspace roots; arbitrary repo roots must not be inferred as OpenClaw projects.
- The OpenClaw fixture directory contains read-only scanner contract fixtures plus evidence samples.
- `catalog.scanAll` includes OpenClaw after V2.16.

V2.18 cross-agent analysis note:

- `catalog.analysis` is a read-only service method and is also embedded in `app.stateSnapshot.analysis`.
- Analysis groups duplicate names, canonical-name overlap, source-path overlap, enabled-state mismatch, malformed/broken rows, and same-agent precedence/shadowing where adapter evidence supports it.
- The analysis fixture must not imply writes, config changes, CLI calls, execution, or unsupported-root inference.

V2.12 opencode writable note:

- V2.12 updates opencode capability fixtures to writable after code implementation plus disposable local evidence verification completed.
- Regression coverage includes exact `permission.skill` patch, re-enable, snapshot/rollback, install, guarded UI/service gating, fixture HOME writes, and real HOME isolation.
