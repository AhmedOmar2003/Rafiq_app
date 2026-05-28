// POST /approve-place
//   body: { place_id: string }

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
    const { place_id } = await req.json().catch(() => ({}));
    if (typeof place_id !== 'string') return jsonError(400, 'place_id required', cors);

    const { data: place } = await ctx.serviceClient
      .from('places')
      .select('id, name, provider_id, status, providers!inner(owner_id)')
      .eq('id', place_id)
      .is('deleted_at', null)
      .single();
    if (!place) return jsonError(404, 'place not found', cors);
    if (place.status === 'approved') return jsonOk({ ok: true, idempotent: true }, cors);

    const { error: updErr } = await ctx.serviceClient
      .from('places')
      .update({
        status: 'approved',
        approved_at: new Date().toISOString(),
        approved_by: ctx.userId,
        rejection_reason: null,
        suspended_at: null,
      })
      .eq('id', place_id);
    if (updErr) return jsonError(500, 'update failed', cors);

    const ownerId = (place as { providers: { owner_id: string } }).providers.owner_id;
    await notify(ctx, ownerId, 'place_approved',
      'مكانك ظاهر للناس',
      `"${place.name}" تم قبوله ويظهر دلوقتي في الاقتراحات.`,
      { place_id });

    await logAdmin(ctx, 'approve_place', 'place', place_id, {});
    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
