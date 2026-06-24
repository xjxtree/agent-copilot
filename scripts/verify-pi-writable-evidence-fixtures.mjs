#!/usr/bin/env node
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, "..");
const sourceRoot = join(repoRoot, "fixtures", "pi", "writable-evidence");
const tempRoot = mkdtempSync(join(tmpdir(), "skills-copilot-pi-writable-evidence-"));
const workRoot = join(tempRoot, "fixture");

function fail(message) {
  throw new Error(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function assertUnderTemp(path) {
  const resolved = resolve(path);
  const temp = resolve(tempRoot) + sep;
  assert(resolved === resolve(tempRoot) || resolved.startsWith(temp), `refusing non-temp path: ${resolved}`);
}

function readJson(relativePath) {
  const path = join(workRoot, relativePath);
  assertUnderTemp(path);
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(relativePath, value) {
  const path = join(workRoot, relativePath);
  assertUnderTemp(path);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function isDisabled(config, skillName) {
  return Array.isArray(config.disabledSkills) && config.disabledSkills.includes(skillName);
}

function disableSkill(config, skill) {
  if ((skill.scope === "project" || skill.scope === "package") && config.trust?.projectRootTrusted === false) {
    return { changed: false, blocked: true, reason: "project is explicitly marked untrusted" };
  }
  const disabledSkills = Array.isArray(config.disabledSkills) ? [...config.disabledSkills] : [];
  if (!disabledSkills.includes(skill.name)) disabledSkills.push(skill.name);
  return { changed: true, blocked: false, config: { ...config, disabledSkills } };
}

function enableSkill(config, skill) {
  const disabledSkills = Array.isArray(config.disabledSkills)
    ? config.disabledSkills.filter((name) => name !== skill.name)
    : [];
  return { ...config, disabledSkills };
}

function packageEnabled(config, source, skillName) {
  const pkg = config.packages?.find((entry) => entry.source === source);
  return Array.isArray(pkg?.skills) && pkg.skills.includes(skillName);
}

try {
  assert(existsSync(sourceRoot), `missing fixture root: ${sourceRoot}`);
  cpSync(sourceRoot, workRoot, { recursive: true });
  assertUnderTemp(workRoot);

  const manifest = readJson("manifest.json");
  assert(manifest.notice.includes("guarded Pi native/compatibility toggle support"), "manifest must keep guarded toggle status explicit");
  assert(manifest.notice.includes("native-root direct install are implemented"), "manifest must keep native direct install status explicit");
  assert(manifest.notice.includes("package install/remove and .agents direct installs remain blocked"), "manifest must keep blocked write scope explicit");

  for (const skill of manifest.skills) {
    const skillPath = join(workRoot, skill.path);
    assertUnderTemp(skillPath);
    const content = readFileSync(skillPath, "utf8");
    assert(content.includes(`name: ${skill.name}`), `skill name mismatch for ${skill.name}`);
    assert(content.includes("guarded_toggle: implemented"), `missing guarded toggle marker for ${skill.name}`);
    assert(content.includes("package_install_writable: blocked"), `missing package install blocked marker for ${skill.name}`);
    assert(content.includes("agents_direct_install_writable: blocked"), `missing agents direct install blocked marker for ${skill.name}`);
  }

  const enabled = readJson(manifest.cases.enabled);
  for (const skill of manifest.skills) {
    assert(!isDisabled(enabled, skill.name), `${skill.name} should start enabled`);
  }

  const globalSkill = manifest.skills.find((skill) => skill.scope === "global");
  const projectSkill = manifest.skills.find((skill) => skill.scope === "project");
  const packageSkill = manifest.skills.find((skill) => skill.scope === "package");
  assert(globalSkill && projectSkill && packageSkill, "manifest must include global/project/package skills");

  const disabledGlobal = readJson(manifest.cases.disabledGlobal);
  assert(isDisabled(disabledGlobal, globalSkill.name), "disabled global config must disable global skill");

  const disabledProjectPackage = readJson(manifest.cases.disabledProjectPackage);
  assert(isDisabled(disabledProjectPackage, projectSkill.name), "disabled project config must disable project skill");
  assert(isDisabled(disabledProjectPackage, packageSkill.name), "disabled package config must disable package skill");

  const packageFiltered = readJson(manifest.cases.packageFilterDisabled);
  assert(!packageEnabled(packageFiltered, packageSkill.package, packageSkill.name), "package filter must hide package skill");

  let invalidRejected = false;
  try {
    readJson(manifest.cases.invalidJson);
  } catch {
    invalidRejected = true;
  }
  assert(invalidRejected, "invalid JSON fixture must be rejected");

  const untrusted = readJson(manifest.cases.untrustedProject);
  const blockedProjectToggle = disableSkill(untrusted, projectSkill);
  assert(blockedProjectToggle.blocked, "untrusted project must block project toggle");
  const blockedPackageToggle = disableSkill(untrusted, packageSkill);
  assert(blockedPackageToggle.blocked, "untrusted project must block package toggle");
  const allowedGlobalToggle = disableSkill(untrusted, globalSkill);
  assert(allowedGlobalToggle.changed && isDisabled(allowedGlobalToggle.config, globalSkill.name), "global toggle should not depend on project trust");

  const tempConfigPath = "config/pi-settings.enabled.json";
  let mutableConfig = readJson(tempConfigPath);
  for (const skill of manifest.skills) {
    const result = disableSkill(mutableConfig, skill);
    assert(!result.blocked, `${skill.name} should disable in trusted temp config`);
    mutableConfig = result.config;
  }
  writeJson(tempConfigPath, mutableConfig);
  const afterDisable = readJson(tempConfigPath);
  for (const skill of manifest.skills) {
    assert(isDisabled(afterDisable, skill.name), `${skill.name} should be disabled after temp write`);
  }
  for (const skill of manifest.skills) {
    mutableConfig = enableSkill(mutableConfig, skill);
  }
  writeJson(tempConfigPath, mutableConfig);
  const afterReenable = readJson(tempConfigPath);
  for (const skill of manifest.skills) {
    assert(!isDisabled(afterReenable, skill.name), `${skill.name} should be re-enabled after temp write`);
  }

  const rollbackBefore = readJson(manifest.cases.rollbackBefore);
  const rollbackAfter = readJson(manifest.cases.rollbackAfterDisable);
  assert(rollbackAfter.disabledSkills.length > rollbackBefore.disabledSkills.length, "rollback fixture should model a changed disable state");
  writeJson("rollback/pi-settings.after-disable.json", rollbackBefore);
  const rolledBack = readJson(manifest.cases.rollbackAfterDisable);
  assert(JSON.stringify(rolledBack) === JSON.stringify(rollbackBefore), "rollback temp copy should restore baseline config");

  console.log(`Pi writable evidence fixture verifier passed in temp root: ${tempRoot}`);
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}
