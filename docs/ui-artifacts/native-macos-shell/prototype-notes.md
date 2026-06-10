# Native macOS Shell Prototype Notes

```text
+-----------------------------------------------------------------------+
| Toolbar: Scan · Reload · Search                      Skills Copilot    |
+------------------------------+----------------------------------------+
| Summary                      | Skill detail                           |
| enabled / visible / catalog  |                                        |
| Project context              |                                        |
| Agent filter                 |                                        |
| State filter · Sort picker   |                                        |
|                              | Name                         Enable/Disable |
| Skills                       | Agent · Scope · State                  |
| - summarize-changes          | Path                                   |
| - project-helper             | Overview · Findings · Conflicts · Snapshots |
|                              | Preview snapshot · Rollback            |
| Settings                     | Claude settings JSON editor            |
+------------------------------+----------------------------------------+
```

## Interaction Model

- Launch calls `service.status`, `catalog.listSkills`, `catalog.listFindings`, `catalog.listConflicts`, and `snapshot.list`.
- Scan calls `catalog.scanAll` and then refreshes all collections.
- Project context controls call `project.getContext`, `project.setContext`, or `project.clearContext`; Swift does not mutate project context files directly.
- Reload refreshes all collections without writing.
- Sidebar search, state filter, and sort picker update the visible skill list without writing.
- Selecting a row calls `catalog.getSkill` and updates the detail pane.
- Enable/Disable calls `config.toggleSkill`; the UI shows a success banner, updated state, enabled count, and snapshot count.
- Settings loads `config.readClaudeSettings`; Save calls `config.saveClaudeSettings`, validates JSON, snapshots, writes, verifies, and rescans.
- Snapshot Preview calls `snapshot.previewRollback` and presents current config vs snapshot content.
- Snapshot Rollback uses a confirmation dialog, calls `snapshot.rollback`, and refreshes catalog state.
- Native commands cover Scan, Reload, Overview, Findings, Conflicts, Snapshots, Clear Search, and Settings.
- Empty and error states stay in the detail pane, not in modal alerts.

## V2.1 Claude/Codex Adapter Prototype Update

Status: implemented with automated validation passing. Real local Computer Use validation is still blocked in the current macOS session because SkillsCopilot launches as a process but exposes 0 windows to System Events / Computer Use (`cgWindowNotFound`). The smoke fixture screenshot remains useful app-window evidence, but it is not a substitute for real local validation.

- The sidebar includes an agent filter with `All`, `Claude Code`, `Codex`, and `opencode`.
- Agent filtering combines with search, state filter, and sort without writing config or rescanning.
- `All` shows supported adapters after `catalog.scanAll`; `Claude Code`, `Codex`, and `opencode` narrow the list, visible count, and empty state.
- Skill rows keep agent identity visible through grouped sections; detail metadata shows display agent, scope, state, and path.
- Scan summary distinguishes supported adapters through service `activity.agent_summaries` and refresh log entries instead of reporting only a single aggregate.
- A writable Codex toggle completes the same snapshot/write/verify/rescan path as other writable toggles, then displays a note that Codex may need runtime restart to reread `config.toml`.
- Claude Code Settings, snapshot preview, and rollback remain reachable and are not relabeled as Codex features.
- If the real app has no local Codex roots, the Codex filter should show a clear missing/empty state; that state should be recorded during validation instead of counting as Codex visibility success.

## V2.1 Coordinator Validation Checklist

- [x] `pnpm check:macos` completes; exact result is recorded.
- [x] `pnpm dev:macos` launches the real local app process.
- [x] Scan / scan-all is operated in the real app and the visible summary distinguishes Claude Code from Codex.
- [x] Agent filter was operated for `All`, `Claude Code`, and `Codex` during the V2.1 real local pass; later UI revisions removed `All` by design.
- [x] Codex visibility is confirmed with real/local fixture roots, or the missing-root state is recorded.
- [x] Claude Code list/detail/toggle/settings/snapshot regression is checked.
- [ ] Codex toggle displays a restart note for Codex runtime config reload after write/rescan.
- [x] Completed evidence is captured with a full app-window-only screenshot, not a desktop screenshot.

## V2.2 Project Context Prototype Update

Status: implemented with automated validation passing. The original macOS/AX window-resolution blocker has been superseded by later real local Computer Use passes, including the 2026-06-10 current-mainline validation against the explicit `dist/SkillsCopilot.app` bundle path.

- The sidebar or toolbar summary shows active project context: env override, selected/persisted project, or no-project.
- Project picker actions route through `project.setContext`; clear routes through `project.clearContext`.
- Env override is visually distinguishable from a user-selected project and cannot be overwritten by UI persistence.
- No-project scan-all keeps agent-global skills visible while skipping project-local Claude/Codex roots.
- Scan summary includes project context source plus root/no-project state from service activity.
- Recent projects are read from app data `project-context.json`; the file is app state and is not written into a project repo.
- Switching project context refreshes collections and clears selected detail if the selected row is outside the active project/global scope.
- Toggle controls remain disabled or guarded when a row belongs to a different project root than the active `ProjectContext`.

## V2.2 Coordinator Validation Checklist

- [x] `cargo test --workspace`
- [x] `cargo clippy --workspace --all-targets --all-features`
- [x] `swift test --package-path apps/macos`
- [x] `pnpm check:macos`
- [x] Fixture smoke project context scenario: no-project, set project, scan-all, switch/clear project, confirm catalog ownership and toggle target boundaries.
- [x] Real local app project context scenario with Computer Use/AX when the macOS session is unlocked and a SkillsCopilot window is visible.
- [x] If Computer Use/AX cannot see the app window, record the blocker and keep real local Computer Use validation pending; current mainline blocker is resolved as of 2026-06-10.

## V2.4 Opencode Read-only Prototype Update

Status: implemented with automated validation passing. The original macOS/AX window-resolution blocker has been superseded by later real local Computer Use passes; current mainline validation passed on 2026-06-10 when targeting the explicit `dist/SkillsCopilot.app` bundle path.

- Agent filter includes `opencode`; grouped rows and detail metadata show opencode as a distinct adapter.
- `catalog.scanAll` includes guarded writable opencode config/native install support, opencode native plus compatibility scan roots, and read-only Pi roots alongside Claude Code and Codex.
- No-project state shows global opencode skills from `~/.config/opencode/skills` when fixture or real roots exist.
- Active project context can show project opencode skills from `.opencode/skills`; no-project skips project-local opencode roots.
- Toggle UI for opencode rows is disabled with a read-only adapter reason and must not call `config.toggleSkill`.
- Direct service attempts to toggle opencode return read-only/unsupported and must not create or modify opencode config.
- The UI can label `.agents` / `.claude` compatibility roots as opencode-visible rows when OpenCode would load them; cross-agent analysis should explain overlap with Claude/Codex.

## Visual Direction

- Let `NavigationSplitView`, toolbar, list selection, buttons, and Settings use system styling.
- Use `.regularMaterial` only for small status/detail surfaces.
- Keep custom glass minimal until feature parity requires richer inspectors or command bars.
