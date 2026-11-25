# ADR-013: Camera Rig Addon — Phantom Camera

**Status:** Accepted (adopt now, Phase A)

**Date:** 2026-11-24

---

### Context

`scripts/camera/chase_camera.gd` is a hand-rolled single `Camera3D`
trailing the car with exponential-decay smoothing. It has no collision
avoidance yet (its own comment defers it to "a future polish pass"), no
camera shake, and no notion of blending between cameras.

Upcoming work needs all three, plus more:

- **Feel testing now:** a chase camera that clips through walls or jitters
  makes handling feel worse than it is, which corrupts the Iteration 01
  hand feel-test (Guardrail 1).
- **Splitscreen (Tier 1):** one camera rig per `SubViewport`, each
  following its own car.
- **`PresenterDirector` (ADR-005):** priority-based cuts and tweened
  blends between many candidate cameras (lead car, bumper battle, ramp
  cam, crash cam).

Camera follow, damping, collision avoidance, shake and blending are
solved, undifferentiated infrastructure. The *heuristics* that decide
which camera is live remain game-specific and stay self-implemented per
[ADR-012](ADR-012-self-implementation-boundary.md).

---

### Decision

Adopt **Phantom Camera** (`ramokz/phantom-camera`, MIT) as the camera rig
layer for all gameplay and presenter cameras.

- Pin **v0.12** (released 2026-11-17; requires Godot 4.4+, uses the 4.6+
  editor dock on our 4.7.2). Verified via `gh api` on 2026-11-24.
- Vendor into `addons/phantom_camera/`, enabled in `project.godot`.
- Replace `ChaseCamera` with a `PhantomCamera3D` in Third Person follow
  mode on a `Camera3D` + `PhantomCameraHost`
  ([T-005](../tasks/T-005-replace-chase-camera-with-phantom-camera.md)).
- Use `PhantomCameraNoiseEmitter3D` for impact/boost shake
  ([T-008](../tasks/T-008-impact-camera-shake.md)).
- Splitscreen: one `PhantomCameraHost` per viewport, separated by the
  host-layer mechanism. Confirm this at splitscreen kickoff, not now.

**Autoload exception.** The plugin registers its own `PhantomCameraManager`
autoload. The AGENTS.md Autoload Policy limits autoloads to `EventBus` and
`GameConfig` for *first-party* code. This is accepted as vendor
infrastructure: it holds no per-race or per-player state that we own, and
gameplay code never calls it directly.

**Boundary (ADR-012).** Phantom Camera provides the rig: follow, damping,
collision, blend and shake. `PresenterDirector` cut selection, the crash-cam
trigger logic and replay-buffer playback remain our own code. Those systems
only *set priorities* on Phantom Camera nodes.

---

### Consequences

**Positive:**
- Collision avoidance, damping, look-ahead and shake arrive maintained.
  The ~97-line `chase_camera.gd` is deleted instead of grown.
- The same tool serves gameplay cameras and the future presenter camera
  bank, so there is no second camera system later.
- The editor viewfinder lets you tune camera feel without running the game.

**Negative / Tradeoffs:**
- One more vendored dependency with its own release cadence (same class of
  burden as GdUnit4 under ADR-007).
- An extra autoload owned by a third party (see exception above).
- v0.12 moved `PhantomCamera3D` to `_process` with
  `get_global_transform_interpolated()`. Our car moves in
  `_physics_process`. At high refresh rates this can show stepping unless
  physics interpolation is enabled. T-005 evaluates this and records the
  result.
- The addon ships optional C# wrapper scripts (`*.cs`). Our editor is not
  the .NET build, so these are inert. Do not delete them, because that
  would modify vendor code (AGENTS.md Boundaries).

---

### Notes for T-005

Read from the vendored v0.12 source on 2026-11-25 (T-004). v0.12 is still
the latest release. Paths are under `addons/phantom_camera/scripts/`. Line
numbers refer to v0.12 and will move if the addon is bumped.

**Release notes v0.11 to v0.12** (v0.11.0.1 to v0.11.0.4 are small fixes).
Breaking: `dead_zone_width` and `dead_zone_height` became `Vector2`, and
`append_look_at_target` became `append_look_at_targets`. Neither touches a
Third Person chase camera. v0.12 also rewrote Third Person from scratch (it
no longer uses `SpringArm3D`) and moved `PhantomCamera3D` to `_process`.

**Third Person and yaw.**
- Mode is `FollowMode.THIRD_PERSON` (`phantom_camera/phantom_camera_3d.gd:88`).
  Distance is `spring_length` (`:569`). The camera sits behind a `ShapeCast3D`
  that the addon creates as a sibling (`:1146-1186`).
- Yaw does not follow the car on its own. The cast's rotation is set from
  `horizontal_rotation_offset` and `vertical_rotation_offset` (`:555-565`) or
  from `set_third_person_rotation(_degrees)` / `set_third_person_quaternion`
  (`:2480-2520`). T-005 must write the car's heading into one of these each
  frame.
- Position comes from `follow_target.get_global_transform_interpolated()`
  plus `follow_offset` (`:1543-1547`).

**Damping math.** Follow damping and look-at damping are different.
- *Position* (`follow_damping_value`, a `Vector3`, per world axis X/Y/Z,
  default 0.1): `_smooth_damp` (`:1684-1705`), called per axis from
  `_follow_position_damping` (`:1566-1578`). It is a critically damped
  spring (the Unity `SmoothDamp` formula): `omega = 2 / T`,
  `x = omega * dt`, `exp = 1 / (1 + x + 0.48x^2 + 0.235x^3)`. So the value is
  a **smooth time T in seconds**, not a factor. It is frame-rate independent.
  It is also not a first-order time constant:
  - Steady-state lag behind a target moving at speed `v` is `v * T`. A
    first-order filter with time constant `tau` lags `v * tau`. So **`T = tau`
    gives the same chase distance**, and this is the best start for a chase
    camera.
  - Step response: 63% at about `0.57 T`, 95% at about `2.4 T`. To match a
    first-order 63% time instead, use `T = 1.74 * tau`.
  - Y is damped separately (`follow_damping_value.y`), so the vertical 0.3 s
    maps to `y = 0.3` and the 0.15 s position maps to `x = z = 0.15`.
- *Rotation* (`look_at_damping_value`, a `float`, default 0.25;
  `_interpolate_rotation`, `:1648-1681`): a quaternion slerp each frame with
  `t = min(1, dt / T)`. That is a first-order filter with **time constant
  `tau = T`** (frame-rate dependent in the usual lerp way). It only runs when
  a look-at mode is active (`:1221-1226`). **Third Person has no rotation
  damping of its own.** T-005 either adds a look-at target or smooths yaw
  itself before calling the setter above. (Inference from reading the code.
  Confirm by running it.)
- Collision is applied after damping (`_set_third_person_camera`,
  `:1581-1621`), so a wall pulls the camera in at once. It is not smoothed.

**Collision.** `collision_mask` (`:574`, default `1`, which is our `Track`
layer) and `margin` (`:586`, default `0.01`, passed to the cast). `shape`
(`:580`) defaults to a pyramid built from the camera frustum. The follow
target's own bodies are excluded automatically (`:1171-1174`). The release
notes say to use **Jolt** for collision. The project already does (ADR-021).

**`_process` vs. physics interpolation.** `PhantomCamera3D.process_logic` is
called from `PhantomCameraHost._process` (`phantom_camera_host/phantom_camera_host.gd:823-850`).
Setting the host's `interpolation_mode` to `Physics` no longer has any effect
on 3D cameras (release notes). The camera reads the target's
*interpolated* transform. That only smooths anything if
`physics/common/physics_interpolation` is on, and it is **off** in
`project.godot` today. For a physics-based follow target the addon prints a
jitter tip (`phantom_camera_3d.gd:2030-2044`) unless
`phantom_camera/tips/show_jitter_tips` is set. T-005 decides whether to turn
physics interpolation on.

**Godot 4.7.** v0.11.0.3 fixed the `PhantomCameraManager` autoload not being
unregistered on 4.7.1. v0.11.0.4 stopped the plugin restarting the editor on
enable. The v0.11.0.3 notes mention
`Node not found: "PhantomCameraManager"` errors that wait on an upstream
Godot fix (godot PR 121509). We did not see them on 4.7.2.

---

### Alternatives Considered

1. **Keep growing `chase_camera.gd`:** Rejected. Collision, shake, blending
   and multi-viewport support together are weeks of undifferentiated work,
   which is Trap 1 in [critique-and-risks.md](../design/critique-and-risks.md).
2. **Built-in `SpringArm3D` + `Camera3D` only:** Viable for collision alone,
   but provides no blending, priority switching or shake. Those would still
   be needed for `PresenterDirector`.
