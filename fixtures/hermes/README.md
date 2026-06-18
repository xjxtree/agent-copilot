# Hermes Evidence Fixtures

These fixtures document local Hermes evidence, the V2.17 read-only scanner
contract, and the V2.95 native-root install boundary.

P0 evidence on 2026-06-10 promoted Hermes to a read-only scanner candidate. V2.17 adds a filesystem-only scanner contract for active/profile Hermes home `skills/**/SKILL.md`. V2.95 allows confirmed local ToolGlobal `SKILL.md` copies into native `~/.hermes/skills` only. Cron and config samples remain evidence-only and must not be used as writable skill toggle contracts.

Evidence status:

- Official Hermes Agent docs and read-only macmini checks confirm first-class skills under active Hermes home `skills/**/SKILL.md`.
- Hermes has no confirmed generic project-level skills. Do not scan arbitrary project roots; model `skills.external_dirs` only as future explicit external roots.
- The native install target is `~/.hermes/skills`; external roots remain
  read-only and are not install targets.
- The only concrete schema-like clue is cron job management under `<hermes-home>/cron/jobs.json`.
- Cron `enabled: false` is service-task evidence only and must not be treated as skill enable/disable semantics.

`service-evidence/cron-jobs.sample.json` is a minimal evidence sample for maintainer discussion. It is not a parser contract, and cron jobs should not be mapped to `SkillInstance` in the first Hermes adapter slice.

Scanner fixture scope:

- `active-home/.hermes/skills/nested/research-brief/SKILL.md` covers nested active-home skill discovery.
- `active-home/.hermes/skills/broken/malformed-metadata/SKILL.md` confirms malformed YAML returns a broken skill record instead of aborting the scan.
- `active-home/.hermes/.env`, `active-home/.hermes/auth.json`, `active-home/.hermes/cron/jobs.json`, and `active-home/.hermes/logs/session.log` confirm the scanner root stays scoped to `skills/` and does not read secrets, cron content, or logs.

The V2.17 scanner must not infer arbitrary repository roots as Hermes projects, must not call `hermes`, and must not write or patch Hermes config. V2.95 native installs must use the app's local ToolGlobal copy path and must not call `hermes skills install`, fetch hub/URL/tap sources, patch `external_dirs`, or toggle per-platform state.

## Read-only scanner verifier checklist

- [x] Confirm Hermes scan scope is filesystem-only and does not invoke `hermes` CLI for ordinary catalog scans.
- [x] Confirm scan root is limited to active/profile Hermes home `skills/**/SKILL.md`.
- [x] Confirm generic project roots and `skills.external_dirs` are not scanned in the first slice.
- [x] Confirm secrets, `auth.json`, cron content, and logs are outside the scan root.
- [x] Confirm scanner flows do not install, toggle, or write Hermes config.
- [x] Confirm V2.95 native install is limited to confirmed local ToolGlobal
  `SKILL.md` copy into `~/.hermes/skills`.
