/// <reference types="vitest/config" />

import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath, URL } from 'node:url';
import react from '@vitejs/plugin-react';
import { msw } from 'msw/vite';
import { defineConfig, loadEnv, type Plugin } from 'vite';

// Vite writes this placeholder as the nonce of every script and stylesheet tag it emits and into
// <meta property="csp-nonce">; the preview replaces it with a fresh nonce on every HTML response.
const NONCE_PLACEHOLDER = '__CSP_NONCE__';

/**
 * Security headers, from security-headers.json: the one source for `vite preview` here, the server
 * or CDN in production, and the engine's header check of a served URL (headers.mjs). No
 * 'unsafe-inline': CSS Modules and a bundled entry script need neither inline scripts nor inline
 * styles. {origin:NAME} is the origin of the URL in that variable, or nothing when it is unset.
 * `{nonce}` becomes 'nonce-<value>', as the engine's renderHeaders (scripts/lib/production.mjs) fills
 * it; without a nonce (static files) the source is left out. Write `{nonce}` into style-src only when
 * a design framework injects styles at runtime (stacks/react-vite.md, A kit that injects styles).
 */
function securityHeaders(env: Record<string, string | undefined>, nonce?: string): Record<string, string> {
  const file = JSON.parse(readFileSync(new URL('./security-headers.json', import.meta.url), 'utf8')) as {
    headers: Record<string, string | string[]>;
  };
  const fill = (value: string) =>
    value
      .replace(/ ?\{nonce\}/g, nonce ? ` 'nonce-${nonce}'` : '')
      .replace(/\{origin:([A-Z0-9_]+)\}/g, (_, name: string) => {
        const url = env[name];
        return url ? new URL(url).origin : '';
      })
      .replace(/ {2,}/g, ' ')
      .replace(/ ;/g, ';')
      .trim();
  return Object.fromEntries(
    Object.entries(file.headers).map(([name, v]) => [name, fill(Array.isArray(v) ? v.join('; ') : v)]),
  );
}

/**
 * `vite preview` only: every HTML response gets a fresh nonce, in the CSP header and in the page. A fixed
 * nonce in static headers would be no protection at all. Production must do the same per request (a
 * templating step at the server or an edge function at the CDN); a static file host cannot.
 */
function perRequestNonce(env: Record<string, string | undefined>): Plugin {
  return {
    name: 'per-request-csp-nonce',
    configurePreviewServer(server) {
      const outDir = server.config.build.outDir;
      server.middlewares.use((req, res, next) => {
        const path = new URL(req.url ?? '/', 'http://localhost').pathname;
        const isPage = req.method === 'GET' && (path.endsWith('.html') || !path.slice(1).includes('.'));
        if (!isPage) return next();
        const nonce = randomBytes(16).toString('base64');
        const html = readFileSync(`${outDir}/index.html`, 'utf8').replaceAll(NONCE_PLACEHOLDER, nonce);
        for (const [k, v] of Object.entries(securityHeaders(env, nonce))) res.setHeader(k, v);
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.setHeader('Cache-Control', 'no-store');
        res.end(html);
      });
    },
  };
}

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  const mocks = command === 'serve' || env.VITE_ENABLE_MOCKS === 'true';
  // The variables security-headers.json names as {origin:NAME}. Only a full URL has an origin: the
  // API's default, the path `/api` (.env.example), is the page's own origin, already 'self'.
  const api = process.env.VITE_API_BASE_URL ?? env.VITE_API_BASE_URL;
  const headerEnv = {
    VITE_API_BASE_URL: api && URL.canParse(api) ? api : undefined,
    VITE_OTEL_EXPORTER_OTLP_ENDPOINT:
      process.env.VITE_OTEL_EXPORTER_OTLP_ENDPOINT ?? env.VITE_OTEL_EXPORTER_OTLP_ENDPOINT,
  };
  return {
    // worker-only: the plugin serves (dev) or emits (mocked build) mockServiceWorker.js; mocks start
    // through the stable setupWorker API in src/mocks/browser.ts, only in dev or a --mode mocked build.
    plugins: [react(), perRequestNonce(headerEnv), ...(mocks ? [msw({ mode: 'worker-only' })] : [])],
    html: { cspNonce: NONCE_PLACEHOLDER },
    // Tests live in tests/, mirroring src/, and import what they test as @/path.
    resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
    // A mocked build goes to its own folder, so `dist` never holds the mocks or the fixtures.
    build: { outDir: env.VITE_ENABLE_MOCKS === 'true' ? 'dist-mocked' : 'dist' },
    // Static files get the same headers; HTML answers get them from perRequestNonce, with the nonce.
    preview: { headers: securityHeaders(headerEnv) },
    test: {
      environment: 'jsdom',
      include: ['tests/**/*.test.{ts,tsx}'],
      setupFiles: ['./tests/support/setup.ts'],
      css: { modules: { classNameStrategy: 'non-scoped' } },
    },
  };
});
