import exec from 'k6/execution';

import { runtimeConfig, envNumber, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import {
  publicBrowse,
  publicPlaceDetails,
  userProfileRead,
  userSignInAndProfile,
} from './lib/flows.js';

const config = runtimeConfig();
const peakRate = envNumber('USER_FLOW_PEAK_RATE', 12);
const loginPeakRate = envNumber('USER_LOGIN_PEAK_RATE', 1);
const authAccountCount = envNumber('AUTH_ACCOUNT_COUNT', 1);
const scenarios = {};

if (loginPeakRate > 0) {
  scenarios.user_login = {
    executor: 'ramping-arrival-rate',
    startRate: 1,
    timeUnit: '1s',
    preAllocatedVUs: 5,
    maxVUs: 20,
    stages: scenarioStages(loginPeakRate),
    exec: 'userLogin',
  };
}

if (peakRate > 0) {
  scenarios.user_flow = {
    executor: 'ramping-arrival-rate',
    startRate: Math.max(1, Math.round(peakRate * 0.25)),
    timeUnit: '1s',
    preAllocatedVUs: 20,
    maxVUs: 80,
    stages: scenarioStages(peakRate),
    exec: 'userFlow',
  };
}

export const options = standardOptions(
  scenarios,
  {
    'http_req_duration{scenario:user_login}': ['p(95)<1200'],
    'http_req_duration{scenario:user_flow}': ['p(95)<1500'],
    'checks{scenario:user_login}': ['rate>0.99'],
    'checks{scenario:user_flow}': ['rate>0.99'],
  },
);

export function setup() {
  return buildSharedFixtures(config, {
    includeRegular: true,
    includeProvider: false,
    includeAdmin: false,
    regularCount: authAccountCount,
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function userLogin(data) {
  const users = data.regularUsers?.length ? data.regularUsers : [data.regular];
  const account = users[exec.scenario.iterationInTest % users.length];
  userSignInAndProfile(config, account);
}

export function userFlow(data) {
  const users = data.regularUsers?.length ? data.regularUsers : [data.regular];
  const account = users[(exec.vu.idInTest - 1) % users.length];
  publicBrowse(config);
  publicPlaceDetails(config, data.samplePlace);
  userProfileRead(config, account);
}
