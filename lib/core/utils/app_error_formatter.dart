import 'app_microcopy.dart';

class AppErrorFormatter {
  AppErrorFormatter._();

  static String userMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return AppCopy.errorGeneric;

    final normalized = raw.toLowerCase();

    if (normalized.contains('socketexception') ||
        normalized.contains('timeout') ||
        normalized.contains('network') ||
        normalized.contains('connection')) {
      return AppCopy.offlineBody;
    }

    if (normalized.contains('payload too large') ||
        normalized.contains('maximum allowed size') ||
        normalized.contains('file size')) {
      return 'الصورة كبيرة شوية. اختار صورة أقل من 2 ميجا.';
    }

    if (normalized.contains('mime') ||
        normalized.contains('content type') ||
        normalized.contains('unsupported image')) {
      return 'اختار صورة JPG أو PNG أو WebP.';
    }

    if (normalized.contains('jwt') ||
        normalized.contains('auth') ||
        normalized.contains('session') ||
        raw.contains('يجب تسجيل الدخول')) {
      return AppCopy.providerSessionExpired;
    }

    if (normalized.contains('supabase') ||
        normalized.contains('postgres') ||
        normalized.contains('postgrest') ||
        normalized.contains('storageexception') ||
        normalized.contains('functionexception') ||
        normalized.contains('pgrst') ||
        normalized.contains('rpc') ||
        normalized.contains('failed to') ||
        normalized.contains('relation "') ||
        normalized.contains('column "') ||
        normalized.contains('unexpected')) {
      return AppCopy.errorGeneric;
    }

    return raw;
  }
}
