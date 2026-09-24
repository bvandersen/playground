# playground — Project Instructions

This repo holds many small, unrelated playground projects (demos,
experiments). They must stay **self-contained**: nothing from one project
may leak into, depend on, or break another.

## Layout

```
projects/<name>/        one folder per project — everything it owns lives here
  README.md             required: "# Title", then a one-paragraph summary
  web/                  what gets published (must contain index.html)
  ...                   anything else the project needs (source, scripts, docs, assets)
scripts/build-pages.mjs builds the GitHub Pages site into _site/
.github/workflows/pages.yml  runs that on every push to main and deploys it
```

The published site is https://bvandersen.github.io/playground/ — an
index of every project, each served at `/<name>/`.

## Rules for every project

1. **One folder.** A project's source, build output, scripts, docs, and
   assets all live under `projects/<name>/`. Never add project files at
   the repo root, in a shared `docs/` or `scripts/`, or in another
   project's folder.
2. **No cross-project references.** Never import, link to, or copy at
   build time from another project's folder. If two projects need the same
   thing, each keeps its own copy.
3. **Relative paths only inside `web/`.** Each project is served from
   `/playground/<name>/`, so absolute paths (`/foo.js`) break. Use
   `./foo.js` or `foo.js`.
4. **`web/` is committed and published as-is.** CI never runs a
   project's own build tooling (Godot, bundlers, etc.) — build locally,
   commit the output to `web/` together with the source change. Keep any
   project build tooling (`package.json`, export presets, …) inside the
   project folder.
5. **The README summary is the index listing.** `scripts/build-pages.mjs`
   takes the title from `README.md`'s `# Heading` and the summary from its
   first paragraph. Keep that paragraph to one or two plain sentences.
6. **Root-level files are for the repo, not a project.** Only change
   `scripts/build-pages.mjs`, `.github/workflows/pages.yml`, `.gitignore`,
   `README.md` or this file for things that apply to every project.
   Project-specific ignores go in a `.gitignore` inside that project.

## Adding a project

1. Create `projects/<name>/` (lowercase, dashes — it becomes the URL).
2. Add `README.md` (title + summary) and `web/index.html`.
3. Nothing else: the index picks it up automatically on the next push to
   `main`. Check locally with `node scripts/build-pages.mjs` and
   `python3 -m http.server -d _site 8000`.

A project without `web/index.html` is skipped by the index (useful for
work in progress).

## Removing a project

Delete its folder. Nothing else references it.
