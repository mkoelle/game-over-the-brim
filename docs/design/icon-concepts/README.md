# App Icon Concepts

Eight concepts for replacing `icon.svg`, from safe to more creative. The
owner asked for them at FC-1 ("this one is meh, create 8 samples with
differing options, getting increasingly creative").

`contact-sheet.png` shows each concept at 256 px, with 48, 32 and 16 px
previews underneath. An app icon has to work at taskbar size, so judge
the small versions too.

The palette is the same throughout:
- night plum `#2b1f3a`
- velvet red `#c8323c`
- gold `#f2b632`
- cream `#f6efe2`
- teal `#2fb3a5`
- ink `#1b1622`

All files are 128 x 128 SVG, using only shapes and one gradient, so
Godot's SVG importer handles them.

| # | File | Idea | Small-size read |
|---|---|---|---|
| 1 | `01-classic-topper.svg` | The current idea, cleaned up: a front-on red top hat with eyes, a gold band and two wheels, on a rounded plum tile. | Strong |
| 2 | `02-full-throttle.svg` | The topper leans into speed, with angry brows, a checkered band and motion lines, on a teal disc. | Good |
| 3 | `03-checkered-badge.svg` | A racing roundel: a checkered ring around a red disc holding a black top-hat-car silhouette. | Strongest at 16 px |
| 4 | `04-hat-pack.svg` | Bowler, top hat and fez side by side on a road: couch multiplayer at a glance. | Busy below 32 px |
| 5 | `05-wheelie-wink.svg` | The topper pops a wheelie and winks, on an orange sunburst, with a sparkle. | Good |
| 6 | `06-over-the-brim.svg` | The title as a picture: tiny hat-cars spill out of an upturned top hat, with confetti. | Busy below 32 px |
| 7 | `07-brim-speedway.svg` | Top-down: the brim is the race track, the crown is a smiling infield, and four cars race on the brim. | Good, reads as a face |
| 8 | `08-moonshot.svg` | A fez-car launches off a ramp curved like a hat brim, across the moon, its steam trail looping behind. | Fair |

This folder has a `.gdignore`, so Godot neither imports nor exports these
drafts. To adopt one:
1. Copy it over `icon.svg`.
2. Re-render the `.ico`, `.icns` and Android launcher icons, following
   ADR-007.
3. Delete this folder.
