import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountModeSnapshot {
  const AccountModeSnapshot({
    required this.hasChosenRole,
    required this.isProviderMode,
    required this.hasProviderHistory,
    this.providerId,
  });

  final bool hasChosenRole;
  final bool isProviderMode;
  final bool hasProviderHistory;
  final String? providerId;
}

class PlaceAnalyticsSnapshot {
  const PlaceAnalyticsSnapshot({
    required this.views,
    required this.totalActions,
    required this.favoriteAdds,
    required this.favoriteRemovals,
    required this.mapClicks,
    required this.campaignClicks,
    required this.otherActions,
    required this.trendPoints,
  });

  final int views;
  final int totalActions;
  final int favoriteAdds;
  final int favoriteRemovals;
  final int mapClicks;
  final int campaignClicks;
  final int otherActions;
  final List<int> trendPoints;

  static const empty = PlaceAnalyticsSnapshot(
    views: 0,
    totalActions: 0,
    favoriteAdds: 0,
    favoriteRemovals: 0,
    mapClicks: 0,
    campaignClicks: 0,
    otherActions: 0,
    trendPoints: <int>[],
  );
}

class PromotionCampaignSnapshot {
  const PromotionCampaignSnapshot({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.status,
    required this.placeId,
    required this.imagePath,
    required this.ctaLabel,
    required this.startsAt,
    required this.endsAt,
    required this.impressions,
    required this.clicks,
    required this.rejectionReason,
    required this.createdAt,
    required this.editRequestStatus,
    required this.editRequestNote,
    required this.editRequestResponse,
    required this.editRequestRequestedAt,
    required this.editRequestReviewedAt,
    required this.editAllowed,
  });

  final String id;
  final String title;
  final String? body;
  final String kind;
  final String status;
  final String? placeId;
  final String? imagePath;
  final String? ctaLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int impressions;
  final int clicks;
  final String? rejectionReason;
  final DateTime? createdAt;
  final String editRequestStatus;
  final String? editRequestNote;
  final String? editRequestResponse;
  final DateTime? editRequestRequestedAt;
  final DateTime? editRequestReviewedAt;
  final bool editAllowed;
}

class PlacePromotionBanner {
  const PlacePromotionBanner({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    this.body,
    this.imagePath,
    this.ctaLabel,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final String kind;
  final String status;
  final String? body;
  final String? imagePath;
  final String? ctaLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
}

class ApiService {
  static Future<void>? _supabaseInitFuture;
  static const int _placesPageSize = 80;
  static const int _reviewsPageSize = 50;
  static const Duration _networkTimeout = Duration(seconds: 12);
  static const Duration _placesCacheTtl = Duration(minutes: 3);
  static const Duration _reviewsCacheTtl = Duration(minutes: 2);
  static const int _providerResolveAttempts = 4;
  static const Duration _providerResolveDelay = Duration(milliseconds: 250);
  static const String _authUserIdKey = 'authUserId';
  static const String _userNameKey = 'userName';
  static const String _userEmailKey = 'userEmail';
  static const String _providerIdKey = 'providerId';
  static final Map<String, _TimedCache<List<Place>>> _placesCache = {};
  static final Map<String, Future<List<Place>>> _inFlightPlaces = {};
  static final Map<String, _TimedCache<List<String>>> _galleryCache = {};
  static final Map<int, _TimedCache<List<EvaluationsItemModel>>> _reviewsCache =
      {};
  static final Map<int, Future<List<EvaluationsItemModel>>> _inFlightReviews =
      {};

  static Future<void> ensureSupabaseInitialized() {
    final existingInit = _supabaseInitFuture;
    if (existingInit != null) {
      return existingInit;
    }

    final initFuture = Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    _supabaseInitFuture = initFuture;
    return initFuture;
  }

  SupabaseClient get _client => Supabase.instance.client;

  static String _normalizeFilter(String? input) => (input ?? '').trim();

  static bool _isAnyCity(String city) =>
      city.isEmpty || city == 'أي حتة' || city == 'اي حتة';

  static bool _isUnsetBudget(String budget) =>
      budget.isEmpty || budget == 'لسه محددتش' || budget == 'لسة محددتش';

  static bool _isSurpriseActivity(String activity) => activity == 'فاجئني';

  String _buildPlacesCacheKey({
    required String cityName,
    String? budget,
    String? activity,
  }) {
    final city = _normalizeFilter(cityName);
    final budgetValue = _normalizeFilter(budget);
    final activityValue = _normalizeFilter(activity);
    return '$city|$budgetValue|$activityValue';
  }

  static bool _isFresh<T>(_TimedCache<T>? entry, Duration ttl) {
    if (entry == null) return false;
    return DateTime.now().difference(entry.cachedAt) <= ttl;
  }

  static String _extensionFromPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return 'png';
    if (normalized.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  Future<AccountModeSnapshot?> fetchAccountModeSnapshot() async {
    await ensureSupabaseInitialized();
    final prefs = await SharedPreferences.getInstance();
    await _persistAuthIdentity(prefs);

    final user = _client.auth.currentUser ?? _client.auth.currentSession?.user;
    final userId = user?.id ?? prefs.getString(_authUserIdKey);
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final profile = await _client
        .from('profiles')
        .select('account_mode')
        .eq('id', userId)
        .maybeSingle()
        .timeout(_networkTimeout);
    final provider = await _client
        .from('providers')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle()
        .timeout(_networkTimeout);

    final accountMode = profile?['account_mode']?.toString().trim();
    final providerId = provider?['id']?.toString();
    final snapshot = resolveAccountMode(
      accountMode: accountMode,
      providerId: providerId,
    );

    if (snapshot.hasProviderHistory && snapshot.providerId != null) {
      await prefs.setString(_providerIdKey, snapshot.providerId!);
    }

    return snapshot;
  }

  Future<void> persistAccountMode({
    required bool isProviderMode,
  }) async {
    await ensureSupabaseInitialized();
    final prefs = await SharedPreferences.getInstance();
    await _persistAuthIdentity(prefs);

    final user = _client.auth.currentUser ?? _client.auth.currentSession?.user;
    final userId = user?.id ?? prefs.getString(_authUserIdKey);
    if (userId == null || userId.isEmpty) {
      return;
    }

    await _client
        .from('profiles')
        .update({'account_mode': isProviderMode ? 'provider' : 'user'})
        .eq('id', userId)
        .timeout(_networkTimeout);
  }

  static AccountModeSnapshot resolveAccountMode({
    String? accountMode,
    String? providerId,
  }) {
    final normalizedMode = accountMode?.trim();
    final normalizedProviderId = providerId?.trim();
    final hasProviderHistory = normalizedProviderId != null &&
        normalizedProviderId.isNotEmpty &&
        normalizedProviderId != 'null';

    return switch (normalizedMode) {
      'provider' => AccountModeSnapshot(
          hasChosenRole: true,
          isProviderMode: true,
          hasProviderHistory: hasProviderHistory,
          providerId: hasProviderHistory ? normalizedProviderId : null,
        ),
      'user' => AccountModeSnapshot(
          hasChosenRole: true,
          isProviderMode: false,
          hasProviderHistory: hasProviderHistory,
          providerId: hasProviderHistory ? normalizedProviderId : null,
        ),
      _ when hasProviderHistory => AccountModeSnapshot(
          hasChosenRole: false,
          isProviderMode: false,
          hasProviderHistory: true,
          providerId: normalizedProviderId,
        ),
      _ => const AccountModeSnapshot(
          hasChosenRole: false,
          isProviderMode: false,
          hasProviderHistory: false,
        ),
    };
  }

  /// Returns the provider id for the signed-in user if a providers row already
  /// exists. This never creates one, which makes it safe for regular-user
  /// surfaces like Profile where we only want to *detect* provider history.
  Future<String?> lookupCurrentProviderId() {
    return _resolveCurrentProviderId(createIfMissing: false);
  }

  /// Resolves (and creates if missing) the provider id for the signed-in user.
  ///
  /// Resilience rules:
  ///   1. Auth identity is read from the *Supabase session first*, then prefs
  ///      as a fallback. This avoids the "session expired" failure when prefs
  ///      were partially cleared (e.g. by an aborted logout) but the auth
  ///      cookie is still valid.
  ///   2. If we find no auth.users id at all → returns null. The caller
  ///      should redirect to login (we are genuinely signed out).
  ///   3. If we have an id but no providers row → we create one with a
  ///      sensible default business name. This is what unblocks the "add
  ///      first place" flow right after sign-up.
  Future<String?> ensureCurrentProviderId() {
    return _resolveCurrentProviderId(createIfMissing: true);
  }

  Future<String?> _resolveCurrentProviderId({
    required bool createIfMissing,
  }) async {
    await ensureSupabaseInitialized();
    final prefs = await SharedPreferences.getInstance();

    for (var attempt = 0; attempt < _providerResolveAttempts; attempt++) {
      await _persistAuthIdentity(prefs);

      // Prefer live auth state over stale prefs.
      final sessionUser = _client.auth.currentSession?.user;
      final supabaseUser = _client.auth.currentUser ?? sessionUser;
      final userId = supabaseUser?.id ?? prefs.getString(_authUserIdKey);
      final email = supabaseUser?.email ?? prefs.getString(_userEmailKey) ?? '';
      final metaName = supabaseUser?.userMetadata?['full_name']?.toString() ??
          supabaseUser?.userMetadata?['name']?.toString() ??
          '';
      final name = (prefs.getString(_userNameKey) ?? metaName).trim();

      if (userId == null || userId.isEmpty) {
        if (attempt < _providerResolveAttempts - 1) {
          await Future.delayed(_providerResolveDelay);
          continue;
        }
        return null;
      }

      // No email yet but we have a userId → derive a placeholder so the
      // insert below doesn't violate the NOT NULL constraint on contact_email.
      final safeEmail = email.trim().isEmpty
          ? 'user_$userId@placeholder.local'
          : email.trim();

      try {
        final existing = await _client
            .from('providers')
            .select('id')
            .eq('owner_id', userId)
            .maybeSingle();
        final existingId = existing?['id']?.toString();
        if (existingId != null && existingId.isNotEmpty) {
          await prefs.setString(_providerIdKey, existingId);
          return existingId;
        }

        if (!createIfMissing) {
          return null;
        }

        // RPC path — SECURITY DEFINER, grants the provider role and creates
        // the row atomically. This is what unblocks brand-new signups whose
        // JWT doesn't yet have `is_provider()` true, so a direct INSERT
        // would be rejected by RLS.
        final businessName =
            name.isNotEmpty ? name : safeEmail.split('@').first;
        final rpcResult = await _client.rpc<dynamic>(
          'become_provider',
          params: {
            '_business_name': businessName,
            '_contact_email': safeEmail,
          },
        ).timeout(_networkTimeout);
        final createdId = rpcResult?.toString();
        if (createdId != null && createdId.isNotEmpty && createdId != 'null') {
          await prefs.setString(_providerIdKey, createdId);
          return createdId;
        }
      } catch (_) {
        // Race condition: another request may have created the row meanwhile,
        // or RLS rejected an insert. Re-read before giving up.
        final fallback = await _client
            .from('providers')
            .select('id')
            .eq('owner_id', userId)
            .maybeSingle();
        final fallbackId = fallback?['id']?.toString();
        if (fallbackId != null && fallbackId.isNotEmpty) {
          await prefs.setString(_providerIdKey, fallbackId);
          return fallbackId;
        }

        if (!createIfMissing) {
          return null;
        }

        if (attempt < _providerResolveAttempts - 1) {
          await Future.delayed(_providerResolveDelay);
          continue;
        }
      }
    }
    return null;
  }

  Future<void> _persistAuthIdentity(SharedPreferences prefs) async {
    final user = _client.auth.currentUser ?? _client.auth.currentSession?.user;
    if (user == null) return;

    await prefs.setString(_authUserIdKey, user.id);

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      await prefs.setString(_userEmailKey, email);
    }

    final metaName = user.userMetadata?['full_name']?.toString() ??
        user.userMetadata?['name']?.toString() ??
        '';
    if (metaName.trim().isNotEmpty) {
      await prefs.setString(_userNameKey, metaName.trim());
    }
  }

  Future<List<Place>> fetchPlaces({
    required String cityName,
    String? budget,
    String? activity,
    bool forceRefresh = false,
  }) async {
    try {
      await ensureSupabaseInitialized();
      final cacheKey = _buildPlacesCacheKey(
        cityName: cityName,
        budget: budget,
        activity: activity,
      );

      if (!forceRefresh) {
        final cached = _placesCache[cacheKey];
        if (_isFresh(cached, _placesCacheTtl)) {
          return cached!.value;
        }

        final inFlight = _inFlightPlaces[cacheKey];
        if (inFlight != null) {
          return await inFlight;
        }
      }

      final request = _fetchPlacesFromRemote(
        cityName: cityName,
        budget: budget,
        activity: activity,
      );
      _inFlightPlaces[cacheKey] = request;

      final places = await request;
      _placesCache[cacheKey] = _TimedCache(
        value: places,
        cachedAt: DateTime.now(),
      );
      return places;
    } on PostgrestException catch (e) {
      throw Exception('فشل في تحميل البيانات من Supabase: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء الاتصال بـ Supabase: $e');
    } finally {
      final cacheKey = _buildPlacesCacheKey(
        cityName: cityName,
        budget: budget,
        activity: activity,
      );
      _inFlightPlaces.remove(cacheKey);
    }
  }

  Future<List<Place>> _fetchPlacesFromRemote({
    required String cityName,
    String? budget,
    String? activity,
  }) async {
    final normalizedCity = _normalizeFilter(cityName);
    final normalizedBudget = _normalizeFilter(budget);
    final normalizedActivity = _normalizeFilter(activity);
    final isAnyCity = _isAnyCity(normalizedCity);
    final isUnsetBudget = _isUnsetBudget(normalizedBudget);
    final isSurpriseActivity = _isSurpriseActivity(normalizedActivity);

    final response = await _client.rpc<List<dynamic>>(
      'browse_ranked_places',
      params: {
        '_city_name': isAnyCity ? null : normalizedCity,
        '_budget': isUnsetBudget ? null : normalizedBudget,
        '_activity_name': normalizedActivity.isEmpty || isSurpriseActivity
            ? null
            : normalizedActivity,
        '_limit': _placesPageSize,
      },
    ).timeout(_networkTimeout);
    return response
        .map((row) => Place.fromJson(Map<String, dynamic>.from(row)))
        .where((place) => place.status == 'approved')
        .toList();
  }

  void _invalidatePlacesCache() {
    _placesCache.clear();
    _galleryCache.clear();
  }

  void _invalidateReviewsCacheForPlace(int placeId) {
    _reviewsCache.remove(placeId);
  }

  Future<Place> addPlace({
    required String providerId,
    required String placeName,
    required String activityName,
    required String budget,
    String? priceRange,
    required String address,
    required String cityName,
    required String description,
    String? imagePath,
    List<File> galleryImages = const [],
  }) async {
    try {
      await ensureSupabaseInitialized();
      final payload = <String, dynamic>{
        'provider_id': providerId,
        'place_name': placeName.trim(),
        'activity_name': activityName.trim(),
        'budget': budget.trim(),
        'price_range': (priceRange?.trim().isNotEmpty == true
            ? priceRange!.trim()
            : budget.trim()),
        'place_address': address.trim(),
        'city_name': cityName.trim(),
        'description': description.trim(),
        'rating': 0,
        'image_path':
            imagePath != null && imagePath.isNotEmpty ? imagePath : null,
      };

      final response = await _client
          .from('places')
          .insert(payload)
          .select()
          .timeout(_networkTimeout);
      if (response.isNotEmpty) {
        final createdPlace =
            Place.fromJson(Map<String, dynamic>.from(response.first));
        if (galleryImages.isNotEmpty && createdPlace.placeUuid != null) {
          final coverPublicUrl = await _savePlaceGalleryImages(
            providerId: providerId,
            placeUuid: createdPlace.placeUuid!,
            galleryImages: galleryImages,
            placeName: placeName,
          );
          if (coverPublicUrl != null) {
            await _client.from('places').update({
              'image_path': coverPublicUrl,
            }).eq('id', createdPlace.placeUuid!);
          }
        }
        _invalidatePlacesCache();
        return createdPlace;
      }

      throw Exception('لم يتم إرجاع بيانات المكان بعد الإضافة.');
    } on PostgrestException catch (e) {
      throw Exception('فشل في إضافة المكان: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء إضافة المكان: $e');
    }
  }

  Future<List<Place>> fetchProviderPlaces({
    required String providerId,
    bool forceRefresh = false,
  }) async {
    await ensureSupabaseInitialized();
    final cacheKey = 'provider::$providerId';

    if (!forceRefresh) {
      final cached = _placesCache[cacheKey];
      if (_isFresh(cached, _placesCacheTtl)) {
        return cached!.value;
      }

      final inFlight = _inFlightPlaces[cacheKey];
      if (inFlight != null) {
        return await inFlight;
      }
    }

    final request = _fetchProviderPlacesFromRemote(providerId: providerId);
    _inFlightPlaces[cacheKey] = request;
    try {
      final places = await request;
      _placesCache[cacheKey] = _TimedCache(
        value: places,
        cachedAt: DateTime.now(),
      );
      return places;
    } finally {
      _inFlightPlaces.remove(cacheKey);
    }
  }

  Future<List<Place>> _fetchProviderPlacesFromRemote({
    required String providerId,
  }) async {
    final rows = await _client
        .from('places')
        .select(
          'id,place_id,provider_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at,status,rejection_reason,edit_allowed,edit_request_status,edit_request_note,edit_request_response,edit_request_requested_at,edit_request_reviewed_at,edit_submitted_at',
        )
        .eq('provider_id', providerId)
        .order('created_at', ascending: false)
        .limit(_placesPageSize)
        .timeout(_networkTimeout);

    return rows
        .map((row) => Place.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<String>> fetchPlaceGalleryImages({
    required String placeUuid,
    bool forceRefresh = false,
  }) async {
    await ensureSupabaseInitialized();
    final cacheKey = 'gallery::$placeUuid';

    if (!forceRefresh) {
      final cached = _galleryCache[cacheKey];
      if (_isFresh(cached, _placesCacheTtl)) {
        return cached!.value;
      }
    }

    final rows = await _client
        .from('place_images')
        .select('storage_path,is_cover,sort_order,created_at')
        .eq('place_id', placeUuid)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true)
        .timeout(_networkTimeout);

    final urls = (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .map((row) {
          final storagePath = row['storage_path']?.toString() ?? '';
          if (storagePath.isEmpty) return null;
          return _client.storage.from('place-images').getPublicUrl(storagePath);
        })
        .whereType<String>()
        .toList(growable: false);

    _galleryCache[cacheKey] = _TimedCache(
      value: urls,
      cachedAt: DateTime.now(),
    );
    return urls;
  }

  Future<PlaceAnalyticsSnapshot> fetchPlaceAnalytics({
    required String providerId,
    String? placeId,
    int days = 30,
  }) async {
    await ensureSupabaseInitialized();
    final rows = await _client.rpc<List<dynamic>>(
      'provider_place_analytics_live',
      params: {
        '_place_id': placeId,
        '_days': days,
      },
    ).timeout(_networkTimeout);
    final campaignClicksRaw = await _client.rpc<dynamic>(
      'provider_campaign_clicks_live',
      params: {
        '_place_id': placeId,
        '_days': days,
      },
    ).timeout(_networkTimeout);
    final campaignClicks = (campaignClicksRaw as num?)?.toInt() ??
        int.tryParse(campaignClicksRaw?.toString() ?? '') ??
        0;
    if (rows.isEmpty) {
      return PlaceAnalyticsSnapshot(
        views: 0,
        totalActions: campaignClicks,
        favoriteAdds: 0,
        favoriteRemovals: 0,
        mapClicks: 0,
        campaignClicks: campaignClicks,
        otherActions: 0,
        trendPoints: const <int>[],
      );
    }

    var views = 0;
    var favoriteAdds = 0;
    var favoriteRemovals = 0;
    var mapClicks = 0;
    var otherActions = 0;
    final trendByDay = <String, int>{};

    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow);
      final kind = row['kind']?.toString() ?? '';
      final count = (row['event_count'] as num?)?.toInt() ?? 0;
      final uniqueSessions = (row['unique_sessions'] as num?)?.toInt() ?? 0;
      final dayKey = row['day']?.toString() ?? '';

      switch (kind) {
        case 'place_open':
          views += uniqueSessions > 0 ? uniqueSessions : count;
          trendByDay[dayKey] = (trendByDay[dayKey] ?? 0) +
              (uniqueSessions > 0 ? uniqueSessions : count);
          break;
        case 'place_favorite':
          favoriteAdds += count;
          break;
        case 'place_unfavorite':
          favoriteRemovals += count;
          break;
        case 'place_map_open':
          mapClicks += count;
          break;
        case 'place_share':
        case 'place_phone_call':
        case 'place_website_click':
        case 'place_review_submit':
        case 'recommendation_click':
          otherActions += count;
          break;
      }
    }

    final safeDays = days < 1 ? 1 : days;
    final trendPoints = List<int>.generate(safeDays, (index) {
      final day = DateTime.now().subtract(Duration(days: safeDays - 1 - index));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return trendByDay[key] ?? 0;
    });

    return PlaceAnalyticsSnapshot(
      views: views,
      totalActions: favoriteAdds +
          favoriteRemovals +
          mapClicks +
          campaignClicks +
          otherActions,
      favoriteAdds: favoriteAdds,
      favoriteRemovals: favoriteRemovals,
      mapClicks: mapClicks,
      campaignClicks: campaignClicks,
      otherActions: otherActions,
      trendPoints: trendPoints,
    );
  }

  Future<List<Place>> fetchFavoritePlaces({bool forceRefresh = false}) async {
    await ensureSupabaseInitialized();
    final userId =
        _client.auth.currentUser?.id ?? _client.auth.currentSession?.user.id;
    if (userId == null || userId.isEmpty) {
      return const <Place>[];
    }

    final favoriteRows = await _client
        .from('favorites')
        .select('place_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);

    final orderedIds = favoriteRows
        .map((row) => row['place_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (orderedIds.isEmpty) return const <Place>[];

    final placeRows = await _client
        .from('places')
        .select(
          'id,provider_id,place_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at,status,deleted_at',
        )
        .inFilter('id', orderedIds)
        .eq('status', 'approved')
        .isFilter('deleted_at', null)
        .timeout(_networkTimeout);

    final byId = <String, Place>{};
    for (final row in placeRows) {
      final place = Place.fromJson(Map<String, dynamic>.from(row));
      final id = place.placeUuid;
      if (id != null && id.isNotEmpty && place.status == 'approved') {
        byId[id] = place;
      }
    }

    final orderedPlaces = <Place>[];
    for (final id in orderedIds) {
      final place = byId[id];
      if (place != null) orderedPlaces.add(place);
    }
    return orderedPlaces;
  }

  Future<List<PromotionCampaignSnapshot>> fetchPromotionCampaigns({
    required String providerId,
    String? placeId,
  }) async {
    await ensureSupabaseInitialized();
    var query = _client
        .from('promotional_campaigns')
        .select(
          'id,title,body,kind,status,place_id,image_path,cta_label,starts_at,ends_at,impressions,clicks,rejection_reason,created_at,edit_request_status,edit_request_note,edit_request_response,edit_request_requested_at,edit_request_reviewed_at,edit_allowed',
        )
        .eq('provider_id', providerId);

    if (placeId != null && placeId.isNotEmpty) {
      query = query.eq('place_id', placeId);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);
    return rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      return PromotionCampaignSnapshot(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? 'حملة بدون عنوان',
        body: row['body']?.toString(),
        kind: row['kind']?.toString() ?? 'featured',
        status: row['status']?.toString() ?? 'draft',
        placeId: row['place_id']?.toString(),
        imagePath: row['image_path']?.toString(),
        ctaLabel: row['cta_label']?.toString(),
        startsAt: DateTime.tryParse(row['starts_at']?.toString() ?? ''),
        endsAt: DateTime.tryParse(row['ends_at']?.toString() ?? ''),
        impressions: (row['impressions'] as num?)?.toInt() ?? 0,
        clicks: (row['clicks'] as num?)?.toInt() ?? 0,
        rejectionReason: row['rejection_reason']?.toString(),
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        editRequestStatus: row['edit_request_status']?.toString() ?? 'none',
        editRequestNote: row['edit_request_note']?.toString(),
        editRequestResponse: row['edit_request_response']?.toString(),
        editRequestRequestedAt: DateTime.tryParse(
          row['edit_request_requested_at']?.toString() ?? '',
        ),
        editRequestReviewedAt: DateTime.tryParse(
          row['edit_request_reviewed_at']?.toString() ?? '',
        ),
        editAllowed: row['edit_allowed'] as bool? ?? false,
      );
    }).toList(growable: false);
  }

  Future<List<PlacePromotionBanner>> fetchActivePlacePromotions({
    required String placeId,
  }) async {
    await ensureSupabaseInitialized();
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('promotional_campaigns')
        .select(
          'id,title,body,kind,status,image_path,cta_label,starts_at,ends_at',
        )
        .eq('place_id', placeId)
        .eq('status', 'active')
        .lte('starts_at', now)
        .gte('ends_at', now)
        .order('created_at', ascending: false)
        .timeout(_networkTimeout);

    return rows.map((rawRow) {
      final row = Map<String, dynamic>.from(rawRow);
      return PlacePromotionBanner(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? 'عرض خاص',
        body: row['body']?.toString(),
        kind: row['kind']?.toString() ?? 'discount',
        status: row['status']?.toString() ?? 'active',
        imagePath: row['image_path']?.toString(),
        ctaLabel: row['cta_label']?.toString(),
        startsAt: DateTime.tryParse(row['starts_at']?.toString() ?? ''),
        endsAt: DateTime.tryParse(row['ends_at']?.toString() ?? ''),
      );
    }).toList(growable: false);
  }

  Future<bool> isPlaceFavorited(String placeId) async {
    await ensureSupabaseInitialized();
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return false;

    final row = await _client
        .from('favorites')
        .select('place_id')
        .eq('user_id', userId)
        .eq('place_id', placeId)
        .maybeSingle()
        .timeout(_networkTimeout);
    return row != null;
  }

  Future<bool> setPlaceFavorite({
    required String placeId,
    required bool shouldFavorite,
  }) async {
    await ensureSupabaseInitialized();
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('يجب تسجيل الدخول أولاً.');
    }

    if (shouldFavorite) {
      await _client.from('favorites').upsert({
        'user_id': userId,
        'place_id': placeId,
      }).timeout(_networkTimeout);
      return true;
    }

    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('place_id', placeId)
        .timeout(_networkTimeout);
    return false;
  }

  Future<void> createPromotionCampaign({
    required String placeId,
    required String kind,
    required String title,
    String? body,
    String? imagePath,
    String? ctaLabel,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await ensureSupabaseInitialized();
    await _client.rpc<dynamic>(
      'create_provider_campaign',
      params: {
        '_place_id': placeId,
        '_kind': kind,
        '_title': title.trim(),
        '_body': body?.trim().isNotEmpty == true ? body!.trim() : null,
        '_image_path':
            imagePath?.trim().isNotEmpty == true ? imagePath!.trim() : null,
        '_cta_label':
            ctaLabel?.trim().isNotEmpty == true ? ctaLabel!.trim() : null,
        '_starts_at': startsAt.toUtc().toIso8601String(),
        '_ends_at': endsAt.toUtc().toIso8601String(),
      },
    ).timeout(_networkTimeout);
  }

  Future<void> requestPromotionCampaignEdit({
    required String campaignId,
    String? note,
  }) async {
    await ensureSupabaseInitialized();
    await _client.rpc<dynamic>(
      'request_campaign_edit',
      params: {
        '_campaign_id': campaignId,
        '_note': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
    ).timeout(_networkTimeout);
  }

  Future<void> updatePromotionCampaign({
    required String campaignId,
    required String placeId,
    required String kind,
    required String title,
    String? body,
    String? imagePath,
    String? ctaLabel,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await ensureSupabaseInitialized();
    await _client.rpc<dynamic>(
      'update_provider_campaign',
      params: {
        '_campaign_id': campaignId,
        '_place_id': placeId,
        '_kind': kind,
        '_title': title.trim(),
        '_body': body?.trim().isNotEmpty == true ? body!.trim() : null,
        '_image_path':
            imagePath?.trim().isNotEmpty == true ? imagePath!.trim() : null,
        '_cta_label':
            ctaLabel?.trim().isNotEmpty == true ? ctaLabel!.trim() : null,
        '_starts_at': startsAt.toUtc().toIso8601String(),
        '_ends_at': endsAt.toUtc().toIso8601String(),
      },
    ).timeout(_networkTimeout);
  }

  Future<void> recordCampaignMetric({
    required String campaignId,
    required String metric,
    String? sessionId,
  }) async {
    await ensureSupabaseInitialized();
    await _client.rpc<dynamic>(
      'record_campaign_metric',
      params: {
        '_campaign_id': campaignId,
        '_metric': metric,
        // Pass the app session_id so the server can deduplicate impressions
        // and clicks within the rate-limit window. Falls back to null if the
        // caller did not supply one (older call sites).
        '_session_id': sessionId,
      },
    ).timeout(_networkTimeout);
  }

  Future<String> uploadCampaignImage({
    required String providerId,
    required String placeId,
    required File file,
  }) async {
    await ensureSupabaseInitialized();
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('ملف الصورة فاضي، اختَر صورة تانية.');
    }

    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}.${_extensionFromPath(file.path)}';
    final storagePath = '$providerId/$placeId/$fileName';
    await _client.storage.from('campaign-assets').uploadBinary(
          storagePath,
          bytes,
        );
    return _client.storage.from('campaign-assets').getPublicUrl(storagePath);
  }

  Future<String?> _savePlaceGalleryImages({
    required String providerId,
    required String placeUuid,
    required List<File> galleryImages,
    required String placeName,
  }) async {
    if (galleryImages.isEmpty) return null;

    await _client
        .from('place_images')
        .update({'is_cover': false}).eq('place_id', placeUuid);

    String? coverPublicUrl;
    for (var i = 0; i < galleryImages.length; i++) {
      final file = galleryImages[i];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;

      final uniqueSuffix = DateTime.now().microsecondsSinceEpoch;
      final storagePath =
          '$providerId/$placeUuid/$uniqueSuffix-$i.${_extensionFromPath(file.path)}';
      await _client.storage.from('place-images').uploadBinary(
            storagePath,
            bytes,
          );
      final publicUrl =
          _client.storage.from('place-images').getPublicUrl(storagePath);
      coverPublicUrl ??= publicUrl;
      await _client.from('place_images').insert({
        'place_id': placeUuid,
        'storage_path': storagePath,
        'is_cover': i == 0,
        'alt_text': placeName.trim().isNotEmpty ? placeName.trim() : null,
        'sort_order': i,
      });
    }
    return coverPublicUrl;
  }

  Future<Place> updatePlace({
    required String? placeUuid,
    int? legacyPlaceId,
    String? providerId,
    required String placeName,
    required String activityName,
    required String budget,
    String? priceRange,
    required String address,
    required String cityName,
    required String description,
    String? imagePath,
    double? rating,
    List<File> galleryImages = const <File>[],

    /// Kept for source compatibility. The database now derives the correct
    /// moderation transition from the current place state and approved edit
    /// request, so clients cannot keep an edited approved place live.
    bool resubmitForReview = false,
  }) async {
    try {
      await ensureSupabaseInitialized();
      var resolvedId = placeUuid;
      if ((resolvedId == null || resolvedId.isEmpty) && legacyPlaceId != null) {
        final row = await _client
            .from('places')
            .select('id')
            .eq('place_id', legacyPlaceId)
            .single()
            .timeout(_networkTimeout);
        resolvedId = row['id']?.toString();
      }
      if (resolvedId == null || resolvedId.isEmpty) {
        throw Exception('تعذر تحديد المكان المطلوب تعديله.');
      }

      String? uploadedCover;
      if (galleryImages.isNotEmpty &&
          providerId != null &&
          providerId.isNotEmpty) {
        uploadedCover = await _savePlaceGalleryImages(
          providerId: providerId,
          placeUuid: resolvedId,
          galleryImages: galleryImages,
          placeName: placeName,
        );
      }

      await _client.rpc<dynamic>(
        'update_provider_place',
        params: {
          '_place_id': resolvedId,
          '_place_name': placeName.trim(),
          '_activity_name': activityName.trim(),
          '_budget': budget.trim(),
          '_price_range': priceRange?.trim().isNotEmpty == true
              ? priceRange!.trim()
              : budget.trim(),
          '_address': address.trim(),
          '_city_name': cityName.trim(),
          '_description': description.trim(),
          '_image_path': uploadedCover ??
              (imagePath?.startsWith('http') == true ? imagePath : null),
          '_rating': rating,
        },
      ).timeout(_networkTimeout);

      final response = await _client
          .from('places')
          .select(
            'id,place_id,provider_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at,status,rejection_reason,edit_allowed,edit_request_status,edit_request_note,edit_request_response,edit_request_requested_at,edit_request_reviewed_at,edit_submitted_at',
          )
          .eq('id', resolvedId)
          .single()
          .timeout(_networkTimeout);

      _invalidatePlacesCache();
      return Place.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw Exception('فشل في تحديث المكان: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء تحديث المكان: $e');
    }
  }

  Future<void> requestPlaceEdit({
    required String placeUuid,
    String? note,
  }) async {
    await ensureSupabaseInitialized();
    await _client.rpc<dynamic>(
      'request_place_edit',
      params: {
        '_place_id': placeUuid,
        '_note': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
    ).timeout(_networkTimeout);
    _invalidatePlacesCache();
  }

  Future<void> deletePlace(int placeId) async {
    await deletePlaceByIdentifier(legacyPlaceId: placeId);
  }

  Future<void> deletePlaceByIdentifier({
    String? placeUuid,
    int? legacyPlaceId,
  }) async {
    try {
      await ensureSupabaseInitialized();
      var query = _client.from('places').delete();
      if (placeUuid != null && placeUuid.isNotEmpty) {
        query = query.eq('id', placeUuid);
      } else if (legacyPlaceId != null) {
        query = query.eq('place_id', legacyPlaceId);
      }
      await query.timeout(_networkTimeout);
      _invalidatePlacesCache();
    } on PostgrestException catch (e) {
      throw Exception('فشل في حذف المكان: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء حذف المكان: $e');
    }
  }

  Future<List<EvaluationsItemModel>> fetchReviews({
    required int placeId,
    bool forceRefresh = false,
  }) async {
    try {
      await ensureSupabaseInitialized();
      if (!forceRefresh) {
        final cached = _reviewsCache[placeId];
        if (_isFresh(cached, _reviewsCacheTtl)) {
          return cached!.value;
        }

        final inFlight = _inFlightReviews[placeId];
        if (inFlight != null) {
          return await inFlight;
        }
      }

      final request = _fetchReviewsFromRemote(placeId: placeId);
      _inFlightReviews[placeId] = request;
      final reviews = await request;
      _reviewsCache[placeId] = _TimedCache(
        value: reviews,
        cachedAt: DateTime.now(),
      );
      return reviews;
    } on PostgrestException catch (e) {
      throw Exception('فشل في تحميل التقييمات: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء الاتصال بـ Supabase: $e');
    } finally {
      _inFlightReviews.remove(placeId);
    }
  }

  Future<List<EvaluationsItemModel>> _fetchReviewsFromRemote({
    required int placeId,
  }) async {
    final response = await _client
        .from('reviews')
        .select(
          'review_id,place_id,user_id,name,review_text,rating,image,created_at',
        )
        .eq('place_id', placeId)
        .order('created_at', ascending: false)
        .limit(_reviewsPageSize)
        .timeout(_networkTimeout);

    return response
        .map((row) =>
            EvaluationsItemModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<EvaluationsItemModel?> fetchLastReview({required int placeId}) async {
    try {
      await ensureSupabaseInitialized();
      final response = await _client
          .from('reviews')
          .select(
            'review_id,place_id,user_id,name,review_text,rating,image,created_at',
          )
          .eq('place_id', placeId)
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(_networkTimeout);

      if (response.isEmpty) {
        return null;
      }

      return EvaluationsItemModel.fromJson(
        Map<String, dynamic>.from(response.first),
      );
    } on PostgrestException catch (e) {
      throw Exception('فشل في تحميل التقييمات: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء الاتصال بـ Supabase: $e');
    }
  }

  Future<EvaluationsItemModel> submitReview({
    required int placeId,
    required String userId,
    required String name,
    required String reviewText,
    required String image,
    int rating = 5,
  }) async {
    try {
      await ensureSupabaseInitialized();
      final response = await _client
          .from('reviews')
          .insert({
            'place_id': placeId,
            'user_id': userId,
            'name': name.trim(),
            'review_text': reviewText.trim(),
            'rating': rating,
            'image': image.trim(),
          })
          .select()
          .single()
          .timeout(_networkTimeout);

      final inserted = EvaluationsItemModel.fromJson(
        Map<String, dynamic>.from(response),
      );
      final cached = _reviewsCache[placeId];
      if (cached != null) {
        _reviewsCache[placeId] = _TimedCache(
          value: [inserted, ...cached.value],
          cachedAt: DateTime.now(),
        );
      } else {
        _invalidateReviewsCacheForPlace(placeId);
      }

      return inserted;
    } on PostgrestException catch (e) {
      throw Exception('فشل في حفظ التقييم: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء حفظ التقييم: $e');
    }
  }

  Future<void> deleteReview(int reviewId) async {
    try {
      await ensureSupabaseInitialized();
      final deletedRows = await _client
          .from('reviews')
          .delete()
          .eq('review_id', reviewId)
          .select('place_id')
          .timeout(_networkTimeout);

      if (deletedRows.isNotEmpty) {
        final rawPlaceId = deletedRows.first['place_id'];
        final placeId =
            rawPlaceId is int ? rawPlaceId : int.tryParse('$rawPlaceId');
        if (placeId != null) {
          _invalidateReviewsCacheForPlace(placeId);
        }
      } else {
        _reviewsCache.clear();
      }
    } on PostgrestException catch (e) {
      throw Exception('فشل في حذف التقييم: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء حذف التقييم: $e');
    }
  }
}

class _TimedCache<T> {
  final T value;
  final DateTime cachedAt;

  const _TimedCache({
    required this.value,
    required this.cachedAt,
  });
}
