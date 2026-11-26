# Addon & Third-Party Adoption Plan

**Date:** 2026-11-24
**Scope:** OSS addons, free assets and platform features that replace
undifferentiated work, so effort stays on handling feel, spectator chaos
and tournament identity ([ADR-012](../adr/ADR-012-self-implementation-boundary.md)).

All versions below were verified against upstream with `gh api` on
2026-11-24, per AGENTS.md "Dependency & Tooling Versions". Re-verify any
pin older than about 30 days at the moment of vendoring.

---

## Ground rules (apply to every ticket)

Process, tracking and model tiering: [ADR-022](../adr/ADR-022-dev-workflow-lean-trunk-and-model-tiering.md).

1. **Vendoring needs owner approval.** AGENTS.md Boundaries forbid
   modifying `addons/` without approval. Approval of a ticket counts as
   approval to vendor that one addon at the pinned version. Never edit
   vendored files afterwards.
2. **Native addons** must pass the
   [ADR-015](../adr/ADR-015-native-gdextension-addon-policy.md) checklist.
   Record the results in the addon's ADR.
3. **Pins:** use the release tag where one exists. Otherwise use a commit
   SHA, recorded in the ADR.
4. **Branch per ticket** (`chore/…` for vendoring, `feature/…` for
   integration), per [branching.md](../standards/branching.md). `task ci`
   must be green before the PR.
5. **Before the "1-Car Fun" gate passes** (STATE.md Iteration 01), only
   Phase 1 tickets are in scope. Phase 1 exists to make the hand feel-test
   faster and more trustworthy.

---

## Owner decisions (2026-11-24)

- **Vendoring approved** for Phantom Camera (T-004), Debug Draw 3D (T-006)
  and the GdUnit4 bump (T-009), at the **latest release available at
  vendoring time**. Re-verify with `gh api` and read the release notes
  since the version named in the ticket. If they differ, update that
  ticket's ADR pin. Other addons still need approval per ticket.
- **Feel gate:** hand-tested, not passed. Steering response, drift,
  camera and ramps/air/landing all feel wrong. **The current handling and
  camera values are not a reference baseline.** Tickets must not try to
  preserve them for comparison. Phase 1 builds the tools (physics pin,
  correct input, a real camera rig, debug vectors) for a handling rework.
  The rework itself is self-implemented (ADR-012) and is not covered by
  this plan. Phases 3-4 stay blocked.
- **Test hardware available:**
  - 2+ gamepads: T-003 does a real isolation check.
  - A Windows or Linux machine: T-006 launches non-host desktop exports.
  - An Android device: T-006 installs and launches the APK.
  - **No** high-refresh monitor: skip T-005's physics-interpolation
    comparison. *(Corrected 2026-11-25: the owner's MacBook Pro built-in
    display is 120 Hz ProMotion. FC-1 found the resulting vibration.
    [T-020](../tasks/T-020-enable-physics-interpolation.md) enables
    interpolation.)*
- **Toolchain:** move dev tools to mise. Separate branch
  `chore/mise-toolchain`.

---

## Phase 1 — Feel-test support (now)

| Ticket | Title | Pri | Est | Depends on | ADR |
|---|---|---|---|---|---|
| [T-001](../tasks/T-001-pin-3d-physics-engine.md) | Pin the 3D physics engine | P1 | 2h | — | ADR-021 (new) |
| [T-002](../tasks/T-002-device-action-map.md) | `DeviceActionMap` per-device action copies | P1 | 3h | — | [014](../adr/ADR-014-per-device-input-action-map.md) |
| [T-003](../tasks/T-003-port-input-source-to-device-action-map.md) | Port `InputSource` onto `DeviceActionMap` | P1 | 3h | T-002 | 014 |
| [T-004](../tasks/T-004-vendor-phantom-camera.md) | Vendor Phantom Camera v0.12 | P1 | 1h | — | [013](../adr/ADR-013-camera-addon-phantom-camera.md) |
| [T-005](../tasks/T-005-replace-chase-camera-with-phantom-camera.md) | Replace `ChaseCamera` with `PhantomCamera3D` | P1 | 3h | T-004 | 013 |
| [T-006](../tasks/T-006-vendor-debug-draw-3d.md) | Vendor Debug Draw 3D v1.7.3 (ADR-015 checks) | P2 | 3h | — | [016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md) |
| [T-007](../tasks/T-007-vehicle-debug-vectors.md) | In-world vehicle debug vectors (F3) | P2 | 2h | T-006 | 016 |
| [T-008](../tasks/T-008-impact-camera-shake.md) | Impact camera shake | P2 | 3h | T-005 | 013 |
| [T-009](../tasks/T-009-bump-gdunit4.md) | Bump GdUnit4 6.2.0 → 6.2.3 | P3 | 1h | — | [007](../adr/ADR-007-build-test-and-release-pipeline.md) |
| [T-019](../tasks/T-019-vendor-godot-ai.md) | Vendor godot-ai 4.4.2 (project scope, telemetry off) | P1 | 2h | — | [022](../adr/ADR-022-dev-workflow-lean-trunk-and-model-tiering.md) |
| [T-018](../tasks/T-018-upgrade-godot-4-8.md) | Upgrade to Godot 4.8 stable | P2 | 3h | 4.8 stable + addon support | [007](../adr/ADR-007-build-test-and-release-pipeline.md) |
| [T-020](../tasks/T-020-enable-physics-interpolation.md) | Enable physics interpolation (FC-1: car vibration at 120 Hz) | P1 | 1h | T-005 | [013](../adr/ADR-013-camera-addon-phantom-camera.md) |
| [T-021](../tasks/T-021-solid-ramp2-camera-pop.md) | Solid Ramp2 wedge (FC-1: camera jumps through the ramp) | P1 | 2h | T-020 | [013](../adr/ADR-013-camera-addon-phantom-camera.md) |

**Execution order** (ADR-022; tickets run one at a time, because most of
them touch `project.godot`):

1. T-001 physics pin. Switching engines later would invalidate tuning.
2. T-009 GdUnit4 bump, so the new tests are written on 6.2.3.
3. T-019 → T-004 → T-005 camera. The camera was flagged in the
   feel-test, and T-005 is also the `godot-ai` MCP spike, which needs
   T-019 first.
4. T-002 → T-003 input fix.
5. T-006 → T-007 debug vectors.
6. **FC-1 (feel checkpoint 1):** the owner drives with the new camera,
   correct input and F3 vectors on. Checks: does the camera feel right,
   and can drift and air problems now be seen and described? Also confirm
   the pinned physics engine (ADR-021, Jolt) feels right on wall slides
   and ramp landing; flip back to `GodotPhysics3D` if not. All owner
   checks from the Phase 1 and 2 tickets are collected in the
   [FC-1 owner checklist](fc-1-owner-checklist.md).
7. T-008 impact shake. *(Done before FC-1, on 2026-11-25, so FC-1 also
   judges the shake.)*

[T-017](../tasks/T-017-handling-genre-research.md) (handling genre
research, no code) runs in parallel. The handling rework tickets are
written from its results after FC-1.

## Phase 2 — Assets (any time; T-010 early)

| Ticket | Title | Pri | Est | Depends on | ADR |
|---|---|---|---|---|---|
| [T-010](../tasks/T-010-asset-credits-manifest.md) | `assets/CREDITS.md` + licensing standard | P2 | 1h | — | [019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md) |
| [T-011](../tasks/T-011-kenney-greybox-kit.md) | Import Kenney greybox kit into test track | P2 | 3h | T-010 | 019 |

## Phase 3 — Track building (after the "1-Car Fun" gate)

| Ticket | Title | Pri | Est | Depends on | ADR |
|---|---|---|---|---|---|
| [T-012](../tasks/T-012-spike-road-generator.md) | Spike Road Generator 0.9.5 (loop track) | P2 | 4h | gate | [017](../adr/ADR-017-track-tooling-road-generator-and-scatter.md) |
| [T-013](../tasks/T-013-roadlane-follower-probe.md) | `RoadLane` follower probe (AI path check) | P3 | 2h | T-012 | 017 |
| [T-014](../tasks/T-014-vendor-scatter.md) | Vendor ProtonScatter (`main@7198cc00078e`) | P3 | 3h | T-011 | 017 |

## Phase 4 — Menus (when the first real menu is needed)

| Ticket | Title | Pri | Est | Depends on | ADR |
|---|---|---|---|---|---|
| [T-015](../tasks/T-015-spike-maaack-menus-template.md) | Spike Maaack's Menus Template v1.8.0 | P3 | 4h | T-003, T-010 | [018](../adr/ADR-018-menu-framework-maaack-menus-template.md) |

## Phase 5 — Online path decision

| Ticket | Title | Pri | Est | Depends on | ADR |
|---|---|---|---|---|---|
| [T-016](../tasks/T-016-evaluate-steam-remote-play-together.md) | Evaluate Steam Remote Play Together | P3 | 3h | — | [020](../adr/ADR-020-steam-remote-play-together-online-path.md) (Proposed) |

---

## Already decided, deferred (no tickets yet)

These keep their existing trigger conditions. Create tickets when the
trigger fires.

| Addon | Pin (verified 2026-11-24) | Trigger | ADR | Extra gate |
|---|---|---|---|---|
| netfox | v1.49.12 | Tier 2 networked grid starts. Possibly much later if ADR-020 is accepted. | [009](../adr/ADR-009-netcode-addon-netfox.md) | — |
| Controller Icons (`rsubtil`) | v3.1.8 | First input-prompt UI | [010](../adr/ADR-010-input-glyph-addon-controller-icons.md) | Compare with G.U.I.D.E prompts at that time |
| LimboAI (GDExtension) | v1.8.1 (needs Godot 4.6+) | First `RaceManager` state machine or AI bot | [011](../adr/ADR-011-ai-state-machine-addon-limboai.md) | ADR-015 checklist; Beehave is the fallback |

## Candidates, no decision yet

- **FMOD for Godot** (`utopia-rise/fmod-gdextension`, latest
  6.1.0-4.5.0). Revisit only if pitch-shifting the built-in
  `AudioStreamPlayer3D` is not enough for engine sound. It is native (ADR-015),
  and the FMOD license is proprietary with a free indie tier, so check its
  terms.
- **G.U.I.D.E**: revisit as a combined remap and prompt layer at menu time
  (see ADR-010 alternative 2).
- **Terrain3D**: only if outdoor terrain tracks enter the design.

## Rejected (do not re-propose without new information)

- **gdtoolkit / pre-commit**: replaced by gdscript-formatter and prek
  (ADR-023). The tools were stale and Python-dependent.

- **MultiplayerInput** (`matjlars`): incompatible with Godot 4.7 device IDs
  and the upstream is stale. See ADR-014.
- **Resonate** (audio manager): the upstream repo is archived.
- **PankuConsole**: no release since 2024-07. Godot's built-in Remote
  scene tree already supports live `VehicleStats` edits while the game
  runs.
- **Any vehicle physics addon** (for example `VehicleBody3D` kits): ADR-012.
- **gdUnit4-coverage**: already evaluated in STATE.md (beta, 20-file cap).

## Built-ins to use instead of addons

- `GPUParticles3D` with trails for steam exhaust and drift sparks.
- `Decal` for skid marks.
- `Tween` for UI and juice.
- `SubViewportContainer` grid for splitscreen.
- `AnimationTree` for hat eyes.
- Remote scene tree for live tuning.
- **From Godot 4.8 (T-018):** a native `Trail3D` node for drift and
  steam trails, and non-allocating physics queries for per-frame raycasts.
