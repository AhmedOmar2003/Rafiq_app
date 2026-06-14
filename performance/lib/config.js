export const DEFAULT_SUPABASE_URL = 'https://qtlmumlcvcwqieexcguy.supabase.co';
export const DEFAULT_DASHBOARD_URL = 'https://rafiq-master-zeta.vercel.app';
export const DEFAULT_SAMPLE_IMAGE_URL =
  'https://qtlmumlcvcwqieexcguy.supabase.co/storage/v1/object/public/place-images/d225a998-a411-445b-b7c6-1836653b6bce/b07251b4-cff9-4c42-9f90-6e434214f7cb/1780333445720623-0.jpg';

export function envNumber(name, fallback) {
  const raw = __ENV[name];
  if (!raw) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function envBoolean(name, fallback = false) {
  const raw = (__ENV[name] || '').trim().toLowerCase();
  if (!raw) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(raw);
}

export function scenarioStages(peakRate) {
  const stageDuration = __ENV.STAGE_DURATION || '15s';
  const coolDownDuration = __ENV.COOLDOWN_DURATION || '5s';
  return [
    { target: Math.max(1, Math.round(peakRate * 0.25)), duration: stageDuration },
    { target: Math.max(1, Math.round(peakRate * 0.5)), duration: stageDuration },
    { target: Math.max(1, Math.round(peakRate * 0.75)), duration: stageDuration },
    { target: peakRate, duration: stageDuration },
    { target: 0, duration: coolDownDuration },
  ];
}

export function standardOptions(scenarios, thresholds = {}) {
  return {
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
    thresholds: {
      http_req_failed: ['rate<0.01'],
      ...thresholds,
    },
    scenarios,
  };
}

export function runtimeConfig() {
  return {
    supabaseUrl: (__ENV.SUPABASE_URL || DEFAULT_SUPABASE_URL).replace(/\/+$/, ''),
    anonKey: __ENV.SUPABASE_ANON_KEY || '',
    serviceRoleKey: __ENV.SUPABASE_SERVICE_ROLE_KEY || '',
    dashboardBaseUrl: (__ENV.DASHBOARD_BASE_URL || DEFAULT_DASHBOARD_URL).replace(
      /\/+$/,
      '',
    ),
    defaultPassword: __ENV.PERF_TEST_PASSWORD || 'Rafiq2026@',
    enableWrites: envBoolean('ENABLE_SAFE_WRITES', false),
    stagingOnly: envBoolean('STAGING_ONLY', false),
    sampleImageUrl: __ENV.PLACE_IMAGE_URL || DEFAULT_SAMPLE_IMAGE_URL,
  };
}
