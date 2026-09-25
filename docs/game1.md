# game1 — Rail Yard (Godot top-down train playground) — plan

A standalone, unlisted interactive demo, built the same way as game2
(see `docs/game2.md`): a **Godot 4.3 HTML5 export**, source under
`game1/<demo>/`, exported build committed under `static/game1/<demo>/`.
Everything game2's plan says about *why* it's built that way (Godot 4
over 3, the nothreads Web templates, procedurally built scene tree with
one `Main.tscn`, the export never being part of any site build, the
`.godot/` cache being gitignored, the Cloudflare 25 MiB asset limit and
the GitHub Pages deploy) applies here unchanged and isn't repeated.

## Original brief (verbatim)

> Make a game1 based on how game2 is made but this one should be train
> tracks that I can lay out and draw in design view and place trains with
> different wagons on the tracks. Seen from above 2d. Good looking wagon
> physics procedural animation

## What it is

- **Design mode**: a top strip with `Play`, and the tools `Select`,
  `Draw`, `Erase`, `+Train`, plus `Menu`.
  Every button is a picture rather than a word, so a child who can't
  read yet can use it (`IconArt` in `scripts/ui/icon_art.gd` draws them
  procedurally, `IconButton` shows one; the words stay as tooltips):
  ▶/■ play/stop, a hand (Select), a pencil (Draw), an eraser (Erase), a
  steam engine with a green + (+Train), ≡ (Menu), a curly back arrow
  (Undo); in the menu four corners around a loop (Fit view), a magic
  wand (Demo layout), a bin (Clear all / delete a save), arrow-into-box /
  arrow-out-of-box (Save / Load), circling arrows (auto-save on/off) and
  rewind (reset trains on stop on/off); in the train sheet an arrow
  (which way it sets off), a U-turn (Turn around), ▶/⏸ (Runs), an eye
  (Follow), a bin (Delete) and a tick (Done). The consist and the
  "add a wagon" buttons are little wagons painted by `WagonArt` itself,
  with a red × or green + badge. Emoji aren't used because the Web export
  has no system-font fallback to draw them.
  - **Draw**: drag a finger/mouse to lay track. The stroke is thinned,
    smoothed (Chaikin corner cutting) and resampled every 5 px. If it
    starts or ends on existing track it's bent to join *tangentially*
    (a short straight lead-in along that track before smoothing), so
    every junction a player draws is one a train can run through.
    Starting or ending in the middle of a piece splits it there — that's
    how switches get made. Ending back on its own start closes a loop.
    A ghost of the stroke and green rings where it will join are shown
    while drawing.
  - **+Train**: tap a track to put down a ready-made train (one of a few
    presets: steam + tender + coaches, mixed freight, coal train, …). It
    faces the longer run of open track, and is refused if it would sit on
    top of another train or doesn't fit.
  - **Select**: tap a train to open its sheet; drag a train to slide it
    along its track (stops at buffers and other trains); drag the ground
    to pan; pinch or scroll to zoom; tap a switch to flip it.
  - **Train sheet**: livery colour, speed, `Reverse` (which way it sets
    off — a loco can push), `Turn around` (loco faces the other way,
    cars re-coupled behind), `Runs` (start stopped), the consist as chips
    (tap one to uncouple it), `+<type>` buttons to couple any vehicle on
    at the back, `Follow` (camera follows this train in Play), `Delete`.
  - **Erase**: tap a piece of track or a train.
  - **Undo** (floating, top right) for every structural edit.
  - **Menu**: Fit view, Demo layout, Clear all, named save/load with
    auto-save, and "Reset trains on stop" — the same save/reset/freeze
    model as game2 (`SceneStore`, `user://` → IndexedDB on the web).
- **Play mode**: trains run. Tap a train to stop/start it, tap a switch
  to flip it. Trains look ahead down the track (through switches as
  they're currently set) and brake to stop short of buffer stops and of
  other trains; after standing blocked for a moment they reverse, so
  layouts with dead ends and meeting trains shunt back and forth on
  their own instead of jamming. Nose-to-nose meetings use a randomised
  wait so one train backs off first.

## Architecture

Same "catalog + data + view" split game2 set up, applied to trains:

- **`TrackNetwork`** (`scripts/track/track_network.gd`) — the layout as
  a graph: `TrackSegment`s (smoothed polylines with cumulative arc
  length) joined at `TrackNode`s (1 port = buffer stop, 2 = plain joint,
  3+ = switch). Owns every edit (`add_stroke`, `split`, `remove_segment`,
  auto-merging plain joints back into one piece) and every routing
  question: `candidates()` — which branches a train arriving through a
  port can take (only those less than ~84° off its heading, sorted
  left-to-right so `switch_state` always means the same branch) — and
  `walk()` for looking ahead. No drawing.
- **`TrackView`** draws it in layers across *all* pieces (ballast edge,
  ballast, sleepers, rails, then buffer stops and switch indicators), so
  crossings and junctions overlap like real track.
- **`Route`** (`scripts/train/route.gd`) — the stretch of track one
  train is on: a chain of oriented segments with one continuous
  coordinate `s`. It grows at whichever end the train approaches
  (choosing branches at switches *as they're set at that moment*) and
  drops pieces the train has left. Because `s` is never re-based,
  physics sees the whole train as points on a line however many
  switches it crosses.
- **`Train`** (`scripts/train/train.gd`) — saved description (loco
  position + heading, direction, speed, livery, cars) plus runtime
  physics and visual state.
- **`WagonCatalog`** (autoload) — the one place a vehicle type is
  registered: name, length, width, mass, powered, smoke kind/position,
  whether it takes the livery, default colours, and its painter.
- **`WagonArt`** — procedural top-down painters, one per type, no image
  assets: diesel (hood, fans, cab, windscreen, stripes, headlights),
  steam (boiler with highlight and brass bands, smokebox, chimney, domes,
  cab), tender and hopper (seeded coal lumps), coach (roof, clerestory,
  vents, gangways), boxcar, tanker (shaded cylinder, dome, walkway),
  log flat (seeded logs with ring ends, stakes, chains), container flat
  (one 40 ft or two 20 ft boxes), caboose (cupola, tail lamps).
- **`TrainsView`** draws every train in passes (shadows, headlight
  cones, bogies, couplers/buffers, bodies, selection) so one train's
  shadow never lands on another's roof.
- **`Smoke`**, **`Ground`** (seamless FastNoise grass + trees, bushes,
  rocks and tufts re-scattered clear of the track whenever it changes),
  **`DrawOverlay`**.

### Standing rule

As in game2: a new vehicle type is one `WagonCatalog` entry plus one
`WagonArt` painter — never an `if type == "..."` in `Train`,
`TrainsView` or the UI (the sheet's add buttons are generated from the
catalog). A new track feature is a `TrackNetwork` change, not a special
case in `Train`.

## The physics and procedural animation

The brief's "good looking wagon physics" is the heart of this demo, so
it's layered on purpose:

1. **1-D slack-action dynamics.** Each car is a mass at `s` along the
   route. Couplers have ±1.4 px of free slack, pull like a spring
   (`K_PULL`) and push like a stiffer buffer (`K_BUFF`), damped;
   integrated in 8 substeps per physics tick. Only locomotives apply
   traction and braking (a P-controller on the train's mean speed with
   rolling-resistance feed-forward and a stiffer braking gain), so a
   start snatches the couplers taut car by car and a stop runs the cars
   in against each other — the accordion effect of real trains. Buffer
   stops are stiff springs at the route's dead end.
2. **Bogies on the track, body on the chord.** Each car's two bogies are
   placed on the track at ±33 % of its length; the body sits on the line
   between them. On curves the body therefore overhangs the inside of
   the curve at its middle and the outside at its ends, and the bogies
   visibly swivel under it — the single biggest "looks like a real
   train" cue from above.
3. **Sway.** Centripetal acceleration `v² · curvature` (from the change
   in bogie tangents) drives a damped spring that shifts each body and,
   more visibly, its shadow outward in curves; it swings back and settles
   on the straight.
4. **Rail joints.** Every 42 px of track each bogie kicks a vertical
   bounce spring (harder the faster it goes), shown as a flicker in
   shadow offset and a hair of scale — the clickety-clack.
5. **Pitch.** Longitudinal acceleration tips the shadow forward when
   braking and back when accelerating.
6. **Exhaust.** Steam locos chuff a puff every 13 px travelled (four per
   wheel turn), bigger under load; diesels exhaust continuously,
   thickening with throttle. Puffs are clusters of blobs that drift with
   the wind plus some of the loco's velocity, swell and fade.
7. Headlight cones ahead of the lead loco in Play.

## Build & export

Same pipeline as game2 (Godot 4.3 stable Linux editor + the two
`web_nothreads_*` templates):

```sh
cd game1/rail-yard
godot4 --headless --editor --quit --path .      # builds the class_name cache (first time)
godot4 --headless --path . --export-release "Web"
cd ../.. && node scripts/game2-postexport.mjs rail-yard game1   # robots noindex + "(unlisted demo)" title
```

`.github/workflows/game2-pages.yml` publishes game1 alongside game2's
demo on the repo's GitHub Pages site, at `game1/rail-yard/` (the game2
demo stays at the site root, so its URL doesn't move). As with game2,
nothing links to it from any real site.

## Verification (this pass)

- Headless GDScript runs of the real scene: demo layout builds the
  expected graph (4 switches, 2 buffer stops, loop joint merged), both
  trains place, run to their set speeds (105 / 80 px/s exactly once the
  feed-forward was added — they settled 2.5 % low before), couplers sit
  at their slack length and stretch under acceleration, sway builds in
  curves and returns to 0 on straights; flipping the spur switch sends a
  train in, it brakes to a stop at the buffer (after tuning — first
  version braked too late and hit it at ~40 px/s), waits, reverses out;
  a following train matches the speed of the one ahead instead of
  running into it; save → JSON → load round trip; reset on stop.
- The exported build in headless Chromium (SwiftShader WebGL) at
  480×860: renders, no errors; drawing a branch off a straight makes a
  switch, a stroke between two tracks makes a crossover, `+Train`,
  the train sheet, `Follow` + Play, Clear all + a hand-drawn loop.
- Two bugs found that way and fixed: a train could be placed overlapping
  another (it poked through a switch onto the main line) — placement,
  coupling on cars and dragging now refuse overlaps; and after placing a
  train both `+Train` and `Select` stayed highlighted
  (`set_pressed_no_signal` bypasses the ButtonGroup).
- **Not verified**: real phones (touch/pinch were written to game2's
  proven pattern — emulated mouse events from touches are ignored via
  `DEVICE_ID_EMULATION`, touches tracked by index — but only desktop
  mouse input was driven in the test browser), and frame rate on a
  low-end phone with several long trains.
- 2D MSAA isn't supported by Godot 4.3's GLES3/WebGL renderer (it warns
  and ignores it), so edges rely on the anti-aliased outline strokes the
  painters draw rather than on MSAA.

## Ideas for later

Signals/blocks instead of look-ahead braking, turntables, uncoupling
into separate cuts that can be shunted, level crossings with road
traffic, sounds (chuff/horn/clack through the same procedural approach
as game2's ToneEngine), day/night with the headlights mattering.
