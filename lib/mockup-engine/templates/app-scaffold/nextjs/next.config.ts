import type { NextConfig } from 'next';
import { PHASE_DEVELOPMENT_SERVER } from 'next/constants';
import headersFile from './security-headers.json' with { type: 'json' };

/**
 * MOCKS is a build-time constant: `next dev` and `MOCKS=true next build` (the mocked build, into its
 * own folder) inline `true`; a production build inlines `false`, so the mock API, the fixtures and the
 * preview flags are dead code there. Setting MOCKS=true when starting a server only switches the
 * folder `next start` serves to `.next-mocked`, which a production host never has (the deploy ships
 * `.next` only). The mock clock is the mockup's pin (mockup.config.json pins.clock).
 */
export default function config(phase: string): NextConfig {
  const mocks = phase === PHASE_DEVELOPMENT_SERVER || process.env.MOCKS === 'true';
  // Every header but the CSP, which proxy.ts sets per request with its nonce, also on static files.
  const plain = Object.entries(headersFile.headers)
    .filter(([name]) => name !== 'Content-Security-Policy')
    .map(([key, value]) => ({ key, value: Array.isArray(value) ? value.join('; ') : value }));
  return {
    distDir: phase !== PHASE_DEVELOPMENT_SERVER && mocks ? '.next-mocked' : '.next',
    env: { MOCKS: mocks ? 'true' : 'false', MOCK_NOW: mocks ? '<pins.clock>' : '' },
    devIndicators: false,
    poweredByHeader: false,
    reactStrictMode: true,
    headers: async () => [{ source: '/:path*', headers: plain }],
  };
}
