# Hosting the Godot Web demos — plan

Where the Web exports of game1/game2 (and later any other Godot demo)
are served from, why, and what's planned. The background is in
`docs/game2.md`, "Hosting problem: Cloudflare Workers' 25 MiB asset
limit"; this doc picks up from there.

## Decision (2026-09-25)

**Stay on GitHub Pages** (`.github/workflows/game2-pages.yml`). No move
to another host. The constraints this was decided against:

- the repo stays **private**, and hosting must be **free**;
- a **separate URL** for the demos is fine (they don't have to live on
  `oraclecardoftheday.com`);
- traffic is **low** (well under 100 plays a day);
- **stock** Godot export templates (no custom, module-stripped engine
  build).

What actually needs hosting (measured on the exports under `static/`):

| File | Size | Notes |
|---|---|---|
| `index.wasm` | 35,376,909 B (~34 MiB) | Godot 4.3 Web release template. **Byte-identical in all three demos** (same SHA-256) |
| `index.js`, `index.audio.worklet.js` | 324 KB, 7 KB | also identical across demos |
| `index.pck` | 45 KB – 743 KB | the only per-demo game data |
| `index.html`, `index.png` | < 25 KB | |

The wasm is the only problem file. It compresses to about 8 MB with gzip,
but Cloudflare's 25 MiB limit counts the uncompressed size, so that doesn't
get it through. It's the engine, not our content, so it won't shrink without a custom template.

### Why Pages, and not the alternatives

| Option | Verdict |
|---|---|
| **GitHub Pages** (current) | Already works, deploys on every push to `main`. No per-file limit that matters; 1 GB site limit (we're at ~104 MB); 100 GB/month soft bandwidth ≈ 12,000 first-time plays at ~8 MB each. |
| Netlify | Works (private repos on the free plan, 100 MB per file). No gain over Pages today → it's the **standby** (Phase 2). Its free plan became credit-based in 2025; check the current bandwidth allowance before relying on it. |
| Vercel Hobby | Works technically, but Hobby is **non-commercial only**, and Rail Yard is heading to Google Play. Not used. |
| Firebase Hosting (Spark) | The 2 GB per-file limit doesn't help: the free tier caps downloads at ~360 MB/**day**, which is only about 45 fresh plays a day. Not used. |
| R2 / S3 / B2 for the wasm | Only needed if the demos must be served from `oraclecardoftheday.com`. That's Phase 3, not now. |

### Correction: repo size is *not* a problem

An earlier note assumed three committed copies of the wasm would bloat git
history by ~100 MB per Godot upgrade. They don't: git stores identical
content as **one** blob, and the whole wasm takes ~9 MB on disk in
the pack (`git count-objects -vH`: 8.9 MiB total pack). Each future
Godot version adds roughly another ~9 MB, once. Not worth changing how
exports are committed, so there's no phase for it.

## Phase 1 — one shared engine copy in the Pages site (done 2026-09-26)

**Why**: every demo ships its own copy of the same 34 MiB wasm under a
different URL, so the browser can't reuse it. A player who opens two
demos downloads the engine twice (~8 MB each over the wire). The deployed
site is ~104 MB, and about two-thirds of that is duplicate engine. It also buys
headroom on the 1 GB site limit as demos are added.

**How** (changes only in the workflow's "Assemble site" step plus a small
post-export patch; the committed `static/` exports stay as they are):

1. In `_site/`, write the engine once, per Godot version:
   `_site/engine/4.3/index.{wasm,js,audio.worklet.js}`. Assert in the
   workflow that each demo's copy has the same SHA-256 as the shared one,
   and fail the deploy if not (e.g. a demo exported with a different Godot
   version). Group by version because game3 (Vigil) is on Godot 4.7.2.
   If it ever joins Pages, it gets `engine/4.7.2/` and doesn't share with
   the 4.3 demos.
2. Delete the per-demo `index.wasm`/`index.js`/`index.audio.worklet.js`
   from each `_site/<demo>/` folder.
3. Patch each demo's `_site/.../index.html` (a new step in
   `scripts/game2-postexport.mjs`, behind a flag so plain local exports are
   unaffected):
   - `<script src="index.js">` → relative path to `engine/4.3/index.js`
     (relative, not absolute, because of the `github.io/playground/`
     project-page subpath; see `docs/game2.md`);
   - `GODOT_CONFIG.executable` `"index"` → the same relative engine base,
     and `mainPack: "index.pck"` so the pck still loads from the demo's own
     folder;
   - rename the `GODOT_CONFIG.fileSizes` key `"index.wasm"` to
     `"<engine base>.wasm"`. The loader looks up the size under
     `` `${basePath}.wasm` ``, so with the old key the loading bar has no
     total.

   The generated 4.3 `index.js` confirms the mechanism (checked
   2026-09-25): its `locateFile` resolves `.wasm` and `.audio.worklet.js`
   to `` `${loadPath}.wasm` `` / `` `${loadPath}.audio.worklet.js` ``,
   where `loadPath` is `executable`. `mainPack` is a separate setting
   that only covers the pck.
4. **Verify before shipping**: boot each demo in headless Chromium (as in
   game1's verification) and check the network log. The wasm should come
   from `engine/4.3/` and each pck from its own folder. Audio should work,
   and the second demo should get the wasm from cache.

**Done when**: `_site` is ~36 MB instead of ~104 MB, all three demo URLs
still boot, and opening a second demo doesn't re-download the wasm.

**As built** (2026-09-26):

- `share_engine()` in the workflow's "Assemble site" step moves every
  engine file (`index.wasm`, `index.js`, `index.*.js`, which also covers
  the extra `index.audio.position.worklet.js` that Godot 4.4+ exports) to
  `_site/engine/<full Godot version>/`. It fails the deploy if a later demo
  on the same version has a file that isn't byte-identical (`cmp`). The
  root copy of `ROOT_DEMO` gets the same treatment, with base
  `engine/<v>/index` instead of `../../engine/<v>/index`.
- The html patch is `node scripts/game2-postexport.mjs --shared-engine
  <index.html> <engine-base>`, a separate mode that only runs on `_site`
  and never touches `static/`.
- Verified locally on the three committed 4.3 exports, served under
  `/playground/` with Pages' `Cache-Control: max-age=600`: `_site` is
  36 MB (was ~104 MB). All four URLs (three demos plus the root) boot in
  headless Chromium. The wasm comes from `engine/4.3/`, each pck from its
  own folder, and the 2nd–4th demo get the wasm from the disk cache. After
  a click, the audio worklet loads from `engine/4.3/` and the
  AudioContext is running. game3 (4.7) isn't in `static/`, so it was first
  exercised by the CI run itself.

## Phase 2 — Netlify standby (write down now, build only if needed)

**Trigger**: GitHub Pages stops working for this private repo. The
likeliest cause is the GitHub plan lapsing, since Pages on private repos
needs a paid plan.

**Steps** (about 30 minutes; nothing else in the pipeline changes):

1. Create a Netlify site with *no* Git integration (deploys come from
   Actions), and note its site ID.
2. Add repo secrets `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID`.
3. In `game2-pages.yml`, replace the `configure-pages`,
   `upload-pages-artifact` and `deploy-pages` steps with
   `npx netlify-cli deploy --prod --dir=_site` (env: the two secrets),
   and drop the `pages`/`id-token` permissions and the
   `environment: github-pages` block.
4. Update the demo URLs in `docs/game1.md` and `docs/game2.md`.

Everything else keeps working unchanged: the Godot export, the post-export
patch and the "Assemble site" step, including Phase 1's shared
engine. Netlify's 100 MB per-file limit is well above our 34 MiB.

## Phase 3 — demos on the real domain (only if wanted later)

**Trigger**: the demos need to be served from `oraclecardoftheday.com`
(e.g. a game goes public, or the Play listing links to it).

**Approach**: that site already deploys to Cloudflare Workers
(`wrangler deploy`, `daily-deploy.yml`). Keep Workers static assets for
everything except the engine files. Put `engine/<godot-version>/index.wasm`
in an **R2** bucket and serve it through a Worker route with an R2 binding
on the same origin, so no CORS setup is needed. R2's free tier (10 GB
storage, no egress fees) easily covers one 34 MiB file per Godot
version. Upload it from CI with `wrangler r2 object put` only when its
hash changes. This builds directly on Phase 1: the demos already fetch
the engine from one shared path, so only that path's host changes.

## Numbers to watch

- **Bandwidth**: Pages' soft limit is 100 GB/month ≈ 12,000 first plays.
  If a demo takes off (Ragdoll Meme Maker is the likely one), switch to
  Phase 3 early. Its bandwidth is effectively free, and Pages/Netlify
  aren't.
- **Site size**: 1 GB on Pages. Fine after Phase 1 even with dozens of demos.
- **Godot upgrade** of the Web demos (4.3 → 4.6+): the wasm grows (4.6
  measured ~37.6 MiB, see `docs/game2.md`). Still fine on Pages, Netlify
  and R2; it only matters for Cloudflare Workers' own static assets,
  which this plan doesn't use for the engine.
