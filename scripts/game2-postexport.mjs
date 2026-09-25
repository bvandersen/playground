// Patches one Godot Web export's generated static/game2/<demo>/index.html
// to carry the same "unlisted demo" conventions every static/game/*.html
// file already does (see docs/game.md): a noindex/nofollow robots meta
// tag, and a title suffixed "(unlisted demo)".
//
// This is deliberately NOT a custom Godot HTML export shell
// (`html/custom_html_shell` in export_presets.cfg) -- see docs/game2.md,
// "Why the Godot export is never part of `npm run build`": hand-writing a
// shell against Godot's own template placeholders is easy to get subtly
// wrong with no interactive editor to preview it against, where patching
// two tags into the shell Godot already generated (and that this session
// already verified boots correctly) is a small, low-risk, easily-verified
// text edit.
//
// Run once, by hand, right after `godot4 --headless --export-release
// "Web"` for a given demo -- never part of `npm run build`/predev/
// prebuild (this repo's own build must never depend on Godot being
// installed; see docs/game2.md).
//
//   node scripts/game2-postexport.mjs <demo-name> [game-folder]
//
// `game-folder` defaults to game2; game1 (docs/game1.md) is exported the
// same way and patched with `node scripts/game2-postexport.mjs rail-yard game1`.

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const demoName = process.argv[2];
const gameFolder = process.argv[3] ?? 'game2';
if (!demoName || !/^game\d+$/.test(gameFolder)) {
	console.error('Usage: node scripts/game2-postexport.mjs <demo-name> [game-folder]');
	process.exit(1);
}

const indexPath = fileURLToPath(
	new URL(`../static/${gameFolder}/${demoName}/index.html`, import.meta.url)
);

let html = readFileSync(indexPath, 'utf8');

if (!html.includes('name="robots"')) {
	html = html.replace(
		/<meta name="viewport"[^>]*>/,
		(match) => `${match}\n\t\t<meta name="robots" content="noindex, nofollow">`
	);
}

html = html.replace(
	/<title>([^<]*)<\/title>/,
	(match, title) =>
		title.includes('(unlisted demo)') ? match : `<title>${title} (unlisted demo)</title>`
);

writeFileSync(indexPath, html);
console.log(`game2-postexport: patched ${indexPath}`);
