# OpenClaw Evidence Fixtures

These fixtures document local OpenClaw evidence only. They are not adapter implementation inputs.

P0 evidence on 2026-06-10 promoted OpenClaw to a read-only scanner candidate. The samples below are useful for maintainer discussion, but they are not scanner/parser, install, toggle, or rollback contracts until the scanner fixture set is explicitly added.

Evidence status:

- Local OpenClaw security-scan docs list candidate skill roots and expect skill directories containing `SKILL.md`.
- The same docs extract skill names from YAML frontmatter `name:` and fall back to the directory basename.
- Local plugin docs patch `openclaw.json` plugin fields, but plugin `enabled` is not verified as skill enable/disable semantics.
- A local `$HOME/.openclaw/openclaw.json` exists, but it was not copied because it may contain credentials and is not strict JSON.

`skill-evidence/sample-openclaw-skill/SKILL.md` is a future parser candidate only if maintainers confirm the local-doc evidence as canonical.

`config/openclaw.plugins.redacted.sample.json` is a minimal plugin evidence sample only. It is not a writable skill toggle contract.
