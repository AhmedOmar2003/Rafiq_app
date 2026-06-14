import { check, fail, sleep } from 'k6';

import { envNumber, runtimeConfig, standardOptions } from './lib/config.js';
import { fetchSamplePlace, rpc } from './lib/supabase.js';

const config = runtimeConfig();
const rate = envNumber('SOAK_RATE', 50);
const duration = __ENV.SOAK_DURATION || '10m';

export const options = standardOptions(
  {
    public_browse_soak: {
      executor: 'constant-arrival-rate',
      rate,
      timeUnit: '1s',
      duration,
      preAllocatedVUs: 40,
      maxVUs: 160,
      exec: 'browsePlaces',
    },
  },
  {
    'http_req_duration{scenario:public_browse_soak}': ['p(95)<1500'],
    'checks{scenario:public_browse_soak}': ['rate>0.99'],
  },
);

export function setup() {
  if (!config.anonKey) {
    fail('SUPABASE_ANON_KEY is required for public soak tests.');
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
    { flow: 'public_soak' },
  );

  check(browse.response, {
    'soak browse returned 200': (r) => r.status === 200,
  });

  sleep(0.2);
}
