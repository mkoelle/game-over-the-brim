# T-010: Asset Credits Manifest and Licensing Standard

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Estimate:** 1h
**Phase:** 2 — Assets ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md)

### Goal

Create the single source of truth for third-party asset licenses, and
document the import rules. Do this before any free asset enters the repo.

### Acceptance Criteria

- [ ] `assets/CREDITS.md` exists with columns: path(s), source URL,
      author, license (SPDX), date added, placeholder (yes/no).
- [ ] Every existing file under `assets/` is either listed or marked
      "original (in-house)".
- [ ] The provenance of `assets/art/tracks/dev_grid.png` is resolved. If
      the source is unknown, replace it with an equivalent from Kenney
      Prototype Textures (CC0) and list that.
- [ ] `docs/standards/asset-organization.md` gains a "Third-party assets"
      section summarizing the ADR-019 rules:
  - allowed and forbidden licenses
  - pack subfolder naming (`kenney_racing_kit/`)
  - import only what is used
  - list every file in CREDITS

### Context

- ADR-019 allowed licenses: CC0-1.0, CC-BY-4.0 (with attribution), OFL-1.1
  and MIT. Forbidden: any NC (non-commercial), SA (share-alike) for code
  or shaders, and personal-use-only.
- The Maaack credits scene (T-015) will read this file later, so keep it
  plain Markdown tables.

### Files Likely Affected

- `assets/CREDITS.md` (new)
- `docs/standards/asset-organization.md`

### Implementation Plan

1. Branch `chore/asset-credits`.
2. List the files: `git ls-files assets | grep -v '\.import$'`.
3. For each file, check `git log --follow --format='%h %s' -- <file>` for
   its origin. The icon set was generated from `icon.svg` (in-house).
4. `dev_grid.png`: if the commit history does not show its source,
   replace it with a Kenney Prototype Textures grid (CC0). Keep the same
   path so `test_track.tscn` references stay valid, and list it.
5. Write `assets/CREDITS.md` with a header that links to ADR-019.
6. Add the "Third-party assets" section to `asset-organization.md`.

### Verification

Every path from `git ls-files assets | grep -v '\.import$' | grep -v .gitkeep`
appears in `assets/CREDITS.md`.

### Dependencies

None.
