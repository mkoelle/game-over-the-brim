# Asset Credits

This file is the single source of truth for third-party licenses.
Rules are in [ADR-019](../docs/adr/ADR-019-third-party-asset-sourcing-and-licensing.md)
and [asset-organization](../docs/standards/asset-organization.md).
The credits screen reads this file, so keep it plain Markdown tables.

Allowed licenses: CC0-1.0, CC-BY-4.0, OFL-1.1, MIT.
Not allowed: any NC license, SA for code or shaders, "free for personal use".

A row with `placeholder: yes` must be replaced or confirmed before release.

## Third-party assets

| Path(s) | Source URL | Author | License (SPDX) | Date added | Placeholder |
| --- | --- | --- | --- | --- | --- |
| `assets/art/tracks/dev_grid.png` (copy of `PNG/Light/texture_07.png`, 1024x1024) | <https://kenney.nl/assets/prototype-textures> (zip mirrored at <https://opengameart.org/content/prototype-textures>) | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |

## Third-party code (vendored addons)

| Path(s) | Source URL | Author | License (SPDX) | Date added | Placeholder |
| --- | --- | --- | --- | --- | --- |
| `addons/gdUnit4/` (v6.2.1, includes its bundled `.png` icons and logos) | <https://github.com/MikeSchulze/gdUnit4> | Mike Schulze | MIT | 2026-09-09 | no |

The license text is in `addons/gdUnit4/LICENSE`. It requires the copyright
notice to ship "in all copies or substantial portions". The addon is not
excluded from exports today (`exclude_filter` is empty), so the credits
screen must show this notice. See the open items below.

## Engine

| Path(s) | Source URL | Author | License (SPDX) | Date added | Placeholder |
| --- | --- | --- | --- | --- | --- |
| Godot Engine 4.7.2 (runtime in every export, includes Jolt Physics per ADR-021) | <https://godotengine.org/license/> | Godot Engine contributors | MIT | 2026-09-09 | no |

## Original (in-house)

These files are made by the project. No third-party license applies.

| Path(s) | Source URL | Author | License (SPDX) | Date added | Placeholder |
| --- | --- | --- | --- | --- | --- |
| `icon.svg`, `icon.svg.import` | n/a | in-house | original (in-house) | 2026-09-09 | yes |
| `assets/art/ui/icon.ico` | n/a (rendered from `icon.svg`) | in-house | original (in-house) | 2026-09-10 | yes |
| `assets/art/ui/icon.icns` | n/a (rendered from `icon.svg`) | in-house | original (in-house) | 2026-09-10 | yes |
| `assets/art/ui/android/main_192x192.png` | n/a (rendered from `icon.svg`) | in-house | original (in-house) | 2026-09-10 | yes |
| `assets/art/ui/android/adaptive_foreground_432x432.png` | n/a (rendered from `icon.svg`) | in-house | original (in-house) | 2026-09-10 | yes |
| `assets/art/ui/android/adaptive_background_432x432.png` | n/a (rendered from `icon.svg`) | in-house | original (in-house) | 2026-09-10 | yes |

The icon set is a stand-in until final key art exists, so it is marked as a placeholder.
Files named `.gitkeep` and Godot `.import` files are not assets and are not listed.

## Open items

- **Replaced `dev_grid.png`.** The previous file was added in commit
  `ed5e899` with no recorded source. It was replaced on 2026-11-25 by the
  Kenney CC0 texture above. The old file is still in git history, so its
  origin remains unknown.
- **Confirm the icon artwork is original.** `icon.svg` was added in
  `d48e2a6` (ADR-007 calls it "the icon") with no recorded author. Its shapes are a hand-drawn
  vector and not Godot's default logo, but no commit message states who made it.
  The owner should confirm it is theirs.
- **Notice for gdUnit4 and Godot (MIT).** Decide whether to exclude
  `addons/gdUnit4/` from exports, and where the Godot and gdUnit4 notices
  appear in the credits screen (T-015).
