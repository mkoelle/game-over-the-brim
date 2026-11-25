# T-019: Vendor godot-ai 4.4.2 (Project Scope, Telemetry Off)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Todo
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

- [ ] `addons/godot_ai/` is vendored at the pinned release and enabled.
- [ ] Telemetry is off, both in the editor setting and through
      `GODOT_AI_DISABLE_TELEMETRY=true` in the MCP entry's environment.
- [ ] A project-scoped `godot-ai` MCP entry pins the matching server
      version (`godot-ai==4.4.2`). The global 3.2.4 entry for lab-godot
      still exists afterwards.
- [ ] From a Claude Code session in this repo, a godot-ai call that reads
      the scene tree of `scenes/main.tscn` succeeds.
- [ ] `task ci` is green, and the plugin adds no parse errors.

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
