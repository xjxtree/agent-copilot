# Codex Adapter Spec Worklist

> Status: first implementation and V2.3 adapter hardening completed on 2026-06-08; V2.92 expanded Codex roots on 2026-06-17. `crates/adapters/src/codex/` implements Codex as **native-root user-config writable**, not project-config writable: scan verified user/project `.agents/skills` plus read-only `$CODEX_HOME/skills`, local plugin marketplace roots, and `/etc/codex/skills` when present; toggle by patching only the user Codex config for native `.agents/skills` instances; keep project-local `.codex/config.toml`, plugin/admin/system roots, and compatibility roots out of writable scope.

## 1. Evidence Summary

Sources checked:

- Official Codex Agent Skills docs, retrieved 2026-06-08: <https://developers.openai.com/codex/skills>
- Official Codex Agent Skills docs, rechecked 2026-06-17 for repo/user/admin/system roots and `[[skills.config]]`: <https://developers.openai.com/codex/skills>
- Official Codex plugin docs, retrieved 2026-06-17 for local plugin marketplace paths and plugin skills directories: <https://developers.openai.com/codex/plugins/build>
- Official Codex config basics, retrieved 2026-06-08: <https://developers.openai.com/codex/config-basic>
- Official Codex config reference, retrieved 2026-06-08: <https://developers.openai.com/codex/config-reference>
- Official Codex AGENTS.md guide, retrieved 2026-06-08: <https://developers.openai.com/codex/guides/agents-md>
- Local Codex CLI: `codex-cli 0.137.0`, installed at `/opt/homebrew/bin/codex`.

Local evidence verification used `codex debug prompt-input` with temporary `HOME`, `CODEX_HOME`, and git repositories. The product implementation adds Rust fixture/unit coverage plus service/macOS smoke coverage; live Codex runtime reload is still not assumed.

| Area | Status | Evidence |
| --- | --- | --- |
| Project instruction entrypoint | Verified | Official AGENTS.md guide confirms Codex uses `AGENTS.md`; this is instruction behavior only, not skill discovery or toggle semantics. |
| Skill file format | Verified | Official Codex skills docs state a skill is a directory containing required `SKILL.md`; `name` and `description` are required. |
| Optional skill resources | Verified | Official docs list optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`. |
| Project skill roots | Verified for read-only scanning | Official docs: Codex scans `.agents/skills` from current working directory up to repository root. Local `codex debug prompt-input` confirmed nested and repo-root `.agents/skills` entries become model-visible when run inside a git repo. |
| User skill root | Verified for read-only scanning | Official docs: user skills live under `$HOME/.agents/skills`. Local `codex debug prompt-input` confirmed a synthetic `$HOME/.agents/skills/<name>/SKILL.md` becomes model-visible. |
| Admin skill root | Read-only scan/diagnostic | Official docs list `/etc/codex/skills`; V2.92 exposes it as `RootSource::Admin` when present and never elevates or writes it. |
| System/plugin skills | Plugin read-only, system not filesystem-scanned | Official docs say system skills are bundled with Codex and plugins can include skills. V2.92 parses local plugin marketplace entries into `RootSource::Plugin` scan roots without running hooks/installers/MCP/network. System skills remain noted as no stable local filesystem root for this product. |
| Symlinked skill folders | Official only | Official docs state Codex follows symlinked skill folders. Not locally fixture-tested in this pass. |
| Config path/schema | Verified for user writes | Official config docs say user config is `~/.codex/config.toml` and project config is `.codex/config.toml`. Official skills docs document `[[skills.config]] path = ".../SKILL.md"; enabled = false` in `~/.codex/config.toml`. The config reference lists `skills.config` as per-skill enablement overrides, but describes `path` as a skill folder; local CLI verification showed the absolute `SKILL.md` path works and the folder path did not. |
| User config disable | Verified writable candidate | Local `codex debug prompt-input` confirmed `[[skills.config]]` in synthetic `$CODEX_HOME/config.toml` removes both user and project skills from the model-visible skill list when the `path` is the absolute `SKILL.md` path. |
| Project config disable | Blocked | Local `codex debug prompt-input` did not remove a project skill when the same `[[skills.config]]` entry was placed in `<repo>/.codex/config.toml`, even with an attempted trusted-project override. Do not write project config for Codex skills until this is verified. |
| Live reload after config changes | Partially verified | Official docs require restarting Codex after changing `~/.codex/config.toml`; no live reload behavior should be assumed. |
| Enable semantics | Verified for user config | `enabled = false` is verified for disabling. Re-enable is verified by removing all matching `[[skills.config]]` entries from user config, which returns to default discovery. Duplicate entries are order-sensitive in local CLI verification: the last matching entry wins, so writers must normalize duplicates instead of appending blindly. |

## 2. Verified Local Commands

These commands were run manually with temporary directories:

```sh
codex --version
# codex-cli 0.137.0
```

Read-only discovery checks:

```sh
HOME="$tmp/home" CODEX_HOME="$tmp/home/.codex" \
  codex -C "$tmp/repo/nested" debug prompt-input 'fixture prompt'
```

Observed results:

- `$HOME/.agents/skills/user-alpha/SKILL.md` appeared in prompt input.
- `$repo/.agents/skills/repo-beta/SKILL.md` appeared in prompt input when `$repo` was a git repository.
- `$repo/nested/.agents/skills/nested-gamma/SKILL.md` appeared in prompt input from the nested working directory.
- `$CODEX_HOME/skills/codex-home-skill/SKILL.md` also appeared in prompt input locally. V2.92 treats it as `RootSource::Compatibility`: scan/diagnostic only, never toggle/install/write.

User-config disable check:

```toml
[[skills.config]]
path = "/absolute/path/to/skill/SKILL.md"
enabled = false
```

Observed result: the matching skill was absent from `codex debug prompt-input` output after the config entry was present in `$CODEX_HOME/config.toml`.

User-config re-enable round trip:

```sh
# With the same temp HOME/CODEX_HOME and repo fixture:
# 1. Baseline prompt input included user-alpha and repo-beta.
# 2. Add user config entries with enabled = false for both absolute SKILL.md paths.
# 3. Prompt input no longer included either skill.
# 4. Remove those entries, leaving either an empty config.toml or no config.toml.
# 5. Prompt input included user-alpha and repo-beta again.
HOME="$tmp/home" CODEX_HOME="$tmp/home/.codex" \
  codex -C "$tmp/repo" debug prompt-input 'fixture prompt'
```

Observed result: removing the matching user-config entries restored both user and project skill discovery. This verifies "remove override" as the re-enable patch behavior.

Duplicate and path-shape checks:

- `path = "/absolute/path/to/skill"` did not disable the fixture skill in `codex-cli 0.137.0`; use the absolute `SKILL.md` path.
- Duplicate entries for the same absolute `SKILL.md` path are order-sensitive: `enabled = false` followed by `enabled = true` left the skill visible, while `enabled = true` followed by `enabled = false` hid it.
- Patch policy: for disable, remove all existing entries for the exact absolute `SKILL.md` path and append one `enabled = false` entry; for re-enable, remove all entries for that path and do not add `enabled = true`.

Project-config disable check:

```toml
[[skills.config]]
path = "/absolute/path/to/repo/.agents/skills/repo-beta/SKILL.md"
enabled = false
```

Observed result: the matching skill remained present when this entry lived in `<repo>/.codex/config.toml`. Keep project-local Codex toggles blocked.

Trusted project re-check:

```toml
[projects."/absolute/path/to/repo"]
trust_level = "trusted"
```

Observed result: with the repo marked trusted in user config, `<repo>/.codex/config.toml` still did not hide the project skill using either an absolute `SKILL.md` path or the skill folder path. Keep project-level writable toggles blocked.

## 3. Minimal Fixtures

Fixture files now live under `fixtures/codex/`.

- `fixtures/codex/user-home/.agents/skills/user-alpha/SKILL.md`
- `fixtures/codex/project/.agents/skills/repo-beta/SKILL.md`
- `fixtures/codex/project/nested/.agents/skills/nested-gamma/SKILL.md`
- `fixtures/codex/config/user-config-disabled.toml`
- `fixtures/codex/config/user-config-disabled-project.toml`
- `fixtures/codex/broken/missing-description/SKILL.md`
- `fixtures/codex/conflict/user-home/.agents/skills/shared-name/SKILL.md`
- `fixtures/codex/conflict/project/.agents/skills/shared-name/SKILL.md`

The config fixture uses an absolute fixture path placeholder under `/tmp/skills-copilot-codex-fixture/...` because Codex `[[skills.config]].path` is path-based. Tests should materialize fixtures under a temp directory and rewrite this path to the temporary absolute `SKILL.md` path before invoking Codex.

## 4. Adapter Mapping

The implementation maps only verified Codex data into the shared model:

| Field | Required mapping |
| --- | --- |
| `AgentId` | `codex` |
| `Scope::AgentGlobal` | Writable native root: `$HOME/.agents/skills/<skill-name>/SKILL.md`. Read-only roots: `$CODEX_HOME/skills`, local plugin marketplace roots, and `/etc/codex/skills` when present. |
| `Scope::AgentProject` | `.agents/skills/<skill-name>/SKILL.md` from adapter context `project_cwd` upward to `project_root`, matching the verified Codex cwd-to-repo-root discovery shape. |
| `SkillInstance.name` | `name` from `SKILL.md` frontmatter. Unlike Claude Code, do not assume the directory name is the command/display name. |
| `SkillInstance.description` | `description` from `SKILL.md` frontmatter. Required by Codex docs. |
| `SkillInstance.permissions` | Do not infer from `SKILL.md`. Optional `agents/openai.yaml` can declare dependencies, but product permission mapping is not verified. |
| `SkillInstance.enabled` | Default discovered skills are enabled unless the user config has a matching absolute `SKILL.md` path whose last normalized state is `enabled = false`. |
| `frontmatter_raw` | Preserve original YAML frontmatter from `SKILL.md`. |

Plugin-distributed skills are scan-only in V2.92. They are distribution artifacts, not the same user/project authoring roots, and must not become toggle/install/config-write targets without a new rollback-safe evidence slice.

## 5. Config Write Rules

Codex toggle support uses the same service-layer guarantees as Claude Code:

- Snapshot before write.
- Patch in memory.
- Atomic write through temp file + rename.
- Read-back verification.
- Rescan after save.
- No direct writes from UI.

Writable scope for a first adapter is constrained:

- User config write: `$CODEX_HOME/config.toml` / `~/.codex/config.toml` with `[[skills.config]]`.
- Writable instance allowlist: only user/project `.agents/skills` instances may be patched through the user config override.
- Disable operation: remove all existing entries for the target absolute `SKILL.md` path, then add exactly one `[[skills.config]]` entry with `enabled = false`.
- Re-enable operation: remove all existing entries for the target absolute `SKILL.md` path, returning to Codex default discovery. Do not add `enabled = true` entries.
- Project config write: blocked. Do not write `<repo>/.codex/config.toml` for skill toggles until Codex project-local `[[skills.config]]` behavior is verified.
- Live reload: blocked. Official docs require restart after config changes; the product should tell users a Codex restart may be required after toggling.
- Compatibility/admin/plugin/system roots: read-only. Do not write `$CODEX_HOME/skills`, `/etc/codex/skills`, local plugin marketplace roots, system roots, or project `.codex/config.toml`.

This means project skills are toggled only by user-config override in the first adapter. Project-local toggle semantics remain blocked until verified.

## 5.1 V2.3 Hardening

V2.3 hardens the current user-config writer without expanding writable scope.

Implemented behavior:

- Preserve non-target config content: comments, unrelated tables, unrelated `[[skills.config]]` entries, unknown keys, and existing file newline style should survive target-skill disable/re-enable.
- Normalize only entries whose `path` exactly matches the canonical absolute `SKILL.md` path for the target skill.
- Disable by removing all target entries and writing exactly one target `enabled = false` entry.
- Re-enable by removing all target entries and writing no `enabled = true` replacement.
- Treat malformed target blocks, missing/invalid `path`, symlink config targets, unsafe config parents, and unwritable config files as explicit errors with stable user-facing status.
- Keep project-local `.codex/config.toml`, `/etc/codex/skills`, `$CODEX_HOME/skills`, plugin-distributed skills, and system skills out of writable scope.

## 5.2 V2.92 Expanded Roots

V2.92 resolves the previously deferred root-discovery questions by adding
read-only discovery and diagnostics without expanding writes.

Implemented behavior:

- `RootSource::Compatibility` covers `$CODEX_HOME/skills` as a scan-only root.
- `RootSource::Admin` covers `/etc/codex/skills` when present; missing roots are
  reported as skipped diagnostics.
- `RootSource::Plugin` covers local plugin marketplace entries whose plugin
  manifest exposes a local skills directory. Escaping or remote marketplace
  entries are skipped.
- Project `.codex/config.toml` is listed in diagnostics only.
- Toggle/write operations reject Codex instances unless the canonical
  `SKILL.md` path is under a native user/project `.agents/skills` root.
- No plugin hooks, MCP servers, installers, network fetches, provider calls,
  scripts, credentials, cloud sync, or telemetry are invoked by discovery.

Implemented state expression:

- Distinguish default enabled, user-config disabled, broken frontmatter, duplicate/conflict, missing root, root read error, and symlink/root rejection in adapter findings and UI refresh summaries.
- Show the Codex restart note only after a successful user config write; do not imply live reload.
- Preserve the V2.2 project context boundary: Codex project skills are scanned only for the active safe project root, while toggles still write only the user config override.

## 6. Open Questions

- V2.92 decision: scan `/etc/codex/skills` as read-only admin diagnostics when present.
- V2.92 decision: scan `$CODEX_HOME/skills` as a read-only compatibility root.
- V2.92 decision: scan local plugin marketplace skills as read-only plugin roots; grouping can be refined later, but writes remain blocked.
- Can project-local `.codex/config.toml` ever disable skills in current/future Codex versions, and what trust settings are required?
- Should `agents/openai.yaml` policy and dependencies be parsed into product fields, or preserved as raw adapter metadata only?

## 7. First Implementation Checklist

Current integrated status:

- [x] Add `crates/adapters/src/codex/` and register it from `crates/adapters/src/lib.rs`.
- [x] Implement verified roots only: user `$HOME/.agents/skills` and project `.agents/skills` from adapter context `project_cwd` upward to `project_root`.
- [x] Parse `SKILL.md` with required `name` and `description`; malformed skills become broken instances rather than aborting the scan.
- [x] Implement user-config toggle through `$CODEX_HOME/config.toml` / `~/.codex/config.toml` with snapshot, atomic write, read-back verification, and rescan. The writer normalizes duplicate entries and removes all matching entries on re-enable.
- [x] Add fixtures/tests for global/project roots, malformed skills, disabled/re-enabled config entries, duplicate config entries, and name conflicts.
- [x] Add catalog/service contract coverage so Claude Code and Codex records coexist cleanly through `catalog.scanAll`.
- [x] Update macOS UI scan copy and store/client calls so `codex` records are visible via the agent field.
- [x] Run `cargo test --workspace` and `pnpm check:macos`.
- [x] Real local app Computer Use validation waived for this pass by user request; future UI/code changes should restore the normal validation rule.
- [x] V2.92 expanded roots: read-only `$CODEX_HOME/skills`, local plugin marketplace roots, `/etc/codex/skills`, project `.codex/config.toml` diagnostics, and native `.agents/skills` write allowlist tests.
