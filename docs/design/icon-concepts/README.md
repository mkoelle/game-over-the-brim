# App Icon Concepts

At FC-1 the owner asked for eight concepts, then kept two (T-025, T-026):

| # | File | Idea | Status |
|---|---|---|---|
| 2 | `02-full-throttle.svg` | The topper leans into speed, with angry brows, a checkered band and motion lines, on a teal disc. | **In use** as `icon.svg` ("for now") |
| 4 | `04-hat-pack.svg` | Bowler, top hat and fez side by side on a road: couch multiplayer at a glance. | Kept as an option (busy below 32 px) |

`contact-sheet.png` shows both at 256, 48, 32 and 16 px.

Concepts 1, 3, 5, 6, 7 and 8 were dropped, and git history still has
them (T-025, PR #28).

This folder has a `.gdignore`, so Godot neither imports nor exports it.
To switch icons:
1. Copy the SVG over `icon.svg`.
2. Mark its background shape with `id="background"`.
3. Run `task icons`.
