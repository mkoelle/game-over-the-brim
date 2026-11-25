# T-019: Vendor godot-ai 4.4.2 (Project Scope, Telemetry Off)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 2h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-022](../adr/ADR-022-dev-workflow-lean-trunk-and-model-tiering.md) §6
**Approval:** vendoring approved by the owner on 2026-11-24, at 4.4.2 or the latest release available at vendoring time, project-scoped with telemetry off.

### Goal

Install the `godot-ai` editor plugin in this project and wire a
**project-scoped** MCP entry for it. Claude Code can then edit scenes,
run the game and take screenshots for the T-005 spike. The owner's other
project (lab-godot, which uses godot-ai 3.2.4 through the global config)
must not be disturbed.

### Acceptance Criteria

- [x] `addons/godot_ai/` is vendored at the pinned release and enabled.
- [x] Telemetry is off, both in the editor setting and through
      `GODOT_AI_DISABLE_TELEMETRY=true` in the MCP entry's environment.
      *The entry also passes `--disable-telemetry`, which is what Configure renders when the setting is off.*
- [x] A project-scoped `godot-ai` MCP entry pins the matching server
      version (`godot-ai==4.4.2`). The global 3.2.4 entry for lab-godot
      still exists afterwards.
      *Met by substitution: `.mcp.json` was written by hand, and `~/.claude.json` was never read or touched, so the global entry is untouched by construction.*
- [ ] From a Claude Code session in this repo, a godot-ai call that reads
      the scene tree of `scenes/main.tscn` succeeds.
      *Met by substitution with a scripted stdio MCP client (see Assumptions). Pending owner: restart Claude Code in the repo, approve the project server, and call `scene_get_hierarchy`.*
- [x] `task ci` is green, and the plugin adds no parse errors.

### Context

- godot-ai: `hi-godot/godot-ai`, MIT, about 3.7k stars, needs Godot 4.7+.
  The latest release is v4.4.2 (2026-11-16). The installed global server
  is 3.2.4 (2026-08-27).
- Facts from the upstream README:
  - Install from the Asset Store, or extract to `addons/godot_ai/`.
  - "Never extract a new version over an existing `addons/godot_ai/`";
    upgrade with the dock's **Update** button.
  - The dock's **Configure** writes the client entry, pinning "the
    matching version, ports, and tool domains".
  - Set **Editor Settings → Plugins → `godot_ai/mcp_client_scope`** to
    `project` before pressing Configure.
  - **Warning:** "Configure removes existing `godot-ai` entries from every
    scope before writing the selected one". Pressing it can delete the
    global entry lab-godot depends on.
  - Telemetry: "Opt out with `GODOT_AI_DISABLE_TELEMETRY=true` … or in the
    editor."
- `.mcp.json` is gitignored today, because it held the OpenRouter key
  entry, and ADR-022 retired OpenRouter. A project-scoped Claude Code
  `.mcp.json` is meant to be committed, as long as it has no secrets.
- Ports: the server defaults to HTTP 8000 and WebSocket 9500. Two Godot
  editors running godot-ai at the same time (this project and lab-godot)
  would collide. If both are used together, give this project its own
  ports in the plugin settings, then re-Configure.

### Files Likely Affected

- `addons/godot_ai/` (vendored)
- `project.godot` (plugin enable and plugin settings)
- `.mcp.json` + `.gitignore` (project-scoped entry; un-ignore)

### Implementation Plan

1. Branch `chore/vendor-godot-ai`. Re-verify the latest release with
   `gh api repos/hi-godot/godot-ai/releases/latest`, and read the
   v4 notes (`docs/v4-migration.md`).
2. Back up the global entry:
   `python3 -c "import json;print(json.dumps(json.load(open('$HOME/.claude.json'))['mcpServers']['godot-ai']))"`
3. Install the release into `addons/godot_ai/` and enable it in Project
   Settings → Plugins.
4. Turn off telemetry in the editor. Set `godot_ai/mcp_client_scope` to
   `project`.
5. Remove the obsolete `openrouter` entry from `.mcp.json` (ADR-022).
   Press **Configure** for Claude Code. Confirm that `.mcp.json` now has a
   `godot-ai` entry pinned to the matching version. Add
   `"env": {"GODOT_AI_DISABLE_TELEMETRY": "true"}` to it if the dock did
   not.
6. Re-check `~/.claude.json`. If Configure removed the global entry,
   restore it from the step 2 backup. lab-godot keeps working on 3.2.4.
7. Remove `.mcp.json` from `.gitignore`. Check that the file holds no
   secrets, then commit it.
8. Restart Claude Code in the repo and approve the project MCP server.
   Call a read-only tool, such as the scene hierarchy of
   `scenes/main.tscn`.
9. `task ci`.

### Verification

In a fresh Claude Code session in this repo, a godot-ai scene-tree call on
`scenes/main.tscn` returns its nodes, and `~/.claude.json` still holds
lab-godot's 3.2.4 entry.

### Dependencies

None. It must land before T-005, which runs the MCP spike.

### Outcome

- Vendored release v4.4.2 (the latest, 2026-11-16, checked with
  `gh api repos/hi-godot/godot-ai/releases`), from the
  `godot-ai-v4-plugin.zip` asset (sha256 `93b976b6...c9a0`, matches the
  manifest). No change to the v4.4.1 to v4.4.2 notes affects this setup
  (Python 3.15 launch fix, uv version flag, release tooling).
- `project.godot` gains the plugin in `editor_plugins/enabled` and one
  autoload, `_mcp_game_helper`, which the plugin registers itself for game
  capture. It is the plugin's own entry. The first autoload beyond
  AGENTS.md's EventBus and GameConfig, so the owner should know.
- `.mcp.json` is now committed, un-ignored, with only the `godot-ai` entry.
- The editor opened with the plugin loaded, authenticated and connected, and
  the 47-tool catalogue came back through the real `attach` bridge.

### Assumptions (owner to validate)

- **Assumption:** Ports stay at the defaults (HTTP 8000, WS 9500) and this
  project and lab-godot are not run in the editor at the same time.
  **Evidence:** the ports are read from EditorSettings
  (`addons/godot_ai/client_configurator.gd` lines 82-94 and 190-199,
  `godot_ai/http_port`, `godot_ai/ws_port`, `godot_ai/v4_endpoint_ports`),
  not from ProjectSettings, so they cannot differ per project. On 2026-11-25
  a 3.2.4 server from the other project held 8000 and 9500.
  **Owner check:** do not open both editors together. To run both, give one
  editor its own `godot_ai/v4_endpoint_ports` in a separate editor config,
  which is a global change the owner must choose.
- **Assumption:** Telemetry is sent only by the Python server (the plugin
  only relays events over the WebSocket), so the opt-out is the env var, the
  `--disable-telemetry` flag, and the editor setting.
  **Evidence:** `addons/godot_ai/telemetry.gd` lines 1-9 (relay design),
  `utils/settings.gd` lines 111-117 (env var first, then
  `godot_ai/telemetry_enabled`), `client_configurator.gd` lines 1556-1557
  (argv flag), `utils/server_lifecycle.gd` line 827. The server log said
  "Telemetry disabled" and "opted this server out".
  **Owner check:** `godot_ai/telemetry_enabled` was set to `false` in the
  global `editor_settings-4.7.tres`. This was the only user-global change.
  It also turns telemetry off for lab-godot. Revert it in Editor Settings,
  Plugins, if unwanted.
- **Assumption:** The command is a bare `uvx`, with no machine-specific path.
  **Evidence:** `uvx` resolves on PATH in a mise-activated shell here
  (`mise` uv install). Configure would write an absolute path, so it would
  report a mismatch against this file. The entry's other arguments are
  copied from `_resolve_attach_launch_uncached` and
  `utils/uv_resolution_policy.gd`, and plugin.cfg's cutoff and Python range.
  **Owner check:** if Claude Code is launched from a GUI that lacks the mise
  PATH, change `command` to `mise` with args `x uv -- uvx ...`. Do not press
  Configure (it removes `godot-ai` entries from every scope, including the
  global one lab-godot uses).
- **Assumption:** A scripted stdio client stands in for a fresh Claude Code
  session. **Evidence:** run in an isolated editor with a throwaway HOME and
  ports 8010/9510, because the owner's 3.2.4 server held 8000/9500 and the
  bridge finds the editor-managed server through a HOME-based capability
  directory. It used the committed `.mcp.json` command, with only the ports
  overridden. `scene_get_hierarchy` returned `Main`, `TestTrack`,
  `DirectionalLight3D`, `WorldEnvironment`, `Ground`, `Walls`
  (`BoundaryNorth/South/East/West`, `InnerWallA/B`, `EndCapSouth/East`),
  `Ramp`, `Ramp2` and `TophatCar` (a `CharacterBody3D`).
  **Owner check:** restart Claude Code in the repo, approve the project
  `godot-ai` server, open the project in Godot, and call
  `scene_get_hierarchy`. Confirm `~/.claude.json` still holds the 3.2.4
  entry.
- **Assumption:** `project.godot` was edited by hand for the plugin line, and
  the editor then added the autoload. **Evidence:** `git diff project.godot`
  shows only those two changes. **Owner check:** none.
