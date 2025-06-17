import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/Api_model/api_model.dart';

class ApiService {
  // رابط الـ API الأساسي
  final String apiUrl = 'http://${GlopalVariable.ipConfig}/Api/api.php';

  /// **جلب الأماكن من الخادم عبر الـ API**
  /// [cityName] هو اسم المدينة المطلوب
  /// [budget] هي الميزانية المدخلة
  /// [activity] هو النشاط المطلوب
  Future<List<Place>> fetchPlaces({
    required String cityName,
    String? budget,
    String? activity,
  }) async {
    try {
      // إعداد القيم الافتراضية عند الحاجة
      final String validBudget =
          budget?.isNotEmpty == true ? budget! : 'غير محدد';
      final String validActivity = activity?.isNotEmpty == true
          ? activity!
          : ''; // يمكن تركه فارغ إذا لم يكن هناك نشاط معين

      // بناء رابط الطلب
      final Uri requestUri = Uri.parse(
        '$apiUrl?cityName=$cityName&budget=$validBudget&activityName=$validActivity',
      );

      print("رابط الـ API: $requestUri");

      // إرسال الطلب إلى الخادم
      final response = await http.get(requestUri);

      // التحقق من حالة الرد
      if (response.statusCode == 200) {
        // فك تشفير الاستجابة إلى خريطة JSON
        final decodedResponse = json.decode(response.body);

        // التحقق من أن الرد يحتوي على المفتاح "places"
        if (decodedResponse is Map<String, dynamic> &&
            decodedResponse.containsKey("places")) {
          final List<dynamic> placesJson = decodedResponse["places"];

          // التحقق من أن الأماكن ليست فارغة وأن التنسيق صحيح
          if (placesJson.isNotEmpty && placesJson[0] is Map<String, dynamic>) {
            return placesJson.map((place) => Place.fromJson(place)).toList();
          } else {
            throw Exception('لا توجد أماكن تناسب اختياراتك.');
          }
        } else {
          throw Exception('لم يتم العثور على المفتاح "places" في الاستجابة.');
        }
      } else {
        throw Exception('فشل في تحميل البيانات: ${response.statusCode}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
      throw Exception('حدث خطأ أثناء الاتصال بالخادم: $e');
    }
  }
}
