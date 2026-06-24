# opencode Adapter Spec

This document records the current opencode adapter contract.

## Scan Roots

- Native global and project `.opencode/skills` roots.
- Official `.claude/skills` and `.agents/skills` compatibility roots.
- Configured local `skills.paths` roots from readable JSON/JSONC config.

`skills.paths` roots are scan-only. Paths are expanded relative to the declaring
config scope, canonicalized, deduped, and bounded to the expected project/user
context.

## Skill Format

- A skill is a directory containing `SKILL.md`.
- Required frontmatter: `name`, `description`.
- The `name` should match the containing directory. Mismatch creates a broken
  record rather than aborting scanning.
- Lowercase colon namespaces may appear at runtime when the containing
  directory uses the colon-normalized form.

## Writable Scope

- Toggles may patch exact `permission.skill` overrides in verified config
  targets.
- Disable writes exact `deny`; re-enable removes only the matching exact deny.
- Wildcard and unrelated permission rules must be preserved.
- Tool-global installs are limited to native opencode roots.

## Blocked Scope

- `skills.urls` is metadata-only and must not fetch remote indexes.
- Configured local roots and compatibility roots are not install targets.
- Managed config, environment-provided config content, and network-backed
  installs need separate evidence before write support.

## Fixtures

opencode fixtures live under `fixtures/opencode/` and cover valid, malformed,
configured-root, and permission behavior.
