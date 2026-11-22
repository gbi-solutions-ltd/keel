#!/usr/bin/env node
/**
 * check-links.mjs: every markdown link in the engine's docs resolves: the skills (skills/mockup,
 * skills/convert-mockup), the port worker (agents/keel-port-worker.md) and everything under
 * lib/mockup-engine, only those, so in keel it judges no other skill's files; --file adds one
 * more (repeatable). It resolves its #anchor included (GitHub's heading slugs, a repeated heading numbered -1, -2).
 * Links inside fenced or inline code are skipped; external links (http, mailto, data) are not
 * fetched.
 *
 *   node check-links.mjs [<root>] [--list <target substring>] [--file <extra.md>]...
 *
 * <root> defaults to the folder holding skills/ and lib/ (keel's root; this script's
 * lib/mockup-engine/scripts/../../..). --list also prints every link whose
 * target path contains the substring (to find what points at a file before moving it). Exit 0 all
 * resolve, 1 a link is broken (each printed as BROKEN-FILE or BROKEN-ANCHOR with file:line), 2 no
 * markdown file found under the root, or bad usage.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { cli, usageError } from './lib/args.mjs';

const { values: { list: listTarget = null, file: extra = [] }, positional: [rootArg] } = cli('check-links');
const root = path.resolve(rootArg || fileURLToPath(new URL('../../..', import.meta.url)));

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name.startsWith('.')) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.md')) out.push(p);
  }
  return out;
}

const files = [
  ...extra.map((f) => path.resolve(f)),
  ...walk(path.join(root, 'skills', 'mockup')),
  ...walk(path.join(root, 'skills', 'convert-mockup')),
  path.join(root, 'agents', 'keel-port-worker.md'),
  ...walk(path.join(root, 'lib', 'mockup-engine')),
].filter((f) => fs.existsSync(f));
for (const f of extra) if (!fs.existsSync(f)) usageError('check-links', `--file ${f}: no such file`);
if (!files.length) usageError('check-links', `no markdown file under ${root} (skills/mockup, skills/convert-mockup, agents/keel-port-worker.md, lib/mockup-engine/)`);

function stripCode(text) {
  // drop fenced blocks, keep line count
  return text.replace(/^(```|~~~)[\s\S]*?^\1/gm, (m) => m.replace(/[^\n]/g, ''));
}

function slug(h) {
  return h
    .trim()
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/[^\p{L}\p{N}\s_-]/gu, '')
    .replace(/ /g, '-');
}

const anchorCache = new Map();
function anchors(file) {
  if (anchorCache.has(file)) return anchorCache.get(file);
  const set = new Set();
  const counts = {};
  const text = stripCode(fs.readFileSync(file, 'utf8'));
  for (const line of text.split('\n')) {
    const m = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (!m) continue;
    let s = slug(m[1].replace(/`/g, '').replace(/\[([^\]]*)\]\([^)]*\)/g, '$1'));
    if (counts[s] !== undefined) { counts[s]++; set.add(`${s}-${counts[s]}`); }
    else { counts[s] = 0; set.add(s); }
  }
  for (const m of text.matchAll(/<a\s+(?:name|id)="([^"]+)"/g)) set.add(m[1]);
  anchorCache.set(file, set);
  return set;
}

let broken = 0, total = 0;
for (const f of files) {
  const text = stripCode(fs.readFileSync(f, 'utf8'));
  const lines = text.split('\n');
  lines.forEach((line, i) => {
    const noInline = line.replace(/`[^`]*`/g, (m) => ' '.repeat(m.length));
    for (const m of noInline.matchAll(/\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)) {
      const href = m[1];
      if (/^(https?:|mailto:|data:)/.test(href)) continue;
      total++;
      const [p, a] = href.split('#');
      const target = p ? path.resolve(path.dirname(f), decodeURIComponent(p)) : f;
      const rel = path.relative(root, f) + ':' + (i + 1);
      if (listTarget && path.relative(root, target).includes(listTarget)) console.log(`LINK ${rel} -> ${href}`);
      if (!fs.existsSync(target)) { broken++; console.log(`BROKEN-FILE ${rel} -> ${href}`); continue; }
      if (a && target.endsWith('.md') && !anchors(target).has(a)) {
        broken++; console.log(`BROKEN-ANCHOR ${rel} -> ${href}`);
      }
    }
  });
}
console.log(`checked ${total} links in ${files.length} files, ${broken} broken`);
process.exitCode = broken ? 1 : 0;
