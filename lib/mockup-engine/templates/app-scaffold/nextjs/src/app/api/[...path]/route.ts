/**
 * The browser's /api in a mocked build only: answered by the mock API for this visit (proxy.ts puts
 * the visit and role in the request headers). A production build never reaches this file, because
 * proxy.ts rewrites /api to the backend first; it answers 404 there, and MOCKS is inlined false, so
 * the mock code is not in that build.
 */
import type { NextRequest } from 'next/server';

async function answer(request: NextRequest): Promise<Response> {
  if (process.env.MOCKS !== 'true') return new Response('Not found', { status: 404 });
  const { mockFetch } = await import('@/mocks/visits');
  return mockFetch(new Request(request.url, request), {
    visit: request.headers.get('x-mock-visit') ?? 'none',
    role: request.headers.get('x-mock-role'),
  });
}

export const GET = answer;
export const POST = answer;
