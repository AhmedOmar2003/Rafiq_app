// POST /reject-provider
//   body: { provider_id: string, reason: string }

import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError, jsonError, jsonOk, logAdmin, notify, rejectOversizedBody, requireAuth,
} from '../_shared/auth.ts';

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const pre = preflight(req); if (pre) return pre;
  if (req.method !== 'POST') return jsonError(405, 'method not allowed', cors);
  const oversized = rejectOversizedBody(req, cors);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'moderator');
    const { provider_id, reason } = await req.json().catch(() => ({}));

    if (typeof provider_id !== 'string') return jsonError(400, 'provider_id required', cors);
    if (typeof reason !== 'string' || reason.trim().length < 5) {
      return jsonError(400, 'rejection reason required (min 5 chars)', cors);
    }

    const { data: provider } = await ctx.serviceClient
      .from('providers')
      .select('id, owner_id, business_name, status')
      .eq('id', provider_id)
      .is('deleted_at', null)
      .single();
    if (!provider) return jsonError(404, 'provider not found', cors);

    const { error: updErr } = await ctx.serviceClient
      .from('providers')
      .update({
        status: 'rejected',
        rejection_reason: reason.trim().slice(0, 1000),
        approved_at: null,
        approved_by: null,
      })
      .eq('id', provider_id);
    if (updErr) return jsonError(500, 'update failed', cors);

    await notify(ctx, provider.owner_id, 'provider_rejected',
      'طلبك يحتاج تعديل',
      reason.trim().slice(0, 600),
      { provider_id });

    await logAdmin(ctx, 'reject_provider', 'provider', provider_id, { reason });

    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
