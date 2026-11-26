# ADR-016: Debug Visualization Addon — Debug Draw 3D

**Status:** Accepted (adopt now, Phase A; dev-only)

**Date:** 2026-11-24

---

### Context

The Iteration 01 gate is a hand feel-test. The current F3 `DebugOverlay`
shows numbers (speed, input, FPS), but drift and handling problems are
spatial:

- Is velocity lagging facing by the expected slip angle?
- Is the floor normal what we think it is on the ramp?
- Did `is_on_floor()` drop for one frame on a seam?

Seeing these as in-world vectors makes tuning `VehicleStats` much faster.
Drawing lines, arrows and text in 3D is generic tooling with no game
identity value.

---

### Decision

Adopt **Debug Draw 3D** (`DmitriySalnikov/godot_debug_draw_3d`, MIT) as a
**dev-only** in-world debug drawing tool.

- Pin **v1.7.3** (released 2026-04-04; verified via `gh api` on
  2026-11-24). The README lists Windows, Linux, macOS, Android 5.0+, iOS
  and Web.
- It is a native GDExtension, so it must pass the
  [ADR-015](ADR-015-native-gdextension-addon-policy.md) checklist
  ([T-006](../tasks/T-006-vendor-debug-draw-3d.md)).
- Usage lives only in a separate component,
  `scripts/vehicles/vehicle_debug_draw.gd`, added as a child of the car
  scene and gated on `GameConfig.debug_mode` (F3)
  ([T-007](../tasks/T-007-vehicle-debug-vectors.md)).
  `VehicleController` never references `DebugDraw3D`.
- Release behavior: T-006 confirms whether the release-template build of
  the extension is inert. If it is not inert, exclude the addon and the
  component from release exports with an export filter (ADR-015 check 6).

Known 4.7 issue: upstream #112 (`DebugDraw2D.set_text` is broken in the
4.7 *editor* for `@tool` scripts). It does not affect runtime 3D drawing,
which is all we use.

---

### Consequences

**Positive:**
- Velocity vs. facing, slip angle, floor normal and grounded state become
  visible while driving. This directly supports Guardrail 1 hand testing.
- The same tool serves checkpoint, AI lane and hazard-telegraph debugging
  later.

**Negative / Tradeoffs:**
- Native binaries in the repo (see ADR-015 check 5).
- A known editor-only text bug on 4.7 (see above).

---

### Alternatives Considered

1. **Hand-rolled `ImmediateMesh` line drawer:** Viable fallback and pure
   GDScript. Rejected as the default because Debug Draw 3D already handles
   batching, per-frame lifetimes, text and shapes. Fall back to this if
   ADR-015 checks fail.
2. **Numbers only in `DebugOverlay`:** Rejected. Spatial problems are hard
   to read as numbers.

---

### ADR-015 checklist results (T-006, 2026-11-25)

Pinned release: **1.7.3** (2026-04-04), the latest release on 2026-11-25
(`gh api repos/DmitriySalnikov/godot_debug_draw_3d/releases`). The notes
since 1.7.0 contain no breaking changes. 1.7.3 only fixes the initial
state of `DebugDrawManager.debug_enabled` (#107). Vendored unmodified from
`debug-draw-3d_1.7.3.zip` into `addons/debug_draw_3d/`.

| # | Check | Result | Note |
|---|---|---|---|
| 1 | Platforms | Pass | The manifest has libraries for Windows x86_64, Linux x86_64 and arm64, macOS universal (as a `.framework`), Android arm32, arm64, x86_32 and x86_64, iOS and Web. All four export targets are covered. |
| 2 | Engine | Pass | `compatibility_minimum = "4.4.1"`, so Godot 4.7.2 is allowed. `task import && task ci` is green with the addon present (36 GdUnit4 tests, 0 failures). Upstream #112 only affects `DebugDraw2D.set_text` in the 4.7 editor. |
| 3 | License | Pass | MIT, copyright 2026 DmitriySalnikov (`addons/debug_draw_3d/LICENSE`). The file has lost its punctuation, which is why GitHub reports NOASSERTION, but the text is the standard MIT grant. Redistribution in builds is allowed. The notice is listed in `assets/CREDITS.md`. |
| 4 | Export smoke test | Pass for host, pending owner for two | See "Export results" below. |
| 5 | Git hygiene | Pass | `.gitattributes` marks `*.dll`, `*.so`, `*.dylib`, `*.framework/**`, `*.aar` and, in addition, `*.wasm` as `binary`. Vendored size is **41 MB** (`du -sh addons/debug_draw_3d`, 30 binaries), which is 82% of the 50 MB Git LFS threshold. Most of it is platforms we do not export (Web, iOS, Android arm32 and x86, Linux arm64). Do not add more native addons without an LFS ADR or trimming those. |
| 6 | Dev-only | Pass | The release libraries are inert. No export filter is needed. See "Release behavior". |
| 7 | Pure-GDScript alternative | Pass | None is equal (see Alternatives). |

#### Release behavior

The `.gdextension` manifest has three library sets:

- **Debug and editor** (`macos`, `windows.x86_64`, `linux.x86_64`, Android
  `template_debug`): the full implementation.
- **`template_release`** ("release no debug draw"): the class and its
  methods still exist, but nothing is drawn.
- **`template_release.forced_dd3d`** (`*.enabled.*` files): a release build
  that draws anyway. We do not use it. Android has no forced set.

Evidence from the macOS probe (a separate throwaway project, outside the
commit):

- The release export loads the extension (`ClassDB.class_exists("DebugDraw3D")`
  is true, `OS.is_debug_build()` is false) and `draw_box` / `draw_line` calls
  draw nothing. The screenshot is blank.
- The debug export of the same scene draws the red box and green line.

Decision: **no `exclude_filter` and no `export_presets.cfg` change.** The
inert release library ships (0.84 to 1.70 MB per platform). First-party code
must still avoid static references to `DebugDraw3D` (ADR-015 check 6), so
T-007 keeps the usage in `vehicle_debug_draw.gd`, gated on
`GameConfig.debug_mode`. Release exports do not draw even if that gate is on.

#### Binary size per platform

| Platform | Debug / editor library | Release library (shipped in release) |
|---|---|---|
| Windows x86_64 | 1.73 MB | 1.15 MB |
| Linux x86_64 | 2.75 MB | 0.91 MB |
| macOS universal | 2.89 MB | 1.70 MB |
| Android arm64 | 1.16 MB | 0.84 MB |

#### Supply chain

- **Checksum:** the downloaded `debug-draw-3d_1.7.3.zip` has SHA-256
  `e16c7e1bd7f4c30d8e503ce424caef5b9e2fd5f44094cf00be66c334aff54c70`. It
  matches the `digest` that GitHub shows for the release asset.
- **CI-built:** the tag `1.7.3` points at commit `c6d9112`. The upstream
  `GDExtension Build` workflow ran on that exact commit and succeeded
  (2026-04-04). A `VirusTotal Release Scan` workflow ran on the release.
  The binaries are CI-built, not committed by hand. We did not rebuild them
  from source.
- **Maintenance:** last push 2026-04-04. Six releases between 2025-11 and
  2026-04. 16 open issues, mostly feature requests. One upstream CI PR build
  failed on 2026-08-02. Active, but slower since April.

#### Export results (local, macOS host, Godot 4.7.2)

| Preset | Command | Exit | Output |
|---|---|---|---|
| macOS | `task export:macos` | 134 on the first run, 0 on the rerun | `OverTheBrim.zip`. Exit 134 is the known MoltenVK shutdown crash after the output is written. The zip holds `Frameworks/libdd3d.macos.template_release.universal.framework`. `codesign --verify --deep --strict` passes (ad-hoc, universal). |
| Linux | `task export:linux` | 0 | `libdd3d.linux.template_release.x86_64.so` next to the binary and `.pck`. |
| Windows | `task export:windows` | 0 | `libdd3d.windows.template_release.x86_64.dll` next to the `.exe` and `.pck`. |
| Android | `task export:android` | 0 | `lib/arm64-v8a/libdd3d.android.template_debug.arm64.so` and `lib/x86_64/...`. The preset is a debug export, so the debug library ships. |

`release.yml` zips the whole Windows and Linux output folders, so the library
travels with the build.

Host launch (macOS, Apple M1 Pro): exported builds of a probe project
loaded the extension in both debug and release modes (log lines
`PROBE class_exists(DebugDraw3D)=true` and
`PROBE extensions=["res://addons/debug_draw_3d/debug_draw_3d.gdextension"]`,
no extension errors).

**Pending owner:** the Windows or Linux launch on a second machine, and
the Android install on a device. See the assumptions in
[T-006](../tasks/T-006-vendor-debug-draw-3d.md).

#### Physics interpolation (T-022, 2026-11-25)

`draw_text` uses pooled `Label3D` nodes under the addon's
`_DD3D_WorldWatcher` node. With project physics interpolation on (T-020),
they inherited it and blended from stale positions: 300 px RMS shake and
pops in turns. `VehicleDebugDraw` turns interpolation off for nodes whose
name contains `_DD3D_`. The addon's arrows render through
`RenderingServer` and were not affected. **On any Debug Draw 3D update,
re-check the node name and re-run the T-022 probe.**
