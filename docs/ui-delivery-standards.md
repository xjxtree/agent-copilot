# UI Delivery Standards

> Status: **mandatory for product work**. These standards apply to every major version, major feature, UI-facing workflow, bug fix that changes behavior, and macOS app run/check work.

## 1. Product UI Target

The only maintained product UI shell is the native macOS app:

- Location: `apps/macos/`
- Stack: SwiftUI + AppKit interop
- Runtime access: Rust service protocol only
- Visual system: native macOS controls first, Liquid Glass only on functional surfaces

The old Tauri/React UI has been removed. Do not recreate `ui/`, `src-tauri/`, or Tauri IPC for product work.

## 2. Prototype Before Build

Before every major version or major feature starts:

- Add or update a UI prototype artifact.
- Define the target shell: macOS native now; future Windows/Linux shell only after macOS parity.
- Document the user flow, states, data dependencies, empty/error/loading states, keyboard flow, and accessibility concerns.
- Record expected screenshots or wireframes for desktop and minimum supported window size.
- For Health Dashboard / Adapter Capability UX changes，额外记录侧栏 selected-agent 切换、卡片行动摘要、scan/toggle/install/blocker 状态展示的状态流与文案。

Recommended artifact layout:

```text
docs/ui-artifacts/
└── <feature-or-version>/
    ├── brief.md
    ├── prototype.png
    ├── prototype-notes.md
    ├── completed.png
    └── verification.md
```

If the prototype is text-only at first, `prototype-notes.md` must still describe the layout clearly enough to implement and review.

## 3. Completed UI Evidence

After development and test verification:

- Update the completed UI screenshot for every changed high-level view.
- Completed screenshots must capture the complete app window only. Full-desktop screenshots are forbidden.
- For macOS artifacts, use `script/capture_app_window.sh` where possible. It performs a window-id capture for the target app window. If a region capture is unavoidable, crop strictly to the app window bounds and verify no desktop, wallpaper, menu bar, Dock, or unrelated window is visible.
- Update `verification.md` with the app build, date, tested flows, and known gaps.
- If the finished UI intentionally differs from the prototype, document the reason.
- Do not mark a UI feature complete if the latest completed screenshot is stale.
- Health 区块必须以行动摘要（可执行动作）展示；若只剩全量数字复用表格，不算该特性完成。

## 4. Required macOS App Verification

Every task that changes code must be verified by launching the macOS app and operating the affected behavior with macOS Computer Use before the task is considered complete, but only when the macOS session is confirmed unlocked and interactive.

This includes:

- Feature work
- Bug fixes
- Refactors that can affect runtime behavior
- App run/check or version metadata work
- Service protocol changes
- Native macOS UI changes

Documentation-only changes are exempt. If the app cannot be launched, the macOS session is locked or not clearly interactive, or Computer Use returns `remoteConnection`, `cgWindowNotFound`, or activation errors, record the blocker and keep the candidate pending; do not use smoke screenshots as a substitute for blocked real-local checks.

Minimum verification record:

- App build or launch command
- Screens or flows operated
- Result
- Screenshot path when UI changed
- Known gaps

## 5. Cross-platform UI Compatibility

Future Windows/Linux UI shells should not copy macOS implementation code. They should align through:

- Rust service protocol
- Shared request/response fixtures
- Shared view model vocabulary
- Shared information architecture
- Shared design tokens and interaction principles
- Per-platform native controls
- Per-platform completed UI screenshots

The compatibility target is consistent capability and mental model, not pixel-perfect sameness.

## 6. Pull Request Checklist Additions

> 下面是每次 PR / 任务完成时复制使用的模板项；保持未勾选是刻意的，不代表当前项目进度遗漏。

For code changes:

- [ ] I launched the macOS app and operated the affected flow with macOS Computer Use.
- [ ] I recorded the verification result.

For UI changes:

- [ ] I updated or added the prototype artifact before implementation.
- [ ] I updated the completed UI screenshot after implementation, using a complete app-window-only capture.
- [ ] I checked minimum window size, keyboard flow, and accessibility-sensitive settings where relevant.

## 7. V2.23: Health Dashboard & Adapter Capability UX Checklist

- 侧栏必须只呈现当前 selected/current agent 的 health 行动摘要；不得在侧栏重复展示跨 agent 的 full list table。
- finding 与 conflict 的卡片与 `catalog.listFindings` / `catalog.listConflicts` 的过滤口径保持一致。
- capability matrix 文案必须明确 scan / toggle / install / read-only / blocked 的状态和 blocker。
- Health 卡片应包含下一步动作（比如 refresh / open details / review / remediation）而非仅展示计数。
- 该功能验收项已作为 V2.23 完成口径；未来 Health / capability UI 变更仍需重新验证这些约束。

## 8. V2.24: Skill Detail Diagnostics Checklist（完成口径）

- Detail 为单 skill 诊断工作台（列表点击即开一页式诊断视图）。
- Findings 与 issue group 口径统一：列表/健康卡片/筛选展示的 finding 统计一致。
- Conflicts 仅展示 selected/current agent 的 runtime/name 冲突；不得混入 cross-agent duplicate/source overlap。
- Analysis 区域仅作只读离线分析预览，不提供执行或写入路径。
- History 仅展示 toggle/config 相关事件；不展示 skill-content snapshot。
- 当前口径已完成；未来 detail 改动仍需窗口级验证。若 detail 仅显示 counts 而未给出 remediation action，则视为回归。

## 9. V2.25: Agent-config timeline（完成口径）

- Agent-config History 以 per-agent 时间线展示，不与 selected-skill detail 混用。
- 仅展示 toggle/config 相关快照事件，不展示 skill-content snapshot 或 skill-toggle snapshot。
- rollback 流必须是 preview diff + 明确二次确认：先 `snapshot.previewRollback` 再独立确认 `snapshot.rollback`。
- 当前口径已完成；未来涉及 rollback 或 timeline 的 UI/service/protocol 变更仍需 evidence 记录，且多 agent 视图必须保持各自独立。

## 10. V2.26: Finding explainability（完成口径）

- Findings 显示必须可解释：每条 finding issue group 需展示 rule source、触发原因（reason/message）、受影响实例数与实例列表、扫描条目（agent/scope/definition/path/root）、severity 与 risk 子集关系。
- Health 卡片与 Detail 的 drill-down 需形成闭环：从统计入口可直接跳转到对应 finding group 的实例集合、规则、scope 与 scan entry，再到单 skill 细览。
- 风险口径约束：Risk 仅是 finding 的可解释子集；Health 与 Findings 计数、Filtering 不能出现互斥定义。
- 行为空间约束：finding explainability 仅提供说明/筛选/跳转；不提供执行、自动写入、自动 apply；AI 建议仍为只读预览，且不涉及凭据持久化。
