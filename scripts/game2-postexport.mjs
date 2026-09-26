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
//
// Second mode, used only by the Pages workflow's "Assemble site" step
// (docs/hosting.md, Phase 1) on the assembled copy, never on static/:
//
//   node scripts/game2-postexport.mjs --shared-engine <index.html> <engine-base>
//
// points that export at one shared engine copy instead of its own
// index.wasm/index.js/worklets. <engine-base> is relative to the html
// (e.g. ../../engine/4.3/index; relative because of the github.io
// project-page subpath). Godot's loader derives every engine file from
// GODOT_CONFIG.executable (`${executable}.wasm`, `.audio.worklet.js`, ...)
// and only the pck from mainPack, so the pck keeps loading from the
// demo's own folder.

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

if (process.argv[2] === '--shared-engine') {
	const [, , , htmlPath, engineBase] = process.argv;
	if (!htmlPath || !engineBase) {
		console.error('Usage: node scripts/game2-postexport.mjs --shared-engine <index.html> <engine-base>');
		process.exit(1);
	}
	let html = readFileSync(htmlPath, 'utf8');
	const scriptTag = '<script src="index.js"></script>';
	const configRe = /const GODOT_CONFIG = (\{.*\});/;
	const configMatch = html.match(configRe);
	if (!html.includes(scriptTag) || !configMatch) {
		console.error(`game2-postexport: ${htmlPath} doesn't look like a Godot Web export`);
		process.exit(1);
	}
	const config = JSON.parse(configMatch[1]);
	if (config.executable !== 'index') {
		console.error(`game2-postexport: ${htmlPath} has executable "${config.executable}", expected "index"`);
		process.exit(1);
	}
	config.executable = engineBase;
	config.mainPack = 'index.pck';
	// The loader looks the wasm size up under `${executable}.wasm`; without
	// the renamed key the loading bar has no total.
	config.fileSizes = Object.fromEntries(
		Object.entries(config.fileSizes ?? {}).map(([file, size]) => [
			file === 'index.pck' ? file : file.replace(/^index\./, `${engineBase}.`),
			size
		])
	);
	html = html.replace(scriptTag, `<script src="${engineBase}.js"></script>`);
	html = html.replace(configRe, () => `const GODOT_CONFIG = ${JSON.stringify(config)};`);
	writeFileSync(htmlPath, html);
	console.log(`game2-postexport: ${htmlPath} -> shared engine ${engineBase}`);
	process.exit(0);
}

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
