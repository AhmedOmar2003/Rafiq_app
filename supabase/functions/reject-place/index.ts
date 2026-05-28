// POST /reject-place
//   body: { place_id: string, reason: string }

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
    const { place_id, reason } = await req.json().catch(() => ({}));
    if (typeof place_id !== 'string') return jsonError(400, 'place_id required', cors);
    if (typeof reason !== 'string' || reason.trim().length < 5) {
      return jsonError(400, 'rejection reason required', cors);
    }

    const { data: place } = await ctx.serviceClient
      .from('places')
      .select('id, name, provider_id, providers!inner(owner_id)')
      .eq('id', place_id)
      .single();
    if (!place) return jsonError(404, 'place not found', cors);

    const { error: updErr } = await ctx.serviceClient
      .from('places')
      .update({
        status: 'rejected',
        rejection_reason: reason.trim().slice(0, 1000),
        approved_at: null,
        approved_by: null,
      })
      .eq('id', place_id);
    if (updErr) return jsonError(500, 'update failed', cors);

    const ownerId = (place as { providers: { owner_id: string } }).providers.owner_id;
    await notify(ctx, ownerId, 'place_rejected',
      'مكانك يحتاج تعديل',
      reason.trim().slice(0, 600),
      { place_id });

    await logAdmin(ctx, 'reject_place', 'place', place_id, { reason });
    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
