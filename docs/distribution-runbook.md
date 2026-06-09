# Distribution Runbook

> Status: deferred public-release planning reference. SkillsCopilot has not made a public release yet. The current local bundle remains `dist/SkillsCopilot.app`; it is not signed, notarized, stapled, zipped, or packaged as a public distribution artifact.

This runbook records the future pre-distribution path for the native macOS app. It is not an active V2 Prep implementation checklist: signing, notarization, DMG/ZIP packaging, release artifact automation, and updater work are deferred until the product is mature enough for public release work.

For V2.6 local release-readiness checks, use [`release-checklist.md`](./release-checklist.md). That checklist is limited to manual validation of `dist/SkillsCopilot.app` and must not be treated as public distribution automation.

## Current Distribution State

- Current app bundle path: `dist/SkillsCopilot.app`.
- Current bundle id: `dev.skills-copilot.native`.
- Current bundle assembly command: `./script/build_and_run.sh run` or `./script/build_and_run.sh --verify`.
- Current quality gate: `pnpm check:macos`.
- Current signing state: unsigned local development bundle.
- Current notarization state: not notarized or stapled.
- Current packaging state: no DMG, ZIP, release feed, or public download artifact.
- Current release implementation decision: deferred until the product is mature; do not add signing, notarization, DMG/ZIP, updater, or release artifact automation as routine V2 Prep work.

## Version Number Strategy

The current source of truth for the app version is the Rust service crate version in `crates/service/Cargo.toml`. `script/build_and_run.sh` reads that version and writes both:

- `CFBundleShortVersionString`
- `CFBundleVersion`

For V2 Prep and pre-release local builds:

- Keep the Rust service crate version, app bundle version, and release notes version aligned.
- Use SemVer for human-facing release versions, for example `0.2.0`.
- Use pre-release identifiers for non-public candidates, for example `0.2.0-rc.1`, only where every downstream tool accepts them.
- Do not tag or publish a version until the validation checklist in this file has passed.

Before public release work resumes, decide whether `CFBundleVersion` should remain equal to `CFBundleShortVersionString` or move to a monotonically increasing build number. If App Store, MDM, Sparkle, or notarization tooling imposes stricter build-number behavior, update `script/build_and_run.sh`, this runbook, and any release checklist together.

## Signing

Public distribution requires Developer ID signing. The current local bundle is intentionally unsigned, and signing implementation is deferred until the product is mature enough for public release work.

Before signing is enabled:

- Confirm the Apple Developer Team ID and certificate holder.
- Confirm the signing identity name, expected form: `Developer ID Application: <Name> (<TEAMID>)`.
- Decide whether signing runs only on a maintainer machine or also in CI with protected secrets.
- Decide whether the Rust service sidecar is signed explicitly before signing the `.app` bundle.
- Add an entitlements file only if a real capability requires it; do not add broad entitlements as a placeholder.

Expected manual verification once signing exists:

```sh
codesign --verify --deep --strict --verbose=2 dist/SkillsCopilot.app
codesign -dv --verbose=4 dist/SkillsCopilot.app
spctl --assess --type execute --verbose=4 dist/SkillsCopilot.app
```

Signing must preserve the project's privacy stance: no cloud sync, no telemetry, no anonymous crash reporting, and no uncontrolled outbound network calls.

## Notarization

Public macOS distribution outside the App Store requires notarization and stapling. The current local bundle is not notarized, and notarization implementation is deferred until public release work resumes.

Before notarization is enabled:

- Confirm the notarization account and credential storage method.
- Prefer `notarytool` credentials stored outside the repository.
- Confirm whether notarization is submitted for the signed `.app`, ZIP, DMG, or both.
- Record the notarization request id in release notes or an internal release log.
- Staple the notarization ticket to any user-facing app or DMG artifact that supports stapling.

Expected manual verification once notarization exists:

```sh
xcrun stapler validate dist/SkillsCopilot.app
spctl --assess --type execute --verbose=4 dist/SkillsCopilot.app
```

If the public artifact is a DMG, also validate the DMG after stapling.

## DMG and ZIP Packaging

The project currently defines no DMG or ZIP artifact. Choosing and implementing the first public artifact format is deferred until the product is mature enough for public release work.

Recommended packaging decision:

- DMG: primary public download for macOS users.
- ZIP: optional secondary artifact for automation or developer workflows.
- Checksums: publish SHA-256 for every downloadable artifact.

Expected DMG contents:

- `SkillsCopilot.app`
- An Applications folder alias, if the DMG layout tool supports it.
- No auto-run installer behavior.
- No bundled user data, fixture data, catalog, logs, credentials, or local Claude config.

Expected ZIP contents:

- `SkillsCopilot.app` only, unless a future release note explicitly adds files.
- No generated local app data, fixture data, catalog, logs, credentials, or local Claude config.

Expected artifact naming:

```text
SkillsCopilot-<version>-macos-universal.dmg
SkillsCopilot-<version>-macos-universal.zip
SkillsCopilot-<version>-macos-universal.dmg.sha256
SkillsCopilot-<version>-macos-universal.zip.sha256
```

If the build is not universal, replace `universal` with the real architecture label and document the supported machines.

## Local Validation Before Packaging

Run these checks before creating any signed or packaged candidate:

```sh
git status --short
cargo fmt --all -- --check
cargo test --workspace
cargo clippy --workspace --all-targets --all-features -- -D warnings
pnpm test:macos-list-model
pnpm verify:macos-ui-layout
swift build --package-path apps/macos
./script/build_and_run.sh --verify
pnpm smoke:macos-app -- --fixture-data --capture-window
```

Or run the combined current-stage gate:

```sh
pnpm check:macos
```

For UI-facing changes, also run the real local app and operate the affected flow:

```sh
./script/build_and_run.sh run
```

Real local validation uses the developer's real `HOME`, default app data, and real Claude config. Smoke validation must use fixture data and must not touch the real user Claude config.

Completed UI screenshots must be app-window-only captures:

```sh
pnpm capture:macos-window
```

Full desktop screenshots are forbidden.

## Candidate Validation After Packaging

Once signing, notarization, and packaging scripts exist, validate the packaged candidate on a clean macOS account or machine before any public upload.

Required checks:

- The downloaded artifact checksum matches the published SHA-256.
- The artifact opens without quarantine or Gatekeeper failures.
- `SkillsCopilot.app` launches from `/Applications`.
- `service.status` reports the expected app version and protocol version.
- Scan, Enable/Disable, Settings save, Snapshot Preview, and Snapshot Rollback still pass with fixture data.
- A real local smoke pass confirms the app can read the developer's real Claude setup without touching unrelated files.
- The app creates no telemetry, crash-reporting, cloud-sync, account, or unexpected network behavior.

Expected command checks after packaging exists:

```sh
shasum -a 256 <artifact>
spctl --assess --type open --verbose=4 <artifact>
xcrun stapler validate <artifact>
```

Use the app-window screenshot rule for any release-candidate UI evidence.

## Release Notes and Public Release Gate

Before a public release:

- Confirm the release version and git tag.
- Summarize user-visible changes, known limitations, and supported macOS versions.
- Confirm whether the artifact is DMG-only, ZIP-only, or both.
- Confirm signing identity and notarization status.
- Confirm SHA-256 checksums.
- Confirm the security checklist in `docs/security-model.md` has no unresolved high/critical release blockers.
- Confirm this runbook and `docs/macos-app-runbook.md` still match the actual commands.

Do not publish a public download while any of these are still unresolved:

- Unsigned public artifact.
- Failed notarization or missing stapling decision.
- Missing checksum.
- Smoke validation that requires real user config.
- Any release path that uploads user catalog, skill contents, logs, credentials, or Claude config.

## Future Updater Decision Placeholder

The project has not selected an updater. Do not add an updater before the first public distribution decision is made.

Decision options to evaluate later:

- No auto-updater for the first public release; users download new DMG/ZIP manually.
- Sparkle-based updater for macOS, with signed update feeds and explicit release-note UI.
- A custom updater is discouraged unless there is a concrete requirement that Sparkle cannot satisfy.

Updater requirements if one is added:

- User-visible update checks.
- Signed update artifacts and signed update feed.
- No telemetry or silent tracking.
- No mandatory account.
- No uncontrolled background network calls.
- Clear rollback or downgrade guidance for failed updates.

Record the final updater decision in this section before implementing updater code.
