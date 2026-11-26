# FC-1 Owner Checklist

**Date:** 2026-11-25
**Plan:** [Addon adoption plan](addon-adoption-plan.md), Phase 1, step 6

The agents finished the Phase 1 tickets under ADR-022. Some steps need a
person, hardware or a decision. The agents recorded a researched
assumption for each of those steps in the ticket's
`### Assumptions (owner to validate)` section. This page collects them in
one order, so one session covers them. Each line links to the ticket that
holds the evidence and the full steps.

Tick a box when it is confirmed. If a check fails, note it in the
ticket's Assumptions section and open a follow-up ticket.

## 0. Setup

- [x] Pull `main`, run `mise install && task import`, then `task run`.
- [x] Press F3. The debug overlay appears. The car shows blue, green and
      yellow arrows and a slip label
      ([T-007](../tasks/T-007-vehicle-debug-vectors.md)).

## 1. FC-1 drive (keyboard, one player)

Drive the test track for about 10 minutes, then answer the two FC-1
questions: does the camera feel right, and can drift and air problems
now be seen and described?

Physics ([T-001](../tasks/T-001-pin-3d-physics-engine.md), ADR-021):

- [ ] Jolt feels right on wall slides and on the Ramp2 landing. If not,
      set `physics/3d/physics_engine` back to `GodotPhysics3D` and compare.

Camera ([T-005](../tasks/T-005-replace-chase-camera-with-phantom-camera.md)):

- [x] The camera turns with the car and never goes through a wall. Hug
      every wall, including the corners.
      - camera can jump through blue ramp when backing up into the base of the ramp
        - *Agent:* Reproduced. Reversing under Ramp2's high end wedges the
          car in the gap under the slab. The camera's collision start point
          ends up inside the slab, so the camera pops to the top side.
          Fixed in [T-021](../tasks/T-021-solid-ramp2-camera-pop.md).
          Ramp2 is now a solid wedge with the same top surface, so there
          is no gap. The rule is in
          [track-geometry.md](../design/track-geometry.md). Re-check by
          backing into Ramp2 from both ends.
- [x] Framing: the car is not too small or too high in frame. If it is,
      try `spring_length` 4.0–5.0 or `follow_offset.y` 0.8–1.4.
- [x] Full-throttle straight: the car keeps a steady size.
- [x] Ramp2 landing does not jolt (Y damping 0.2 s; try 0.25 or 0.15).
- [x] Hard corners: yaw smoothing of 0.15 s is neither loose nor twitchy.

Impact shake ([T-008](../tasks/T-008-impact-camera-shake.md)):

- [x] Low-speed taps (under 3 m/s) do not shake.
- [x] Five full-speed head-on hits give a clear jolt that is not harsh
      (peak about 2.5°; `max_amplitude` 14 if weak, 6–7 if harsh).
- [x] A 45° hit shakes less than head-on.
- [x] The shake is not a buzz (`frequency` 10) or a wobble (20).
- [x] A 3 s wall scrape shakes once, not continuously.

Debug vectors ([T-007](../tasks/T-007-vehicle-debug-vectors.md)), F3 on:

- [x] The arrows and the slip label are readable at chase distance. If
      not, change the constants at the top of `vehicle_debug_draw.gd`.
- [x] Straight driving: the blue and green arrows overlap.
- [x] A held drift through a corner: green swings off blue, and the slip
      sign reads sensibly.
      - barely noticable
        - *Agent:* The arrows are right; the drift itself is weak. Earlier
          probes measured about 2-3.5 degrees of slip in a held drift
          (`drift_grip` 0.55 per physics tick pulls the velocity back to the
          nose almost at once). The genre goes up to about 45 degrees
          (`handling-reference.md` §2). This is input for the handling
          rework, not a debug-vector bug. It is added to §5.
- [ ] Up `Ramp2`: the yellow arrow tilts (30° measured).
- [x] Press F3 again: everything disappears.

Track ([T-011](../tasks/T-011-kenney-greybox-kit.md),
[T-010](../tasks/T-010-asset-credits-manifest.md)):

- [x] Barriers and cones read as the right size next to the car.
- [ ] The car does not hop an inner 1.05 m wall off Ramp2.
- [ ] Clipping a pylon's top edge feels fair (box collider).
- [ ] Sliding along inner walls at an angle has no seam bumps.
- [ ] The floor still reads at speed. The Kenney light texture is low
      contrast. Say if you want `Dark/texture_07.png`.

Handling targets ([T-017](../tasks/T-017-handling-genre-research.md)):

- [ ] Read `docs/design/handling-reference.md` before or after the drive.
      Mark any target that feels wrong.
- [ ] Say whether two drift tiers are enough, or you want three.

## 2. Hardware checks

Gamepads, 2 or more ([T-003](../tasks/T-003-port-input-source-to-device-action-map.md),
[T-002](../tasks/T-002-device-action-map.md)):

- [ ] Isolation: follow the 6 steps in T-003's Assumptions, using the
      temporary `_car.input_source = InputSource.new(1)` line. Only the
      chosen pad drives. The other pad and the keyboard stay at
      `Throttle: +0.00`, `Steer: +0.00`.
- [ ] Hotplug: unplug the active pad mid-run. The car coasts and no errors
      appear. Replug it, and it drives again.
- [ ] Stick drift: leave each pad alone for 10 s. The overlay stays at
      zero with the 0.08 deadzone.

Exports ([T-006](../tasks/T-006-vendor-debug-draw-3d.md)):

- [ ] Windows or Linux: run `task export:windows` or `task export:linux`,
      copy `build/<platform>/` to the machine, and run it with
      `--verbose`. The log has no `GDExtension` error and no
      `Can't open dynamic library` line.
- [ ] Android: run `task export:android`, then `adb install -r
      build/android/OverTheBrim.apk`, launch it, and check
      `adb logcat` for the same errors.
- [ ] macOS: unzip `build/macos/OverTheBrim.zip` and open it from Finder.
      A quarantine prompt is expected.

## 3. Editor and tooling

- [ ] Editor: Project Settings > Plugins shows Phantom Camera, GdUnit4
      and godot-ai enabled. The Phantom Camera bottom panel loads. The
      Output panel has no errors. Debug Draw 3D is a GDExtension, so it has
      no plugin entry ([T-004](../tasks/T-004-vendor-phantom-camera.md)).
- [ ] godot-ai MCP ([T-019](../tasks/T-019-vendor-godot-ai.md)): restart
      Claude Code in the repo, approve the project `godot-ai` server, and
      call `scene_get_hierarchy`. Do not press the plugin's Configure
      button. Do not run this project and another godot-ai project in the
      editor at the same time (both use ports 8000/9500).
- [x] T-019 set the global editor setting `godot_ai/telemetry_enabled` to
      `false`. Keep it, or restore it from the backup that T-019 names.

## 4. Decisions only the owner can make

- [ ] Steam: decide whether to pay the $100 Steam Direct fee, then set
      ADR-020 to Accepted or Rejected
      ([T-016](../tasks/T-016-evaluate-steam-remote-play-together.md)).
      The ADR-020 hands-on test needs an app ID.
- [ ] Confirm the project made `icon.svg` ([T-010](../tasks/T-010-asset-credits-manifest.md)).
- [ ] Phantom Camera's bundled Nunito fonts have no license file in the
      addon. Upstream says OFL-1.1. Confirm this, or exclude the fonts from
      exports ([T-004](../tasks/T-004-vendor-phantom-camera.md)).
- [ ] Dev addons in exports: today `exclude_filter` is empty, so GdUnit4,
      godot-ai and the inert Debug Draw 3D release library ship. Decide
      whether to exclude them before the first public build.
- [ ] Debug Draw 3D is 41 MB, most of it for platforms we do not export.
      Keep it, or trim it in a later ticket (ADR-015 has a 50 MB LFS
      threshold).

## 5. Findings for the handling rework (no action at FC-1)

The scripted probes found these handling issues while measuring the
camera and shake. They feed the rework tickets written from T-017:

- A wall hit removes the into-wall speed with no bounce. A head-on hit
  stops the car dead.
- `velocity.y` is set to 0 while grounded, so the car leaves a ramp top
  with no upward speed. Ramps do not launch it.
- Reverse speed has the same cap as forward speed (`max_speed`, 24 m/s).
- `drift_grip` and `air_control` are fixed lerp factors per physics tick.
  Their effect changes with the physics tick rate, not with time.
- Yaw rate scales with `speed / max_speed`. The car barely turns at low
  speed and turns fastest at top speed. In the genre, yaw rate stays
  roughly flat while the turn radius grows with speed
  (`handling-reference.md` §1).
- While driving car/box looks like it is vibrating, and is blurry because of it
  - *Agent:* The cause is 60 Hz physics on a 120 Hz display: the car is
    drawn still every other frame, about 8 px of judder per frame at top
    speed. Fixed in
    [T-020](../tasks/T-020-enable-physics-interpolation.md), which turns on
    physics interpolation (now 0.09 px). Re-check on the next drive.
- Turns cause the debug text to vibrate and turn fuzzy
      - sometimes the text jumps or pops , large and off center
  - *Agent:* Reproduced. It is a side effect of T-020. Debug Draw 3D draws
    text with pooled `Label3D` nodes and uses a different one each frame.
    With physics interpolation on, each label blended from where it was
    last used: 300 px RMS off its anchor in a turn, with pops up to
    4,248 px. Fixed in
    [T-022](../tasks/T-022-debug-text-interpolation.md), which turns
    interpolation off for the addon's nodes (now 0.0 px).
- driving under ramp one hits invisible wall
  - *Agent:* Reproduced. Kenney's `roadRampLong` model is only a one-sided
    road deck. From the side or the high end it is almost invisible, and
    the space under it looks open. Its collision is a solid wedge (T-011),
    so that "open" space is an invisible wall. Fixed in
    [T-023](../tasks/T-023-kenney-ramp-visible-body.md): the ramp now has
    a visible grey wedge body under the deck that matches its collision
    (rule 3 in [track-geometry.md](../design/track-geometry.md)).
- Drift slip is barely visible with F3 on (about 2-3.5 degrees in a held
  drift). The drift needs much more slip in the handling rework.
