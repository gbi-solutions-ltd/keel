#!/usr/bin/env node
/**
 * check-frontend.mjs: the Keel frontend rules a linter like Biome cannot check, as a check-only
 * command. Copied into each converted app as scripts/check-frontend.mjs and run by `npm run lint`.
 * Works for React, Vue and Next.js sources. No dependencies.
 *
 * Vue single-file components, proven on the first Vue port (each form caught a planted failure):
 *   - a .vue file's <style> block is checked as CSS (raw-value on every line, not only colour words);
 *   - inline-style also catches `v-bind:style=` and a `style="` attribute on its own line;
 *   - unsafe-html also catches `:innerHTML=` and `v-bind:innerHTML=` (the same sink as v-html);
 *   - layer-import also resolves the `@/` alias (to the scanned src root) and dynamic import();
 *   - public-secret scans every .env* file at the app root (.env.mocked was skipped).
 *
 * Comments: a line that starts as a comment (//, *, a block comment opener, <!--, a JSX comment) is
 * not code, and neither is a line inside a comment that spans lines: an HTML comment (<!-- on one
 * line, --> on a later one, in .vue and .html files), or a block or JSX comment whose first line
 * starts with its opener (so a glob in a string opens nothing). Text after the closing mark is code
 * again. The dash rule still reads every line, comments included.
 *
 *   node scripts/check-frontend.mjs [src-dir ...]      exits 1 on any finding
 *
 * A comment `check-frontend-allow <rule>: <reason>` on the line before a finding allows that one
 * finding (not dash); allows are listed and counted, and one with no reason, an unknown rule or
 * nothing to allow on the next line is a finding of rule `allow`.
 *
 * Exit 2, before any rule runs, when a root (src by default) is missing or the roots hold no file
 * to scan: a lint that read nothing must not pass as clean. A crash (an unreadable file, a broken
 * symlink) also exits 2, could not run, never 1, which is kept for findings.
 *
 * Rules (Keel references in brackets):
 *   dash            no em or en dash anywhere, UI strings and comments included   [house-defaults]
 *   raw-value       no hex/rgb/hsl colour or font-family outside a tokens file    [frontend: theming]
 *                   and, in CSS (.css, .scss, a .vue <style> block), no named colour (red, white,
 *                   ...; not transparent, currentColor, inherit, initial, unset) as the value of a
 *                   colour property (color, background, background-color, border*, outline*, fill,
 *                   stroke, box-shadow, text-decoration-color); var(), url() and strings are skipped
 *   inline-style    no inline style attribute or style prop, an object included   [frontend: theming, CSP]
 *                   (style={{ ... }} and style={obj})
 *   unsafe-html     no dangerouslySetInnerHTML, v-html or innerHTML assignment    [frontend: XSS]
 *   token-storage   no token, jwt or session in localStorage/sessionStorage       [frontend: tokens]
 *   token-in-url    no token or key in a URL                                      [frontend: tokens]
 *   public-secret   no secret-looking name in a bundler-public env var            [frontend: secrets]
 *   role-check      permissions, never roles (not in mocks/, the server's stand-in) [house-defaults: access]
 *   layer-import    primitives < composites < domain < layout < pages             [frontend: components]
 *   unknown-layer   a folder directly under a components/ folder that is not a layer name: layer-import
 *                   checks nothing in it (an adapters/ folder); put it in a layer   [frontend: components]
 *   test-location   no test, spec, fixture-for-tests or test helper inside the app source:
 *                   tests live in tests/ at the app root, mirroring src/               [mockup-engine]
 *   generated-format  (app root) every output in orval.config.* sets a formatter, and biome.json
 *                   does not exclude an Orval output folder, nor skip one through vcs.useIgnoreFile
 *                   and .gitignore (Biome skips both, so the formatter silently does nothing);
 *                   switch its linter off by override instead
 *                                                                                      [mockup-engine]
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';

// A crash exits 2 (could not run), never 1 (findings). Standalone: an app copy has no lib/args.mjs.
const crash = (e) => {
  console.error(`check-frontend: crashed: ${e?.stack || e}`);
  process.exit(2);
};
process.on('uncaughtException', crash);
process.on('unhandledRejection', crash);

const roots = (process.argv.slice(2).length ? process.argv.slice(2) : ['src']).map((r) => resolve(r));
const SKIP_DIRS = new Set(['node_modules', 'dist', '.next', '.nuxt', 'generated', 'coverage']);
const EXT = /\.(tsx?|jsx?|mjs|vue|css|scss|html)$/;
const LAYERS = ['primitives', 'composites', 'domain', 'layout', 'pages'];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (!SKIP_DIRS.has(name)) walk(p, out);
    } else if (EXT.test(name)) out.push(p);
  }
  return out;
}

const findings = [];
// `check-frontend-allow <rule>: <reason>` in a comment allows that rule's finding on the next line
// only. Every allow is listed and counted; one with no reason, an unknown rule, or nothing to allow
// is itself a finding. The dash rule cannot be allowed.
const ALLOWABLE = [
  'raw-value',
  'inline-style',
  'unsafe-html',
  'token-storage',
  'token-in-url',
  'role-check',
  'layer-import',
];
const allows = new Map(); // `${file}\0${line}` -> { rule, reason, line, used }
const allowed = [];
const add = (file, line, rule, detail) => {
  const a = line === null ? null : allows.get(`${file}\0${line}`);
  if (a && a.rule === rule) {
    a.used = true;
    allowed.push({ file: relative(process.cwd(), file), line, rule, reason: a.reason });
    return;
  }
  findings.push({ file: relative(process.cwd(), file), line, rule, detail: detail.trim().slice(0, 120) });
};

// The CSS named colours (CSS Color 4), lowercase. Not transparent, currentcolor or the global keywords.
const NAMED_COLOURS = new Set(
  'aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen'.split(
    ' ',
  ),
);
// A colour property at the start of a declaration (line start, after ; or {, or after whitespace),
// so a selector such as .text-red or .border:hover is not read as one.
const COLOUR_DECL =
  /(?:^|[;{\s])(color|background|background-color|border(?:-[a-z-]+)?|outline(?:-[a-z-]+)?|fill|stroke|box-shadow|text-decoration-color)\s*:\s*([^;{}]*)/gi;

/** Removes every var(...) and url(...) call, nested ones included, from a CSS value. */
function stripCalls(value) {
  let out = '';
  for (let i = 0; i < value.length; ) {
    const m = /^(var|url)\(/i.exec(value.slice(i));
    if (!m || (i > 0 && /[\w-]/.test(value[i - 1]))) {
      out += value[i++];
      continue;
    }
    let depth = 0;
    let j = i + m[0].length - 1;
    for (; j < value.length; j++) {
      if (value[j] === '(') depth++;
      else if (value[j] === ')' && --depth === 0) break;
    }
    out += ' ';
    i = j + 1;
  }
  return out;
}

/** The first named colour a CSS line gives a colour property, or null. */
function namedColour(line) {
  const code = line.replace(/\/\*.*?\*\//g, ' ').replace(/(["'])(?:\\.|(?!\1).)*\1/g, ' ');
  for (const m of code.matchAll(COLOUR_DECL)) {
    for (const word of stripCalls(m[2]).split(/[\s,()/]+/)) if (NAMED_COLOURS.has(word.toLowerCase())) return word;
  }
  return null;
}

// A test file, or a helper folder used only by tests, inside an app source root.
const TEST_PATH = /(\.(test|spec)\.[cm]?[jt]sx?$)|([\\/](__tests__|__mocks__|tests?)[\\/])/;

const isComment = (text) => /^\s*(\/\/|\*|\/\*|<!--|\{\/\*)/.test(text);

function layerOf(file) {
  const parts = file.split(sep);
  const i = parts.lastIndexOf('components');
  const candidate = i >= 0 ? parts[i + 1] : parts.includes('pages') ? 'pages' : parts.includes('app') ? 'pages' : null;
  return LAYERS.includes(candidate) ? candidate : null;
}

const missing = roots.filter((r) => !existsSync(r) || !statSync(r).isDirectory());
if (missing.length) {
  console.error(
    `check-frontend: no such source folder: ${missing.map((r) => relative(process.cwd(), r) || r).join(', ')}`,
  );
  process.exit(2);
}
const files = roots.flatMap((r) => walk(r));
if (!files.length) {
  console.error(
    `check-frontend: no files to scan in ${roots.map((r) => relative(process.cwd(), r) || '.').join(', ')}`,
  );
  process.exit(2);
}

// unknown-layer: a folder directly under any components/ folder must be a layer.
{
  const seen = new Set();
  for (const file of files) {
    const root = roots.find((r) => file.startsWith(r + sep)) ?? '';
    const parts = file.slice(root.length + 1).split(sep);
    for (let k = 0; k < parts.length - 2; k++) {
      if (parts[k] !== 'components' || LAYERS.includes(parts[k + 1])) continue;
      const folder = join(root, ...parts.slice(0, k + 2));
      if (seen.has(folder)) continue;
      seen.add(folder);
      add(
        folder,
        null,
        'unknown-layer',
        `${parts[k + 1]}/ is not a layer (${LAYERS.join(', ')}): layer-import checks nothing in it`,
      );
    }
  }
}
// Every .env* file at the app root, not only four named ones: a mode file (.env.mocked) is public too.
const envFiles = [
  ...new Set([
    '.env',
    '.env.example',
    '.env.local',
    '.env.production',
    ...readdirSync('.').filter((n) => /^\.env(\.|$)/.test(n)),
  ]),
].filter(existsSync);

for (const file of files) {
  const root = roots.find((r) => file.startsWith(r + sep)) ?? '';
  if (TEST_PATH.test(file.slice(root.length)))
    add(file, 1, 'test-location', 'move it to tests/ at the app root, at the same path it has under src/');
  const src = readFileSync(file, 'utf8');
  const lines = src.split('\n');
  const isTokens = /(^|[\\/])tokens\.(css|scss)$/.test(file);
  const isCss = /\.(css|scss)$/.test(file);
  const isVue = /\.vue$/.test(file);
  let inStyle = false; // inside a .vue <style> block, whose lines are CSS
  const isMarkup = /\.(vue|html)$/.test(file);
  let inComment = null; // the closing mark of a comment spanning lines: '-->' or '*/'
  const isScript = /\.(tsx?|jsx?|mjs|vue)$/.test(file);
  const isMock = file.split(sep).includes('mocks');
  const myLayer = layerOf(file);

  lines.forEach((line, i) => {
    const n = i + 1;
    if (/[\u2013\u2014]/.test(line)) add(file, n, 'dash', line);
    const allow = line.match(/check-frontend-allow\s+([\w-]+)\s*:?\s*(.*?)\s*(?:\*\/\s*\}?|-->)?\s*$/);
    if (allow) {
      const [, rule, reason] = allow;
      if (!ALLOWABLE.includes(rule))
        add(file, n, 'allow', `${rule} is not a rule that can be allowed (${ALLOWABLE.join(', ')})`);
      else if (!reason) add(file, n, 'allow', `check-frontend-allow ${rule} needs a reason after the colon`);
      else allows.set(`${file}\0${n + 1}`, { rule, reason, line: n, used: false });
    }
    // Every other rule is about code; a comment that explains a rule is not a breach of it.
    let text = line;
    if (inComment) {
      const at = text.indexOf(inComment);
      if (at < 0) return;
      text = text.slice(at + inComment.length);
      inComment = null;
      if (!text.trim()) return;
    }
    if (isMarkup && text.includes('<!--') && !text.slice(text.lastIndexOf('<!--')).includes('-->')) inComment = '-->';
    else if (/^\s*\{?\/\*/.test(text) && !text.slice(text.indexOf('/*') + 2).includes('*/')) inComment = '*/';
    if (isVue && /^\s*<style\b/.test(text)) inStyle = true;
    if (isVue && /^\s*<\/style>/.test(text)) inStyle = false;
    const cssLine = isCss || inStyle;
    if (isComment(text)) return;
    if (inComment === '-->') text = text.slice(0, text.lastIndexOf('<!--'));
    if (
      !isTokens &&
      /(#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\()/.test(text) &&
      !/var\(--/.test(text) &&
      (cssLine || /(color|background|border|fill|stroke)/i.test(text))
    ) {
      if (!/\b(href|to)=/.test(text)) add(file, n, 'raw-value', text);
    } else if (!isTokens && cssLine) {
      const named = namedColour(text);
      if (named) add(file, n, 'raw-value', `named colour ${named}: ${text.trim()}`);
    }
    if (!isTokens && /font-family\s*:/.test(text) && !/var\(--/.test(text)) add(file, n, 'raw-value', text);
    if (
      /(?<![\w-])style=\{|\s:style=|<[a-z][^>]*\sstyle="/i.test(text) ||
      (isVue && /(^|\s)(v-bind:|:)?style=["']/.test(text))
    )
      add(file, n, 'inline-style', text);
    if (/dangerouslySetInnerHTML|\sv-html=|\.innerHTML\s*=/.test(text) || /(^|\s)(v-bind)?:innerHTML=/i.test(text))
      add(file, n, 'unsafe-html', text);
    if (/(localStorage|sessionStorage)\.setItem\(\s*['"`][^'"`]*(token|jwt|auth|session|secret)/i.test(text))
      add(file, n, 'token-storage', text);
    if (/[?&](access_token|token|api_key|apikey|key)=/i.test(text) && isScript) add(file, n, 'token-in-url', text);
    if (/\b(VITE|NEXT_PUBLIC|NUXT_PUBLIC|REACT_APP)_\w*(SECRET|PRIVATE|PASSWORD|API_KEY|TOKEN)\w*/.test(text))
      add(file, n, 'public-secret', text);
    // The mock API stands in for the server, whose rules may be about roles (keep one administrator).
    if (isScript && !isMock && /\.role\s*[!=]==?|\brole\s*[!=]==?\s*['"`]|\broles?\.includes\(/.test(text))
      add(file, n, 'role-check', text);

    if (isScript && myLayer) {
      const m = text.match(/(?:import|from)\s*\(?\s*['"]((?:\.{1,2}|@)\/[^'"]+)['"]/);
      if (m) {
        const spec = m[1];
        const target = layerOf(spec.startsWith('@/') ? join(root, spec.slice(2)) : resolve(dirname(file), spec));
        if (target && LAYERS.indexOf(target) > LAYERS.indexOf(myLayer))
          add(file, n, 'layer-import', `${myLayer} imports ${target}: ${spec}`);
      }
      if (myLayer === 'primitives' && /(?:from)\s+['"][^'"]*\/api\//.test(text))
        add(file, n, 'layer-import', `primitives import API types: ${text}`);
    }
  });
  for (const [key, a] of allows)
    if (key.startsWith(`${file}\0`) && !a.used)
      add(
        file,
        a.line,
        'allow',
        `check-frontend-allow ${a.rule} allows nothing: no ${a.rule} finding on the next line`,
      );
}
// Orval's output is formatted with the app's own Biome on every generation (formatter: 'biome' on
// each output), and biome.json keeps that folder in scope with only its linter switched off. An
// excluded folder is skipped silently, so the formatter does nothing and the code stays ragged.
const orvalConfig = ['orval.config.ts', 'orval.config.js', 'orval.config.mjs', 'orval.config.cjs'].find(existsSync);
if (orvalConfig) {
  const text = readFileSync(orvalConfig, 'utf8')
    .split('\n')
    .filter((l) => !/^\s*(\/\/|\*|\/\*)/.test(l))
    .join('\n');
  const outputs = (text.match(/\boutput\s*:/g) || []).length;
  const formatted = (text.match(/\bformatter\s*:/g) || []).length;
  if (outputs > formatted)
    add(
      resolve(orvalConfig),
      null,
      'generated-format',
      `${outputs - formatted} of ${outputs} outputs set no formatter: add formatter: 'biome' to each`,
    );
  const dirs = [...text.matchAll(/\b(?:target|schemas)\s*:\s*['"]\.?\/?([^'"]+)['"]/g)]
    .map((m) => m[1])
    .filter((p) => !/\.(ya?ml|json)$/.test(p))
    .map((p) => (/\.[cm]?[jt]sx?$/.test(p) ? dirname(p) : p).replace(/\/+$/, ''));
  if (existsSync('biome.json')) {
    let includes = [];
    let vcs = {};
    try {
      const biome = JSON.parse(readFileSync('biome.json', 'utf8'));
      includes = biome.files?.includes ?? [];
      vcs = biome.vcs ?? {};
    } catch {}
    // vcs.useIgnoreFile makes Biome skip what .gitignore lists, and Orval's folder usually is.
    if (vcs.enabled && vcs.useIgnoreFile && existsSync('.gitignore')) {
      const ignored = readFileSync('.gitignore', 'utf8')
        .split('\n')
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('#') && !l.startsWith('!'))
        .map((l) =>
          l
            .replace(/^\//, '')
            .replace(/^\*\*\//, '')
            .replace(/\/\*\*$/, '')
            .replace(/\/+$/, ''),
        );
      for (const ex of ignored)
        if (dirs.some((d) => d === ex || d.startsWith(`${ex}/`)))
          add(
            resolve('biome.json'),
            null,
            'generated-format',
            `vcs.useIgnoreFile skips ${ex} (in .gitignore), Orval's output, so Biome never formats it: set vcs.useIgnoreFile to false, or keep that folder out of .gitignore`,
          );
    }
    for (const inc of includes.filter((i) => typeof i === 'string' && i.startsWith('!'))) {
      const ex = inc
        .slice(1)
        .replace(/^\.\//, '')
        .replace(/\/\*\*$/, '')
        .replace(/\/+$/, '');
      if (dirs.some((d) => d === ex || d.startsWith(`${ex}/`)))
        add(
          resolve('biome.json'),
          null,
          'generated-format',
          `files.includes excludes ${ex}, Orval's output, so Biome never formats it: keep it in and switch its linter off with an override`,
        );
    }
  }
}

for (const f of envFiles) {
  readFileSync(f, 'utf8')
    .split('\n')
    .forEach((text, i) => {
      if (/^\s*(VITE|NEXT_PUBLIC|NUXT_PUBLIC|REACT_APP)_\w*(SECRET|PRIVATE|PASSWORD|API_KEY|TOKEN)\w*\s*=/.test(text))
        add(resolve(f), i + 1, 'public-secret', text);
    });
}

if (findings.length) {
  for (const a of allowed) console.log(`${a.file}:${a.line}  allowed  ${a.rule}  ${a.reason}`);
  for (const f of findings) console.log(`${f.file}${f.line === null ? '' : `:${f.line}`}  ${f.rule}  ${f.detail}`);
  console.log(
    `\ncheck-frontend: ${findings.length} finding(s) in ${files.length} files${allowed.length ? `, ${allowed.length} allowed` : ''}`,
  );
  process.exit(1);
}
for (const a of allowed) console.log(`${a.file}:${a.line}  allowed  ${a.rule}  ${a.reason}`);
console.log(`check-frontend: clean (${files.length} files${allowed.length ? `, ${allowed.length} allowed` : ''})`);
