#!/usr/bin/env node
/**
 * import-mockup.mjs: regenerate the files a converted app takes from the frozen mockup, in one
 * idempotent run. They are never edited by hand: change the mockup and rerun.
 *
 *   node import-mockup.mjs --mockup <dir> --app <dir> [--stack react-vite|vue|nextjs]
 *                          [--only fixtures,icons,css,nav,strings,contract] [--i18n vue-i18n|i18next|icu]
 *                          [--contract-out <path in the app>] [--flat] [--check] [--force]
 *
 * --stack defaults to the mockup's mockup.config.json `project.stack.name` (or the older `targetStack`),
 * else react-vite. All three
 * stacks use a `src/` folder, so the outputs are the same per stack today (the table is in STACKS
 * below, so a stack can differ later):
 *
 *   fixtures  src/mocks/fixtures.ts    window.FIXTURES from data/fixtures.js as an ES module: a
 *                                      default export of the whole object and one named export per
 *                                      top-level key that is a valid identifier (`export const
 *                                      session`), as the example apps import them. Types are
 *                                      inferred from the literal. To type it against the contract,
 *                                      import it into a typed module and use `satisfies`
 *                                      (`export const invoices = fx.invoices satisfies Invoice[]`);
 *                                      never edit this file
 *   icons     src/lib/icons.ts         each icon as `{ tag, attrs, children? }[]`, so an Icon
 *                                      component renders SVG children without v-html or
 *                                      dangerouslySetInnerHTML. Sources, in order: the ICON_PATHS
 *                                      table in components/Icon.js (name: inner SVG markup), then
 *                                      assets/icons/<name>.svg (the root's children; its viewBox goes
 *                                      to ICON_VIEWBOX). Every icon must re-serialise to its source
 *                                      markup exactly (for a file, with whitespace between tags
 *                                      removed), or the run fails: a single-quoted attribute, text
 *                                      or `<path></path>` would otherwise change silently. No source
 *                                      is not an error unless --only names icons
 *   css       src/styles/tokens.css, base.css, components.css   byte copies of assets/*.css. A
 *                                      React app usually splits components.css into CSS Modules
 *                                      with split-css.mjs; the copy is still written (leave css out
 *                                      of --only to skip it). Module sheets (tours.css) are not copied.
 *                                      With project.designFramework utility-css, assets/tailwind.css
 *                                      (the framework's input: its @source paths land on
 *                                      src/components and src/pages) is required and components.css
 *                                      is not. Font and image files a copied sheet names by a relative
 *                                      url() inside assets/ are copied beside it, so the url still
 *                                      resolves (a missing one fails the run)
 *   nav       src/lib/nav.ts           the menu as app config: the `nav` given to MK.shell in
 *                                      components/AppLayout.js (evaluated with a stub MK), else
 *                                      FIXTURES.nav. `href` (a mockup file) is dropped where the
 *                                      entry has a `route`; every other field is kept in order
 *   strings   src/locales/<locale>.ts and src/locales/index.ts   each strings/<locale>.js
 *                                      (MK.strings) as a module of nested messages (`invoices.title`
 *                                      becomes { invoices: { title } }), in the target library's
 *                                      syntax: --i18n vue-i18n (the default for vue: {name}; plurals
 *                                      "one | other" or "zero | one | other"; @ and | escaped),
 *                                      i18next (react-vite: {{name}}; plurals as key_one, key_other),
 *                                      icu (nextjs, next-intl: {name}; {count, plural, one {..} other
 *                                      {..}}; apostrophes doubled). index.ts exports LOCALES,
 *                                      DEFAULT_LOCALE (project.i18n.defaultLocale, else the first
 *                                      file) and messages. A key that is both a message and a prefix
 *                                      of another, or a plural vue-i18n cannot express, fails the run.
 *                                      --flat (i18next or vue-i18n) writes each key as it is instead
 *                                      ("invoices.title": ...), for i18next's keySeparator: false or
 *                                      vue-i18n's messageResolver: (o, k) => o[k] ?? null, which take
 *                                      a key that is also a prefix of another (icu refuses --flat)
 *                                      No strings/ folder is not an error unless --only names strings
 *   contract  api/openapi.yaml and api/contract-source.json   only when --only names it. A byte
 *                                      copy of the signed-off contract (project.contract.location in
 *                                      the mockup) and where it came from: the mockup, the sign-off
 *                                      round, who and when, its version and sha256. Refused unless
 *                                      the mockup's sign-off is valid now (lib/signoff.mjs), so an app
 *                                      is only ever built from a signed-off contract. The mockup's copy
 *                                      is the source: a change goes in as a new sign-off round, then
 *                                      a re-import, and --check reports an app built from an older
 *                                      round or an app copy edited by hand. --contract-out moves both
 *                                      files (an existing repo keeps its contract where its Orval
 *                                      config reads it); the source file sits beside the contract
 *
 * --app must be an existing folder (exit 2 otherwise), so a mistyped path never starts a new tree.
 *
 * Every output is built in memory and checked first; on any failure nothing is written (exit 1).
 * Fixtures and nav must survive JSON exactly: a function, undefined, a Date or NaN fails the run
 * instead of vanishing. A generated .ts file is overwritten only when it carries the GENERATED
 * marker; a hand-written file at that path fails the run unless --force. Headers name relative
 * sources only and no date, so a rerun is byte-identical. Exclude the generated files from the
 * app's formatter (Biome `files.ignore`), or a format pass makes --check fail.
 *
 * The record: each run writes .import-mockup.json at the app root, the part and sha256 of every file
 * the imports wrote (an --only run replaces the entries of its own parts and keeps the rest) and
 * where the contract went (`contract`, which a later run without --contract-out reuses). A byte
 * copy (the CSS and the files it names, the contract and contract-source.json) whose bytes differ
 * from the record was changed by hand: the run refuses it unless --force, and --check lists it as
 * hand-changed. On an app's first import (no record yet), a byte copy that exists with other bytes
 * than the import would write may be the app's own: the run refuses it unless --force (which
 * overwrites it and says so), and --check lists it as unrecorded; one equal to what would be written
 * is fine and gets recorded. The same holds with a record that has no entry for the file (a part
 * not imported before): a differing byte copy is refused unless --force. Orphans: a recorded file of a part in this
 * run that the mockup no longer produces, or a generated locale module (GENERATED marker) with no
 * strings/ file behind it, is listed and never deleted.
 *
 * --check writes nothing and exits 1 if any output would change (new, different, hand-written,
 * hand-changed or unrecorded) or an orphan is left, listing each; exit 0 when all are up to date. For CI. Without
 * --only it also checks the contract when the app has one (where the record says, else
 * api/contract-source.json). The `mockup` path in contract-source.json is not compared, as it is
 * relative to wherever the app and the mockup sit on that machine.
 * Exit 0 written (or, with --check, up to date); 1 a refusal (nothing written) or, with --check,
 * drift; 2 on bad arguments (lib/args.mjs; --app missing, --flat with icu) and on a crash (a bug or
 * a system error, lib/args.mjs isCrash: nothing written).
 */
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import vm from 'node:vm';
import { assertJson, plain, readFixtures } from './lib/fixtures.mjs';
import { projectStack } from './lib/project.mjs';
import { sha256 } from './lib/production.mjs';
import { contractLocation, readRecord, signoffStatus } from './lib/signoff.mjs';
import { SPECS, cli, isCrash } from './lib/args.mjs';

const STACKS = {
  'react-vite': { fixtures: 'src/mocks/fixtures.ts', icons: 'src/lib/icons.ts', styles: 'src/styles', nav: 'src/lib/nav.ts', locales: 'src/locales', i18n: 'i18next' },
  vue: { fixtures: 'src/mocks/fixtures.ts', icons: 'src/lib/icons.ts', styles: 'src/styles', nav: 'src/lib/nav.ts', locales: 'src/locales', i18n: 'vue-i18n' },
  nextjs: { fixtures: 'src/mocks/fixtures.ts', icons: 'src/lib/icons.ts', styles: 'src/styles', nav: 'src/lib/nav.ts', locales: 'src/locales', i18n: 'icu' },
};
const PARTS = ['fixtures', 'icons', 'css', 'nav', 'strings', 'contract'];
// Parts left out of a run without --only: they need more than the mockup's files.
const ONLY_WHEN_NAMED = new Set(['contract']);
const I18N = ['vue-i18n', 'i18next', 'icu'];
const CSS_FILES = ['tokens.css', 'base.css', 'components.css', 'tailwind.css'];
const MARKER = '// GENERATED by import-mockup.mjs';
const RECORD = '.import-mockup.json';
const RESERVED = new Set(('break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield let static implements interface package private protected public await arguments eval').split(' '));

class Fail extends Error {}
const { usage } = SPECS['import-mockup'];

/** The options (lib/args.mjs parsed them): --mockup and --app are required. */
function readOptions({ values }) {
  const o = { check: false, force: false, ...values };
  if (!o.mockup || !o.app) throw new Fail('--mockup and --app are required');
  return o;
}

const header = (source, extra = []) => [`${MARKER} from the mockup's ${source}. Do not edit; rerun the script.`, ...extra.map((l) => `// ${l}`)].join('\n');

function fixturesModule(fx) {
  const named = Object.keys(fx).filter((k) => /^[A-Za-z_$][\w$]*$/.test(k) && !RESERVED.has(k) && k !== 'fixtures');
  return `${header('data/fixtures.js', [
    'Types are inferred from the literal. To type against the contract, import from here into a',
    'typed module and use `satisfies` there (fx.invoices satisfies Invoice[]); never edit this file.',
  ])}\n\nconst fixtures = ${JSON.stringify(fx, null, 2)};\n\nexport default fixtures;\n${named.map((k) => `export const ${k} = fixtures.${k};\n`).join('')}`;
}

// --- icons ---------------------------------------------------------------------------------------
// A tiny SVG markup parser: elements and attributes only (double quoted). Anything else (text,
// comments, single quotes) is left out of the parse, and the round trip then fails on it.
function parseSvg(markup) {
  const root = { children: [] };
  const stack = [root];
  const re = /<(\/?)([A-Za-z][\w:-]*)((?:\s+[\w:-]+="[^"]*")*)\s*(\/?)>/g;
  let m;
  while ((m = re.exec(markup))) {
    const [, close, tag, rest, selfClose] = m;
    if (close) { if (stack.length > 1) stack.pop(); continue; }
    const el = { tag, attrs: Object.fromEntries([...rest.matchAll(/([\w:-]+)="([^"]*)"/g)].map(([, k, v]) => [k, v])) };
    stack.at(-1).children.push(el);
    if (!selfClose) { el.children = []; stack.push(el); }
  }
  return root.children;
}
const serialise = (parts) => parts.map((e) => {
  const attrs = Object.entries(e.attrs).map(([k, v]) => ` ${k}="${v}"`).join('');
  return e.children && e.children.length ? `<${e.tag}${attrs}>${serialise(e.children)}</${e.tag}>` : `<${e.tag}${attrs}/>`;
}).join('');
const prune = (parts) => parts.map((e) => (e.children && e.children.length ? { ...e, children: prune(e.children) } : { tag: e.tag, attrs: e.attrs }));

function readIcons(mockup) {
  const icons = {};
  const viewBox = {};
  const sources = [];
  const tableFile = join(mockup, 'components/Icon.js');
  if (existsSync(tableFile)) {
    const src = readFileSync(tableFile, 'utf8');
    const start = src.search(/(?:const|let|var)\s+ICON_PATHS\s*=\s*\{/);
    if (start >= 0) {
      const open = src.indexOf('{', start);
      const end = matchBrace(src, open);
      const table = plain(vm.runInNewContext(`(${src.slice(open, end + 1)})`, {}));
      for (const [name, markup] of Object.entries(table)) {
        if (typeof markup !== 'string') throw new Error(`icon ${name}: ICON_PATHS value is not a string`);
        icons[name] = { markup, from: 'components/Icon.js' };
      }
      sources.push('components/Icon.js');
    }
  }
  const dir = join(mockup, 'assets/icons');
  if (existsSync(dir)) {
    const files = readdirSync(dir).filter((f) => f.endsWith('.svg')).sort();
    for (const f of files) {
      const name = f.slice(0, -4);
      if (icons[name]) throw new Error(`icon ${name}: defined in both components/Icon.js and assets/icons/${f}`);
      const text = readFileSync(join(dir, f), 'utf8').replace(/^﻿/, '').replace(/<\?xml[^>]*\?>/, '').trim();
      const m = text.match(/^<svg\b([^>]*)>([\s\S]*)<\/svg>$/);
      if (!m) throw new Error(`icon ${name}: assets/icons/${f} is not a single <svg> element`);
      const vb = m[1].match(/\sviewBox="([^"]*)"/);
      if (vb) viewBox[name] = vb[1];
      icons[name] = { markup: m[2].replace(/>\s+</g, '><').trim(), from: `assets/icons/${f}` };
    }
    if (files.length) sources.push('assets/icons/*.svg');
  }
  if (!sources.length) return null;
  const out = {};
  for (const name of Object.keys(icons).sort()) {
    const { markup, from } = icons[name];
    const parts = parseSvg(markup);
    const back = serialise(parts);
    if (back !== markup) throw new Error(`icon ${name} (${from}): markup does not round-trip\n  source: ${markup}\n  rebuilt: ${back}`);
    out[name] = prune(parts);
  }
  return { icons: out, viewBox, sources };
}
function matchBrace(src, open) {
  let depth = 0;
  let quote = null;
  for (let i = open; i < src.length; i += 1) {
    const c = src[i];
    if (quote) { if (c === '\\') i += 1; else if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'" || c === '`') quote = c;
    else if (c === '{') depth += 1;
    else if (c === '}' && (depth -= 1) === 0) return i;
  }
  throw new Error('components/Icon.js: ICON_PATHS table is not closed');
}

function iconsModule({ icons, viewBox, sources }) {
  const vb = Object.keys(viewBox).length
    ? `\n/** The viewBox of each icon read from assets/icons/*.svg. */\nexport const ICON_VIEWBOX: Record<string, string> = ${JSON.stringify(viewBox, null, 2)};\n`
    : '';
  return `${header(sources.join(' and '), ['Render each part with the framework\'s dynamic element (<component :is>, createElement); the round trip to the source markup was checked.'])}\n\n` +
    'export interface IconPart {\n  tag: string;\n  attrs: Record<string, string>;\n  children?: readonly IconPart[];\n}\n\n' +
    `export const ICONS: Record<string, readonly IconPart[]> = ${JSON.stringify(icons, null, 2)};\n${vb}`;
}

// --- nav -----------------------------------------------------------------------------------------
function noopProxy() {
  const fn = function noop() { return proxy; };
  const proxy = new Proxy(fn, { get: (_t, k) => (k === Symbol.toPrimitive ? () => '' : proxy), apply: () => proxy, construct: () => proxy });
  return proxy;
}
function readShellNav(mockup) {
  const file = join(mockup, 'components/AppLayout.js');
  if (!existsSync(file)) return null;
  let config = null;
  const any = noopProxy();
  const MK = new Proxy({
    shell: (c) => { config = c; },
    component: () => {}, html: () => '', raw: (s) => s, onRender: () => {}, href: (p) => p, components: any,
  }, { get: (t, k) => (k in t ? t[k] : any) });
  const window = { MK, FIXTURES: {} };
  try {
    vm.runInNewContext(readFileSync(file, 'utf8'), { MK, window, document: any, navigator: { platform: '' }, location: { search: '', href: '' }, console }, { filename: 'components/AppLayout.js' });
  } catch (e) {
    throw new Error(`components/AppLayout.js could not be evaluated with a stub MK to read its nav: ${e.message}`);
  }
  return config && config.nav !== undefined ? plain(config.nav) : null;
}
const dropHref = (v) => {
  if (Array.isArray(v)) return v.map(dropHref);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).filter(([k]) => !(k === 'href' && 'route' in v)).map(([k, x]) => [k, dropHref(x)]));
  return v;
};
function navModule(nav, source) {
  return `${header(source, ['The menu as app config, in the mockup\'s order. The router and the permission guard use the same routes.'])}\n\n` +
    `export const NAV = ${JSON.stringify(nav, null, 2)};\n\nexport type NavEntry = (typeof NAV)[number];\n`;
}

// --- main ----------------------------------------------------------------------------------------
// ---------- strings: strings/<locale>.js to the app's locale modules ----------
function readStrings(mockup, defaultLocale) {
  const dir = join(mockup, 'strings');
  if (!existsSync(dir)) return null;
  const catalogs = {};
  const order = [];
  const files = readdirSync(dir).filter((f) => f.endsWith('.js')).sort();
  for (const f of files) {
    const MK = { strings: (code, table) => { if (!catalogs[code]) order.push(code); catalogs[code] = { ...(catalogs[code] || {}), ...plain(table) }; } };
    vm.runInNewContext(readFileSync(join(dir, f), 'utf8'), { MK, window: { MK } }, { filename: `strings/${f}` });
  }
  if (!order.length) return null;
  for (const [code, table] of Object.entries(catalogs)) assertJson(table, `strings ${code}`);
  const def = defaultLocale && catalogs[defaultLocale] ? defaultLocale : order[0];
  return { catalogs, locales: [def, ...order.filter((c) => c !== def)], defaultLocale: def, files };
}

const CATEGORIES = ['zero', 'one', 'two', 'few', 'many', 'other'];
function convertMessage(msg, lib, key) {
  const text = (t) => {
    if (lib === 'i18next') return t.replace(/\{(\w+)\}/g, '{{$1}}');
    if (lib === 'vue-i18n') return t.replace(/[@|]/g, (c) => `{'${c}'}`);
    return t.replace(/'/g, "''"); // icu
  };
  if (typeof msg === 'string') return { value: text(msg) };
  const cats = Object.keys(msg);
  const bad = cats.filter((c) => !CATEGORIES.includes(c));
  if (bad.length) throw new Error(`strings: ${key} has plural categories ${bad.join(', ')} (CLDR: ${CATEGORIES.join(', ')})`);
  if (!msg.other) throw new Error(`strings: ${key} is a plural without "other"`);
  if (lib === 'i18next') return { plural: Object.fromEntries(cats.map((c) => [c, text(msg[c])])) };
  if (lib === 'vue-i18n') {
    const extra = cats.filter((c) => !['zero', 'one', 'other'].includes(c));
    if (extra.length) throw new Error(`strings: ${key} uses ${extra.join(', ')}, which vue-i18n's default choice rule cannot express; give the app pluralRules and use --i18n icu, or keep to zero, one, other`);
    return { value: [msg.zero, msg.one ?? msg.other, msg.other].filter((v) => v !== undefined).map(text).join(' | ') };
  }
  return { value: `{count, plural, ${cats.map((c) => `${c === 'zero' ? '=0' : c} {${text(msg[c]).replace(/#/g, "'#'")}}`).join(' ')}}` };
}

// Flat: each key as it is ("invoices.title"), for i18next with keySeparator: false or vue-i18n with
// a messageResolver that reads the key whole, either of which takes a key that is both a message and
// a prefix of another (nesting cannot).
function flatMessages(table, lib) {
  const out = {};
  for (const key of Object.keys(table).sort()) {
    const c = convertMessage(table[key], lib, key);
    if (c.plural) for (const [cat, v] of Object.entries(c.plural)) out[`${key}_${cat}`] = v;
    else out[key] = c.value;
  }
  return out;
}

function nestMessages(table, lib, code) {
  const root = {};
  for (const key of Object.keys(table).sort()) {
    const parts = key.split('.');
    let node = root;
    for (const p of parts.slice(0, -1)) {
      if (typeof node[p] === 'string') throw new Error(`strings ${code}: ${key} nests under ${parts.slice(0, parts.indexOf(p) + 1).join('.')}, which is a message`);
      node = node[p] ??= {};
    }
    const leaf = parts[parts.length - 1];
    if (node[leaf] !== undefined) throw new Error(`strings ${code}: ${key} is both a message and a prefix of another key${lib === 'i18next' ? ' (with i18next, pass --flat and set keySeparator: false)' : lib === 'vue-i18n' ? ' (with vue-i18n, pass --flat and give createI18n messageResolver: (o, k) => o[k] ?? null)' : ''}`);
    const c = convertMessage(table[key], lib, key);
    if (c.plural) for (const [cat, v] of Object.entries(c.plural)) node[`${leaf}_${cat}`] = v;
    else node[leaf] = c.value;
  }
  return root;
}

const localeId = (code) => code.replace(/[^A-Za-z0-9]/g, '_');
function localeModule(code, messages, lib) {
  return `${header(`strings/${code}.js`, [`Messages for ${code} in ${lib} syntax.`])}\n\nexport default ${JSON.stringify(messages, null, 2)} as const;\n`;
}
function localesIndex(st, lib) {
  const imports = st.locales.map((c) => `import ${localeId(c)} from './${c}';`).join('\n');
  return `${header('strings/', [`The locales and their messages, in ${lib} syntax.`])}\n\n${imports}\n\n` +
    `export const LOCALES = ${JSON.stringify(st.locales)} as const;\nexport const DEFAULT_LOCALE = ${JSON.stringify(st.defaultLocale)};\n` +
    `export const messages = { ${st.locales.map((c) => `${JSON.stringify(c)}: ${localeId(c)}`).join(', ')} };\n`;
}

function plan(opts) {
  const mockup = resolve(opts.mockup);
  const app = resolve(opts.app);
  if (!existsSync(mockup)) throw new Fail(`mockup folder not found: ${mockup}`);
  if (!existsSync(app) || !statSync(app).isDirectory()) throw new Fail(`--app ${app} not found: create the app first (a mistyped path would start a new tree)`);
  const recPath = join(app, RECORD);
  let record = null;
  if (existsSync(recPath)) {
    try { record = JSON.parse(readFileSync(recPath, 'utf8')); } catch (e) { throw new Error(`${RECORD} is not JSON (${e.message}): fix it or delete it, and the next run records again`); }
    if (!record || typeof record.files !== 'object') throw new Error(`${RECORD} has no files map: delete it, and the next run records again`);
  }
  // Where the app keeps its contract: --contract-out, else where the last contract run put it.
  const contractDest = opts['contract-out'] ?? (typeof record?.contract === 'string' ? record.contract : undefined);
  const hasContract = (contractDest && existsSync(join(app, contractDest.split('/').slice(0, -1).join('/'), 'contract-source.json'))) || existsSync(join(app, 'api/contract-source.json'));
  let stack = opts.stack;
  if (!stack) {
    const cfg = join(mockup, 'mockup.config.json');
    stack = (existsSync(cfg) && projectStack(JSON.parse(readFileSync(cfg, 'utf8')))) || 'react-vite';
  }
  const paths = STACKS[stack];
  if (!paths) throw new Fail(`unknown stack ${stack} (one of ${Object.keys(STACKS).join(', ')})`);
  const only = opts.only ? opts.only.split(',').map((s) => s.trim()).filter(Boolean) : null;
  for (const p of only ?? []) if (!PARTS.includes(p)) throw new Fail(`unknown --only part ${p} (one of ${PARTS.join(', ')})`);
  // A default --check includes the contract when the app has one, so CI sees a hand-edited copy.
  const want = (p) => (only ? only.includes(p) : !ONLY_WHEN_NAMED.has(p) || (p === 'contract' && opts.check && hasContract));

  const lib = opts.i18n || paths.i18n;
  if (!I18N.includes(lib)) throw new Fail(`unknown --i18n ${lib} (one of ${I18N.join(', ')})`);
  if (opts.flat && lib === 'icu') throw new Fail('--flat is for i18next (keySeparator: false) or vue-i18n (messageResolver: (o, k) => o[k] ?? null); icu nests by key');
  const outputs = []; // { path (relative to app), content: Buffer|string, generated: boolean }
  const notes = [];
  let fx = null;
  const fixtures = () => (fx ??= readFixtures(mockup));

  if (want('fixtures')) {
    const f = fixtures();
    outputs.push({ part: 'fixtures', path: paths.fixtures, content: fixturesModule(f), generated: true });
    notes.push(`fixtures: ${Object.keys(f).length} keys -> ${paths.fixtures}`);
  }
  if (want('icons')) {
    const ic = readIcons(mockup);
    if (ic) {
      outputs.push({ part: 'icons', path: paths.icons, content: iconsModule(ic), generated: true });
      notes.push(`icons: ${Object.keys(ic.icons).length} from ${ic.sources.join(' and ')} -> ${paths.icons} (round trip ok)`);
    } else if (only) throw new Error('icons: no source (components/Icon.js with ICON_PATHS, or assets/icons/*.svg)');
    else notes.push('icons: no source (components/Icon.js ICON_PATHS or assets/icons/*.svg), skipped');
  }
  if (want('css')) {
    const cfgFile = join(mockup, 'mockup.config.json');
    const kind = existsSync(cfgFile) ? JSON.parse(readFileSync(cfgFile, 'utf8')).project?.designFramework?.kind : undefined;
    const required = kind === 'utility-css' ? 'tailwind.css' : 'components.css';
    const copied = [];
    const assets = new Set();
    for (const f of CSS_FILES) {
      const src = join(mockup, 'assets', f);
      if (!existsSync(src)) { if (f === required) throw new Error(`assets/${f} not found${kind === 'utility-css' ? ' (project.designFramework is utility-css: the framework input file)' : ''}`); continue; }
      const css = readFileSync(src);
      outputs.push({ part: 'css', path: `${paths.styles}/${f}`, content: css, generated: false });
      copied.push(f);
      for (const m of css.toString('utf8').matchAll(/url\(\s*(['"]?)([^'")]+)\1\s*\)/g)) {
        const ref = m[2].split(/[?#]/)[0];
        if (/^(data:|[a-z]+:|\/|#)/i.test(ref)) continue;
        const abs = resolve(join(mockup, 'assets'), ref);
        const rel = relative(join(mockup, 'assets'), abs);
        if (rel.startsWith('..')) throw new Error(`${f}: url(${m[2]}) points outside assets/, so the copy cannot resolve it`);
        if (!existsSync(abs)) throw new Error(`${f}: url(${m[2]}) is not there`);
        assets.add(rel.split(sep).join('/'));
      }
    }
    for (const rel of [...assets].sort()) outputs.push({ part: 'css', path: `${paths.styles}/${rel}`, content: readFileSync(join(mockup, 'assets', rel)), generated: false });
    notes.push(`css: ${copied.join(', ')} byte-copied -> ${paths.styles}/${assets.size ? ` (with ${assets.size} files they name)` : ''}`);
  }
  if (want('nav')) {
    let nav = readShellNav(mockup);
    let source = 'components/AppLayout.js (MK.shell nav)';
    if (nav == null) {
      const f = existsSync(join(mockup, 'data/fixtures.js')) ? fixtures() : {};
      if (f.nav !== undefined) { nav = f.nav; source = 'data/fixtures.js (FIXTURES.nav)'; }
    }
    if (nav == null) {
      if (only) throw new Error('nav: no MK.shell nav in components/AppLayout.js and no FIXTURES.nav');
      notes.push('nav: no MK.shell nav and no FIXTURES.nav, skipped');
    } else {
      if (!Array.isArray(nav)) throw new Error(`nav from ${source} is not an array`);
      assertJson(nav, 'nav');
      nav = dropHref(nav);
      outputs.push({ part: 'nav', path: paths.nav, content: navModule(nav, source), generated: true });
      notes.push(`nav: ${nav.length} entries from ${source} -> ${paths.nav}`);
    }
  }

  if (want('strings')) {
    const cfgPath = join(mockup, 'mockup.config.json');
    const cfg = existsSync(cfgPath) ? JSON.parse(readFileSync(cfgPath, 'utf8')) : {};
    const st = readStrings(mockup, cfg.project?.i18n?.defaultLocale);
    if (st) {
      for (const code of st.locales) outputs.push({ part: 'strings', path: `${paths.locales}/${code}.ts`, content: localeModule(code, opts.flat ? flatMessages(st.catalogs[code], lib) : nestMessages(st.catalogs[code], lib, code), lib), generated: true });
      outputs.push({ part: 'strings', path: `${paths.locales}/index.ts`, content: localesIndex(st, lib), generated: true });
      notes.push(`strings: ${st.locales.join(', ')} (default ${st.defaultLocale}, ${Object.keys(st.catalogs[st.defaultLocale]).length} keys) as ${lib} -> ${paths.locales}/`);
    } else if (only) throw new Error('strings: no strings/<locale>.js calling MK.strings');
    else notes.push('strings: no strings/ folder, skipped');
  }

  if (want('contract')) {
    const cfgPath = join(mockup, 'mockup.config.json');
    const cfg = existsSync(cfgPath) ? JSON.parse(readFileSync(cfgPath, 'utf8')) : {};
    const sign = signoffStatus(mockup, cfg);
    if (!sign.signed) throw new Error(`contract: the mockup's sign-off is not valid (${sign.problems.join('; ')}); an app is built from a signed-off contract only (skills/mockup/references/signoff.md)`);
    const loc = contractLocation(cfg);
    const last = readRecord(mockup).rounds.at(-1);
    const dest = (contractDest ?? 'api/openapi.yaml').split(sep).join('/');
    if (dest.startsWith('/') || dest.split('/').includes('..')) throw new Fail(`--contract-out ${dest} must be a path inside the app`);
    const bytes = readFileSync(join(mockup, loc.path));
    const sourceFile = `${dest.split('/').slice(0, -1).join('/') || '.'}/contract-source.json`.replace(/^\.\//, '');
    const source = { mockup: relative(app, mockup).split(sep).join('/'), contract: loc.path, round: last.round, signedOffBy: last.by, date: last.date, version: last.contract.version, sha256: last.contract.sha256 };
    outputs.push({ part: 'contract', path: dest, content: bytes, generated: false });
    outputs.push({ part: 'contract', path: sourceFile, content: `${JSON.stringify(source, null, 2)}\n`, generated: false, sourceRecord: true });
    notes.push(`contract: ${loc.path}${last.contract.version ? ` ${last.contract.version}` : ''}, sign-off round ${last.round} (${last.date}) -> ${dest}, ${sourceFile}`);
  }

  // Compare with disk, and with what the last import recorded.
  for (const o of outputs) {
    const abs = join(app, o.path);
    const next = Buffer.isBuffer(o.content) ? o.content : Buffer.from(o.content, 'utf8');
    o.bytes = next;
    if (!existsSync(abs)) { o.state = 'new'; continue; }
    const cur = readFileSync(abs);
    o.onDisk = sha256(cur);
    const recorded = record?.files?.[o.path];
    if (o.generated && !cur.toString('utf8').startsWith(MARKER)) o.state = 'hand-written';
    else if (cur.equals(next) || (o.sourceRecord && sameButMockup(cur, next))) o.state = 'same';
    else if (!o.generated && recorded && recorded.sha256 !== o.onDisk) o.state = 'hand-changed';
    else if (!o.generated && !recorded) { o.state = 'unrecorded'; o.unrecorded = true; }
    else { o.state = 'changed'; o.unrecorded = false; }
  }

  // Orphans: recorded files of the parts in this run that the mockup no longer produces, and
  // generated locale modules with no strings/ file behind them (found without a record too).
  const ran = new Set(outputs.map((o) => o.part));
  if (want('strings')) ran.add('strings');
  const produced = new Set(outputs.map((o) => o.path));
  const orphans = new Set(Object.entries(record?.files ?? {}).filter(([f, e]) => ran.has(e.part) && !produced.has(f) && existsSync(join(app, f))).map(([f]) => f));
  if (want('strings') && existsSync(join(app, paths.locales))) {
    for (const f of readdirSync(join(app, paths.locales))) {
      const rel = `${paths.locales}/${f}`;
      if (f.endsWith('.ts') && !produced.has(rel) && readFileSync(join(app, rel), 'utf8').startsWith(MARKER)) orphans.add(rel);
    }
  }
  const contract = outputs.find((o) => o.part === 'contract' && !o.sourceRecord)?.path;
  return { app, stack, outputs, notes, record, contract, orphans: [...orphans].sort(), orphanParts: Object.fromEntries([...orphans].map((f) => [f, record?.files?.[f]?.part ?? 'strings'])) };
}

/** contract-source.json equal but for `mockup`, a path relative to where the app sits on this machine. */
function sameButMockup(cur, next) {
  try {
    const a = JSON.parse(cur.toString('utf8'));
    const b = JSON.parse(next.toString('utf8'));
    delete a.mockup;
    delete b.mockup;
    return JSON.stringify(a) === JSON.stringify(b);
  } catch { return false; }
}

/** The new record: this run's outputs as they sit on disk, orphans still there, other parts kept. */
function nextRecord({ outputs, record, contract, orphans, orphanParts }) {
  const ran = new Set(outputs.map((o) => o.part));
  const files = {};
  for (const [f, e] of Object.entries(record?.files ?? {})) if (!ran.has(e.part) && !orphanParts[f]) files[f] = e;
  for (const f of orphans) files[f] = record?.files?.[f] ?? { part: orphanParts[f], sha256: null };
  for (const o of outputs) files[o.path] = { part: o.part, sha256: o.state === 'same' ? o.onDisk : sha256(o.bytes) };
  const sorted = Object.fromEntries(Object.keys(files).sort().map((f) => [f, files[f]]));
  return `${JSON.stringify({ about: 'Written by import-mockup.mjs: what the last import wrote, a sha256 per file. Do not edit; a byte copy that no longer matches is refused as changed by hand.', contract: contract ?? record?.contract, files: sorted }, null, 2)}\n`;
}

function main() {
  let opts;
  try { opts = readOptions(cli('import-mockup')); } catch (e) { console.error(`${e.message}\n${usage}`); process.exit(2); }
  let p;
  try { p = plan(opts); } catch (e) {
    if (e instanceof Fail) { console.error(`${e.message}\n${usage}`); process.exit(2); }
    if (isCrash(e)) { console.error(`import-mockup: crashed: ${e.stack || e}\nnothing written`); process.exit(2); }
    console.error(`import-mockup: ${e.message}\nnothing written`);
    process.exit(1);
  }
  const { app, stack, outputs, notes, record, orphans } = p;
  console.log(`import-mockup: stack ${stack}, app ${app}`);
  for (const n of notes) console.log(`  ${n}`);
  if (!record) console.log(`  record: no ${RECORD} yet${opts.check ? '; the next import writes one' : '; this run writes one'}`);
  const stale = outputs.filter((o) => o.state !== 'same');
  const orphanLine = (f) => `  orphan: ${f} (the mockup no longer produces it; delete it)`;
  if (opts.check) {
    for (const o of stale) console.log(`  would change: ${o.path} (${o.state})`);
    for (const f of orphans) console.log(orphanLine(f));
    const tail = orphans.length ? `, ${orphans.length} orphan${orphans.length === 1 ? '' : 's'}` : '';
    console.log(stale.length || orphans.length ? `check: ${stale.length} of ${outputs.length} outputs out of date${tail}` : `check: all ${outputs.length} outputs up to date`);
    process.exit(stale.length || orphans.length ? 1 : 0);
  }
  const hand = outputs.filter((o) => ['hand-written', 'hand-changed', 'unrecorded'].includes(o.state));
  if (hand.length && !opts.force) {
    for (const o of hand) {
      if (o.state === 'hand-written') console.error(`  ${o.path} exists without the GENERATED marker (hand-written?); move it or pass --force`);
      else if (o.state === 'unrecorded') console.error(`  ${o.path} exists with other bytes and no import recorded it (${record ? `not in ${RECORD}` : `no ${RECORD} yet`}): it may be the app's own; move it, or pass --force to overwrite it`);
      else console.error(`  ${o.path} changed by hand since the last import (its sha256 is not the one in ${RECORD}); make the change in the mockup, or pass --force to overwrite it`);
    }
    console.error('import-mockup: nothing written');
    process.exit(1);
  }
  for (const o of stale) {
    const abs = join(app, o.path);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, o.bytes);
  }
  const rec = nextRecord(p);
  const recPath = join(app, RECORD);
  if (!existsSync(recPath) || readFileSync(recPath, 'utf8') !== rec) writeFileSync(recPath, rec);
  for (const o of stale.filter((x) => x.unrecorded)) console.log(`  overwrote ${o.path}, which no import had recorded: if it was the app's own, recover it from version control`);
  for (const f of orphans) console.log(orphanLine(f));
  console.log(`wrote ${stale.length}, unchanged ${outputs.length - stale.length}${stale.length ? `: ${stale.map((o) => relative(app, join(app, o.path))).join(', ')}` : ''}`);
}

main();
