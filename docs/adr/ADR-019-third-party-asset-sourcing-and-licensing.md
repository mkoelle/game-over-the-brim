# ADR-019: Third-Party Asset Sourcing and License Tracking

**Status:** Accepted

**Date:** 2026-11-24

---

### Context

Greybox tracks, placeholder sound effects, fonts and shaders can come from
free sources instead of being made in-house. This keeps effort on handling
feel and spectator chaos. Mixed licenses (CC0, CC-BY, OFL, per-shader
licenses) become a release blocker if nobody records where each file came
from. The existing `assets/art/tracks/dev_grid.png` has no recorded source
today.

---

### Decision

**Approved sources** (default license in brackets — always confirm on the
specific item):

- **Kenney** (kenney.nl) [CC0]: Racing Kit, Car Kit, Prototype Textures,
  Particle Pack, Impact Sounds, Interface Sounds. Use for greybox and
  placeholders.
- **Quaternius** [CC0]: low-poly city and props.
- **Poly Haven** [CC0]: sky images (HDRIs) and textures.
- **Freesound** [per item; filter to CC0, accept CC-BY with attribution].
- **jsfxr / ChipTone** [generated sounds; owned by us].
- **Google Fonts** [SIL OFL 1.1; ship the license text with the font].
- **godotshaders.com** [**per shader**; accept CC0 or MIT only, record each].

**Rules:**

1. Every third-party file is listed in `assets/CREDITS.md` with:
   - path(s) in the repo
   - source URL
   - author
   - license (SPDX ID where one exists)
   - date added
2. **Allowed licenses:** CC0-1.0, CC-BY-4.0 (attribution required in the
   credits screen), OFL-1.1, MIT. **Not allowed:** CC-BY-NC (any
   non-commercial clause), CC-BY-SA (share-alike) for code or shaders, and
   "free for personal use".
3. Imported packs go in a subfolder named for the source, under the
   matching `assets/` category. Example:
   `assets/art/tracks/kenney_racing_kit/`. Rename files to snake_case only
   when we use them directly. Keep original names inside the pack folder
   so we can trace and update them.
4. Import only the files we use, not entire packs.
5. Maaack's credits scene ([ADR-018](ADR-018-menu-framework-maaack-menus-template.md))
   is driven from `assets/CREDITS.md`.
6. Placeholder assets are marked `placeholder: yes` in CREDITS so they are
   easy to find before release.

Tickets: [T-010](../tasks/T-010-asset-credits-manifest.md) (manifest +
standard) and [T-011](../tasks/T-011-kenney-greybox-kit.md) (first import).

---

### Consequences

**Positive:**
- License audit before release is reading one file.
- Greybox and placeholder content is available immediately and free.

**Negative / Tradeoffs:**
- Small per-import bookkeeping cost.
- CC-BY items create an attribution obligation in the credits screen.

---

### Alternatives Considered

1. **Track licenses ad hoc in commit messages:** Rejected. It cannot be
   audited at release.
2. **CC0-only policy:** Rejected as too strict. Fonts (OFL) and some good
   Freesound items (CC-BY) are worth the attribution cost.
