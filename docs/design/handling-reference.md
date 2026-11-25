# Kart-Racer Handling Reference

**Ticket:** [T-017](../tasks/T-017-handling-genre-research.md)
**Date:** 2026-11-25
**Purpose:** Genre conventions with target numbers for the handling rework.
**Not a design copy.** This doc records how the genre solves each problem.
Our game is original. We pick numbers from these ranges. We do not
reproduce any one game's handling, names or presentation.

## How to read the numbers

- Units match the code: metres (m), metres per second (m/s), radians per
  second (rad/s), seconds (s). Source frame counts are converted at
  60 frames per second.
- Each number carries a tag.
  - **[P]** primary: engine source, config files or developer statements.
  - **[S]** secondary: fan wiki or community datamine. Fan wikis can be
    wrong. Treat them as measurements, not specs.
  - **[E]** our estimate. The derivation is stated next to it.
- Our current values come from `scripts/vehicles/vehicle_controller.gd`
  and `resources/vehicles/stovepipe_speedster.tres`. Top speed is
  24 m/s, so "20% of top speed" means about 4.8 m/s.

### Current values at a glance

| Field | Value | Notes |
|---|---|---|
| `max_speed` | 24.0 m/s | about 86 km/h |
| `acceleration` | 14.0 m/s^2 | 0 to top speed in about 1.7 s |
| `braking_force` | 22.0 m/s^2 | |
| `steering_rate` | 2.4 rad/s | at top speed. Scales linearly with speed. |
| `drift_grip` | 0.55 | lerp factor applied per physics tick |
| `air_control` | 0.35 | scales throttle, yaw and velocity re-blend |

## 1. Steering

### Convention

- Yaw rate does not grow with speed forever. Karts turn on a
  **turn radius that grows with speed**, so yaw rate stays roughly flat
  at 1.1 to 1.5 rad/s once the kart is moving.
- At a standstill the kart barely rotates. Rotation fades in over the
  first few m/s.
- Steering input is **smoothed**. Full lock takes a fraction of a second,
  and reversing direction is slower than ramping up from centre.
- No true counter-steer is needed outside a drift. Counter-steering
  appears inside drifts (section 2).
- Analog input is passed through as a scaled value. Digital input is
  ramped by the game so a keyboard feels like a soft analog stick.

### Evidence

- SuperTuxKart (open source) defines turn radius against speed for a
  medium kart: 2.3 m at 0 m/s, 8.625 m at 10 m/s, 17.25 m at 25 m/s,
  34.5 m at 45 m/s. [P]
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/kart_characteristics.xml>
- Derived yaw rate is speed divided by radius. [E] At 10 m/s it is
  1.16 rad/s. At 25 m/s it is 1.45 rad/s. At 45 m/s it is 1.30 rad/s.
- SuperTuxKart ramps steering over `time-full-steer`: 0.17 s from centre
  and 0.28 s when reversing across centre. [P] Same file as above.
- Feel-wise, the original SNES kart racer's designers dropped realistic
  counter-steer drifting because most players could not do it. They kept
  tuning controls until they felt right, not until they were accurate. [P]
  <https://gamedeveloper.com/design/the-design-origins-of-drifting-in-i-mario-kart-i->
- A Godot arcade car recipe (MIT) turns only above 0.75 m/s and slerps
  heading toward the target at `turn_speed = 4.0` per second. [P]
  <https://github.com/godotrecipes/3d_car_sphere>

### Target ranges

| Parameter | Target | Source / derivation | Current |
|---|---|---|---|
| Yaw rate at 10 m/s, full lock | 1.1-1.4 rad/s | STK-derived, above [P/E] | 1.0 rad/s (2.4 x 10/24) |
| Yaw rate at 24 m/s (top), full lock | 1.2-1.6 rad/s | STK-derived, above [P/E] | 2.4 rad/s |
| Turn radius at top speed | 15-20 m | speed / yaw rate [E] | 10 m |
| Turn radius at 10 m/s | 7-9 m | STK 8.6 m [P] | 10 m |
| Standstill steering | none below about 1 m/s, fade in to full by about 6-8 m/s | Recipe cutoff 0.75 m/s [P]; fade is [E] | none below 0, full at 24 |
| Steer input ramp, centre to full | 0.15-0.2 s | STK 0.17 s [P] | none (raw input) |
| Steer input ramp, across centre | 0.25-0.3 s | STK 0.28 s [P] | none |
| Steering reversal in reverse | do not invert | our existing code, keep | already done |

### Gap against current code

- Current radius is a constant 10 m because yaw rate scales linearly with
  speed. Genre karts use a **flat or falling** yaw rate with speed, so
  they get a wider radius when fast. The current curve is why high speed
  feels twitchy and low speed feels sluggish.
- There is no input smoothing in the controller. Keyboard users get
  instant full lock.
- Turn-in delay: the genre gets it from the input ramp (0.15-0.2 s), not
  from a separate delay. Do not add a dead time.

## 2. Drift

### Convention

- **Entry:** hold a drift button while steering and moving fast enough.
  Many games add a small hop. Realistic counter-steer drifting was
  rejected by the genre's originators. [P] (link above)
- **Direction lock:** the drift direction is fixed when the drift starts.
  Steering then only adjusts the line inside a band, it cannot flip the
  drift.
- **Slide angle:** the car body points away from the velocity vector by
  up to about 45 degrees on outward-drifting vehicles. [S]
- **Steering during drift:** the stick maps to a **reduced** turn range.
  Steering into the turn tightens the line. Steering out widens it.
  Neither exits the drift.
- **Charge:** time spent drifting charges a boost in tiers. Steering
  into the turn charges faster than countersteering.
- **Release:** letting go of the button pays out the highest tier
  reached. Dropping below minimum speed cancels the drift without a
  payout.

### Evidence

- Mario Kart Wii family charge data. [S]
  <https://wiki.mkwtas.com/wiki/Miniturbo>
  - Charge rate: 5 per frame when steering toward the turn, 2 per frame
    otherwise.
  - Tier 1 at charge above 270, tier 2 about 300 charge later (total 570).
  - Best case: 54 frames (0.9 s) to tier 1, 114 frames (1.9 s) to tier 2.
  - Worst case (default stats, 2 per frame): 136 frames (2.3 s) to tier 1.
  - Boost duration: tier 1 lasts 15-48 frames (0.25-0.8 s). Tier 2 lasts
    three times as long, 45-141 frames (0.75-2.35 s).
  - Boost strength: +20% on maximum speed.
  - Spark cues appear at charge 150 and 180 before tier 1, so the player
    sees progress before the payout.
- Same family, drift start and angle. [S]
  <https://wiki.mkwtas.com/wiki/Manual_drift>
  - A drift only starts above 55% of base top speed.
  - Outward-drifting vehicles rotate up to 45 degrees off the velocity
    vector.
  - There is no speed loss from drifting itself.
- A later entry in the same series: tier 1 about 0.62 s, tier 2 about
  1.67 s, tier 3 about 2.63 s of boost, stat dependent. [S]
  <https://www.mariowiki.com/Mini-Turbo> (cites the game's own tutorial)
  Charge thresholds there: 135 (sparks), 270, 570. [S]
- Fan-estimated boost lengths for the same later entry range 28-188
  frames by stat and charge. [S, estimated from video frame counts]
  <https://kotaku.com/everything-you-didn-t-know-about-drifting-in-mario-kart-1819196173>
- SuperTuxKart skid config. [P]
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/kart_characteristics.xml>
  - `min-speed = 10` m/s.
  - `time-till-bonus = 1.0 3.0` s: tier 1 after 1 s, tier 2 after 3 s.
  - `bonus-speed = 4.5 6.5` m/s extra, `bonus-force = 250 350`.
  - `bonus-time = 3.0 4.0` s. The units were not confirmed in the file
    comments, and the numbers look long next to the other games. Treat
    as unverified.
  - `reduce-turn-min/max = 0.2 / 0.8`: steering inside a skid is remapped
    into 20-80% of full turn.
  - `time-till-max = 0.5` s to reach the maximum slide factor (2.5x).
  - `graphical-jump-time = 0.4` s: a visual-only hop of 0.4 s, no
    physical hop.
  - Source code for the mapping and cancel rules:
    <https://raw.githubusercontent.com/supertuxkart/stk-code/master/src/karts/skidding.cpp>
    (GPLv3: read for technique, do not copy code.)
  - Boosts of 4.5 and 6.5 m/s match 16.2 and 23.4 km/h in a speedrun
    guide, which could not be re-fetched. [S]

### Target ranges

All times are seconds at 60 Hz. Percentages are of top speed (24 m/s).

| Parameter | Target | Source / derivation | Current |
|---|---|---|---|
| Entry | button held + steer, speed above min | all sources | held button only, no steer or speed check |
| Minimum speed to drift | 40-55% of top (10-13 m/s) | MKW 55% [S]; STK 10 m/s [P] | none |
| Entry hop | visual only, 0.3-0.4 s, no physics hop | STK 0.4 s visual [P] | none |
| Direction lock | locked at entry | genre-wide [S] | none, follows live steer |
| Steer range inside drift | 20-80% of normal turn | STK 0.2-0.8 [P] | full |
| Max slide angle | 25-45 degrees | MKW 45 degrees [S]; lower bound [E] for couch readability | not tracked |
| Tier 1 charge time | 0.9-1.0 s | MKW best 0.9 s [S]; STK 1.0 s [P] | none |
| Tier 2 charge time | 1.9-2.5 s total | MKW best 1.9 s [S] | none |
| Tier 3 (optional) | 3.0 s total | later entry tutorial [S], STK tier 2 at 3 s [P] | none |
| Charge rate when steering out | about 40% of in-turn rate | MKW 2 vs 5 per frame [S] | none |
| Boost duration, tier 1 | 0.5-0.8 s | MKW 0.25-0.8 s [S]; later entry 0.62 s [S] | none |
| Boost duration, tier 2 | 1.2-1.7 s | later entry 1.67 s [S] | none |
| Boost strength | +15-25% of top speed (3.6-6 m/s) | MKW +20% [S]; STK 4.5-6.5 m/s [P] | none |
| Cancel | release pays out; below minimum speed or crash cancels with no payout | STK [P] | none |
| Slide grip (lateral velocity decay) | frame-rate independent, about 0.3-0.6 s time constant | [E] see below | `drift_grip = 0.55` per tick |

### Slide time constant, derived

[E] Current code does `flat_velocity.lerp(target, 0.55)` once per physics
tick. At 60 Hz, 45% of the sideways error remains after one tick and
under 1% after 8 ticks (0.13 s). That is an effective time constant of
about 0.02 s, so the slide is nearly invisible. It also changes with the
physics rate. A frame-rate independent form is
`lerp(target, 1 - exp(-delta / tau))`. Start with tau = 0.4 s while
drifting and 0.05-0.08 s while gripping.

### Gap against current code

- No charge, no tiers, no payout. This is the largest gap.
- Drift has no direction lock and no hop.
- Slide strength is per tick, not per second.
- STATE.md says "regular/super/ultra" tiers. Research agrees for the
  newest entries only. The Wii-era and open-source references use
  **two tiers**. Start with two and treat a third as optional.

## 3. Ramps, air, landing

### Convention

- **Air control:** small. Steering adds a few degrees of yaw and nothing
  else. Velocity direction is mostly kept from launch. Throttle does not
  accelerate in the air.
- **Trick input:** a button press within a short window after takeoff
  gives a landing boost. The boost is shorter than a drift boost but
  stronger per second.
- **Landing boost:** applied on landing, not during flight.
- **Landing alignment:** the car snaps to the ground normal over a few
  frames, and velocity is redirected along the new surface. Speed is not
  lost on a clean landing.
- **Slope alignment on ground:** the visual body follows the surface
  normal smoothly. Physics stays upright.

### Evidence

- Trick data from the Mario Kart Wii TAS wiki. [S]
  <https://wiki.mkwtas.com/wiki/Trick>
  - Input window: from airtime frame 3 to frame 10 (0.05-0.17 s after
    takeoff). Input can be buffered up to 13 frames before takeoff.
  - Cooldown: 5 frames (0.08 s) after the trick fires.
  - Trick boost on karts: 40 frames (0.67 s) for a small stunt, 70 frames
    (1.17 s) for a single flip, 85 frames (1.42 s) for a double flip.
    Bikes are 5-10 frames longer.
  - Boost strength: +30% on maximum speed. This is higher than the drift
    boost (+20%) because the trick needs a ramp.
  - The boost starts on landing. If the car lands before the cooldown
    ends, the boost waits for the cooldown.
  - A trick needs speed at least 50% of base top speed.
  - Redirection while flying: 11-15 degrees on small stunts, 16-20 on
    flips, capped at 32-45 degrees total.
- The same page says karts cannot lean, so they have less air control
  than bikes.
- Open-source technique for ground alignment (Godot recipe, MIT): build
  a basis from the floor normal and interpolate toward it at
  `10 * delta`; lerp body roll toward a target at `5 * delta`. [P]
  <https://github.com/godotrecipes/3d_car_sphere>
- STATE.md claims that one other racer gives *more* air control than
  ground control. I could not verify that in this research. Do not use
  it as a target.

### Target ranges

| Parameter | Target | Source / derivation | Current |
|---|---|---|---|
| Air yaw rate | 15-30% of ground yaw | [E] consistent with 11-20 degree redirection [S] | 35% of ground yaw |
| Air throttle | none (0%) | [E] speed is preserved from launch | 35% of throttle |
| Air velocity re-blend | none, keep launch velocity | [E] | lerps toward facing at 0.35 per tick |
| Gravity while airborne | 1.3-1.8 x 9.8 m/s^2 | [E] arcade jumps need snappier falls; start at 1.5 and judge by hang time | 9.8 |
| Jump hang time over a ramp | 0.6-1.2 s | [E] long enough to trick, short enough for a loop of 4 cars | not measured |
| Trick window | 0.05-0.2 s after takeoff, buffered 0.2 s before | MKW 3-10 frames, 13 buffered [S] | no trick |
| Trick cooldown | 0.08 s | MKW 5 frames [S] | none |
| Trick boost duration | 0.6-1.2 s | MKW 40-70 frames [S] | none |
| Trick boost strength | +25-30% of top speed (6-7 m/s) | MKW +30% [S] | none |
| Min speed to trick | 50% of top (12 m/s) | MKW 50% [S] | none |
| Landing alignment time constant | 0.08-0.12 s | Recipe `10 * delta` is tau 0.1 s [P] | none |
| Speed lost on landing | 0 on a clean landing | genre [S] | not applicable |

### Gap against current code

- **Ramps do not launch the car.** Grounded frames set `velocity.y = 0`.
  After leaving a ramp, the car has no upward velocity from the slope.
  `move_and_slide()` also snaps and slides along floors by default
  (`floor_snap_length` 0.1 m, `floor_stop_on_slope` true).
  <https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html>
  The rework must carry the pre-ramp velocity along the slope and keep it
  when leaving the floor.
- No slope alignment. The body stays upright and level on ramps.
- No trick input, no landing boost.
- Airborne re-blend pulls velocity back to the facing direction. This is
  the opposite of keeping launch momentum.

## 4. Camera (input for T-005)

[Phantom Camera](../adr/ADR-013-camera-addon-phantom-camera.md) will drive
a Third Person follow rig. These are **starting values**, not final. Most
are [E] derived from the few open sources below. Final values come from
the FC-1 drive.

### Evidence

- SuperTuxKart chase camera, from source. [P]
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/src/graphics/camera/camera_normal.cpp>
  - Distance behind the kart grows with speed:
    `-2.8 - 5.6 * (speed / max_speed)`. That is 2.8 m at rest and 8.4 m
    at top speed in world units (about metres; kart scale unverified).
  - Height: `0.85 + ratio / 2.5`, so 0.85 m at rest and 1.25 m at top.
  - Aim point is 0.75 m above the kart.
  - Pitch up-angle is 0 degrees when going forward, 5 degrees in reverse
    (config default).
  - Position and rotation are smoothed with `delta = dt / max(dt, T)`.
    That is a first-order filter, so T is a time constant in seconds.
    T is set by user config, and its default was not found.
  - Sideways sway from steering exists in code but is disabled.
  - Flying (falling) camera: 4 m behind the heading at 0.5 m height.
- SuperTuxKart field of view by player count: 80 degrees for one player,
  65 for two, 50 for three and four. [P]
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/stk_config.xml>
  The config does not change FOV with speed or boost.
- A mod for a known kart racer sets 80 degrees to fix a weak sense of
  speed. [S, from a search snippet, not opened]
  <https://modworkshop.net/mod/53909>
- Community chase cams for a driving sim use 3.1 m distance and 1.4 m
  height, or 3.5 m and 1.8 m. [S, not opened]
  <https://www.overtake.gg/downloads/j-spec-chase-cam.69347>
- A 2018 GDC talk on vehicle feel covers input choices and camera design.
  I could not read it. [P, not read]
  <https://gamedeveloper.com/design/video-balancing-accessibility-with-depth-to-make-vehicles-feel-great>
- Godot `Camera3D.fov` is vertical by default, in degrees. [P, engine docs
  knowledge, not re-fetched]

### Starting values

Our car length and hat height are not fixed yet. Distances below assume a
body of about 2.5 m long. Scale them by the final body length.

| Parameter | Start value | Range to try | Source / derivation |
|---|---|---|---|
| Follow distance at rest | 4.5 m | 4-5.5 m | STK 2.8 m is for a small kart. Add room for tall hats. [E] |
| Follow distance at top speed | 6.0 m | 5.5-7.5 m | STK grows by 5.6 m, which is large. We add about 1.5 m only. [E] |
| Distance blend | linear in speed ratio | | STK [P] |
| Height at rest | 2.2 m | 1.8-2.6 m | STK 0.85 m scaled for hats plus 1 m over the bonnet. [E] |
| Height at top speed | 2.5 m | 2.2-3.0 m | STK adds 0.4 m. [E] |
| Aim point above car | 1.0 m above origin, plus hat height | 0.8-1.4 m | STK 0.75 m. [E] |
| Look-ahead | 4-6 m ahead along velocity at top speed, 0 at rest | 3-8 m | [E] frames the road, STK sets none |
| Resulting pitch | about 12-15 degrees down | 8-18 degrees | `atan(height-aim / distance)` for the values above [E] |
| Position follow lag (time constant) | 0.15 s | 0.1-0.25 s | Unity forum warns high damping drags the camera [S]; STK T unknown [E] |
| Rotation follow lag (time constant) | 0.25 s | 0.15-0.4 s | Rotation slower than position hides jitter [E] |
| Vertical follow lag | 0.3 s | 0.2-0.5 s | Ramps and bumps should not jerk the view [E] |
| Base FOV, 1 player, vertical | 75 degrees | 70-80 | STK 80 for one player [P] |
| Base FOV, 2 players split | 70 degrees | 65-75 | STK 65 [P] |
| Base FOV, 3-4 players split | 55-60 degrees | 50-65 | STK 50 [P] |
| FOV boost delta | +8 degrees, up to +12 for the strongest boost | +5 to +15 | Weak sense of speed fixed by 80 degrees [S]; amount [E] |
| FOV boost attack | 0.15 s in | 0.1-0.25 s | [E] |
| FOV boost decay | 0.5 s out | 0.3-0.8 s | [E] slow release feels like deceleration |
| FOV by speed alone | +0 to +4 degrees across 0 to top speed | | [E] STK has none |

### Drift behavior

[E] unless noted.

- Do **not** rotate the camera fully with the car's body angle. Follow the
  **velocity heading** blended with the body heading at about 50-70%
  velocity. This keeps the road in view during a 30-45 degree slide.
- STK has a `camera_follow_skid` option, so some games follow the skid
  rotation. [P] Keep it as a tunable toggle.
- Roll the camera 0-3 degrees into the turn. Optional, off by default.
- Widen rotation lag to 0.35-0.5 s while drifting, so entering a drift
  does not snap the view.
- Add a small outward offset, 0.3-0.5 m, to show the inside of the turn.
- During a boost, pull the camera 0.3-0.6 m further back and hold the FOV
  delta. Do not shake it by default. Add shake as a separate effect later.

### Airborne behavior

- STK drops to a rigid chase 4 m behind the heading at 0.5 m height while
  falling. [P] That is a hard switch we should avoid.
- Freeze the **world-space height** of the camera target during a jump,
  and keep following in X and Z. The car rises and falls in frame.
  Return to normal vertical follow over 0.3-0.5 s after landing. [E]
- Pitch the camera down by 0-5 degrees at the peak of a long jump so the
  landing zone stays visible. [E]
- Keep FOV at its current value. No FOV pop on takeoff. [E]
- Lower vertical damping for the first 0.2 s after landing, so the
  landing thump reads. [E]

### Reverse

- Reverse look is allowed to swing behind the car with a separate setting
  (STK uses its own angle and distance, with smoothing off). [P]
- Our controller flips the yaw direction in reverse, like a real car
  (`signf(current_speed)` in `vehicle_controller.gd`). Keep the camera
  behind the car when reversing for now. [E]

## 5. Implementation techniques

### Option A: CharacterBody3D (what we use now)

- Pros: simple. Stable on tracks built from static collision. Good for
  split screen cost.
- Cons: no built-in physics reaction. Slopes, ramps and landing need
  manual code. This is the cause of the current ramp gap.
- Useful settings: `floor_snap_length` (0.1 m default) stops the car
  leaving the ground on small bumps, but it also prevents small ramp
  launches. Set it to 0 or a small value during a launch, and restore it
  after landing. `floor_constant_speed` (false by default) keeps speed on
  slopes. `up_direction` can be set to the floor normal for non-flat
  tracks. [P]
  <https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html>

### Option B: sphere collider rig

- A sphere (RigidBody3D) rolls and carries all physics. A separate car
  mesh follows it. Steering rotates the mesh, throttle pushes the sphere.
  [P] <https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car> and
  <https://github.com/godotrecipes/3d_car_sphere> (MIT).
- Recipe values: acceleration 35 force units, turn speed 4.0, min
  speed to turn 0.75 m/s, body tilt divisor 35. [P]
- Pros: natural ramps, slopes and landing. A sphere does not catch on
  track seams.
- Cons: harder to make deterministic. Drift and speed caps need extra
  code. Rigid bodies and splitscreen network sync are more costly.
  ADR-009 plans networking, which favours code-driven motion. [E]
- A Godot Kenney starter kit uses the same idea with a RayCast3D to align
  the body. [S, from a search result]
  <https://doc.photonengine.com/fusion-godot/current/game-samples/racing-starter-kit>

### Visual tilt separated from physics

- Keep the physics body upright and aligned to yaw only. Put the car
  model on a child node, `VisualBody`, which receives:
  - roll into turns: target = `-steer * speed / divisor`, lerped at about
    5 per second (tau 0.2 s), [P] recipe above
  - extra yaw during a drift (the slide angle), so the body points off
    the velocity vector while the physics heading stays on the line
  - pitch and roll from ground normal
  - hop offset during drift entry
- Tall hats and tassels attach to `VisualBody` so they inherit tilt and
  can lag behind it. This keeps our identity visible in the tilt.

### Aligning to the ground normal

- Read `get_floor_normal()` after `move_and_slide()` when `is_on_floor()`.
  The doc warns the collision normal is not always the surface normal,
  so smooth it. [P] link above
- Build a basis with Y = normal, X = cross(normal, forward), then
  orthonormalise. Interpolate toward it at `10 * delta` (tau 0.1 s). [P]
- Apply this to `VisualBody` first. Apply to the physics body only if
  ramps need gravity along the slope.
- In the air, ease the body toward the velocity direction pitch, not a
  fixed up vector.

## 6. Our deviations

These tie to [game-pillars.md](game-pillars.md).

- **Hat-car identity.** Hats are tall. The camera needs more height and
  distance than a small kart needs (section 4). Visual tilt and slide
  angle should stay modest so the hat does not leave the frame. Cap
  visual roll at about 10 degrees and slide angle at 35 degrees to start.
  Tassels use the lag of `VisualBody`, which gives free drift
  readability: the tassel swings out during a slide.
- **Couch readability in splitscreen.** Four viewports are small.
  - FOV drops by player count (STK does this [P]).
  - Keep tiers visible by **sparks and body colour**, not by small UI.
  - Boost cues use camera FOV and trailing effects, large and clear.
  - Prefer **two tiers** over three so a spectator can tell them apart.
  - Camera shake is off by default in splitscreen.
- **Guardrail 3 ("1-Car Fun").** One car on one flat corner must feel
  good before anything else. So:
  - Steering and drift must work well **without** items or boost pads.
    The drift boost is a reward, not what makes the slide fun.
  - Steer smoothing and radius curve (section 1) come first.
  - Keep the number of tunables small. Start with about 12 parameters
    per car, not the dozens genre games expose.
  - Judge by the FC-1 drive, not by matching any number here.
- **Smaller, easier tiers for casual players.** Shorter charge times than
  the best-case genre numbers for tier 1 (0.8-0.9 s), so a new player
  gets a payout on a normal-length corner. [E]
- **Deterministic.** Tournament code must be deterministic (AGENTS.md).
  Use fixed-step physics and frame-rate independent smoothing
  (`1 - exp(-delta / tau)`), not per-tick lerp factors. Ticks, not
  floats, should drive charge counters.

## 7. Proposed rework tickets (titles and scope only)

Each is sized per [task-sizing.md](../standards/task-sizing.md). Order
reflects dependencies. Not written until the owner reviews this doc.

1. **Steering curve and input smoothing.** Speed-dependent yaw rate,
   standstill fade, steer ramp. Files: controller, `VehicleStats`,
   `InputSource` smoothing. Check: constant-radius circle at 3 speeds.
2. **Frame-rate independent grip and drift slide.** Replace per-tick
   lerps with time constants. Drift entry, direction lock, reduced steer
   range, slide angle. Depends on 1.
3. **Drift charge tiers and boost.** Charge timer, two tiers, release
   payout, cancel rules, boost speed and duration in `VehicleStats`.
   Depends on 2.
4. **Ramp launch, air behavior and landing.** Keep velocity off ramps,
   air yaw and gravity values, `floor_snap` handling, landing
   alignment. Depends on 1.
5. **Visual body split and ground alignment.** `VisualBody` node with
   roll, slide yaw and normal alignment. Depends on 2 and 4.
6. **Trick boost.** Trick window, cooldown, landing boost. Depends on 3
   and 4.
7. **Chase camera tuning pass (follows T-005).** Apply section 4 values
   in the Phantom Camera rig: speed distance, FOV boost, drift and air
   behavior, splitscreen FOV by player count.

## 8. Sources

Primary [P]:

- SuperTuxKart kart characteristics (turn, skid, camera defaults, nitro):
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/kart_characteristics.xml>
- SuperTuxKart config (FOV by player count, skid element):
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/stk_config.xml>
- SuperTuxKart skidding logic:
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/src/karts/skidding.cpp>
- SuperTuxKart chase camera:
  <https://raw.githubusercontent.com/supertuxkart/stk-code/master/src/graphics/camera/camera_normal.cpp>
- Godot recipe, sphere car (MIT):
  <https://github.com/godotrecipes/3d_car_sphere>,
  <https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car>
- Godot CharacterBody3D docs:
  <https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html>
- Design origins of drifting (developer interviews):
  <https://gamedeveloper.com/design/the-design-origins-of-drifting-in-i-mario-kart-i->

Secondary [S] (fan wikis, community measurements):

- <https://wiki.mkwtas.com/wiki/Miniturbo>
- <https://wiki.mkwtas.com/wiki/Manual_drift>
- <https://wiki.mkwtas.com/wiki/Trick>
- <https://www.mariowiki.com/Mini-Turbo>
- <https://kotaku.com/everything-you-didn-t-know-about-drifting-in-mario-kart-1819196173>

Not opened or not readable (listed for follow-up):

- GDC 2018, Criterion, "Balancing accessibility with depth to make
  vehicles feel great":
  <https://gamedeveloper.com/design/video-balancing-accessibility-with-depth-to-make-vehicles-feel-great>
- <https://modworkshop.net/mod/53909>
- <https://www.overtake.gg/downloads/j-spec-chase-cam.69347>
- <https://doc.photonengine.com/fusion-godot/current/game-samples/racing-starter-kit>
- Speedrun guide for STK skid bonuses (HTTP 403):
  <https://www.speedrun.com/stk/guides/674pf>

Licenses: SuperTuxKart code is GPL. We read it for technique and cite
numbers only. No code or data was copied. The Godot recipe is MIT. No
snippets are included here.
