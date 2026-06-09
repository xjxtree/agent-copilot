# opencode Adapter Evidence Spec

> Evidence date: 2026-06-09. V2.12 decision: opencode is upgraded from native-root read-only to **verified writable** for guarded app-managed writes. Writes are limited to exact-name `permission.skill` patches in verified `opencode.json` targets and tool-global installs into verified native opencode skill roots.

## Status

Read-only scanner/parser implementation is approved for first-class opencode-native skills only. V2.4 must scan:

- Global native root: `~/.config/opencode/skills/<name>/SKILL.md`.
- Project native roots: `.opencode/skills/<name>/SKILL.md`, walking from `project_cwd` upward through ancestors until `project_root`.

V2.4 must not scan opencode compatibility roots (`.agents/skills`, `~/.agents/skills`, `.claude/skills`, or `~/.claude/skills`) under the opencode adapter. Those roots are intentionally deferred so opencode does not duplicate Codex/Claude catalog entries.

Writable toggle support is enabled for app-managed strict JSON config files:

- Global skills patch `$HOME/.config/opencode/opencode.json`.
- Project skills patch the active project root `opencode.json`.
- Disable writes an exact skill-name rule under `permission.skill["<name>"] = "deny"`.
- Re-enable removes only an exact `"deny"` entry for that skill name; exact `"ask"` and `"allow"` entries are preserved.
- Every config toggle uses the existing snapshot, lock, atomic write, read-back verification, and rollback path.
- Tool-global install copies only the source `SKILL.md` into `$HOME/.config/opencode/skills/<name>/SKILL.md` or `<project>/.opencode/skills/<name>/SKILL.md`.

Remaining boundaries: JSONC/commented configs are not mutated by the app's strict JSON writer; managed config and `OPENCODE_CONFIG_CONTENT` can still override local files at opencode runtime; compatibility roots and custom `skills.paths` / `skills.urls` remain out of scope.

Local validation on 2026-06-08:

- `opencode --version` returned `1.16.2`.
- `$HOME/.config/opencode/` exists locally.
- `$HOME/.config/opencode/skills/` exists locally.
- `$HOME/.config/opencode/opencode.json` exists locally.
- No local opencode config content was inspected or modified.
- Disposable read-only check: with temporary `HOME`, `XDG_CONFIG_HOME`, `OPENCODE_CONFIG_DIR`, and a temporary Git project, `opencode debug skill --pure` returned the synthetic `global-review`, `project-release`, and `nested-local` fixtures plus the built-in `customize-opencode` skill. No real config was read or modified. This confirms native global/project skill discovery and upward nested project discovery, but it does not verify writable permission mutation.
- Disposable malformed check: the same command surfaced `name-mismatch` as `different-name` and surfaced a missing-description skill without a description; a missing-name skill was omitted. V2.4 should still use this app's stricter parser contract below so malformed rows become broken records rather than silently changing identity or disappearing.
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

Official docs used on 2026-06-08:

- OpenCode Agent Skills: <https://opencode.ai/docs/skills/>
- OpenCode Config: <https://opencode.ai/docs/config>
- OpenCode Agents: <https://opencode.ai/docs/agents/>
- OpenCode Commands: <https://opencode.ai/docs/commands/>
- OpenCode Rules: <https://opencode.ai/docs/rules/>

The Agent Skills page is the canonical source for this adapter evidence. Agents and commands are related opencode concepts, but they should not be mapped into this app's `SkillInstance` unless product scope explicitly expands beyond skills.

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

OpenCode itself can load native roots plus Claude/agent-compatible roots. V2.4 intentionally narrows the product adapter to native roots only:

- Include: `.opencode/skills/<name>/SKILL.md` found while walking from `project_cwd` upward to `project_root`.
- Include: `~/.config/opencode/skills/<name>/SKILL.md`.
- Exclude: `.claude/skills`, `~/.claude/skills`, `.agents/skills`, and `~/.agents/skills`.
- Exclude: built-in `<built-in>` skills and non-filesystem skills.
- Exclude: custom `skills.paths` / `skills.urls` from `opencode.json` until a later evidence pass defines duplicate handling, trust, and read-only provenance.

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

Read-only state: **approved for V2.4 implementation**. The scanner can model opencode-native skills under `.opencode/skills` and `~/.config/opencode/skills` using the parser/scan contract fixtures below.

Compatibility root state: **deferred**. Do not include `.claude/skills` or `.agents/skills` under the opencode adapter in V2.4. Claude/Codex ownership and duplicate suppression need a separate product decision.

Writable state: **verified for V2.12 guarded implementation**:

- Disable writes `permission.skill["<exact-name>"] = "deny"` based on official opencode permission semantics.
- Re-enable deletes only an exact `"deny"` entry and falls back to inherited/default behavior rather than forcing `"allow"`.
- Global skills write only global config; project skills write only the active project root config.
- App tests verify snapshot creation, atomic write/read-back, rollback, project-context guards, and tool-global install roots without touching real user HOME.

Still deferred:

- JSONC/commented config mutation; strict JSON is required for app-managed writes.
- Runtime proof that `opencode debug skill --pure` reflects permission filtering; it currently appears to be discovery-only.
- How to surface `"ask"` in UI; it is neither fully enabled nor disabled.
- Whether compatible `.claude/skills` and `.agents/skills` roots should ever be exposed under the opencode adapter or left to their native adapters to avoid duplicate catalog entries.
- Whether custom `skills.paths` / `skills.urls` should be scanned, and what trust/provenance labels they require.
- Whether managed config or `OPENCODE_CONFIG_CONTENT` can make a local write ineffective.

## Fixtures

Parser/scan contract fixtures live under `fixtures/opencode/`.

- `fixtures/opencode/user-home/.config/opencode/skills/global-review/SKILL.md`: valid global native root.
- `fixtures/opencode/project/.opencode/skills/project-release/SKILL.md`: project opencode skill shape.
- `fixtures/opencode/project/packages/app/.opencode/skills/nested-local/SKILL.md`: valid nested project root used to confirm walking from `project_cwd` upward to `project_root`.
- `fixtures/opencode/config/opencode-deny-skill.json`: candidate config fragment showing permission-based hidden/read-only state.
- `fixtures/opencode/broken/name-mismatch/SKILL.md`: malformed sample where `name` does not match the containing directory.
- `fixtures/opencode/broken/missing-description/SKILL.md`: malformed sample with required `description` missing.
- `fixtures/opencode/broken/missing-name/SKILL.md`: malformed sample with required `name` missing.

The config fixture remains writable-evidence only. It must not be used as authority for V2.4 writes.
