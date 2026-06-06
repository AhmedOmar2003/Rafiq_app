import { corsHeaders, preflight } from '../_shared/cors.ts';
import {
  AuthError,
  jsonError,
  jsonOk,
  rejectOversizedBody,
  requireAuth,
} from '../_shared/auth.ts';

type ProviderRow = { id: string };
type PlaceRow = { id: string; image_path: string | null };
type StoragePathRow = { storage_path: string | null };
type CampaignRow = { image_path: string | null };

function parsePublicPath(value: string | null, bucket: string): string | null {
  if (!value) return null;
  const marker = `/storage/v1/object/public/${bucket}/`;
  const idx = value.indexOf(marker);
  if (idx === -1) return null;
  const path = value.slice(idx + marker.length).trim();
  return path.length > 0 ? decodeURIComponent(path) : null;
}

function unique(values: Array<string | null | undefined>): string[] {
  return [...new Set(values.map((value) => value?.trim()).filter(Boolean) as string[])];
}

async function removeInChunks(
  removeFn: (paths: string[]) => Promise<{ error: { message: string } | null }>,
  paths: string[],
  warnings: string[],
  label: string,
) {
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    const { error } = await removeFn(batch);
    if (error) warnings.push(`${label}: ${error.message}`);
  }
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return jsonError(405, 'method not allowed', cors);
  const oversized = rejectOversizedBody(req, cors);
  if (oversized) return oversized;

  try {
    const ctx = await requireAuth(req, 'user');
    const body = await req.json().catch(() => ({}));
    const reason = typeof body?.reason === 'string' && body.reason.trim().length > 0
      ? body.reason.trim()
      : null;

    const { data: providerRows, error: providerError } = await ctx.serviceClient
      .from('providers')
      .select('id')
      .eq('owner_id', ctx.userId);
    if (providerError) return jsonError(500, providerError.message, cors);

    const providerIds = ((providerRows ?? []) as ProviderRow[]).map((row) => row.id).filter(Boolean);
    const warnings: string[] = [];

    let placeImagePaths: string[] = [];
    let providerDocumentPaths: string[] = [];
    let campaignAssetPaths: string[] = [];

    if (providerIds.length > 0) {
      const { data: placeRowsRaw, error: placeError } = await ctx.serviceClient
        .from('places')
        .select('id, image_path')
        .in('provider_id', providerIds);
      if (placeError) return jsonError(500, placeError.message, cors);

      const placeRows = (placeRowsRaw ?? []) as PlaceRow[];
      const placeIds = placeRows.map((row) => row.id).filter(Boolean);
      placeImagePaths = unique(
        placeRows.map((row) => parsePublicPath(row.image_path, 'place-images')),
      );

      if (placeIds.length > 0) {
        const { data: galleryRows, error: galleryError } = await ctx.serviceClient
          .from('place_images')
          .select('storage_path')
          .in('place_id', placeIds);
        if (galleryError) return jsonError(500, galleryError.message, cors);
        placeImagePaths = unique([
          ...placeImagePaths,
          ...((galleryRows ?? []) as StoragePathRow[]).map((row) => row.storage_path),
        ]);
      }

      const { data: docRows, error: docError } = await ctx.serviceClient
        .from('provider_documents')
        .select('storage_path')
        .in('provider_id', providerIds);
      if (docError) return jsonError(500, docError.message, cors);
      providerDocumentPaths = unique(
        ((docRows ?? []) as StoragePathRow[]).map((row) => row.storage_path),
      );

      const { data: campaignRowsRaw, error: campaignError } = await ctx.serviceClient
        .from('promotional_campaigns')
        .select('image_path')
        .in('provider_id', providerIds);
      if (campaignError) return jsonError(500, campaignError.message, cors);
      campaignAssetPaths = unique(
        ((campaignRowsRaw ?? []) as CampaignRow[]).map((row) =>
          parsePublicPath(row.image_path, 'campaign-assets')),
      );
    }

    const { data: rpcData, error: rpcError } = await ctx.userClient.rpc('delete_my_account', {
      _reason: reason,
    });
    if (rpcError) return jsonError(500, rpcError.message, cors);

    await removeInChunks(
      (paths) => ctx.serviceClient.storage.from('avatars').remove(paths),
      [`${ctx.userId}/avatar`],
      warnings,
      'avatars',
    );
    await removeInChunks(
      (paths) => ctx.serviceClient.storage.from('place-images').remove(paths),
      placeImagePaths,
      warnings,
      'place-images',
    );
    await removeInChunks(
      (paths) => ctx.serviceClient.storage.from('provider-documents').remove(paths),
      providerDocumentPaths,
      warnings,
      'provider-documents',
    );
    await removeInChunks(
      (paths) => ctx.serviceClient.storage.from('campaign-assets').remove(paths),
      campaignAssetPaths,
      warnings,
      'campaign-assets',
    );

    return jsonOk(
      {
        ...(rpcData && typeof rpcData === 'object' ? rpcData as Record<string, unknown> : {}),
        cleanup: {
          avatars_removed: 1,
          place_images_removed: placeImagePaths.length,
          provider_documents_removed: providerDocumentPaths.length,
          campaign_assets_removed: campaignAssetPaths.length,
          warnings,
        },
      },
      cors,
    );
  } catch (e) {
    if (e instanceof AuthError) return jsonError(e.status, e.message, cors);
    console.error(e);
    return jsonError(500, 'internal error', cors);
  }
});
