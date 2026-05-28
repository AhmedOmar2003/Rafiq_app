// POST /assign-role
//   body: { user_id: string, role: 'moderator'|'admin'|'super_admin', revoke?: boolean }
//
// Auth: super_admin only.
//
// Why an Edge Function and not direct SQL?
//   - We log who granted/revoked.
//   - We enforce that nobody can grant themselves a role.
//   - We can later add MFA / step-up here without touching schema.

import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError, jsonError, jsonOk, logAdmin, rejectOversizedBody, requireAuth,
} from '../_shared/auth.ts';

const ASSIGNABLE = new Set(['moderator', 'admin', 'super_admin', 'provider']);

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const pre = preflight(req); if (pre) return pre;
  if (req.method !== 'POST') return jsonError(405, 'method not allowed', cors);
  const oversized = rejectOversizedBody(req, cors);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'super_admin');
    const { user_id, role, revoke } = await req.json().catch(() => ({}));

    if (typeof user_id !== 'string' || user_id.length < 8) {
      return jsonError(400, 'user_id required', cors);
    }
    if (typeof role !== 'string' || !ASSIGNABLE.has(role)) {
      return jsonError(400, `role must be one of ${[...ASSIGNABLE].join(', ')}`, cors);
    }
    if (user_id === ctx.userId) {
      return jsonError(403, 'cannot modify your own role', cors);
    }

    if (revoke === true) {
      const { error } = await ctx.serviceClient
        .from('user_roles')
        .update({ revoked_at: new Date().toISOString() })
        .eq('user_id', user_id)
        .eq('role', role)
        .is('revoked_at', null);
      if (error) return jsonError(500, 'revoke failed', cors);
      await logAdmin(ctx, 'revoke_role', 'user_role', user_id, { role });
    } else {
      const { error } = await ctx.serviceClient
        .from('user_roles')
        .upsert(
          { user_id, role, granted_by: ctx.userId, revoked_at: null },
          { onConflict: 'user_id,role' },
        );
      if (error) return jsonError(500, 'grant failed', cors);
      await logAdmin(ctx, 'grant_role', 'user_role', user_id, { role });
    }

    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
