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
  `Draw`, `Smooth`, `Erase`, `+Train`, plus `Menu`.
  Every button is a picture rather than a word, so a child who can't
  read yet can use it (`IconArt` in `scripts/ui/icon_art.gd` draws them
  procedurally, `IconButton` shows one; the words stay as tooltips):
  ▶/■ play/stop, a hand (Select), a pencil (Draw), a paintbrush
  sweeping a wobbly line straight (Smooth), an eraser (Erase), a
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

## Plan: Android build and Google Play release (not started)

Goal: ship Rail Yard as an Android app on Google Play, built headlessly
from this same project (no interactive editor, as with the Web export).
Google's numbers below (target API level, tester counts) change often,
so re-check them in Play Console before relying on them.

### Status

- [ ] 1. Toolchain in the build environment
- [ ] 2. Android export preset + icons in the project
- [ ] 3. Signed AAB builds headlessly (script in `scripts/`)
- [ ] 4. Tested on a real phone (touch, pinch, save/load, frame rate)
- [ ] 5. Play Console: app created, store listing, policies
- [ ] 6. Internal testing, then closed test (12+ testers, 14 days)
- [ ] 7. Production release

### 1. Toolchain

- Godot 4.3 **Android** export templates. Only the two `web_nothreads_*`
  templates are installed so far (`~/.local/share/godot/export_templates/4.3.stable/`);
  the full `Godot_v4.3-stable_export_templates.tpz` contains the
  Android ones (`android_release.apk`, `android_debug.apk`, `android_source.zip`).
- JDK 17 (what Godot 4.3's Gradle template is built against). The cloud
  container has only Java 21 at `/usr/lib/jvm/java-21-openjdk-amd64`;
  install 17 rather than find out whether the template's Gradle copes.
- Android SDK via `cmdline-tools`: `platform-tools`, `build-tools`, and
  the `platforms;android-<target>` for the target API below. Point Godot
  at it with the editor settings `export/android/android_sdk_path` and
  `export/android/java_sdk_path` (for a headless run, write them into
  `~/.config/godot/editor_settings-4.3.tres` or pass them as env).
- Check the proxy lets Gradle reach `dl.google.com` and Maven Central;
  if not, the build has to run on a local machine.

### 2. Project changes

- Add `[preset.1]` "Android" to `export_presets.cfg` (keep "Web" as
  preset 0 so the Web command is unchanged):
  - `package/unique_name="com.<you>.railyard"`, `package/name="Rail Yard"`
  - `version/code` (an integer that goes up with **every** upload) and
    `version/name`
  - `gradle_build/use_gradle_build=true`: the Play Store only accepts
    AAB, and a custom target SDK needs a Gradle build. So also
    `gradle_build/export_format=1` (AAB) and install the build template
    (`android/build/` from `android_source.zip`; decide whether to commit
    it or unpack it in the build script, leaning towards the script)
  - `gradle_build/target_sdk`: whatever Google requires now. That was
    API 35 (Android 15) for new apps from Aug 2025 and it rises every
    August. Godot 4.3 defaults to 34, which is too low. `min_sdk` stays
    at Godot's default.
  - `architectures/arm64-v8a=true` (and `armeabi-v7a` for old phones);
    Play needs 64-bit.
  - `screen/orientation`: portrait (already `window/handheld/orientation`
    in `project.godot`)
  - No permissions needed: no internet, no storage (saves go to
    `user://`, which is app-private on Android).
- Icons, drawn procedurally to match the rest of the game (e.g. a
  script that renders `IconArt`'s steam engine on a track loop to PNG
  with `godot4 --headless`), rather than hand-made art:
  - `launcher_icons/main_192x192`
  - `launcher_icons/adaptive_foreground_432x432` and
    `adaptive_background_432x432` (keep the picture inside the central
    ~66% safe zone of the foreground)
  - Play listing: a 512×512 icon and a 1024×500 feature graphic
- Code: probably nothing. The Web-only bits (`JavaScriptBridge` in
  `ui_root.gd`) are behind `OS.has_feature("web")`, and touch/pinch uses
  the same `InputEventScreenTouch` path. Worth checking on the phone:
  the Android back button (`NOTIFICATION_WM_GO_BACK_REQUEST`: close an
  open sheet, or leave Play, before quitting the app), and the insets
  for the notch/status bar (`DisplayServer.get_display_safe_area()`)
  so the top strip isn't under the camera cutout.

### 3. Signing and build

- Upload key: `keytool -genkeypair -v -keystore railyard-upload.jks
  -alias upload -keyalg RSA -keysize 2048 -validity 10000`. **Never
  commit it.** Keep it and its password somewhere backed up, and pass
  them to Godot via env (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
  `..._USER`, `..._PASSWORD`). Enrol in Play App Signing so Google holds
  the real app key and a lost upload key can be reset.
- Build: `godot4 --headless --path game1/rail-yard --export-release
  "Android" <out>/rail-yard.aab`. Put this in a `scripts/` build script
  (unpack the build template, bump `version/code`, export), and don't
  commit the `.aab` itself (unlike the Web build, which is committed).
- Check `project.godot`'s `config/name` and add `config/icon`.

### 4. Real-phone test

The first real touch test of this game (see "Not verified" above):
drawing, the Smooth brush, pinch-zoom, dragging trains, save/load and
auto-save surviving the app being killed, and frame rate with several
long trains on a low-end phone. Sideload with `adb install` using an
APK export of the same preset, or go through Play's internal testing
track.

### 5. Play Console

- Developer account: $25 once plus ID verification.
- Create the app; store listing: title, short description (80 chars),
  full description, icon, feature graphic, 2+ phone screenshots
  (the headless Chromium screenshot setup used for the Web build works
  for these too).
- Privacy policy URL (required): the app collects nothing, so a short
  page saying so. It could live on the same GitHub Pages site.
- Content rating questionnaire (IARC); Data safety form: no data
  collected or shared.
- Target audience: the UI is built for children who can't read yet, so
  the **Families policy** applies: kid-appropriate content, no
  non-certified ads/analytics SDKs (there are none), and the privacy
  policy and listing have to reflect a child audience.

### 6–7. Testing tracks and release

- Upload to **Internal testing** first (fast, up to 100 testers).
- New personal developer accounts must run a **closed test with at
  least 12 opted-in testers for 14 days in a row** before they can apply
  for production access.
- Then promote to **Production** and submit; review usually takes a few
  days. Every later update needs a higher `version/code`.

## Ideas for later

Signals/blocks instead of look-ahead braking, turntables, uncoupling
into separate cuts that can be shunted, level crossings with road
traffic, sounds (chuff/horn/clack through the same procedural approach
as game2's ToneEngine), day/night with the headlights mattering.
