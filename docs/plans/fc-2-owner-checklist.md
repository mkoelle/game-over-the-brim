# FC-2 Owner Checklist

**Date:** 2026-11-25 (built up while the handling rework lands)
**Plan:** [Handling rework plan](handling-rework-plan.md)

FC-2 is the "1-Car Fun" gate (Guardrail 3). Drive the test track with
the reworked handling, then answer one question: **is one car on one
track fun?**

Each handling ticket adds its owner checks below once it merges. The
agents recorded a researched assumption, with evidence and a probe, for
each one in the ticket's `### Assumptions (owner to validate)` section.
Tick a box when it is confirmed. Comment under any item like FC-1, and
the next round fixes or tunes it.

## 0. Setup

- [ ] Pull `main`, run `mise install && task import`, then `task run`.
      F3 shows the overlay and the in-world vectors.

## 1. Steering ([T-027](../tasks/T-027-steering-curve-and-smoothing.md))

- [ ] Top speed feels planted, not twitchy, with a turn radius of about
      17 m. The tuning knob is `steering_rate` (1.4) in
      `resources/vehicles/stovepipe_speedster.tres`.
- [ ] Hairpins at low speed feel agile (about 5-7 m radius).
- [ ] Tapping left and right moves the nose smoothly, not in snaps
      (`steer_ramp_time` 0.17 s).
- [ ] A gamepad stick still feels direct with the ramp on.
- [ ] Stopped against a wall, a little reverse frees the car (no
      rotation below 1 m/s).

## 2. Drift slide ([T-028](../tasks/T-028-grip-and-drift-slide.md))

- [ ] With F3 on, a held drift through the barrier corners reads about
      20-35 degrees of slide and stays controllable. Steering in
      tightens the line, steering out widens it, and neither ends the
      drift.
- [ ] Drifting does not cost speed. Say if it feels like a free lunch.
- [ ] A slow hairpin can still be drifted (minimum 11 m/s).
- [ ] A normal full-lock turn feels planted, not icy (about 4 degrees of
      slip).
- [ ] A drift over a bump or a ramp lip does not cancel unexpectedly.
- [ ] The overlay's `Drift:` line shows the side and the slide.

## 3. Walls ([T-029](../tasks/T-029-wall-contact-response.md))

- [ ] Glancing a wall keeps momentum. The car slides off and carries on,
      and does not grind to a stop (your FC-1 comment).
- [ ] A head-on hit at full speed bounces the car back. It feels fun, not
      punishing (`wall_restitution` 0.4).
- [ ] Holding throttle into a wall gives a few shrinking bounces, not
      jitter.
- [ ] A glancing hit does not feel like the game is steering for you
      (`wall_align_time` 0.1 s).
- [ ] Each crash still shakes the camera once.

## 4. Ramps, air, landing (T-030)

_Added when T-030 merges._

## 5. Drift boost tiers (T-031)

_Added when T-031 merges._

## 6. Visual body (T-032)

_Added when T-032 merges._

## 7. Tricks (T-033)

_Added when T-033 merges._

## 8. Camera (T-034)

_Added when T-034 merges._

## 9. The gate

- [ ] One car on one track is fun (Guardrail 3). If not, say what is
      missing, and the next round becomes tickets.

## Deferred from FC-1

Not answered at FC-1. They are deferred until the owner picks them up
(owner, 2026-11-25). The links point at the tickets that hold the steps.

- [ ] Jolt feels right on wall slides and on the Ramp2 landing. If not,
      set `physics/3d/physics_engine` back to `GodotPhysics3D` and compare.
- [ ] Clipping a pylon's top edge feels fair (box collider).
- [ ] Isolation: follow the 6 steps in T-003's Assumptions, using the
      temporary `_car.input_source = InputSource.new(1)` line. Only the
      chosen pad drives. The other pad and the keyboard stay at
      `Throttle: +0.00`, `Steer: +0.00`.
- [ ] Hotplug: unplug the active pad mid-run. The car coasts and no errors
      appear. Replug it, and it drives again.
- [ ] Stick drift: leave each pad alone for 10 s. The overlay stays at
      zero with the 0.08 deadzone.
- [ ] Windows or Linux: run `task export:windows` or `task export:linux`,
      copy `build/<platform>/` to the machine, and run it with
      `--verbose`. The log has no `GDExtension` error and no
      `Can't open dynamic library` line.
- [ ] Android: run `task export:android`, then `adb install -r
      build/android/OverTheBrim.apk`, launch it, and check
      `adb logcat` for the same errors.
- [ ] macOS: unzip `build/macos/OverTheBrim.zip` and open it from Finder.
      A quarantine prompt is expected.
- [ ] Editor: Project Settings > Plugins shows Phantom Camera, GdUnit4
      and godot-ai enabled. The Phantom Camera bottom panel loads. The
      Output panel has no errors. Debug Draw 3D is a GDExtension, so it has
      no plugin entry ([T-004](../tasks/T-004-vendor-phantom-camera.md)).
- [ ] godot-ai MCP ([T-019](../tasks/T-019-vendor-godot-ai.md)): restart
      Claude Code in the repo, approve the project `godot-ai` server, and
      call `scene_get_hierarchy`. Do not press the plugin's Configure
      button. Do not run this project and another godot-ai project in the
      editor at the same time (both use ports 8000/9500).
- [ ] Steam: decide whether to pay the $100 Steam Direct fee, then set
      ADR-020 to Accepted or Rejected
      ([T-016](../tasks/T-016-evaluate-steam-remote-play-together.md)).
      The ADR-020 hands-on test needs an app ID.
- [ ] Phantom Camera's bundled Nunito fonts have no license file in the
      addon. Upstream says OFL-1.1. Confirm this, or exclude the fonts from
      exports ([T-004](../tasks/T-004-vendor-phantom-camera.md)).
- [ ] Dev addons in exports: today `exclude_filter` is empty, so GdUnit4,
      godot-ai and the inert Debug Draw 3D release library ship. Decide
      whether to exclude them before the first public build.
- [ ] Debug Draw 3D is 41 MB, most of it for platforms we do not export.
      Keep it, or trim it in a later ticket (ADR-015 has a 50 MB LFS
      threshold).
