/**
 * Permissions, never roles: `useCan('<resource>:<action>')`, not `role === '<role>'`.
 *
 * Everything here is display logic. Hiding a control is a UX decision; the server enforces every
 * permission on every request. A per-record action comes from the API's `allowed_actions`, never
 * from a rule recomputed here. The session is loaded once by SessionGate and provided to the tree.
 */
import { type ComputedRef, computed, type InjectionKey, inject, type Ref } from 'vue';
import type { Permission, Session } from '@/api/generated/model';

export type { Permission };
/** `public`: anyone. Otherwise a permission. */
export type Access = Permission | 'public';

export const SessionKey: InjectionKey<Ref<Session>> = Symbol('session');

/** Whether a session holds a permission. Display only. */
export function canIn(session: Session | null | undefined, access: Access): boolean {
  if (access === 'public') return true;
  return session?.permissions.includes(access) ?? false;
}

export function useSession(): Ref<Session> {
  const session = inject(SessionKey, null);
  if (!session) throw new Error('useSession outside SessionGate');
  return session;
}

/** Whether the signed-in user holds a permission. Display only. */
export function useCan(access: Access): ComputedRef<boolean> {
  const session = inject(SessionKey, null);
  return computed(() => canIn(session?.value, access));
}
