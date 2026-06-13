# V2.69 Verification

## Automated Checks

- `plutil -lint apps/macos/Sources/SkillsCopilot/Resources/en.lproj/Localizable.strings apps/macos/Sources/SkillsCopilot/Resources/zh-Hans.lproj/Localizable.strings`
- `pnpm test:macos-list-model`
- `pnpm verify:macos-ui-layout`
- `pnpm verify:screenshot-artifacts`
- `swift test --package-path apps/macos`
- `pnpm smoke:macos-app -- --fixture-data`
- `pnpm check:macos` reached fixture capture and failed closed with `locked-session: macOS session is locked; refusing to create screenshot evidence`
- `pnpm check:privacy`
- `git diff --check`
- `git diff --cached --check`

## Screenshot

- No fresh V2.69 fixture screenshot was committed from the locked session.
- Add `docs/ui-artifacts/v2.69-privacy-screenshot-mode/completed.png` only after rerunning fixture capture in an unlocked interactive session.
- Screenshot verifier rejects invalid PNGs, near-black captures, mostly transparent captures, and near-flat captures.
- Manual inspection remains required because automated verification does not perform OCR.

## Real-local Status

Current locked-session attempt: Computer Use returned `timeoutReached`, `ioreg` reported `CGSSessionScreenIsLocked=Yes`, and direct capture exited with `locked-session`.

V2.69 hardens capture failure handling but does not claim a new unlocked real-local Computer Use pass. Real-local UI validation must be retried when the macOS session is unlocked and interactive. Blockers must be classified explicitly instead of accepting smoke screenshots as a substitute.
