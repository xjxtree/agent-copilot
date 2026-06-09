# Hermes Evidence Fixtures

These fixtures document local Hermes evidence only. P0 evidence on 2026-06-10 promoted Hermes to a read-only scanner candidate, but these files are not parser contracts until the scanner fixtures are explicitly added.

Evidence status:

- Official Hermes Agent docs and read-only macmini checks confirm first-class skills under active Hermes home `skills/**/SKILL.md`.
- Hermes has no confirmed generic project-level skills. Do not scan arbitrary project roots; model `skills.external_dirs` only as future explicit external roots.
- The only concrete schema-like clue is cron job management under `<hermes-home>/cron/jobs.json`.
- Cron `enabled: false` is service-task evidence only and must not be treated as skill enable/disable semantics.

`service-evidence/cron-jobs.sample.json` is a minimal evidence sample for maintainer discussion. It is not a parser contract, and cron jobs should not be mapped to `SkillInstance` in the first Hermes adapter slice.
