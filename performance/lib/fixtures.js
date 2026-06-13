import { fail } from 'k6';

import {
  cleanupFixtures,
  createAdminFixture,
  createProviderFixture,
  createRegularUser,
  fetchSamplePlace,
} from './supabase.js';

export function requireAuthEnv(config) {
  if (!config.anonKey) {
    fail('SUPABASE_ANON_KEY is required for authenticated performance scripts.');
  }
  if (!config.serviceRoleKey) {
    fail(
      'SUPABASE_SERVICE_ROLE_KEY is required for authenticated performance scripts.',
    );
  }
}

export function buildSharedFixtures(config, { includeRegular = true, includeProvider = true, includeAdmin = true } = {}) {
  requireAuthEnv(config);
  const samplePlace = fetchSamplePlace(config);
  const label = `k6perf.${Date.now()}`;

  return {
    samplePlace,
    regular: includeRegular ? createRegularUser(config, label) : null,
    provider: includeProvider ? createProviderFixture(config, label) : null,
    admin: includeAdmin ? createAdminFixture(config, label) : null,
  };
}

export function teardownSharedFixtures(config, data) {
  cleanupFixtures(config, data);
}
