import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/Api_model/api_model.dart';
import 'package:rafiq_app/core/logic/cache_helper.dart';

class ApiService {
  // رابط الـ API الأساسي
  final String apiUrl = 'http://${GlopalVariable.ipConfig}/Api/api.php';
  final http.Client _client = http.Client();
  static const int maxRetries = 3;
  static const Duration timeoutDuration = Duration(seconds: 10);
  static const Duration cacheValidityDuration = Duration(hours: 1);

  /// **جلب الأماكن من الخادم عبر الـ API**
  /// [cityName] هو اسم المدينة المطلوب
  /// [budget] هي الميزانية المدخلة
  /// [activity] هو النشاط المطلوب
  Future<List<Place>> fetchPlaces({
    required String cityName,
    String? budget,
    String? activity,
  }) async {
    final String validBudget = budget?.isNotEmpty == true ? budget! : 'غير محدد';
    final String validActivity = activity?.isNotEmpty == true ? activity! : '';
    
    // Create cache key
    final String cacheKey = 'places_${cityName}_${validBudget}_$validActivity';
    
    // Try to get data from cache first
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final Uri requestUri = Uri.parse(
          '$apiUrl?cityName=$cityName&budget=$validBudget&activityName=$validActivity',
        );

        final response = await _client
            .get(requestUri)
            .timeout(timeoutDuration)
            .catchError((error) {
          throw _handleError(error);
        });

        if (response.statusCode == 200) {
          final decodedResponse = json.decode(response.body);

          if (decodedResponse is Map<String, dynamic> &&
              decodedResponse.containsKey("places")) {
            final List<dynamic> placesJson = decodedResponse["places"];

            if (placesJson.isNotEmpty && placesJson[0] is Map<String, dynamic>) {
              final places = placesJson.map((place) => Place.fromJson(place)).toList();
              
              // Cache the successful response
              await _cacheResponse(cacheKey, places);
              
              return places;
            } else {
              throw const ApiException('لا توجد أماكن تناسب اختياراتك.');
            }
          } else {
            throw const ApiException('لم يتم العثور على المفتاح "places" في الاستجابة.');
          }
        } else if (response.statusCode >= 500) {
          // Retry on server errors
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        } else {
          throw ApiException('فشل في تحميل البيانات: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        if (retryCount == maxRetries - 1) {
          throw ApiException('خطأ في الاتصال بالإنترنت: ${e.message}');
        }
        retryCount++;
        await Future.delayed(Duration(seconds: retryCount * 2));
      } on TimeoutException catch (_) {
        if (retryCount == maxRetries - 1) {
          throw const ApiException('انتهت مهلة الاتصال بالخادم');
        }
        retryCount++;
        await Future.delayed(Duration(seconds: retryCount * 2));
      } catch (e) {
        throw _handleError(e);
      }
    }
    
    throw const ApiException('فشلت جميع محاولات الاتصال بالخادم');
  }

  Exception _handleError(dynamic error) {
    if (error is SocketException) {
      return ApiException('خطأ في الاتصال بالإنترنت: ${error.message}');
    } else if (error is TimeoutException) {
      return const ApiException('انتهت مهلة الاتصال بالخادم');
    } else if (error is ApiException) {
      return error;
    }
    return ApiException('حدث خطأ غير متوقع: $error');
  }

  Future<List<Place>?> _getFromCache(String key) async {
    final cachedData = await CacheHelper.getData(key: key);
    if (cachedData != null) {
      final cacheTime = await CacheHelper.getData(key: '${key}_time');
      if (cacheTime != null) {
        final cacheDateTime = DateTime.parse(cacheTime);
        if (DateTime.now().difference(cacheDateTime) < cacheValidityDuration) {
          try {
            return (json.decode(cachedData) as List)
                .map((item) => Place.fromJson(item))
                .toList();
          } catch (_) {
            await CacheHelper.removeData(key: key);
            await CacheHelper.removeData(key: '${key}_time');
          }
        }
      }
    }
    return null;
  }

  Future<void> _cacheResponse(String key, List<Place> places) async {
    final jsonData = places.map((place) => place.toJson()).toList();
    await CacheHelper.saveData(key: key, value: json.encode(jsonData));
    await CacheHelper.saveData(
        key: '${key}_time', value: DateTime.now().toIso8601String());
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  
  @override
  String toString() => message;
}
