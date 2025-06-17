import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static late final SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static bool isAuth() {
    String? token = prefs.getString("token");
    return token != null || (token ?? "").isNotEmpty;
  }

  static String getUserToken() {
    return prefs.getString("token") ?? "";
  }

  static Future<bool> clearUserData() async {
    return prefs.clear();
  }
}
