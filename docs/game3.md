# game3 — Vigil (daily esoteric mini-ritual app) — plan

A standalone mobile-first demo, built the same way as game1/game2
(`docs/game1.md`, `docs/game2.md`): **Godot 4**, source under
`game3/<demo>/`, one hand-authored `project.godot`, a procedurally built
scene tree with one `Main.tscn`, no interactive editor, `.godot/` cache
gitignored. Everything those plans say about *why* it's built that way
applies here and isn't repeated.

"Vigil" is a working title (folder `game3/vigil/`); renaming later means
renaming the folder, `config/name` and the Android/iOS package ids.

**This file is the hand-off.** Each phase below is sized for one fresh
session. A new session should read *only*: this file's "Decisions",
"Architecture" and its own phase — plus the files that phase lists — not
the whole tree. Tick the status box and add a short "Done notes" line
under the phase when it lands (what changed from the plan, anything the
next phase must know). Keep those notes short: they are what the next
session pays tokens to read.

Starter prompt for a new session:

> Read docs/game3.md (Decisions, Architecture, and Phase N only) and do
> Phase N. Update its status and Done notes when finished.

## Status

- [x] Phase 0 — Scaffold, daily draw, threshold screens, first rite
- [ ] Phase 1 — Kit: synth audio, text/shader effects, Senses layer
- [ ] Phase 2 — Touch-only rites (no permissions)
- [ ] Phase 3 — Motion rites (accelerometer / gyroscope / haptics)
- [ ] Phase 4 — Microphone rites
- [ ] Phase 5 — Stones: mining, the Reliquary, crystal growing, gems
- [ ] Phase 6 — Camera and location rites (native plugins)
- [ ] Phase 7 — Enigma Scroll as a reward system, streaks, notifications
- [ ] Phase 8 — Android + iOS builds
- [ ] Phase 9 — Polish, safety, onboarding
- [ ] Phase 10 — Content at scale: recipe generator, validator, library
- [ ] Phase 11 — Paid tier: in-app purchase, entitlement, paywall moments

## Original brief (verbatim, abridged only where marked)

> Make a new demo. Godt or löve2d or whatever fits best. Going to be
> exported as an android and iPhone app later.
>
> # System Prompt: Esoteric Mini-Ritual Generator
>
> You are the central intelligence behind an enigmatic, deeply esoteric,
> and unsettlingly present mysticism app. Your sole purpose is to design
> and deliver daily "mini-ritual experiences."
>
> The goal of this app is to shatter automatic daily habits, disorient
> the mundane mind, and instantly shock the user into absolute, raw
> awareness of the present moment. The user should never know what
> awaits them when they open the app—it could be a silence, a physical
> demand, an optical trick, or a deep sensory confrontation.
>
> *[The 20 core archetypes are summarised per rite in "The rites"
> below, with every quoted line kept word for word.]*
>
> 21. Gemstone manifestation. Making shiny gemstones by combining
>     different materials and forces.
> 22. Crystal growing
> 23. Spiritual stone mining. See which random stone you find and make it
>     shine and what message does it give? Does it boat well or evil?
>
> Game features an Enigma scroll or what it's called which purpose might
> later be revealed and it's for opening a specific mini ritual. Eg for
> debugging but later it might be opened as a reward for leveling up. To
> begin with only one ritual per day and it's random so you can't decide
> a specific one to play without knowing a code that you won't for the
> first long while. It's to get people addicted to go back every day to
> see what's there and the excitement and the app might be used as a
> daily morning or evening ritual for divination or meditation or
> pondering etc.
>
> **Tone & design directives:** Atmosphere: deeply mystical, uncanny,
> minimalist, atmospheric, and unhurried. Tone of voice: cryptic yet
> direct, authoritative, grounded, poetic, and non-judgmental. Avoid
> cheesy "new age" tropes or overly friendly language. UX strategy:
> utilize all hardware capabilities—gyroscope, haptics, front camera,
> microphone, screen brightness, touch speed, and location services—to
> blur the line between the device and physical reality. Output
> standard per ritual: 1. Visual & Auditory Setup (first 5 seconds),
> 2. Hardware & Sensory Mechanics, 3. The Awakening Payoff.
>
> Plan it out now in phases so each phase can be picked up in a new
> session to make it token and feature optimized

## Decisions

### Engine: Godot 4.7.2 (not LÖVE, not 4.3)

- **LÖVE** has no camera API, no official iOS store pipeline, and mic,
  haptics and permissions would all be hand-written native code.
  **Godot** has, built in: accelerometer / gyroscope / gravity /
  magnetometer (`Input.get_*`), `Input.vibrate_handheld(ms, amplitude)`,
  microphone input (`AudioStreamMicrophone` + `AudioEffectCapture` /
  `AudioEffectRecord`), `CameraServer` / `CameraTexture`, runtime
  permission requests on Android (`OS.request_permissions`), and
  first-party Android and iOS export. The repo already has a working
  Godot Android pipeline (`scripts/game1-android.sh`, game1-android.yml).
- **4.7.2, not the 4.3 the Web demos use**: Play needs 16 KB aligned
  libraries (see docs/game1.md) and `CameraServer` only gained Android
  support in 4.5-era releases. The project therefore declares 4.7 in
  `config/features` and is *not* part of the 4.3 Pages export loop.
  **Verify in Phase 0** that 4.7.2's camera feed on Android works headed
  for the front camera (if not, Phase 6 uses a plugin instead).
- Renderer: `gl_compatibility` (same as game1; widest phone coverage).
- Portrait, `canvas_items` stretch, base viewport 480×800 like game1.

### What hardware Godot can't reach without a plugin

Stated here so nobody rediscovers it:

| Need | Built-in? | Plan |
|---|---|---|
| Accelerometer, gyro, gravity, magnetometer | yes | Phase 3 |
| Haptics (duration + amplitude) | yes (`vibrate_handheld`); patterns are sequences of calls | Phase 1 |
| Microphone level / record / playback | yes; needs `audio/driver/enable_input=true` + permission | Phase 4 |
| Front camera frames | yes (`CameraServer`), verify per platform | Phase 6 |
| GPS / altitude | **no** | Phase 6: small Android plugin (v2) + iOS GDExtension; fallback text without coordinates |
| Screen brightness | **no** | Phase 6 plugin (same one), optional |
| Local notifications ("the rite is waiting") | **no** | Phase 7 plugin, optional |
| Heart rate | **no sensor exists on phones** | #2 fakes the "sync": pulses ease toward a resting ~62 bpm; optional stretch: camera-flash fingertip PPG |
| Eye tracking | **no** | #8 uses the fingertip as the gaze |
| Speech-to-text | **no** | #12 accepts typed words; speech is a later plugin |
| Step counting | no API, but accelerometer peak detection is enough for 10 steps | Phase 3 |

### Desktop / Web fallbacks

Every sensor goes through one `Senses` autoload (Phase 1) that, when no
real sensor is present, maps: mouse drag with right button → tilt,
arrow keys → shake / steps, `Space` held → mic loudness, `H` → haptic
logged on screen. This keeps every rite testable on a laptop and in a
headless run. A Web export (4.7.2, nothreads) is a dev convenience only;
it is **not** added to the Pages workflow until someone asks.

### The daily draw

- One rite per **ritual day**. The day rolls over at **04:00 local
  time**, so an evening rite after midnight still belongs to "tonight".
- `seed = hash(ritual_day_string + install_salt)`; `install_salt` is a
  random 64-bit value created on first launch and saved. Same install,
  same day → same rite no matter how often the app is reopened; two
  phones differ.
- Candidates = recipes this device can perform (sensor + permission
  check, `requires`) and the user is entitled to (`tier`), minus every
  recipe already seen (until the pool is exhausted) and minus any recipe
  whose **engine** ran in the last 3 days. Weighted pick (`weight`,
  default 1). No reroll, no preview of the name.
- The first 7 days are not random: a curated opening sequence of the
  strongest free rites, one per sense (breath, touch, sound, motion, …),
  so the first week is the hook. Random draw from day 8.
- After completion (or abandonment past the payoff point) the day is
  **sealed**; reopening shows only the sealed screen until 04:00.
- Clock tampering is ignored for the demo (note for later: store the
  last-seen timestamp and refuse to go backwards).

### The Enigma Scroll

A hidden surface, not a menu item. Found by **pressing and holding the
home sigil for 7 seconds** (nothing hints at it). It unrolls into a ring
of 12 glyphs; a code is a sequence of 4 glyphs. Codes:

- `dev` codes (Phase 0): one per rite, opens that rite without sealing
  the day. Listed in `scripts/core/scroll_codes.gd` only — never shown
  in UI. The file comment says so.
- Later (Phase 7): codes are *earned* — fragments revealed by streaks /
  depth, and a rite opened by an earned code is a "second rite" that
  doesn't count toward the day. Wrong codes do nothing and say nothing.

### Free and paid: rites are data (engines × recipes)

(Added after the plan was first written, from the user's follow-up:
"get people hooked with free version with some rituals and then add
hundreds or thousands of mini rituals to paid version".)

Thousands of rites can't be thousands of hand-written scripts. So a rite
is split in two:

- **Engine** — code, one per mechanic. The 23 archetypes are the first
  23 engines; new engines are added rarely (target ~40). Each exposes
  many knobs: timings, shapes, palette, audio voice, thresholds, which
  sensor gates it, copy slots. An engine may also be **chained** with one
  other ("compound rite": e.g. stillness → glyph, match → oracle), which
  multiplies variety without new code.
- **Recipe** — data, one JSON object (~1–3 KB): `id`, `engine` (or
  `chain`), `params`, `lines`, `title`, `tier` (`free` | `deep`),
  `tags` (dawn, dusk, body, sound, …), `requires`, `weight`, `reviewed`.
  What the user experiences as "a rite" is one recipe. 2,000 recipes are
  ~5 MB and ship inside the app — no server.

Variety has to be real, not reskins: a recipe must change what the user
*does* or *feels* (rhythm, duration, sense, payoff line), not just its
colour. The draw's 3-day engine cooldown backs this up.

**Authoring at scale** (Phase 10): the brief's system prompt becomes the
generator prompt. An offline, dev-only tool asks the Claude API for
recipes against each engine's JSON schema; a validator checks schema,
tone rules (banned-word list, line length), requirements, and runs each
recipe headless for a smoke test; a human curates in an in-app library
viewer and sets `reviewed: true`. Only reviewed recipes ship. Nothing is
generated on the phone at runtime (privacy, cost, and tone control).

**Tiers:**

- **Free**: the 23 canonical recipes (the brief's own versions) plus
  ~20 more — enough that a free user rarely meets a repeat in the first
  month. One rite per day, exactly as described above.
- **Paid** (in-world name "the Deep Rites", placeholder): the whole
  library, growing with every app update. *Still one rite per day* —
  the scarcity is the hook. Paid adds: the Enigma Scroll's earned codes
  beyond the first, and the full Reliquary (stones, crystals, gems).
- **Idea, undecided — an extra rite a day.** A second daily rite could
  be a paid perk (e.g. an evening slot, dusk to 04:00) *or* a separate
  in-app purchase / add-on bought on top. Not planned into any phase;
  nothing is built for it until the user decides. If it goes ahead,
  `Daily` needs a second slot per ritual day and `Entitlement` a second
  product — both small, so no groundwork is needed now.
- **Model (recommendation, user to confirm before Phase 11)**:
  subscription, monthly + yearly, with a one-off lifetime option; a
  7-day trial offered only after day ~10, once the habit exists.
  Ongoing new recipes are what justify a subscription.
- **Paywall moments are in-world but honest.** On some days a free user
  is shown that a deep rite was drawn ("A deeper rite was drawn for you
  today. It is sealed.") and then gets their free rite anyway — never a
  blocked day. The purchase sheet itself is plain: price, period,
  renewal terms, restore, cancel — Apple and Google both require it, and
  dark patterns get apps rejected.
- Entitlement is checked on-device against the store (Play Billing /
  StoreKit); no own backend in v1; piracy is accepted. Downloadable
  recipe packs (content without an app update) would need hosting and
  network code — deferred, not planned.

### Tone rules for all copy

Second person, present tense, short sentences, no exclamation marks, no
emoji, no "journey / energy / vibes / manifest your best self", no
praise ("Great job"), no apology. Silence is allowed; not every screen
needs text. All copy lives in data files (`data/lines/*.tres` or `.json`)
so it can be rewritten without touching code — never inline in scripts.

## Architecture

```
game3/vigil/
  project.godot          hand-authored, 4.7, portrait, autoloads below
  export_presets.cfg     Web (dev), Android (Phase 8), iOS (Phase 8)
  Main.tscn              one node, Main.gd builds everything
  scripts/
    main.gd              screen router: Threshold → Rite → Seal; Scroll overlay
    core/
      ritual.gd          class_name Ritual (base, see contract)
      registry.gd        autoload Registry: loads recipe packs, engine id → script
      entitlement.gd     autoload: free | deep (Phase 11; returns free until then)
      daily.gd           autoload Daily: ritual day, seed, draw, seal
      save.gd            autoload Save: user://vigil.json, versioned
      scroll_codes.gd    code → rite id table
      lines.gd           autoload Lines: data/lines/<pool>.json, pick(pool, key, seed)
    kit/                 Phase 1 — shared by all rites
      senses.gd          autoload Senses: sensors + fallbacks + permissions
      synth.gd           autoload Synth: sine, noise, drones, one-shots
      haptics.gd         pulse patterns on top of vibrate_handheld
      words.gd           Label effects: fade-in, typewriter, burn, embers
      fx/*.gdshader      noise, dissolve, negative/thermal, fog, afterimage
    screens/
      home_sigil.gd      class_name HomeSigil: breathing sigil, tap + hidden 7 s hold
      threshold.gd       home: the sigil, one line, tap to begin
      seal.gd            after a rite: closing line, "return" hint
      scroll.gd          the Enigma Scroll
      reliquary.gd       Phase 5: stones and crystals kept
    engines/
      e01_unblinking_eye.gd … e23_stone_mining.gd  (one file per engine)
  data/
    rites/               recipe packs: free_core.json, deep_001.json, …
    schema/              recipe.schema.json + one params schema per engine
    lines/               shared copy pools (JSON), keyed by engine + moment
    stones.json          Phase 5
  fonts/                 one serif (OFL), one mono; nothing else
  tools/                 headless test runners (not exported)
```

### Engine contract (`scripts/core/ritual.gd`)

```gdscript
class_name Ritual extends Node2D       # base of every engine
const ENGINE_ID := ""                  # e.g. "breath_sigil"
static func defaults() -> Dictionary: return {}   # every knob + default
signal finished(outcome: String)       # "done" | "left"
func setup(recipe: Dictionary) -> void: pass      # params merged over defaults
func begin() -> void: pass             # called once, after fade-in
func payoff_reached() -> bool: return false  # past this, leaving still seals
```

A recipe (in `data/rites/*.json`):

```json
{"id": "free.breath.003", "engine": "breath_sigil", "tier": "free",
 "title": "The Sigil of Breath", "requires": [], "weight": 1,
 "tags": ["breath", "dawn"], "reviewed": true,
 "params": {"shape": "heptagram", "rhythm": [3, 7, 2, 5], "cycles": 6},
 "lines": {"payoff": null}}
```

Engines never touch `Save`, `Daily`, `Entitlement` or screens directly;
they get `Senses`, `Synth`, `Haptics`, `Words` and the recipe (its
`lines`, falling back to `Lines.pick(engine_id, key)`) only. That keeps
each engine one self-contained file a session can write without reading
the others. Every engine ships with its canonical recipe (the brief's
version, `tier: free`) plus at least 2 variant recipes that prove its
knobs actually change the experience.

Every rite plan below follows the brief's output standard:
**Setup** (first 5 s), **Mechanics** (sensors + action), **Payoff**.

### Testing without a phone

`tools/run_rite.gd`: `godot --headless --path game3/vigil -s
tools/run_rite.gd -- free.breath.001 --fake "tilt=0,0;still=1"`
instances one recipe's engine with scripted fake senses, steps it for N
seconds, and prints its `finished` outcome — used to smoke-test every
recipe. Parse check for the
whole project: `godot --headless --editor --quit --path game3/vigil`
and fail on any `ERROR` line (same trick as game2-pages.yml). Visual
check: Web export + headless Chromium screenshot (as game1 did).

---

## Phase 0 — Scaffold, daily draw, threshold screens, first rite

Goal: open the app, see the threshold, get today's rite (always a
breath-sigil recipe until more exist), perform it, see the seal; reopen → still sealed.

1. `game3/vigil/` with `project.godot` (4.7, portrait 480×800,
   compatibility renderer, near-black clear colour `#07070a`,
   `quit_on_go_back=false`), `Main.tscn`, `.gitignore` entry
   `game3/*/.godot/`.
2. Autoloads `Save`, `Daily`, `Registry`, `Entitlement` (stub: always
   `free`); `Ritual` base class; `data/schema/recipe.schema.json`;
   recipe-pack loader; `scroll_codes.gd` (dev codes map to recipe ids).
3. `threshold.gd`: a slowly breathing sigil (drawn with `draw_*`, not a
   texture), one line from `data/lines/threshold.json` chosen by
   time-of-day (dawn / day / dusk / night). Tap → fade to black 1.5 s →
   rite. Sealed day → `seal.gd` directly.
4. `seal.gd`: closing line, the sigil dimmed, nothing to press.
5. **r17 The Sigil of Breath** as engine `breath_sigil` + 3 recipes
   (canonical free, one free variant, one `deep` variant that the draw
   must skip while entitlement is free) — proves the engine/recipe split
   and the tier filter from day one.
6. Minimal Enigma Scroll: 7 s hold on the sigil, 12-glyph ring, enter 4,
   dev code opens that rite unsealed.
7. `tools/run_rite.gd` + a `tools/check.sh` that runs the parse check.
8. Web preset only. Install Godot 4.7.2 locally in the session
   (`scripts/game1-android.sh` shows the download URL pattern) and
   confirm headless boot with zero `ERROR`.
9. Quick spike (≤ 20 min, write result into Done notes): does
   `CameraServer` list a feed on 4.7.2 Android? Only if a device/emulator
   is reachable; otherwise note "unverified" and move on.

Done when: headless boot clean; `run_rite free.breath.001` prints
`done`; a draw over 30 simulated days never returns the deep recipe; a
screenshot of threshold and seal exists in the Done notes' commit.

## Phase 1 — Kit: synth audio, text/shader effects, Senses layer

Nothing new for the user; everything later rites need. No rite files
beyond updating r17 to use the kit.

- `Synth`: `AudioStreamGenerator`-based voices — `sine(hz, gain)`,
  `noise(color)` (white / pink / brown), `drone(root_hz)` (two detuned
  sines + slow LFO), `chime()`, `whisper_bed()` (band-passed noise).
  Fades on everything (no clicks). One `Master` → `Room` bus with a
  reverb for "space".
- `Haptics`: `pulse(ms, amp)`, `pattern([[ms, amp, gap], …])`,
  `heartbeat(bpm)` (lub-dub = two pulses 120 ms apart), `scratch()`
  (irregular 8–25 ms bursts). No-op + on-screen log off-device.
- `Words`: `fade_in(label, s)`, `typewriter(label, cps)`, `burn(label,
  from_char)` (per-character alpha via `RichTextLabel` visible ratio or a
  shader), `embers(text, pos)` (glyph particles drifting up and dying).
- Shaders: `noise.gdshader` (animated film grain / static),
  `dissolve.gdshader` (noise-threshold dissolve with glowing edge),
  `negative.gdshader` (invert + thermal ramp), `fog.gdshader`
  (condensation mask painted by a `SubViewport`), `vignette.gdshader`.
- `Senses`: `available(cap)`, `request(cap) -> bool` (awaits Android
  permission result; iOS asks on first use), `tilt()`, `rotation_rate()`,
  `stillness()` (0..1 from gyro + accel variance over 0.5 s),
  `mic_level()` (RMS dB from `AudioEffectCapture`), `touch_speed()`, and
  the desktop fallbacks from Decisions. A debug overlay (3-finger tap or
  `F1`) shows all live values.
- Global: every screen gets the grain + vignette overlay at low opacity
  (the "atmosphere" is mostly this and silence).

## Phase 2 — Touch-only rites (no permissions)

Ten rites; all work on Web/desktop. Suggested order (cheap → rich):
5, 13, 12, 8, 19, 14, 7, 1, 11, 15. (17 is done.) Split across two
sessions if needed: 2a = 5, 13, 12, 8, 19 · 2b = 14, 7, 1, 11, 15.

## Phase 3 — Motion rites

20, 16, 9, 2, plus the tilt-reset part of 1. Add `Senses.steps()` (peak
detection on accel magnitude with a 0.35 s refractory period) and
`Senses.orientation_class()` (flat / upright / face-down / against-chest
≈ upright + still + dark screen). Tune thresholds only on a real phone;
until then fallbacks drive them.

## Phase 4 — Microphone rites

Enable `audio/driver/enable_input`. Permission flow: ask *inside* the
rite, at the moment it's needed, with one line of copy ("It needs to
hear the room."). Refused → the rite shows a short silent alternative
ending and still seals (never nag). Rites: 3, 6, 10, and
11's breath-hold check (mic silence = holding).

## Phase 5 — Stones: mining, the Reliquary, crystals, gems

The only rites that leave something behind — the long-term "come back"
loop. Split into sessions:

- **5a — r23 Stone Mining + Reliquary + `data/stones.json`.**
  ~40 stones, each: name, colour ramp, rarity (common 60 / uncommon 28 /
  rare 10 / unnamed 2 %), **temper** (luminous / shadowed / ambivalent —
  the brief's "does it bode well or evil", phrased without good/evil
  words), and 3 lines (found / polished / its message). Stones are drawn
  procedurally (noise-displaced polygon + facets + shader), seeded, so
  every find is visually unique. The Reliquary is a dark shelf reached
  from the seal screen, read-only.
- **5b — r22 Crystal Growing.** Plant a seed crystal; it grows only in
  real time across *future* days (each daily open adds growth whether or
  not today's rite is the crystal); tended by a short touch/stillness act
  when it *is* drawn. Growth = deterministic L-system-ish facets from
  seed + days tended. Shape and colour depend on what the user did on
  those days (still → clear, restless → clouded). Lives in the Reliquary.
- **5c — r21 Gem Manifestation.** Combine 2 materials (from stones owned
  or three base ones: ash, salt, iron) with a force applied physically
  (pressure = long press, heat = fast rubbing, time = stillness,
  resonance = hum into mic if permitted). Material × force table in
  `data/gems.json` yields a cut gem with a line. Keeps it a *rite*: one
  combination per draw, no crafting menu.

## Phase 6 — Camera and location rites (native plugins)

- r04 Inverse Camera via `CameraServer` + `negative.gdshader` (if the
  Phase 0 spike failed on Android, a tiny camera plugin instead).
- Android plugin (v2, Kotlin, `game3/vigil/android/plugins/ritual_os/`)
  exposing `location()` (lat, lon, alt, accuracy — one fix, coarse is
  fine) and `set_brightness(0..1)` for the activity window. iOS
  counterpart as a GDExtension/plugin — only in Phase 8 if an Apple
  build machine exists; until then iOS uses the no-location fallback.
- r18 Name of the Hour; brightness used by r13 (dim → max for the stare,
  then minimum for the afterimage) and r02 (black at minimum).

## Phase 7 — Enigma Scroll as a reward, depth, streaks, notifications

- **Depth** (not "level"): +1 per sealed day, streak bonus. Depth 7, 21,
  49, 108 each reveal one scroll fragment = one earned code (shown once,
  as glyphs, then gone — the user must remember or write it down; the
  scroll never lists codes).
- Earned code opens a specific rite as a second rite of the day; each
  earned code works once per ritual day. Free users get the depth-7
  fragment as a taste; later fragments need the paid tier.
- Missed days break the streak silently; nothing punitive is shown.
- Optional local notification at a user-chosen hour ("It is waiting.").
  Needs a notification plugin on both platforms — skip if Phase 6 didn't
  set up plugin plumbing.
- Leave room for the scroll's "purpose later revealed": at depth 108 the
  scroll shows a thirteenth glyph. What it does is undecided — ask.

## Phase 8 — Android + iOS builds

- Generalise `scripts/game1-android.sh` → `scripts/godot-android.sh
  <game>/<demo> <package>` (or copy to `scripts/game3-android.sh` if
  generalising would touch game1's working pipeline — prefer the copy).
  Workflow `game3-android.yml` mirroring game1-android.yml. Package
  `com.bvandersen.vigil`. Permissions: `RECORD_AUDIO`, `CAMERA`,
  `ACCESS_COARSE_LOCATION`, `VIBRATE`.
- iOS: Godot exports an Xcode project; building/signing needs macOS +
  an Apple Developer account. Add a `macos-latest` workflow that exports
  and builds an unsigned archive; signing/TestFlight need secrets from
  the user (list them, like game1's to-do list). Info.plist strings:
  `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`,
  `NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription`, all
  in the app's voice but plainly honest about the purpose.
- Privacy: nothing leaves the device (no network code of our own; from
  Phase 11 the store's billing library talks to Google/Apple); camera
  and mic data are never stored beyond the rite (#3's 3-second clip lives
  in memory only). Store listing + privacy page like game1's.

## Phase 9 — Polish, safety, onboarding

- **Photosensitivity**: first-launch notice; r05 and r13 flash/strobe
  under 3 Hz and no saturated red flashes (WCAG 2.3.1). A "gentle" toggle
  in the scroll that also drops sudden haptics and loud onsets.
- **Physical safety**: r09 (walking with eyes on the screen) and r16
  (eyes closed) get a one-line safety cue; r11 breath-hold is capped at
  20 s and never demands more.
- Onboarding = one screen, three lines, no tutorial. Audio mix pass,
  haptic tuning on a real device, reduced-motion respects OS setting
  where Godot exposes it, localisation hooks (all copy already in data).

## Phase 10 — Content at scale: recipe generator, validator, library

Needs Phases 0–1 and several engines done (it's pointless before ~10
engines exist). Can run in parallel with Phases 5–9 after that.

- `tools/recipes/` (Node or Python, dev-only, never exported): `gen`
  sends the brief's system prompt + tone rules + one engine's params
  schema + 3 reviewed examples to the Claude API and asks for N new
  recipes as JSON; `validate` checks schema, banned words, line lengths,
  duplicate/near-duplicate params, and runs each headless via
  `run_rite`; output goes to `data/rites/_inbox/`. API key from an env
  var, never committed.
- In-app **library viewer** (dev build only, opened by a dev scroll
  code): flip through inbox recipes, play any, mark keep/reject, which
  writes `reviewed` and moves it into a pack.
- Target for the first paid launch: ~300 reviewed deep recipes over the
  engines that exist, plus ~20 compound chains. "Thousands" comes from
  later packs in app updates.
- Coverage report: recipes per engine, per tag, per sensor, so the
  library doesn't drift toward whatever engine generates easiest.

## Phase 11 — Paid tier: in-app purchase, entitlement, paywall moments

Needs Phase 8 (real store builds). Confirm the pricing model first
(Open questions).

- Android: Godot's official Google Play Billing plugin
  (`godot-sdk-integrations/godot-google-play-billing`); iOS: a StoreKit
  plugin (check which one is maintained for Godot 4.7 at the time —
  `godot-ios-plugins`' in-app store or a StoreKit 2 GDExtension).
  Wrap both behind `Entitlement` so nothing else knows which store.
- Products: `deep_monthly`, `deep_yearly` (subscriptions, one group),
  `deep_lifetime` (non-consumable). Restore purchases in the scroll.
- `Entitlement`: cache last known state in `Save` so it works offline;
  re-check on launch; grace period on lapse (deep rites already in the
  Reliquary stay).
- Paywall moments as described under "Free and paid"; the offer screen
  appears only after day 10 and at most once a week, never mid-rite.
- Store listing: free app with in-app purchases; privacy labels updated
  for purchase data handled by the store.

---

## The rites

Each entry is one **engine** and its canonical free recipe (the brief's
version). Id, source archetype, requirements, phase. Quoted lines are
the brief's own and are used verbatim. Additional copy goes in
`data/lines/`; the obvious knobs for variant recipes are the timings,
shapes, sounds and payoff lines named in each entry.

### r01 The Unblinking Eye — `touch` (+`gyro` in Phase 3) — P2
- **Setup:** black; a single iris fades in, pupil dilating slowly; a
  low drone; no timer is shown but a faint ring fills around the eye.
- **Mechanics:** finger must stay on the glass; the iris tracks it. Lift
  → clock resets, the eye blinks once. Phase 3: tilt beyond ~12° from
  the starting pose also resets. Duration 40–70 s (seeded).
- **Payoff:** the eye cracks into Voronoi shards that drift apart
  (dissolve shader); one line appears — "an unvarnished truth about the
  user's current stance in life", drawn from a pool of ~60 in
  `lines/r01.json`, seeded by the day.
- Iris: procedural (radial noise fibres + limbal ring + specular), not a
  photo.

### r02 The Phantom Haptic — `haptics`, `accel` — P3
- **Setup:** pitch-black, total silence, nothing on screen for 4 s.
- **Mechanics:** erratic biological haptics begin (`Haptics.scratch()`
  mixed with irregular pulses). One line after 6 s: "Hold it against
  your chest." Detected as upright + still for 3 s (orientation class).
- **Payoff:** pulses slide from ~110 bpm toward ~62 bpm over 60 s and
  settle; screen stays black; after 20 s of steady beat, it stops. No
  claim is made that it reads the heart (see Decisions).

### r03 The Echo Chamber — `mic` — P4
- **Setup:** grey static at low level for 2 s, then silence; a thin
  red recording dot.
- **Mechanics:** records 3 s of ambient room noise (`AudioEffectRecord`),
  plays it back looped at `pitch_scale` 0.35–0.5 through reverb + low
  pass: a subterranean hum.
- **Payoff:** "This is the sound of the room you are choosing to inhabit
  right now." Loop fades out over 20 s; clip discarded.

### r04 The Inverse Camera — `camera` — P6
- **Setup:** black; a faint heat-shimmer; then the front camera fades in
  through `negative.gdshader` (thermal ramp: indigo → violet → bone).
- **Mechanics:** front camera only; nothing recorded. Face must stay in
  frame ~20 s (no face detection — just time, plus "Look." after 3 s).
- **Payoff:** "You are the ghost haunting this body." Image slowly
  loses contrast to black.

### r05 The Glyph of the Moment — `touch` — P2
- **Setup:** black with grain; "Look." then a sharp tone.
- **Mechanics:** a unique glyph, generated from `seed + OS time usec`
  (strokes on a 5×5 lattice with arcs, never an existing letter — reject
  if too simple) is shown exactly 3 s, then dissolves into static
  permanently. It is never saved; there is no way back.
- **Payoff:** "You are the only consciousness in human history to ever
  see that shape. Keep the secret."

### r06 The Tonal Tether — `mic` optional — P4
- **Setup:** a continuous, sharp 432 Hz sine at moderate level; one line:
  "Find the furthest sound you can hear. Then touch."
- **Mechanics:** tap to end; taps within the first 8 s are ignored
  (forces actual listening). If mic granted, the tone ducks slightly
  when the room is loud (optional nuance).
- **Payoff:** instant silence upon contact — hard cut, no fade, screen
  goes fully black for 10 s before the seal.

### r07 The Shadow Shadowing — `touch` — P2
- **Setup:** a dim floor-like gradient; a long shadow of an unseen
  object slowly creeps across the display.
- **Mechanics:** its angle is computed from the local clock and then
  deliberately rotated wrong (e.g. mirrored sun azimuth) and it moves
  *backwards*; ~90 s, no interaction beyond watching.
- **Payoff:** "If time moved backward in this room for the next three
  minutes, what is the first mistake you would undo?" — then 3 minutes
  of a slow reverse-ticking sound; leaving early is fine.

### r08 The Disappearing Sentence — `touch` — P2
- **Setup:** black; a glowing passage (3–5 lines) fades in, blurred.
- **Mechanics:** the fingertip is the gaze: text is legible only just
  ahead of the finger as it slides under the line; every word behind the
  finger burns away (`Words.burn` + embers). Lifting the finger leaves
  what's left blurred; burned words never return. Passages in
  `lines/r08.json`.
- **Payoff:** the last word burns and the screen stays empty; no
  re-reading is possible.

### r09 The Veiled Threshold — `accel` — P3
- **Setup:** a moss-covered stone door (procedural: stone noise + moss
  mask shader), a low wind bed.
- **Mechanics:** 10 real steps counted by `Senses.steps()`; each step
  sends a faint crack of light around the door edge; safety cue first.
- **Payoff:** door cracks open with light and a whisper: "Turn around.
  Look at what is behind you in the physical room." Whisper = recorded
  voice asset (Phase 9) or synthesized breathy noise under text until
  then.

### r10 The Breath-Stained Glass — `mic`, `touch` — P4
- **Setup:** cold glass: faint condensation droplets over a dark,
  blurred image; ambient cold wind.
- **Mechanics:** blowing into the mic (level spike, low-frequency heavy)
  fogs it further; the finger wipes the fog away (paint into the fog
  mask). Fog slowly returns.
- **Payoff:** a fleeting atmospheric image underneath (procedural:
  moonlit field, a window, a far lamp — seeded) visible for a few
  seconds before the fog reclaims it.

### r11 The Unlit Match — `touch` (+`mic`) — P2 (mic check P4)
- **Setup:** an unlit match on black; a faint paper rustle.
- **Mechanics:** strike = a fast swipe along the screen's edge band
  (`touch_speed()` > threshold within 40 px of the edge); slow swipes
  scrape and fail. Then "Hold your breath." — the flame burns 15–20 s;
  Phase 4: mic detects exhale and the flame gutters (not failure, just
  seen).
- **Payoff:** sudden spark-out, a single thin smoke line, total
  stillness and silence for 8 s.

### r12 The Reverse Oracle — `touch` (keyboard) — P2 (speech later)
- **Setup:** a hooded shadow (silhouette shader with slow smoke), a
  subsonic drone.
- **Mechanics:** "Give me a single word you are holding onto today that
  no longer serves you." A single-line input; only one word accepted.
  The word is never saved.
- **Payoff:** the word dissolves into glowing embers; the shadow departs
  in complete silence (drone cuts, shadow fades over 6 s).

### r13 The Memory Eraser — `touch` — P2 (brightness P6)
- **Setup:** a hyper-detailed high-contrast fractal (shader: domain-
  warped rings), a dot at its centre, "Stare at the centre."
- **Mechanics:** 20 s count shown only as the dot shrinking; finger
  must rest anywhere (lifting pauses). Pattern must stay static and
  high-contrast (the afterimage needs that), no flicker.
- **Payoff:** screen cuts to black; the burn-in halo floats in the
  user's eyes; after 12 s one faint line: "It is in you now, not in the
  glass." (proposed copy).

### r14 The Static Seance — `touch` — P2
- **Setup:** analog TV static and white noise, full screen.
- **Mechanics:** horizontal finger position = tuner frequency; 5 hidden
  stations at seeded positions; nearing one clears the static and fades
  in a 2-second fragment — shortwave numbers-station-like tones, choral
  cluster, deep-sea groan — all **synthesized** in `Synth` (no licensed
  audio). Each station plays once.
- **Payoff:** after all found (or 90 s), static collapses to a single
  bright line, then black (old-TV power-off).

### r15 The Bloodline Knot — `touch` (multitouch) — P2
- **Setup:** one glowing thread tied in a complex knot, faint hum.
- **Mechanics:** knot = a closed curve with N crossings (Bézier chain).
  Two-finger pinch/drag on a crossing loosens it (one crossing removed).
  Desktop fallback: click-and-hold a crossing. 5–7 crossings.
- **Payoff:** each undone loop reveals a reflection line; the last one:
  "A knot tied six generations ago ends with your hands today." The
  thread lies straight, then fades.

### r16 The Weight of Air — `accel` — P3
- **Setup:** a minimalist scale: one thin beam, level; "Rest it flat on
  your open palm. Close your eyes."
- **Mechanics:** 45 s of flat + hand-held (tiny natural tremor, not table
  stillness — a table reads too still; ask again). Big movement resets.
- **Payoff:** a faint chime after 45 s. Nothing else.

### r17 The Sigil of Breath — none — P0
- **Setup:** a geometric ring (heptagram inside a circle) centred on
  black; a quiet low drone.
- **Mechanics:** ring expands and contracts in asymmetric, non-human
  intervals: seeded per day from sets like Inhale 3 s, Hold 7 s, Exhale
  2 s, Hold 5 s. Only the ring moves; the phase word ("in", "hold",
  "out") appears faintly for the first two cycles, then never. 6 cycles.
- **Payoff:** the ring stops mid-expansion and stays still; the drone
  stops; after 6 s the seal.

### r18 The Name of the Hour — `location` optional — P6
- **Setup:** mono font, coordinates resolving digit by digit like a
  lock, time to the millisecond, altitude.
- **Mechanics:** one coarse location fix; no permission → coordinates
  replaced by the timezone and "somewhere".
- **Payoff:** "For the next 60 seconds, you are not at home. You are at
  Latitude [X], standing on top of 4 billion years of continental
  crust." (X = live latitude to 4 dp). 60 s count in milliseconds, then
  black. (Oceans/islands: same line — do not try to be clever.)

### r19 The Cipher of Touch — `touch` — P2
- **Setup:** a wandering pinprick of light on black, like a firefly.
- **Mechanics:** it moves along the pen path of a hidden word (a
  single-stroke script path for "Forgive", "Unclench", "Listen", … from
  `lines/r19.json`), slow; the user tracks it with a fingertip. Breaking
  contact or straying > 40 px pauses it and dims the trail.
- **Payoff:** the trail left behind spells out the single imperative;
  it glows for 5 s, then cools.

### r20 The Void's Reciprocity — `gyro` — P3
- **Setup:** "I am waiting for you to be completely still."
- **Mechanics:** `Senses.stillness()`; micro-tremors reset a 10-second
  timer (shown as nothing — only the text slowly sharpening).
- **Payoff:** absolute stillness unlocks a whispered, ambient soundscape
  (`Synth.whisper_bed()` + drone) that plays 40 s.

### r21 Gem Manifestation — `touch` (+`mic`) — P5c
See Phase 5c. **Setup:** two materials on a dark anvil-stone. **Payoff:**
the gem cuts itself facet by facet, a clear tone per facet, then its
line; kept in the Reliquary.

### r22 Crystal Growing — `touch`, `gyro` — P5b
See Phase 5b. **Setup:** first time: a seed crystal in the palm of a
drawn hand; later: *your* crystal, grown since last time. **Payoff:** one
new facet grows in front of the user.

### r23 Spiritual Stone Mining — `touch` — P5a
See Phase 5a. **Setup:** a rock face in torchlight; a pick sound on
tap. **Mechanics:** tap to chip (each tap haptic), then rub the found
stone to polish (touch speed + coverage raise its shine shader).
**Payoff:** the stone's name, its temper, and its message; kept.

---

## Open questions (ask the user when the phase comes up)

- Real name (Vigil is a placeholder) — before Phase 8.
- Whisper / voice lines: recorded voice actor, TTS (e.g. ElevenLabs,
  generated once and committed as assets), or none — before Phase 3's r09.
- What the Enigma Scroll finally reveals at depth 108 — Phase 7.
- Pricing model: subscription (monthly + yearly + lifetime, as
  recommended), one-off unlock, or both; prices; trial length. No ads —
  they would break the tone. Before Phase 11.
- The extra-rite-a-day idea (see "Free and paid"): drop it, make it
  part of paid, or sell it as its own add-on. Before Phase 11.

## Done notes

(append per phase, newest last)

**Phase 0** (screenshots in `docs/game3/`: threshold, seal, scroll, rite).
- Check everything: `GODOT=<4.7.2 binary> game3/vigil/tools/check.sh`
  (import, boot, all 3 breath recipes to `done`, 30-day draw, and
  `tools/flow_test.gd`: tap → rite → sealed → relaunch sealed, plus a dev
  scroll code runs a rite without sealing). `tools/screenshot.gd` needs a
  display: `xvfb-run -s "-screen 0 480x800x24" godot --path game3/vigil
  --rendering-driver opengl3 -s tools/screenshot.gd -- <dir>`.
- Contract changes: `Ritual` does **not** declare `ENGINE_ID` (GDScript
  forbids a subclass redeclaring it); engines do, base has `engine_id()`.
  Host seeds `rite.rng` before `setup()`; `setup()` merges params over
  `get_script().defaults()`; `line(key)` = recipe `lines` then `Lines`;
  `end(outcome)` / `leave()` emit `finished` once. `Registry.ENGINES` is
  an explicit id → preload table (add one line per engine) and
  `Registry.validate()` rejects unknown params (push_error → check fails).
- `-s` tool scripts must not type anything as `Ritual` or reference
  autoload names statically: they compile before autoloads exist. Use
  untyped vars and `root.get_node("Registry")` after one `process_frame`.
- `Save` honours `VIGIL_SAVE` (tests). Draw: pure `Daily.draw(day, salt,
  history, pool, opening)`; `opening.json` has only `free.breath.001` so
  far — extend it as engines land. With one engine the 3-day cooldown
  falls back to "any unseen".
- Dev codes: `0-6-3-9`, `0-6-3-10`, `0-6-3-11` (glyph indices clockwise
  from the top) — see `scroll_codes.gd`.
- Not done / for Phase 1: the drone (needs `Synth`), fonts (the default
  font is used; no OFL serif added yet), grain/vignette. Web preset exists
  but was not exported (no 4.7.2 Web templates downloaded). Camera spike:
  **unverified** (no device or emulator reachable).
