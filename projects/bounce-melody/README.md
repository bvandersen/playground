# Bounce Melody

Place balls in a room and watch them bounce at constant speed, playing a tone on every wall hit — a Godot 4 web demo.

- **Play it:** https://bvandersen.github.io/playground/bounce-melody/
- **Plan, brief and design decisions:** [PLAN.md](PLAN.md) (written before
  this repo's `projects/` layout existed — paths in it have been updated,
  but some historical notes refer to the `oraclecardoftheday.com` repo it
  came from, e.g. `npm run build`, `docs/game.md`, `static/game/`).

## Layout

| Path | What it is |
| --- | --- |
| `godot/` | Godot 4 project source (`project.godot`, `.gd` scripts, `Main.tscn`, `export_presets.cfg`) |
| `web/` | Exported HTML5 build — committed, published as-is |
| `scripts/postexport.mjs` | Patches `web/index.html` after each export |

## Rebuilding `web/`

Godot is not needed to publish — only to change the demo. From `godot/`:

```sh
godot4 --headless --export-release "Web"   # writes ../web/
node ../scripts/postexport.mjs
```

Commit the updated `web/` together with the source change.
