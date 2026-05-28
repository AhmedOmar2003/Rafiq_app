// POST /approve-provider
//   body: { provider_id: string, notes?: string }
//
// Auth: moderator or higher.
// Effect:
//   - providers.status = 'approved'
//   - approved_at / approved_by populated
//   - user_roles: ensure target user has 'provider' role
//   - notifications inbox for the provider owner
//   - admin_logs audit row
//
// Idempotent — calling again on an already-approved provider is a no-op.

import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError,
  jsonError,
  jsonOk,
  logAdmin,
  notify,
  rejectOversizedBody,
  requireAuth,
} from '../_shared/auth.ts';

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const pre = preflight(req); if (pre) return pre;

  if (req.method !== 'POST') return jsonError(405, 'method not allowed', cors);
  const oversized = rejectOversizedBody(req, cors);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'moderator');
    const { provider_id, notes } = await req.json().catch(() => ({}));

    if (typeof provider_id !== 'string' || provider_id.length < 8) {
      return jsonError(400, 'provider_id required', cors);
    }

    // Load the provider (service role, bypasses RLS).
    const { data: provider, error: loadErr } = await ctx.serviceClient
      .from('providers')
      .select('id, owner_id, business_name, status')
      .eq('id', provider_id)
      .is('deleted_at', null)
      .single();
    if (loadErr || !provider) return jsonError(404, 'provider not found', cors);

    if (provider.status === 'approved') {
      return jsonOk({ ok: true, idempotent: true }, cors);
    }

    // Transition.
    const { error: updErr } = await ctx.serviceClient
      .from('providers')
      .update({
        status: 'approved',
        approved_at: new Date().toISOString(),
        approved_by: ctx.userId,
        rejection_reason: null,
        suspended_at: null,
      })
      .eq('id', provider_id);
    if (updErr) return jsonError(500, 'update failed', cors);

    // Make sure the role exists.
    await ctx.serviceClient.from('user_roles').upsert({
      user_id: provider.owner_id,
      role: 'provider',
      granted_by: ctx.userId,
    }, { onConflict: 'user_id,role' });

    await notify(ctx, provider.owner_id, 'provider_approved',
      'تم اعتماد متجرك',
      `طلبك "${provider.business_name}" تم قبوله. تقدر دلوقتي تضيف أماكنك.`,
      { provider_id });

    await logAdmin(ctx, 'approve_provider', 'provider', provider_id, { notes });

    return jsonOk({ ok: true }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
