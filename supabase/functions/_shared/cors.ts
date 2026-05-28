// Allowed origins are deliberately tight. The mobile app uses the anon key
// directly and never calls these functions; only the Next.js admin dashboard
// + a couple of trusted internal tools do.
//
// Override via the env var `ALLOWED_ORIGINS` (comma-separated) when adding
// new origins in production.
const fallback = [
  'http://localhost:3000',
  'http://localhost:3001',
];

const allowed = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const origins = allowed.length ? allowed : fallback;

export function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin') ?? '';
  const allow = origins.includes(origin) ? origin : '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

export function preflight(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  return null;
}
