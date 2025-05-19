import 'package:shared_preferences/shared_preferences.dart';

/// A helper class that manages local storage operations using SharedPreferences.
/// This class provides methods for handling onboarding state and authentication status.
class CacheHelper {
  /// Key for storing onboarding seen status
  static const String _onBoardingKey = 'isOnBoardingSeen';

  /// Key for storing authentication status
  static const String _authKey = 'isAuthenticated';

  /// Stores the onboarding seen status in SharedPreferences
  ///
  /// [isSeen] - Boolean value indicating whether onboarding has been seen
  ///
  /// Throws [Exception] if storage operation fails
  static Future<void> setOnBoardingSeen(bool isSeen) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onBoardingKey, isSeen);
    } catch (e) {
      throw Exception('Failed to set onboarding status: $e');
    }
  }

  /// Retrieves the onboarding seen status from SharedPreferences
  ///
  /// Returns [bool] - true if onboarding has been seen, false otherwise
  ///
  /// Throws [Exception] if retrieval operation fails
  static Future<bool> getOnBoardingSeen() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onBoardingKey) ?? false;
    } catch (e) {
      throw Exception('Failed to get onboarding status: $e');
    }
  }

  /// Checks if the user is authenticated
  ///
  /// Returns [Future<bool>] - true if user is authenticated, false otherwise
  ///
  /// Throws [Exception] if retrieval operation fails
  static Future<bool> isAuth() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_authKey) ?? false;
    } catch (e) {
      throw Exception('Failed to get authentication status: $e');
    }
  }

  /// Sets the authentication status
  ///
  /// [isAuthenticated] - Boolean value indicating whether user is authenticated
  ///
  /// Throws [Exception] if storage operation fails
  static Future<void> setAuthStatus(bool isAuthenticated) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authKey, isAuthenticated);
    } catch (e) {
      throw Exception('Failed to set authentication status: $e');
    }
  }
}
