# ADR-015: Native (GDExtension) Addon Policy

**Status:** Accepted

**Date:** 2026-11-24

---

### Context

ADR-002 makes the project GDScript-only. Several addons already accepted or
recommended ship compiled native code as a GDExtension (`.dll` / `.so` /
`.dylib` / `.framework` plus a `.gdextension` manifest):

| Addon | ADR | Native? |
|---|---|---|
| LimboAI | [ADR-011](ADR-011-ai-state-machine-addon-limboai.md) | GDExtension build (or a custom engine module) |
| Debug Draw 3D | [ADR-016](ADR-016-debug-visualization-addon-debug-draw-3d.md) | GDExtension |
| GodotSteam | [ADR-020](ADR-020-steam-remote-play-together-online-path.md) (Proposed) | GDExtension |
| FMOD for Godot | none (candidate only) | GDExtension |

Native addons carry risks that pure-GDScript addons do not:

- They break on platforms the author does not build for. We export four:
  Windows, Linux, macOS and Android (ADR-007).
- They can break on an engine minor bump.
- They need code-signing inside the macOS bundle. The release workflow
  ad-hoc signs, per commit `59cb630`.
- They add binary weight to git.

There is no written rule yet for when this is acceptable.

---

### Decision

ADR-002 ("GDScript only") governs **first-party code**. A vendored addon
may ship native GDExtension binaries only if **all** of the following
checks pass. Record the result in the addon's ADR:

1. **Platforms:** the pinned release ships prebuilt binaries for every
   export target in `export_presets.cfg`: Windows x86_64, Linux x86_64,
   macOS (universal or arm64+x86_64) and Android arm64. An addon that is
   dev-only (check 6) may skip platforms it is excluded from.
2. **Engine:** works on the pinned Godot version (`Taskfile.yml`
   `GODOT_VERSION`, currently 4.7.2), and `task ci` is green with it
   enabled.
3. **License:** permits redistributing the binaries inside shipped game
   builds (MIT, BSD, zlib or Apache-2.0). For a proprietary SDK underneath
   (Steamworks, FMOD), record the SDK's own terms separately.
4. **Export smoke test:** `task export` succeeds for all four platforms.
   The desktop builds launch to the test track, and the macOS build
   launches after ad-hoc signing.
5. **Git hygiene:** add the binary extensions (`*.dll`, `*.so`, `*.dylib`,
   `*.framework/**`, `*.aar`) to `.gitattributes` as `binary`. Record the
   vendored size in the ADR. If the total vendored binary size passes
   50 MB, open an ADR on Git LFS before adding more.
6. **Dev-only addons** (debug tooling) must not be required by release
   builds. First-party gameplay scripts must never reference the addon's
   classes statically. Isolate the usage in a debug-only script that
   release builds exclude, or guard every use with
   `ClassDB.class_exists()`.
7. **Prefer pure GDScript** when a pure-GDScript alternative is roughly
   equal in fit. Example: Beehave as a fallback for LimboAI.

---

### Consequences

**Positive:**
- One reusable gate for every native addon, instead of each addon ADR
  re-deriving it.
- Android and macOS breakage is caught at adoption time, not at release.

**Negative / Tradeoffs:**
- Adoption takes longer (export smoke test on four platforms).
- Some addons will fail check 1 or 2 and need a fallback or a wait.

---

### Alternatives Considered

1. **Ban native addons outright (strict ADR-002 reading):** Rejected. It
   would rule out LimboAI's GDExtension build, Debug Draw 3D and
   GodotSteam, all of which have no equal pure-GDScript alternative.
2. **No policy, judge each addon case by case:** Rejected for the same
   reason ADR-012 exists. A standing checklist avoids re-deriving the same
   reasoning per addon.
