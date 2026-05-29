# Rafiq Provider Dashboard — Architecture

Production-grade Next.js 14 (App Router) provider dashboard, sharing the
same Supabase project as the Flutter app.

> **Repo placement:** new sibling repo `rafiq-dashboard/` (not inside the
> Flutter project). Deployed on Vercel. Same Supabase URL + anon key for
> client reads; server-only `SUPABASE_SERVICE_ROLE_KEY` for billing
> webhooks.

---

## 1. Tech choices

| Layer | Choice | Why |
|---|---|---|
| Framework | **Next.js 14 (App Router)** | RSC for fast TTFB, server actions for billing writes, edge-friendly. |
| Auth | `@supabase/ssr` (cookies) | Single source of truth with the Flutter app; provider sessions Just Work. |
| UI | `shadcn/ui` + Tailwind + Radix | Owned components (no vendor lock-in), match Flutter design tokens. |
| Charts | `recharts` (lazy-loaded) | Tree-shakeable, SSR-safe, ~25 KB gzipped. |
| Forms | `react-hook-form` + `zod` | Schema validation matching Postgres CHECKs. |
| State | RSC + server actions; **no Redux** | Reads happen on the server. Mutations are server actions. |
| Webhooks | Edge Route Handlers under `/api/billing/*` | Idempotent — keyed on `provider_event_id`. |
| Observability | Vercel Analytics + Sentry | Track LCP/INP + capture server action exceptions. |
| Hosting | Vercel (Edge) | Closest to Supabase region; bandwidth + image CDN included. |

---

## 2. Folder structure

```
rafiq-dashboard/
├─ app/
│  ├─ (marketing)/                       # public pricing page (reuses plan catalog)
│  │  ├─ page.tsx
│  │  └─ pricing/page.tsx
│  ├─ (auth)/                            # login / signup / reset
│  │  ├─ login/page.tsx
│  │  └─ callback/route.ts               # PKCE callback
│  ├─ (provider)/                        # protected provider dashboard
│  │  ├─ layout.tsx                      # sidebar + top bar shell
│  │  ├─ overview/page.tsx
│  │  ├─ places/
│  │  │  ├─ page.tsx                     # list
│  │  │  ├─ new/page.tsx
│  │  │  └─ [id]/page.tsx                # edit
│  │  ├─ analytics/
│  │  │  ├─ page.tsx                     # summary cards + charts
│  │  │  └─ [placeId]/page.tsx           # per-place drilldown
│  │  ├─ subscription/page.tsx           # pricing + manage + invoices
│  │  ├─ promotions/
│  │  │  ├─ page.tsx
│  │  │  └─ new/page.tsx
│  │  ├─ reviews/page.tsx
│  │  ├─ notifications/page.tsx
│  │  └─ settings/page.tsx
│  ├─ (admin)/                           # moderator/admin-only
│  │  └─ moderation/page.tsx
│  └─ api/
│     ├─ billing/
│     │  ├─ paymob/webhook/route.ts      # POST, edge runtime
│     │  └─ stripe/webhook/route.ts
│     └─ checkout/route.ts               # POST, creates Paymob session
├─ components/
│  ├─ ui/                                # shadcn primitives
│  ├─ dashboard/
│  │  ├─ sidebar.tsx
│  │  ├─ topbar.tsx
│  │  └─ stat-card.tsx
│  ├─ charts/
│  │  ├─ engagement-trend.tsx
│  │  ├─ city-distribution.tsx
│  │  └─ budget-distribution.tsx
│  ├─ pricing/
│  │  ├─ plan-card.tsx
│  │  └─ comparison-table.tsx
│  └─ marketing/
│     └─ pricing-page.tsx
├─ lib/
│  ├─ supabase/
│  │  ├─ server.ts                       # createServerClient (RSC + actions)
│  │  ├─ client.ts                       # createBrowserClient
│  │  ├─ middleware.ts                   # session refresh + role check
│  │  └─ admin.ts                        # service-role client (webhooks only!)
│  ├─ billing/
│  │  ├─ paymob.ts                       # checkout, signature verify
│  │  └─ idempotency.ts                  # exact-once event handler
│  ├─ feature-gate.ts                    # mirrors Flutter FeatureGate
│  ├─ queries/
│  │  ├─ subscription.ts                 # cached server reads (Suspense)
│  │  ├─ analytics.ts
│  │  └─ promotions.ts
│  └─ types/
│     └─ database.ts                     # `supabase gen types typescript`
├─ middleware.ts                         # auth + role gating
├─ next.config.mjs
├─ tailwind.config.ts
└─ package.json
```

---

## 3. Auth + role gating

`middleware.ts`:
```ts
import { NextResponse, type NextRequest } from 'next/server'
import { createMiddlewareClient } from '@/lib/supabase/middleware'

export async function middleware(req: NextRequest) {
  const { supabase, response } = createMiddlewareClient(req)
  const { data: { session } } = await supabase.auth.getSession()
  const path = req.nextUrl.pathname

  // Public routes
  if (path.startsWith('/login') || path === '/' || path.startsWith('/pricing')) {
    return response
  }
  if (!session) return NextResponse.redirect(new URL('/login', req.url))

  // Provider-only routes need the provider role.
  if (path.startsWith('/overview') || path.startsWith('/places')) {
    const { data: role } = await supabase.rpc('current_role')
    if (role !== 'provider' && role !== 'admin' && role !== 'super_admin') {
      return NextResponse.redirect(new URL('/login', req.url))
    }
  }

  return response
}

export const config = { matcher: ['/((?!_next|favicon.ico|api/billing).*)'] }
```

The `(api/billing)` exclusion matters: webhooks have no user session and are
authenticated via gateway signature instead.

---

## 4. Reads: server actions hit views, not raw tables

```ts
// lib/queries/subscription.ts
import 'server-only'
import { createServerClient } from '@/lib/supabase/server'
import { cache } from 'react'

export const getCurrentEntitlement = cache(async (providerId: string) => {
  const supabase = createServerClient()
  const { data } = await supabase
    .from('provider_current_plan')   // <- view, not raw table
    .select('*')
    .eq('provider_id', providerId)
    .maybeSingle()
  return data
})

export const getCatalog = cache(async () => {
  const supabase = createServerClient()
  const { data } = await supabase
    .from('subscription_plans')
    .select('*')
    .eq('is_public', true)
    .order('sort_order')
  return data ?? []
})
```

`cache(...)` deduplicates within a single render pass; combined with RSC
this means a page calling `getCurrentEntitlement` 5 times hits the DB once.

---

## 5. Mutations: server actions only

```ts
// app/(provider)/subscription/actions.ts
'use server'
import { z } from 'zod'
import { createServerClient } from '@/lib/supabase/server'

const StartCheckout = z.object({
  targetTier: z.enum(['pro', 'max']),
  yearly: z.boolean(),
})

export async function startCheckout(input: z.infer<typeof StartCheckout>) {
  const parsed = StartCheckout.parse(input)
  const supabase = createServerClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('unauthenticated')

  // Resolve provider for this user (RLS will block cross-provider writes).
  const { data: provider } = await supabase
    .from('providers')
    .select('id')
    .eq('owner_id', user.id)
    .single()

  // Hand off to billing route — never call gateway from client.
  const res = await fetch(`${process.env.APP_URL}/api/checkout`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      providerId: provider.id,
      targetTier: parsed.targetTier,
      yearly: parsed.yearly,
    }),
  })
  return res.json() as Promise<{ redirectUrl: string }>
}
```

Webhooks (`/api/billing/paymob/webhook/route.ts`) use the admin client
(service_role) under strict request-signature verification.

---

## 6. Idempotent billing handler

```ts
// app/api/billing/paymob/webhook/route.ts
import { NextResponse } from 'next/server'
import { admin } from '@/lib/supabase/admin'
import { verifyPaymobSignature } from '@/lib/billing/paymob'

export const runtime = 'edge'

export async function POST(req: Request) {
  const raw = await req.text()
  if (!verifyPaymobSignature(raw, req.headers)) {
    return new NextResponse('bad signature', { status: 401 })
  }
  const payload = JSON.parse(raw)
  const eventId = payload.obj.id as string   // gateway-side primary key

  // Insert the event idempotently — UNIQUE (gateway, provider_event_id)
  // makes duplicate deliveries a no-op.
  const { error: insertErr } = await admin.from('billing_events').insert({
    gateway: 'paymob',
    provider_event_id: String(eventId),
    kind: mapKind(payload),
    provider_id: payload.obj.merchant_order_id,
    amount_egp: payload.obj.amount_cents / 100,
    raw_payload: payload,
  })
  if (insertErr && insertErr.code !== '23505') {
    return new NextResponse('insert failed', { status: 500 })
  }

  // Apply the state transition via a SECURITY DEFINER function.
  await admin.rpc('apply_billing_event', { _gateway: 'paymob', _event_id: String(eventId) })

  return NextResponse.json({ ok: true })
}
```

---

## 7. Dashboard navigation

```
Sidebar (collapsible)
├─ Overview                           (recent activity, plan summary, KPIs)
├─ My Places                          (CRUD on places, moderation badges)
├─ Analytics                          (header KPIs + 3 charts + export)
├─ Subscription                       (pricing cards + manage + invoices)
├─ Promotions                         (campaign list, only enabled on Pro+)
├─ Reviews                            (latest, reply, hide)
├─ Notifications                      (system + moderation alerts)
└─ Settings                           (business profile, payouts, team)
```

`Settings → Team` and `Promotions` are gated by `provider_current_plan` —
they render an [Upgrade] card with the same `<PricingCards />` component used on
the public pricing page.

---

## 8. Charts (analytics)

Components live in `components/charts/`. All wrapped in
`<Suspense fallback=<ChartSkeleton />>` so an RSC stream renders the rest of
the page immediately.

```tsx
// app/(provider)/analytics/page.tsx
export default async function AnalyticsPage() {
  const summary = await getProviderAnalyticsSummary()
  return (
    <div className="grid gap-6">
      <StatRow totals={summary.totals_30d} />
      <Suspense fallback={<ChartSkeleton />}>
        <EngagementTrend providerId={providerId} />
      </Suspense>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <CityDistribution providerId={providerId} />
        <BudgetDistribution providerId={providerId} />
      </div>
    </div>
  )
}
```

Each chart server-fetches its own slice from
`analytics_daily_rollups` — keeps individual requests small and lets
Suspense progressively hydrate.

---

## 9. Performance budgets

- LCP < **1.8 s** on 4G; INP < **150 ms**.
- Each provider page ships ≤ **120 KB JS** (RSC + lazy charts).
- Tables paginate at 50 rows; analytics queries always hit
  `analytics_daily_rollups`, never `analytics_events`.
- Sidebar uses `next/link` prefetch; pricing page is fully static (ISR
  every 1 h).

---

## 10. Local dev

```bash
pnpm dlx create-next-app rafiq-dashboard --typescript --tailwind --app
pnpm add @supabase/ssr @supabase/supabase-js zod react-hook-form recharts
pnpm add -D supabase
npx supabase gen types typescript --project-id <id> > lib/types/database.ts
```

Wire the same `.env.local` you already have for the Flutter app (URL +
anon key), plus `SUPABASE_SERVICE_ROLE_KEY` (server-only) and
`PAYMOB_API_KEY` / `PAYMOB_HMAC`.

---

## 11. Going to production

- [ ] `supabase db push` runs all migrations 0001–0015.
- [ ] Service role key only on Vercel **server**, never exposed to client.
- [ ] Webhook URLs registered with gateway, HMAC verified.
- [ ] `pg_cron` schedules `rebuild_daily_rollups(current_date - 1)` at 02:00.
- [ ] Sentry DSN + Vercel Analytics on, alerts on 5xx on `/api/billing/*`.
- [ ] Pricing page generated statically (no DB call during request).
- [ ] Rate-limit `/api/checkout` (10/min/user) at the edge.
