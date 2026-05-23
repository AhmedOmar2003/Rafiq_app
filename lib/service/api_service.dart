import 'dart:async';

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
          'place_id,place_name,description,price_range,budget,rating,place_address,image_path,activity_name,city_name,created_at',
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
  }

  void _invalidateReviewsCacheForPlace(int placeId) {
    _reviewsCache.remove(placeId);
  }

  Future<Place> addPlace({
    required String placeName,
    required String activityName,
    required String budget,
    String? priceRange,
    required String address,
    required String cityName,
    required String description,
    String? imagePath,
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
        _invalidatePlacesCache();
        return Place.fromJson(Map<String, dynamic>.from(response.first));
      }

      throw Exception('لم يتم إرجاع بيانات المكان بعد الإضافة.');
    } on PostgrestException catch (e) {
      throw Exception('فشل في إضافة المكان: ${e.message}');
    } catch (e) {
      throw Exception('حدث خطأ أثناء إضافة المكان: $e');
    }
  }

  Future<Place> updatePlace({
    required int placeId,
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

      final response = await _client
          .from('places')
          .update(payload)
          .eq('place_id', placeId)
          .select()
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

  Future<void> deletePlace(int placeId) async {
    try {
      await ensureSupabaseInitialized();
      await _client
          .from('places')
          .delete()
          .eq('place_id', placeId)
          .timeout(_networkTimeout);
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
