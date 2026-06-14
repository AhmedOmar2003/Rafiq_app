import { check, fail, sleep } from 'k6';

import { envNumber, runtimeConfig, standardOptions } from './lib/config.js';
import { fetchSamplePlace, rpc } from './lib/supabase.js';

const config = runtimeConfig();
const lowRate = envNumber('SPIKE_LOW_RATE', 10);
const highRate = envNumber('SPIKE_HIGH_RATE', 100);
const lowDuration = __ENV.SPIKE_LOW_DURATION || '10s';
const highDuration = __ENV.SPIKE_HIGH_DURATION || '20s';
const recoverDuration = __ENV.SPIKE_RECOVERY_DURATION || '10s';
const coolDownDuration = __ENV.SPIKE_COOLDOWN_DURATION || '5s';

export const options = standardOptions(
  {
    public_browse_spike: {
      executor: 'ramping-arrival-rate',
      startRate: lowRate,
      timeUnit: '1s',
      preAllocatedVUs: 40,
      maxVUs: 200,
      stages: [
        { target: lowRate, duration: lowDuration },
        { target: highRate, duration: '1s' },
        { target: highRate, duration: highDuration },
        { target: lowRate, duration: recoverDuration },
        { target: 0, duration: coolDownDuration },
      ],
      exec: 'browsePlaces',
    },
  },
  {
    'http_req_duration{scenario:public_browse_spike}': ['p(95)<1500'],
    'checks{scenario:public_browse_spike}': ['rate>0.99'],
  },
);

export function setup() {
  if (!config.anonKey) {
    fail('SUPABASE_ANON_KEY is required for public spike tests.');
  }

  return { samplePlace: fetchSamplePlace(config) };
}

export function browsePlaces() {
  const browse = rpc(
    config,
    config.anonKey,
    'browse_ranked_places',
    {
      _city_name: null,
      _budget: null,
      _activity_name: null,
      _limit: 12,
    },
    { flow: 'public_spike' },
  );

  check(browse.response, {
    'spike browse returned 200': (r) => r.status === 200,
  });

  sleep(0.2);
}
