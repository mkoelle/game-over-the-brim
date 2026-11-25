# GDScript Style Guide

Follow Godot official style conventions with project-specific additions.

See AGENTS.md for naming conventions and coding rules.

## Enforcement

Formatting and lint rules are enforced by
[GDScript Formatter](https://github.com/GDQuest/GDScript-formatter)
(`gdscript-formatter` and `gdscript-formatter lint`), with the default
config: 100-character lines, tabs, and the official GDScript style guide
rules. The scope is `scripts/` and `test/`. `addons/` is vendored and is
never reformatted. To keep a hand-aligned block as written, wrap it in
`# fmt: off` / `# fmt: on`. See ADR-023 for why this replaced gdtoolkit.

```bash
task fmt         # reformat in place
task fmt:check   # check only, no writes (what CI runs)
task lint        # gdscript-formatter lint
```

CI (`.github/workflows/ci.yml`) fails on either check. The formatter is
pinned in `mise.toml` like the rest of the toolchain. Bootstrap once with
`mise trust && mise install`, then run `task setup`. That registers a git
pre-commit hook (run by prek) that runs `task fmt` + `task lint` on every
commit. That catches issues before they are
committed, not only before CI runs. CI installs the same pinned versions
with `jdx/mise-action` and never registers the hook.

Details to be expanded as patterns emerge during development.
