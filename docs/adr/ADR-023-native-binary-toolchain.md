# ADR-023: Native-Binary Dev Toolchain (gdscript-formatter, prek)

**Status:** Accepted

**Date:** 2026-11-24

---

### Context

On 2026-11-24 the local toolchain broke. `gdformat`, `gdlint` and
`pre-commit` were Python tools installed with pip against mise's Python
3.14.7. When mise upgraded Python and removed 3.14.7, their shims pointed
at an interpreter that no longer existed, and the git hook could not run.

A same-day audit of every tool (AGENTS.md "Dependency & Tooling Versions")
found:

- **gdtoolkit 4.5.0** was released 2025-10-09, 13+ months ago. It has open
  bugs on Godot 4.5+ syntax:
  - [#424](https://github.com/Scony/godot-gdscript-toolkit/issues/424):
    `gdformat` writes closer indentation that Godot rejects after
    multiline lambda bodies, so a formatter run on commit can break code.
  - #419 and #430: `@abstract` handling.
  - #425: the lint AST misses `static func`.
- **GDQuest GDScript Formatter 0.28.0**
  ([GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter),
  MIT, about 500 stars, released 2026-10-30):
  - a Rust single binary for Linux, macOS and Windows on x86_64 and arm64
  - formatting plus a linter for the official style guide
  - `--check` for CI and `--verify-structure`, which rejects output whose
    parse tree changed
  - EditorConfig support and `# fmt: off/on`
- **prek 0.5.11**
  ([j178/prek](https://github.com/j178/prek), released 2026-11-16) is a
  Rust drop-in for pre-commit. It reads the same `.pre-commit-config.yaml`
  and is in the mise registry (`aqua:j178/prek`). Our hooks are local
  `language: system` hooks, which it supports fully.
- **pre-commit 4.7.0** is current but Python-based, so it is exposed to
  the same failure that just happened.

---

### Decision

- Replace `gdformat`/`gdlint` with `gdscript-formatter`:
  - `task fmt`: `gdscript-formatter --verify-structure scripts/ test/`
  - `task fmt:check`: `gdscript-formatter --check scripts/ test/`
  - `task lint`: `gdscript-formatter lint scripts/ test/`

  Use default settings (100 columns, tabs, style-guide rules). Pin it in
  `mise.toml` through the GitHub backend, with `bin = "gdscript-formatter"`
  because the release binary ships with a version suffix.
- Replace `pre-commit` with `prek` (`task setup` runs `prek install`).
  Keep `.pre-commit-config.yaml` unchanged in format. prek's generated
  hook falls back to `prek` on PATH when its pinned binary path is gone,
  so a future upgrade cannot break the hook the way today's Python
  removal did.
- Drop `uv` and all `pypi:` tools from `mise.toml`. The toolchain is
  native binaries only: Godot, Task, gdscript-formatter and prek.
- The one-time reformat touched 4 files with layout-only changes, checked
  by `--verify-structure`. The linter reported no findings on the current
  code.

---

### Consequences

**Positive:**
- No interpreter dependency, so a mise Python upgrade cannot break
  formatting, linting or hooks again.
- The formatter is maintained and tracks current GDScript syntax. One tool
  covers both format and lint.
- Faster hooks: Rust binaries start in milliseconds.

**Negative / Tradeoffs:**
- Both tools are 0.x, so expect breaking changes between minor versions.
  Read the release notes on every bump.
- gdscript-formatter's style differs from gdformat in places (for example
  `{ }` for an empty dictionary, and one argument per line once a call
  wraps). Accepted: the formatter defines the style.
- gdscript-formatter has no mise registry shortname. It uses the generic
  `github:` backend, which needs the `bin` rename option.

---

### Alternatives Considered

1. **Keep gdtoolkit + pre-commit:** Rejected. The tools are stale (known
   breakage on lambdas and `@abstract`), and the Python dependency is the
   proven failure mode.
2. **Run both formatters in CI for a while before switching:** Rejected
   by the owner in favor of switching now. The reformat diff was small.
3. **Drop local hooks and rely on CI only:** Rejected. Format and lint
   issues would surface only after a push.
