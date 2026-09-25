# CLAUDE.md

## Git workflow

- **Always commit and push directly to `main`.** No feature branches and
  no pull requests unless the user explicitly asks for one in that session.
- Push each commit as soon as it's made (`git push origin main`); don't
  batch several local commits before one push.
- Before committing, fetch and make sure local `main` is up to date with
  `origin/main` (`git pull --ff-only origin main`) so the push is never
  rejected or force-pushed.
