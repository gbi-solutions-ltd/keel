import { defineConfig } from 'orval';

// Generated into src/api/generated, which is gitignored: never edit it, regenerate with
// `npm run generate`. The contract in api/openapi.yaml is the signed-off source of truth, imported
// byte for byte (import-mockup --only contract). Two clients from it: react-query hooks for the
// browser (through src/api/http.ts, same origin /api), and plain fetch functions for the server
// (through src/lib/server/api.ts, which forwards the user's cookie to the backend).
const input = { target: './api/openapi.yaml' };

export default defineConfig({
  browser: {
    input,
    output: {
      mode: 'tags-split',
      httpClient: 'fetch',
      formatter: 'biome',
      target: './src/api/generated/browser/endpoints.ts',
      schemas: './src/api/generated/model',
      client: 'react-query',
      override: {
        mutator: { path: './src/api/http.ts', name: 'apiFetch' },
        fetch: { includeHttpResponseReturnType: false },
      },
      clean: true,
    },
  },
  server: {
    input,
    output: {
      mode: 'tags-split',
      httpClient: 'fetch',
      formatter: 'biome',
      target: './src/api/generated/server/endpoints.ts',
      schemas: './src/api/generated/model',
      client: 'fetch',
      override: {
        mutator: { path: './src/lib/server/api.ts', name: 'serverFetch' },
        fetch: { includeHttpResponseReturnType: false },
      },
    },
  },
  zod: {
    input,
    output: { target: './src/api/generated/zod.ts', client: 'zod', mode: 'single', formatter: 'biome' },
  },
});
