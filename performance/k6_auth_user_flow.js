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

export const options = standardOptions(
  {
    user_login: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 5,
      maxVUs: 20,
      stages: scenarioStages(loginPeakRate),
      exec: 'userLogin',
    },
    user_flow: {
      executor: 'ramping-arrival-rate',
      startRate: Math.max(1, Math.round(peakRate * 0.25)),
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 80,
      stages: scenarioStages(peakRate),
      exec: 'userFlow',
    },
  },
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
  });
}

export function teardown(data) {
  teardownSharedFixtures(config, data);
}

export function userLogin(data) {
  userSignInAndProfile(config, data.regular);
}

export function userFlow(data) {
  publicBrowse(config);
  publicPlaceDetails(config, data.samplePlace);
  userProfileRead(config, data.regular);
}
