// Prints one test link per recipe for the Pages /demos/ list
// (.github/workflows/game2-pages.yml runs any game*/<demo>/tools/demo_links.mjs
// it finds): "<label>\t<query>" per line. The app opens ?rite=<id> straight
// away without sealing the day (scripts/main.gd, requested_rite()).
//   node game3/vigil/tools/demo_links.mjs
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const dir = fileURLToPath(new URL('../data/rites/', import.meta.url));
const recipes = readdirSync(dir)
	.filter((f) => f.endsWith('.json') && f !== 'opening.json')
	.sort()
	.flatMap((f) => JSON.parse(readFileSync(dir + f, 'utf8')).recipes ?? []);
recipes.sort((a, b) => (a.tier === b.tier ? a.id.localeCompare(b.id) : a.tier === 'free' ? -1 : 1));
for (const r of recipes) {
	console.log(`${r.title}${r.tier === 'deep' ? ' (deep)' : ''}\t?rite=${encodeURIComponent(r.id)}`);
}
