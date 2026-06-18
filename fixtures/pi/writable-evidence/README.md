# Pi Writable Evidence Harness Fixtures

These fixtures began as V2.36 disposable Pi writable research inputs and were promoted by V2.37 into the guarded native global/project/package toggle slice. V2.94 later added guarded compatibility toggles and native-root direct install in code/tests. These fixtures still intentionally do **not** define Pi package install/remove, `.agents` direct skill-file installs, arbitrary package mutation, script execution, AI auto-write, or credential persistence.

The harness models guarded toggle cases using temp-dir copies only:

- `home/.pi/agent/skills/global-evidence-toggle/SKILL.md` models a global Pi skill that can be disabled and re-enabled by the V2.37 guarded writer.
- `project/.pi/skills/project-evidence-toggle/SKILL.md` models a trusted project-level guarded toggle.
- `project/packages/app/.pi/skills/package-evidence-toggle/SKILL.md` models a package/nested project guarded toggle plus package resource filtering.
- `config/pi-settings.enabled.json` is the baseline candidate settings file.
- `config/pi-settings.disabled-global.json` models global skill disable state.
- `config/pi-settings.disabled-project-package.json` models project and package skill disable state.
- `config/pi-settings.package-filter-disabled.json` models package-provided skill filtering.
- `config/pi-settings.invalid-json.json` confirms invalid config is treated as evidence failure input, not silently repaired.
- `config/pi-settings.untrusted-project.json` models a trust gate that must block project/package writes.
- `rollback/pi-settings.before.json` and `rollback/pi-settings.after-disable.json` model snapshot/rollback comparison inputs.

The verifier `scripts/verify-pi-writable-evidence-fixtures.mjs` copies this directory to a temporary path, mutates only that copy, validates disable/re-enable/rollback behavior in the copied configs, and removes the temp directory. It must not read or write real `$HOME`, real `~/.pi`, credentials, provider settings, or skill content scripts.
