import http from 'k6/http';
import { check, fail, sleep } from 'k6';

import {
  envNumber,
  runtimeConfig,
  scenarioStages,
  standardOptions,
} from './lib/config.js';
import { fetchSamplePlace, rpc } from './lib/supabase.js';

const config = runtimeConfig();
const browsePeakRate = envNumber('BROWSE_PEAK_RATE', 20);
const detailPeakRate = envNumber('DETAILS_PEAK_RATE', 10);
const loginPagePeakRate = envNumber('LOGIN_PAGE_PEAK_RATE', 0);
const redirectPeakRate = envNumber('REDIRECT_PEAK_RATE', 6);
const detailsMode = (__ENV.DETAILS_MODE || 'context_rpc').trim().toLowerCase();

const restHeaders = {
  apikey: config.anonKey,
  Authorization: `Bearer ${config.anonKey}`,
};

const scenarios = {};

if (browsePeakRate > 0) {
  scenarios.browse_places = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(browsePeakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 20,
    maxVUs: 160,
    stages: scenarioStages(browsePeakRate),
    exec: 'browsePlaces',
  };
}

if (detailPeakRate > 0) {
  scenarios.place_details_bundle = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(detailPeakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 20,
    maxVUs: 160,
    stages: scenarioStages(detailPeakRate),
    exec: 'loadPlaceDetailsBundle',
  };
}

if (loginPagePeakRate > 0) {
  scenarios.dashboard_login_page = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 10,
    maxVUs: 40,
    stages: scenarioStages(loginPagePeakRate),
    exec: 'loadLoginPage',
  };
}

if (redirectPeakRate > 0) {
  scenarios.unauthenticated_dashboard_redirect = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 10,
    maxVUs: 40,
    stages: scenarioStages(redirectPeakRate),
    exec: 'loadDashboardRedirect',
  };
}

export const options = standardOptions(
  scenarios,
  {
    'http_req_duration{scenario:browse_places}': ['p(95)<1200'],
    'http_req_duration{scenario:place_details_bundle}': ['p(95)<1800'],
    'http_req_duration{scenario:dashboard_login_page}': ['p(95)<1800'],
    'http_req_duration{scenario:unauthenticated_dashboard_redirect}': ['p(95)<1800'],
    'checks{scenario:browse_places}': ['rate>0.99'],
    'checks{scenario:place_details_bundle}': ['rate>0.99'],
    'checks{scenario:dashboard_login_page}': ['rate>0.99'],
    'checks{scenario:unauthenticated_dashboard_redirect}': ['rate>0.99'],
  },
);

export function setup() {
  if (!config.anonKey) {
    fail('SUPABASE_ANON_KEY is required for public read tests.');
  }
  return { samplePlace: fetchSamplePlace(config) };
}

export function browsePlaces() {
  const browse = rpc(
    config,
    config.anonKey,
    'browse_ranked_places',
    {
      _city_name: null,
      _budget: null,
      _activity_name: null,
      _limit: 12,
    },
    { flow: 'public_read' },
  );

  check(browse.response, {
    'browse returned 200': (r) => r.status === 200,
  });

  sleep(0.2);
}

export function loadPlaceDetailsBundle(data) {
  const sample = data.samplePlace;
  if (detailsMode === 'context_rpc') {
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
      'details context returned 200': (r) => r.status === 200,
      'details context resolved place': () => Boolean(context.data?.place_uuid),
    });

    if (sample.imageUrl) {
      const image = http.get(sample.imageUrl, {
        tags: { flow: 'public_details', endpoint: 'place_image_asset' },
      });
      check(image, { 'image returned 200': (r) => r.status === 200 });
    }
    sleep(0.3);
    return;
  }

  const responses = http.batch([
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/reviews?select=id,place_id,user_id,rating,body,created_at&place_id=eq.${sample.placeId}&order=created_at.desc&limit=12`,
      null,
      { headers: restHeaders, tags: { flow: 'public_details', endpoint: 'reviews' } },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/place_images?select=storage_path,is_cover,sort_order,created_at&place_id=eq.${sample.placeUuid}&order=is_cover.desc,sort_order.asc,created_at.asc`,
      null,
      { headers: restHeaders, tags: { flow: 'public_details', endpoint: 'place_images' } },
    ],
    [
      'GET',
      `${config.supabaseUrl}/rest/v1/promotional_campaigns?select=id,title,body,kind,status,image_path,cta_label,starts_at,ends_at&place_id=eq.${sample.placeUuid}&status=eq.active&order=created_at.desc`,
      null,
      {
        headers: restHeaders,
        tags: { flow: 'public_details', endpoint: 'promotional_campaigns' },
      },
    ],
    ...(sample.imageUrl
      ? [[
          'GET',
          sample.imageUrl,
          null,
          { tags: { flow: 'public_details', endpoint: 'place_image_asset' } },
        ]]
      : []),
  ]);

  check(responses[0], { 'reviews returned 200': (r) => r.status === 200 });
  check(responses[1], { 'gallery returned 200': (r) => r.status === 200 });
  check(responses[2], { 'campaigns returned 200': (r) => r.status === 200 });
  if (sample.imageUrl) {
    check(responses[3], { 'image returned 200': (r) => r.status === 200 });
  }

  sleep(0.3);
}

export function loadLoginPage() {
  const response = http.get(`${config.dashboardBaseUrl}/login`, {
    tags: { flow: 'public_read', endpoint: 'dashboard_login_page' },
  });

  check(response, {
    'dashboard login returned 200': (r) => r.status === 200,
  });

  sleep(0.2);
}

export function loadDashboardRedirect() {
  const response = http.get(`${config.dashboardBaseUrl}/dashboard/places`, {
    redirects: 5,
    tags: { flow: 'dashboard_redirect', endpoint: 'dashboard_places_redirect' },
  });

  check(response, {
    'dashboard redirect landed on login': (r) =>
      r.status === 200 && String(r.url || '').includes('/login'),
  });

  sleep(0.2);
}
