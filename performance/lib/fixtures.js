import { fail } from 'k6';

import { requireStagingOnly } from './staging.js';
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

export function buildSharedFixtures(
  config,
  {
    includeRegular = true,
    includeProvider = true,
    includeAdmin = true,
    regularCount = 1,
    providerCount = 1,
    adminCount = 1,
  } = {},
) {
  requireAuthEnv(config);
  requireStagingOnly(config);
  const samplePlace = fetchSamplePlace(config);
  const label = `k6perf.${Date.now()}`;
  const safeRegularCount = includeRegular ? Math.max(1, Number(regularCount)) : 0;
  const safeProviderCount = includeProvider ? Math.max(1, Number(providerCount)) : 0;
  const safeAdminCount = includeAdmin ? Math.max(1, Number(adminCount)) : 0;
  const regularUsers = Array.from({ length: safeRegularCount }, (_, index) =>
    createRegularUser(config, `${label}.${index}`),
  );
  const providers = Array.from({ length: safeProviderCount }, (_, index) =>
    createProviderFixture(config, `${label}.${index}`),
  );
  const admins = Array.from({ length: safeAdminCount }, (_, index) =>
    createAdminFixture(config, `${label}.${index}`),
  );

  return {
    samplePlace,
    regular: regularUsers[0] || null,
    provider: providers[0] || null,
    admin: admins[0] || null,
    regularUsers,
    providers,
    admins,
  };
}

export function teardownSharedFixtures(config, data) {
  cleanupFixtures(config, data);
}
