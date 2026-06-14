import { envNumber, runtimeConfig, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { adminAnalyticsRead, providerAnalyticsRead } from './lib/flows.js';

const config = runtimeConfig();
const providerPeakRate = envNumber('ANALYTICS_PROVIDER_PEAK_RATE', 8);
const adminPeakRate = envNumber('ANALYTICS_ADMIN_PEAK_RATE', 4);
const scenarios = {};

if (providerPeakRate > 0) {
  scenarios.provider_analytics = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(providerPeakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 10,
    maxVUs: 60,
    stages: scenarioStages(providerPeakRate),
    exec: 'providerAnalytics',
  };
}

if (adminPeakRate > 0) {
  scenarios.admin_analytics = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 5,
    maxVUs: 30,
    stages: scenarioStages(adminPeakRate),
    exec: 'adminAnalytics',
  };
}

export const options = standardOptions(
  scenarios,
  {
    'http_req_duration{scenario:provider_analytics}': ['p(95)<1200'],
    'http_req_duration{scenario:admin_analytics}': ['p(95)<1500'],
    'checks{scenario:provider_analytics}': ['rate>0.99'],
    'checks{scenario:admin_analytics}': ['rate>0.99'],
  },
);

export function setup() {
  return buildSharedFixtures(config, {
    includeRegular: false,
    includeProvider: true,
    includeAdmin: false,
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function providerAnalytics(data) {
  providerAnalyticsRead(config, data.provider);
}

export function adminAnalytics() {
  adminAnalyticsRead(config);
}
