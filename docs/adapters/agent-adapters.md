# Agent Adapters

This document defines supported local-agent scan roots, write scopes, and
blocked operations. It is a current contract, not a version history.

## Global Rules

- Adapters are stateless. They discover roots, parse skill records, and report
  enabled state; they do not cache file contents.
- Scanner errors must degrade to broken records or skipped roots rather than
  aborting the whole scan.
- Writes must go through the service layer with preview, snapshot/read-back
  where applicable, atomic write, rollback, and rescan.
- Network fetch, package manager calls, script execution, credentials, cloud
  sync, and telemetry are blocked unless explicitly scoped and reviewed.
- Configured or compatibility roots are scan-only unless the adapter table
  below explicitly names a guarded write path.

## Adapter Matrix

| Adapter | Scan roots | Guarded writes | Install targets | Blocked |
| --- | --- | --- | --- | --- |
| Claude Code | User/project `.claude/skills` and supported compatibility roots | Private Claude settings toggle path | Verified native target paths | Shared project settings writes unless separately scoped |
| Codex | User/project `.agents/skills`; read-only `$CODEX_HOME/skills`, local plugin marketplace roots, `/etc/codex/skills`, and project `.codex/config.toml` diagnostics | User config override for native `.agents/skills` instances | Native `.agents/skills` roots | Project `.codex/config.toml`, plugin/admin/system/compat writes |
| opencode | Native roots, official `.claude` / `.agents` compatibility roots, and configured local `skills.paths` roots | Exact `permission.skill` overrides in verified config targets | Native opencode roots | `skills.urls` fetch, configured-root writes, compatibility-root installs |
| Pi | Native `~/.pi/agent/skills`, project `.pi/skills`, and `.agents/skills` compatibility roots | Guarded settings toggle for native and `.agents` compatibility instances | Native Pi roots only | Package install/remove, `.agents` direct installs, scripts, credentials |
| Hermes | Native `~/.hermes/skills` and explicit read-only `skills.external_dirs` | Global `skills.disabled` only | Native `~/.hermes/skills` | Project installs, `platform_disabled`, `external_dirs` writes, hub/URL/tap/update/uninstall/reset |
| OpenClaw | Native `~/.openclaw/skills`, shared `~/.agents/skills`, bundled roots, confirmed workspace `<workspace>/skills`, and `<workspace>/.agents/skills` | `skills.entries.<key>.enabled` only | Native `~/.openclaw/skills` and confirmed workspace `<workspace>/skills` | `.agents` direct installs, allowlists, env/apiKey, install policy, load roots, ClawHub/Git/update/verify/workshop |

## Discovery Requirements

New or expanded adapter support needs verified evidence for:

- skill discovery roots;
- skill file/directory format;
- project inheritance behavior;
- config file path and schema;
- enable/disable semantics;
- fixture data;
- malformed input behavior;
- read-only fallback behavior when write semantics are absent.

Do not infer support from neighboring tools, guessed paths, or generic project
root conventions.

## Identity And Dedupe

- Same physical file exposed by multiple agents may appear as multiple
  `SkillInstance` rows.
- Same-agent runtime/name collisions are conflicts.
- Cross-agent duplicate, overlap, or enabled-state mismatch belongs in analysis,
  not conflict counts.
- Path/provenance labels should explain why two rows exist without changing
  conflict semantics.

## Safety Notes

- `skills.urls`, hubs, taps, package managers, Git-backed installs, cloud
  scanners, security scans, and update commands are metadata-only or blocked
  unless separately scoped.
- Import/install must copy only confirmed local `SKILL.md` records into verified
  app-controlled or native roots.
- Adapter config snapshots must redact secrets before persistence or display.
- Any future write expansion must include disposable evidence, fixture tests,
  rollback tests, and privacy verification.
