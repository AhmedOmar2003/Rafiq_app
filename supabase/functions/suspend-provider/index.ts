// POST /suspend-provider
//   body: { provider_id: string, reason: string }
//
// Auth: admin or higher.
// Effect: providers.status -> 'suspended', also cascades to hide all of
//         their places from public view (status -> 'suspended').

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
    const ctx = await requireAuth(req, 'admin');
    const { provider_id, reason } = await req.json().catch(() => ({}));
    if (typeof provider_id !== 'string') return jsonError(400, 'provider_id required', cors);
    if (typeof reason !== 'string' || reason.trim().length < 5) {
      return jsonError(400, 'reason required', cors);
    }

    const { data: provider } = await ctx.serviceClient
      .from('providers')
      .select('id, owner_id, business_name')
      .eq('id', provider_id)
      .single();
    if (!provider) return jsonError(404, 'provider not found', cors);

    const now = new Date().toISOString();
    const { error: updProvider } = await ctx.serviceClient
      .from('providers')
      .update({ status: 'suspended', suspended_at: now, rejection_reason: reason.trim() })
      .eq('id', provider_id);
    if (updProvider) return jsonError(500, 'provider suspend failed', cors);

    // Cascade-hide the provider's places.
    await ctx.serviceClient
      .from('places')
      .update({ status: 'suspended', suspended_at: now })
      .eq('provider_id', provider_id)
      .in('status', ['approved', 'pending', 'under_review']);

    await notify(ctx, provider.owner_id, 'provider_suspended',
      'حسابك كمقدم خدمة معلّق',
      reason.trim().slice(0, 600),
      { provider_id });

    await logAdmin(ctx, 'suspend_provider', 'provider', provider_id, { reason });
    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
