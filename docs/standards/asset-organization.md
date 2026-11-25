# Asset Organization

## Directory Structure

```text
assets/
├── art/
│   ├── vehicles/
│   ├── tracks/
│   ├── ui/
│   └── effects/
├── audio/
│   ├── music/
│   ├── sfx/
│   └── ui/
├── fonts/
└── themes/
```

## Naming Rules

- All asset files use snake_case
- Prefix textures with purpose: ui_button_normal.png, vfx_spark_01.png
- Group related assets in subdirectories

## Import Settings

- **Commit `.import` and `.uid` files.** They hold import settings and
  resource UIDs. Without them, every clone regenerates UIDs and scene
  references break ("invalid UID" warnings). Ignore only `.godot/`.
  See the Godot docs on version control and the 4.4 UID changes.
- Document custom import presets in this file as they are created
- **Kenney Racing Kit models** (`assets/art/tracks/kenney_racing_kit/`): set
  `nodes/root_scale=8.0` in each `.gltf.import`. The kit is about 1/8 of our
  scale (a barrier is 0.13 high in the file, 1.05 m in game). Import scale is
  the only scaling. Never scale nodes in scenes (Jolt, T-001). The kit's
  glTF files keep each mesh at an offset from the origin, so each wrapper
  scene shifts its `Model` node to centre the footprint. Collision is a
  hand-sized box or convex shape in the wrapper scene.

Details to be expanded as the asset pipeline matures.

## Third-party assets

Rules come from [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md).
The manifest is [`assets/CREDITS.md`](../../assets/CREDITS.md).

- **Allowed licenses:** CC0-1.0, CC-BY-4.0 (attribution goes in the credits
  screen), OFL-1.1 and MIT.
- **Forbidden licenses:** any non-commercial (NC) license, share-alike (SA)
  for code or shaders, and "free for personal use".
- **Check the license on the item itself.** Do not trust the source's
  default. Read the license file in the download or on the item page.
- **Pack folders:** put an imported pack in a subfolder named for the source
  and pack, under the matching category. Example:
  `assets/art/tracks/kenney_racing_kit/`. Keep the original file names
  inside the pack folder. Rename to snake_case only when we use a file
  directly.
- **Import only what is used.** Do not commit whole packs.
- **List every file in `assets/CREDITS.md`.** Each row has path(s), source
  URL, author, SPDX license, date added and a placeholder flag. Add the row
  in the same PR as the import.
- **Mark placeholders** with `placeholder: yes` so they are easy to find
  before release.
- **In-house files** are listed as "original (in-house)".
