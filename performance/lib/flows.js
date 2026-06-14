import http from 'k6/http';
import { check, sleep } from 'k6';

import { authSignIn, restGet, rpc, serviceGet, serviceHeadCount } from './supabase.js';

function envBoolean(name) {
  const raw = (__ENV[name] || '').trim().toLowerCase();
  return ['1', 'true', 'yes', 'on'].includes(raw);
}

export function publicBrowse(config) {
  const browse = rpc(config, config.anonKey, 'browse_ranked_places', {
    _city_name: null,
    _budget: null,
    _activity_name: null,
    _limit: 12,
  }, { flow: 'public_browse' });

  check(browse.response, {
    'public browse 200': (r) => r.status === 200,
  });

  sleep(0.2);
}

export function publicPlaceDetails(config, sample) {
  const context = rpc(
    config,
    config.anonKey,
    'get_place_details_context',
    {
      _place_uuid: sample.placeUuid,
      _legacy_place_id: Number.isInteger(sample.placeId) ? sample.placeId : null,
    },
    { flow: 'public_details', endpoint: 'place_details_context' },
  );
  check(context.response, {
    'details context 200': (r) => r.status === 200,
    'details context resolved place': () => Boolean(context.data?.place_uuid),
  });
  if (sample.imageUrl) {
    const image = http.get(sample.imageUrl, {
      tags: { flow: 'public_details', endpoint: 'place_image_asset' },
    });
    check(image, { 'image asset 200': (r) => r.status === 200 });
  }

  sleep(0.3);
}

export function userSignInAndProfile(config, regularUser) {
  const signIn = authSignIn(config, regularUser.email, config.defaultPassword);
  check(signIn.response, { 'user sign-in 200': (r) => r.status === 200 });
  sleep(0.2);
}

export function userProfileRead(config, regularUser) {
  const token = regularUser.accessToken;
  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/profiles?select=id,full_name,email,account_mode&id=eq.${regularUser.userId}`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'user_auth', endpoint: 'profile' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/favorites?select=place_id,created_at&user_id=eq.${regularUser.userId}&order=created_at.desc`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'user_auth', endpoint: 'favorites' },
      },
    ],
  ]);

  check(responses[0], { 'profile 200': (r) => r.status === 200 });
  check(responses[1], { 'favorites 200': (r) => r.status === 200 });
  sleep(0.2);
}

export function providerLogin(config, providerFixture) {
  const signIn = authSignIn(config, providerFixture.email, config.defaultPassword);
  check(signIn.response, { 'provider sign-in 200': (r) => r.status === 200 });
  sleep(0.2);
}

export function providerHubRead(config, providerFixture) {
  const token = providerFixture.accessToken;
  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/providers?select=id,business_name,contact_email,created_at&owner_id=eq.${providerFixture.userId}&limit=1`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'provider_hub', endpoint: 'providers_self' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/places?select=id,provider_id,place_name,status,edit_allowed,edit_request_status,created_at,updated_at,edit_submitted_at&provider_id=eq.${providerFixture.providerId}&order=created_at.desc&limit=25`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'provider_hub', endpoint: 'provider_places' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/provider_current_plan?provider_id=eq.${providerFixture.providerId}&select=provider_id,tier,status,period_end,cancel_at_period_end,max_places,max_campaigns`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'provider_hub', endpoint: 'provider_current_plan' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/promotional_campaigns?select=id,title,status,place_id,created_at,starts_at,ends_at,impressions,clicks,edit_request_status,edit_allowed&provider_id=eq.${providerFixture.providerId}&order=created_at.desc&limit=20`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${token}`,
        },
        tags: { flow: 'provider_hub', endpoint: 'provider_campaigns' },
      },
    ],
  ]);

  check(responses[0], { 'provider profile 200': (r) => r.status === 200 });
  check(responses[1], { 'provider places 200': (r) => r.status === 200 });
  check(responses[2], { 'provider plan 200': (r) => r.status === 200 });
  check(responses[3], { 'provider campaigns 200': (r) => r.status === 200 });

  providerAnalyticsRead(config, providerFixture);
  sleep(0.3);
}

export function providerAnalyticsRead(config, providerFixture) {
  const token = providerFixture.accessToken;
  const analytics = rpc(
    config,
    token,
    'provider_place_analytics_live',
    {
      _place_id: providerFixture.approvedPlaceUuid,
      _days: 30,
    },
    { flow: 'provider_hub' },
  );
  check(analytics.response, {
    'provider analytics 200': (r) => r.status === 200,
  });

  const campaignClicks = rpc(
    config,
    token,
    'provider_campaign_clicks_live',
    {
      _place_id: providerFixture.approvedPlaceUuid,
      _days: 30,
    },
    { flow: 'provider_hub' },
  );
  check(campaignClicks.response, {
    'provider campaign clicks 200': (r) => r.status === 200,
  });
}

export function adminDataRead(config, adminFixture) {
  const signIn = authSignIn(config, adminFixture.email, config.defaultPassword);
  check(signIn.response, { 'admin sign-in 200': (r) => r.status === 200 });
  sleep(0.2);
}

export function adminDashboardRead(config, adminFixture) {
  if (!envBoolean('SKIP_DASHBOARD_UI_CHECK')) {
    const page = http.get(`${config.dashboardBaseUrl}/login`, {
      tags: { flow: 'admin_dashboard', endpoint: 'dashboard_login_page' },
    });
    check(page, {
      'dashboard login page reachable': (r) => r.status === 200 || r.status === 401,
    });
  }

  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/auth/v1/admin/users?page=1&per_page=50`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'auth_admin_users' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/places?select=id,place_name,city_name,activity_name,rating,status,provider_id,created_at&order=created_at.desc&limit=100`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'places_table' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/providers?select=id,owner_id,business_name,contact_email,status,created_at&order=created_at.desc&limit=100`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'providers_table' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/moderation_reports?select=id,reporter_id,target_type,target_id,reason_code,status,created_at&order=created_at.desc&limit=100`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'reports_table' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/place_appeals?select=id,place_id,provider_id,status,created_at,appeal_type&order=created_at.desc&limit=100`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'appeals_table' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/provider_subscriptions?select=id,provider_id,tier,status,period_start,period_end,amount_paid_egp,created_at&order=created_at.desc&limit=100`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_dashboard', endpoint: 'subscriptions_table' },
      },
    ],
  ]);

  check(responses[0], { 'admin users 200': (r) => r.status === 200 });
  check(responses[1], { 'admin places 200': (r) => r.status === 200 });
  check(responses[2], { 'admin providers 200': (r) => r.status === 200 });
  check(responses[3], { 'admin reports 200': (r) => r.status === 200 });
  check(responses[4], { 'admin appeals 200': (r) => r.status === 200 });
  check(responses[5], { 'admin subscriptions 200': (r) => r.status === 200 });
  adminAnalyticsRead(config);

  sleep(0.3);
}

export function adminAnalyticsRead(config) {
  const rangeStart = new Date();
  rangeStart.setDate(rangeStart.getDate() - 30);
  const rangeStartDay = rangeStart.toISOString().slice(0, 10);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayIso = encodeURIComponent(today.toISOString());
  const todayDay = today.toISOString().slice(0, 10);

  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/analytics_daily_rollups?select=place_id,kind,event_count,day&day=gte.${rangeStartDay}&day=lt.${todayDay}`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_analytics', endpoint: 'analytics_rollups' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/analytics_events?select=place_id,kind&occurred_at=gte.${todayIso}&limit=1000`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_analytics', endpoint: 'analytics_today_tail' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/campaign_metric_daily_rollups?select=campaign_id,place_id,metric,event_count,day&day=gte.${rangeStartDay}`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
        },
        tags: { flow: 'admin_analytics', endpoint: 'campaign_rollups' },
      },
    ],
  ]);

  check(responses[0], { 'admin analytics rollups 200': (r) => r.status === 200 });
  check(responses[1], { 'admin analytics today tail 200': (r) => r.status === 200 });
  check(responses[2], { 'admin campaign rollups 200': (r) => r.status === 200 });
}

export function adminOverviewCounts(config) {
  const counts = [
    serviceHeadCount(
      config,
      'places?select=id',
      { flow: 'admin_overview', endpoint: 'places_count' },
    ),
    serviceHeadCount(
      config,
      'providers?select=id',
      { flow: 'admin_overview', endpoint: 'providers_count' },
    ),
    serviceHeadCount(
      config,
      'moderation_reports?select=id&status=eq.open',
      { flow: 'admin_overview', endpoint: 'reports_open_count' },
    ),
  ];

  check(counts[0], { 'places count 200': (r) => r.status === 200 });
  check(counts[1], { 'providers count 200': (r) => r.status === 200 });
  check(counts[2], { 'reports count 200': (r) => r.status === 200 });
  adminAnalyticsRead(config);
}
