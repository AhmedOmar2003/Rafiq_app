import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qtlmumlcvcwqieexcguy.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0bG11bWxjdmN3cWllZXhjZ3V5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NDMwMTEsImV4cCI6MjA5MjExOTAxMX0.fvPB55Iedho6ABmMoVQ9M5xEPtNfSN7bwr6HYKL-Qkc',
  );

  static const String _webRecoveryRedirectFallback =
      'https://rafiq-master-zeta.vercel.app/app/';
  static const String _mobileRecoveryRedirectFallback =
      'rafiqapp://reset-password';

  static String get recoveryRedirectUrl {
    const configured = String.fromEnvironment(
      'SUPABASE_RECOVERY_REDIRECT_URL',
      defaultValue: '',
    );
    if (configured.isNotEmpty) {
      return configured;
    }
    return kIsWeb
        ? _webRecoveryRedirectFallback
        : _mobileRecoveryRedirectFallback;
  }

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '15647293384-9albfrqg5h84e4jfbnbto2ms3nhhg4td.apps.googleusercontent.com',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static String get googleWebRedirectUrl {
    const configured = String.fromEnvironment(
      'GOOGLE_WEB_OAUTH_REDIRECT_URL',
      defaultValue: '',
    );
    if (configured.isNotEmpty) {
      return configured;
    }
    return _webRecoveryRedirectFallback;
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
