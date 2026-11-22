/*
 * mk.js: tiny mockup runtime. No build step, works from file://.
 *
 * Gives plain HTML mockups the shape a framework app will have:
 *   - components are pure functions, props to markup, each tagged with its layer
 *     (primitive, composite, domain, layout), which become framework components
 *   - a shell (MK.shell) owns what every page shares: navigation, keyboard shortcuts, the
 *     command palette, and the page shown when a role lacks permission
 *   - pages own state and actions and re-render on change (useState / ref plus handlers)
 *   - data comes from window.FIXTURES through load(), never inline markup
 *   - ?state=empty|loading|error previews non-happy states, ?as=<role> previews a role;
 *     the app honours both flags in development, which is how the visual diff compares them
 *   - copy comes from strings/<locale>.js through MK.t(key, vars); ?locale=<code> previews a
 *     locale and ?locale=pseudo a generated one with longer, accented text
 *
 * Do not add features here casually: anything this runtime can do, every conversion has to
 * reproduce. Keep it boring.
 */
(function () {
  'use strict';

  const LAYERS = ['primitive', 'composite', 'domain', 'layout'];
  const components = {};
  const componentMeta = {};
  const used = new Set();
  let shellDef = null;
  let currentPage = null;
  let pendingFocus = null;
  const renderHooks = [];
  // MK.onRender((info) => ...) runs after every render with { page, status, session, scenario,
  // params }. For modules that act on a ready page, such as tours. Becomes an effect in the app.
  const onRender = (fn) => { renderHooks.push(fn); };

  // html tagged template with auto-escaping
  class Raw {
    constructor(value) { this.value = value; }
    toString() { return this.value; }
  }
  const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ESC[c]);
  const part = (v) => {
    if (v === false || v === null || v === undefined) return '';
    if (v instanceof Raw) return v.value;
    if (Array.isArray(v)) return v.map(part).join('');
    return esc(v);
  };
  function html(strings, ...values) {
    let out = '';
    strings.forEach((s, i) => { out += s + (i < values.length ? part(values[i]) : ''); });
    return new Raw(out);
  }
  const raw = (s) => new Raw(String(s));

  // MK.component('Badge', ({ tone, label }) => html`<span class="badge">...</span>`, { layer: 'primitive' })
  // The runtime stamps data-component="Badge" on the root element. A wrapper whose root is
  // another component keeps the inner name, matching what a framework renders.
  function component(name, fn, meta = {}) {
    if (components[name]) console.warn(`[mk] component ${name} registered twice`);
    if (!LAYERS.includes(meta.layer)) console.warn(`[mk] component ${name} needs { layer: ${LAYERS.join(' | ')} }`);
    componentMeta[name] = { layer: meta.layer || null };
    components[name] = (props = {}) => {
      used.add(name);
      const out = String(fn(props));
      const rootTag = out.match(/^\s*<[a-zA-Z][\w-]*[^>]*>/);
      if (rootTag && /\sdata-component=/.test(rootTag[0])) return raw(out);
      return raw(out.replace(/^\s*<([a-zA-Z][\w-]*)/, `<$1 data-component="${name}"`));
    };
    return components[name];
  }

  // Strings and locales (skills/mockup/references/mockup-conventions.md, Strings). A strings file calls
  // MK.strings('fr-FR', { 'invoices.title': 'Factures', ... }); the first one loaded is the default.
  // A message has {name} placeholders, or is { one, other, ... } (CLDR plural categories, chosen by
  // vars.count). ?locale=<code> picks a registered locale; ?locale=pseudo renders the default one
  // accented and about 40% longer, in [brackets], to find hard-coded copy and text that cannot grow.
  // With no strings file at all, the locale stays unset and formatting is exactly as before.
  const catalogs = {};
  let defaultLocale = null;
  const requestedLocale = new URLSearchParams(location.search).get('locale');
  function strings(code, table) {
    catalogs[code] = { ...(catalogs[code] || {}), ...table };
    defaultLocale ??= code;
  }
  const isPseudo = () => requestedLocale === 'pseudo' && Boolean(defaultLocale);
  // The locale strings come from: the requested one when it is registered, else the default.
  const stringsLocale = () => (requestedLocale && catalogs[requestedLocale] ? requestedLocale : defaultLocale);
  // The locale formatting follows: null (the original fixed locales) when no strings are loaded.
  const activeLocale = () => (defaultLocale ? stringsLocale() : null);
  const RTL = /^(ar|he|fa|ur|ps|sd|yi|dv|ckb)(-|$)/i;
  const ACCENT = { a: '\u00e1', e: '\u00e9', i: '\u00ed', o: '\u00f3', u: '\u00fa', A: '\u00c1', E: '\u00c9', I: '\u00cd', O: '\u00d3', U: '\u00da', c: '\u00e7', n: '\u00f1', y: '\u00fd' };
  // Accents every letter it can and pads by about 40%, leaving {placeholders} alone.
  const pseudoize = (msg) => {
    const body = msg.replace(/\{\w+\}|[aeiouAEIOUcny]/g, (m) => (m.startsWith('{') ? m : ACCENT[m]));
    const plain = msg.replace(/\{\w+\}/g, '').length;
    return `[${body}${'~'.repeat(Math.ceil(plain * 0.4))}]`;
  };
  function t(key, vars = {}) {
    const code = stringsLocale();
    let msg = code ? catalogs[code][key] : undefined;
    if (msg === undefined && code !== defaultLocale && defaultLocale) msg = catalogs[defaultLocale][key];
    if (msg === undefined) {
      console.error(`[mk] no string "${key}"${code ? ` in ${code}` : ': no strings file is loaded'}`);
      return `[[${key}]]`;
    }
    if (typeof msg === 'object') msg = msg[new Intl.PluralRules(code).select(Number(vars.count ?? 0))] ?? msg.other;
    if (isPseudo()) msg = pseudoize(msg);
    return msg.replace(/\{(\w+)\}/g, (m, k) => (Object.hasOwn(vars, k) ? String(vars[k]) : m));
  }
  // Sets <html lang dir> to the locale shown. Called when a page boots.
  function applyLocale() {
    const code = activeLocale();
    if (!code) return;
    document.documentElement.lang = code;
    document.documentElement.dir = RTL.test(code) ? 'rtl' : 'ltr';
  }

  // Formatting helpers. The app's lib/format must produce identical output. They follow the active
  // locale when strings are loaded; without strings they keep their original fixed locales.
  const loc = (fixed) => activeLocale() ?? fixed;
  const format = {
    // amount is integer minor units; the currency's ISO 4217 exponent comes from Intl
    money(amount, currency) {
      const digits = new Intl.NumberFormat(loc('en'), { style: 'currency', currency }).resolvedOptions().maximumFractionDigits;
      // fixtures.format.currency_display: 'code' writes UGX 1,000,000 where the default writes USh 1,000,000
      const currencyDisplay = window.FIXTURES?.format?.currency_display || 'symbol';
      return new Intl.NumberFormat(loc('en-UG'), { style: 'currency', currency, currencyDisplay, minimumFractionDigits: digits, maximumFractionDigits: digits })
        .format(amount / 10 ** digits);
    },
    // instants arrive as RFC 3339 UTC; rendered in the viewer's own zone
    dateTime(iso) {
      return new Intl.DateTimeFormat(loc('en-GB'), { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(iso));
    },
    // a business date (YYYY-MM-DD) is a day, not an instant: never shifted by a time zone
    date(day) {
      return new Intl.DateTimeFormat(loc('en-GB'), { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${day}T00:00:00Z`));
    },
    // basis points (1 = 0.01%) to a percentage with one decimal
    percent(bp) {
      return `${(bp / 100).toFixed(1)}%`;
    },
    count(n) {
      return new Intl.NumberFormat(loc('en-GB')).format(n);
    },
    // a large number shortened for an axis or a tight label: 270M, 1.1B
    compact(n) {
      return new Intl.NumberFormat(loc('en-GB'), { notation: 'compact', maximumFractionDigits: 1 }).format(n);
    },
    // relative change, signed, one decimal: +12.4%
    change(current, previous) {
      if (!previous) return 'new';
      const pct = ((current - previous) / previous) * 100;
      return `${pct >= 0 ? '+' : '\u2212'}${Math.abs(pct).toFixed(1)}%`;
    },
  };

  // Session and permissions. Fixtures hold { session: { user_id, role }, roles: { name: {
  // label, permissions } } }. ?as=<role> previews another role. Display only, as in the app:
  // the server enforces every permission.
  const params0 = new URLSearchParams(location.search);
  function session() {
    const fx = window.FIXTURES || {};
    const roles = fx.roles || {};
    // Own keys only: ?as=__proto__ or ?as=constructor must not resolve to Object.prototype
    const has = (name) => typeof name === 'string' && Object.hasOwn(roles, name);
    const role = has(params0.get('as')) ? params0.get('as') : fx.session?.role;
    const r = has(role) ? roles[role] : { label: role, permissions: [] };
    return { user_id: fx.session?.user_id, role, label: r.label, permissions: r.permissions };
  }
  // 'public': anyone, signed in or not. 'authenticated': any signed-in user (account pages).
  const can = (permission) => permission === 'public' || permission === 'authenticated' || session().permissions.includes(permission);

  // Links keep the role, theme and locale previews (?as=, ?theme=, ?locale=), so a reviewer stays in what they chose. A #fragment survives.
  function href(path) {
    const keep = new URLSearchParams();
    for (const k of ['as', 'theme', 'locale']) if (params0.get(k)) keep.set(k, params0.get(k));
    const [target, hash = ''] = path.split('#');
    const [base, query = ''] = target.split('?');
    const merged = new URLSearchParams(query);
    keep.forEach((v, k) => merged.set(k, v));
    const qs = merged.toString();
    return (qs ? `${base}?${qs}` : base) + (hash ? `#${hash}` : '');
  }
  const navigate = (path) => { location.href = href(path); };
  const focus = (id) => { pendingFocus = id; };

  // MK.shell({ layout, nav: [{ label, href, route, permission }], forbidden, actions,
  //            state: { ... } or ({ params }) => ({ ... }),
  //            load: (fixtures, { state, session, nav, params }) => shellData,
  //            keys: { 'mod+k': 'openPalette', '/': 'openPalette', 'mod+enter': 'save' } })
  // Registered once, in the layout component's file. Becomes the app's layout route plus the
  // context that holds shell state. params is the page URL's query as a plain object, so the
  // shell reads preview flags (?session=expiring) from it, never from location.search.
  // The layout component gets { page, state, nav, session, shell, params, children }.
  //
  // keys: a combo is modifiers joined by '+' then a key, matched against KeyboardEvent.key
  // without case: 'mod+k', 'mod+enter', 'mod+shift+d', 'alt+n', 'shift+?', '/', 'escape'.
  // 'mod' is Ctrl or Cmd. A chord with ctrl, meta, mod or alt fires while typing in a field;
  // a bare key (or shift plus a key) does not, so '/' can still be typed into a search box.
  function shell(def) { shellDef = def; }

  // MK.page({
  //   id, route, title, layout,
  //   needs: { api: ['GET /v1/x -> Shape'], permission: 'x:read', uses: ['x:export'], notes: [] },
  //   state: { sort: '-created_at' },   // or ({ params }) => ({ ... }), seeded from the URL
  //   load: (fixtures, { params, scenario, state, session }) => data,   // runs on every render
  //   render: ({ state, data, status, params, scenario, session }) => html`...`,
  //   actions: { setSort(state, event, el, ctx) { ... } },
  // })
  // morph(live, fresh): make the live children match the fresh ones with the fewest changes. Nodes
  // that match by position, tag and id are kept and their attributes and text patched; the rest are
  // replaced. Form controls get their value and checked state from the new markup, and an open modal
  // dialog stays open (its open attribute is the browser's, not the markup's).
  function morph(live, fresh) {
    const a = [...live.childNodes];
    const b = [...fresh.childNodes];
    b.forEach((y, i) => {
      const x = a[i];
      if (!x) { live.appendChild(y); return; }
      const same = x.nodeType === y.nodeType && x.nodeName === y.nodeName && (x.nodeType !== 1 || (x.id || '') === (y.id || ''));
      if (!same) { live.replaceChild(y, x); return; }
      if (x.nodeType !== 1) { if (x.nodeValue !== y.nodeValue) x.nodeValue = y.nodeValue; return; }
      for (const at of [...x.attributes]) if (!y.hasAttribute(at.name) && !(x.nodeName === 'DIALOG' && at.name === 'open')) x.removeAttribute(at.name);
      for (const at of [...y.attributes]) if (x.getAttribute(at.name) !== at.value) x.setAttribute(at.name, at.value);
      if (x.nodeName === 'TEMPLATE') { x.innerHTML = y.innerHTML; return; }
      // Read what the fresh control holds before morph(x, y) moves y's children into x: after the
      // move y has lost its text node (a textarea) or the options that were added (a select whose
      // list grew), so y.textContent and y.value would no longer say what the markup chose.
      const text = x.nodeName === 'TEXTAREA' ? y.textContent : null;
      const chosen = x.nodeName === 'SELECT' ? [...y.options].filter((o) => o.selected).map((o) => o.value) : null;
      morph(x, y);
      if (x.nodeName === 'INPUT') {
        if (x.type === 'checkbox' || x.type === 'radio') x.checked = y.hasAttribute('checked');
        else if (x.value !== (y.getAttribute('value') ?? '')) x.value = y.getAttribute('value') ?? '';
      }
      if (chosen) for (const o of x.options) o.selected = chosen.includes(o.value);
      if (text !== null && x.value !== text) x.value = text;
    });
    for (let i = a.length - 1; i >= b.length; i--) a[i].remove();
  }

  // 'mod+shift+d' -> { mod: true, shift: true, key: 'd' }. The key is the last part, so '+' itself
  // is written 'shift++' or '+'. Aliases: esc, space, up, down, left, right.
  const KEY_ALIAS = { esc: 'escape', space: ' ', up: 'arrowup', down: 'arrowdown', left: 'arrowleft', right: 'arrowright' };
  function parseCombo(combo) {
    const parts = combo.toLowerCase().split('+');
    let key = parts.pop();
    if (key === '' && parts[parts.length - 1] === '') { parts.pop(); key = '+'; }
    const mods = new Set(parts.filter(Boolean));
    for (const m of mods) if (!['mod', 'ctrl', 'meta', 'alt', 'shift'].includes(m)) console.warn(`[mk] shell key "${combo}": unknown modifier ${m}`);
    return { key: KEY_ALIAS[key] || key, mod: mods.has('mod'), ctrl: mods.has('ctrl'), meta: mods.has('meta'), alt: mods.has('alt'), shift: mods.has('shift') };
  }
  function matchCombo(c, e, typing) {
    if (!e.key || e.key.toLowerCase() !== c.key) return false;
    // mod is Ctrl or Cmd, whichever the platform uses; ctrl and meta name one exactly
    const ctrl = c.ctrl || (c.mod && e.ctrlKey && !c.meta);
    const meta = c.meta || (c.mod && e.metaKey && !c.ctrl);
    if (c.mod && !(e.ctrlKey || e.metaKey)) return false;
    if (e.ctrlKey !== ctrl || e.metaKey !== meta || e.altKey !== c.alt) return false;
    const chord = c.mod || c.ctrl || c.meta || c.alt;
    // shift is checked when the combo names it or ends in a letter; a symbol such as '?' already
    // needs shift on most layouts, so 'shift' is optional there
    if ((c.shift || /^[a-z]$/.test(c.key)) && e.shiftKey !== c.shift) return false;
    // a bare key types into a field, so it is a shortcut only outside one
    return chord || !typing;
  }

  function page(def) {
    const params = Object.fromEntries(params0);
    const scenario = ['empty', 'loading', 'error'].includes(params.state) ? params.state : 'default';
    const sh = shellDef || {};
    const seed = (s) => structuredClone((typeof s === 'function' ? s({ params }) : s) || {});
    const pageState = seed(def.state);
    const state = { ...seed(sh.state), ...pageState };
    const actions = { ...(sh.actions || {}), ...(def.actions || {}) };
    const root = document.getElementById('app');
    if (!root) throw new Error('[mk] page needs <div id="app"></div>');

    applyLocale();
    document.body.dataset.page = def.id;
    document.body.dataset.route = def.route;
    if (def.title) document.title = def.title;

    const fixtures = window.FIXTURES || {};
    const status = scenario === 'loading' ? 'loading' : scenario === 'error' ? 'error' : 'ready';
    const permission = def.needs?.permission;
    const allowed = !permission || can(permission);
    // A nav entry's labelKey is resolved here, at render, so the menu follows the locale and the app
    // imports keys rather than English.
    const navFor = () => (sh.nav || []).filter((n) => can(n.permission)).map((n) => ({ ...n, href: href(n.href), label: n.labelKey ? t(n.labelKey) : n.label }));
    const shellData = () => (sh.load ? sh.load(fixtures, { state, session: session(), nav: navFor(), params }) : null);
    const ctx = () => ({ params, fixtures, session: session(), can, navigate, href, focus, shellData: shellData() });

    function render() {
      const s = session();
      const data = allowed && status === 'ready' && def.load ? def.load(fixtures, { params, scenario, state, session: s }) : null;
      const body = allowed ? def.render({ state, data, status, params, scenario, session: s }) : components[sh.forbidden]?.({}) ?? '';
      const layoutName = def.layout ?? sh.layout;
      const layout = layoutName && components[layoutName];
      const nav = navFor();

      // Patch the page in place, as a framework does: elements that are still there are kept, so
      // focus, the caret, a scroll position and a slider being dragged all survive the re-render.
      const active = document.activeElement;
      const keep = active && active.id && root.contains(active) ? { id: active.id } : null;
      const next = document.createElement('template');
      next.innerHTML = String(layout ? layout({ page: def, state, nav, session: s, shell: shellData(), params, children: body }) : body);
      morph(root, next.content);

      root.querySelectorAll('dialog[data-modal]').forEach((d) => { if (!d.open) d.showModal(); });
      const target = pendingFocus ? document.getElementById(pendingFocus) : keep && document.getElementById(keep.id);
      if (target && target !== document.activeElement) target.focus();
      pendingFocus = null;
      for (const fn of renderHooks) fn({ page: def, status: allowed ? status : 'forbidden', session: s, scenario, params, data });
    }

    function run(name, event, el) {
      const action = actions[name];
      if (!action) { console.warn(`[mk] no action "${name}" on page ${def.id}`); return; }
      const result = action(state, event, el, ctx());
      if (result !== false) render();
    }

    // The nearest element whose action listens for this event type handles it, so an input can
    // take `input` while its wrapper takes `keydown`.
    function dispatch(event) {
      let el = event.target.closest?.('[data-action]');
      while (el && root.contains(el)) {
        const tag = el.tagName;
        const wanted = el.dataset.on || (tag === 'FORM' ? 'submit' : ['SELECT', 'INPUT', 'TEXTAREA'].includes(tag) ? 'change' : 'click');
        if (wanted === event.type) {
          if (event.type === 'submit' || event.type === 'cancel' || tag === 'A') event.preventDefault();
          run(el.dataset.action, event, el);
          return;
        }
        el = el.parentElement?.closest('[data-action]');
      }
    }
    ['click', 'change', 'input', 'submit', 'keydown'].forEach((t) => root.addEventListener(t, dispatch));
    root.addEventListener('cancel', dispatch, true); // a dialog's Escape; cancel does not bubble

    // Shell keyboard shortcuts, on pages inside the shell's layout only (combo syntax at MK.shell).
    const inShell = (def.layout ?? sh.layout) === sh.layout;
    const shortcuts = Object.entries(sh.keys || {}).map(([combo, name]) => ({ chord: parseCombo(combo), name }));
    document.addEventListener('keydown', (e) => {
      if (!inShell || e.isComposing) return;
      const typing = Boolean(e.target.closest?.('input, textarea, select, [contenteditable]'));
      for (const { chord, name } of shortcuts) {
        if (matchCombo(chord, e, typing)) { e.preventDefault(); run(name, e, e.target); return; }
      }
    });

    currentPage = { def, scenario, initialState: pageState };
    render();
    mountRolePreview();
  }

  // A role picker for the client reviewing the mockup. Not part of the design: it is never
  // rendered under automation, so the scripts see exactly what the app will show.
  function mountRolePreview() {
    const roles = (window.FIXTURES || {}).roles;
    if (!roles || navigator.webdriver || document.getElementById('mk-role-preview')) return;
    const style = document.createElement('style');
    style.textContent = '#mk-role-preview{position:fixed;right:12px;bottom:12px;z-index:9999;background:#111;color:#fff;font:12px system-ui;padding:6px 10px;border-radius:8px;opacity:.9}#mk-role-preview select{font:inherit;margin-left:6px}';
    const box = document.createElement('label');
    box.id = 'mk-role-preview';
    box.textContent = 'Mockup: preview as';
    const select = document.createElement('select');
    for (const [name, r] of Object.entries(roles)) {
      const o = document.createElement('option');
      o.value = name; o.textContent = r.label; o.selected = name === session().role;
      select.append(o);
    }
    select.addEventListener('change', () => { const p = new URLSearchParams(location.search); p.set('as', select.value); location.search = p.toString(); });
    box.append(select);
    document.head.append(style);
    document.body.append(box);
  }

  // Introspection, used by scripts/inventory.mjs
  function inspect() {
    const p = currentPage;
    return {
      page: p && {
        id: p.def.id, route: p.def.route, title: p.def.title, layout: p.def.layout ?? shellDef?.layout ?? null,
        needs: p.def.needs || {}, initialState: p.initialState || {},
        actions: Object.keys(p.def.actions || {}), scenario: p.scenario, loads: Boolean(p.def.load),
      },
      shell: shellDef && { nav: shellDef.nav || [], keys: shellDef.keys || {}, actions: Object.keys(shellDef.actions || {}), forbidden: shellDef.forbidden || null },
      roles: (window.FIXTURES || {}).roles || {},
      session: session(),
      componentsRegistered: Object.keys(components),
      componentMeta,
      componentsUsed: [...used],
      i18n: { defaultLocale, locale: activeLocale(), pseudo: isPseudo(), keys: Object.fromEntries(Object.entries(catalogs).map(([c, tbl]) => [c, Object.keys(tbl)])) },
    };
  }

  window.MK = { html, raw, component, components, shell, page, format, can, session, href, onRender, inspect, strings, t };
})();
