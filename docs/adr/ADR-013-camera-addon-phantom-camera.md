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

### Alternatives Considered

1. **Keep growing `chase_camera.gd`:** Rejected. Collision, shake, blending
   and multi-viewport support together are weeks of undifferentiated work,
   which is Trap 1 in [critique-and-risks.md](../design/critique-and-risks.md).
2. **Built-in `SpringArm3D` + `Camera3D` only:** Viable for collision alone,
   but provides no blending, priority switching or shake. Those would still
   be needed for `PresenterDirector`.
