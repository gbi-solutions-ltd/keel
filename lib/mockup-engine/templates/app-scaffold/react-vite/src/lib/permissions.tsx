/**
 * Permissions, never roles: `useCan('<resource>:<action>')`, not `role === '<role>'`.
 *
 * Everything here is display logic. Hiding a control is a UX decision; the server enforces every
 * permission on every request. A per-record action comes from the API's `allowed_actions`, never
 * from a rule recomputed here.
 */
import { createContext, type ReactNode, useContext, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Permission, Session } from '../api/generated/model';
import { useGetSession } from '../api/generated/session/session';
import { ApiError } from '../api/http';
import { ErrorState } from '../components/composites/ErrorState/ErrorState';
import { ForbiddenPage } from '../components/composites/ForbiddenPage/ForbiddenPage';
import { setActor } from './telemetry';

export type { Permission };
/** `public`: anyone. Otherwise a permission. */
export type Access = Permission | 'public';

const SessionContext = createContext<Session | null>(null);
const RELOADED_KEY = 'session:reloaded';

/** Whether a session holds a permission. Display only. */
export function canIn(session: Session | null, access: Access): boolean {
  if (access === 'public') return true;
  return session?.permissions.includes(access) ?? false;
}

/**
 * Before any session exists, a 401 means "not signed in": the BFF signs the user in on a full page
 * load, so reload once. A second 401 in the same tab shows our error instead of looping.
 */
function reloadOnce(): boolean {
  try {
    if (sessionStorage.getItem(RELOADED_KEY)) return false;
    sessionStorage.setItem(RELOADED_KEY, '1');
  } catch {
    return false;
  }
  window.location.reload();
  return true;
}

/** Loads the session once and makes it available to `useCan`, `<Can>` and `useSession`. */
export function SessionProvider({ children }: { children: ReactNode }) {
  const session = useGetSession();
  const { t } = useTranslation();
  const userId = session.data?.user_id;
  const unauthenticated = session.error instanceof ApiError && session.error.status === 401;
  useEffect(() => {
    setActor(userId);
    if (!userId) return;
    try {
      sessionStorage.removeItem(RELOADED_KEY);
    } catch {
      // storage blocked: the guard simply does not apply
    }
  }, [userId]);
  const [gaveUp, setGaveUp] = useState(false);
  useEffect(() => {
    if (unauthenticated && !reloadOnce()) setGaveUp(true);
  }, [unauthenticated]);
  if (session.isPending || (unauthenticated && !gaveUp)) return null;
  if (session.isError) return <ErrorState title={t('ErrorState.title')} body={t('ErrorState.body')} />;
  return <SessionContext value={session.data}>{children}</SessionContext>;
}

export function useSession(): Session {
  const session = useContext(SessionContext);
  if (!session) throw new Error('useSession outside SessionProvider');
  return session;
}

/** Whether the signed-in user holds a permission. Display only. */
export function useCan(access: Access): boolean {
  return canIn(useContext(SessionContext), access);
}

/** Renders children only when the user holds the permission; hidden, not disabled. */
export function Can({ permission, children }: { permission: Permission; children: ReactNode }) {
  return useCan(permission) ? children : null;
}

/** A route's gate: the page, or the shell's refusal (the mockup's ForbiddenPage). */
export function RequirePermission({ permission, children }: { permission: Access; children: ReactNode }) {
  return useCan(permission) ? children : <ForbiddenPage />;
}
