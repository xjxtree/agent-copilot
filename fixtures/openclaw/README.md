# OpenClaw Evidence Fixtures

These fixtures document local OpenClaw evidence, the V2.16 read-only scanner
contract, and the V2.96 native/workspace install boundary.

P0 evidence on 2026-06-10 promoted OpenClaw to a read-only scanner candidate.
V2.16 adds a filesystem-only scanner contract for parsing `SKILL.md`
directories. V2.96 allows confirmed local ToolGlobal `SKILL.md` copies into
native `~/.openclaw/skills` and confirmed workspace `<workspace>/skills`. The
config sample remains evidence-only and must not be used as a writable skill
toggle contract.

Evidence status:

- Local OpenClaw security-scan docs list candidate skill roots and expect skill directories containing `SKILL.md`.
- OpenClaw project-like scope is workspace-scoped only: `<workspace>/skills` and `<workspace>/.agents/skills`. Do not infer arbitrary repository roots or `.openclaw/skills` project roots.
- Install scope is narrower than scan scope: V2.96 writes only
  `~/.openclaw/skills` and confirmed `<workspace>/skills`; `.agents` roots
  remain scan-only.
- The same docs extract skill names from YAML frontmatter `name:` and fall back to the directory basename.
- Local plugin docs patch `openclaw.json` plugin fields, but plugin `enabled` is not verified as skill enable/disable semantics.
- A local `$HOME/.openclaw/openclaw.json` exists, but it was not copied because it may contain credentials and is not strict JSON.

Scanner fixture scope:

- `skill-evidence/sample-openclaw-skill/SKILL.md` covers a valid OpenClaw skill directory.
- `user-home/.openclaw/skills/managed-global/SKILL.md` mirrors managed global OpenClaw skills.
- `user-home/.agents/skills/personal-shared/SKILL.md` mirrors the documented shared personal skill root.
- `user-home/.openclaw/workspace/skills/workspace-override/SKILL.md` mirrors `<workspace>/skills`.
- `user-home/.openclaw/workspace/.agents/skills/workspace-agents/SKILL.md` mirrors `<workspace>/.agents/skills`.
- `broken/missing-name/SKILL.md` confirms the read-only scanner falls back to the containing directory name.
- `broken/missing-description/SKILL.md` confirms missing descriptions do not block read-only discovery.

The V2.16 scanner must not infer arbitrary repository roots as OpenClaw
workspaces, must not call `openclaw`, and must not write or patch
`openclaw.json`.

The V2.96 install path must not use `.agents` direct installs, `skills.entries`
writes, ClawHub, Git, update, verify, workshop, or network-backed operations.

`config/openclaw.plugins.redacted.sample.json` is a minimal plugin evidence sample only. It is not a writable skill toggle contract.

## Read-only scanner verifier checklist

- [x] Confirm OpenClaw scan scope is filesystem-only and does not invoke `openclaw` CLI for ordinary catalog scans.
- [x] Confirm workspace project scan is limited to `<workspace>/skills` and `<workspace>/.agents/skills` and does not infer arbitrary repo roots.
- [x] Confirm `<workspace>/.openclaw/skills` is not used as a project inference root.
- [x] Confirm no install/toggle/writable path is used by scanner flows.
- [x] Confirm OpenClaw scan fixtures include documented global/project roots, missing-name fallback, missing description, and workspace-boundary checks.

## V2.96 install-only checklist

- [x] Confirm native install target is only `~/.openclaw/skills`.
- [x] Confirm workspace install target is only confirmed `<workspace>/skills`.
- [x] Confirm `.agents` roots remain scan-only and are not direct install targets.
- [x] Confirm config toggles, `skills.entries` writes, ClawHub, Git, update,
  verify, workshop, and network-backed operations remain blocked.
