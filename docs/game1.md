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
  `Draw`, `Road`, `Smooth`, `Erase`, `+Train`, `+Build`, plus `Menu`
  (see "Roads, traffic, buildings and nature" below).
  Every button is a picture rather than a word, so a child who can't
  read yet can use it (`IconArt` in `scripts/ui/icon_art.gd` draws them
  procedurally, `IconButton` shows one; the words stay as tooltips):
  ▶/■ play/stop, a hand (Select), a pencil (Draw), a paintbrush
  sweeping a wobbly line straight (Smooth), an eraser (Erase), a
  steam engine with a green + (+Train), ≡ (Menu), a curly back arrow
  (Undo); in the menu four corners around a loop (Fit view), a magic
  wand (Demo layout), a bin (Clear all / delete a save), arrow-into-box /
  arrow-out-of-box (Save / Load), circling arrows (auto-save on/off) and
  rewind (reset trains on stop on/off), a loudspeaker (sounds on/off);
  in the train sheet an arrow
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
  - **Smooth**: a brush for track that's already laid. Hold and rub
    over wobbly track and it irons out under the ring, a little more
    every frame it's held (an airbrush, `BRUSH_RATE`); tap a piece to
    smooth all of it at once. Both ends of every piece stay put and the
    lead-in beside a junction keeps its tangent, so switches and joins
    still work; trains standing on the track are re-seated as it moves.
    One brush stroke is one undo step.
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
- **Smoothing** (`TrackNetwork.smooth_brush` / `smooth_segment`): each
  point moves towards a Gaussian-weighted average of its neighbours
  along the piece, then a slightly stronger step pushes it back out
  (Taubin's λ/μ pair, 1/λ + 1/μ ≈ 0.03). That removes wiggles of up to
  ~a hundred px but leaves broad curves alone, so a loop doesn't shrink
  as plain averaging would make it. The pass is always full strength and
  the brush blends only part of the way towards it each frame: tiny λ
  and μ steps cancel out and do nothing. Points are re-spaced every
  5 px once the stroke ends, not per frame, so the rest of the piece
  isn't nibbled at.
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

## Roads, traffic, buildings and nature

Brief (verbatim): "Train game add roads, many diff cars, trucks, busses,
houses, industry, shopping, nature".

- **Road tool** (a road with a yellow dashed line): drag to lay a road.
  `RoadNetwork` (`scripts/road/road_network.gd`) *is* a `TrackNetwork`
  (same segments, nodes, snapping, smoothing brush, save format), with
  two differences: a road started or ended on the side of another road
  joins at the angle it was drawn (a T-junction, not a tangent switch),
  and two roads that cross are split and joined into a crossroads
  (`add_road` → `_fuse_one_crossing`). Carrying on from a dead end still
  continues it smoothly. Smooth and Erase work on roads too.
- **Level crossings** (`LevelCrossing`): found afresh wherever a road
  crosses the track (`TrackNetwork.crossings`, also used for the
  crossroads). `RoadView` bakes the road (kerb, asphalt, junction patches,
  turning circles at dead ends, dashed centre and solid edge lines) and
  lays each crossing over it: rubber panels, the rails running through,
  stop lines and a painted X. In Play the barriers swing down and the
  lights flash while a train is getting closer and under 3.2 s away (at
  least 150 px), or is
  on the crossing; crossings within 110 px of each other shut together so
  nobody waits between two tracks. A bell rings while they're down.
  A vehicle already on a crossing hurries off it. Trains never wait for
  cars.
- **Traffic** (`Vehicle`, `VehicleCatalog`, `VehicleArt`, `VehiclesView`):
  25 types in three kinds. Cars: mini, hatchback, saloon, estate, SUV,
  sports car, taxi, police car, pickup, van, ice cream van. Lorries: box,
  tanker, tipper, cement mixer, log lorry, bin lorry, fire engine and an
  articulated lorry. Buses: city bus, school bus, double-decker, coach,
  minibus and a bendy bus. A vehicle drives along a *lane* polyline
  8.5 px right of the road centre (right-hand traffic), built a few pieces
  ahead; at each junction it picks a random way on, and at a dead end it
  turns round. Lanes of consecutive pieces are joined with a cubic Bezier,
  so corners and U-turns are one smooth path. Both axles sit on that path
  and the body on the chord between them (the trains' bogie trick); the
  articulated lorry's and the bendy bus's trailers follow a hitch. Each
  vehicle cruises at its own speed, slows for bends, keeps its distance
  from anything in its lane ahead, stops for closed crossings, and shows
  brake lights. Two vehicles waiting on each other at a junction (crossing
  paths, or merging into the same lane) sort it out: after a wait, the
  one that has waited longest beeps and goes first. All traffic is one
  mesh per frame, like the crowds.
- **Build tool** (a house with a +) opens a palette painted by the same
  painters that draw the layout: a station (moved here from the top
  strip), house, flats, shop, supermarket, factory, warehouse, farm, tree,
  woods, pond, flowers, and a car, a lorry and a bus (each tap puts down a
  different one of that kind, on the side of the road tapped). Buildings
  turn to face the nearest road and sit back from its kerb; they are
  refused on track, roads, stations or other buildings; scenery may
  overlap other scenery. Laying track or road over a building clears it.
  `Building` + `BuildingCatalog` (`scripts/build/`) follow the standing
  rule: a new kind is one catalog entry plus one `BuildingArt` painter.
  Houses vary (gable, hip or side-gable roofs, chimneys, solar panels,
  driveways with the family car, garden trees or flowers); the
  supermarket has a car park with parked cars; the factory's chimney
  smokes in Play; the farm has crops, a barn, hay bales and a tractor; the
  pond has reeds, lily pads and ducks. Shadows fall the same way as the
  trains' however a building is turned. Everything is baked into one mesh.
- The demo layout now has a small town round the railway: four roads
  (three level crossings, a crossroads, T-junctions, a cul-de-sac), about
  50 buildings and bits of nature, and 18 vehicles of different types.
- Saved state gains `roads`, `vehicles` and `buildings`; older saves load
  with none.

Verified headless: the demo builds 9 road pieces with 4 junctions and 3
crossings; 90 s of Play keeps traffic moving (no permanent jams after the
merge-deadlock fix) with trains at their usual 105 / 80 px/s; road
crossroads/T-junctions, building placement and refusal, vehicle placement,
erase, undo and a JSON save/load round trip. Screenshots were checked
under xvfb (`tools/_shot_town.gd`). Not checked on a phone.

## Bridges, tunnels and crossing tracks

Brief (verbatim): "And tunnels and bridges and train crossings. Remember
to add new sounds to fit".

- **Track crossing track** now makes a proper crossing
  (`TrackCrossing`, found by `TrackNetwork.crossings` between pieces and
  `self_crossings` for a figure of eight drawn in one go; crossings within
  30 px of a switch are branches, not crossings). A **diamond** is flat:
  trains clatter over it and wait for each other. `Train.plan` tells a car
  crossing its path (more than ~53° off) from one ahead on its own line,
  and waits up to 12 s for it instead of giving up and reversing after
  1.4 s.
- **Bridges.** With the Select tool, tap where two lines cross to cycle
  what's built there. Road over track: level crossing → road bridge over
  the railway → railway bridge over the road. Track over track: diamond →
  one line on a flyover → the other line on top. Each bridge has a
  `Deck` (`scripts/road/deck.gd`), which answers the two questions
  everything else asks: *which line is this on* (`line_of`, by direction
  near the crossing) and *is this up on the deck* (`carries`). Trains on
  different levels of a flyover ignore each other (`Train.line_of`); a
  bridge has no barriers and nobody waits there. Kinds are saved by
  position (`bridges` in the saved state, with the upper line's direction
  for a flyover) and kept across edits.
- **Drawing on two levels.** `TrainsView` and `VehiclesView` each come
  twice: the low one draws everything not on a deck, then `BridgesView`
  draws the decks (concrete road bridge with parapets and expansion
  joints; steel girder railway bridge with its own sleepers and rails;
  both cast a shadow on what's below), then the high views draw what's up
  on them. Levels are refreshed every frame (`Main._update_levels`).
- **Tunnels.** A **Mountain** in the Build palette may be put over track
  and roads (not over stations, buildings, fields or ponds; trees may grow
  on it). `HillsView` draws it above everything: rings of wooded slopes,
  rock and a snowy top, shifted towards the light. It adds a stone portal
  (face wall, wing walls, keystone, dark arch) wherever a track or road
  crosses its outline, so trains and cars vanish in and come out the other
  side. No smoke comes out inside a tunnel, and sounds from inside are
  muffled (-9 dB, lower pitch).
- **Demo layout.** A cross-country line runs over the top: a flyover over
  the oval on one side and a diamond on the other, a railway bridge over
  the high street, and a road bridge carrying the back road over it; a
  shuttle freight works it back and forth. A mountain covers the top of
  the oval, with a tunnel through it.

Verified headless: 180 s of Play in the demo. No two trains ever overlap
on the diamond. Trains pass over and under each other on the flyover
without stopping. No vehicle is ever on a level crossing with a train.
All three trains keep running. Tapping cycles the crossing kinds; kinds
(and which line is on top) survive a save/load round trip; a mountain can
go over track and puts it in a tunnel; a one-stroke figure of eight gets
its diamond. Screenshots of each were checked under xvfb
(`tools/_shot_series.gd`). Not heard: the container has no audio output.

## Sound

Seventeen short sound effects, made with ElevenLabs' text-to-sound model
(`eleven_text_to_sound_v2`, through the ElevenLabs MCP connector, flow
"Rail Yard sound effects"). No sound is synthesised in the game. Each clip
was decoded, cut to the one event that was wanted, trimmed of silence, given
a 3 ms fade in and a 40 ms fade out, normalised to -1 dBFS and saved as
22.05 kHz mono 16-bit WAV in `game1/rail-yard/sounds/` (248 KB in total,
+245 KB on the Web `.pck`).

| File | Prompt | Plays when |
|---|---|---|
| `whistle` | Short cheerful steam locomotive whistle, single bright toot, about one second, outdoors | a steam loco sets off: entering Play, tapped back to running, reversing after it's blocked |
| `horn` | Short diesel locomotive air horn, two-tone chord, one quick blast, outdoors | the same, for diesels |
| `chuff` | One sharp steam engine chuff, punchy burst of exhaust steam from a chimney, quick attack and fast decay | with every steam puff while moving, louder under load |
| `clack` | Single train wheel clack over a rail joint, two quick metallic clicks, isolated (first click only) | the lead and last car's bogies crossing a rail joint (every 42 px), louder and higher the faster the train goes |
| `brake` | Train brakes squealing briefly as it slows to a stop, metallic squeal ending with air brake hiss | once, when a train moving faster than 45 px/s brakes towards a stop |
| `switch` | Railway switch lever thrown, heavy metallic clunk and short steel slide, isolated | a switch is flipped |
| `couple` | Railway wagon couplers locking together, single heavy metal clank, isolated | a train is put down, or a car is coupled, uncoupled or turned |
| `track` | Toy wooden train track piece clicked into place, satisfying soft knock with a little gravel crunch (second knock only) | a drawn stroke becomes track |
| `erase` | Quick soft cartoon swoosh with a gentle pop, playful removal sound | track or a train is erased |
| `tap` | Single crisp wooden block click, short bright UI tap, close-mic | any icon button is pressed |
| `bell` | Railway level crossing warning bell, a single clear electronic ding, isolated, outdoors | every 0.55 s while a level crossing is closed |
| `beep` | Small cartoon car horn, two quick friendly beeps, beep beep, isolated, close | a vehicle is put down, or goes first at a junction standoff |

| `tunnel` | Train rushing into a tunnel, sudden whoosh of air with a hollow echoing rumble | a train's front (with its horn), or a car, goes into a tunnel |
| `bridge` | Single railway wagon rolling onto a steel girder bridge, one deep hollow metallic clang with a short resonant rumble | each car rolling onto a railway bridge or flyover |
| `diamond` | Train wheels passing over a railway diamond crossing, one quick sharp metallic clack-clack double hit | each bogie over a diamond crossing |
| `joint` | Car tyres driving over a bridge expansion joint, soft quick double thump, ba-dum | a vehicle driving onto or off a road bridge |
| `construct` | Short cheerful toy construction sound, three quick wooden hammer taps and a satisfying click | a crossing is turned into a bridge (or back) |

The last five came with bridges and tunnels, two takes each. The kept
takes: the first tunnel whoosh (cut at 1.9 s), the first bridge clang, the
clack-clack from inside the second diamond take (the first was a single
clack), one thump pair from the first joint take, and the second
construct take.

`bell` and `beep` were added with the roads (flows "level crossing bell"
and "car horn", two takes each; the first bell take and the second horn
take were kept), processed the same way, decoded with the `miniaudio`
Python package since the container has no ffmpeg.

Two of the first takes were replaced: the first `tap` came out silent
(peak 0.003), and the first `chuff` was a 2 s swelling hiss, not a single
puff.

`Sfx` (`scripts/audio/sfx.gd`, autoload) owns playback. UI sounds are
plain `AudioStreamPlayer`s. Everything on the layout goes through a pool
of 20 `AudioStreamPlayer2D`s, so it pans with its position on screen.
Their hearing range is scaled by the camera zoom so that what's on screen
is audible and what's far off screen fades out. Each sound has a minimum
gap between starts and a cap on how many copies may play at once. Two
trains produce about 20 chuffs and clacks a second, so without the caps
they would pile up; anything over a cap is dropped. At first every bogie
clacked, which was about 50 a second and sounded like a buzz, so only the
end cars' bogies clack now. Which loco has which horn, and which ones
chuff, is in `WagonCatalog` (`horn`, `chuff`), as the standing rule
requires. The menu's loudspeaker switch is saved in `settings.json` as
`sound`.

Verified: headless runs of the demo layout. Play starts the whistle and
horn, chuffs and clacks play while moving, flipping every switch sends a
train into a buffer and it squeals once and whistles when it reverses,
and train speeds are unchanged (105 / 80 px/s). The exported build runs in
headless Chromium with no console errors and shows the new menu toggle.
**Not verified by ear here**: the container has no audio output, so the
mix levels (`SOUNDS` in `sfx.gd`) were set from the clips' measured
loudness and may need adjusting on a real device.

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

Every push to `main` releases, whatever it changed. The workflow
installs Godot 4.3 with only the two `web_nothreads_*` templates (cached
between runs), exports every demo from its source, runs the postexport
patch and publishes. So a commit that only touches `game1/` source goes
out too. Before, the workflow ran only when `static/**` changed, and
source-only commits were silently not released. The export step fails
the run if the log has any `ERROR`, because a GDScript parse error still
exports with exit code 0. Keep committing the local export under
`static/` as well: it's the known-good build and what the local
headless-Chromium checks run against.

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
  low-end phone with several long trains (see the performance pass
  below: measured in SwiftShader only).
- 2D MSAA isn't supported by Godot 4.3's GLES3/WebGL renderer (it warns
  and ignores it), so edges rely on the anti-aliased outline strokes the
  painters draw rather than on MSAA.

## Performance pass (mobile was slow)

Cause: draw calls, not the simulation. In Godot 4.3's Compatibility
(WebGL) renderer every `draw_circle`, anti-aliased line and polygon is
its own draw call with its own vertex buffer. The scenery alone was
~5,000 of them, drawn every frame across the whole 5 km map (one canvas
item, so no culling). The cars were several hundred more, rebuilt from
scratch every physics tick, and the smoke up to ~1,600 circles per frame.
Headless Chromium (SwiftShader) managed **1.9 FPS** even with nothing
moving.

Fix, with no visual change:

- `scripts/render/tri_batch.gd`: `TriBatch` copies the `CanvasItem.draw_*`
  calls the painters use (circle, arc, line, polyline, polygon, rect,
  set_transform) but writes one vertex-coloured triangle list, uploaded
  as a single `ArrayMesh`. It reproduces Godot's geometry: the
  averaged-normal polyline strip and the 1.25-unit AA feather including
  end caps, both measured from the 4.3 Web renderer. Circles get enough
  segments to stay round at max zoom on a high-DPI phone. Painters now
  take an untyped `ci`, so they work on a CanvasItem or a TriBatch.
- Cars, shadows and bogies are baked once per (type, colour, seed) in
  `WagonCatalog.car_mesh` & co. `TrainsView` only places the meshes each
  frame; the couplers go into one per-frame batch.
- Scenery is baked once per item. After every track change the
  survivors are merged into 640 px chunk meshes, one layer per kind so
  trees still overlap bushes and rocks, and they keep the same stacking
  sort. Off-screen chunks are culled.
- Track: one mesh, rebuilt only when it changes. Icon buttons: one mesh each.
- Smoke: one shared soft-edged disc texture drawn as tinted quads, which
  Godot batches into one draw call. The only pixel difference anywhere:
  blob rims are smoothly anti-aliased instead of aliased (≤ 31/255 at
  alpha 0.34).
- Train physics, same arithmetic: per-car length and mass are read once
  per tick rather than in each of the 8 substeps. The look-ahead
  collision check pre-filters to cars near the look-ahead path rather
  than allocating an array per car per probe point. 2.2 → ~0.9 ms per
  tick (desktop WASM).

Result, same headless Chromium: ~80 draw calls per frame, down from
several thousand. **1.9 → 17.8 FPS** idle and 2.0 → 16.7 FPS playing.
What's left there is SwiftShader rasterising: 73% of main-thread time
sits in `getParameter`, a synchronous wait for the GPU process, and an
empty scene only reaches ~50 FPS. Before/after screenshots at fit and at
max zoom are pixel-identical apart from the per-load random wagon
colours and coal. Graphics-quality tiers were considered and not added:
the cost was overhead, not detail, so tiers would have traded visuals
for a problem that's gone.

## Android build and Google Play release

Goal: ship Rail Yard as an Android app on Google Play, built headlessly
from this same project, with no interactive editor (the same approach as
the Web export). Google's numbers below (target API level, tester
counts, page size) change often, so re-check them in Play Console.

### Status

Everything that can be done from the repo is done. What's left needs
your accounts, a phone, or a decision only you can make: see **Your
to-do list** below.

- [x] 1. Toolchain: pinned Godot 4.7.2 for Android; the build runs in
  GitHub Actions, which has the Android SDK
- [x] 2. Android export preset, launcher icons, Back button, safe area
- [x] 3. Build script + workflow for a debug APK and a signed AAB
- [x] Play listing art, listing text, privacy policy page
- [x] 4a. CI builds the debug APK (16 KB aligned, our icons)
- [ ] 4b. Tested on a real phone
- [ ] 5. Play Console: account, app, listing, policies
- [ ] 6. Internal testing, then closed test (12+ testers, 14 days)
- [ ] 7. Production release

### Why Android builds with Godot 4.7.2, not 4.3

Google Play has required **16 KB memory page support** for new apps and
updates targeting Android 15+ since November 2025. Godot 4.3's Android
libraries are 4 KB aligned (`readelf -l libgodot_android.so`: LOAD
alignment `0x1000`), so Play would reject them. 4.7.2 (the latest stable)
is 16 KB aligned (`0x4000`) and its Gradle template already targets API
36, which is what Play wants now. The CI build checks the alignment
again on every run.

The Web build stays on 4.3, since nothing is wrong with it.
`scripts/game1-android.sh` exports from a **throwaway copy** of the
project, so the 4.7 editor's import and upgrade never touch the source
tree. The game runs the same on both: headless runs of the demo layout
give identical train speeds, digit for digit, on 4.3 and 4.7.2, with no
script errors. Moving the Web build to 4.7 too would remove the split,
but it would mean re-measuring `TriBatch`'s anti-aliasing geometry
against the newer renderer. It hasn't been done.

### What's in the repo

- **`export_presets.cfg` → `[preset.1]` "Android"**: Gradle build, AAB,
  target SDK 36 (min SDK: Godot's default, 24), arm64-v8a + armeabi-v7a,
  `package/unique_name="com.bvandersen.railyard"`, `version/code=1`
  (CI overrides it), `version/name="1.0"`, immersive full screen, no
  permissions, no backup of user data (so "nothing leaves the device"
  is literally true). Keystore fields are empty: the keys come from the
  environment. "Web" is still preset 0 and now leaves `tools/` and
  `art/` out of the Web `.pck`.
- **`project.godot`**: `config/icon`, `config/quit_on_go_back=false`,
  and `import_etc2_astc=true` (the Android export refuses to run
  without it; Web doesn't use it).
- **Code** (applies to Android only, harmless elsewhere):
  - Back (`Main._notification`, `NOTIFICATION_WM_GO_BACK_REQUEST`):
    closes an open train sheet or menu first, then leaves Play, and only
    then quits.
  - Pending auto-saves are written when the app goes to the background
    (`NOTIFICATION_APPLICATION_PAUSED`), since Android may kill it there
    without warning.
  - Safe area (`UIRoot._apply_safe_area`, only with the `mobile`
    feature): the UI root is inset by
    `DisplayServer.get_display_safe_area()`, so the top strip and sheets
    stay clear of the status bar, the camera cutout and the gesture bar
    (Android 15+ always draws edge to edge).
- **Art, all rendered from the game's own painters** (no hand-made art)
  by `scripts/game1-android-art.sh`, which runs
  `game1/rail-yard/tools/store_art.gd` under Xvfb:
  - `game1/rail-yard/art/android/`: launcher icon 192 px plus the
    adaptive foreground, background and monochrome (themed icon) layers
    at 432 px. The picture is `IconArt`'s steam engine (the one on the
    +Train button) on a piece of track, over grass green, inside the
    66% safe zone. Icons render at 4× with AA off and are then scaled
    down: IconArt's AA fringe is sized for a 24 px button and blurs
    everything when blown up.
  - `game1/store/rail-yard/`: 512 px Play icon, 1024×500 feature graphic
    (the demo layout running, camera turned 90° to fill the banner), and
    three 1080×1920 phone screenshots (design, train sheet, play).
  - `game1/store/rail-yard/listing.md`: title, short and full
    description, and the answers for content rating, data safety, target
    audience and ads.
- **Privacy policy**: `static/game1/rail-yard/privacy.html` (nothing
  collected, saves stay on the device, fine for children). The Pages
  workflow publishes it with the game, at
  `https://bvandersen.github.io/playground/game1/rail-yard/privacy.html`.
- **`scripts/game1-android.sh aab|apk`**: downloads Godot 4.7.2 and its
  templates into `~/.cache` if needed, points its editor settings at
  `$JAVA_HOME` / `$ANDROID_HOME`, copies the project to
  `build/game1-android/` (gitignored), applies `$VERSION_CODE`, installs
  the Gradle build template into the copy
  (`--install-android-build-template`) and exports. `aab` is the signed
  release for Play and needs `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
  `_USER` and `_PASSWORD`. `apk` is a debug build to sideload (Godot
  makes its own debug key).
- **`.github/workflows/game1-android.yml`** (run by hand from the Actions
  tab, choosing `apk` or `aab`): runs the script on GitHub's Ubuntu
  runner (JDK 17 plus the preinstalled Android SDK), checks the 16 KB
  alignment of the arm64 libraries in the output, and uploads the file
  as a workflow artifact. The version code is the workflow's run number,
  so it always goes up (`VERSION_CODE_BASE` in the workflow can jump it
  if ever needed). For `aab` it reads the upload key from three repo
  secrets (see the to-do list).

Verified here: the Android export gets through the preset, icons and
ETC2 checks and stops only at the missing Android SDK. (This container
can't reach `dl.google.com`, which is why the build runs in CI.) The Web
build was re-exported with 4.3 and still boots in headless Chromium with
no errors. The Back and pause handling were exercised headless on both
4.3 and 4.7.2. The CI workflow has built the debug APK end to end (run 2, 25 Sep
2026): Gradle build, our launcher icons, arm64 libraries at `0x4000` (16
KB). Run 1 exposed a bug, now fixed: the script's copy step dropped
`art/android/`, so that build had Godot's default icon. The script now
fails if an icon is missing. **Not verified**: the signed `aab` path
(needs your upload key) and anything on a real device, including the
safe-area insets.

### Your to-do list

In order. Steps 1–3 need no Google account.

1. **Confirm the package name** before anything is uploaded:
   `com.bvandersen.railyard` in `game1/rail-yard/export_presets.cfg`. It
   can **never** change after the first upload to Play. Change it now if
   you'd rather have something else.
2. **Install the debug build**: a finished one is already there:
   GitHub → Actions → "game1 Android build" → run #2 → artifact
   `rail-yard-apk-2` (or start a new run with `apk`). Unzip it and
   `adb install rail-yard.apk`, or copy it to the phone and open it,
   allowing installs from unknown sources.
3. **Test on a real phone** (the game's first real touch test): drawing
   track, the Smooth brush, pinch-zoom, dragging trains, the train
   sheet, Play, flipping switches, Back (closes the sheet, then leaves
   Play, then quits), save/load, and auto-save surviving the app being
   swiped away. Check the top strip isn't under the camera cutout or
   status bar, and that frame rate holds with several long trains on
   the slowest phone you have.
4. **Make the upload key** on your own computer, not in a cloud session:
   ```sh
   keytool -genkeypair -v -keystore railyard-upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Back the `.jks` file and its password up somewhere safe (a password
   manager). **Never commit it.**
5. **Add three repo secrets** (Settings → Secrets and variables →
   Actions): `ANDROID_UPLOAD_KEYSTORE_BASE64` = output of
   `base64 -w0 railyard-upload.jks`, `ANDROID_UPLOAD_KEY_ALIAS` =
   `upload`, `ANDROID_UPLOAD_KEY_PASSWORD` = the password.
6. **Check the privacy policy URL loads**:
   https://bvandersen.github.io/playground/game1/rail-yard/privacy.html
   (the Pages workflow runs on this push). If Pages isn't live, run that
   workflow by hand, or tell me to host the page somewhere else.
7. **Google Play developer account**: https://play.google.com/console,
   $25 once, plus identity verification (can take a few days). A
   personal account is fine.
8. **Create the app** in Play Console: name "Rail Yard", type Game, free.
   Accept the declarations.
9. **Fill in the store listing and App content** from
   `game1/store/rail-yard/listing.md` and upload its images: the privacy
   policy URL, ads (none), content rating questionnaire, target audience
   (include children, so the Families policy applies), data safety (no
   data collected), app access. Choose "Everyone" for the rating.
10. **Build the release**: Actions → "game1 Android build" → `aab`.
    Download `rail-yard.aab` from the run's artifacts.
11. **Internal testing**: Testing → Internal testing → create a release →
    upload the `.aab`. On the first upload, accept **Play App Signing**
    (Google keeps the real app key, and a lost upload key can be reset).
    Add yourself as a tester and install from the opt-in link.
12. **Closed test**: new personal accounts must run one with **at least
    12 testers opted in for 14 days in a row** before production access
    is granted. Recruit them (family and friends with Android phones) and
    start it as soon as the build works.
13. **Apply for production access** once the 14 days are done
    (Dashboard), answer the questions about the test, then promote the
    release to Production and submit. Review usually takes a few days.
14. **Every later update**: re-run the workflow with `aab` (the version
    code goes up by itself) and upload it to a track. Each August, check
    Play's target-API deadline. If Godot 4.7's API 36 falls behind, move
    to a newer Godot and bump `GODOT_VERSION` in the script and the cache
    key in the workflow.

Optional: point me at anything from step 3 that feels wrong on the
phone. If you want a different icon, `tools/store_art.gd` is where it's
drawn.

## Ideas for later

Signals/blocks instead of look-ahead braking, turntables, uncoupling
into separate cuts that can be shunted, level crossings with road
traffic, sounds (chuff/horn/clack through the same procedural approach
as game2's ToneEngine), day/night with the headlights mattering.
