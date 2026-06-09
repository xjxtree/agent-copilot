# Native macOS Shell Brief

## Product Goal

Start the maintained product UI as a native macOS SwiftUI/AppKit shell while keeping all business logic behind the Rust service protocol.

## First Screen

- Native `NavigationSplitView`
- Sidebar: summary row, visible count, state filter, sort picker, and skill list
- Detail: selected skill metadata, path, state, full detail, findings, conflicts, and snapshots
- Toolbar: scan and reload from service
- Header action: enable/disable selected Claude skill
- Snapshot actions: preview current config vs snapshot, then rollback after confirmation
- Settings scene: product/protocol diagnostics and Claude `settings.json` editor

## Non-goals

- No broad preferences surface in this pass; provider/language/keychain settings remain later polish.
- No custom web-style chrome.
- No direct Rust crate imports from Swift.
- No project-local Codex config writes.
- No third adapter, plugin/admin roots, cloud sync, telemetry, or public distribution surface as part of V2.2 project context work.

## Acceptance

- Builds as a SwiftPM macOS GUI app bundle.
- Bundles `skills-copilot-service` as a sidecar resource.
- Launches in foreground and can reload skills through `catalog.listSkills`.
- Scans supported adapters through `catalog.scanAll`; `catalog.scanClaude` remains a Claude-only compatibility method.
- Loads selected skill detail through `catalog.getSkill`.
- Renders read-only Findings, Conflicts, and Snapshots segments from service protocol data.
- Toggles selected skill through `config.toggleSkill`.
- Loads and saves Claude settings through `config.readClaudeSettings` and `config.saveClaudeSettings`.
- Previews and rolls back snapshots through `snapshot.previewRollback` and `snapshot.rollback`.
- Provides native menu commands for scan, reload, detail sections, search clearing, and Settings.
- Provides sidebar search, state filtering, and sort controls for catalog navigation.
- Completed screenshot and verification notes are recorded after launch.

## V2.1 Dual Adapter Experience Target

Status: implemented with automated validation passing; latest real app window operation is blocked because the launched process exposes 0 windows to System Events / Computer Use.

- Sidebar navigation adds an agent filter with `All`, `Claude Code`, and `Codex` options.
- Summary and list counts follow the active agent filter while preserving the full catalog after `catalog.scanAll`.
- Skill rows and detail metadata expose the agent identity clearly enough to distinguish same-name skills from Claude Code and Codex.
- Scan feedback summarizes Claude Code and Codex results separately through `activity.agent_summaries` and refresh log entries.
- Codex writable toggles show a Codex runtime restart note after the write/rescan flow; the note does not describe the change as live reload.
- Claude Code scan/list/detail/toggle/settings/snapshot behavior remains unchanged by the dual-adapter UI pass.
- Completed smoke screenshot evidence is app-window-only; real local window-operation evidence still needs an interactive macOS session with a visible SkillsCopilot window.

## V2.2 Project Context Experience

Status: implementation and automated validation complete; real local Computer Use operation remains pending until an interactive macOS window is available.

- The shell exposes the current `ProjectContext` near the scan/reload workflow so users can tell whether scans are running under env override, a selected/persisted project, or no-project.
- Users can choose a project directory, switch to a recent project, and clear the current project through service methods rather than direct Swift filesystem mutation.
- No-project is a first-class state: scan-all still covers supported agent-global roots, but project-local Claude/Codex roots are skipped and the UI must not imply an old project remains active.
- Scan feedback should include project context source and root/no-project state in the visible summary.
- Project switching must clear stale selection when the selected skill no longer belongs to the active context.
- Codex cwd-to-repo-root behavior is validated only when a real or fixture Codex project root is available; missing Codex roots should be recorded as a validation note, not treated as success.
