import { runtimeConfig, envNumber, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { adminDashboardRead, adminDataRead, adminOverviewCounts } from './lib/flows.js';

const config = runtimeConfig();
const peakRate = envNumber('ADMIN_FLOW_PEAK_RATE', 4);
const loginPeakRate = envNumber('ADMIN_LOGIN_PEAK_RATE', 1);

export const options = standardOptions(
  {
    admin_login: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 5,
      maxVUs: 20,
      stages: scenarioStages(loginPeakRate),
      exec: 'adminLoginFlow',
    },
    admin_flow: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 10,
      maxVUs: 40,
      stages: scenarioStages(peakRate),
      exec: 'adminFlow',
    },
  },
  {
    'http_req_duration{scenario:admin_login}': ['p(95)<1200'],
    'http_req_duration{scenario:admin_flow}': ['p(95)<2200'],
    'checks{scenario:admin_login}': ['rate>0.99'],
    'checks{scenario:admin_flow}': ['rate>0.99'],
  },
);

export function setup() {
  return buildSharedFixtures(config, {
    includeRegular: false,
    includeProvider: true,
    includeAdmin: true,
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function adminLoginFlow(data) {
  adminDataRead(config, data.admin);
}

export function adminFlow(data) {
  adminOverviewCounts(config);
  adminDashboardRead(config, data.admin);
}
