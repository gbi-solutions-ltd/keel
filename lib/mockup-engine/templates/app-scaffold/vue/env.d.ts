/// <reference types="vite/client" />

// Everything prefixed VITE_ is compiled into the public bundle: never a secret.
interface ImportMetaEnv {
  /** The BFF, same origin by default (`/api`); another origin of the same site is supported. */
  readonly VITE_API_BASE_URL?: string;
  /**
   * The API's sign-in, when it is on another origin and the app has no sign-in screen (such as
   * `https://api.example.com/auth/sign-in`); unset, a page load with no session reloads, and the
   * BFF on this origin signs it in.
   */
  readonly VITE_SIGN_IN_URL?: string;
  /** `true` only in `.env.mocked`: a production build that still serves fixtures through MSW. */
  readonly VITE_ENABLE_MOCKS?: string;
  /** OpenTelemetry collector; unset keeps telemetry off. */
  readonly VITE_OTEL_EXPORTER_OTLP_ENDPOINT?: string;
  readonly VITE_APP_ENV?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
