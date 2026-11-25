# AGENTS.md

Purpose:
Guide all coding agents working in this repository.

---

# Startup Procedure

Read files in this order:

1. CONTEXT.md
2. STATE.md
3. docs/architecture/overview.md
4. docs/design/game-pillars.md
5. Relevant documents for current task

Do not scan entire repository unless necessary.

---

# Project Summary

Engine:
Godot 4.x

Language:
GDScript only

Genre:
Tournament-focused multiplayer party racer

Core Principles:

- Couch multiplayer first
- Competitive but approachable
- Fast iteration
- Emergent player stories
- Chaos with strategic depth

---

# Required Behaviors

Before implementing:

- understand goal
- inspect existing patterns
- identify impacted systems

Before modifying architecture:

- check ADR documents
- verify decision consistency

Before creating new systems:

- check for existing implementations
- avoid duplication

---

# Decision Hierarchy

When tradeoffs occur:

1. Fun
2. Clarity
3. Maintainability
4. Performance
5. Feature completeness

---

# Coding Rules

Use static typing.

Prefer:

```gdscript
var speed: float = 0.0
```

Avoid:

```gdscript
var speed
```

Use:

```gdscript
class_name RaceManager
```

for reusable systems.

Use:

```gdscript
signal race_finished
```

for communication.

Avoid direct dependencies when signals are sufficient.

---

# Scene Rules

One scene should have one responsibility.

Good:

Vehicle
HUD
RaceManager
Checkpoint

Bad:

GameEverythingManager

Split complex scenes.

Favor composition.

Avoid deep inheritance.

Maximum inheritance depth:

3

---

# Architecture Rules

Dependencies flow:

UI
↓
Presentation
↓
Systems
↓
Data

Never reverse dependency flow.

UI cannot own gameplay state.

Gameplay cannot depend on menu systems.

---

# Multiplayer Rules

Assume future online support.

Avoid:

- single-player assumptions
- global player references
- player one hardcoding

Support:

- split screen
- local tournament play
- future networking expansion

Player ownership must always be explicit.

---

# Tournament Rules

Tournament progression is core identity.

Tournament systems must:

- be deterministic
- be independent of UI
- support elimination formats
- support points formats
- support custom formats

Bracket logic must never live inside UI.

---

# Performance Rules

Avoid:

- allocations in _process()
- repeated get_node()
- loading resources during gameplay

Use:

- pooling
- cached references
- preloading

Optimization targets:

60 FPS minimum
4-player split screen minimum

---

# File Creation Rules

Before creating:

VehicleSystem.gd

check if:

VehicleController.gd

already solves problem.

Prefer extending existing systems.

Avoid parallel implementations.

---

# Documentation Rules

Architectural decisions:

docs/adr/

Coding standards:

docs/standards/

Design decisions:

docs/design/

Task sizing:

docs/standards/task-sizing.md

Task template:

docs/templates/task-template.md

Do not place large documentation in AGENTS.md.

---

# Task Tracking

Tickets live in `docs/tasks/T-*.md` (one file per ticket, using
`docs/templates/task-template.md`), and that file is the single source of
truth. Each ticket has a `**Status:**` line (`Todo`, `In progress`, `Done`,
`Blocked (reason)`), and the PR that implements a ticket also flips its
status. Order and dependencies are in the plan that owns the tickets (for
example `docs/plans/addon-adoption-plan.md`). Size each ticket per
`docs/standards/task-sizing.md`. `.squad/tasks.json` is no longer used
(ADR-022).

Workflow (ADR-022):

- One short-lived branch + one PR per ticket. Enable auto-merge (squash)
  right away; it lands when `QC` passes. Keep vendored-addon tickets
  separate from integration tickets.
- The PR body states the verification evidence: the `task ci` result,
  tests, and a screenshot or log for scene or camera work. "It compiles"
  is not evidence.
- The owner is pulled in at the plan's feel checkpoints, and for
  decisions only the owner can make (product intent, money, accounts,
  licenses). Before asking, try a reversible probe.

STATE.md stays at milestone/phase level only — current priorities and recent
progress, not individual tasks.

---

# Agent Delegation

Model tiering inside Claude Code, per
[ADR-022](docs/adr/ADR-022-dev-workflow-lean-trunk-and-model-tiering.md).
ADR-008's OpenRouter delegation is superseded.

- **Builder:** a Sonnet 5.5 subagent per ticket, in an isolated git
  worktree, with the ticket file as its prompt. In a new worktree, run
  `mise trust && mise install && task import` first.
- **Checker:** the main session (Opus) reviews the real diff, re-runs
  `task ci`, and opens the PR. Never accept a subagent's self-reported
  success without checking.
- **Lookups:** read-only search and inventory go to Haiku 5.5 subagents.
- **Opus does it directly:** ADR-012 self-implemented systems,
  gameplay-feel tuning, and any ticket the builder failed twice.
- **Fresh session per ticket batch.** Carry state between sessions in the
  ticket files, not in chat history.
- **Godot editor MCP (`godot-ai`):** adopted for scene edits and
  run-plus-screenshot checks after the T-005 spike. Follow the rules and
  known failures in ADR-022 §6a.

---

# Boundaries

Never modify:

- .godot/
- .import/
- *.uid files directly
- addons/ vendor code without approval

Never commit:

- signing secrets: `*.keystore`, `*.jks`, or any credential typed into
  `export_presets.cfg`'s `keystore/*_user` / `keystore/*_password` fields
  (see ADR-007 — those must stay empty in the tracked file; CI injects them
  from GitHub Secrets)
- .DS_Store

`export_presets.cfg` itself IS committed (ADR-007) — it holds build/platform
config, not secrets.

---

# Dependency & Tooling Versions

When pinning a version — a GitHub Action (`uses: owner/repo@vX`), a pip/npm
package, a vendored addon — verify the actual latest release first; don't
pin from training-data memory. Model knowledge of "current" versions goes
stale immediately and silently produces an outdated pin with no error.

- Check via the registry's own source: `gh api repos/<owner>/<repo>/releases`
  or `/tags` for GitHub Actions and addons, `mise ls-remote <tool>` for
  toolchain pins, and the Godot **Asset Store** (store.godotengine.org) for
  addons. The old Asset Library is deprecated as of Godot 4.7.
- Check that a tool is still the right tool, not only its latest version:
  look for deprecations, replacements and stale maintenance. Examples
  found 2026-11-24: Android `sdkmanager` was replaced by the Android CLI,
  and gdtoolkit had gone 13 months without a release while carrying open
  4.5+ syntax bugs.
- When docs and engine source disagree, trust the source for the pinned
  version. Example: the Godot 4.7 Android docs list SDK 35, but 4.7.2's
  `config.gradle` targets SDK 36 with build-tools 36.1.0.
- mise holds back releases younger than 24h (`minimum_release_age`). A
  "hidden newer release" warning is that deliberate supply-chain delay,
  not a missed update.
- Before bumping an existing pin, read that version's changelog/release
  notes for breaking changes — don't bump blind.
- If verification isn't possible (offline, private registry), say so
  explicitly and flag the pin as unverified rather than presenting a guess
  as current.

---

# Development Commands

Toolchain versions (Godot, Task, gdscript-formatter, prek) are pinned in
`mise.toml`. Bootstrap once per clone:

```bash
mise trust && mise install   # install the pinned toolchain
task setup                   # register the git pre-commit hook (prek)
```

Everything below is a `task <name>` in `Taskfile.yml` (`task` with no args
lists all of them):

```bash
task check:versions   # fail if Godot pins drift (mise.toml / release.yml / project.godot)
task run              # launch the game
task ci               # everything CI runs: import, check:parse, test, fmt:check, lint
task test             # just GdUnit4 (ADR-007), once addons/gdUnit4/ is installed
task fmt              # reformat GDScript in place (gdscript-formatter)
task lint             # gdscript-formatter lint
task export           # export all 4 platforms locally (needs export templates installed)
task export:windows   # or one platform at a time — also :linux, :macos, :android
task clean            # sweep build/, reports/, godot_check.log
```

Raw equivalent for `task test` if Task isn't installed:

```bash
godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --ignoreHeadlessMode -c
```

Cut a release (tag push triggers `.github/workflows/release.yml`):

```bash
git tag v0.1.0 && git push origin v0.1.0
```

---

# Naming Conventions

Files: snake_case.gd

Classes: PascalCase

Variables: snake_case

Constants: UPPER_SNAKE_CASE

Signals: past_tense_snake_case (race_finished, lap_completed)

Nodes: PascalCase matching purpose (PlayerVehicle, RaceHUD)

Scenes: snake_case.tscn matching primary script

---

# Autoload Policy

Use Autoloads for:

- EventBus (global signal bus)
- GameConfig (settings and constants)

Do not use Autoloads for:

- per-race state
- player-specific data
- UI management

Minimize Autoload count.

---

# Verification

After modifying scripts:

- confirm no parse errors
- verify scene references are intact
- run affected test scenes

After modifying scenes:

- verify node paths are valid
- check signal connections
- test with 2+ players when relevant

---

# Output Style

For technical responses:

Problem
Cause
Fix
Risks
Files

Keep explanations concise.

Prioritize implementation guidance.
