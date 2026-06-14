import { check, sleep } from 'k6';
import exec from 'k6/execution';

import { envNumber, runtimeConfig } from './lib/config.js';
import { providerHubRead } from './lib/flows.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { requireStagingOnly, stagingWriteOptions } from './lib/staging.js';
import {
  authInsert,
  buildCanonicalPlaceRow,
  rpc,
  serviceGet,
  servicePatch,
  serviceRpc,
} from './lib/supabase.js';

const config = runtimeConfig();

export const options = stagingWriteOptions(
  'staging_admin_moderation',
  'stagingAdminModeration',
  {
    'http_req_duration{scenario:staging_admin_moderation}': ['p(95)<4000'],
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
  teardownSharedFixtures(config, data);
}

export function stagingAdminModeration(data) {
  const providers = data.providers?.length ? data.providers : [data.provider];
  const provider = providers[(exec.vu.idInTest - 1) % providers.length];
  const suffix = uniqueSuffix();

  const pendingPlaceInsert = authInsert(
    config,
    provider.accessToken,
    'places?select=*',
    [
      buildCanonicalPlaceRow({
        providerId: provider.providerId,
        city: provider.referenceCity,
        category: provider.referenceCategory,
        placeName: `K6 Moderation Pending ${suffix}`,
        slug: `k6-moderation-pending-${suffix}`,
        description: 'Pending place for admin moderation staging flow',
        address: `Moderation street ${suffix}`,
      }),
    ],
    { flow: 'staging_moderation' },
  );
  check(pendingPlaceInsert.response, {
    'moderation fixture place created': (r) => r.status >= 200 && r.status < 300,
  });
  const pendingPlace = Array.isArray(pendingPlaceInsert.data)
    ? pendingPlaceInsert.data[0]
    : null;

  const approvePlace = serviceRpc(
    config,
    'admin_set_place_status_uuid',
    {
      _place_uuid: pendingPlace.id,
      _status: 'approved',
      _rejection_reason: null,
      _allow_edit: false,
    },
    { flow: 'staging_moderation' },
  );
  check(approvePlace.response, {
    'pending place approved by admin': (r) => r.status === 200,
  });

  const rejectPlace = serviceRpc(
    config,
    'admin_set_place_status_uuid',
    {
      _place_uuid: pendingPlace.id,
      _status: 'rejected',
      _rejection_reason: 'k6 staging rejection reason',
      _allow_edit: false,
    },
    { flow: 'staging_moderation' },
  );
  check(rejectPlace.response, {
    'approved place rejected by admin': (r) => r.status === 200,
  });

  const requestApprovedEdit = rpc(
    config,
    provider.accessToken,
    'request_place_edit',
    {
      _place_id: provider.approvedPlaceUuid,
      _note: 'k6 staging edit request for moderation flow',
    },
    { flow: 'staging_moderation' },
  );
  check(requestApprovedEdit.response, {
    'edit request opened': (r) => r.status === 200,
  });

  const approveEditWindow = servicePatch(
    config,
    `places?id=eq.${provider.approvedPlaceUuid}`,
    {
      edit_request_status: 'approved',
      edit_request_response: 'تم فتح التعديل للاختبار.',
      edit_request_reviewed_at: new Date().toISOString(),
      edit_allowed: true,
      updated_at: new Date().toISOString(),
    },
    { flow: 'staging_moderation' },
  );
  check(approveEditWindow.response, {
    'place edit window approved by admin': (r) => r.status >= 200 && r.status < 300,
  });

  const editSubmission = rpc(
    config,
    provider.accessToken,
    'submit_provider_place_edit',
    {
      _place_id: provider.approvedPlaceUuid,
      _place_name: `K6 Moderation Edit ${suffix}`,
      _activity_name: provider.referenceCategory.name_ar,
      _budget: '100 إلى 500 جنيه',
      _price_range: '100 إلى 500 جنيه',
      _address: `Moderated address ${suffix}`,
      _city_name: provider.referenceCity.name_ar,
      _description: 'Submitted for moderation by k6 staging flow',
      _rating: 4,
      _image_storage_paths: [],
      _note: 'k6 staging moderation flow',
    },
    { flow: 'staging_moderation' },
  );
  check(editSubmission.response, {
    'place edit submitted for admin review': (r) => r.status === 200,
  });

  const latestSubmission = serviceGet(
    config,
    `place_edit_submissions?select=id,status,place_id,previous_data,proposed_data&place_id=eq.${provider.approvedPlaceUuid}&order=submitted_at.desc&limit=1`,
    { flow: 'staging_moderation' },
  );
  check(latestSubmission.response, {
    'latest edit submission loaded': (r) => r.status === 200,
  });

  const submission = Array.isArray(latestSubmission.data) ? latestSubmission.data[0] : null;
  const approveSubmission = serviceRpc(
    config,
    'admin_review_place_edit_submission',
    {
      _submission_id: submission?.id,
      _decision: 'approved',
      _reason: null,
    },
    { flow: 'staging_moderation' },
  );
  check(approveSubmission.response, {
    'edit submission approved by admin': (r) => r.status === 200,
  });

  const campaignRows = serviceGet(
    config,
    `promotional_campaigns?select=id,status,title,edit_request_status&provider_id=eq.${provider.providerId}&order=created_at.desc&limit=5`,
    { flow: 'staging_moderation' },
  );
  check(campaignRows.response, {
    'campaign moderation queue visible': (r) => r.status === 200,
  });

  providerHubRead(config, provider);
  sleep(0.2);
}
