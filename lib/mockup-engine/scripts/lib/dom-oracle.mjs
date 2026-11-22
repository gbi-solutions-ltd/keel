/**
 * dom-oracle.mjs: the DOM oracle's normaliser and line diff, pure functions with no browser, shared by
 * dom-oracle.mjs (the CLI) and its tests.
 *
 * Input is a serialised DOM (an element's innerHTML as the browser writes it). Output is one line per
 * element and per text node, indented by depth, so two renderings of the same screen (the mockup and
 * a port) can be compared line by line:
 *   - element: `<tag a="1" b="2">`, attributes sorted by name; void elements open no depth
 *   - text:    `T:<text>`, whitespace runs collapsed to one space; whitespace-only text dropped
 *   - comments dropped (Vue's `<!--v-if-->` anchors, the mockup's notes)
 * Normalising:
 *   - class lists compared as sets (sorted), an empty class dropped
 *   - href mapped to a route (`route`), so `./ledger-journals.html?x=1` and `/ledger/journals` match
 *   - `data-v-*` attributes always dropped (Vue scoped styles), plus `dropAttributes` (default the mk.js
 *     plumbing a port does not emit: data-action, data-group)
 *   - a hidden `<button>` whose data-action is in `skipHiddenActions`, or whose id is in
 *     `skipHiddenIds`, is dropped with its subtree (mockup-only plumbing buttons; the lists are the
 *     mockup's own, empty by default, set in mockup.config.json `domOracle`)
 *   - an element whose data-component is in `opaqueComponents` (a js-kit's components, which render
 *     their own DOM in the app and an approximation in the mockup) becomes one line,
 *     `<kit data-component="Name">`, and one text line holding its text with aria-hidden parts and
 *     svg left out: its place, its name and its copy are compared, its inner DOM is not
 *   - `edge: true` strips leading and trailing whitespace from each text node. Edge whitespace inside a
 *     button or a flex item draws no pixels (see the Vue stack reference, Template whitespace), so
 *     `compare` reports it apart from the rest.
 * Names are lowercased and entities decoded, as Python's html.parser does, so the line lists match the
 * session 7 domdiff.py this replaces.
 */
import { sha256 } from './production.mjs';

export const VOID = new Set(['br', 'img', 'input', 'hr', 'meta', 'link', 'path', 'circle', 'rect', 'line', 'polyline', 'polygon', 'ellipse', 'area', 'base', 'col', 'embed', 'source', 'track', 'wbr', 'use', 'stop']);
const RAW = new Set(['script', 'style']);
export const DEFAULT_OPTIONS = { edge: false, dropAttributes: ['data-action', 'data-group'], skipHiddenActions: [], skipHiddenIds: [], opaqueComponents: [], pageRoutes: {} };

const NAMED = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'" };

/** Decodes the entities a browser serialiser writes, plus numeric references. Unknown names stay as written. */
export function decode(s) {
  return s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+[0-9]*);/gi, (m, name) => {
    if (name[0] === '#') {
      const code = name[1] === 'x' || name[1] === 'X' ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : m;
    }
    return NAMED[name.toLowerCase()] ?? m;
  });
}

/** An href as a comparable route: hashes and absolute URLs as written, mockup pages and app paths as `R:<a-b>`. */
export function route(href, pageRoutes = {}) {
  if (href.startsWith('#') || href.startsWith('http')) return href;
  const h = href.replace(/[?#].*$/, '');
  // a mockup page, relative (./x.html, x.html, ../pages/x.html): the page's own route template
  // (pageRoutes, file name to MK.page route) with each :param taken from the link's query key of the
  // same name (mockup-conventions: params travel as query strings); else its file name without .html
  if (!h.startsWith('/')) {
    const file = h.replace(/^(\.\.?\/)+/, '').replace(/^pages\//, '').replace(/\.html$/, '');
    const template = pageRoutes[file];
    if (template) {
      const q = new URLSearchParams(href.includes('?') ? href.slice(href.indexOf('?') + 1).replace(/#.*$/, '') : '');
      const filled = template.replace(/:([A-Za-z_]\w*)/g, (m, name) => q.get(name) ?? m);
      if (!filled.includes(':')) return route(filled);
    }
    return 'R:' + file;
  }
  // an app path: its segments joined by '-'
  return 'R:' + h.replace(/^\/+/, '').replaceAll('/', '-');
}

/**
 * Tokenises serialised HTML into { type: 'start'|'end'|'text', ... }. Handles double, single and
 * unquoted attribute values, boolean attributes, self-closing tags, comments and raw-text elements.
 */
export function tokenize(html) {
  const out = [];
  let i = 0;
  const n = html.length;
  let text = '';
  const flush = () => { if (text) { out.push({ type: 'text', text: decode(text) }); text = ''; } };
  while (i < n) {
    const c = html[i];
    if (c !== '<') { text += c; i++; continue; }
    if (html.startsWith('<!--', i)) {
      flush();
      const end = html.indexOf('-->', i + 4);
      i = end < 0 ? n : end + 3;
      continue;
    }
    if (html.startsWith('<!', i) || html.startsWith('<?', i)) {
      flush();
      const end = html.indexOf('>', i);
      i = end < 0 ? n : end + 1;
      continue;
    }
    const close = html[i + 1] === '/';
    const nameMatch = /^[a-zA-Z][^\s/>]*/.exec(html.slice(i + (close ? 2 : 1), i + (close ? 2 : 1) + 64));
    if (!nameMatch) { text += c; i++; continue; }
    flush();
    const tag = nameMatch[0].toLowerCase();
    let j = i + (close ? 2 : 1) + nameMatch[0].length;
    if (close) {
      const end = html.indexOf('>', j);
      i = end < 0 ? n : end + 1;
      out.push({ type: 'end', tag });
      continue;
    }
    const attrs = [];
    let selfClosing = false;
    while (j < n) {
      while (j < n && /\s/.test(html[j])) j++;
      if (html[j] === '>') { j++; break; }
      if (html[j] === '/' && html[j + 1] === '>') { selfClosing = true; j += 2; break; }
      if (html[j] === '/') { j++; continue; }
      const an = /^[^\s/>=]+/.exec(html.slice(j, j + 256));
      if (!an) { j++; continue; }
      const name = an[0].toLowerCase();
      j += an[0].length;
      while (j < n && /\s/.test(html[j])) j++;
      let value = null;
      if (html[j] === '=') {
        j++;
        while (j < n && /\s/.test(html[j])) j++;
        const q = html[j];
        if (q === '"' || q === "'") {
          const end = html.indexOf(q, j + 1);
          value = html.slice(j + 1, end < 0 ? n : end);
          j = end < 0 ? n : end + 1;
        } else {
          const v = /^[^\s>]*/.exec(html.slice(j))[0];
          value = v;
          j += v.length;
        }
        value = decode(value);
      }
      attrs.push([name, value]);
    }
    i = j;
    out.push({ type: 'start', tag, attrs, selfClosing });
    if (RAW.has(tag)) {
      const endAt = html.toLowerCase().indexOf(`</${tag}`, i);
      const body = html.slice(i, endAt < 0 ? n : endAt);
      if (body) out.push({ type: 'text', text: body });
      i = endAt < 0 ? n : endAt;
    }
  }
  flush();
  return out;
}

/** The normalised lines of serialised HTML (see the file comment). */
export function normalise(html, options = {}) {
  const o = { ...DEFAULT_OPTIONS, ...options };
  const drop = new Set(o.dropAttributes);
  const skipActions = new Set(o.skipHiddenActions);
  const skipIds = new Set(o.skipHiddenIds);
  const opaque = new Set(o.opaqueComponents);
  const out = [];
  let depth = 0;
  let skip = 0;
  // Inside an opaque component: its nesting depth, the depth at which an aria-hidden or svg part
  // began (0 when none), and the text gathered so far.
  let kit = 0;
  let kitHidden = 0;
  let kitText = '';
  const start = (tag, attrList) => {
    const a = new Map(attrList);
    if (skip) { if (!VOID.has(tag)) skip++; return; }
    if (kit) {
      if (VOID.has(tag)) return;
      kit++;
      if (!kitHidden && (a.get('aria-hidden') === 'true' || tag === 'svg')) kitHidden = kit;
      return;
    }
    if (opaque.has(a.get('data-component'))) {
      out.push('  '.repeat(depth) + `<kit data-component="${a.get('data-component')}">`);
      if (VOID.has(tag)) return;
      kit = 1; kitHidden = 0; kitText = '';
      return;
    }
    if (tag === 'button' && a.has('hidden') && (skipActions.has(a.get('data-action')) || skipIds.has(a.get('id')))) { skip = 1; return; }
    const parts = [];
    for (const k of [...a.keys()].sort()) {
      if (drop.has(k) || k.startsWith('data-v-')) continue;
      let v = a.get(k) ?? '';
      if (k === 'class') {
        v = v.split(/\s+/).filter(Boolean).sort().join(' ');
        if (!v) continue;
      }
      if (k === 'href') v = route(v, o.pageRoutes);
      parts.push(`${k}="${v}"`);
    }
    out.push('  '.repeat(depth) + `<${tag} ` + parts.join(' ') + '>');
    if (!VOID.has(tag)) depth++;
  };
  const end = (tag) => {
    // start counts no void tag while skipping, so end does not either (an svg's </path>)
    if (skip) { if (!VOID.has(tag)) skip--; return; }
    if (kit) {
      if (VOID.has(tag)) return;
      if (kitHidden === kit) kitHidden = 0;
      kit--;
      if (!kit) {
        const text = kitText.replace(/\s+/g, ' ').trim();
        if (text) out.push('  '.repeat(depth + 1) + 'T:' + text);
      }
      return;
    }
    if (VOID.has(tag)) return;
    depth = Math.max(0, depth - 1);
  };
  for (const t of tokenize(html)) {
    if (t.type === 'start') {
      start(t.tag, t.attrs);
      if (t.selfClosing && !VOID.has(t.tag)) end(t.tag);
    } else if (t.type === 'end') end(t.tag);
    else if (kit) { if (!kitHidden) kitText += ` ${t.text} `; }
    else if (!skip) {
      let s = t.text.replace(/\s+/g, ' ');
      if (o.edge) s = s.trim();
      if (s.trim()) out.push('  '.repeat(depth) + 'T:' + s);
    }
  }
  return out;
}

/**
 * Myers' shortest edit script between two line arrays: [{ op: ' '|'-'|'+', line }].
 * Common prefix and suffix are trimmed first, so near-identical dumps cost almost nothing.
 */
export function editScript(a, b) {
  let pre = 0;
  while (pre < a.length && pre < b.length && a[pre] === b[pre]) pre++;
  let suf = 0;
  while (suf < a.length - pre && suf < b.length - pre && a[a.length - 1 - suf] === b[b.length - 1 - suf]) suf++;
  const A = a.slice(pre, a.length - suf);
  const B = b.slice(pre, b.length - suf);
  const N = A.length;
  const M = B.length;
  const max = N + M;
  const off = max + 1;
  const v = new Int32Array(2 * max + 3);
  const trace = [];
  let found = N === 0 && M === 0;
  for (let d = 0; d <= max && !found; d++) {
    trace.push(v.slice(off - d - 1, off + d + 2));
    for (let k = -d; k <= d; k += 2) {
      let x = k === -d || (k !== d && v[off + k - 1] < v[off + k + 1]) ? v[off + k + 1] : v[off + k - 1] + 1;
      let y = x - k;
      while (x < N && y < M && A[x] === B[y]) { x++; y++; }
      v[off + k] = x;
      if (x >= N && y >= M) { found = true; break; }
    }
  }
  const mid = [];
  let x = N;
  let y = M;
  for (let d = trace.length - 1; d >= 0; d--) {
    const tv = trace[d];
    const at = (k) => tv[k + d + 1];
    const k = x - y;
    const prevK = k === -d || (k !== d && at(k - 1) < at(k + 1)) ? k + 1 : k - 1;
    const prevX = d === 0 ? 0 : at(prevK);
    const prevY = prevX - prevK;
    while (x > prevX && y > prevY) { mid.push({ op: ' ', line: A[x - 1] }); x--; y--; }
    if (d > 0) {
      if (x === prevX) mid.push({ op: '+', line: B[y - 1] });
      else mid.push({ op: '-', line: A[x - 1] });
    }
    x = prevX;
    y = prevY;
  }
  mid.reverse();
  return [...a.slice(0, pre).map((line) => ({ op: ' ', line })), ...mid, ...a.slice(a.length - suf).map((line) => ({ op: ' ', line }))];
}

/** Unified diff text of an edit script, `context` lines around each change; '' when there is no change. */
export function unified(script, { context = 2, from = 'mockup', to = 'app' } = {}) {
  const changed = script.map((e, i) => (e.op !== ' ' ? i : -1)).filter((i) => i >= 0);
  if (!changed.length) return '';
  const hunks = [];
  let s = Math.max(0, changed[0] - context);
  let e = Math.min(script.length, changed[0] + context + 1);
  for (const i of changed.slice(1)) {
    if (i - context <= e) e = Math.min(script.length, i + context + 1);
    else { hunks.push([s, e]); s = Math.max(0, i - context); e = Math.min(script.length, i + context + 1); }
  }
  hunks.push([s, e]);
  const out = [`--- ${from}`, `+++ ${to}`];
  for (const [hs, he] of hunks) {
    let aStart = 1;
    let bStart = 1;
    for (let i = 0; i < hs; i++) { if (script[i].op !== '+') aStart++; if (script[i].op !== '-') bStart++; }
    const body = script.slice(hs, he);
    const aLen = body.filter((x) => x.op !== '+').length;
    const bLen = body.filter((x) => x.op !== '-').length;
    out.push(`@@ -${aLen ? aStart : aStart - 1},${aLen} +${bLen ? bStart : bStart - 1},${bLen} @@`);
    for (const x of body) out.push(x.op + x.line);
  }
  return out.join('\n');
}

/** Number of removed plus added lines in an edit script. */
export function changeCount(script) {
  return script.reduce((n, e) => n + (e.op === ' ' ? 0 : 1), 0);
}

/**
 * A short hash of what an edit script changes: its removed and added lines, in order, without their
 * positions or context, so the same difference hashes alike when unrelated lines move it, and another
 * difference of the same size does not.
 */
export function diffHash(script) {
  const changed = script.filter((e) => e.op !== ' ').map((e) => e.op + e.line).join('\n');
  return sha256(changed).slice(0, 16);
}

/**
 * Compares two serialised DOMs. `diffLines` counts changed lines with edge whitespace ignored (the
 * number to drive to zero); `diffHash` is diffHash of that diff; `edgeLines` is how many more a strict comparison finds (whitespace at the
 * edge of a text node only). `diff` is the edge-ignoring unified diff, `strictDiff` the strict one.
 */
export function compare(mockupHtml, appHtml, options = {}) {
  const o = { ...DEFAULT_OPTIONS, ...options };
  const ma = normalise(mockupHtml, { ...o, edge: true });
  const pa = normalise(appHtml, { ...o, edge: true });
  const loose = editScript(ma, pa);
  const strict = editScript(normalise(mockupHtml, { ...o, edge: false }), normalise(appHtml, { ...o, edge: false }));
  const diffLines = changeCount(loose);
  return {
    mockupLines: ma.length,
    appLines: pa.length,
    diffLines,
    diffHash: diffHash(loose),
    edgeLines: changeCount(strict) - diffLines,
    diff: unified(loose),
    strictDiff: unified(strict),
  };
}

/** The `domOracle` options a mockup.config.json gives, validated. Returns { error } or { options }. */
export function optionsFromConfig(config = {}) {
  const d = config.domOracle;
  if (d === undefined) return { options: {} };
  if (typeof d !== 'object' || d === null || Array.isArray(d)) return { error: 'domOracle must be an object' };
  const options = {};
  for (const key of ['dropAttributes', 'skipHiddenActions', 'skipHiddenIds', 'opaqueComponents']) {
    if (d[key] === undefined) continue;
    if (!Array.isArray(d[key]) || d[key].some((x) => typeof x !== 'string')) return { error: `domOracle.${key} must be an array of strings` };
    options[key] = d[key];
  }
  // The config's dropAttributes add to the defaults: the mk.js plumbing is never a port's.
  if (options.dropAttributes) options.dropAttributes = [...new Set([...DEFAULT_OPTIONS.dropAttributes, ...options.dropAttributes])];
  const unknown = Object.keys(d).filter((k) => !['dropAttributes', 'skipHiddenActions', 'skipHiddenIds', 'opaqueComponents', 'root', 'appRoot'].includes(k));
  if (unknown.length) return { error: `domOracle has unknown keys: ${unknown.join(', ')}` };
  if (d.root !== undefined && typeof d.root !== 'string') return { error: 'domOracle.root must be a selector string' };
  if (d.appRoot !== undefined && typeof d.appRoot !== 'string') return { error: 'domOracle.appRoot must be a selector string' };
  return { options, root: d.root, ...(d.appRoot !== undefined ? { appRoot: d.appRoot } : {}) };
}

/**
 * Compares this run's case rows with a reference run's, by slug. A row is { slug, status:
 * 'match'|'diff'|'error', diffLines, edgeLines }. `planned` is every slug the config gives at this
 * viewport, unfiltered: a reference case still in the config but filtered out of this run is
 * 'not-run' (no verdict), one no longer in the config is 'missing'.
 * Verdict per case: 'worse' (more diff lines; the same number with a different diffHash, so one
 * difference fixed and another of the same size made, marked contentChanged; or an error now and not
 * before), 'better' (fewer diff lines, or no error now after one before), 'same' (equal diff lines and
 * hash, or an error both times), 'new' (not in the reference), 'missing', 'not-run'. Classified on diff
 * lines and their hash; edge lines are reported as a delta. A pair where either row has no diffHash
 * (a reference written before hashes were stored) is classified on the count alone and counted in
 * `unhashed`. Returns { counts, unhashed, cases: [{ slug, verdict, before, after, diffDelta,
 * edgeDelta, contentChanged? }] } with `before`/`after` the diff line count or 'error' (null when absent).
 */
export function compareWithReference(rows, refRows, planned = rows.map((r) => r.slug)) {
  const ref = new Map(refRows.map((r) => [r.slug, r]));
  const now = new Map(rows.map((r) => [r.slug, r]));
  const plannedSet = new Set(planned);
  const counts = { worse: 0, better: 0, same: 0, new: 0, 'new-error': 0, missing: 0, 'not-run': 0 };
  const lines = (r) => (r.status === 'error' ? 'error' : r.diffLines ?? 0);
  const delta = (a, b, key) => (a && b && a.status !== 'error' && b.status !== 'error' ? (b[key] ?? 0) - (a[key] ?? 0) : null);
  const out = [];
  let unhashed = 0;
  for (const r of rows) {
    const p = ref.get(r.slug);
    let verdict;
    let contentChanged = false;
    // A case the reference never had that errors now has no baseline to excuse it: it fails
    if (!p) verdict = r.status === 'error' ? 'new-error' : 'new';
    else if (r.status === 'error') verdict = p.status === 'error' ? 'same' : 'worse';
    else if (p.status === 'error') verdict = 'better';
    else {
      const hashed = typeof r.diffHash === 'string' && typeof p.diffHash === 'string';
      if (!hashed) unhashed++;
      contentChanged = hashed && r.diffHash !== p.diffHash;
      const [now, before] = [r.diffLines ?? 0, p.diffLines ?? 0];
      verdict = now < before ? 'better' : now > before || contentChanged ? 'worse' : 'same';
    }
    counts[verdict]++;
    out.push({ slug: r.slug, verdict, before: p ? lines(p) : null, after: lines(r), diffDelta: delta(p, r, 'diffLines'), edgeDelta: delta(p, r, 'edgeLines'), ...(contentChanged ? { contentChanged: true } : {}) });
  }
  for (const p of refRows) {
    if (now.has(p.slug)) continue;
    const verdict = plannedSet.has(p.slug) ? 'not-run' : 'missing';
    counts[verdict]++;
    out.push({ slug: p.slug, verdict, before: lines(p), after: null, diffDelta: null, edgeDelta: null });
  }
  return { counts, unhashed, cases: out };
}
