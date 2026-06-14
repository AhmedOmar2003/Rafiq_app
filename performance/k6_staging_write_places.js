import { check, fail, sleep } from 'k6';
import exec from 'k6/execution';

import { envNumber, runtimeConfig } from './lib/config.js';
import { providerHubRead } from './lib/flows.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { requireStagingOnly, stagingWriteOptions } from './lib/staging.js';
import {
  authInsert,
  buildCanonicalPlaceRow,
  cleanupStoragePrefix,
  rpc,
  serviceGet,
  servicePatch,
  storageUploadPlaceholderPngObject,
} from './lib/supabase.js';

const config = runtimeConfig();

export const options = stagingWriteOptions(
  'staging_place_writes',
  'stagingPlaceWrites',
  {
    'http_req_duration{scenario:staging_place_writes}': ['p(95)<3500'],
  },
);

function uniqueSuffix() {
  return `${Date.now()}-${exec.vu.idInTest}-${exec.scenario.iterationInTest}`;
}

function approveEditRequest(placeUuid) {
  return servicePatch(
    config,
    `places?id=eq.${placeUuid}`,
    {
      edit_request_status: 'approved',
      edit_request_response:
        'تم فتح التعديل في بيئة الاختبار. عدّل وأعد الإرسال للمراجعة.',
      edit_request_reviewed_at: new Date().toISOString(),
      edit_allowed: true,
      updated_at: new Date().toISOString(),
    },
    { flow: 'staging_places' },
  );
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
  }
  teardownSharedFixtures(config, data);
}

export function stagingPlaceWrites(data) {
  const providers = data.providers?.length ? data.providers : [data.provider];
  const provider = providers[(exec.vu.idInTest - 1) % providers.length];
  if (!provider?.accessToken) {
    fail('Provider staging fixture is missing.');
  }

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
        placeName: `K6 Staging Place ${suffix}`,
        slug: `k6-staging-place-${suffix}`,
        description: 'Created by k6 staging place write script',
        address: `Staging Street ${suffix}`,
      }),
    ],
    { flow: 'staging_places' },
  );

  check(createPlace.response, {
    'staging place created': (r) => r.status >= 200 && r.status < 300,
  });

  const createdPlace = Array.isArray(createPlace.data) ? createPlace.data[0] : null;
  if (!createdPlace?.id) {
    fail(`Could not create staging place: ${JSON.stringify(createPlace.data)}`);
  }

  const updatePending = rpc(
    config,
    provider.accessToken,
    'update_provider_place',
    {
      _place_id: createdPlace.id,
      _place_name: `K6 Pending Update ${suffix}`,
      _activity_name: provider.referenceCategory.name_ar,
      _budget: '100 إلى 500 جنيه',
      _price_range: '100 إلى 500 جنيه',
      _address: `Updated staging address ${suffix}`,
      _city_name: provider.referenceCity.name_ar,
      _description: 'Updated while still pending review',
      _image_path: null,
      _rating: 0,
    },
    { flow: 'staging_places' },
  );
  check(updatePending.response, {
    'pending place updated': (r) => r.status === 200,
  });

  const pendingImagePaths = [0, 1].map(
    (index) => `${provider.providerId}/${createdPlace.id}/${suffix}-pending-${index}.png`,
  );
  for (const path of pendingImagePaths) {
    const upload = storageUploadPlaceholderPngObject(
      config,
      provider.accessToken,
      'place-images',
      path,
      { flow: 'staging_places' },
    );
    check(upload.response, {
      'pending place image uploaded': (r) => r.status >= 200 && r.status < 300,
    });
  }

  const registerPendingImages = rpc(
    config,
    provider.accessToken,
    'register_provider_place_images',
    {
      _place_id: createdPlace.id,
      _storage_paths: pendingImagePaths,
      _alt_text: 'K6 staging pending place',
    },
    { flow: 'staging_places' },
  );
  check(registerPendingImages.response, {
    'pending place images registered': (r) => r.status === 200,
  });

  const requestApprovedEdit = rpc(
    config,
    provider.accessToken,
    'request_place_edit',
    {
      _place_id: provider.approvedPlaceUuid,
      _note: 'k6 staging request to edit an approved place',
    },
    { flow: 'staging_places' },
  );
  check(requestApprovedEdit.response, {
    'approved place edit requested': (r) => r.status === 200,
  });

  const openEditWindow = approveEditRequest(provider.approvedPlaceUuid);
  check(openEditWindow.response, {
    'approved place edit request opened by admin': (r) =>
      r.status >= 200 && r.status < 300,
  });

  const approvedEditImagePaths = [0, 1].map(
    (index) =>
      `${provider.providerId}/${provider.approvedPlaceUuid}/${suffix}-approved-${index}.png`,
  );
  for (const path of approvedEditImagePaths) {
    const upload = storageUploadPlaceholderPngObject(
      config,
      provider.accessToken,
      'place-images',
      path,
      { flow: 'staging_places' },
    );
    check(upload.response, {
      'approved place edit image uploaded': (r) =>
        r.status >= 200 && r.status < 300,
    });
  }

  const submitApprovedEdit = rpc(
    config,
    provider.accessToken,
    'submit_provider_place_edit',
    {
      _place_id: provider.approvedPlaceUuid,
      _place_name: `K6 Approved Edit ${suffix}`,
      _activity_name: provider.referenceCategory.name_ar,
      _budget: '100 إلى 500 جنيه',
      _price_range: '100 إلى 500 جنيه',
      _address: `Approved edit address ${suffix}`,
      _city_name: provider.referenceCity.name_ar,
      _description: 'Submitted by k6 for staging moderation testing',
      _rating: 4.2,
      _image_storage_paths: approvedEditImagePaths,
      _note: 'k6 staging edit submission',
    },
    { flow: 'staging_places' },
  );
  check(submitApprovedEdit.response, {
    'approved place edit submitted': (r) => r.status === 200,
  });

  const submissions = serviceGet(
    config,
    `place_edit_submissions?select=id,status,place_id,submitted_at&place_id=eq.${provider.approvedPlaceUuid}&order=submitted_at.desc&limit=1`,
    { flow: 'staging_places' },
  );
  check(submissions.response, {
    'edit submission visible to admin': (r) => r.status === 200,
  });

  providerHubRead(config, provider);
  sleep(0.2);
}
