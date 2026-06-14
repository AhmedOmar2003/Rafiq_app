import exec from 'k6/execution';

import { runtimeConfig, envNumber, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { adminDashboardRead, adminDataRead, adminOverviewCounts } from './lib/flows.js';

const config = runtimeConfig();
const peakRate = envNumber('ADMIN_FLOW_PEAK_RATE', 4);
const loginPeakRate = envNumber('ADMIN_LOGIN_PEAK_RATE', 1);
const authAccountCount = envNumber('AUTH_ACCOUNT_COUNT', 1);
const scenarios = {};

if (loginPeakRate > 0) {
  scenarios.admin_login = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 5,
    maxVUs: 20,
    stages: scenarioStages(loginPeakRate),
    exec: 'adminLoginFlow',
  };
}

if (peakRate > 0) {
  scenarios.admin_flow = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 10,
    maxVUs: 40,
    stages: scenarioStages(peakRate),
    exec: 'adminFlow',
  };
}

export const options = standardOptions(
  scenarios,
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
    includeProvider: false,
    includeAdmin: true,
    adminCount: authAccountCount,
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function adminLoginFlow(data) {
  const admins = data.admins?.length ? data.admins : [data.admin];
  const account = admins[exec.scenario.iterationInTest % admins.length];
  adminDataRead(config, account);
}

export function adminFlow(data) {
  adminOverviewCounts(config);
  adminDashboardRead(config, data.admin);
}
