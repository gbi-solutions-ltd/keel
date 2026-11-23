import 'server-only';
import { cookies, headers } from 'next/headers';
import type { ErrorEnvelope } from '@/api/generated/model';
import { ApiError } from '@/api/http';
import { mockFlags } from './flags';

/**
 * The server's HTTP client (Orval's `mutator` for the server's fetch functions). It calls the
 * backend for frontend as the user: their cookie header goes with every call, and a state-changing
 * call carries the `csrf_token` cookie's value as `X-CSRF-Token` (the backend's double-submit check;
 * on this server it passes by construction, so the protection is Next.js's Origin check on Server
 * Actions, stacks/nextjs.md, Serving and the backend). A timeout on every call; errors mapped to the contract's envelope
 * as ApiError, as the browser's client does. In a mocked build the mock API answers instead, with
 * no network at all.
 *
 * BACKEND_URL is read when the server starts (`next start`), never compiled into a bundle.
 */
const TIMEOUT_MS = 10_000;
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

function backend(): string {
  const url = process.env.BACKEND_URL;
  if (!url) throw new Error('BACKEND_URL is not set: the server cannot reach the API');
  return url.replace(/\/$/, '');
}

/**
 * Sends a request to the API as the signed-in user and returns the parsed body, or throws ApiError.
 * @param path Path from the generated client, without `/api` (`/v1/items?q=x`).
 */
export async function serverFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method ?? 'GET').toUpperCase();
  const h = new Headers(init.headers);
  h.set('Accept', 'application/json');
  const cookie = (await headers()).get('cookie');
  if (cookie) h.set('Cookie', cookie);
  if (!SAFE_METHODS.has(method)) {
    const csrf = (await cookies()).get('csrf_token')?.value;
    if (csrf) h.set('X-CSRF-Token', decodeURIComponent(csrf));
  }
  const timeout = AbortSignal.timeout(TIMEOUT_MS);
  const signal = init.signal ? AbortSignal.any([init.signal, timeout]) : timeout;

  let res: Response;
  try {
    if (process.env.MOCKS === 'true') {
      const { mockFetch } = await import('@/mocks/visits');
      const flags = (await mockFlags()) ?? { visit: 'none', role: null };
      res = await mockFetch(
        new Request(`http://mock.local/api${path}`, { ...init, method, headers: h, signal }),
        flags,
      );
    } else {
      res = await fetch(`${backend()}/api${path}`, { ...init, method, headers: h, signal, cache: 'no-store' });
    }
  } catch (err) {
    if (init.signal?.aborted) throw err;
    throw new ApiError(0, timeout.aborted ? 'timeout' : 'network_error', undefined);
  }
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
