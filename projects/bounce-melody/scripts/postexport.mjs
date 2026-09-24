// Patches this project's Godot Web export (web/index.html) right after
// it's regenerated: adds a noindex/nofollow robots meta tag and suffixes
// the title "(unlisted demo)", since Godot's default Web export shell
// carries neither.
//
// This is deliberately NOT a custom Godot HTML export shell
// (`html/custom_html_shell` in export_presets.cfg) -- see PLAN.md: patching
// two tags into the shell Godot already generated (and that is verified
// to boot correctly) is a small, low-risk, easily-verified text edit.
//
// Run once, by hand, right after exporting (from godot/):
//   godot4 --headless --export-release "Web"
//   node ../scripts/postexport.mjs

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const indexPath = fileURLToPath(
	new URL('../web/index.html', import.meta.url)
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
console.log(`postexport: patched ${indexPath}`);
