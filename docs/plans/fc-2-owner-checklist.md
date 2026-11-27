# FC-2 Owner Checklist

**Date:** 2026-11-25. **Ready:** all eight handling tickets are merged
(T-027 to T-034).
**Plan:** [Handling rework plan](handling-rework-plan.md)

FC-2 is the "1-Car Fun" gate (Guardrail 3). Drive the test track with
the reworked handling, then answer one question: **is one car on one
track fun?**

Each section below comes from one handling ticket. The agents recorded a
researched assumption, with evidence and a probe, for each check in that
ticket's `### Assumptions (owner to validate)` section. Every tuning knob
named here lives in `resources/vehicles/stovepipe_speedster.tres`, or in
the named scene node, so a change needs no code.

**Controls:**
- throttle and brake
- steer
- the drift button, which also tricks just after a ramp launch
Tick a box when it is confirmed. Comment under any item like FC-1, and
the next round fixes or tunes it.

## 0. Setup

- [x] Pull `main`, run `mise install && task import`, then `task run`.
      F3 shows the overlay and the in-world vectors.

## 1. Steering ([T-027](../tasks/T-027-steering-curve-and-smoothing.md))

- [x] Top speed feels planted, not twitchy, with a turn radius of about
      17 m. The tuning knob is `steering_rate` (1.4) in
      `resources/vehicles/stovepipe_speedster.tres`.
- [x] Hairpins at low speed feel agile (about 5-7 m radius).
- [x] Tapping left and right moves the nose smoothly, not in snaps
      (`steer_ramp_time` 0.17 s).
- [ ] A gamepad stick still feels direct with the ramp on.
- [x] Stopped against a wall, a little reverse frees the car (no
      rotation below 1 m/s).

## 2. Drift slide ([T-028](../tasks/T-028-grip-and-drift-slide.md))

- [x] With F3 on, a held drift through the barrier corners reads about
      20-35 degrees of slide and stays controllable. Steering in
      tightens the line, steering out widens it, and neither ends the
      drift.
- [x] Drifting does not cost speed. Say if it feels like a free lunch.
- [x] A slow hairpin can still be drifted (minimum 11 m/s).
- [x] A normal full-lock turn feels planted, not icy (about 4 degrees of
      slip).
- [ ] A drift over a bump or a ramp lip does not cancel unexpectedly.
- [ ] The overlay's `Drift:` line shows the side and the slide.

## 3. Walls ([T-029](../tasks/T-029-wall-contact-response.md))

- [x] Glancing a wall keeps momentum. The car slides off and carries on,
      and does not grind to a stop (your FC-1 comment).
- [x] A head-on hit at full speed bounces the car back. It feels fun, not
      punishing (`wall_restitution` 0.4).
- [x] Holding throttle into a wall gives a few shrinking bounces, not
      jitter.
- [x] A glancing hit does not feel like the game is steering for you
      (`wall_align_time` 0.1 s).
- [x] Each crash still shakes the camera once.

## 4. Ramps, air, landing ([T-030](../tasks/T-030-ramp-launch-air-landing.md))

- [x] Both ramps launch the car now. About 1.2 s of air feels snappy, not
      floaty (`air_gravity_scale` 1.6).
      - adds a bounce at top, this may be ok, still debating
      - the bounce feels like it occurs after leaving the ramp instead of while on the ramp
        - *Agent:* Measured and fixed in
          [T-037](../tasks/T-037-ramp-crest-hitch.md). At the top edge the
          car held level for about 80 ms, with its rear on the edge, and
          was then launched: a hitch and a second pop. Now the climb
          carries straight off the edge (6.2 m/s up, then gravity only).
          Jump again: any bounce left is the launch itself.
- [ ] Ramp2 is now a 20-degree, 2.5 m kicker (it was 30 degrees and 8 m).
      Is it big enough?
- [ ] In the air the nose turns a little (25%), but the line holds.
      Landings feel controllable.
- [x] A clean landing keeps your speed. Jumping is not a speed boost.
- [x] Driving into the foot of a ramp never pops the car into the air.

## 5. Drift boost tiers ([T-031](../tasks/T-031-drift-charge-tiers-boost.md))

- [ ] Tier 1 lands on a normal corner, about 0.85 s of drifting into the
      turn. Tier 2 comes at 1.9 s and tier 3 at 3.0 s.
- [ ] Releasing pays a boost you can feel: +4.8 m/s for 0.7, 1.45 or
      2.3 s. Tier 3 feels worth the risk.
- [ ] Steering out of a drift charges more slowly (40%). It feels like a
      fair trade.
- [ ] Braking out, or hitting a wall hard, loses the charge. That feels
      fair.
- [ ] After a boost, the speed eases back down and does not snap.

## 6. Visual body ([T-032](../tasks/T-032-visual-body-ground-alignment.md))

- [x] The car leans into corners (up to 10 degrees), and the lean looks
      right.
- [x] On the ramps the body tilts to the slope. In the air the nose
      follows the arc.
- [x] Starting a drift gives a small hop. It feels alive, not silly.
- [x] Each tier is obvious from the sparks and the glow: cyan, then amber,
      then magenta. The car still reads as red.
- [x] A boost glows brighter in the tier's colour.

## 7. Tricks ([T-033](../tasks/T-033-trick-boost.md))

- [x] Tap the drift button just as you leave a ramp. The car does a barrel
      roll and boosts on landing (+6.7 m/s for 0.9 s, white glow).
- [ ] The timing window (0.15 s, plus a 0.2 s early buffer) feels fair,
      not random.
- [ ] You never trick by accident when trying to drift right after a
      landing.
- [x] A trick landing feels worth it next to a tier-2 drift boost.

## 8. Camera ([T-034](../tasks/T-034-chase-camera-tuning-pass.md))

- [ ] Speed reads on the straight: the FOV widens a little at top speed
      (+4 degrees).
- [ ] A boost widens it more (+8 to +12 by tier) and pulls the camera back
      a little. It feels fast, not like a fish-eye.
- [x] In a drift the camera looks down the travel direction, so the road
      stays in view and the car is angled across the screen. It does not
      look too sideways.
- [ ] Entering and leaving a drift never snaps the camera.

## 8b. Tuning circuit ([T-035](../tasks/T-035-tuning-circuit.md))

A second, larger map. Press **F4** in game or run `task run:circuit`. The
layouts are in [test-tracks.md](../design/test-tracks.md).

- [x] F4 switches maps, and the car starts behind the start line.
- [x] The 14 m road feels right for drifting and (later) four cars.
- [x] The R10 hairpin needs a brake or a drift, and drifting it is fun.
- [x] The R35 sweeper holds a drift long enough for tier 3.
- [x] The kicker launches cleanly, and the trick window works there too.
- [ ] Pick the next layout to build (B to E in `test-tracks.md`).
- [x] Each map (and each F4) opens on a still shot above and behind the
      car, then flies smoothly into the chase camera
      ([T-036](../tasks/T-036-intro-camera-and-jump-walls.md)).
- [x] The jump walls no longer flicker against the barriers. Say if they
      still feel heavy (the option is a see-through catch fence).

## 9. The gate

- [x] One car on one track is fun (Guardrail 3). If not, say what is
      missing, and the next round becomes tickets.
      - could chaining drifts be possible?
      - could nuilding up a boost be done over time , and using space to boost when not turning and space to drift when turning work?
      - time without boosting or drifitng would slowly drain boost guage?
      - thougths and chalenges, counters and alternatives
  - *Agent:* **Gate passed (2026-11-26).** Phases 3-4 of the addon plan
    are unblocked (T-012 to T-015 are now Todo). The boost and drift
    questions are answered in
    [boost-meter-and-drift-chains.md](../design/boost-meter-and-drift-chains.md):
    genre evidence (CTR reserves, Mario Kart DS snaking and its removal,
    Burnout and Hot Wheels meters), plus options, challenges, counters
    and a recommendation. In short: a hybrid "bank" gauge, a chain combo
    with anti-snaking counters, and a cap with no drain. Pick a
    direction to prototype.


## 10. New since the gate: boost and drift depth (prototypes)

From your FC-2 questions, built to your choices. See
[boost-meter-and-drift-chains.md](../design/boost-meter-and-drift-chains.md).

- [ ] **Drift chain** ([T-038](../tasks/T-038-drift-chain.md)): link
      left-right drifts within 0.75 s through the chicane and the
      sweeper. Each link makes the payout 25% longer (F3 shows
      `CHAIN xN`). Weaving on a straight should earn nothing.
- [ ] **Boost gauge** ([T-039](../tasks/T-039-boost-gauge-contextual.md)):
      releases bank charge into the pips on the car's back. A **quick tap**
      of space with no steer spends one segment. Hold and steer still
      drifts. You never spend by accident when you press, then steer.
- [ ] **Overcharge:** chaining past three full pips lights the hot pip,
      which pulses and drains about 2 s after your last charge. It feels
      like a nudge to spend, not a punishment.

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
