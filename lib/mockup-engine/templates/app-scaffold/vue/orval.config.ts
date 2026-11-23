import { defineConfig } from 'orval';

// Generated into src/api/generated, which is gitignored: never edit it, regenerate with
// `npm run generate`. The contract in api/openapi.yaml is the signed-off source of truth, imported
// byte for byte (import-mockup --only contract).
const input = { target: './api/openapi.yaml' };

export default defineConfig({
  client: {
    input,
    output: {
      target: './src/api/generated/endpoints.ts',
      schemas: './src/api/generated/model',
      mode: 'tags-split',
      client: 'vue-query',
      httpClient: 'fetch',
      override: {
        mutator: { path: './src/api/http.ts', name: 'apiFetch' },
        fetch: { includeHttpResponseReturnType: false },
      },
      clean: true,
      // Formatted with the app's own Biome, so generated code reads like the rest (biome.json keeps
      // it out of the linter, not out of the formatter).
      formatter: 'biome',
    },
  },
  zod: {
    input,
    output: { target: './src/api/generated/zod.ts', client: 'zod', mode: 'single', formatter: 'biome' },
  },
});
