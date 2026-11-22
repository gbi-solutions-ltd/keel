/**
 * project.mjs: mockup.config.json against lib/mockup-engine/mockup-config.schema.json, the readiness rules
 * for a port, and the defaults every script takes from the config (pins, locale, stack).
 *
 * The schema is the single source: its x-tier marks which project fields are asked at intake (1)
 * and which may be deferred with an owner and a date until the port (2). The validator is
 * lib/json-schema.mjs, shared with the contract check.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { validate } from './json-schema.mjs';
import { screenProblems } from './screens.mjs';

export const SCHEMA_PATH = fileURLToPath(new URL('../../mockup-config.schema.json', import.meta.url));

let cached;
export function loadSchema() {
  cached ??= JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
  return cached;
}

export { validate };

/** The project fields by tier, read from the schema. */
export function tiers(schema = loadSchema()) {
  const props = schema.$defs.project.properties;
  const t = { 1: [], 2: [] };
  for (const [k, v] of Object.entries(props)) t[v['x-tier']]?.push(k);
  return t;
}

/**
 * Every problem with a config that is wrong whatever stage the mockup is at: the schema, plus the
 * rules the schema cannot say. Returns a list of "path: problem" strings.
 */
export function configProblems(config, schema = loadSchema()) {
  const out = validate(schema, config);
  out.push(...screenProblems(config));
  const p = config?.project;
  if (!p || typeof p !== 'object') return out;
  const df = p.designFramework;
  if (df && df.kind && df.kind !== 'none' && !df.name) out.push('project.designFramework: name is required when kind is not none');
  if (p.i18n?.locales && p.i18n.defaultLocale && !p.i18n.locales.includes(p.i18n.defaultLocale))
    out.push(`project.i18n: defaultLocale ${p.i18n.defaultLocale} is not in locales`);
  if (p.auth?.signIn === 'idp-hosted' && !p.auth.provider) out.push('project.auth: provider is required when signIn is idp-hosted');
  if (p.target && !p.target.deferred && p.target.kind === 'existing-repo' && !p.target.path) out.push('project.target: path is required for an existing repo');
  if (p.contract && !p.contract.deferred && p.contract.source === 'backend' && !p.contract.location) out.push('project.contract: location is required when the backend owns the contract');
  if (p.stack && !p.stack.deferred && p.stack.decidedBy === 'design-architecture' && !p.stack.record) out.push('project.stack: record is required when design-architecture chose it');
  const decided = p.stack && !p.stack.deferred ? p.stack.name : null;
  if (config.targetStack && decided && config.targetStack !== decided) out.push(`targetStack ${config.targetStack} disagrees with project.stack.name ${decided}`);
  return out;
}

/** What still blocks a port: tier 1 answers missing, tier 2 neither decided nor deferred. */
export function readiness(config, schema = loadSchema()) {
  const p = config?.project || {};
  const t = tiers(schema);
  const open = [];
  for (const k of t[1]) if (!(k in p)) open.push({ field: `project.${k}`, tier: 1, detail: 'not answered: asked at intake (skills/mockup/references/intake.md)' });
  for (const k of t[2]) if (!(k in p)) open.push({ field: `project.${k}`, tier: 2, detail: 'neither decided nor deferred with an owner and a date' });
  // asked at intake with the formats (skills/mockup/references/intake.md, question 7), kept at the top level for the scripts
  if (!config?.timezoneId) open.push({ field: 'timezoneId', tier: 1, detail: 'not answered: the business time zone, asked at intake (skills/mockup/references/intake.md)' });
  const deferred = t[2].filter((k) => p[k]?.deferred).map((k) => ({ field: `project.${k}`, ...p[k].deferred }));
  return { open, deferred };
}

/** True when s is YYYY-MM-DD and a real calendar date (2026-02-30 and 2026-13-01 are not). */
export function isCalendarDate(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

/** A config read from JSON is an object: null, an array or a scalar is no config at all. */
export const isConfigObject = (config) => Boolean(config) && typeof config === 'object' && !Array.isArray(config);

/** Today as YYYY-MM-DD, in the local time zone. */
export const today = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** The deferrals (readiness().deferred) whose date has passed: by is before on (YYYY-MM-DD). */
export const overdue = (deferred, on = today()) => deferred.filter((d) => typeof d.by === 'string' && d.by < on);

/** The checklist items (skills/mockup/references/modules.md), shared by the inventory and check-config. */
export const CHECKLIST = ['user-management', 'roles-admin', 'audit-log', 'notifications', 'settings', 'developer-access',
  'session-timeout', 'password-reset', 'approvals', 'onboarding', 'system-pages', 'bulk-actions', 'saved-views',
  'file-upload', 'localisation', 'dark-mode', 'print', 'privacy'];

/** The checklist items each module settles when it is on. */
export const MODULE_COVERS = {
  'auth-mfa': [], 'tours-help': [], 'users-roles': ['user-management', 'roles-admin'], 'audit-log': ['audit-log'],
  'session-password': ['session-timeout', 'password-reset'], notifications: ['notifications'], 'system-pages': ['system-pages'],
};

/** The checklist items a project answer settles, as a module settles its own. */
export function settledByProject(config) {
  const p = config?.project || {};
  const s = {};
  if (p.i18n) s.localisation = 'designed';
  if (p.theming) s['dark-mode'] = p.theming === 'light' ? 'not-needed' : 'designed';
  return s;
}

/** --clock and --seed when passed, else the config's pins. */
export function pinDefaults(config, clockArg, seedArg) {
  return { clock: clockArg ?? config?.pins?.clock, seed: seedArg ?? (config?.pins?.seed !== undefined ? String(config.pins.seed) : undefined) };
}

/** The time zone the checks render in: config.timezoneId, else UTC (never the machine's own zone). */
export const configZone = (config) => config?.timezoneId ?? 'UTC';

/** The browser locale for the checks: config.locale, else the project's default locale, else en-GB. */
export const configLocale = (config) => config?.locale ?? config?.project?.i18n?.defaultLocale ?? 'en-GB';

/**
 * The app-mode diff threshold when the config sets no diff.maxMismatchPercent: 0, the gate for every
 * design framework kind but js-kit, whose components render through the kit's own code (0.2 there).
 */
export const appMaxMismatchDefault = (config) => (config?.project?.designFramework?.kind === 'js-kit' ? 0.2 : 0);

/** The decided stack: project.stack.name, else targetStack, else null. */
export const projectStack = (config) => (config?.project?.stack && !config.project.stack.deferred ? config.project.stack.name : null) ?? config?.targetStack ?? null;

/**
 * Every decision still open, as check-config prints them: the open project fields and zone from
 * readiness, then each checklist item neither answered, covered by a module, nor settled by a
 * project answer. Returns { open: [{ field, detail }], deferred }.
 */
export function openDecisions(config) {
  const checklist = { ...(config?.checklist || {}) };
  for (const m of config?.modules || []) for (const item of MODULE_COVERS[m] || []) checklist[item] = 'designed';
  for (const [item, answer] of Object.entries(settledByProject(config))) checklist[item] ??= answer;
  const ready = readiness(config);
  return {
    open: [
      ...ready.open.map((o) => ({ field: o.field, detail: `tier ${o.tier} ${o.detail}` })),
      ...CHECKLIST.filter((k) => !checklist[k]).map((k) => ({ field: `checklist ${k}`, detail: 'undecided (skills/mockup/references/modules.md)' })),
    ],
    deferred: ready.deferred,
  };
}
