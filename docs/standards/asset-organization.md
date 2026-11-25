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

Details to be expanded as the asset pipeline matures.
