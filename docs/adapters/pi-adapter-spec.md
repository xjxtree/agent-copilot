# Pi Adapter Spec

This document records the current Pi adapter contract.

## Scan Roots

- Native global `~/.pi/agent/skills`.
- Native project `.pi/skills`.
- Shared `.agents/skills` compatibility roots from user and project scopes.

Directory skills with `SKILL.md` are cataloged. Direct root Markdown files are
ignored because they can include ordinary resource documents.

## Skill Format

- A skill is a directory containing `SKILL.md`.
- Required frontmatter: `name`, `description`.
- Missing required frontmatter creates a broken record rather than aborting the
  scan.

## Writable Scope

- Guarded toggles may update supported disabled-skill collections in Pi
  settings.
- Project settings writes must be project-bound, snapshot-backed, read back,
  and rollback-capable.
- Tool-global installs may copy confirmed local `SKILL.md` records only into
  native Pi roots.

## Blocked Scope

- No package install/remove.
- No `.agents` direct skill-file installs.
- No scripts, credentials, cloud sync, telemetry, or AI write-back.
- Explicit untrusted project markers block project writes.

## Fixtures

Pi fixtures live under `fixtures/pi/` and cover native roots, compatibility
roots, malformed skills, and disposable writable evidence.
