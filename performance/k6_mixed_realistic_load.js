import { runtimeConfig, envNumber, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import {
  adminDashboardRead,
  providerHubRead,
  publicBrowse,
  publicPlaceDetails,
  userProfileRead,
} from './lib/flows.js';

const config = runtimeConfig();
const userPeakRate = envNumber('MIXED_USER_PEAK_RATE', 18);
const providerPeakRate = envNumber('MIXED_PROVIDER_PEAK_RATE', 5);
const adminPeakRate = envNumber('MIXED_ADMIN_PEAK_RATE', 2);
const scenarios = {};

if (userPeakRate > 0) {
  scenarios.mixed_user = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(userPeakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 20,
    maxVUs: 100,
    stages: scenarioStages(userPeakRate),
    exec: 'mixedUserFlow',
  };
}

if (providerPeakRate > 0) {
  scenarios.mixed_provider = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(providerPeakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 10,
    maxVUs: 50,
    stages: scenarioStages(providerPeakRate),
    exec: 'mixedProviderFlow',
  };
}

if (adminPeakRate > 0) {
  scenarios.mixed_admin = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 5,
    maxVUs: 20,
    stages: scenarioStages(adminPeakRate),
    exec: 'mixedAdminFlow',
  };
}

export const options = standardOptions(
  scenarios,
  {
    'http_req_duration{scenario:mixed_user}': ['p(95)<1800'],
    'http_req_duration{scenario:mixed_provider}': ['p(95)<2200'],
    'http_req_duration{scenario:mixed_admin}': ['p(95)<2500'],
    'checks{scenario:mixed_user}': ['rate>0.99'],
    'checks{scenario:mixed_provider}': ['rate>0.99'],
    'checks{scenario:mixed_admin}': ['rate>0.99'],
  },
);

export function setup() {
  return buildSharedFixtures(config, {
    includeRegular: true,
    includeProvider: true,
    includeAdmin: true,
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function mixedUserFlow(data) {
  publicBrowse(config);
  publicPlaceDetails(config, data.samplePlace);
  userProfileRead(config, data.regular);
}

export function mixedProviderFlow(data) {
  providerHubRead(config, data.provider);
}

export function mixedAdminFlow(data) {
  adminDashboardRead(config, data.admin);
}
