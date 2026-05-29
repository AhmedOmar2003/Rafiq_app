import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static Future<void>? _supabaseInitFuture;
  static const int _placesPageSize = 80;
  static const int _reviewsPageSize = 50;
  static const Duration _networkTimeout = Duration(seconds: 12);
  static const Duration _placesCacheTtl = Duration(minutes: 3);
  static const Duration _reviewsCacheTtl = Duration(minutes: 2);
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
  Future<String?> ensureCurrentProviderId() async {
    await ensureSupabaseInitialized();
    final prefs = await SharedPreferences.getInstance();

    // Prefer live auth state over stale prefs.
    final sessionUser = _client.auth.currentSession?.user;
    final supabaseUser = _client.auth.currentUser ?? sessionUser;
    final userId = supabaseUser?.id ?? prefs.getString('authUserId');
    final email = supabaseUser?.email ?? prefs.getString('userEmail') ?? '';
    final metaName = supabaseUser?.userMetadata?['full_name']?.toString() ??
        supabaseUser?.userMetadata?['name']?.toString() ??
        '';
    final name = (prefs.getString('userName') ?? metaName).trim();

    if (userId == null || userId.isEmpty) return null;
    // No email yet but we have a userId → derive a placeholder so the
    // insert below doesn't violate the NOT NULL constraint on contact_email.
    final safeEmail =
        email.trim().isEmpty ? 'user_$userId@placeholder.local' : email.trim();

    try {
      final existing = await _client
          .from('providers')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();
      final existingId = existing?['id']?.toString();
      if (existingId != null && existingId.isNotEmpty) {
        await prefs.setString('providerId', existingId);
        return existingId;
      }

      final businessName = name.isNotEmpty ? name : safeEmail.split('@').first;
      final created = await _client
          .from('providers')
          .insert({
            'owner_id': userId,
            'business_name': businessName,
            'contact_email': safeEmail,
            'status': 'pending',
          })
          .select('id')
          .single()
          .timeout(_networkTimeout);
      final createdId = created['id']?.toString();
      if (createdId != null && createdId.isNotEmpty) {
        await prefs.setString('providerId', createdId);
      }
      return createdId;
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
        await prefs.setString('providerId', fallbackId);
      }
      return fallbackId;
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

    var query = _client.from('places').select(
          'id,provider_id,place_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at',
        );
    if (!isAnyCity) {
      query = query.eq('city_name', normalizedCity);
    }

    if (!isUnsetBudget) {
      query = query.eq('budget', normalizedBudget);
    }

    if (normalizedActivity.isNotEmpty && !isSurpriseActivity) {
      query = query.eq('activity_name', normalizedActivity);
    }

    final response = await (isSurpriseActivity
            ? query
                .order('rating', ascending: false)
                .order('created_at', ascending: false)
                .limit(_placesPageSize)
            : query.order('place_id', ascending: false).limit(_placesPageSize))
        .timeout(_networkTimeout);
    return response
        .map((row) => Place.fromJson(Map<String, dynamic>.from(row)))
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
          'id,place_id,provider_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at',
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

  Future<String?> _savePlaceGalleryImages({
    required String providerId,
    required String placeUuid,
    required List<File> galleryImages,
    required String placeName,
  }) async {
    if (galleryImages.isEmpty) return null;

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
    required String placeName,
    required String activityName,
    required String budget,
    String? priceRange,
    required String address,
    required String cityName,
    required String description,
    String? imagePath,
    double? rating,
  }) async {
    try {
      await ensureSupabaseInitialized();
      final payload = <String, dynamic>{
        'place_name': placeName.trim(),
        'activity_name': activityName.trim(),
        'budget': budget.trim(),
        'price_range': (priceRange?.trim().isNotEmpty == true
            ? priceRange!.trim()
            : budget.trim()),
        'place_address': address.trim(),
        'city_name': cityName.trim(),
        'description': description.trim(),
        if (rating != null) 'rating': rating,
        'image_path':
            imagePath != null && imagePath.isNotEmpty ? imagePath : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      var query = _client.from('places').update(payload);
      if (placeUuid != null && placeUuid.isNotEmpty) {
        query = query.eq('id', placeUuid);
      } else if (legacyPlaceId != null) {
        query = query.eq('place_id', legacyPlaceId);
      }

      final response = await query.select().single().timeout(_networkTimeout);

      _invalidatePlacesCache();
      return Place.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw Exception('فشل في تحديث المكان: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء تحديث المكان: $e');
    }
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
