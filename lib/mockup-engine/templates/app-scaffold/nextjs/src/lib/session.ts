/**
 * Permissions, never roles: `canIn(session, '<resource>:<action>')`, not `role === '<role>'`. Display
 * logic only: the server enforces every permission on every request, and a per-record action comes
 * from the API's `allowed_actions`.
 */
import type { Permission, Session } from '@/api/generated/model';

export type { Permission, Session };
/** `public`: anyone. Otherwise a permission. */
export type Access = Permission | 'public';

/** Whether a session holds a permission. Display only. */
export function canIn(session: Session | null | undefined, access: Access): boolean {
  if (access === 'public') return true;
  return session?.permissions.includes(access) ?? false;
}
