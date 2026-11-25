# T-010: Asset Credits Manifest and Licensing Standard

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Done
**Estimate:** 1h
**Phase:** 2 — Assets ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md)

### Goal

Create the single source of truth for third-party asset licenses, and
document the import rules. Do this before any free asset enters the repo.

### Acceptance Criteria

- [x] `assets/CREDITS.md` exists with columns: path(s), source URL,
      author, license (SPDX), date added, placeholder (yes/no).
- [x] Every existing file under `assets/` is either listed or marked
      "original (in-house)".
- [x] The provenance of `assets/art/tracks/dev_grid.png` is resolved. If
      the source is unknown, replace it with an equivalent from Kenney
      Prototype Textures (CC0) and list that.
- [x] `docs/standards/asset-organization.md` gains a "Third-party assets"
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

### Assumptions (owner to validate)

- **Assumption:** `dev_grid.png` has no recoverable source, so it was
  replaced by Kenney Prototype Textures `PNG/Light/texture_07.png` (CC0).
  The path is unchanged, so `test_track.tscn` still works. The new
  checkerboard is lower contrast than the old one.
  **Evidence:** `git log --follow` shows only commit `ed5e899` (no source
  in the message or the repo). The Kenney zip's `License.txt` says
  "License: (Creative Commons Zero, CC0)" and "free to use in personal,
  educational and commercial projects". The zip came from
  <https://opengameart.org/content/prototype-textures> ("All CC0 -
  Uploader: Kenney"), because kenney.nl's own download link needs a
  browser session.
  **Owner check:** run the test track and confirm the ground still reads
  well. Say if you want a higher-contrast texture (`Dark/texture_07.png`).
- **Assumption:** the in-house icon set (`icon.svg` and the `.ico`,
  `.icns` and Android PNGs rendered from it) is original work.
  **Evidence:** `icon.svg` is hand-written SVG shapes, and ADR-007 records
  the other files as rendered from it with Godot and Pillow. No commit
  names an outside author.
  **Owner check:** confirm you or the project made `icon.svg`.
- **Assumption:** listing gdUnit4 in the credits screen satisfies its MIT
  license.
  **Evidence:** `addons/gdUnit4/LICENSE` says "The above copyright notice
  and this permission notice shall be included in all copies or substantial
  portions of the Software." The credits screen can show that notice.
  Shipping `addons/gdUnit4/LICENSE` in the build also satisfies it.
  **Owner check:** when T-015 lands, confirm the credits screen shows the
  gdUnit4 and Godot MIT notices. Also decide whether to exclude the addon
  from exports (`exclude_filter` is empty today).
- **Assumption:** Godot Engine (MIT, includes Jolt) needs only its notice
  and third-party license text in the credits.
  **Evidence:** <https://godotengine.org/license/> and the Godot docs
  page "Complying with licenses". I did not re-read the full third-party
  list in this ticket.
  **Owner check:** at release, add Godot's copyright text and
  third-party license list to the credits screen.
- **Assumption:** CC0 needs no attribution, but we still list Kenney.
  **Evidence:** `License.txt`: "Support us by crediting Kenney or
  www.kenney.nl (this is not mandatory)".
  **Owner check:** none needed. Remove the credit if you prefer.
