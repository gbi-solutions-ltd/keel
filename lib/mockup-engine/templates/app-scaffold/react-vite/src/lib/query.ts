import { MutationCache, QueryCache, QueryClient } from '@tanstack/react-query';
import { ApiError } from '../api/http';
import { reportError } from './telemetry';

const MAX_ATTEMPTS = 3;

// A 4xx is the caller's mistake or an expected answer, handled in the UI. Only failures a human
// must look at are reported (keel observability: not error).
const reportable = (error: unknown) => !(error instanceof ApiError) || error.status === 0 || error.status >= 500;

/** Exponential backoff with full jitter, so clients that failed together do not retry together. */
function retryDelay(attempt: number): number {
  return Math.random() * Math.min(4_000, 300 * 2 ** attempt);
}

function opFromKey(key: readonly unknown[]): string {
  return `query ${String(key[0] ?? 'unknown')}`;
}

/**
 * One query client for the app. Reads retry only what can succeed on retry (5xx, network,
 * timeout) and only at this layer; writes never retry here.
 */
export function createQueryClient(): QueryClient {
  return new QueryClient({
    queryCache: new QueryCache({
      onError: (error, query) => {
        if (!reportable(error)) return;
        reportError(error, {
          op: opFromKey(query.queryKey),
          request_id: error instanceof ApiError ? error.requestId : undefined,
        });
      },
    }),
    mutationCache: new MutationCache({
      onError: (error, _v, _c, mutation) => {
        if (!reportable(error)) return;
        reportError(error, { op: `mutation ${String(mutation.options.mutationKey?.[0] ?? 'unknown')}` });
      },
    }),
    defaultOptions: {
      queries: {
        retry: (failures, error) => failures + 1 < MAX_ATTEMPTS && error instanceof ApiError && error.retryable,
        retryDelay,
        staleTime: 30_000,
      },
      mutations: { retry: false },
    },
  });
}
