# Pi Writable Evidence Harness Fixtures

These fixtures are V2.36 evidence-only inputs for disposable Pi writable research. They intentionally do **not** define production writable support, and the app must continue to report Pi toggle/install as blocked until rollback-safe evidence is validated and promoted separately.

The harness models candidate write cases using temp-dir copies only:

- `home/.pi/agent/skills/global-evidence-toggle/SKILL.md` models a global Pi skill that could be disabled and re-enabled by a future verified config writer.
- `project/.pi/skills/project-evidence-toggle/SKILL.md` models a trusted project-level skill toggle candidate.
- `project/packages/app/.pi/skills/package-evidence-toggle/SKILL.md` models a package/nested project skill candidate plus package resource filtering.
- `config/pi-settings.enabled.json` is the baseline candidate settings file.
- `config/pi-settings.disabled-global.json` models global skill disable state.
- `config/pi-settings.disabled-project-package.json` models project and package skill disable state.
- `config/pi-settings.package-filter-disabled.json` models package-provided skill filtering.
- `config/pi-settings.invalid-json.json` confirms invalid config is treated as evidence failure input, not silently repaired.
- `config/pi-settings.untrusted-project.json` models a trust gate that must block project/package writes.
- `rollback/pi-settings.before.json` and `rollback/pi-settings.after-disable.json` model snapshot/rollback comparison inputs.

The verifier `scripts/verify-pi-writable-evidence-fixtures.mjs` copies this directory to a temporary path, mutates only that copy, validates disable/re-enable/rollback behavior in the copied configs, and removes the temp directory. It must not read or write real `$HOME`, real `~/.pi`, credentials, provider settings, or skill content scripts.
