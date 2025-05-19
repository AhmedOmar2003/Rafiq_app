import '../../models/Api_model/api_model.dart';

class ApiConfig {
  static String get baseUrl => "http://${GlopalVariable.ipConfig}/Api";
  static String get loginUrl => "$baseUrl/login_user.php";
  static String get getUserUrl => "$baseUrl/get_user.php";
  static String get registerUrl => "$baseUrl/register_user.php";
  static const String geminiApiKey = String.fromEnvironment(
    'AIzaSyAQ_mE8k4FQNQw2ZFbGt-1QSb1XzpSJTZI',
    defaultValue: 'AIzaSyAQ_mE8k4FQNQw2ZFbGt-1QSb1XzpSJTZI', // Replace with your actual API key
  );

  // Default Values
  static const String defaultBudget = 'غير محدد';
  static const String defaultActivity = '';

  // Response Keys
  static const String placesKey = 'places';

  // HTTP Status Codes
  static const int successStatusCode = 200;

  // Error Messages
  static const String invalidResponseFormat =
      'Invalid response format from server';
  static const String networkError = 'Network error: ';
  static const String unexpectedError = 'Unexpected error: ';
  static const String missingPlacesKey =
      'Invalid response format: missing "places" key';
  static const String noPlacesFound = 'No places found matching your criteria';
  static const String parseError = 'Failed to parse place data: ';

  // URL Builder Methods
  static Uri buildPlacesUri({
    required String cityName,
    String? budget,
    String? activity,
  }) {
    final validBudget = budget?.isNotEmpty == true ? budget! : defaultBudget;
    final validActivity =
        activity?.isNotEmpty == true ? activity! : defaultActivity;

    return Uri.parse(
      '$baseUrl/get_places.php?cityName=$cityName&budget=$validBudget&activityName=$validActivity',
    );
  }
}
