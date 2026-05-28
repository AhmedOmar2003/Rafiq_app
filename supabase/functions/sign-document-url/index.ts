// POST /sign-document-url
//   body: { storage_path: string, expires_in_seconds?: number }
//
// Returns a short-lived signed URL for a private provider-documents object.
// Only the document's owning provider OR a moderator+ can request it.

import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError, jsonError, jsonOk, logAdmin, rejectOversizedBody, requireAuth,
} from '../_shared/auth.ts';

const MAX_EXPIRY = 5 * 60;          // 5 minutes hard cap

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const pre = preflight(req); if (pre) return pre;
  if (req.method !== 'POST') return jsonError(405, 'method not allowed', cors);
  const oversized = rejectOversizedBody(req, cors);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'user');     // any logged-in user; access check below
    const { storage_path, expires_in_seconds } = await req.json().catch(() => ({}));
    if (typeof storage_path !== 'string' || !storage_path.length) {
      return jsonError(400, 'storage_path required', cors);
    }
    const expiry = Math.min(
      Math.max(parseInt(`${expires_in_seconds ?? 60}`, 10) || 60, 5),
      MAX_EXPIRY,
    );

    // The folder is the provider_id. Verify the caller owns it OR is a moderator+.
    const folder = storage_path.split('/')[0];
    const isMod = ['moderator', 'admin', 'super_admin'].includes(ctx.role);

    if (!isMod) {
      const { data: provider } = await ctx.serviceClient
        .from('providers').select('id').eq('id', folder).eq('owner_id', ctx.userId).maybeSingle();
      if (!provider) return jsonError(403, 'forbidden', cors);
    }

    const { data, error } = await ctx.serviceClient
      .storage.from('provider-documents')
      .createSignedUrl(storage_path, expiry);
    if (error || !data?.signedUrl) return jsonError(500, 'sign failed', cors);

    await logAdmin(ctx, 'sign_document_url', 'document', null, { storage_path, expiry });
    return jsonOk({ url: data.signedUrl, expires_in: expiry }, cors);
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
