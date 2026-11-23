/**
 * The one HTTP client every generated endpoint goes through (Orval `mutator`).
 *
 * Keel defaults it applies: a timeout on every call, the session cookie rather than a token in
 * JavaScript, a CSRF header on state-changing calls, and errors mapped to the contract's error
 * envelope so callers branch on `code`, never on a message.
 */
import type { ErrorEnvelope } from './generated/model';

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api';
// An API on another origin (same site, such as api.example.com for app.example.com) gets the
// session cookie only with credentials 'include', and its CORS allowlist must name this origin.
// One on this origin, the default, keeps 'same-origin': the cookie never travels anywhere else.
const CROSS_ORIGIN = new URL(BASE_URL, window.location.href).origin !== window.location.origin;
const TIMEOUT_MS = 10_000;
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/** A failed API call. `code` comes from the error envelope, or is one of ours for transport failures. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly requestId: string | undefined,
    /** Extra facts the envelope carries, such as attempts_remaining. */
    readonly details: Record<string, unknown> = {},
  ) {
    super(`API error ${status} ${code}`);
    this.name = 'ApiError';
  }

  /** 5xx and transport failures may succeed on retry; 4xx will fail identically. */
  get retryable(): boolean {
    return this.status === 0 || this.status >= 500;
  }
}

// The CSRF token the server sent last (an X-CSRF-Token response header). An app on another origin
// cannot read the API's csrf_token cookie, so the server repeats the token on every answer. The
// cookie wins when there is one: it changes with the session cookie at every sign-in, even one
// in another tab, while this copy may be stale.
let csrfFromServer: string | undefined;

function readCookie(name: string): string | undefined {
  return document.cookie
    .split('; ')
    .find((c) => c.startsWith(`${name}=`))
    ?.slice(name.length + 1);
}

/**
 * Sends a request and returns the parsed body, or throws ApiError.
 * @param path Path from the generated client, without the base URL.
 * @param init Request options; a caller's AbortSignal is combined with the timeout.
 */
export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method ?? 'GET').toUpperCase();
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (!SAFE_METHODS.has(method)) {
    // Double-submit CSRF: the csrf_token cookie, or (an API on another origin) the token the server
    // last sent.
    const cookie = readCookie('csrf_token');
    const csrf = cookie ? decodeURIComponent(cookie) : csrfFromServer;
    if (csrf) headers.set('X-CSRF-Token', csrf);
  }
  const timeout = AbortSignal.timeout(TIMEOUT_MS);
  const signal = init.signal ? AbortSignal.any([init.signal, timeout]) : timeout;

  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      ...init,
      method,
      headers,
      signal,
      credentials: CROSS_ORIGIN ? 'include' : 'same-origin',
    });
  } catch (err) {
    if (init.signal?.aborted) throw err;
    throw new ApiError(0, timeout.aborted ? 'timeout' : 'network_error', undefined);
  }

  const token = res.headers.get('X-CSRF-Token');
  if (token) csrfFromServer = token;

  if (res.status === 204) return undefined as T;
  const body: unknown = await res.json().catch(() => undefined);
  if (!res.ok) {
    const envelope = body as Partial<ErrorEnvelope> | undefined;
    throw new ApiError(
      res.status,
      envelope?.error?.code ?? 'unknown_error',
      envelope?.error?.request_id,
      envelope?.error?.details ?? {},
    );
  }
  return body as T;
}
