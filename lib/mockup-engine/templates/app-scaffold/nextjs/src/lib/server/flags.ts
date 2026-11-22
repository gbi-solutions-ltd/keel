import 'server-only';
import { headers } from 'next/headers';
import type { VisitFlags } from '@/mocks/visits';

// Every guard writes `process.env.MOCKS === 'true'` out where it branches. next.config inlines the
// value, and only a literal comparison at the branch lets the bundler drop the mock code: an imported
// constant kept the fixtures in the production build's server chunks.

/** The mock visit's flags, from the request headers proxy.ts sets. Null outside a mocked build. */
export async function mockFlags(): Promise<VisitFlags | null> {
  if (process.env.MOCKS !== 'true') return null;
  const h = await headers();
  return {
    visit: h.get('x-mock-visit') ?? 'none',
    role: h.get('x-mock-role'),
    // Absent: keep the visit's; present (even empty): this document load's value.
    state: h.has('x-mock-state') ? h.get('x-mock-state') : undefined,
    system: h.has('x-mock-system') ? h.get('x-mock-system') : undefined,
  };
}
