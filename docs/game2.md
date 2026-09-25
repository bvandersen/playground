# game2 — Godot bouncing-tone playground — plan

> **Moved 2026-09-24** from the `oraclecardoftheday.com` repo (where it
> lived at this same path) into this standalone `playground` repo. It
> was always an unlisted demo unrelated to that site's actual product —
> see "Hosting problem: Cloudflare Workers' 25 MiB asset limit" below for
> why it needed a GitHub Pages deploy independent of that site's own
> Cloudflare Workers deploy in the first place; moving it here removes
> that site's build/deploy entirely from the picture rather than just
> working around it. The rest of this file is unchanged from that repo
> and some of its cross-references (`docs/game.md`, `CLAUDE.md`,
> `npm run build`) point at things that only exist over there.

This is a standalone interactive demo, not tied to any site's product —
originally the same "shipped but unlisted" convention as `static/game/`
(see `docs/game.md`) in the repo it moved from, but on a different
engine: everything under `static/game2/` is a **Godot 4 HTML5 export**,
not a hand-written Pixi/WebGL page.

This file exists so a later session (or a later *me*) picking this demo
back up has the original brief, the inspiration, and the decisions made
against it, without re-deriving intent from the code alone — exactly the
role `docs/game.md` plays for `static/game/`.

## Original brief (verbatim)

> Make a new game demo in a new folder game2. Needs it's own plan. Like
> the other game folder it is standalone demo game not related to the
> site so no linking from the site anywhere. Also auto push to main on
> every commit.
>
> Inspiration for the game: [a Reddit video](https://www.reddit.com/r/MemeVideos/s/RMQ41NQ8Eo)
> — link this in the game2 plan or readme for my own future reference.
> Use Godot with HTML export. Later might be turned into an actual game
> (this is just a playground / PoC where we're testing out different
> ideas). So later eg rewritten and published on android store. Keep an
> index like the other game that automatically lists different demos in
> the game2 folder.
>
> Goal for first demo is a scene where the player can switch between
> design and play. They can move stuff around in the design area. Add
> items, remove items, give them properties like momentum in one
> direction. Then set that it reverses on hitting wall and it never loses
> momentum just constant speed. And each time it hits a wall it plays a
> tone. Melodies can be created by adding multiple items at different
> locations so they hit the walls at different times. For first demo an
> item is just a sphere. The player can assign colors to items. Once play
> is pressed they start moving and playing tones on collisions. In the
> designer players can duplicate items as well to quickly setup a nice
> sequence of tones. Also they can define the room size and assign a sine
> wave to the room width and height to make it auto scale over time.
>
> Leave it open to extend later with other item types, adding different
> properties and enabling/disabling properties etc. Every little detail
> on the designer can be configured through a simple and easy UI. Must be
> possible to drag things around without the UI getting in the way on a
> small mobile screen so think of a good way for menus to work. Later we
> want to have a big catalogue of items to add and properties and
> behaviors to apply to items, room etc.

**Inspiration**, for my own future reference:
<https://www.reddit.com/r/MemeVideos/s/RMQ41NQ8Eo> — a bouncing-ball
"melody maker": balls travel at constant speed inside a box, reverse
off each wall, and play a note on every wall hit; the box itself
breathes in size over time, which is what keeps the pattern of hits (and
so the melody) from ever repeating exactly. That "the room's own size is
animated, not just the balls" detail is why room width/height get a sine
wave, not just the items.

## Tech decisions

- **Godot 4.3 (stable), HTML5/Web export.** Ubuntu's own package
  archive only carries Godot 3.5 (`apt-cache search godot` → `godot3`);
  Godot 4 isn't packaged for this distro, so the 4.3 stable Linux editor
  and Web export templates were downloaded straight from the
  `godotengine/godot` GitHub release (`releases/download/4.3-stable/…`,
  which resolves through `release-assets.githubusercontent.com` and
  isn't blocked by this sandbox's egress policy — `downloads.tuxfamily.org`,
  Godot's own CDN, is). Godot 4 over 3: current, actively developed,
  materially better Web/WASM export, and a real Android export path for
  "later... rewritten and published on android store" — no reason to
  build on the older engine when the eventual target is 4's.
- **2D, not 3D, even though items are called "spheres."** A sphere
  bouncing in a box, viewed from the one angle that makes wall-hit timing
  legible, is a circle in a rectangle — real 3D would mean a camera, a
  light, and a physically-modeled ball for zero gameplay benefit over a
  `Node2D` that draws a circle. It also keeps the WASM export small and
  the physics trivial (see below), both of which matter more here than
  in a "real" game: mobile load time and battery are real constraints for
  a PoC that's meant to run in a phone browser. Nothing about the item/
  property/behavior architecture below is 2D-specific — a real 3D sphere
  item type is one new entry in the item catalog whenever that's worth
  doing, not a rewrite.
- **Constant-speed reflection, not `RigidBody2D` physics.** The brief is
  explicit: never loses momentum, just constant speed, reverses exactly
  on hitting a wall. A physics-engine rigid body (mass, restitution,
  damping, solver tolerance) is the wrong tool for "reflect this vector
  exactly, forever" — it's built to *approximate* elastic collision, not
  guarantee it. Every item is a plain kinematic mover: `position +=
  velocity * delta` in `_physics_process`, and a wall hit negates exactly
  one axis of `velocity`. Speed (the vector's magnitude) is mathematically
  invariant under that operation — it never drifts, by construction, not
  by tuning.
- **Procedurally-built scene tree, not hand-authored `.tscn` files.**
  There's no interactive Godot editor in this environment (or, most of
  the time, whoever's driving this next) — scenes are being read and
  written as text. Godot's `.tscn` format is a hand-editable text format
  in principle, but a typo in a `[node]`/`[connection]` block fails
  silently or fails at load with a stack trace pointing at the resource
  loader, not at the mistake. This project keeps exactly one `.tscn`
  (`Main.tscn`, a bare `Node2D` with `main.gd` attached — the minimum
  Godot's "Main Scene" project setting requires) and builds the entire
  runtime tree — room, items, UI — from GDScript in `_ready()`. This is
  also just a better fit for a scene whose whole point is nodes being
  added, duplicated, and removed at runtime by the player: the "designer"
  *is* runtime scene mutation, so building the initial state the same way
  the player's own actions build on it is one code path, not two.

## Why the Godot export is never part of `npm run build`

`CLAUDE.md`'s standing rule for this repo is that **the daily scheduled
deploy must always run** — a stale card is a broken build, not a
cosmetic issue. Godot is not installed in this repo's normal dev
environment or its Cloudflare/GitHub Actions deploy pipeline, and it
never should be made a hard dependency of either: a ~50MB editor binary
plus gigabyte-scale export templates has no business being a prerequisite
for shipping today's oracle card.

So the split is:

- **`game2/<demo>/`** (repo root, alongside `src/`, `static/`,
  `scripts/`) — the Godot project **source**: `project.godot`, `.gd`
  scripts, the one `.tscn`, `export_presets.cfg`. This is never served —
  it's not under `static/` at all. `.godot/` (Godot 4's per-project
  import/cache directory, regenerated from source on demand, the same
  role `node_modules/` plays) is gitignored.
- **`static/game2/<demo>/`** — the exported HTML5 **build output**
  (`index.html`, `.wasm`, `.pck`, `.js`, an icon) for that demo,
  committed to git like any other file under `static/game/` — it has to
  be, since nothing in the site's own build pipeline can regenerate it.
  Re-exporting after a source change is a manual (or separately-scripted)
  step, documented per-demo below, not something `npm run build` ever
  attempts.
- **`static/game2/index.html`** — generated, gitignored, rebuilt by
  `scripts/game2-index.mjs` before both `npm run dev` and `npm run build`
  (its own `predev`/`prebuild` entry, alongside `scripts/game-index.mjs`'s
  existing one) — this part *is* safe to wire into the site's build,
  because it's a pure directory scan over already-committed static files,
  with zero Godot dependency. It lists every subfolder of
  `static/game2/` that has its own `index.html`, reading each one's
  `<title>` the same way `scripts/game-index.mjs` already does for
  `static/game/*.html` — adding a new exported demo needs nothing else
  done for it to appear there, same guarantee as the other game folder.
- Every exported demo's HTML shell carries the same
  `<meta name="robots" content="noindex, nofollow">` and an
  "(unlisted demo)"-suffixed `<title>` as every file under `static/game/`
  already does (see `docs/game.md`) — Godot's default Web export shell
  doesn't have either, so each demo ships a small custom HTML shell
  (`game2/shared/shell.html`) instead of Godot's built-in one, specifically
  to carry these two tags plus a dark background matching the rest of
  this site's unlisted-demo pages.

## Extensibility architecture — the actual point of this PoC

The brief's last paragraph is the real spec: *"leave it open to extend
later with other item types, adding different properties and
enabling/disabling properties... a big catalogue of items... properties
and behaviors."* Demo 1 only needs one item type and two behaviors, but
the architecture has to already be the shape a catalogue grows into, or
every later item type becomes a special case bolted onto this one — the
same standing rule `docs/game.md` set for `procedural-shuffle-
playground.html`, restated for this engine:

- **`ItemData`** (`game2/bounce-melody/scripts/item_data.gd`) — plain
  data, no drawing, no physics: `type`, `position`, `velocity`, `color`,
  `radius`, `note` (a frequency in Hz), and a free-form `properties`
  dictionary for whatever a future property needs that today's fields
  don't cover. Mirrors `CardPhysicsState` from the other game folder's
  own plan — data a behavior reads and writes, never a node itself.
- **`Item`** (`item.gd`, a `Node2D`) — the view half: owns one
  `ItemData` and draws it (`_draw()`, a filled circle in `data.color`
  sized by `data.radius`). Mirrors `CardView`'s split from
  `CardPhysicsState` in the other plan — nothing about *how an item
  looks* is coupled to *what an item does*.
- **`Behavior`** (`behaviors/behavior.gd`, a base class with two virtual
  hooks: `physics_step(item, delta, room)` and `on_wall_hit(item, axis)`)
  — the extension point both the item catalogue and the "enable/disable
  a property" requirement grow through. An item holds an `Array` of
  behavior instances; the room ticks every item's behaviors every frame
  and calls `on_wall_hit` exactly when that item's movement crosses a
  wall on a given axis. Demo 1 ships two: `ConstantSpeedBounceBehavior`
  (the reflect-off-walls movement itself) and `ToneOnWallHitBehavior`
  (plays `item.data.note` through the shared tone player). A future
  property that can be turned on or off per item — "make this one heavier
  near walls," "make this one leave a trail," whatever the catalogue
  eventually wants — is one more `Behavior` subclass and one more entry
  in that item's `behaviors` array, never a new `if` in `Item` or `Room`.
- **`ITEM_CATALOG`** (`item_catalog.gd`, an autoload singleton — a plain
  `Dictionary` constant keyed by type name) — the one place a new item
  *type* gets registered: default radius, default color, default
  behavior list, and a short display name for the "add item" menu. Demo
  1 registers exactly one entry, `"sphere"`. Adding a second shape later
  is one dictionary entry, not a rewrite of the add-item UI, which only
  ever reads this table.
- **`RoomBehavior`** — same pattern, one level up: the sine-wave
  width/height oscillator is a `RoomBehavior` the `Room` ticks every
  frame in Play mode, not code wired directly into `Room`'s own resize
  logic. A second room-level effect later (pulsing background, gravity)
  is another `RoomBehavior`, not a special case in `Room`.

## Design-mode UI, built for a small phone screen first

The brief calls this out explicitly: dragging an item must never fight
the UI for the same screen space. The layout:

- **The whole screen is the canvas.** No panel is ever docked in a way
  that shrinks the play/design area — every panel below *floats over*
  the canvas and can be dismissed, so a phone in portrait still has its
  full width to drag across.
- **A single always-visible strip, thin, along the top**: the
  Design/Play toggle, and (Design mode only) an "Add Item" button and a
  "Room" button. Nothing else lives here permanently — this is the one
  piece of chrome that's never optional, and it's short enough (one row
  of icon buttons) to never meaningfully cover a small screen.
- **Tap an item (Design mode) → a compact property sheet slides up from
  the bottom**, sized to its content, not the full screen height — color
  swatches, velocity vector (x/y, speed, direction), key + note picker
  and exact pitch,
  Duplicate and Delete buttons. Tapping anywhere on the canvas outside
  the selected item dismisses the sheet. Dragging the selected item works
  the whole time the sheet is up (the sheet only covers the bottom strip
  it occupies, not the item itself, which stays reachable above it) —
  and if it doesn't for a given item's position, dragging always wins:
  the sheet auto-dismisses the instant a drag starts on any item.
- **"Room" opens the same kind of bottom sheet** — width/height fields,
  and per-axis "animate with a sine wave" toggles that reveal amplitude/
  period fields only once switched on (nothing shown that isn't currently
  relevant).
- **Play mode hides every panel except the top strip's Design/Play
  toggle** — the brief's "melody," once triggered, should be watched, not
  configured; there is nothing to click on except "back to Design."
- **Long-press (or a dedicated Duplicate button in the property sheet,
  whichever proves more reliable on the target devices) duplicates the
  selected item** slightly offset from the original, still selected, so
  a player can lay down a quick run of same-toned or differently-toned
  items without re-opening "Add Item" each time — directly answering
  "players can duplicate items as well to quickly setup a nice sequence
  of tones."

## Standing rule

Same spirit as `docs/game.md`'s SOLID rule, restated for this engine and
this PoC's actual purpose (proving the architecture, not shipping a
finished game):

- Every new item type is one `ITEM_CATALOG` entry, never a new `if type
  == "..."` anywhere else in the code.
- Every new property or behavior is one `Behavior` subclass, attached
  through an item's (or room's) behavior list — never a special case in
  `Item`, `Room`, or the UI.
- The UI only ever reads the catalogue/behavior registry to decide what
  it can offer — it never hardcodes "sphere" or any other type name
  outside `item_catalog.gd`.
- A regression here is a regression, not a feature request: if adding
  the *second* item type or property (see Phase 5 below) needs a special
  case bolted onto `Item`/`Room`/the UI, that's a sign this phase's
  architecture wasn't generalized enough, and the fix is to go back and
  generalize it — not to special-case the second type.

## Phased plan for demo 1 — "Bounce Melody"

- [x] **Phase 0 — toolchain spike.** Prove the export pipeline works
      before building anything on top of it: a `Main.tscn` with one
      script that draws a single static circle, exported to
      `static/game2/bounce-melody/` via `godot4 --headless --export-release
      "Web"`, served locally, loads with zero console errors in a
      headless-Chromium Playwright check. This is the same
      "resolve the unknown cheaply first" move `docs/game.md` made before
      committing to the depth-buffer demo.
- [x] **Phase 1 — core physics + tone, no UI yet.** `Room` (fixed-size
      rectangle), one hardcoded `sphere` item, `ConstantSpeedBounce
      Behavior` moving it and reflecting off all four walls,
      `ToneOnWallHitBehavior` playing a short procedural sine-tone burst
      (`AudioStreamGenerator`) on every hit. A Design/Play toggle exists
      but Design mode has nothing to configure yet — this phase is purely
      "does the physics-and-audio core work."
- [x] **Phase 2 — item authoring in Design mode.** Add Item (reads
      `ITEM_CATALOG`), tap-to-select with the bottom property sheet,
      drag-to-reposition, Delete, Duplicate, color swatches, a direction
      dial + speed slider driving `data.velocity`, a note/pitch slider
      driving `data.note`.
- [x] **Phase 3 — room properties.** Width/height fields, per-axis sine-
      wave toggle + amplitude + period, implemented as a `RoomBehavior`
      ticked only in Play mode (Design mode always shows the room at its
      configured base size, so "what you're designing against" stays
      predictable).
- [ ] **Phase 4 — mobile UI pass.** Verify the floating-panel layout
      above on a small viewport specifically (Playwright device
      emulation, e.g. a 390×844 viewport): confirm a drag started on an
      item is never intercepted by a panel, confirm the property sheet
      auto-dismisses on drag-start, confirm nothing but the top strip
      survives into Play mode.
- [ ] **Phase 5 — extensibility acceptance test.** Add one genuinely new
      thing — either a second item type (e.g. a "wall-mounted" item that
      doesn't move, only rings when hit by something else) or a second
      behavior (e.g. a per-item volume or pitch-drift property) — using
      only `ITEM_CATALOG`/`Behavior` as they already exist. If this needs
      a new `if` in `Item`, `Room`, or the UI, the Standing Rule above was
      violated somewhere in Phases 1–3 and that's what gets fixed, not
      this phase special-cased around it.

### Phases 0–3 complete

Built and verified in one pass rather than four separate landings — the
physics/tone core (Phase 1), Design-mode authoring (Phase 2), and room
properties (Phase 3) all needed each other to be meaningfully testable at
all (there's nothing to design without authoring, nothing to watch bounce
without physics), so they're one commit. Phase 4 (a dedicated mobile-
viewport pass) and Phase 5 (the extensibility acceptance test) remain
open, deliberately.

**Toolchain, resolved (Phase 0's actual spike):** Ubuntu's own package
archive only carries Godot 3.5 — the 4.3 stable editor and Web export
templates were fetched straight from the `godotengine/godot` GitHub
release, since `github.com/…/releases/download/…` resolves through
`release-assets.githubusercontent.com` (not blocked) where
`downloads.tuxfamily.org` (Godot's own CDN) is blocked by this sandbox's
egress policy. Export templates are ~1GB zipped covering every platform;
only the two Web variants actually needed
(`web_nothreads_release.zip`/`web_nothreads_debug.zip` — "nothreads"
because threaded WASM needs COOP/COEP cross-origin-isolation response
headers this static site doesn't send, so nothreads is the correct
choice for this hosting, not just the convenient one) were extracted to
`~/.local/share/godot/export_templates/4.3.stable/`, keeping the
resident footprint to ~17MB. **A real, non-obvious gotcha**: a brand-new
project (never opened in an interactive editor, per this file's own
"procedurally-built scene tree" decision) fails every cross-file
`class_name` reference (`Item`, `Room`, `ConstantSpeedBounceBehavior`,
etc. all report "not declared in the current scope") the first time it's
run headless — Godot only builds its global script-class cache
(`.godot/global_script_class_cache.cfg`) during an *editor* load, never
during a plain game run. The fix, and now a standing step for any new
game2 project: `godot4 --headless --editor --quit --path .` once, before
the first `--export-release`, to force that scan — `--headless` keeps
this display-server-free the whole time, no Xvfb or GPU needed.

**Two real bugs, caught by verifying against actual running output, not
by re-reading the code:**

1. **The Width/Height room-size sliders' initial sync corrupted
   `room.base_height` before it was ever read correctly.**
   `_build_room_sheet()` set `width_slider.value = main.room.base_width`
   *then* `height_slider.value = main.room.base_height` — but assigning
   `.value` on a Godot `Range` fires `value_changed` immediately, and the
   connected handler (`_on_room_size_changed`) reads *both* sliders'
   current value every time it runs. The first assignment fired while
   `height_slider` still held its just-constructed default (clamped to
   its own `min_value`, 120), so it called `set_base_size(480, 120)` —
   overwriting `main.room.base_height` from 760 down to 120 *before* the
   second line ever got to read the correct original value out of it.
   Caught because a debug print of `room.width`/`room.height` right after
   `_ready()` showed `480×120`, not the coded default `480×760`, and a
   screenshot showed a room that was visibly a thin horizontal band, not
   filling the screen. Fixed by switching both initial-sync assignments
   to `set_value_no_signal()`, which never fires the handler at all for a
   purely-cosmetic initial sync — the general lesson (documented here so
   it isn't re-learned the hard way on a future room-behavior UI):
   **any Godot `Range`/`Control` initial-value sync that a signal handler
   reads *other* controls' current value from must use
   `set_value_no_signal`, never plain `.value =`, or construction order
   becomes load-bearing.**
2. **The item property sheet never came back after a drag.** Pressing
   down on an item calls `ui.dismiss_sheets_for_drag()` (so the sheet
   never blocks the drag itself), but releasing the drag never told the
   UI to re-show anything — `selected_item` was still correctly set the
   whole time, the sheet was just left hidden. Caught by screenshotting a
   scripted "drag, then click a color swatch" sequence and seeing the
   click land on nothing (the sheet wasn't there to click). Fixed: the
   release branch of `_handle_press` now calls
   `ui.on_selection_changed(selected_item)` once the drag ends, restoring
   the sheet for whatever's still selected — releasing a drag never
   changes selection, so this is exactly "show the sheet a plain tap
   would have shown," not new behavior.

**Known, non-blocking risk**: every `ToneEngine.play_tone()` call logs
`USER WARNING: ... is trying to play a sample from a stream that cannot
be sampled` in the browser console (Godot 4.3's newer "audio samples"
fast-path doesn't apply to `AudioStreamGenerator`, and it says so loudly
even though it still falls through to the correct streaming
`push_frame` path this code already uses). Cosmetic, not a functional
bug — the physics/tone-trigger-count verification below confirms
`play_tone` runs exactly once per wall hit regardless — but a headless
browser can't confirm actual audible output, so this is written down
as a real gap rather than an implicitly-claimed one: **next session with
real speakers or a WAV-capture harness should confirm audio is actually
audible**, not just that the code path that should produce it ran.

**Repo-size note**: each Godot Web export's `.wasm` is ~35MB (the "Bounce
Melody" project is a handful of small scripts; nearly all of that is the
engine + GL-compatibility renderer + physics/audio modules baked into
every Web export regardless of project size) — expected to repeat per
demo added to this folder, not a regression to chase.

### Scene reset, save/load, precise values, vectors, real notes

Brief (verbatim):

> Change game2 so the scene resets to the starting point when play
> stopped. Make it the default but configurable so if turned off it does
> like now where it does not reset but freeze in time when stopped. When
> stated it should start from that state (either where reset or frozen
> but if user changed anything then start from there obviously). Also
> allow user to save their setup for later load again and an option to
> auto save once saved. All sliders should be able to be set to a precise
> value. Eg numeric input or something. The direction is just a slider.
> Needs to be able to set as a vector that is displayed as a thin line
> with an arrow going out from the item. Notes should be able to be set
> from actual scales and to actual notes

What was built:

- **Scene state is one dictionary.** `Main.capture_state()` /
  `Main.apply_state()` serialize the whole scene (room base size + sine
  waves via `Room.to_dict/from_dict`, every item via `ItemData.to_dict/
  from_dict`, the musical key). Pressing Play snapshots it (plus the
  room's live animation phase and the selection); Stop either applies
  that snapshot back (**"Reset scene on stop"**, on by default) or leaves
  everything frozen mid-flight, room size/phase included, so the next
  Play continues from there. Either way, Play always starts from whatever
  is on screen, including any edits made after stopping.
- **Save / Load** (top strip): named setups as JSON under
  `user://saves/` (`scene_store.gd`). On the Web export `user://` is
  IndexedDB, so saves survive a reload in the same browser. After a save
  or load, **"Auto-save changes to …"** writes every design edit back to
  that setup (debounced 0.8s, never mid-Play). With auto-save on, the page
  reopens that setup on the next visit. Settings (reset-on-stop,
  auto-save, current setup) persist in `user://settings.json`.
- **Every slider has a typed numeric box** (`ui/number_field.gd`, a
  slider + `SpinBox` kept in sync). The Web export's experimental virtual
  keyboard is enabled so the boxes are typeable on phones.
  Three Web-only gotchas, fixed after "tapping a number box hides the
  sheet" was reported (and reproduced in Playwright with touch
  emulation): a press on a SpinBox's text box can reach
  `Main._unhandled_input` unconsumed, where it read as an empty-canvas
  tap and deselected the item — presses over a visible panel are now
  ignored there (`UIRoot.is_over_panel`). Phone keystrokes go to a
  hidden HTML `<input>`, so Enter never reached the SpinBox (which only
  applies typed text on Enter or focus loss); Enter now blurs that input
  and `UIRoot._process` releases the box's focus once it's blurred,
  committing the number, and the first canvas tap after typing just
  commits too. And the tap swallowed select-all-on-focus, so digits
  appended to the old value; `NumberField` now selects it and re-opens
  the keyboard with that selection.
- **Velocity is a vector.** In Design mode every item draws a thin arrow
  from its edge along its velocity (length proportional to speed,
  `Item.VECTOR_SCALE`); the selected item's arrow tip has a handle that
  drags direction and speed together. The sheet also takes exact `x`/`y`
  components, or speed + direction in degrees (0° = right, clockwise,
  since y points down).
- **Real notes and scales** (`music_theory.gd`, 12-TET, A4 = 440 Hz): a
  scene-wide key (root + major/minor/modes/pentatonic/blues/…), a note
  picker listing only that scale's notes C2–C7, `<`/`>` to step through
  the scale (previewing the tone), and the exact Hz box still there for
  off-scale pitches (shown as e.g. `~A4 +20c`).

Verified: a headless GDScript run (reset restores exact position/
velocity, freeze keeps position and room phase, edits after a freeze
become the next start, save → modify → load round-trip, auto-save fires,
vector-tip ↔ velocity round-trip), then the exported build in headless
Chromium at 480×800: arrow-tip drag, typing an exact speed, stepping a
note, saving, enabling auto-save, turning reset off, Play → Stop freezes,
and a page reload brings back the auto-saved frozen scene. The default
font has no `▶`/`■` glyphs (they rendered as boxes before), so buttons
now use plain text.

## Verification approach

Same methodology as `docs/game.md`'s demos, adapted for a compiled
export instead of a static HTML file: serve `static/game2/bounce-melody/`
over a local `http.server`, drive it with headless Playwright
(`/opt/pw-browsers/chromium`), and confirm zero page/console errors.
Godot's Web export boots asynchronously (WASM fetch + instantiate), so
every check waits for the `#canvas` element plus a short settle delay
rather than a fixed sleep. Since this is a physics simulation, "it
works" is verified by sampling an item's live position/speed via
temporary debug prints (removed before commit) across real elapsed time,
not just a screenshot — the same "verify, don't just assert" bar the
other game folder's own z-index-popping investigation set.

**Verified, this pass:**

- **Constant speed**: sampled one item's `velocity.length()` every 0.25s
  across a 3+ second Play-mode run, through several wall bounces —
  every sample read `220.000015258789` (or `219.999984741211` on a
  re-export — float rounding noise at the 5th significant digit, not
  drift), confirming the brief's "never loses momentum just constant
  speed" holds exactly, not approximately, across real collisions.
- **Tones on wall hits**: `ToneEngine.play_tone` fired 4–5 times across
  the same run, timed exactly at the moments position samples showed a
  bounce — confirming the tone trigger is wired to the actual collision,
  not a timer.
- **Sine-wave room resize**: enabled the width wave (nonzero amplitude, a
  short period) and sampled `room.width` every ~0.26s across 6 seconds
  of Play mode — values rose and fell smoothly between `~399` and `~562`
  across two full visible cycles, while `velocity.length()` stayed
  exactly `220` throughout — confirming the room can resize live without
  ever touching an item's speed.
- **Design-mode authoring**, each confirmed by screenshot: Add Item
  (spawns a new selected sphere at the room's center), drag-to-reposition
  (works anywhere on the canvas, sheet correctly hidden mid-drag and
  restored after release once the bug above was fixed), color swatches
  (recolors the selected item immediately), Duplicate (a second item
  appears offset from the original, selected), Delete (removes exactly
  the selected item, selection clears).
- **Play mode hides every Design-only control**: screenshotted mid-Play —
  only the Design/Play toggle remains in the top strip, `Add Item`/`Room`
  are gone, no property sheet is showing.
- **Zero page/console errors** other than the pre-existing stray-404
  favicon message this repo's other demos already discount, and the
  documented-above `AudioStreamGenerator` warning.
- **Not yet done** (left for Phase 4, honestly, not silently): the same
  interaction set re-verified under Playwright's actual touch/mobile
  device emulation (`hasTouch`/`isMobile`) rather than mouse events at a
  small viewport — an attempt this pass showed no interaction registering
  at all under that emulation mode, most likely a coordinate/DPR-scaling
  mismatch in the *test*, not necessarily the app (Godot's Web export
  does listen for both mouse and touch input classes, and this code
  handles both), but that's a claim to verify, not assume, so it's
  written down as open rather than papered over.

### Hosting problem: Cloudflare Workers' 25 MiB asset limit

The real site's deploy (`wrangler deploy`, per `daily-deploy.yml`) failed
outright trying to ship this demo: Cloudflare Workers rejects any single
asset over 25 MiB, and Bounce Melody's `index.wasm` is ~34 MiB — this is
Godot 4's standard Web release template baseline (GL Compatibility
renderer + core modules), not something this project's own code
inflated; a same-project export against Godot 4.6 measured *larger*
(~37.6 MiB), and compiling a custom, module-stripped export template
(the standard way indie Godot-web devs get under a size target) needs
the engine's own source, which this sandbox's network policy blocks
fetching (`github.com/godotengine/godot/*` outside a `releases/download/`
asset redirect is intercepted) — expanding this session's repo scope to
the entire upstream Godot engine repo to work around that felt like the
wrong tool for the job, so it wasn't done.

**Fix**: `.github/workflows/game2-pages.yml`, a second, independent
deploy — GitHub Pages, which has no comparable per-file limit — that
publishes exactly one demo folder (`static/game2/bounce-melody/` today)
as the Pages site's own root. This is deliberately *not* the same
`static/game2/index.html` listing the real site would use: that index's
own links are absolute (`/game2/<name>/`), which only resolve correctly
served from the real domain's root, not from a GitHub Pages project
site's `github.io/<repo>/` subpath — a single demo's own asset
references (`index.js`/`.wasm`/`.pck`) are already relative, so serving
just that folder at the Pages root sidesteps the whole subpath problem
rather than fighting it. This workflow only ever touches this repo's
`github.io` Pages site, never the `oraclecardoftheday.com` custom
domain or the daily-deploy pipeline — there is no path by which it can
affect the real site.

This is a workaround, not a resolution — the real site still can't serve
this demo. Genuinely resolving it needs one of: a custom-compiled,
module-stripped export template (blocked here, open to whoever has
unrestricted access to fetch Godot's source), or moving large game2
assets to a store without Cloudflare Workers' per-asset limit (R2, fetched
through a Worker) instead of Workers' own static-asset handling — both
real options, neither attempted yet.

**Update 2026-09-25**: the hosting decision (stay on Pages) and the plan
from here (one shared engine copy, a Netlify standby, R2 for the real
domain) are in `docs/hosting.md`.

## Demo 2 — "Ragdoll Meme Maker" (`game2/ragdoll-meme/`)

Brief (verbatim):

> Game2 user should be able to add a ragdoll and add a photo from the
> internet as the face to it and style the entire body with photos from
> internet or with different emojis or different styles of lines to
> quickly and easily make their own custom person and then they can
> record an animation of it using inverse kinematica combined with
> procedural animation to make funny wonky animations that could easily
> go viral because they're fun to look at Eg by adding physical forces
> that the doll acts on or other pulls pushes wind etc. Basically users
> can create a meme video animation in minutes that has potential to go
> viral. We want to play into users being able to have fun creating and a
> playground that makes it easy and quick to make novel viral trends to
> post to some

Built as a second demo in this folder rather than a mode of Bounce
Melody: nothing is shared but the approach (and a copy of
`ui/number_field.gd`), so each project stays self-contained and
exportable on its own. It shows up in the generated `static/game2/`
index automatically, and `.github/workflows/game2-pages.yml` publishes it
at <https://bvandersen.github.io/playground/game2/ragdoll-meme/> alongside
Bounce Melody (which stays the Pages root).

Re-export after a source change:
`godot4 --headless --path game2/ragdoll-meme --export-release "Web"`, then
`node scripts/game2-postexport.mjs ragdoll-meme`.

### What a player does

1. **Build a person** (Look sheet). A doll is six styleable parts: head,
   body, arms, legs, hands, feet. The head can be a drawn cartoon face
   (six expressions, which scream and widen their eyes as the head flies
   faster), any emoji, or a **photo**. The photo can come from a web
   search (Openverse, falling back to Wikimedia Commons), a pasted link,
   or an upload from the phone's camera roll, and it's cropped into the
   head circle with zoom/offset. Body, arms and legs can be **lines** in
   nine styles (noodle, solid, stick, scribble with "boiling" hand-drawn
   jitter, dashed, spring, beads, rainbow, neon), a chain of stamped
   **emoji** (🌭 arms, 🍌 legs...), or a **photo** mapped along the limb
   like a sleeve. There are six one-tap presets plus 🎲 Random, a
   "whole body" switch, head size (bobbleheads) and doll size. Up to 8
   dolls, each styled separately.
2. **Make it move** (Moves sheet, per doll). Stand up (balance), Dance,
   Floss, Tube-man flail, Headbang, Wave, Walk, Jump and Spin, freely
   combined, each with its own sliders, plus a Muscles slider from
   floppy ragdoll to snappy puppet.
3. **Throw physics at it.** Forces sheet: gravity strength and tilt,
   slow-mo, rubber limbs, bounciness, floor grip, air drag, gusty wind,
   tornado, earthquake, walls on/off. Tool row: Grab (drag any joint,
   flick to throw, several fingers at once to puppeteer), Pin (nail a
   joint, or drag out a rope to hang it from), Boom (explosion + camera
   shake), Balloon (tie some on and float away), Magnet (pull or push,
   drag to move), Erase, and Freeze (time stops and dragging poses the
   body: pure IK).
4. **Dress the scene** (Scene sheet). Impact-style top/bottom meme
   caption (emoji work), gradient/colour/photo background (including a
   green screen), floor colour, and an optional "made with" watermark.
   🎲 "Surprise me!" randomizes every doll's look and moves plus one
   force, which is the fastest way to something weird.
5. **Record.** REC → 3-2-1 → it records the stage only (and the sound
   effects -- see "Sound effects" below), into a 720×1280
   (9:16) video: mp4 where the browser can encode it (Chrome/Edge/
   Safari), webm otherwise, for up to 60 s while the player keeps
   dragging and blowing things up. Then a preview loops with **Share**
   (the phone's share sheet, straight into TikTok/Reels/Shorts, where
   supported) and **Download**.

### Decisions

- **Custom Verlet physics, not `RigidBody2D` + joints** (`doll/doll.gd`,
  `world/world.gd`). The brief's "inverse kinematics" *is* position-based
  dynamics. Pin the grabbed particle to the finger and the stick
  constraints drag the rest of the chain after it, which is IK that also
  swings, collides and can be thrown (velocity is just `pos - prev`).
  Rubber limbs are one stiffness number. A physics-engine joint chain
  fights all three and is much less predictable to tune. 12 joints,
  3 substeps × 7 constraint iterations at 60 Hz.
- **Procedural animation = muscles pulling toward a posed skeleton.** A
  `Move` never touches particles; it bends the rest pose's offsets and
  sets a few context fields (lean, crouch, spin, balance...). The doll's
  muscles then pull every joint toward that pose, placed at the pelvis.
  So every move combines with every other move, with every force and
  with whatever the player is dragging, and the physics resolves the mix
  into something wonky. Three things were needed to make that stable,
  all found by the headless check below rather than by eye:
  - The muscle pulls are **internal forces**: their net push is
    subtracted again. Without that, a pose the arms can't reach (hands
    higher than arms are long) lifted the doll by its own hands. Floss
    and Walk flew it to the ceiling.
  - Standing feet are **planted**: they're locked in place, and a planted
    foot's muscle pull goes into the rest of the body as ground reaction.
    Without that, a swaying upper body dragged its feet along the floor
    and the doll skated across the whole stage in under a second
    (Dance + Tube man).
  - Only ~30% of a muscle pull becomes momentum, and the balance
    "gyroscope" (the one deliberate cheat, which eases a doll back over
    its feet so a ragdoll can get up at all) moves the body without adding
    velocity. Without that, the fight between muscles and bone lengths
    jittered dolls into hops.
- **Catalogs, same standing rule as Bounce Melody.** Moves
  (`moves/move_catalog.gd`), forces (`forces/force_catalog.gd`), stage
  tools (`tools/tool_catalog.gd`), line styles (`doll/line_styles.gd`)
  and faces (`doll/face_painter.gd`) are each one registry. Moves and
  forces *declare* their params, and the Moves/Forces sheets build their
  sliders from those declarations, so a new move or force is one file
  plus one catalog line with no UI code.
- **The browser does what Godot's Web build can't** (`media/web_bridge.gd`,
  a JS blob installed once):
  - Emoji are drawn by the device's own emoji font onto a canvas and
    handed to Godot as PNGs. Godot's fonts have no emoji glyphs, and this
    way they look like the emoji people know from their phone. Off the
    Web, Twemoji PNGs are fetched instead.
  - Meme captions are drawn the same way (Impact + black outline,
    wrapped, emoji included).
  - Photos load through an `<img crossOrigin>`: directly when the host
    allows CORS, else through the `wsrv.nl` image proxy (a third party:
    the image URL goes through it). The browser decodes any format it
    can (gif, avif, heic on Safari), and the result is downsized to
    640px and cached under `user://images/` with a manifest of where
    each came from, so a reload gets them back.
  - Upload uses a real `<input type=file>`.
  - Recording draws the stage's rectangle of the Godot canvas into a
    720×1280 canvas every animation frame and feeds that canvas's
    `captureStream()` to `MediaRecorder`. That only works because the
    export's `html/head_include` patches `getContext` to force WebGL's
    `preserveDrawingBuffer` on (otherwise the canvas reads back blank
    outside Godot's own frame callback).
- **Portrait 9:16 stage in fixed 720×1280 units.** Physics behaves the
  same on every screen, and a recording is always a clean phone-video
  frame. Main scales it to fit between the top strip and the tool row.
  While a sheet is open the stage shrinks to fit above it, so the doll
  being styled stays visible. All chrome is outside the stage rectangle
  (hints are suppressed while recording), so none of it can end up in a
  video.
- **Auto-save** of the design (looks, moves, forces, scene) to
  `user://scene.json`, 1 s after the last edit. Positions and props
  aren't saved; a reload stands everyone back up.

### Verification

- `tools/sim_check.tscn` (`godot4 --headless --path game2/ragdoll-meme
  res://tools/sim_check.tscn`, excluded from the export) steps a World
  with no window and prints what matters: stands, falls over with
  balance off and gets back up with it on, a dragged hand reaches exactly
  the finger and the body hangs from it, every move and every force runs
  with all positions finite, and each move's drift over 5 s. Final
  numbers: headbang/wave ≤ 7 px, dance/floss/flail sway up to ~100 px
  and end near where they started. The triple combo Dance+Headbang+Floss
  wanders ~240 px in 5 s, which is left as wonky on purpose. Also
  checked: 4 balloons lift a doll, and the save/load round-trip is
  identical.
- The exported build was checked in headless Chromium (Playwright) at
  390×844, at DPR 1 and 2 and with real touch events, plus 1280×800:
  - dragging a joint;
  - **two fingers dragging both hands at once**;
  - tapping GUI buttons by touch;
  - every sheet, all presets, Random and three dolls;
  - a photo face from a pasted link, zoomed;
  - balloons lifting a doll, a rope pin, a magnet, Boom;
  - Surprise me + caption;
  - REC → a 720×1280 mp4 (~0.6 MB for ~5 s) whose decoded frames show
    exactly the stage: no top strip, tool row, hint or countdown digit.
    The last "1" of the countdown was leaking into the first frames
    before capture start was delayed two frames.
- **Not verified here (honestly open):**
  - Photo *search* and the wsrv.nl proxy: this sandbox's network policy
    blocks api.openverse.org, commons.wikimedia.org and wsrv.nl. Search
    was only checked to fail gracefully ("can't be reached — paste a
    link or upload"). Openverse's CORS headers in particular are
    unconfirmed; Wikimedia with `origin=*` is the documented-CORS
    fallback.
  - The Share button (headless Chromium has no share sheet) and the
    device photo picker (needs a real file dialog).
  - iOS Safari: its transient-user-activation rules for the file picker
    are stricter than Chrome's.
  - Sound effects on a real phone: iOS mutes Web Audio while the ring/
    silent switch is on, and whether Safari's MediaRecorder keeps the
    mixed-in sound track wasn't checked here.

### Sound effects

Brief (verbatim):

> Add funny sounds to trigger on diff events such as on impact on bending
> back a lot, on balloon attach and so on that can trigger all kinds of
> funny sounds. Load cc free sounds or make some using Elevenlabs mcp

- **Clips:** 31 short mp3s in `game2/ragdoll-meme/sfx/`, generated with
  ElevenLabs' text-to-sound model (`eleven_text_to_sound_v2`) through
  the ElevenLabs MCP, then trimmed of silence, capped at 0.3-2.2 s, faded
  out, peak-normalized to -1 dB and re-encoded as mono 64 kbps with
  ffmpeg: 324 KB in all. What they may be used for follows the
  ElevenLabs account's plan terms (check before a store release). The
  prompts, one line per file:

  | file | prompt |
  |---|---|
  | thud_1, thud_2 | Soft cartoon body thud landing on a wooden floor, short |
  | slam_1, slam_2 | Heavy comedic body slam on the floor with a wet splat, short |
  | bonk_1 | Cartoon bonk, hollow wooden knock on a head, short and funny, close-mic |
  | bonk_2 | Cartoon bonk, metal frying pan hitting a head, short ring |
  | crack_1, crack_2 | Cartoon bone crack, crunchy knuckle crack, short and comedic |
  | ouch_1, ouch_2 | Goofy cartoon character yelping "ow!", short high-pitched voice |
  | scream_1, scream_2 | Goofy cartoon man screaming "aaaah" while flying through the air, short |
  | balloon_tie | Rubber balloon being inflated and tied, squeaky rubber stretch, short |
  | balloon_pop | Loud rubber balloon bursting, sharp bang, close-mic |
  | boom_1, boom_2 | Cartoon explosion, punchy comedic boom with debris clatter |
  | pin | Hammer hitting a nail into wood, single thunk, short |
  | rope | Rope pulled tight, creaky rope stretch, short |
  | magnet | Cartoon magnet activation, electric zap with a wobbly hum, short |
  | boing_1, boing_2 | Cartoon spring boing, wobbly jaw harp twang, short |
  | trombone | Sad trombone, wah wah wah waaah, comedic fail |
  | scratch | Vinyl record scratch, needle scratch stop |
  | whistle | Cartoon slide whistle going up, quick |
  | whoosh | Fast cartoon whoosh, swish through the air |
  | fart | Short comedic squeaky cartoon fart |
  | squeak | Rubber squeaky toy squeezed once |
  | poof | Cartoon poof, magical puff of smoke appearing with a sparkle chime |
  | stretch | Rubber band stretching, creaky elastic stretch, cartoon |
  | beep | Short digital countdown beep, clean |
  | vanish | Cartoon vanish, quick zip and pop disappearing |

  The first balloon-pop prompt ("Balloon popping, sharp loud pop") came
  back near-silent (-35 dB peak) and was regenerated.
- **What triggers what** (`media/sfx.gd` is the catalog: event id ->
  clips, loudness, pitch wobble, minimum gap between repeats):
  - physics, detected by `world/sound_events.gd` from what the solver
    did each frame: a body part hitting the floor or a wall (thud, slam
    above ~1350 px/s, bonk for the head; a hard landing on the behind is
    sometimes a fart, a slam sometimes gets an "ow!"), a knee or elbow
    folding far past natural or the neck/spine bending far back (crack,
    often + "ow!"), rubber limbs pulled past 1.6x their length
    (stretch), a doll flying fast (scream), a doll that stood for a
    second falling flat (sad trombone), two dolls knocking together
    (bonk);
  - tools and moves: grab (squeak), flick-throw (whoosh), pin (hammer),
    rope (creak), boom (explosion; balloons caught in the middle pop),
    balloon tied on (squeaky inflate), erase (balloon pop / vanish),
    magnet placed or flipped (zap, higher when it flips to push), Jump
    (boing), Freeze on/off (record scratch / slide whistle), new or
    copied doll (poof), Surprise me (poof), REC countdown (beeps).
  - Pitch follows the scene: slow-mo plays everything lower, small dolls
    sound higher, big ones lower. Sounds pan with where they happened.
- **Bend detection compares against the animated pose too.** A crack
  needs the joint bent far from *both* its rest bend and the bend the
  moves are pulling it toward -- otherwise Dance, Wave and Flail cracked
  elbows every second (sim_check's first run: 6 cracks in 3 s of
  Dance). Impact speed is read from the step's full travel before the
  floor projection, not from the velocity after it (that read a 700 px
  drop as silent). With both fixes, standing, dancing, headbang, wave,
  quake and walls make at most one sound in 3 s in sim_check, and each
  deliberate mishap (fall over, drop, folded knee, hard throw, doll into
  doll) makes its own.
- **Played through the page's Web Audio, not Godot's**
  (`RagdollSfx` in `media/web_bridge.gd`). Godot hands each clip's mp3
  bytes (`AudioStreamMP3.data`, so they're in the .pck once) to the page,
  which decodes them. That graph is what the recorder taps: `RagdollRec`
  adds its `MediaStreamDestination` track to the captured stream and
  picks an audio+video codec string (`avc1,mp4a.40.2` / `vp9,opus`), so
  **the recorded video now has the sound effects in it**. The preview
  plays with sound where the browser allows, and a tap on it mutes.
  Audio is unlocked on the raw DOM pointer/key events, because Godot
  handles input a frame later, outside the user gesture. Off the Web
  a pool of AudioStreamPlayers plays the same clips.
- **Scene sheet -> Sound effects:** on/off, volume, and switches for the
  voices ("ow!", screams) and fart jokes; kept in `user://sound.json`,
  separate from the scene.
- **Verified** in headless Chromium against the export: all 31 clips
  decode, grab/balloon/boom/countdown events play, and a recording is a
  video/mp4 whose decoded audio track peaks at ~0.6. Not verified: how it
  sounds on a real phone (see "Not verified here" above).
- **Seen while tuning, not changed:** Walk moves a doll across the whole
  stage several times a second in sim_check (pelvis x jumping ~300 px
  every 10 frames, the same on the code before this change), so a
  walking doll slams at every turn-around.

## Git workflow for this folder

Same hard gate as the rest of this repo (`CLAUDE.md`): confirm
`git branch --show-current` is `main` before every commit, fetch-and-
compare before *and* after committing, push straight to `main`. For this
specific build-out the brief asked for **every commit pushed
immediately** — no batching several local commits before one push —
so each phase above lands as its own commit, pushed the moment it's
verified, not held until the whole demo is done.
