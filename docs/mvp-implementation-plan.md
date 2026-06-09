# MVP Implementation Plan

> This is the construction plan for the first code slice. It translates the design docs into implementation tasks without expanding scope.
>
> Status as of 2026-06-08: sections 1-4 are implemented for the Claude Code MVP, the First Code Milestones in section 5 have a working implementation, and [`roadmap.md`](./roadmap.md) has no remaining MVP-blocking hardening items. This file remains the historical MVP construction record. Current product UI direction is native macOS SwiftUI/AppKit; the Tauri + React UI from this plan has been removed.

## 1. MVP Goal

Ship a macOS-first desktop app that can scan, index, inspect, and toggle Claude Code skills with safe writes and rollback.

The MVP originally shipped through the Tauri + React validation shell. That shell has since been removed. Current productization keeps the same Rust core and moves UI work to the SwiftUI/AppKit shell described in [`macos-native-plan.md`](./macos-native-plan.md).

MVP supports:

- ✅ Claude Code only
- ✅ Local scan and catalog only
- ✅ Rule-based diagnostics only
- ✅ No LLM
- ✅ No multi-agent UI
- ✅ No marketplace, sync, telemetry, or crash reporting

## 2. Verified Claude Code Skill Facts

Verified from the official Claude Code skills docs on 2026-06-03:

- Personal skills live at `~/.claude/skills/<skill-name>/SKILL.md`
- Project skills live at `.claude/skills/<skill-name>/SKILL.md`
- Additional `--add-dir` directories can expose nested `.claude/skills/`
- `SKILL.md` uses YAML frontmatter plus Markdown body
- `description` is recommended; all frontmatter fields are optional
- The command name comes from the skill directory name for normal personal/project skills
- Claude Code watches existing skill directories for `SKILL.md` changes during a session
- Skills are discovered and enabled by default in the SDK unless a per-session `skills` option restricts them
- Claude Code CLI supports persistent skill visibility through `skillOverrides`
- The `/skills` menu writes `skillOverrides` to `.claude/settings.local.json`

Primary sources:

- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code SDK skills: https://code.claude.com/docs/en/agent-sdk/skills
- Claude Code settings: https://docs.anthropic.com/en/docs/claude-code/settings

Important MVP decision: use `skillOverrides`, not the older unverified `enableSkills` placeholder.

## 3. MVP Toggle Semantics

Because Claude Code CLI skills are filesystem-discovered and treated as `"on"` when absent from `skillOverrides`, MVP implements toggle by patching the nearest writable Claude Code local settings file:

- Disable:
  - set `skillOverrides[skill_name] = "off"`
- Enable:
  - remove `skillOverrides[skill_name]` when the skill should return to inherited/default behavior
  - or set `skillOverrides[skill_name] = "on"` only when an explicit local override is needed

Other visibility states are indexed but not exposed as the MVP toggle default:

- `"name-only"`: name visible to Claude, hidden details
- `"user-invocable-only"`: visible in `/` menu, hidden from Claude's automatic invocation

For MVP, writes target:

- project skills: `<project>/.claude/settings.local.json`
- personal skills: `~/.claude/settings.json`

Every toggle writes a Claude Code settings file, not `SKILL.md`, and must use:

- pre-write `config_snapshot`
- file lock
- atomic temp-file write
- fsync + rename
- read-back validation
- rollback on validation failure
- immediate rescan

Do not edit `disable-model-invocation` or `user-invocable` during MVP toggle. Those are author intent fields inside the skill itself, while `skillOverrides` is the user/local visibility layer.

## 4. Workspace Shape

Historical target scaffold:

```text
skills-copilot/
├── Cargo.toml
├── crates/
│   ├── core/
│   ├── adapters/
│   ├── scanner/
│   ├── catalog/
│   ├── ai-core/
│   └── commands/
├── ui/
│   ├── package.json
│   └── src/
└── src-tauri/
```

The historical MVP scaffold matched this shape. Current code keeps Rust workspace crates under `crates/`, native macOS UI under `apps/macos/`, and no longer contains `ui/` or `src-tauri/`.

MVP crate responsibilities:

- `core`: pure types and traits, no filesystem or database I/O
- `adapters`: Claude Code path rules, parsing, and frontmatter patch semantics
- `scanner`: root enumeration, candidate discovery, content parsing orchestration
- `catalog`: SQLite migrations, upsert/query, conflict grouping, snapshots, events
- `ai-core`: rule engine only in MVP; no provider implementations
- `commands`: UI-agnostic command orchestration; during MVP it was exposed through Tauri IPC, and current native macOS work reaches it through `crates/service`

## 5. First Code Milestones

1. ✅ Scaffold Tauri 2 + Rust workspace + React/Vite UI.
2. ✅ Add `core` model types from `docs/data-model.md`.
3. ✅ Add initial SQLite migrations.
4. ✅ Add Claude Code fixtures:
   - valid personal skill
   - valid project skill
   - missing frontmatter
   - invalid YAML
   - same-name content drift
   - disabled-by-skill-overrides
5. ✅ Implement `AgentAdapter` for Claude Code scan/parse.
6. ✅ Implement `AgentConfigAdapter.patch_enabled` for `skillOverrides`.
7. ✅ Implement scan to catalog:
   - root discovery
   - canonical path validation
   - parse failures become `Broken`
   - missing records retained as `Missing`
8. ✅ Implement rules:
   - `frontmatter.required-fields`
   - `name.collision`
   - `path.outside-workspace`
   - `fingerprint.changed`
9. ✅ Implement historical Tauri commands, later migrated to service protocol methods:
   - `scan_claude` (MVP Claude-only equivalent of planned `scan_all`)
   - `list_skills`
   - `get_skill`
   - `toggle_skill`
   - `list_findings`
   - `list_conflicts`
   - `list_snapshots`
   - `preview_snapshot_rollback`
   - `rollback_snapshot`
   - V1 added `read_claude_settings` / `save_claude_settings` for the Claude config editor MVP.
10. ✅ Build UI:
   - skill list grouped by definition
   - details panel
   - diagnostics
   - conflict marker
   - toggle button with confirmation
   - snapshot rollback view

## 6. Testing Bar

Required before MVP is considered complete:

- `cargo test` passes
- adapter fixture tests cover happy path and at least three broken paths
- catalog migration test runs from empty database
- toggle test verifies:
  - snapshot created
  - `skillOverrides` patched
  - inherited/default behavior restored on enable
  - rollback restores original settings file
- scanner test verifies symlink escape is rejected
- UI smoke test verifies first screen renders and can list fixture skills

Current verification coverage includes Rust unit/integration tests, native SwiftPM app build, native macOS `.app` smoke automation, macOS unified-log noise classification, 10k synthetic skills scan/catalog benchmark, native list model tests, and native layout checks.

## 7. Developer Commands

Current native macOS development uses `./script/build_and_run.sh --verify`, `pnpm build:macos`, and `pnpm smoke:macos-app`.

```sh
cargo test --workspace
cargo clippy --workspace --all-targets --all-features
./script/build_and_run.sh --verify
pnpm build:macos
pnpm smoke:macos-app
pnpm smoke:macos-app -- --fixture-data --capture-window
pnpm benchmark:10k
pnpm test:macos-list-model
pnpm benchmark:macos-list-model
pnpm verify:macos-ui-layout
```

## 8. Resolved Scaffold Decisions

- Package manager: `pnpm`.
- Rust SQLite layer: `rusqlite` with bundled SQLite.
- Frontend state: historical MVP/V1 used React component state + typed Tauri IPC wrappers; current native SwiftUI shell calls the shared service protocol.
- YAML parser: `serde_yaml` in the Claude Code adapter; raw frontmatter is retained for details/debugging.
