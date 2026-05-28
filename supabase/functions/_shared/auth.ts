// Auth helper used by every privileged Edge Function.
//
// IMPORTANT: a function can be reached by anyone with the anon key. *Never*
// trust the body; *always* re-validate the JWT here and check the user's
// role via the database (NOT via JWT claims, which a malicious client could
// not forge but a misconfigured project could leak stale).
//
// Two clients are returned:
//   userClient    — bound to the caller's JWT, subject to RLS. Use for reads
//                   that should obey policies (e.g. "can this user see this
//                   provider?").
//   serviceClient — service role, bypasses RLS. Use ONLY for writes that the
//                   function has explicitly authorized (e.g. admin approve).

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

type AppRole = 'user' | 'provider' | 'moderator' | 'admin' | 'super_admin';

export interface AuthContext {
  userId: string;
  role: AppRole;
  email: string;
  userClient: SupabaseClient;
  serviceClient: SupabaseClient;
  ip: string;
  userAgent: string;
}

export class AuthError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const supabaseUrl   = Deno.env.get('SUPABASE_URL')!;
const anonKey       = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey    = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

export async function requireAuth(
  req: Request,
  minimumRole: AppRole,
): Promise<AuthContext> {
  const auth = req.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    throw new AuthError(401, 'missing bearer token');
  }
  const jwt = auth.slice('Bearer '.length).trim();

  // 1. Verify the JWT by asking GoTrue who the user is.
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    throw new AuthError(401, 'invalid token');
  }
  const user = userData.user;

  // 2. Look up the highest active role from `user_roles`. NEVER trust a
  //    role claim baked into the JWT — that can go stale after a revoke.
  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });
  const { data: roleRows, error: roleErr } = await serviceClient
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .is('revoked_at', null);

  if (roleErr) throw new AuthError(500, 'role lookup failed');

  const order: Record<AppRole, number> = {
    super_admin: 5, admin: 4, moderator: 3, provider: 2, user: 1,
  };
  const role: AppRole =
    (roleRows ?? []).map((r) => r.role as AppRole)
      .sort((a, b) => order[b] - order[a])[0] ?? 'user';

  if (order[role] < order[minimumRole]) {
    throw new AuthError(403, `requires ${minimumRole}`);
  }

  return {
    userId: user.id,
    role,
    email: user.email ?? '',
    userClient,
    serviceClient,
    ip: req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? '',
    userAgent: req.headers.get('user-agent') ?? '',
  };
}

/**
 * Append a row to `admin_logs`. Every privileged write must call this so the
 * audit trail is complete.
 */
export async function logAdmin(
  ctx: AuthContext,
  action: string,
  entityType: string,
  entityId: string | null,
  payload: Record<string, unknown> = {},
): Promise<void> {
  await ctx.serviceClient.from('admin_logs').insert({
    actor_id: ctx.userId,
    actor_role: ctx.role,
    action,
    entity_type: entityType,
    entity_id: entityId,
    ip_address: ctx.ip || null,
    user_agent: ctx.userAgent || null,
    payload,
  });
}

/**
 * Notifications are disabled for now, so this is a deliberate no-op.
 * Keep the call sites in place so re-enabling later is a one-line change.
 */
export async function notify(
  ctx: AuthContext,
  userId: string,
  type: string,
  title: string,
  body?: string,
  data: Record<string, unknown> = {},
): Promise<void> {
  void ctx;
  void userId;
  void type;
  void title;
  void body;
  void data;
}

export function jsonError(status: number, message: string, cors: HeadersInit) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

export function jsonOk(body: unknown, cors: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

export function rejectOversizedBody(
  req: Request,
  cors: HeadersInit,
  maxBytes = 100 * 1024,
): Response | null {
  const contentLength = req.headers.get('content-length');
  if (!contentLength) {
    return null;
  }

  const parsed = Number(contentLength);
  if (Number.isFinite(parsed) && parsed > maxBytes) {
    return jsonError(413, 'payload too large', cors);
  }

  return null;
}
