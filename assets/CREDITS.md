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
| `assets/art/tracks/kenney_racing_kit/barrierWall.gltf`, `barrierWall.bin` (from `Models/glTF format/`; Racing Kit 1.2) | <https://kenney.nl/assets/racing-kit> (zip from <https://opengameart.org/content/racing-kit>, uploaded by Kenney 2017-04-18) | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |
| `assets/art/tracks/kenney_racing_kit/barrierRed.gltf`, `barrierRed.bin` (Racing Kit 1.2) | same as above | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |
| `assets/art/tracks/kenney_racing_kit/pylon.gltf`, `pylon.bin` (Racing Kit 1.2) | same as above | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |
| `assets/art/tracks/kenney_racing_kit/roadRampLong.gltf`, `roadRampLong.bin` (Racing Kit 1.2) | same as above | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |
| `assets/art/tracks/kenney_racing_kit/License.txt` (the pack's own license file, Racing Kit 1.2) | same as above | Kenney (kenney.nl) | CC0-1.0 | 2026-11-25 | yes |

The Racing Kit models are unmodified Kenney files. Our wrapper scenes
(`barrier_wall.tscn`, `barrier_red.tscn`, `pylon.tscn`, `road_ramp_long.tscn`)
are in-house and add only collision. The import scale (`nodes/root_scale=8.0`
in each `.gltf.import`) is a project setting, not an edit of the model.

## Third-party code (vendored addons)

| Path(s) | Source URL | Author | License (SPDX) | Date added | Placeholder |
| --- | --- | --- | --- | --- | --- |
| `addons/gdUnit4/` (v6.2.3 since T-009, includes its bundled `.png` icons and logos) | <https://github.com/godot-gdunit-labs/gdUnit4> | Mike Schulze | MIT | 2026-09-09 | no |
| `addons/phantom_camera/` (v0.12, T-004; includes its bundled `.svg`/`.png` icons, fonts and example textures) | <https://github.com/ramokz/phantom-camera> | Marcus Skov | MIT | 2026-11-25 | no |
| `addons/debug_draw_3d/` (v1.7.3, T-006; native GDExtension binaries for Windows, Linux, macOS, Android, iOS and Web, plus `native_api/` headers; dev-only, see ADR-016) | <https://github.com/DmitriySalnikov/godot_debug_draw_3d> | DmitriySalnikov | MIT | 2026-11-25 | no |

The license text is in `addons/gdUnit4/LICENSE` (and `addons/phantom_camera/LICENSE` for Phantom Camera, copyright 2022 Marcus Skov, same MIT terms; `addons/debug_draw_3d/LICENSE` for Debug Draw 3D, copyright 2026 DmitriySalnikov, MIT). It requires the copyright
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

- **Nunito fonts inside Phantom Camera.** `addons/phantom_camera/fonts/`
  ships Nunito `.ttf` files with no font license file. Nunito is published
  under OFL-1.1 upstream (Google Fonts), but the addon's `LICENSE` is MIT
  only and does not mention it. Unverified. The fonts are used by the editor
  panel only. Decide whether to exclude `addons/phantom_camera/fonts/` and
  the other editor-only folders from exports (T-015).
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
