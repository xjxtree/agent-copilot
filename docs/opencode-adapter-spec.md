# opencode Adapter Evidence Spec

> Evidence date: 2026-06-17. Current decision: opencode scans native roots, official `.claude` / `.agents` compatibility roots, and configured local `skills.paths` roots from JSON/JSONC config. `skills.urls` is recognized as a config boundary but remains metadata-only/no-fetch. Guarded writes remain limited to exact-name `permission.skill` patches in verified `opencode.json` targets, and tool-global installs remain limited to verified native opencode skill roots. V2.21 completed scan-accuracy, dedupe, and agent-metric alignment requirements; V2.93 completed configured local root scanning.

## Status

Scanner/parser implementation follows the current official OpenCode Agent Skills discovery set. It scans:

- Global native root: `~/.config/opencode/skills/<name>/SKILL.md`.
- Project native roots: `.opencode/skills/<name>/SKILL.md`, walking from `project_cwd` upward through ancestors until `project_root`.
- Global Claude-compatible root: `~/.claude/skills/<name>/SKILL.md`.
- Project Claude-compatible roots: `.claude/skills/<name>/SKILL.md`, walking from `project_cwd` upward through ancestors until `project_root`.
- Global agent-compatible root: `~/.agents/skills/<name>/SKILL.md`.
- Project agent-compatible roots: `.agents/skills/<name>/SKILL.md`, walking from `project_cwd` upward through ancestors until `project_root`.
- Configured local roots from `skills.paths` in readable global/project `opencode.json` or `opencode.jsonc`; paths are expanded, canonicalized, deduped, and constrained to the declaring scope.

Compatibility and configured roots are scan-only sources under the opencode adapter. They intentionally create cross-agent overlap with Claude/Codex roots when the same physical or named skill is available to multiple agents; the app should surface that through cross-agent analysis rather than hiding the opencode-visible skill.

V2.21 completed focus:

- 扫描准确性：canonicalize 根与路径后再去重，避免软链接、重叠根导致同一技能被计入多次。
- 去重规则：按 `agent/scope/path` 作为去重主键；同名但不同源 agent 的实例保留并由 `catalog.analysis` 公开重复来源，不做隐式吞并。
- 统计口径：统一 `catalog.scanAll.result.activity`、`catalog.analysis` 与 `app.stateSnapshot.health` 的 per-agent 计数含义，避免 filter 造成统计口径漂移。

Writable toggle support is enabled for app-managed strict JSON config files:

- Global skills patch `$HOME/.config/opencode/opencode.json`.
- Project skills patch the active project root `opencode.json`.
- Disable writes an exact skill-name rule under `permission.skill["<name>"] = "deny"`.
- Re-enable removes only an exact `"deny"` entry for that skill name; exact `"ask"` and `"allow"` entries are preserved.
- Every config toggle uses the existing snapshot, lock, atomic write, read-back verification, and rollback path.
- Tool-global install copies only the source `SKILL.md` into `$HOME/.config/opencode/skills/<name>/SKILL.md` or `<project>/.opencode/skills/<name>/SKILL.md`.

Remaining boundaries: JSONC/commented configs are read for configured local roots but are not mutated by the app's strict JSON writer; managed config, `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, and `OPENCODE_CONFIG_CONTENT` can still override local files at opencode runtime and remain read-only/out of scope for mutation; `skills.urls` stays metadata-only/no-fetch unless a future explicit confirmation flow is scoped.

Local validation on 2026-06-08:

- `opencode --version` returned `1.16.2`.
- `$HOME/.config/opencode/` exists locally.
- `$HOME/.config/opencode/skills/` exists locally.
- `$HOME/.config/opencode/opencode.json` exists locally.
- No local opencode config content was inspected or modified.
- Disposable read-only check: with temporary `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR`, and a temporary Git project, `opencode debug skill --pure` returned the synthetic `global-review`, `project-release`, and `nested-local` fixtures plus the built-in `customize-opencode` skill. No real config was read or modified. This confirms native global/project skill discovery and upward nested project discovery, but it does not verify writable permission mutation.
- Disposable malformed check: the same command surfaced `name-mismatch` as `different-name` and surfaced a missing-description skill without a description; a missing-name skill was omitted. The product keeps this app's stricter parser contract below so malformed rows become broken records rather than silently changing identity or disappearing.
- Disposable writable check on 2026-06-09: `opencode debug skill --pure` continued listing synthetic skills even when temporary `OPENCODE_CONFIG_DIR/opencode.json` or project `opencode.json` set `permission.skill["<name>"] = "deny"`. Treat that command as discovery evidence only, not as proof of permission filtering. V2.12 therefore relies on official permission semantics for hide/reject behavior and verifies the app-owned write/snapshot/rollback/read-back path with fixture tests.

Disposable command shape used:

```sh
tmp=$(mktemp -d)
mkdir -p "$tmp/home" "$tmp/config/skills/global-review" \
  "$tmp/project/.opencode/skills/project-release" \
  "$tmp/project/packages/app/.opencode/skills/nested-local"
cd "$tmp/project" && git init -q
cd packages/app
HOME="$tmp/home" \
OPENCODE_CONFIG_DIR="$tmp/config" \
XDG_CONFIG_HOME="$tmp/home/.config" \
opencode debug skill --pure
```

Exact relevant result: the JSON array contained `customize-opencode` with `location: "<built-in>"`, `nested-local` at the nested project `.opencode/skills` path, `project-release` at the project root `.opencode/skills` path, and `global-review` at `$OPENCODE_CONFIG_DIR/skills/global-review/SKILL.md`.

## Official Evidence

Official docs and source used on 2026-06-17:

- OpenCode Agent Skills: <https://opencode.ai/docs/skills/>
- OpenCode Config: <https://opencode.ai/docs/config>
- OpenCode config schema: <https://opencode.ai/config.json>
- OpenCode skill loader source: <https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/skill/index.ts>
- OpenCode skill URL discovery source: <https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/skill/discovery.ts>
- OpenCode Agents: <https://opencode.ai/docs/agents/>
- OpenCode Commands: <https://opencode.ai/docs/commands/>
- OpenCode Rules: <https://opencode.ai/docs/rules/>

The Agent Skills page is the canonical source for fixed skill roots; the config schema and source evidence confirm `skills.paths` and `skills.urls`. Agents and commands are related opencode concepts, but they should not be mapped into this app's `SkillInstance` unless product scope explicitly expands beyond skills.

## Directory And Format Evidence

Official opencode skill paths:

| Scope | Path |
| --- | --- |
| Project opencode | `.opencode/skills/<name>/SKILL.md` |
| Global opencode | `~/.config/opencode/skills/<name>/SKILL.md` |
| Project Claude-compatible | `.claude/skills/<name>/SKILL.md` |
| Global Claude-compatible | `~/.claude/skills/<name>/SKILL.md` |
| Project agent-compatible | `.agents/skills/<name>/SKILL.md` |
| Global agent-compatible | `~/.agents/skills/<name>/SKILL.md` |

OpenCode itself can load native roots plus Claude/agent-compatible roots. The product adapter now mirrors those documented roots:

- Include: `.opencode/skills/<name>/SKILL.md` found while walking from `project_cwd` upward to `project_root`.
- Include: `~/.config/opencode/skills/<name>/SKILL.md`.
- Include: `.claude/skills/<name>/SKILL.md` found while walking from `project_cwd` upward to `project_root`.
- Include: `~/.claude/skills/<name>/SKILL.md`.
- Include: `.agents/skills/<name>/SKILL.md` found while walking from `project_cwd` upward to `project_root`.
- Include: `~/.agents/skills/<name>/SKILL.md`.
- Include: configured local `skills.paths` directories from readable global/project JSON/JSONC config after expansion, canonicalization, dedupe, and scope checks.
- Exclude: built-in `<built-in>` skills and non-filesystem skills.
- Exclude: `skills.urls` network fetching; URL entries are metadata-only and never fetched during scan or diagnostics.

`SKILL.md` must start with YAML frontmatter. Recognized fields:

- `name` required
- `description` required
- `license` optional
- `compatibility` optional
- `metadata` optional string-to-string map

Unknown frontmatter fields are ignored. `name` must be 1-64 characters, lowercase alphanumeric with single hyphen separators, must not start/end with a hyphen, must not contain `--`, and must match the containing directory name.

Malformed contract:

- Missing `name`: produce a broken/malformed skill record.
- Missing `description`: produce a broken/malformed skill record.
- `name` not matching the containing directory: produce a broken/malformed skill record.
- A malformed skill must not abort scanning other roots.

## Config And Toggle Evidence

Official config paths and precedence:

- Global config: `~/.config/opencode/opencode.json`
- Project config: `opencode.json` in the project root, found by walking from current directory up to the nearest Git directory
- `.opencode` directories: agents, commands, plugins, skills, tools, themes
- Custom config file: `OPENCODE_CONFIG`
- Custom config directory: `OPENCODE_CONFIG_DIR`
- Managed config exists and must be treated as read-only

Skill access is controlled by pattern-based permissions in `opencode.json`:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

Official behavior:

- `allow`: skill loads immediately.
- `deny`: skill is hidden from the agent and access is rejected.
- `ask`: user is prompted before loading.

OpenCode can also disable the entire `skill` tool for an agent, but that is an agent/tool capability toggle, not an individual skill toggle.

## Adapter Decision

Read-only state: **implemented in V2.4**. The scanner models opencode-native skills under `.opencode/skills` and `~/.config/opencode/skills` using the parser/scan contract fixtures below.

Compatibility root state: **implemented as scan-only**. `.claude/skills` and `.agents/skills` are included under the opencode adapter because current OpenCode official docs list them as discoverable. Claude/Codex ownership and duplicates should be explained by cross-agent analysis rather than suppressing opencode rows.

Configured local root state: **implemented in V2.93 as scan-only**. JSON/JSONC `skills.paths` entries are read from declared user/project config files, expanded relative to the declaring scope, canonicalized, deduped, and exposed as `RootSource::Configured`. They are not install targets and do not become direct file-write targets.

Writable state: **verified for V2.12 guarded implementation**:

- Disable writes `permission.skill["<exact-name>"] = "deny"` based on official opencode permission semantics.
- Re-enable deletes only an exact `"deny"` entry and falls back to inherited/default behavior rather than forcing `"allow"`.
- Global skills write only global config; project skills write only the active project root config.
- App tests verify snapshot creation, atomic write/read-back, rollback, project-context guards, and tool-global install roots without touching real user HOME.

Still deferred:

- JSONC/commented config mutation; strict JSON is required for app-managed writes.
- Runtime proof that `opencode debug skill --pure` reflects permission filtering; it currently appears to be discovery-only.
- How to surface `"ask"` in UI; it is neither fully enabled nor disabled.
- Fetching or caching `skills.urls`; URL entries require a future explicit confirmation and cache/rollback design before any network access.
- Whether managed config or `OPENCODE_CONFIG_CONTENT` can make a local write ineffective.
- Whether `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, remote org config, or managed settings should be surfaced in diagnostics beyond the current documented blockers.

## Fixtures

Parser/scan contract fixtures live under `fixtures/opencode/`.

- `fixtures/opencode/user-home/.config/opencode/skills/global-review/SKILL.md`: valid global native root.
- `fixtures/opencode/project/.opencode/skills/project-release/SKILL.md`: project opencode skill shape.
- `fixtures/opencode/project/packages/app/.opencode/skills/nested-local/SKILL.md`: valid nested project root used to confirm walking from `project_cwd` upward to `project_root`.
- `fixtures/opencode/config/opencode-deny-skill.json`: candidate config fragment showing permission-based hidden/read-only state.
- `fixtures/opencode/broken/name-mismatch/SKILL.md`: malformed sample where `name` does not match the containing directory.
- `fixtures/opencode/broken/missing-description/SKILL.md`: malformed sample with required `description` missing.
- `fixtures/opencode/broken/missing-name/SKILL.md`: malformed sample with required `name` missing.

The config fixture is historical/disposable writable evidence only. V2.12 guarded writes use the verified app-owned strict JSON writer, snapshot/rollback/read-back tests, and exact `permission.skill` semantics; this fixture is not authority for new write scope. V2.93 configured-root tests create temporary JSON/JSONC configs dynamically so duplicate paths, project-boundary checks, and metadata-only `skills.urls` behavior are verified without touching real opencode config.
