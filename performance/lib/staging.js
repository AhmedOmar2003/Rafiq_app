import { fail } from 'k6';

import { DEFAULT_DASHBOARD_URL, DEFAULT_SUPABASE_URL, envNumber } from './config.js';

export function requireStagingOnly(config) {
  if (!config.stagingOnly) {
    fail(
      'Refusing to run staging write tests. Set STAGING_ONLY=true and point SUPABASE_URL / DASHBOARD_BASE_URL to staging targets.',
    );
  }

  if (config.supabaseUrl === DEFAULT_SUPABASE_URL) {
    fail(
      'Refusing to run against the production Supabase project. Set SUPABASE_URL to the staging project URL.',
    );
  }

  if (config.dashboardBaseUrl === DEFAULT_DASHBOARD_URL) {
    fail(
      'Refusing to run against the production dashboard URL. Set DASHBOARD_BASE_URL to the staging dashboard URL.',
    );
  }
}

export function stagingWriteOptions(scenarioName, execName, thresholds = {}) {
  const vus = envNumber('STAGING_VUS', 1);
  const iterations = envNumber('STAGING_ITERATIONS', 1);
  const maxDuration = __ENV.STAGING_MAX_DURATION || '10m';

  return {
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
    thresholds: {
      http_req_failed: ['rate<0.01'],
      [`checks{scenario:${scenarioName}}`]: ['rate>0.99'],
      ...thresholds,
    },
    scenarios: {
      [scenarioName]: {
        executor: 'shared-iterations',
        vus,
        iterations,
        maxDuration,
        exec: execName,
      },
    },
  };
}
