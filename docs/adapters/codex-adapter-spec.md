# Codex Adapter Spec

This document records the current Codex adapter contract.

## Scan Roots

- User `$CODEX_HOME/skills` and `$HOME/.agents/skills` where applicable.
- Project `.agents/skills` discovered from the selected working directory up to
  the project root.
- Local plugin marketplace roots and `/etc/codex/skills` when present, as
  read-only diagnostics.
- Project `.codex/config.toml` as read-only diagnostics.

## Skill Format

- A skill is a directory containing `SKILL.md`.
- Required frontmatter: `name`, `description`.
- Optional directories such as `scripts/`, `references/`, `assets/`, and
  `agents/` are metadata only; importing or scanning must not execute scripts.
- Missing required frontmatter creates a broken record rather than aborting the
  scan.

## Writable Scope

- Toggles may patch only the verified user config override for native
  `.agents/skills` instances.
- The adapter uses absolute `SKILL.md` paths for disabled entries.
- Re-enable removes matching disabled entries and preserves non-target config.

## Blocked Scope

- Do not write project `.codex/config.toml`.
- Do not write plugin, admin, system, or compatibility roots.
- Do not fetch marketplace/network skill indexes.
- Do not add hooks, MCP config writes, script execution, credentials, cloud
  sync, or telemetry through the adapter.

## Fixtures

Codex fixtures live under `fixtures/codex/` and cover valid and malformed skill
frontmatter plus read-only root behavior.
