# Manual Release Checklist

> Status: current-stage manual release readiness checklist through V2.10 docs/release consistency. This is not a public distribution checklist. The only current release candidate artifact boundary is `dist/SkillsCopilot.app`.
>
> SkillsCopilot does not currently ship a signed, notarized, stapled, zipped, DMG-packaged, auto-updated, or publicly downloadable artifact. Do not use this checklist to claim formal distribution automation.

Use this checklist for a maintainer-run local release-readiness pass before tagging, publishing notes, or handing off a local app candidate for review. Keep all evidence in the release notes, issue, or PR that runs this checklist.

## 1. Preflight

- [ ] Work from the intended release branch or release-candidate commit.
- [ ] Confirm `git status --short` contains only intended release-readiness changes, or is clean before the final validation run.
- [ ] Read the current project state in `AGENTS.md`, `README.md`, and `docs/roadmap.md`.
- [ ] Confirm `docs/distribution-runbook.md` still says public distribution work is deferred.
- [ ] Confirm `docs/macos-app-runbook.md` still says the only current app bundle path is `dist/SkillsCopilot.app`.
- [ ] Confirm V2.10 execution safety docs still say no real script execution by default, future execution requires per-request confirmation plus cwd/env/network/files preview, blocked/cancelled/failure attempts are auditable, and LLM cannot trigger execution.
- [ ] Run `pnpm check:privacy` and confirm no current-tree or reachable-history matches remain for real local paths, usernames, temp app-data paths, token/key shapes, private keys, or credential placeholders.
- [ ] Confirm the candidate does not add signing, notarization, stapling, DMG/ZIP packaging, updater, release feed, checksum publishing, or release artifact automation.
- [ ] Confirm the candidate does not claim a finished script runner, sandbox runtime, success output log, or public execution API unless those features are separately shipped and validated.
- [ ] Record the exact commit hash being checked.

Abort before validation if the release candidate depends on an unpublished signing identity, protected notarization credential, DMG/ZIP packaging script, updater behavior, or public upload path. Those are future public-release decisions, not V2.6 release readiness.

## 2. Version Sanity

- [ ] Inspect `crates/service/Cargo.toml` and record the service crate version.
- [ ] Run or inspect `./script/build_and_run.sh --verify` behavior only as part of the quality gate; it writes the service crate version into `CFBundleShortVersionString` and `CFBundleVersion`.
- [ ] After the bundle exists, confirm `dist/SkillsCopilot.app/Contents/Info.plist` reports the expected `CFBundleShortVersionString`.
- [ ] Confirm release notes, changelog draft, PR title, or tracking issue use the same version label.
- [ ] If the version label is a pre-release candidate, confirm downstream tooling accepts that exact value before using it in the bundle.

Do not tag or announce a version when source version, app bundle version, and release notes disagree.

## 3. Local Quality Gate

Run the current combined gate unless a maintainer explicitly records why a narrower rerun is acceptable:

```sh
pnpm check:macos
```

Record the exact command result. This gate runs Rust fmt/test/clippy, native list model tests, native layout checks, Swift tests/build, Local App Launch Verify, and Smoke App Run.

For documentation-only checklist edits, a lightweight closeout may use:

```sh
git diff --check
```

Do not mark a release candidate ready when `pnpm check:macos` fails or was skipped without an explicit maintainer rationale.

Run the privacy gate before commit, push, or handoff:

```sh
pnpm check:privacy
```

If it fails on reachable history, rewrite the affected local branch history before pushing. If new screenshots were added, visually inspect them because the automated binary check does not perform OCR.

## 4. Fixture Smoke Boundary

The smoke pass must use fixture data:

```sh
pnpm smoke:macos-app -- --fixture-data --capture-window
```

Confirm the smoke evidence:

- [ ] Uses temporary `HOME`, temporary app data, and temporary project roots.
- [ ] Does not read, create, or modify the real user Claude config.
- [ ] Does not read, create, or modify real user Codex or opencode config.
- [ ] Validates the existing `dist/SkillsCopilot.app`; smoke does not rebuild the bundle.
- [ ] Captures only the app window, never the full desktop.
- [ ] Does not visibly include real local usernames, home paths, app-data paths, `/var/folders`, temporary fixture roots, token/key values, or credential placeholders.
- [ ] Covers scan, Enable/Disable, Settings save, Snapshot Preview, Snapshot Rollback, project context, Codex user-config toggle behavior, and opencode read-only rejection as supported by the current smoke script.
- [ ] Does not execute skill scripts through scan, import, export, install, LLM prepare, state snapshot, or detail loading.

Abort if fixture smoke requires real user config, uses `--allow-stale-app` for release evidence, captures the desktop, or leaves temporary fixture state in a real user path.

## 5. Real Local Computer Use Gate

Current mainline real local validation passed on 2026-06-09. Fixture smoke screenshots are still not a substitute for real local validation on future release candidates.

For each future user-visible, UI, or service protocol candidate, run the real local app against the developer's real environment:

```sh
pnpm dev:macos
```

or:

```sh
./script/build_and_run.sh run
```

Then operate the real app with macOS Computer Use and record:

- [ ] The app window is visible and can be targeted by Computer Use/AX.
- [ ] Scan-all works from the toolbar/menu path.
- [ ] Agent filter shows Claude Code, Codex, and read-only opencode rows when local roots exist; missing roots are recorded as missing, not as pass/fail ambiguity.
- [ ] Project context can be set, switched, and cleared.
- [ ] Codex cwd-to-repo-root behavior is visible or the missing-root state is recorded.
- [ ] Claude Code toggle/settings behavior still targets the real expected Claude config only after intentional user action.
- [ ] Opencode rows remain read-only and writable toggles are blocked.
- [ ] Script execution is not presented as a completed working feature. If a future execution affordance is visible, it is default-denied, shows cwd/env/network/files preview before confirmation, and records blocked/cancelled/failure attempts without LLM-triggered execution.
- [ ] Completed evidence is app-window-only.

If the app process launches but the window cannot be resolved, record the blocker exactly and keep real local validation pending for that candidate. Do not replace this with smoke evidence.

## 6. Artifact Boundary

Current candidate boundary:

- [ ] `dist/SkillsCopilot.app`

Current non-artifacts:

- [ ] No DMG.
- [ ] No ZIP.
- [ ] No checksum file.
- [ ] No signed app requirement.
- [ ] No notarization or stapling requirement.
- [ ] No updater feed.
- [ ] No public download page.
- [ ] No release artifact automation.

Only hand off `dist/SkillsCopilot.app` as a local review candidate. Do not describe it as a public release artifact.

## 7. Manual Rollback And Abort Conditions

Abort the release-readiness pass when any of these occur:

- `pnpm check:macos` fails.
- `git diff --check` fails.
- Version labels disagree across source, bundle, and notes.
- Smoke uses or mutates real user Claude, Codex, or opencode config.
- Smoke validates a stale app with `--allow-stale-app`.
- Real local validation is claimed complete while Computer Use/AX cannot resolve the app window.
- A screenshot includes the desktop, wallpaper, menu bar, Dock, or unrelated windows.
- Any candidate contains user catalog data, fixture data, logs, credentials, Claude config, Codex config, or opencode config.
- Any doc, script, or note claims signing, notarization, DMG/ZIP packaging, updater, public download, checksum publishing, or release artifact automation is already implemented.
- Any doc, script, or note claims real skill script execution, sandboxed runner completion, success output logs, or model-triggered execution exists when the current candidate only contains the V2.10 safety boundary.
- Any high/critical security blocker in `docs/security-model.md` affects current local app behavior.

Manual rollback for the current stage is:

- [ ] Do not tag or publish notes.
- [ ] Do not hand off the candidate app.
- [ ] Delete the local candidate `dist/SkillsCopilot.app` if it should not be reused.
- [ ] Return to the last known good commit or rebuild from that commit with `pnpm check:macos`.
- [ ] Record the failed command, blocker, and any cleanup performed.

## 8. Documentation Closeout

Before closing the release-readiness pass:

- [ ] Confirm `README.md`, `AGENTS.md`, `docs/roadmap.md`, `docs/macos-app-runbook.md`, `docs/distribution-runbook.md`, and this checklist agree on the current stage.
- [ ] Confirm the release notes or changelog draft captures V2 adapter behavior changes and known risks.
- [ ] Confirm formal public distribution remains explicitly deferred.
- [ ] Confirm V2.10 wording consistently distinguishes safe execution boundary/docs from a real script runner.
- [ ] Run stale-claim checks for distribution automation wording:

```sh
rg -n "signed|notarized|stapled|DMG|ZIP|release artifact automation|public download|updater" README.md AGENTS.md docs
```

Expected results may include deferred/future/non-goal statements, but must not include claims that formal distribution automation already exists.

Run stale-claim checks for execution wording:

```sh
rg -n "(script runner.*([c]omplete|[i]mplemented|[l]anded|[s]upported)|sandbox.*runner.*([c]omplete|[i]mplemented|[l]anded|[s]upported)|successful execution.*([c]omplete|[i]mplemented|[l]anded|[s]upported)|LLM.*trigger.*execution.*([c]omplete|[i]mplemented|[l]anded|[s]upported)|V2\\.10 .*unstarted|V2\\.10 .*not started)" README.md AGENTS.md docs
```

Expected results may include deferred/future/non-goal statements, but must not include claims that real execution or model-triggered execution exists.
