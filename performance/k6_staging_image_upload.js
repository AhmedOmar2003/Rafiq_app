import { check, sleep } from 'k6';
import exec from 'k6/execution';

import { runtimeConfig } from './lib/config.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { requireStagingOnly, stagingWriteOptions } from './lib/staging.js';
import {
  authInsert,
  cleanupStoragePrefix,
  rpc,
  storageUploadTextObject,
} from './lib/supabase.js';

const config = runtimeConfig();

export const options = stagingWriteOptions(
  'staging_image_upload',
  'stagingImageUpload',
  {
    'http_req_duration{scenario:staging_image_upload}': ['p(95)<4000'],
  },
);

function svgImage(title, tone) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="720" viewBox="0 0 1080 720">
  <rect width="1080" height="720" rx="42" fill="${tone}"/>
  <text x="540" y="350" text-anchor="middle" font-size="52" fill="#FFFFFF">${title}</text>
</svg>`;
}

function uniqueSuffix() {
  return `${Date.now()}-${exec.vu.idInTest}-${exec.scenario.iterationInTest}`;
}

export function setup() {
  requireStagingOnly(config);
  return buildSharedFixtures(config, {
    includeRegular: false,
    includeProvider: true,
    includeAdmin: false,
  });
}

export function teardown(data) {
  if (data?.provider?.providerId) {
    cleanupStoragePrefix(config, 'place-images', `${data.provider.providerId}/`);
    cleanupStoragePrefix(config, 'campaign-assets', `${data.provider.providerId}/`);
  }
  teardownSharedFixtures(config, data);
}

export function stagingImageUpload(data) {
  const provider = data.provider;
  const suffix = uniqueSuffix();

  const createPlace = authInsert(
    config,
    provider.accessToken,
    'places',
    [
      {
        provider_id: provider.providerId,
        place_name: `K6 Upload Place ${suffix}`,
        activity_name: 'كوفي شوب',
        budget: '100 إلى 500 جنيه',
        price_range: '100 إلى 500 جنيه',
        place_address: `Upload street ${suffix}`,
        city_name: 'القاهرة',
        description: 'Used to benchmark place image uploads on staging',
        rating: 0,
      },
    ],
    { flow: 'staging_uploads' },
  );
  check(createPlace.response, {
    'upload fixture place created': (r) => r.status >= 200 && r.status < 300,
  });

  const place = Array.isArray(createPlace.data) ? createPlace.data[0] : null;
  const placePaths = [0, 1, 2].map(
    (index) => `${provider.providerId}/${place.id}/${suffix}-gallery-${index}.svg`,
  );

  for (const [index, path] of placePaths.entries()) {
    const upload = storageUploadTextObject(
      config,
      provider.accessToken,
      'place-images',
      path,
      svgImage(`Place ${index + 1}`, ['#9A3412', '#B45309', '#92400E'][index] || '#7C2D12'),
      'image/svg+xml',
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

  const campaignAssetPath = `${provider.providerId}/${provider.approvedPlaceUuid}/${suffix}-campaign.svg`;
  const campaignUpload = storageUploadTextObject(
    config,
    provider.accessToken,
    'campaign-assets',
    campaignAssetPath,
    svgImage('Campaign Asset', '#6B2E12'),
    'image/svg+xml',
    { flow: 'staging_uploads' },
  );
  check(campaignUpload.response, {
    'campaign asset uploaded': (r) => r.status >= 200 && r.status < 300,
  });

  sleep(0.2);
}
