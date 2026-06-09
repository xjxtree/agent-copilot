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
- `service.status.supported_methods` remains unchanged; `catalog.scanAll` is still the single multi-agent scan method.
- Fixture and smoke coverage must keep opencode visible for global no-project scans, visible for project scans after project context is active, and rejected for write toggles.

V2.9 local export note:

- `skill.exportBundle.response.json` includes local response paths, but the bundle manifest itself must keep reproducible metadata path-relative.
- Export fixtures cover directory-form bundles only; signed or zipped distribution artifacts are intentionally out of scope.

V2.9 tool-global import note:

- `catalog.importSkill` imports a local directory containing `SKILL.md` into the app-controlled tool-global staging area and returns the imported `SkillRecord`, `instance_id`, `staging_path`, import findings, and audit summary.
- Imported tool-global content is read-only preview content; installing or writing to an agent config remains a separate confirmed adapter write flow.
- GitHub repo import is explicitly deferred in the service contract. The `catalog.importSkill.github.error.*` fixtures document the unsupported path; callers must provide a local `source_path` after any user-controlled clone or unpack step.
