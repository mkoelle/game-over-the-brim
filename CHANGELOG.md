# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows the tag pushed to trigger a release (see
`docs/standards/versioning.md`); the same value is set in
`project.godot`'s `application/config/version` and mirrored into
`export_presets.cfg`'s per-platform version fields at release time.

## [Unreleased]

### Added (T-008)

- A wall hit shakes the car's camera, scaled by how fast the car hit the
  wall. `VehicleController` emits a local `impacted(impact_speed)` signal
  at the start of each wall contact (not every frame of a scrape, and not
  on landings). `main.tscn` gains `ImpactShake`, a rotation-only
  `PhantomCameraNoiseEmitter3D`, and its `ImpactShakeDriver` child
  (`scripts/camera/impact_shake_driver.gd`). Hits under 3 m/s do not
  shake. A full-speed head-on hit peaks at about 2.5 degrees for about
  0.2 s. The owner confirms the values by feel.

### Changed (T-005)

- The chase camera now runs on Phantom Camera (ADR-013). `main.tscn` has
  `GameCamera` (`Camera3D` + `PhantomCameraHost`) and `CarFollowCam`, a
  Third Person `PhantomCamera3D` that collides with the Track layer only.
  `ChaseCamYawDriver` (`scripts/camera/chase_cam_yaw_driver.gd`, replacing
  `chase_camera.gd`) turns the rig with the car and holds its height on a
  jump. The values were tuned against a scripted drive. The owner confirms
  them by feel at FC-1.

### Added (T-004)

- Vendored Phantom Camera v0.12 (`ramokz/phantom-camera`, MIT) into
  `addons/phantom_camera/` and enabled the plugin. It registers the
  `PhantomCameraManager` autoload (ADR-013). No gameplay changes yet; the
  chase camera swap is T-005.

### Changed (T-009)

- Bumped vendored GdUnit4 to v6.2.3 (from `godot-gdunit-labs/gdUnit4`). No
  breaking or CLI changes. Includes a fix for the scene runner delivering
  input events twice (GD-1459).

### Changed (toolchain, ADR-023)

- Replaced gdtoolkit (`gdformat`/`gdlint`, Python, last released
  2025-10) with GDQuest GDScript Formatter 0.28.0 (`gdscript-formatter`
  for formatting and linting; Rust single binary). This reformatted 4
  files with layout-only changes, checked with `--verify-structure`.
- Replaced pre-commit (Python) with prek 0.5.11 (Rust drop-in). It reads
  the same `.pre-commit-config.yaml`.
- Dropped uv and every `pypi:` tool from `mise.toml`. The toolchain is
  now native binaries only (Godot, Task, gdscript-formatter, prek).

### Fixed

- `.import` files are now committed. `.gitignore` used to exclude them, so
  every clone regenerated resource UIDs and `test_track.tscn` loaded
  `dev_grid.png` through an invalid UID. Ignore only `.godot/`, per
  Godot 4.4+ guidance.
- `task export:*` creates `build/<platform>/` (Godot fails on a missing
  output folder). `task test` and the exports add `.gdignore` to
  `reports/` and `build/`, so Godot stops importing generated files.

### Changed

- Dev toolchain is now managed by mise. `mise.toml` pins Godot 4.7.2,
  Task 3.54.0, gdtoolkit 4.5.0, pre-commit 4.7.0 and uv 0.13.9. CI
  installs the same pins via `jdx/mise-action@v5`, replacing
  `setup-godot`, `setup-task` and the pip install step. `task setup` now
  runs `mise install` and `pre-commit install`. `task setup:ci` is
  removed.
- New `task check:versions`, the first step of `task ci`/`task verify`
  and CI. It fails on Godot version drift between `mise.toml`,
  `release.yml` and `project.godot`.

## [0.0.2-alpha] - 2026-09-14

### Added

- **Drivable prototype milestone** (Phase A, Iteration 01 — Guardrail 3's
  "1-Car Fun" rule): input map + per-device `InputSource` (Architecture
  Decision 01), data-driven `VehicleStats` resource, `VehicleController`
  (arcade accel/brake/steer/drift, partial air control on
  `CharacterBody3D`), `test_track.tscn` sandbox, `ChaseCamera`, and
  `main.tscn` wired end-to-end — running the project spawns a drivable car
  on the test track with a following camera.
- Debug HUD toggle (F3): `GameConfig.debug_mode` gates a live
  speed/throttle/steer/drift/FPS readout
  (`docs/standards/manual-testing.md`).
- Real GdUnit4 coverage for `VehicleController` (acceleration, max-speed
  clamp, NaN guard) and `DebugOverlay`.
- macOS `.icns` and Android adaptive launcher icons, closing the icon gap
  left open by ADR-007 (Windows-only icon fix).
- `application/config/version` in `project.godot` as the version
  source of truth, synced to the current release tag.
- `docs/standards/versioning.md` and `docs/standards/branching.md`.
- ADR-009 through ADR-012: third-party addon selection (netfox,
  Controller Icons, LimboAI — each deferred to its own trigger milestone)
  and a standing self-implementation-boundary policy.
- `Taskfile.yml`: local/CI parity runner (`task ci`, `task verify`,
  `task run`, `task export[:platform]`, `task clean`, and more).
- `gdformat`/`gdlint` (gdtoolkit) enforcement on first-party GDScript,
  plus a `pre-commit` hook (`task setup`) running both on every commit.
- `.gitattributes` for Godot-appropriate line-ending and binary handling.
- `.github/dependabot.yml` for automatic GitHub Actions version-update PRs.
- PR test reporting (`dorny/test-reporter`) and failure-artifact upload
  for CI's QC job.

### Changed

- CI now runs its QC pass on every branch push, not just `main` — but
  only a `main` push or a pull request can fail/alert; a bare
  feature-branch push is non-blocking. Job renamed `test` → `qc` to match
  its actual scope (import, parse-check, tests, format, lint).
- Vehicle steering/camera/air-control tuned against kart-racer genre
  convention: fixed inverted reverse-steering, fixed a floaty fall bug,
  restored partial air control.
- Test track reworked with full perimeter walls and inner walls as
  obstacles; track geometry converted to `CSGBox3D`.

## [0.0.1-alpha] - 2026-09-09

### Added

- Initial project scaffolding: Godot 4.7 project, main scene, autoloads
  (`EventBus`, `GameConfig`).
- CI pipeline (import check, script-error check, GdUnit4 test run).
- Release pipeline (tag-triggered multi-platform export + GitHub Release).
- GdUnit4 test framework, vendored at `addons/gdUnit4/`.
- Windows executable icon.
- Project documentation set: architecture overview, design docs, coding
  standards, ADRs.

See `docs/adr/ADR-007-build-test-and-release-pipeline.md` for the detailed
history of what it took to get the pipeline working.
