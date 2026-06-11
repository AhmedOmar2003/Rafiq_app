import { runtimeConfig, envNumber, scenarioStages, standardOptions } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { providerHubRead, providerLogin } from './lib/flows.js';

const config = runtimeConfig();
const peakRate = envNumber('PROVIDER_FLOW_PEAK_RATE', 8);
const loginPeakRate = envNumber('PROVIDER_LOGIN_PEAK_RATE', 1);

export const options = standardOptions(
  {
    provider_login: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 5,
      maxVUs: 20,
      stages: scenarioStages(loginPeakRate),
      exec: 'providerLoginFlow',
    },
    provider_flow: {
      executor: 'ramping-arrival-rate',
      startRate: Math.max(1, Math.round(peakRate * 0.25)),
      timeUnit: '1s',
      preAllocatedVUs: 20,
      maxVUs: 60,
      stages: scenarioStages(peakRate),
      exec: 'providerFlow',
    },
  },
  {
    'http_req_duration{scenario:provider_login}': ['p(95)<1200'],
    'http_req_duration{scenario:provider_flow}': ['p(95)<1800'],
    'checks{scenario:provider_login}': ['rate>0.99'],
    'checks{scenario:provider_flow}': ['rate>0.99'],
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

export function providerLoginFlow(data) {
  providerLogin(config, data.provider);
}

export function providerFlow(data) {
  providerHubRead(config, data.provider);
}
