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

  static const String recoveryRedirectUrl = String.fromEnvironment(
    'SUPABASE_RECOVERY_REDIRECT_URL',
    defaultValue: 'https://rafiq-master-zeta.vercel.app/app/',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
