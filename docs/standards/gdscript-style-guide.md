# GDScript Style Guide

Follow Godot official style conventions with project-specific additions.

See AGENTS.md for naming conventions and coding rules.

## Enforcement

Formatting and lint rules are enforced by [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)
(`gdformat` + `gdlint`), default config (100-char lines, Godot's official
class-member ordering). Scoped to `scripts/` and `test/` — `addons/` is
vendored, not reformatted.

```bash
task fmt         # reformat in place
task fmt:check   # check only, no writes (what CI runs)
task lint        # gdlint
```

CI (`.github/workflows/ci.yml`) fails on either check. `gdformat`/`gdlint`
come from `mise.toml` (pinned gdtoolkit version), like the rest of the
toolchain. Bootstrap once with `mise trust && mise install`, then run
`task setup` to register a pre-commit hook that runs `task fmt` +
`task lint` on every commit. That catches issues before they are
committed, not only before CI runs. CI installs the same pinned versions
with `jdx/mise-action` and never registers the hook.

Details to be expanded as patterns emerge during development.
