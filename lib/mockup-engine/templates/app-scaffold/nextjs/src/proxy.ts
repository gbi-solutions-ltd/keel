import { type NextRequest, NextResponse } from 'next/server';
import headersFile from '../security-headers.json' with { type: 'json' };

/**
 * Runs before every request but static assets.
 *
 * - A production build proxies `/api/*` to the backend for frontend (BACKEND_URL, read at start), so
 *   the browser sees one origin, and `/__sample/*` only with
 *   PROXY_SAMPLE_ROUTES=1 (a local run against the sample backend).
 * - Every other answer gets the security headers from security-headers.json, the CSP with a fresh
 *   nonce, which Next.js puts on its own scripts. `next dev` adds `'unsafe-eval'`, which
 *   React needs for its development stacks; a build never does.
 * - In a mocked build only (MOCKS, inlined): each document load starts a new mock visit (its id in a
 *   cookie), `?as` is kept in a cookie for the tab, and that load's `?state` and `?system` are passed
 *   as request headers. The first render cannot read a cookie set in this answer, so all of it goes
 *   to the server as request headers as well (stacks/nextjs.md, Mocks and scenarios).
 */
const DEV = process.env.NODE_ENV === 'development';
const API = /^\/api(\/|$)/;
// The sample backend's dev routes (the stand-in sign-in, reset, stats): proxied only when the server
// is told to, for a local run. Elsewhere they would republish a loopback-only backend's dev routes on
// this server's public port (stacks/nextjs.md, Serving and the backend).
const SAMPLE = /^\/__sample(\/|$)/;

/**
 * The backend URL for a proxied path, or null when the path, once its dot segments are resolved, is no
 * longer under the prefix it was let in by. The check is on the resolved URL: a raw path such as
 * `/api/%2e%2e/x` passes a check on itself and then leaves `/api` (stacks/nextjs.md, Serving and the backend).
 */
export function backendUrl(pathname: string, search: string, target: string): URL | null {
  const prefix = SAMPLE.test(pathname) ? SAMPLE : API.test(pathname) ? API : null;
  if (!prefix) return null;
  const url = new URL(`${pathname}${search}`, target);
  return url.origin === new URL(target).origin && prefix.test(url.pathname) ? url : null;
}

function csp(nonce: string): string {
  const policy = headersFile.headers['Content-Security-Policy'].join('; ').replaceAll('{nonce}', `'nonce-${nonce}'`);
  return DEV ? policy.replace("'strict-dynamic'", "'strict-dynamic' 'unsafe-eval'") : policy;
}

export function proxy(request: NextRequest) {
  const { pathname, search, searchParams } = request.nextUrl;
  if (API.test(pathname) || SAMPLE.test(pathname)) {
    if (process.env.MOCKS === 'true') {
      // The mock API answers /api (app/api/[...path]/route.ts); the visit comes from its cookie.
      const h = new Headers(request.headers);
      h.set('x-mock-visit', request.cookies.get('mock_visit')?.value ?? 'none');
      h.set('x-mock-role', request.cookies.get('mock_as')?.value ?? '');
      return NextResponse.next({ request: { headers: h } });
    }
    const sample = SAMPLE.test(pathname);
    if (sample && process.env.PROXY_SAMPLE_ROUTES !== '1') return new NextResponse('Not found', { status: 404 });
    const target = process.env.BACKEND_URL;
    if (!target) return new NextResponse('BACKEND_URL is not set', { status: 503 });
    const url = backendUrl(pathname, search, target);
    return url ? NextResponse.rewrite(url) : new NextResponse('Not found', { status: 404 });
  }

  const nonce = btoa(crypto.randomUUID());
  const policy = csp(nonce);
  const h = new Headers(request.headers);
  h.set('x-nonce', nonce);
  h.set('Content-Security-Policy', policy);
  h.set('x-pathname', `${pathname}${search}`);

  let visit: string | null = null;
  let role: string | null = null;
  if (process.env.MOCKS === 'true') {
    const documentLoad = request.headers.get('sec-fetch-dest') === 'document' && !request.headers.has('rsc');
    visit = documentLoad ? crypto.randomUUID() : (request.cookies.get('mock_visit')?.value ?? crypto.randomUUID());
    role = searchParams.get('as') ?? request.cookies.get('mock_as')?.value ?? null;
    h.set('x-mock-visit', visit);
    h.set('x-mock-role', role ?? '');
    if (documentLoad) {
      h.set('x-mock-state', searchParams.get('state') ?? '');
      h.set('x-mock-system', searchParams.get('system') ?? '');
    }
  }

  const response = NextResponse.next({ request: { headers: h } });
  response.headers.set('Content-Security-Policy', policy);
  if (visit) response.cookies.set('mock_visit', visit, { httpOnly: true, sameSite: 'lax', path: '/' });
  if (process.env.MOCKS === 'true' && searchParams.has('as') && role)
    response.cookies.set('mock_as', role, { httpOnly: true, sameSite: 'lax', path: '/' });
  return response;
}

export const config = {
  matcher: [
    {
      source: '/((?!_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
};
