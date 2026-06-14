import { check, sleep } from 'k6';
import exec from 'k6/execution';

import { envNumber, runtimeConfig } from './lib/config.js';
import { providerHubRead } from './lib/flows.js';
import { buildSharedFixtures, teardownSharedFixtures } from './lib/fixtures.js';
import { requireStagingOnly, stagingWriteOptions } from './lib/staging.js';
import {
  cleanupStoragePrefix,
  rpc,
  serviceGet,
  servicePatch,
  storageUploadPlaceholderPngObject,
} from './lib/supabase.js';

const config = runtimeConfig();

export const options = stagingWriteOptions(
  'staging_campaign_writes',
  'stagingCampaignWrites',
  {
    'http_req_duration{scenario:staging_campaign_writes}': ['p(95)<3500'],
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
    cleanupStoragePrefix(config, 'campaign-assets', `${provider.providerId}/`);
  }
  teardownSharedFixtures(config, data);
}

export function stagingCampaignWrites(data) {
  const providers = data.providers?.length ? data.providers : [data.provider];
  const provider = providers[(exec.vu.idInTest - 1) % providers.length];
  const suffix = uniqueSuffix();
  const startsAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  const endsAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

  const createAssetPath = `${provider.providerId}/${provider.approvedPlaceUuid}/${suffix}-create.png`;
  const createAsset = storageUploadPlaceholderPngObject(
    config,
    provider.accessToken,
    'campaign-assets',
    createAssetPath,
    { flow: 'staging_campaigns' },
  );
  check(createAsset.response, {
    'campaign create asset uploaded': (r) => r.status >= 200 && r.status < 300,
  });

  const createCampaign = rpc(
    config,
    provider.accessToken,
    'create_provider_campaign',
    {
      _place_id: provider.approvedPlaceUuid,
      _kind: 'discount',
      _title: `K6 Campaign ${suffix}`,
      _body: 'Created by k6 staging campaign test',
      _image_path: createAssetPath,
      _cta_label: 'اعرف أكتر',
      _starts_at: startsAt,
      _ends_at: endsAt,
    },
    { flow: 'staging_campaigns' },
  );
  check(createCampaign.response, {
    'campaign created': (r) => r.status === 200,
  });

  const campaignId = String(createCampaign.data || '');
  const pendingRow = serviceGet(
    config,
    `promotional_campaigns?select=id,status,title,place_id,edit_request_status&id=eq.${campaignId}&limit=1`,
    { flow: 'staging_campaigns' },
  );
  check(pendingRow.response, {
    'pending campaign visible to admin': (r) => r.status === 200,
  });

  const requestEdit = servicePatch(
    config,
    `promotional_campaigns?id=eq.${campaignId}`,
    {
      status: 'active',
      approved_at: new Date().toISOString(),
      rejection_reason: null,
      edit_allowed: false,
      edit_request_status: 'none',
      updated_at: new Date().toISOString(),
    },
    { flow: 'staging_campaigns' },
  );
  check(requestEdit.response, {
    'campaign activated for edit request flow': (r) => r.status >= 200 && r.status < 300,
  });

  const openEditRequest = rpc(
    config,
    provider.accessToken,
    'request_campaign_edit',
    {
      _campaign_id: campaignId,
      _note: 'k6 staging campaign edit request',
    },
    { flow: 'staging_campaigns' },
  );
  check(openEditRequest.response, {
    'campaign edit requested': (r) => r.status === 200,
  });

  const approveEditWindow = servicePatch(
    config,
    `promotional_campaigns?id=eq.${campaignId}`,
    {
      edit_allowed: true,
      edit_request_status: 'approved',
      edit_request_response:
        'تم فتح تعديل الإعلان في بيئة الاختبار. عدّل وأعد الإرسال للمراجعة.',
      edit_request_reviewed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
    { flow: 'staging_campaigns' },
  );
  check(approveEditWindow.response, {
    'campaign edit request approved by admin': (r) =>
      r.status >= 200 && r.status < 300,
  });

  const updateAssetPath = `${provider.providerId}/${provider.approvedPlaceUuid}/${suffix}-update.png`;
  const updateAsset = storageUploadPlaceholderPngObject(
    config,
    provider.accessToken,
    'campaign-assets',
    updateAssetPath,
    { flow: 'staging_campaigns' },
  );
  check(updateAsset.response, {
    'campaign update asset uploaded': (r) => r.status >= 200 && r.status < 300,
  });

  const updateCampaign = rpc(
    config,
    provider.accessToken,
    'update_provider_campaign',
    {
      _campaign_id: campaignId,
      _place_id: provider.approvedPlaceUuid,
      _kind: 'discount',
      _title: `K6 Campaign Updated ${suffix}`,
      _body: 'Updated by k6 staging campaign test',
      _image_path: updateAssetPath,
      _cta_label: 'شوف العرض',
      _starts_at: startsAt,
      _ends_at: endsAt,
    },
    { flow: 'staging_campaigns' },
  );
  check(updateCampaign.response, {
    'campaign resubmitted for review': (r) => r.status === 200,
  });

  providerHubRead(config, provider);
  sleep(0.2);
}
