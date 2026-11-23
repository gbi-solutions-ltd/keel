#!/usr/bin/env node
/**
 * split-css.mjs: turn the mockup's components.css into one CSS Module per component.
 *
 *   node split-css.mjs <mockup-dir> <app-components-dir> [--inventory <inventory.json>]
 *
 * Needs <mockup-dir>/.mockup-engine/inventory.json (run inventory.mjs first), or the file
 * --inventory names, for each component's layer. Writes <app-components-dir>/<layer folder>/<Name>/<Name>.module.css, where the layer
 * folders are primitives, composites, domain and layout.
 *
 * Each `/* Name *\/` block is copied unchanged, except that a class defined in base.css (a global
 * utility such as .numeric or .muted) is wrapped as :global(.name). Inside a CSS Module a bare
 * class is hashed, so without the wrap the rule silently never matches.
 *
 * Blocks are found as inventory.mjs counts them: a comment holding only a capitalised name (`/* Badge *\/`),
 * or several joined by " / " (`/* Tabs / TabPanel *\/`, written for each name). The file's prose header
 * comment is not a block. CRLF line ends split as LF. Exit 1 when a block is not written (its name has
 * no layer in the inventory), when rules sit before the first block, or when nothing is written; 2 on
 * bad arguments (lib/args.mjs), a missing inventory, or a crash.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { cli } from './lib/args.mjs';

const { values: { inventory: invArg = null }, positional: [mockupArg, outArg] } = cli('split-css');
const mockupDir = resolve(mockupArg);
const outDir = resolve(outArg);
// --inventory: an inventory written elsewhere (inventory.mjs --out), so Convert never writes into
// a signed-off package.
const inventoryPath = invArg ? resolve(invArg) : join(mockupDir, '.mockup-engine/inventory.json');
if (!existsSync(inventoryPath)) { console.error(`missing ${inventoryPath}: run inventory.mjs first`); process.exit(2); }

const FOLDER = { primitive: 'primitives', composite: 'composites', domain: 'domain', layout: 'layout' };
const layers = JSON.parse(readFileSync(inventoryPath, 'utf8')).componentLayers || {};
const stripComments = (css) => css.replace(/\/\*[\s\S]*?\*\//g, '');
const base = stripComments(readFileSync(join(mockupDir, 'assets/base.css'), 'utf8'));
const globals = new Set([...base.matchAll(/\.([a-z][\w-]*)/g)].map((m) => m[1]));

// CRLF as LF, so a file saved on Windows splits the same way.
const css = readFileSync(join(mockupDir, 'assets/components.css'), 'utf8').replace(/\r\n?/g, '\n');
// The blocks inventory.mjs counts: a comment holding only a capitalised name, or several joined by
// " / ". The file's header comment (prose) is no block, and neither is anything before the first one.
const BLOCK = /\/\*\s*([A-Z][\w /]*?)\s*\*\//g;
const heads = [...css.matchAll(BLOCK)];
const preamble = stripComments(css.slice(0, heads[0]?.index ?? css.length)).trim();
const problems = [];
if (heads.length && preamble) problems.push(`rules before the first block would be lost: "${preamble.replace(/\s+/g, ' ').slice(0, 60)}"`);

let written = 0;
let blocks = 0;
heads.forEach((h, i) => {
  const text = css.slice(h.index + h[0].length, i + 1 < heads.length ? heads[i + 1].index : css.length);
  const block = `${text.trim()}\n`.replace(/(?<![\w-])\.([a-z][\w-]*)/g, (m, cls) => (globals.has(cls) ? `:global(.${cls})` : m));
  for (const name of h[1].split('/').map((x) => x.trim()).filter(Boolean)) {
    blocks += 1;
    const layer = layers[name]?.layer;
    if (!FOLDER[layer]) { problems.push(`${name}: no layer in the inventory, its block is not written`); continue; }
    const dir = join(outDir, FOLDER[layer], name);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, `${name}.module.css`), block);
    written += 1;
    console.log(`${FOLDER[layer]}/${name}/${name}.module.css${block.includes(':global(') ? '  (globals wrapped)' : ''}`);
  }
});
for (const p of problems) console.error(`split-css: ${p}`);
console.log(`\nsplit-css: ${written} modules${written !== blocks ? `, ${written} of ${blocks} blocks written` : ''}`);
// A lost block, lost rules or nothing written is a failed split, not a smaller one.
process.exit(problems.length || !written || written !== blocks ? 1 : 0);
