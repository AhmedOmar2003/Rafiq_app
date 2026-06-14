import { check, sleep } from 'k6';
import exec from 'k6/execution';

import { envNumber, runtimeConfig } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { requireStagingOnly, stagingWriteOptions } from './lib/staging.js';
import {
  authInsert,
  buildCanonicalPlaceRow,
  cleanupStoragePrefix,
  rpc,
  storageUploadPlaceholderPngObject,
} from './lib/supabase.js';

const config = runtimeConfig();

export const options = stagingWriteOptions(
  'staging_image_upload',
  'stagingImageUpload',
  {
    'http_req_duration{scenario:staging_image_upload}': ['p(95)<4000'],
  },
);

function uniqueSuffix() {
  return `${Date.now()}-${exec.vu.idInTest}-${exec.scenario.iterationInTest}`;
}

export function setup() {
  requireStagingOnly(config);
  return buildSharedFixtures(config, {
    includeRegular: false,
    includeProvider: true,
    includeAdmin: false,
    providerCount: envNumber('STAGING_VUS', 1),
  });
}

export function teardown(data) {
  for (const provider of data?.providers || []) {
    cleanupStoragePrefix(config, 'place-images', `${provider.providerId}/`);
    cleanupStoragePrefix(config, 'campaign-assets', `${provider.providerId}/`);
  }
  teardownSharedFixtures(config, data);
}

export function stagingImageUpload(data) {
  const providers = data.providers?.length ? data.providers : [data.provider];
  const provider = providers[(exec.vu.idInTest - 1) % providers.length];
  const suffix = uniqueSuffix();

  const createPlace = authInsert(
    config,
    provider.accessToken,
    'places?select=*',
    [
      buildCanonicalPlaceRow({
        providerId: provider.providerId,
        city: provider.referenceCity,
        category: provider.referenceCategory,
        placeName: `K6 Upload Place ${suffix}`,
        slug: `k6-upload-place-${suffix}`,
        description: 'Used to benchmark place image uploads on staging',
        address: `Upload street ${suffix}`,
      }),
    ],
    { flow: 'staging_uploads' },
  );
  check(createPlace.response, {
    'upload fixture place created': (r) => r.status >= 200 && r.status < 300,
  });

  const place = Array.isArray(createPlace.data) ? createPlace.data[0] : null;
  const placePaths = [0, 1, 2].map(
    (index) => `${provider.providerId}/${place.id}/${suffix}-gallery-${index}.png`,
  );

  for (const path of placePaths) {
    const upload = storageUploadPlaceholderPngObject(
      config,
      provider.accessToken,
      'place-images',
      path,
      { flow: 'staging_uploads' },
    );
    check(upload.response, {
      'place image uploaded': (r) => r.status >= 200 && r.status < 300,
    });
  }

  const registerImages = rpc(
    config,
    provider.accessToken,
    'register_provider_place_images',
    {
      _place_id: place.id,
      _storage_paths: placePaths,
      _alt_text: 'K6 staging upload test',
    },
    { flow: 'staging_uploads' },
  );
  check(registerImages.response, {
    'place gallery registered': (r) => r.status === 200,
  });

  const campaignAssetPath = `${provider.providerId}/${provider.approvedPlaceUuid}/${suffix}-campaign.png`;
  const campaignUpload = storageUploadPlaceholderPngObject(
    config,
    provider.accessToken,
    'campaign-assets',
    campaignAssetPath,
    { flow: 'staging_uploads' },
  );
  check(campaignUpload.response, {
    'campaign asset uploaded': (r) => r.status >= 200 && r.status < 300,
  });

  sleep(0.2);
}
