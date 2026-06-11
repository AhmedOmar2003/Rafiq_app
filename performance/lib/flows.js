import http from 'k6/http';
import { check, sleep } from 'k6';

import { authSignIn, restGet, rpc, serviceGet, serviceHeadCount } from './supabase.js';

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
  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/reviews?select=review_id,place_id,user_id,name,review_text,rating,image,created_at&place_id=eq.${sample.placeId}&order=created_at.desc&limit=12`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${config.anonKey}`,
        },
        tags: { flow: 'public_details', endpoint: 'reviews' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/place_images?select=storage_path,is_cover,sort_order,created_at&place_id=eq.${sample.placeUuid}&order=is_cover.desc,sort_order.asc,created_at.asc`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${config.anonKey}`,
        },
        tags: { flow: 'public_details', endpoint: 'place_images' },
      },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/promotional_campaigns?select=id,title,body,kind,status,image_path,cta_label,starts_at,ends_at&place_id=eq.${sample.placeUuid}&status=eq.active&order=created_at.desc`,
      null,
      {
        headers: {
          apikey: config.anonKey,
          Authorization: `Bearer ${config.anonKey}`,
        },
        tags: { flow: 'public_details', endpoint: 'promotional_campaigns' },
      },
    ],
    [
      'GET',
      sample.imageUrl,
      null,
      { tags: { flow: 'public_details', endpoint: 'place_image_asset' } },
    ],
  ]);

  check(responses[0], { 'reviews 200': (r) => r.status === 200 });
  check(responses[1], { 'gallery 200': (r) => r.status === 200 });
  check(responses[2], { 'campaigns 200': (r) => r.status === 200 });
  check(responses[3], { 'image asset 200': (r) => r.status === 200 });

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
      `${config.supabaseUrl}/rest/v1/places?select=id,place_id,provider_id,place_name,status,edit_allowed,edit_request_status,created_at,updated_at,edit_submitted_at&provider_id=eq.${providerFixture.providerId}&order=created_at.desc&limit=25`,
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

  sleep(0.3);
}

export function adminDataRead(config, adminFixture) {
  const signIn = authSignIn(config, adminFixture.email, config.defaultPassword);
  check(signIn.response, { 'admin sign-in 200': (r) => r.status === 200 });
  sleep(0.2);
}

export function adminDashboardRead(config, adminFixture) {
  const page = http.get(`${config.dashboardBaseUrl}/login`, {
    tags: { flow: 'admin_dashboard', endpoint: 'dashboard_login_page' },
  });
  check(page, { 'dashboard login page 200': (r) => r.status === 200 });

  const now = new Date();
  now.setDate(now.getDate() - 30);
  const sinceIso = encodeURIComponent(now.toISOString());

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
      `${config.supabaseUrl}/rest/v1/places?select=id,place_id,place_name,city_name,activity_name,rating,status,provider_id,created_at&order=created_at.desc&limit=100`,
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
    [
      'HEAD',
      `${config.supabaseUrl}/rest/v1/analytics_events?select=id&kind=eq.place_open&occurred_at=gte.${sinceIso}`,
      null,
      {
        headers: {
          apikey: config.serviceRoleKey,
          Authorization: `Bearer ${config.serviceRoleKey}`,
          Prefer: 'count=exact',
        },
        tags: { flow: 'admin_dashboard', endpoint: 'analytics_place_open_count' },
      },
    ],
  ]);

  check(responses[0], { 'admin users 200': (r) => r.status === 200 });
  check(responses[1], { 'admin places 200': (r) => r.status === 200 });
  check(responses[2], { 'admin providers 200': (r) => r.status === 200 });
  check(responses[3], { 'admin reports 200': (r) => r.status === 200 });
  check(responses[4], { 'admin appeals 200': (r) => r.status === 200 });
  check(responses[5], { 'admin subscriptions 200': (r) => r.status === 200 });
  check(responses[6], { 'admin analytics count 200': (r) => r.status === 200 });

  sleep(0.3);
}

export function adminOverviewCounts(config) {
  const now = new Date();
  now.setDate(now.getDate() - 30);
  const sinceIso = encodeURIComponent(now.toISOString());

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
    serviceHeadCount(
      config,
      `analytics_events?select=id&kind=eq.place_open&occurred_at=gte.${sinceIso}`,
      { flow: 'admin_overview', endpoint: 'place_open_count' },
    ),
  ];

  check(counts[0], { 'places count 200': (r) => r.status === 200 });
  check(counts[1], { 'providers count 200': (r) => r.status === 200 });
  check(counts[2], { 'reports count 200': (r) => r.status === 200 });
  check(counts[3], { 'analytics count 200': (r) => r.status === 200 });
}
