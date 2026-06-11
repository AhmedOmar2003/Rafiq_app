import http from 'k6/http';
import { check, sleep } from 'k6';

const supabaseUrl = __ENV.SUPABASE_URL || 'https://qtlmumlcvcwqieexcguy.supabase.co';
const anonKey =
  __ENV.SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0bG11bWxjdmN3cWllZXhjZ3V5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NDMwMTEsImV4cCI6MjA5MjExOTAxMX0.fvPB55Iedho6ABmMoVQ9M5xEPtNfSN7bwr6HYKL-Qkc';
const dashboardBaseUrl =
  __ENV.DASHBOARD_BASE_URL || 'https://admin-dashboard-rafiq-app.vercel.app';

const samplePlaceId = Number(__ENV.PLACE_ID || 20);
const samplePlaceUuid =
  __ENV.PLACE_UUID || 'b07251b4-cff9-4c42-9f90-6e434214f7cb';
const sampleImageUrl =
  __ENV.PLACE_IMAGE_URL ||
  'https://qtlmumlcvcwqieexcguy.supabase.co/storage/v1/object/public/place-images/d225a998-a411-445b-b7c6-1836653b6bce/b07251b4-cff9-4c42-9f90-6e434214f7cb/1780333445720623-0.jpg';
const browsePeakRate = Number(__ENV.BROWSE_PEAK_RATE || 60);
const detailPeakRate = Number(__ENV.DETAILS_PEAK_RATE || 30);
const stageDuration = __ENV.STAGE_DURATION || '30s';
const coolDownDuration = __ENV.COOLDOWN_DURATION || '10s';

const jsonHeaders = {
  apikey: anonKey,
  Authorization: `Bearer ${anonKey}`,
  'Content-Type': 'application/json',
};

const restHeaders = {
  apikey: anonKey,
  Authorization: `Bearer ${anonKey}`,
};

export const options = {
  discardResponseBodies: true,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{scenario:browse_places}': ['p(95)<1200'],
    'http_req_duration{scenario:place_details_bundle}': ['p(95)<1500'],
    'checks{scenario:browse_places}': ['rate>0.99'],
    'checks{scenario:place_details_bundle}': ['rate>0.99'],
  },
  scenarios: {
    browse_places: {
      executor: 'ramping-arrival-rate',
      startRate: 5,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 120,
      stages: [
        { target: Math.max(1, Math.round(browsePeakRate * 0.17)), duration: stageDuration },
        { target: Math.max(1, Math.round(browsePeakRate * 0.42)), duration: stageDuration },
        { target: Math.max(1, Math.round(browsePeakRate * 0.67)), duration: stageDuration },
        { target: browsePeakRate, duration: stageDuration },
        { target: 0, duration: coolDownDuration },
      ],
      exec: 'browsePlaces',
    },
    place_details_bundle: {
      executor: 'ramping-arrival-rate',
      startRate: 3,
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 120,
      stages: [
        { target: Math.max(1, Math.round(detailPeakRate * 0.2)), duration: stageDuration },
        { target: Math.max(1, Math.round(detailPeakRate * 0.4)), duration: stageDuration },
        { target: Math.max(1, Math.round(detailPeakRate * 0.67)), duration: stageDuration },
        { target: detailPeakRate, duration: stageDuration },
        { target: 0, duration: coolDownDuration },
      ],
      exec: 'loadPlaceDetailsBundle',
    },
  },
};

export function browsePlaces() {
  const response = http.post(
    `${supabaseUrl}/rest/v1/rpc/browse_ranked_places`,
    JSON.stringify({
      _city_name: null,
      _budget: null,
      _activity_name: null,
      _limit: 12,
    }),
    { headers: jsonHeaders, tags: { endpoint: 'browse_ranked_places' } },
  );

  check(response, {
    'browse returned 200': (r) => r.status === 200,
  });

  sleep(0.2);
}

export function loadPlaceDetailsBundle() {
  const responses = http.batch([
    [
      'GET',
      `${supabaseUrl}/rest/v1/reviews?select=review_id,place_id,user_id,name,review_text,rating,image,created_at&place_id=eq.${samplePlaceId}&order=created_at.desc&limit=12`,
      null,
      { headers: restHeaders, tags: { endpoint: 'reviews' } },
    ],
    [
      'GET',
      `${supabaseUrl}/rest/v1/place_images?select=storage_path,is_cover,sort_order,created_at&place_id=eq.${samplePlaceUuid}&order=is_cover.desc,sort_order.asc,created_at.asc`,
      null,
      { headers: restHeaders, tags: { endpoint: 'place_images' } },
    ],
    [
      'GET',
      `${supabaseUrl}/rest/v1/promotional_campaigns?select=id,title,body,kind,status,image_path,cta_label,starts_at,ends_at&place_id=eq.${samplePlaceUuid}&status=eq.active&order=created_at.desc`,
      null,
      { headers: restHeaders, tags: { endpoint: 'promotional_campaigns' } },
    ],
    [
      'GET',
      sampleImageUrl,
      null,
      { tags: { endpoint: 'place_image_asset' } },
    ],
    [
      'GET',
      `${dashboardBaseUrl}/login`,
      null,
      { tags: { endpoint: 'dashboard_login_page' } },
    ],
  ]);

  check(responses[0], { 'reviews returned 200': (r) => r.status === 200 });
  check(responses[1], { 'gallery returned 200': (r) => r.status === 200 });
  check(responses[2], { 'campaigns returned 200': (r) => r.status === 200 });
  check(responses[3], { 'image returned 200': (r) => r.status === 200 });
  check(responses[4], { 'dashboard login returned 200': (r) => r.status === 200 });

  sleep(0.3);
}
