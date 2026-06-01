import fs from "node:fs/promises";
import crypto from "node:crypto";

const envText = await fs.readFile(
  "D:/rafiq_master/admin-dashboard-rafiq-app/.env.local",
  "utf8",
);
const env = Object.fromEntries(
  envText
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      const i = line.indexOf("=");
      return [line.slice(0, i), line.slice(i + 1)];
    }),
);

const base = env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;
const password = "Rafiq2026@";

function authHeaders(token, extra = {}) {
  return {
    apikey: anonKey,
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

function serviceHeaders(extra = {}) {
  return {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

async function parseResponse(res) {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function http(method, url, { headers = {}, body } = {}) {
  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  return {
    ok: res.ok,
    status: res.status,
    data: await parseResponse(res),
  };
}

async function createUser(email, fullName) {
  const res = await http("POST", `${base}/auth/v1/admin/users`, {
    headers: serviceHeaders(),
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    },
  });
  if (!res.ok) {
    throw new Error(`create user failed for ${email}: ${JSON.stringify(res)}`);
  }
  return res.data.user ?? res.data;
}

async function signIn(email) {
  const res = await http(
    "POST",
    `${base}/auth/v1/token?grant_type=password`,
    {
      headers: {
        apikey: anonKey,
        "Content-Type": "application/json",
      },
      body: { email, password },
    },
  );
  if (!res.ok) {
    throw new Error(`sign in failed for ${email}: ${JSON.stringify(res)}`);
  }
  return res.data;
}

async function authRpc(token, name, params) {
  return http("POST", `${base}/rest/v1/rpc/${name}`, {
    headers: authHeaders(token),
    body: params,
  });
}

async function authTable(method, path, token, body, prefer = "return=representation") {
  return http("POST" === method || "PATCH" === method || "DELETE" === method || "GET" === method ? method : method, `${base}/rest/v1/${path}`, {
    headers: authHeaders(token, { Prefer: prefer }),
    body,
  });
}

async function serviceTable(method, path, body, prefer = "return=representation") {
  return http(method, `${base}/rest/v1/${path}`, {
    headers: serviceHeaders({ Prefer: prefer }),
    body,
  });
}

const stamp = Date.now();
const emails = {
  regular: `smoke.user.${stamp}@example.com`,
  provider: `smoke.provider.${stamp}@example.com`,
  admin: `smoke.admin.${stamp}@example.com`,
};

const result = {
  created: {},
  steps: [],
  cleanup: [],
};

const createdUsers = [];

try {
  const regularUser = await createUser(emails.regular, "Smoke Regular");
  const providerUser = await createUser(emails.provider, "Smoke Provider");
  const adminUser = await createUser(emails.admin, "Smoke Admin");
  createdUsers.push(regularUser.id, providerUser.id, adminUser.id);

  result.created.users = {
    regularEmail: emails.regular,
    providerEmail: emails.provider,
    adminEmail: emails.admin,
    regularUserId: regularUser.id,
    providerUserId: providerUser.id,
    adminUserId: adminUser.id,
  };

  await serviceTable("POST", "admin_roles", [
    { user_id: adminUser.id, role: "admin" },
  ]);

  const regularSession = await signIn(emails.regular);
  const providerSession = await signIn(emails.provider);
  const adminSession = await signIn(emails.admin);
  result.steps.push({
    step: "auth_signin",
    ok:
      !!regularSession.access_token &&
      !!providerSession.access_token &&
      !!adminSession.access_token,
  });

  const become = await authRpc(providerSession.access_token, "become_provider", {
    _business_name: "Smoke Bistro",
    _contact_email: emails.provider,
  });
  if (!become.ok) throw new Error(`become_provider failed: ${JSON.stringify(become)}`);
  const providerId = String(become.data);
  result.created.providerId = providerId;

  const planConfirm = await authRpc(
    providerSession.access_token,
    "apply_demo_subscription",
    { _tier: "pro", _yearly: false },
  );
  result.steps.push({
    step: "provider_plan_confirmed",
    ok: planConfirm.ok,
    response: planConfirm.data,
  });

  const placeInsert = await authTable(
    "POST",
    "places",
    providerSession.access_token,
    [
      {
        provider_id: providerId,
        place_name: "Smoke Test Cafe",
        activity_name: "طعام",
        budget: "100 إلى 500 جنيه",
        price_range: "100 إلى 500 جنيه",
        place_address: "Alexandria Corniche",
        city_name: "الإسكندرية",
        description: "مكان اختبار للتحليلات",
        rating: 0,
      },
    ],
  );
  if (!placeInsert.ok) throw new Error(`place insert failed: ${JSON.stringify(placeInsert)}`);
  const place = placeInsert.data[0];
  const placeUuid = place.id;
  result.created.placeUuid = placeUuid;

  await serviceTable("PATCH", `places?id=eq.${placeUuid}`, {
    status: "approved",
    approved_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  result.steps.push({ step: "place_approved", ok: true, placeUuid });

  const sessionId = crypto.randomUUID();
  const nowIso = new Date().toISOString();
  const openEvent = await authRpc(regularSession.access_token, "insert_event_batch", {
    _events: [
      {
        kind: "place_open",
        session_id: sessionId,
        place_id: placeUuid,
        provider_id: providerId,
        occurred_at: nowIso,
        context: { source: "smoke_test" },
      },
    ],
  });
  const favoriteAdd = await authTable(
    "POST",
    "favorites",
    regularSession.access_token,
    [{ user_id: regularUser.id, place_id: placeUuid }],
  );
  const favoriteEvent = await authRpc(regularSession.access_token, "insert_event_batch", {
    _events: [
      {
        kind: "place_favorite",
        session_id: sessionId,
        place_id: placeUuid,
        provider_id: providerId,
        occurred_at: new Date().toISOString(),
        context: { source: "smoke_test" },
      },
    ],
  });
  const favoriteRemove = await authTable(
    "DELETE",
    `favorites?user_id=eq.${regularUser.id}&place_id=eq.${placeUuid}`,
    regularSession.access_token,
    undefined,
    "return=minimal",
  );
  const unfavoriteEvent = await authRpc(regularSession.access_token, "insert_event_batch", {
    _events: [
      {
        kind: "place_unfavorite",
        session_id: sessionId,
        place_id: placeUuid,
        provider_id: providerId,
        occurred_at: new Date().toISOString(),
        context: { source: "smoke_test" },
      },
    ],
  });
  const mapEvent = await authRpc(regularSession.access_token, "insert_event_batch", {
    _events: [
      {
        kind: "place_map_open",
        session_id: sessionId,
        place_id: placeUuid,
        provider_id: providerId,
        occurred_at: new Date().toISOString(),
        context: { source: "smoke_test" },
      },
    ],
  });
  result.steps.push({
    step: "regular_user_interactions",
    ok:
      openEvent.ok &&
      favoriteAdd.ok &&
      favoriteEvent.ok &&
      favoriteRemove.ok &&
      unfavoriteEvent.ok &&
      mapEvent.ok,
    statuses: {
      openEvent: openEvent.status,
      favoriteAdd: favoriteAdd.status,
      favoriteEvent: favoriteEvent.status,
      favoriteRemove: favoriteRemove.status,
      unfavoriteEvent: unfavoriteEvent.status,
      mapEvent: mapEvent.status,
    },
  });

  const providerAnalytics = await authRpc(
    providerSession.access_token,
    "provider_place_analytics_live",
    { _place_id: placeUuid, _days: 30 },
  );
  result.steps.push({
    step: "provider_live_analytics",
    ok: providerAnalytics.ok && Array.isArray(providerAnalytics.data) && providerAnalytics.data.length >= 3,
    rows: providerAnalytics.data,
  });

  const planView = await authTable(
    "GET",
    `provider_current_plan?provider_id=eq.${providerId}&select=tier,max_places,max_campaigns,has_promotions`,
    providerSession.access_token,
    undefined,
    "return=representation",
  );
  result.steps.push({
    step: "plan_limits_visible",
    ok:
      planView.ok &&
      Array.isArray(planView.data) &&
      planView.data[0]?.tier === "pro" &&
      planView.data[0]?.max_campaigns >= 1,
    data: planView.data,
  });

  const campaignCreate = await authRpc(
    providerSession.access_token,
    "create_provider_campaign",
    {
      _place_id: placeUuid,
      _kind: "discount",
      _title: "خصم 20%",
      _body: "خصم خاص لاختبار النظام",
      _image_path: null,
      _cta_label: "احجز الآن",
      _starts_at: new Date(Date.now() - 60 * 1000).toISOString(),
      _ends_at: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    },
  );
  if (!campaignCreate.ok) {
    throw new Error(`campaign create failed: ${JSON.stringify(campaignCreate)}`);
  }
  const campaignId = String(campaignCreate.data);
  result.created.campaignId = campaignId;

  const campaignBefore = await serviceTable(
    "GET",
    `promotional_campaigns?id=eq.${campaignId}&select=id,status,rejection_reason,impressions,clicks`,
    undefined,
    "return=representation",
  );
  const publicPendingRead = await http(
    "GET",
    `${base}/rest/v1/promotional_campaigns?place_id=eq.${placeUuid}&select=id,status,title`,
    {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    },
  );
  result.steps.push({
    step: "campaign_pending_and_hidden",
    ok:
      Array.isArray(campaignBefore.data) &&
      campaignBefore.data[0]?.status === "pending_review" &&
      Array.isArray(publicPendingRead.data) &&
      publicPendingRead.data.length === 0,
    campaign: campaignBefore.data,
    publicPending: publicPendingRead.data,
  });

  const adminRoleCheck = await serviceTable(
    "GET",
    `admin_roles?user_id=eq.${adminUser.id}&select=role`,
    undefined,
    "return=representation",
  );
  result.steps.push({
    step: "admin_account_ready",
    ok:
      Array.isArray(adminRoleCheck.data) &&
      adminRoleCheck.data[0]?.role === "admin",
    data: adminRoleCheck.data,
  });

  await serviceTable("PATCH", `promotional_campaigns?id=eq.${campaignId}`, {
    status: "active",
    rejection_reason: null,
    approved_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  const publicActiveRead = await http(
    "GET",
    `${base}/rest/v1/promotional_campaigns?place_id=eq.${placeUuid}&status=eq.active&select=id,status,title,cta_label`,
    {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    },
  );
  result.steps.push({
    step: "campaign_visible_after_approval",
    ok:
      Array.isArray(publicActiveRead.data) &&
      publicActiveRead.data.some((row) => row.id === campaignId),
    publicActive: publicActiveRead.data,
  });

  const imp1 = await http("POST", `${base}/rest/v1/rpc/record_campaign_metric`, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      "Content-Type": "application/json",
    },
    body: { _campaign_id: campaignId, _metric: "impression" },
  });
  const clk1 = await http("POST", `${base}/rest/v1/rpc/record_campaign_metric`, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      "Content-Type": "application/json",
    },
    body: { _campaign_id: campaignId, _metric: "click" },
  });
  const campaignAfter = await serviceTable(
    "GET",
    `promotional_campaigns?id=eq.${campaignId}&select=id,impressions,clicks,status`,
    undefined,
    "return=representation",
  );
  result.steps.push({
    step: "campaign_metrics_recorded",
    ok:
      imp1.ok &&
      clk1.ok &&
      Array.isArray(campaignAfter.data) &&
      campaignAfter.data[0]?.impressions >= 1 &&
      campaignAfter.data[0]?.clicks >= 1,
    metrics: campaignAfter.data,
  });

  const publicPlace = await http(
    "GET",
    `${base}/rest/v1/places?id=eq.${placeUuid}&select=id,status,place_name`,
    {
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
    },
  );
  result.steps.push({
    step: "approved_place_publicly_visible",
    ok:
      Array.isArray(publicPlace.data) &&
      publicPlace.data[0]?.status === "approved",
    data: publicPlace.data,
  });
} finally {
  for (const userId of createdUsers) {
    const del = await http("DELETE", `${base}/auth/v1/admin/users/${userId}`, {
      headers: serviceHeaders(),
    });
    result.cleanup.push({
      userId,
      ok: del.ok,
      status: del.status,
      data: del.data,
    });
  }
}

console.log(JSON.stringify(result, null, 2));
