#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { platform, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { formatValidationBlocker } from "./validation-blockers.mjs";

const appName = "SkillsCopilot";
const bundleId = "dev.skills-copilot.native";
const processName = appName;
const appPath = resolve(process.env.SKILLS_COPILOT_APP ?? "dist/SkillsCopilot.app");
const serviceBinary = join(appPath, "Contents", "Resources", "skills-copilot-service");
const screenshotPath = resolve(
  process.env.SKILLS_COPILOT_SMOKE_SCREENSHOT ??
    "docs/ui-artifacts/native-macos-shell/completed.png",
);
const bundleOnly = process.argv.includes("--bundle-only");
const fixtureData = process.argv.includes("--fixture-data");
const keepOpen = process.argv.includes("--keep-open");
const captureWindow = process.argv.includes("--capture-window");
const checkLogs = process.argv.includes("--check-logs");
const allowStaleApp =
  process.argv.includes("--allow-stale-app") ||
  process.env.SKILLS_COPILOT_ALLOW_STALE_APP === "1";

const knownBenignLogPatterns = [
  /appintents/i,
  /StateRestoration.*restoreWindowWithIdentifier/i,
  /CFPasteboard/i,
  /Connection invalid/i,
  /XPC_ERROR_CONNECTION_INVALID/i,
  /TCCAccessRequest/i,
  /TCC:access/i,
  /SkyLight.*not a valid connection ID/i,
  /launchservicesd/i,
  /RunningBoard/i,
  /CoreServices\.coreservicesd/i,
  /Missing .* entitlement/i,
  /\[com\.apple\.AppKit:General\] <private>/i,
];

class SmokeFailure extends Error {
  constructor(message) {
    super(message);
    this.name = "SmokeFailure";
  }
}

function fail(message) {
  throw new SmokeFailure(message);
}

function note(message) {
  console.log(`smoke: ${message}`);
}

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    ...options,
  }).trim();
}

function tryRun(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: [options.input === undefined ? "ignore" : "pipe", "pipe", "pipe"],
    ...options,
  });
  return {
    ok: result.status === 0,
    stdout: result.stdout.trim(),
    stderr: result.stderr.trim(),
    status: result.status,
  };
}

function verifyBundle() {
  if (platform() !== "darwin") {
    fail("macOS app smoke only runs on darwin");
  }
  const infoPlist = join(appPath, "Contents", "Info.plist");
  const binary = join(appPath, "Contents", "MacOS", appName);
  const icon = join(appPath, "Contents", "Resources", "AppIcon.icns");
  for (const file of [appPath, infoPlist, binary, serviceBinary, icon]) {
    if (!existsSync(file)) {
      fail(`bundle is missing ${file}`);
    }
  }
  const identifier = run("/usr/libexec/PlistBuddy", [
    "-c",
    "Print :CFBundleIdentifier",
    infoPlist,
  ]);
  if (identifier !== bundleId) {
    fail(`unexpected CFBundleIdentifier ${identifier}`);
  }
  const iconFile = run("/usr/libexec/PlistBuddy", [
    "-c",
    "Print :CFBundleIconFile",
    infoPlist,
  ]);
  if (iconFile !== "AppIcon") {
    fail(`unexpected CFBundleIconFile ${iconFile}`);
  }
  note(`bundle ok: ${appPath}`);
}

function verifyBundleFreshness() {
  if (allowStaleApp) {
    note("bundle freshness check skipped by --allow-stale-app");
    return;
  }

  const appBinary = join(appPath, "Contents", "MacOS", appName);
  const bundledIcon = join(appPath, "Contents", "Resources", "AppIcon.icns");
  const bundledLocalizable = join(appPath, "Contents", "Resources", "en.lproj", "Localizable.strings");
  const infoPlist = join(appPath, "Contents", "Info.plist");
  assertTargetFresh(
    "Swift app binary",
    appBinary,
    [
      "apps/macos/Package.swift",
      "script/build_and_run.sh",
      ...filesUnder("apps/macos/Sources", [".swift"]),
    ],
  );
  assertTargetFresh(
    "Rust service sidecar",
    serviceBinary,
    [
      "Cargo.toml",
      "Cargo.lock",
      "script/build_and_run.sh",
      ...filesUnder("crates", [".rs", ".toml"]),
    ],
  );
  assertTargetFresh("bundled app icon", bundledIcon, [
    "apps/macos/Sources/SkillsCopilot/Resources/AppIcon.icns",
    "script/build_and_run.sh",
  ]);
  assertTargetFresh("bundled localized strings", bundledLocalizable, [
    "script/build_and_run.sh",
    ...filesUnder("apps/macos/Sources/SkillsCopilot/Resources", [".strings"]),
  ]);
  assertTargetFresh("Info.plist", infoPlist, [
    "crates/service/Cargo.toml",
    "script/build_and_run.sh",
  ]);
  note("bundle freshness ok");
}

function assertTargetFresh(label, targetPath, inputPaths) {
  if (!existsSync(targetPath)) {
    fail(`${label} is missing: ${targetPath}`);
  }
  const targetMtime = statSync(targetPath).mtimeMs;
  const staleInputs = inputPaths
    .filter((path) => existsSync(path))
    .map((path) => ({ path, mtime: statSync(path).mtimeMs }))
    .filter((input) => input.mtime > targetMtime + 1_000)
    .sort((a, b) => b.mtime - a.mtime);

  if (staleInputs.length === 0) {
    return;
  }

  const examples = staleInputs
    .slice(0, 8)
    .map((input) => `  - ${input.path}`)
    .join("\n");
  fail(
    `stale-bundle: ${label} is older than source inputs.\n` +
      `${examples}\n` +
      "Run ./script/build_and_run.sh --verify or pnpm check:macos before Smoke App Run.",
  );
}

function filesUnder(dir, extensions) {
  if (!existsSync(dir)) {
    return [];
  }

  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...filesUnder(path, extensions));
    } else if (extensions.some((extension) => path.endsWith(extension))) {
      files.push(path);
    }
  }
  return files;
}

function createFixtureEnvironment() {
  const root = mkdtempSync(join(tmpdir(), "skills-copilot-native-smoke-"));
  const realOpencodeConfigSnapshot = snapshotRealOpencodeConfig();
  const home = join(root, "home");
  const appData = join(root, "app-data");
  const claudeSkillsRoot = join(home, ".claude", "skills");
  const codexSkillsRoot = join(home, ".agents", "skills");
  const opencodeSkillsRoot = join(home, ".config", "opencode", "skills");
  const projectRoot = join(root, "fixture-project");
  const projectCwd = join(projectRoot, "nested", "workspace");
  const projectCodexSkillsRoot = join(projectRoot, ".agents", "skills");
  const projectOpencodeSkillsRoot = join(projectRoot, ".opencode", "skills");
  const codexUserConfig = join(home, ".codex", "config.toml");
  const projectCodexConfig = join(projectRoot, ".codex", "config.toml");
  const projectOpencodeConfig = join(projectRoot, "opencode.json");
  mkdirSync(claudeSkillsRoot, { recursive: true });
  mkdirSync(codexSkillsRoot, { recursive: true });
  mkdirSync(opencodeSkillsRoot, { recursive: true });
  mkdirSync(projectCodexSkillsRoot, { recursive: true });
  mkdirSync(projectOpencodeSkillsRoot, { recursive: true });
  mkdirSync(join(projectRoot, ".git"), { recursive: true });
  mkdirSync(projectCwd, { recursive: true });
  mkdirSync(appData, { recursive: true });
  mkdirSync(join(home, ".claude"), { recursive: true });
  mkdirSync(join(home, ".codex"), { recursive: true });
  writeFileSync(join(home, ".claude", "settings.json"), "{}\n");

  writeSkill(
    claudeSkillsRoot,
    "alpha-review",
    "---\nname: alpha-review\ndescription: Review fixture for native smoke.\n---\nAlpha body.\n",
  );
  writeSkill(
    claudeSkillsRoot,
    "content-drift-a",
    "---\nname: shared-name\ndescription: First conflicting fixture.\n---\nUse version A.\n",
  );
  writeSkill(
    claudeSkillsRoot,
    "content-drift-b",
    "---\nname: shared-name\ndescription: Second conflicting fixture.\n---\nUse version B.\n",
  );
  writeSkill(
    codexSkillsRoot,
    "codex-user-smoke",
    "---\nname: codex-user-smoke\ndescription: User Codex fixture for native smoke.\n---\nUser Codex body.\n",
  );
  writeSkill(
    projectCodexSkillsRoot,
    "codex-project-smoke",
    "---\nname: codex-project-smoke\ndescription: Project Codex fixture for native smoke.\n---\nProject Codex body.\n",
  );
  writeSkill(
    opencodeSkillsRoot,
    "opencode-global-smoke",
    "---\nname: opencode-global-smoke\ndescription: Global opencode fixture for native smoke.\n---\nGlobal opencode body.\n",
  );
  writeSkill(
    projectOpencodeSkillsRoot,
    "opencode-project-smoke",
    "---\nname: opencode-project-smoke\ndescription: Project opencode fixture for native smoke.\n---\nProject opencode body.\n",
  );
  const codexTargetSkillPath = realpathSync(
    join(projectCodexSkillsRoot, "codex-project-smoke", "SKILL.md"),
  );
  const codexNonTargetSkillPath = join(root, "unrelated-codex-skill", "SKILL.md");
  writeFileSync(
    codexUserConfig,
    [
      "# fixture comment preserved by Codex config patch",
      'model = "fixture-model"',
      "",
      "[sandbox]",
      'mode = "read-only"',
      "",
      "[[skills.config]]",
      `path = "${escapeTomlBasicString(codexTargetSkillPath)}"`,
      "enabled = true",
      "",
      "[[skills.config]]",
      `path = "${escapeTomlBasicString(codexNonTargetSkillPath)}"`,
      "enabled = false",
      "",
      "[[skills.config]]",
      `path = "${escapeTomlBasicString(codexTargetSkillPath)}"`,
      "enabled = true",
      "",
      "[[skills.config]]",
      `path = "${escapeTomlBasicString(codexNonTargetSkillPath)}"`,
      "enabled = false",
      "",
    ].join("\n"),
  );
  return {
    appData,
    codexNonTargetSkillPath,
    codexTargetSkillPath,
    codexUserConfig,
    home,
    projectCodexConfig,
    projectCwd,
    projectOpencodeConfig,
    projectRoot,
    realOpencodeConfigSnapshot,
    root,
  };
}

function snapshotRealOpencodeConfig() {
  const realHome = process.env.HOME;
  if (!realHome) {
    fail("HOME is not set; cannot verify real opencode config isolation");
  }
  return [
    join(realHome, ".config", "opencode"),
    join(realHome, ".config", "opencode", "skills"),
  ].map(snapshotPathState);
}

function snapshotPathState(path) {
  if (!existsSync(path)) {
    return { exists: false, path };
  }
  const stat = statSync(path);
  return {
    exists: true,
    isDirectory: stat.isDirectory(),
    mtimeMs: stat.mtimeMs,
    path,
  };
}

function assertRealOpencodeConfigUntouched(snapshot) {
  for (const before of snapshot) {
    const after = snapshotPathState(before.path);
    if (before.exists !== after.exists) {
      fail(
        `fixture run touched real opencode config path ${before.path}: ` +
          `exists changed from ${before.exists} to ${after.exists}`,
      );
    }
    if (!before.exists) {
      continue;
    }
    if (before.isDirectory !== after.isDirectory || before.mtimeMs !== after.mtimeMs) {
      fail(`fixture run modified real opencode config path ${before.path}`);
    }
  }
  note("fixture opencode isolation passed: real HOME config paths unchanged");
}

function writeSkill(skillsRoot, name, content) {
  const dir = join(skillsRoot, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "SKILL.md"), content);
}

function escapeTomlBasicString(value) {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll("\b", "\\b")
    .replaceAll("\t", "\\t")
    .replaceAll("\n", "\\n")
    .replaceAll("\f", "\\f")
    .replaceAll("\r", "\\r")
    .replaceAll('"', '\\"');
}

function setLaunchEnv(env) {
  for (const [key, value] of Object.entries(env)) {
    const result = tryRun("launchctl", ["setenv", key, value]);
    if (!result.ok) {
      fail(result.stderr || `failed to set launch env ${key}`);
    }
  }
}

function unsetLaunchEnv(keys) {
  for (const key of keys) {
    tryRun("launchctl", ["unsetenv", key]);
  }
}

function quitApp() {
  tryRun("osascript", ["-e", `tell application id "${bundleId}" to quit`]);
}

function waitForNoProcess(timeoutMs = 5_000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const result = tryRun("pgrep", ["-x", processName]);
    if (!result.ok || result.stdout.length === 0) {
      return;
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
  }
  fail(`timed out waiting for existing ${processName} to exit`);
}

function terminateExistingApp() {
  quitApp();
  const result = tryRun("pgrep", ["-x", processName]);
  if (result.ok && result.stdout.length > 0) {
    tryRun("pkill", ["-x", processName]);
  }
  waitForNoProcess();
}

function launchApp(env) {
  setLaunchEnv(env);
  const result = tryRun("open", ["-n", appPath]);
  unsetLaunchEnv(Object.keys(env));
  if (!result.ok) {
    fail(result.stderr || "failed to launch app with open");
  }
  const pid = waitForProcess();
  const windowId = waitForWindow();
  note(`launched ${processName} pid ${pid} window ${windowId}`);
  return { pid, windowId };
}

function waitForProcess(timeoutMs = 10_000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const result = tryRun("pgrep", ["-x", processName]);
    if (result.ok && result.stdout.length > 0) {
      return result.stdout.split("\n")[0];
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
  }
  fail(`timed out waiting for ${processName} to start`);
}

function waitForWindow(timeoutMs = 10_000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const result = visibleWindowId();
    if (result) {
      return result;
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
  }
  const sessionBlocker = currentSessionBlocker();
  fail(sessionBlocker ?? `window-not-found: timed out waiting for visible ${appName} window`);
}

function currentSessionBlocker() {
  const swift = `
import CoreGraphics
import Foundation

if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
   let locked = session["CGSSessionScreenIsLocked"] as? Bool,
   locked {
    print("locked-session: macOS session is locked; refusing UI evidence.")
    exit(6)
}
exit(0)
`;
  const result = tryRun("swift", ["-e", swift]);
  if (!result.ok) {
    return result.stderr || result.stdout || "tool-layer-unknown: unable to read macOS session state";
  }
  if (result.stdout) {
    return result.stdout;
  }
  return null;
}

function visibleWindowId() {
  const swift = `
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.dropFirst().first ?? "SkillsCopilot"
guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    exit(2)
}

for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == owner else { continue }
    guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    guard let id = window[kCGWindowNumber as String] else { continue }
    print(id)
    exit(0)
}
exit(1)
`;
  const result = tryRun("swift", ["-e", swift, appName]);
  return result.ok ? result.stdout : null;
}

function captureAppWindow() {
  const sessionBlocker = currentSessionBlocker();
  if (sessionBlocker) {
    fail(formatValidationBlocker(sessionBlocker, "capture-window"));
  }
  tryRun("caffeinate", ["-u", "-t", "3"]);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1_000);
  const result = tryRun("./script/capture_app_window.sh", [appName, screenshotPath]);
  if (!result.ok) {
    fail(formatValidationBlocker(
      result.stderr ||
        result.stdout ||
        "screen-recording-permission: failed to capture app window; check macOS Screen Recording permission for the invoking terminal",
      "capture-window",
    ));
  }
  note(result.stdout);
}

function callService(method, params, env) {
  const envelope = callServiceEnvelope(method, params, env);
  if (!envelope.ok) {
    fail(`${method} returned ${envelope.error?.code}: ${envelope.error?.message}`);
  }
  return envelope.result;
}

function expectServiceError(method, params, env, matcher, label) {
  const envelope = callServiceEnvelope(method, params, env);
  if (envelope.ok) {
    fail(`${label} unexpectedly succeeded`);
  }
  const message = `${envelope.error?.code ?? ""}: ${envelope.error?.message ?? ""}`;
  if (!matcher.test(message)) {
    fail(`${label} returned unexpected error: ${message}`);
  }
  return envelope.error;
}

function callServiceEnvelope(method, params, env) {
  const request = JSON.stringify({
    id: `smoke-${method}`,
    method,
    params,
  });
  const result = tryRun(serviceBinary, [], {
    input: request,
    env: { ...process.env, ...env },
  });
  if (!result.ok) {
    fail(result.stderr || `service failed for ${method}`);
  }
  let envelope;
  try {
    envelope = JSON.parse(result.stdout);
  } catch {
    fail(`invalid service JSON for ${method}: ${result.stdout}`);
  }
  return envelope;
}

function runFixtureServiceSmoke(env) {
  const status = callService("service.status", {}, env);
  if (status.protocol_version !== 1) {
    fail(`unexpected protocol version ${status.protocol_version}`);
  }
  const scan = callService("catalog.scanClaude", {}, env);
  if (scan.scanned_count !== 3) {
    fail(`expected 3 scanned skills, got ${scan.scanned_count}`);
  }
  const skills = callService("catalog.listSkills", {}, env);
  const alpha = skills.find((skill) => skill.name === "alpha-review");
  if (!alpha) {
    fail("alpha-review fixture missing after scan");
  }
  const disabled = callService(
    "config.toggleSkill",
    { instance_id: alpha.id, on: false },
    env,
  );
  if (disabled.enabled !== false) {
    fail("toggle off did not disable alpha-review");
  }
  const enabled = callService(
    "config.toggleSkill",
    { instance_id: alpha.id, on: true },
    env,
  );
  if (enabled.enabled !== true) {
    fail("toggle on did not re-enable alpha-review");
  }
  const settings = callService("config.readClaudeSettings", {}, env);
  const saved = callService(
    "config.saveClaudeSettings",
    { content: `${settings.content.trim() || "{}"}\n` },
    env,
  );
  if (!saved.exists) {
    fail("settings save did not return an existing document");
  }
  const snapshots = callService("snapshot.list", {}, env);
  if (!Array.isArray(snapshots) || snapshots.length === 0) {
    fail("expected snapshots after toggle/settings write flow");
  }
  const preview = callService(
    "snapshot.previewRollback",
    { snapshot_id: snapshots[0].id },
    env,
  );
  if (!preview.snapshot?.id) {
    fail("snapshot preview did not return snapshot payload");
  }
  callService("snapshot.rollback", { snapshot_id: snapshots[0].id }, env);
  note("fixture service smoke passed: scan, toggle, settings save, preview, rollback");
  return status;
}

function runFixtureProjectContextSmoke(env, fixture, status) {
  const baseScan = callService("catalog.scanAll", {}, env);
  assertSkillPresent(
    baseScan.skills,
    "codex",
    "codex-user-smoke",
    "user Codex fixture missing from scanAll",
  );
  assertSkillNotCurrentVisible(
    baseScan.skills,
    "codex-project-smoke",
    "project Codex fixture should not be visible before project context is active",
  );
  assertFixtureOpencodeGlobalSmoke(baseScan.skills);

  const methods = new Set(status.supported_methods ?? []);
  const hasProjectContextApi =
    methods.has("project.getContext") &&
    methods.has("project.setContext") &&
    methods.has("project.clearContext");

  if (!hasProjectContextApi) {
    const projectEnv = {
      ...env,
      SKILLS_COPILOT_PROJECT_CWD: fixture.projectCwd,
      SKILLS_COPILOT_PROJECT_ROOT: fixture.projectRoot,
    };
    const projectScan = callService("catalog.scanAll", {}, projectEnv);
    assertSkillPresent(
      projectScan.skills,
      "codex",
      "codex-project-smoke",
      "project Codex fixture missing from env project scanAll fallback",
    );
    runFixtureOpencodeReadOnlySmoke(projectScan.skills, projectEnv);
    runFixtureCodexConfigHardeningSmoke(projectEnv, fixture, projectScan.skills);
    note(
      "project context API unavailable; verified env project scanAll fallback only " +
        "(waiting for project.getContext/project.setContext/project.clearContext)",
    );
    return;
  }

  const initialContext = callService("project.getContext", {}, env);
  assertProjectContextState(initialContext, false, "initial project context");

  const setContext = callService(
    "project.setContext",
    {
      current_cwd: fixture.projectCwd,
      name: "Smoke Fixture Project",
      root_path: fixture.projectRoot,
    },
    env,
  );
  assertProjectContextState(setContext, true, "set project context");

  const activeContext = callService("project.getContext", {}, env);
  assertProjectContextState(activeContext, true, "active project context");

  const projectScan = callService("catalog.scanAll", {}, env);
  assertSkillPresent(
    projectScan.skills,
    "codex",
    "codex-project-smoke",
    "project Codex fixture missing after project.setContext -> scanAll",
  );
  runFixtureOpencodeWritableSmoke(projectScan.skills, env, fixture);
  runFixtureCodexConfigHardeningSmoke(env, fixture, projectScan.skills);

  const clearContext = callService("project.clearContext", {}, env);
  assertProjectContextState(clearContext, false, "clear project context");

  const clearedContext = callService("project.getContext", {}, env);
  assertProjectContextState(clearedContext, false, "cleared project context");

  const clearedScan = callService("catalog.scanAll", {}, env);
  assertSkillPresent(
    clearedScan.skills,
    "codex",
    "codex-user-smoke",
    "user Codex fixture missing after project.clearContext -> scanAll",
  );
  assertSkillNotCurrentVisible(
    clearedScan.skills,
    "codex-project-smoke",
    "project Codex fixture remained current/visible after project.clearContext -> scanAll",
  );
  note("fixture project context smoke passed: setContext, scanAll project visibility, clearContext");
}

function assertFixtureOpencodeGlobalSmoke(skills) {
  assertSkillPresent(
    skills,
    "opencode",
    "opencode-global-smoke",
    "global opencode fixture missing from no-project scanAll",
  );
  assertSkillNotCurrentVisible(
    skills,
    "opencode-project-smoke",
    "project opencode fixture should not be visible before project context is active",
    "opencode",
  );
  note("fixture opencode global smoke passed: native global root visible without project context");
}

function runFixtureOpencodeWritableSmoke(skills, env, fixture) {
  const projectSkill = assertSkillPresent(
    skills,
    "opencode",
    "opencode-project-smoke",
    "project opencode fixture missing after project context scanAll",
  );
  if (existsSync(fixture.projectOpencodeConfig)) {
    fail(`project opencode config should not exist before toggle: ${fixture.projectOpencodeConfig}`);
  }
  const toggled = callService(
    "config.toggleSkill",
    { instance_id: projectSkill.id, on: false },
    env,
  );
  if (toggled.agent !== "opencode" || toggled.enabled !== false) {
    fail("opencode toggle did not return a disabled opencode skill");
  }
  const config = JSON.parse(readFileSync(fixture.projectOpencodeConfig, "utf8"));
  if (config?.permission?.skill?.["opencode-project-smoke"] !== "deny") {
    fail("opencode project config missing managed permission.skill deny");
  }
  const rescanned = callService("catalog.scanAll", {}, env);
  const disabled = assertSkillPresent(
    rescanned.skills,
    "opencode",
    "opencode-project-smoke",
    "project opencode fixture missing after writable toggle rescan",
    { allowDisabled: true },
  );
  if (disabled.enabled !== false || disabled.state !== "disabled") {
    fail("opencode rescan did not preserve disabled permission.skill state");
  }
  note("fixture opencode smoke passed: project root visible, toggle wrote permission.skill deny, rescan preserved disabled state");
}

function runFixtureCodexConfigHardeningSmoke(env, fixture, skills) {
  if (existsSync(fixture.projectCodexConfig)) {
    fail(`project Codex config should not exist before toggle: ${fixture.projectCodexConfig}`);
  }

  const projectSkill = assertSkillPresent(
    skills,
    "codex",
    "codex-project-smoke",
    "project Codex fixture missing before config hardening toggle",
  );

  const seededConfig = readFixtureCodexConfig(fixture);
  assertCodexConfigPreserved(seededConfig, fixture, "seeded Codex config");
  assertPathOccurrence(
    seededConfig,
    fixture.codexTargetSkillPath,
    2,
    "seeded target duplicate entries",
  );
  assertPathOccurrence(
    seededConfig,
    fixture.codexNonTargetSkillPath,
    2,
    "seeded non-target duplicate entries",
  );

  const disabled = callService(
    "config.toggleSkill",
    { instance_id: projectSkill.id, on: false },
    env,
  );
  if (disabled.enabled !== false) {
    fail("Codex project toggle off did not disable codex-project-smoke");
  }
  if (existsSync(fixture.projectCodexConfig)) {
    fail(`Codex project toggle wrote project config: ${fixture.projectCodexConfig}`);
  }
  const disabledConfig = readFixtureCodexConfig(fixture);
  assertCodexConfigPreserved(disabledConfig, fixture, "disabled Codex config");
  assertPathOccurrence(
    disabledConfig,
    fixture.codexTargetSkillPath,
    1,
    "disabled target normalized entries",
  );
  assertPathOccurrence(
    disabledConfig,
    fixture.codexNonTargetSkillPath,
    2,
    "disabled non-target preserved entries",
  );
  assertConfigBlock(
    disabledConfig,
    fixture.codexTargetSkillPath,
    "enabled = false",
    "disabled target block",
  );

  const enabled = callService(
    "config.toggleSkill",
    { instance_id: projectSkill.id, on: true },
    env,
  );
  if (enabled.enabled !== true) {
    fail("Codex project toggle on did not re-enable codex-project-smoke");
  }
  if (existsSync(fixture.projectCodexConfig)) {
    fail(`Codex project re-enable wrote project config: ${fixture.projectCodexConfig}`);
  }
  const enabledConfig = readFixtureCodexConfig(fixture);
  assertCodexConfigPreserved(enabledConfig, fixture, "re-enabled Codex config");
  assertPathOccurrence(
    enabledConfig,
    fixture.codexTargetSkillPath,
    0,
    "re-enabled target removed entries",
  );
  assertPathOccurrence(
    enabledConfig,
    fixture.codexNonTargetSkillPath,
    2,
    "re-enabled non-target preserved entries",
  );
  note("fixture Codex config hardening smoke passed: user config only, duplicate target normalization, non-target preservation");
}

function readFixtureCodexConfig(fixture) {
  if (!existsSync(fixture.codexUserConfig)) {
    fail(`fixture Codex user config missing: ${fixture.codexUserConfig}`);
  }
  return readFileSync(fixture.codexUserConfig, "utf8");
}

function assertCodexConfigPreserved(content, fixture, label) {
  for (const expected of [
    "# fixture comment preserved by Codex config patch",
    'model = "fixture-model"',
    "[sandbox]",
    'mode = "read-only"',
  ]) {
    if (!content.includes(expected)) {
      fail(`${label} did not preserve ${expected}`);
    }
  }
  if (!existsSync(fixture.codexUserConfig)) {
    fail(`${label} did not use fixture user Codex config`);
  }
}

function assertPathOccurrence(content, path, expected, label) {
  const count = content.split(path).length - 1;
  if (count !== expected) {
    fail(`${label}: expected ${expected} occurrences of ${path}, got ${count}`);
  }
}

function assertConfigBlock(content, path, expectedLine, label) {
  const block = content
    .split("[[skills.config]]")
    .slice(1)
    .find((candidate) => candidate.includes(path));
  if (!block) {
    fail(`${label} missing for ${path}`);
  }
  if (!block.includes(expectedLine)) {
    fail(`${label} did not include ${expectedLine}`);
  }
}

function assertSkillPresent(skills, agent, name, message, options = {}) {
  const skill = findSkill(skills, agent, name);
  if (!skill) {
    fail(message);
  }
  if (skill.state && skill.state !== "loaded" && !(options.allowDisabled && skill.state === "disabled")) {
    fail(`${message}; found ${name} with state ${skill.state}`);
  }
  return skill;
}

function assertSkillNotCurrentVisible(skills, name, message, agent = "codex") {
  const skill = findSkill(skills, agent, name);
  if (!skill) {
    return;
  }
  if (skill.state === "missing" || skill.visible === false || skill.current === false) {
    note(`${name} retained in catalog as non-current (${describeSkillState(skill)})`);
    return;
  }
  fail(`${message}; found ${name} as ${describeSkillState(skill)}`);
}

function findSkill(skills, agent, name) {
  if (!Array.isArray(skills)) {
    fail("scan result did not include a skills array");
  }
  return skills.find((skill) => skill.agent === agent && skill.name === name);
}

function assertProjectContextState(state, expectActive, label) {
  if (!state || typeof state !== "object") {
    fail(`${label} did not return a project context state object`);
  }
  if (!Array.isArray(state.recent)) {
    fail(`${label} did not return recent project contexts`);
  }
  if (expectActive) {
    if (!state.active || typeof state.active !== "object") {
      fail(`${label} did not return an active project context`);
    }
    return;
  }
  if (state.active !== null && state.active !== undefined) {
    fail(`${label} should not have an active project context`);
  }
}

function describeSkillState(skill) {
  const fields = [
    `state=${skill.state ?? "unknown"}`,
    `scope=${skill.scope ?? "unknown"}`,
    `visible=${skill.visible ?? "unknown"}`,
    `current=${skill.current ?? "unknown"}`,
  ];
  return fields.join(", ");
}

function checkSystemLogs(pid) {
  const result = tryRun("/usr/bin/log", [
    "show",
    "--last",
    "5m",
    "--style",
    "compact",
    "--predicate",
    `processID == ${pid} AND (messageType == error OR messageType == fault)`,
  ]);
  if (!result.ok) {
    fail(result.stderr || "failed to read macOS unified log");
  }

  const entries = result.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("Timestamp ") && line !== "}");
  const unknown = entries.filter(
    (line) => !knownBenignLogPatterns.some((pattern) => pattern.test(line)),
  );
  note(
    `system log check: ${entries.length} error/fault lines, ${unknown.length} unknown after filters`,
  );
  if (unknown.length > 0) {
    for (const line of unknown.slice(0, 20)) {
      console.error(line);
    }
    fail("system log check found unknown app error/fault lines");
  }
}

function main() {
  verifyBundle();
  verifyBundleFreshness();
  if (bundleOnly) {
    note("bundle-only mode; launch and fixture checks skipped");
    return;
  }

  let fixture = null;
  let pid = null;
  try {
    fixture = fixtureData ? createFixtureEnvironment() : null;
    const env = fixture
      ? {
          SKILLS_COPILOT_APP_DATA_DIR: fixture.appData,
          SKILLS_COPILOT_HOME: fixture.home,
        }
      : {};
    if (fixture) {
      note(`fixture data enabled: ${fixture.root}`);
    }
    terminateExistingApp();
    pid = launchApp(env).pid;
    if (captureWindow) {
      captureAppWindow();
    }
    if (fixture) {
      const status = runFixtureServiceSmoke(env);
      runFixtureProjectContextSmoke(env, fixture, status);
      assertRealOpencodeConfigUntouched(fixture.realOpencodeConfigSnapshot);
    }
    if (checkLogs) {
      checkSystemLogs(pid);
    }
  } finally {
    if (!keepOpen) {
      terminateExistingApp();
    }
    if (fixture && !keepOpen) {
      rmSync(fixture.root, { force: true, recursive: true });
    }
  }
  note("native macOS app smoke completed");
}

try {
  main();
} catch (error) {
  if (error instanceof SmokeFailure) {
    console.error(`smoke: ${error.message}`);
  } else {
    console.error(error);
  }
  process.exit(1);
}
