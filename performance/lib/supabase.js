import http from 'k6/http';
import { check, fail } from 'k6';

function jsonHeaders(apiKey, token, extra = {}) {
  return {
    apikey: apiKey,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    ...extra,
  };
}

function storageObjectUrl(baseUrl, bucket, objectPath) {
  const encodedPath = String(objectPath)
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
  return `${baseUrl}/storage/v1/object/${bucket}/${encodedPath}`;
}

function maybeParseJson(body) {
  if (!body) return null;
  try {
    return JSON.parse(body);
  } catch (_) {
    return body;
  }
}

export function uniqueEmail(prefix) {
  const stamp = Date.now();
  const suffix = Math.floor(Math.random() * 1e9)
    .toString()
    .padStart(9, '0');
  return `${prefix}.${stamp}.${suffix}@gmail.com`;
}

function budgetBucketFor(priceMin) {
  if (priceMin <= 100) return 'low';
  if (priceMin <= 500) return 'mid';
  if (priceMin <= 1000) return 'high';
  return 'premium';
}

export function fetchReferenceTaxonomy(config) {
  const cities = serviceGet(config, 'cities?select=id,name_ar&limit=1', {
    flow: 'staging_taxonomy',
  });
  const categories = serviceGet(config, 'categories?select=id,name_ar&limit=1', {
    flow: 'staging_taxonomy',
  });

  if (!cities.ok || !Array.isArray(cities.data) || cities.data.length === 0) {
    fail(`Could not fetch staging city reference: ${JSON.stringify(cities.data)}`);
  }
  if (!categories.ok || !Array.isArray(categories.data) || categories.data.length === 0) {
    fail(
      `Could not fetch staging category reference: ${JSON.stringify(categories.data)}`,
    );
  }

  return {
    city: cities.data[0],
    category: categories.data[0],
  };
}

export function buildCanonicalPlaceRow({
  id,
  providerId,
  city,
  category,
  placeName,
  slug,
  description,
  address,
  budget = '100 إلى 500 جنيه',
  priceMin = 100,
  priceMax = 500,
  status = 'pending',
  approvedBy = null,
  approvedAt = null,
  imagePath = null,
}) {
  return {
    ...(id ? { id } : {}),
    provider_id: providerId,
    city_id: city.id,
    category_id: category.id,
    slug,
    name: placeName,
    description,
    address,
    price_min: priceMin,
    price_max: priceMax,
    budget_bucket: budgetBucketFor(priceMin),
    place_name: placeName,
    activity_name: category.name_ar,
    budget,
    price_range: budget,
    place_address: address,
    city_name: city.name_ar,
    rating: 0,
    image_path: imagePath,
    status,
    approved_by: approvedBy,
    approved_at: approvedAt,
  };
}

export function httpJson(method, url, { headers = {}, body, tags = {} } = {}) {
  const response = http.request(method, url, body ? JSON.stringify(body) : null, {
    headers,
    tags,
  });
  return {
    response,
    ok: response.status >= 200 && response.status < 300,
    status: response.status,
    data: maybeParseJson(response.body),
  };
}

export function authSignIn(config, email, password) {
  return httpJson(
    'POST',
    `${config.supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      headers: {
        apikey: config.anonKey,
        'Content-Type': 'application/json',
      },
      body: { email, password },
      tags: { endpoint: 'auth_sign_in' },
    },
  );
}

export function rpc(config, token, name, params, extraTags = {}) {
  return httpJson('POST', `${config.supabaseUrl}/rest/v1/rpc/${name}`, {
    headers: jsonHeaders(config.anonKey, token),
    body: params,
    tags: { endpoint: name, ...extraTags },
  });
}

export function serviceRpc(config, name, params, extraTags = {}) {
  return httpJson('POST', `${config.supabaseUrl}/rest/v1/rpc/${name}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey),
    body: params,
    tags: { endpoint: name, ...extraTags },
  });
}

export function restGet(config, token, path, extraTags = {}) {
  return httpJson('GET', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.anonKey, token),
    tags: { endpoint: path, ...extraTags },
  });
}

export function serviceGet(config, path, extraTags = {}) {
  return httpJson('GET', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey),
    tags: { endpoint: path, ...extraTags },
  });
}

export function serviceHeadCount(config, path, extraTags = {}) {
  return http.request('HEAD', `${config.supabaseUrl}/rest/v1/${path}`, null, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey, {
      Prefer: 'count=exact',
    }),
    tags: { endpoint: path, ...extraTags },
  });
}

export function serviceInsert(config, path, rows, extraTags = {}) {
  return httpJson('POST', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey, {
      Prefer: 'return=representation',
    }),
    body: rows,
    tags: { endpoint: path, ...extraTags },
  });
}

export function servicePatch(config, path, patch, extraTags = {}) {
  return httpJson('PATCH', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey, {
      Prefer: 'return=representation',
    }),
    body: patch,
    tags: { endpoint: path, ...extraTags },
  });
}

export function serviceDelete(config, path, extraTags = {}) {
  return httpJson('DELETE', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey, {
      Prefer: 'return=minimal',
    }),
    tags: { endpoint: path, ...extraTags },
  });
}

export function authInsert(config, token, path, rows, extraTags = {}) {
  return httpJson('POST', `${config.supabaseUrl}/rest/v1/${path}`, {
    headers: jsonHeaders(config.anonKey, token, {
      Prefer: 'return=representation',
    }),
    body: rows,
    tags: { endpoint: path, ...extraTags },
  });
}

export function storageUploadTextObject(
  config,
  token,
  bucket,
  objectPath,
  textBody,
  contentType = 'image/svg+xml',
  extraTags = {},
) {
  const response = http.request(
    'POST',
    storageObjectUrl(config.supabaseUrl, bucket, objectPath),
    textBody,
    {
      headers: jsonHeaders(config.anonKey, token, {
        'Content-Type': contentType,
        'x-upsert': 'true',
      }),
      tags: { endpoint: `${bucket}_upload`, ...extraTags },
    },
  );

  return {
    response,
    ok: response.status >= 200 && response.status < 300,
    status: response.status,
    data: maybeParseJson(response.body),
  };
}

export function storageUploadPlaceholderPngObject(
  config,
  token,
  bucket,
  objectPath,
  extraTags = {},
) {
  return storageUploadTextObject(
    config,
    token,
    bucket,
    objectPath,
    'rafiq-k6-png-placeholder',
    'image/png',
    extraTags,
  );
}

export function storageDeleteObject(
  config,
  token,
  bucket,
  objectPath,
  extraTags = {},
) {
  const response = http.request(
    'DELETE',
    storageObjectUrl(config.supabaseUrl, bucket, objectPath),
    null,
    {
      headers: {
        apikey: token === config.serviceRoleKey ? config.serviceRoleKey : config.anonKey,
        Authorization: `Bearer ${token}`,
      },
      tags: { endpoint: `${bucket}_delete`, ...extraTags },
    },
  );

  return {
    response,
    ok: response.status >= 200 && response.status < 300,
    status: response.status,
    data: maybeParseJson(response.body),
  };
}

export function storageListPrefix(config, token, bucket, prefix, extraTags = {}) {
  return httpJson('POST', `${config.supabaseUrl}/storage/v1/object/list/${bucket}`, {
    headers: jsonHeaders(
      token === config.serviceRoleKey ? config.serviceRoleKey : config.anonKey,
      token,
    ),
    body: {
      prefix,
      limit: 1000,
      offset: 0,
      sortBy: { column: 'name', order: 'asc' },
    },
    tags: { endpoint: `${bucket}_list`, ...extraTags },
  });
}

function cleanupStoragePrefixRecursive(config, bucket, prefix) {
  const listing = storageListPrefix(
    config,
    config.serviceRoleKey,
    bucket,
    prefix,
    { flow: 'cleanup' },
  );

  if (!listing.ok || !Array.isArray(listing.data)) {
    return;
  }

  for (const row of listing.data) {
    const name = row?.name;
    if (!name) continue;

    // Supabase Storage returns folder-like rows with a null id. Recurse into
    // them instead of trying to delete them as if they were files.
    if (row?.id == null) {
      cleanupStoragePrefixRecursive(config, bucket, `${prefix}${name}/`);
      continue;
    }

    storageDeleteObject(
      config,
      config.serviceRoleKey,
      bucket,
      name.startsWith(prefix) ? name : `${prefix}${name}`,
      { flow: 'cleanup' },
    );
  }
}

export function cleanupStoragePrefix(config, bucket, prefix) {
  cleanupStoragePrefixRecursive(config, bucket, prefix);
}

export function adminCreateUser(config, email, fullName) {
  return httpJson('POST', `${config.supabaseUrl}/auth/v1/admin/users`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey),
    body: {
      email,
      password: config.defaultPassword,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    },
    tags: { endpoint: 'auth_admin_create_user' },
  });
}

export function adminDeleteUser(config, userId) {
  return httpJson('DELETE', `${config.supabaseUrl}/auth/v1/admin/users/${userId}`, {
    headers: jsonHeaders(config.serviceRoleKey, config.serviceRoleKey),
    tags: { endpoint: 'auth_admin_delete_user' },
  });
}

export function fetchSamplePlace(config) {
  const result = rpc(config, config.anonKey, 'browse_ranked_places', {
    _city_name: null,
    _budget: null,
    _activity_name: null,
    _limit: 1,
  });
  if (!result.ok || !Array.isArray(result.data) || result.data.length === 0) {
    fail(`Could not fetch sample place: ${JSON.stringify(result.data)}`);
  }
  const row = result.data[0];
  return {
    placeUuid: row.id,
    placeId: row.id,
    imageUrl: row.image_path || config.sampleImageUrl,
  };
}

export function createProviderFixture(config, label) {
  const providerEmail = uniqueEmail(`${label}.provider`);
  const createUser = adminCreateUser(config, providerEmail, 'Perf Provider');
  if (!createUser.ok) {
    fail(`Provider user creation failed: ${JSON.stringify(createUser.data)}`);
  }
  const providerUserId = createUser.data.user?.id || createUser.data.id;

  const signIn = authSignIn(config, providerEmail, config.defaultPassword);
  if (!signIn.ok) {
    fail(`Provider sign-in failed: ${JSON.stringify(signIn.data)}`);
  }
  const providerToken = signIn.data.access_token;

  const becomeProvider = rpc(config, providerToken, 'become_provider', {
    _business_name: 'Perf Provider Hub',
    _contact_email: providerEmail,
  });
  if (!becomeProvider.ok) {
    fail(`become_provider failed: ${JSON.stringify(becomeProvider.data)}`);
  }
  const providerId = String(becomeProvider.data);
  const taxonomy = fetchReferenceTaxonomy(config);

  const plan = rpc(config, providerToken, 'apply_demo_subscription', {
    _tier: 'pro',
    _yearly: false,
  });
  check(plan.response, {
    'provider plan ready': (r) => r.status >= 200 && r.status < 300,
  });
  const approveProvider = servicePatch(
    config,
    `providers?id=eq.${providerId}`,
    {
      status: 'approved',
      updated_at: new Date().toISOString(),
    },
    { flow: 'provider_fixture' },
  );
  check(approveProvider.response, {
    'provider fixture approved': (r) => r.status >= 200 && r.status < 300,
  });
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;

  const approvedInsert = serviceInsert(
    config,
    'places?select=*',
    [
      buildCanonicalPlaceRow({
        providerId,
        city: taxonomy.city,
        category: taxonomy.category,
        placeName: 'Perf Approved Place',
        slug: `perf-approved-${suffix}`,
        description: 'Approved fixture for performance tests',
        address: 'Staging approved fixture address',
        status: 'approved',
        approvedAt: new Date().toISOString(),
      }),
    ],
    { endpoint: 'provider_place_insert' },
  );
  if (!approvedInsert.ok || !Array.isArray(approvedInsert.data)) {
    fail(`Approved place insert failed: ${JSON.stringify(approvedInsert.data)}`);
  }
  const approvedPlace = approvedInsert.data[0];

  const pendingInsert = authInsert(
    config,
    providerToken,
    'places?select=*',
    [
      buildCanonicalPlaceRow({
        providerId,
        city: taxonomy.city,
        category: taxonomy.category,
        placeName: 'Perf Pending Place',
        slug: `perf-pending-${suffix}`,
        description: 'Pending fixture for performance tests',
        address: 'Staging pending fixture address',
      }),
    ],
    { endpoint: 'provider_place_insert_pending' },
  );
  if (!pendingInsert.ok || !Array.isArray(pendingInsert.data)) {
    fail(`Pending place insert failed: ${JSON.stringify(pendingInsert.data)}`);
  }
  const pendingPlace = pendingInsert.data[0];

  const campaign = rpc(config, providerToken, 'create_provider_campaign', {
    _place_id: approvedPlace.id,
    _kind: 'discount',
    _title: 'Perf Active Campaign',
    _body: 'Campaign fixture for performance tests',
    _image_path: null,
    _cta_label: 'اعرف أكتر',
    _starts_at: new Date(Date.now() - 60 * 1000).toISOString(),
    _ends_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
  });
  let campaignId = null;
  if (campaign.ok) {
    campaignId = String(campaign.data);
    const activateCampaign = servicePatch(
      config,
      `promotional_campaigns?id=eq.${campaignId}`,
      {
        status: 'active',
        approved_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
    );
    check(activateCampaign.response, {
      'activated fixture campaign': (r) => r.status >= 200 && r.status < 300,
    });
  }

  return {
    email: providerEmail,
    userId: providerUserId,
    accessToken: providerToken,
    refreshToken: signIn.data.refresh_token,
    providerId,
    approvedPlaceUuid: approvedPlace.id,
    pendingPlaceUuid: pendingPlace.id,
    campaignId,
    referenceCity: taxonomy.city,
    referenceCategory: taxonomy.category,
  };
}

export function createRegularUser(config, label) {
  const email = uniqueEmail(`${label}.user`);
  const createUser = adminCreateUser(config, email, 'Perf Regular User');
  if (!createUser.ok) {
    fail(`Regular user creation failed: ${JSON.stringify(createUser.data)}`);
  }
  const userId = createUser.data.user?.id || createUser.data.id;
  const signIn = authSignIn(config, email, config.defaultPassword);
  if (!signIn.ok) {
    fail(`Regular sign-in failed: ${JSON.stringify(signIn.data)}`);
  }
  return {
    email,
    userId,
    accessToken: signIn.data.access_token,
    refreshToken: signIn.data.refresh_token,
  };
}

export function createAdminFixture(config, label) {
  const email = uniqueEmail(`${label}.admin`);
  const createUser = adminCreateUser(config, email, 'Perf Admin User');
  if (!createUser.ok) {
    fail(`Admin user creation failed: ${JSON.stringify(createUser.data)}`);
  }
  const userId = createUser.data.user?.id || createUser.data.id;
  const roleInsert = serviceInsert(config, 'admin_roles', [
    { user_id: userId, role: 'admin' },
  ]);
  if (!roleInsert.ok) {
    fail(`Admin role insert failed: ${JSON.stringify(roleInsert.data)}`);
  }
  const signIn = authSignIn(config, email, config.defaultPassword);
  if (!signIn.ok) {
    fail(`Admin sign-in failed: ${JSON.stringify(signIn.data)}`);
  }
  return {
    email,
    userId,
    accessToken: signIn.data.access_token,
    refreshToken: signIn.data.refresh_token,
  };
}

export function cleanupFixtures(config, fixtures) {
  if (!fixtures) return;

  if (fixtures.provider?.campaignId) {
    serviceDelete(config, `promotional_campaigns?id=eq.${fixtures.provider.campaignId}`);
  }
  if (fixtures.provider?.approvedPlaceUuid || fixtures.provider?.pendingPlaceUuid) {
    serviceDelete(
      config,
      `places?provider_id=eq.${fixtures.provider.providerId}`,
    );
  }
  if (fixtures.provider?.providerId) {
    serviceDelete(
      config,
      `providers?id=eq.${fixtures.provider.providerId}`,
    );
  }
  if (fixtures.regular?.userId) {
    serviceDelete(config, `favorites?user_id=eq.${fixtures.regular.userId}`);
  }
  if (fixtures.admin?.userId) {
    serviceDelete(config, `admin_roles?user_id=eq.${fixtures.admin.userId}`);
  }

  const userIds = [
    fixtures.regular?.userId,
    fixtures.provider?.userId,
    fixtures.admin?.userId,
  ].filter(Boolean);
  for (const userId of userIds) {
    adminDeleteUser(config, userId);
  }
}
