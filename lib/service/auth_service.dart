import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/model/user_model.dart';
import 'package:rafiq_app/service/api_service.dart';

class AuthService {
  static const String _loggedInKey = 'isLoggedIn';
  static const String _authUserIdKey = 'authUserId';
  static const String _userNameKey = 'userName';
  static const String _userEmailKey = 'userEmail';
  static const String _profileImageKey = 'profile_image';

  static Future<void> ensureSupabaseInitialized() {
    return ApiService.ensureSupabaseInitialized();
  }

  SupabaseClient get _client => Supabase.instance.client;

  static bool isGmailEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(normalized);
  }

  static bool isStrongPassword(String password) {
    return RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[#?!@$%^&*\-_.])[A-Za-z\d#?!@$%^&*\-_.]{8,}$',
    ).hasMatch(password);
  }

  static String passwordRequirementMessage() {
    return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل وتحتوي على حرف كبير وحرف صغير ورقم ورمز.';
  }

  String _friendlyAuthError(Object error) {
    final message = error.toString();
    if (message.contains('over_email_send_rate_limit') ||
        message.contains('AuthApiException') && message.contains('429')) {
      return 'Supabase ما زال يحاول إرسال email confirmation. لو تريد تسجيلًا مباشرًا بدون أي تأكيد، أوقف Email Confirmation من Supabase Auth > Providers > Email ثم جرّب مرة أخرى.';
    }
    if (message.contains('email_not_confirmed')) {
      return 'الحساب يحتاج تأكيد بريد إلكتروني. أوقف Email Confirmation من Supabase لو تريد التسجيل الفوري.';
    }
    if (message.contains('invalid_grant') ||
        message.contains('otp_expired') ||
        message.contains('token_not_found')) {
      return 'كود التحقق غير صحيح أو انتهت صلاحيته. اطلب كودًا جديدًا وحاول مرة أخرى.';
    }
    if (message.contains('user_not_found')) {
      return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();
    final normalizedPassword = password;

    if (normalizedName.isEmpty) {
      throw Exception('اسم المستخدم مطلوب.');
    }
    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('البريد الإلكتروني يجب أن ينتهي بـ @gmail.com.');
    }
    if (!isStrongPassword(normalizedPassword)) {
      throw Exception(passwordRequirementMessage());
    }

    late final AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: normalizedEmail,
        password: normalizedPassword,
        data: {
          'full_name': normalizedName,
          'name': normalizedName,
        },
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }

    final user = response.user;
    if (user == null) {
      throw Exception(
        'فشل إنشاء الحساب. تأكد أن تأكيد البريد الإلكتروني معطل من Supabase حتى يتم التسجيل مباشرة.',
      );
    }

    if (response.session == null) {
      throw Exception(
        'تم إنشاء الحساب لكن لم يتم تسجيل الدخول تلقائيًا. عطّل Email Confirmation من Supabase Auth > Providers > Email لإتاحة التسجيل الفوري.',
      );
    }

    final profile = await _loadProfile(user.id);
    await _cacheUserSession(
      id: user.id,
      name: profile?['full_name']?.toString() ?? normalizedName,
      email: profile?['email']?.toString() ?? normalizedEmail,
    );

    return UserModel(
      id: user.id,
      name: profile?['full_name']?.toString() ?? normalizedName,
      email: profile?['email']?.toString() ?? normalizedEmail,
    );
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password;

    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('البريد الإلكتروني يجب أن ينتهي بـ @gmail.com.');
    }
    if (normalizedPassword.isEmpty) {
      throw Exception('كلمة المرور مطلوبة.');
    }

    late final AuthResponse response;
    try {
      response = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: normalizedPassword,
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw Exception('تعذر تسجيل الدخول.');
    }

    final profile = await _loadProfile(user.id);
    final fallbackName = profile?['full_name']?.toString() ??
        user.userMetadata?['full_name']?.toString() ??
        user.userMetadata?['name']?.toString() ??
        normalizedEmail.split('@').first;

    await _cacheUserSession(
      id: user.id,
      name: fallbackName,
      email: profile?['email']?.toString() ?? normalizedEmail,
    );

    return UserModel(
      id: user.id,
      name: fallbackName,
      email: profile?['email']?.toString() ?? normalizedEmail,
    );
  }

  Future<void> signOut() async {
    await ensureSupabaseInitialized();
    await _client.auth.signOut();

    final prefs = await SharedPreferences.getInstance();
    final preservedProfileImage = prefs.getString(_profileImageKey);
    await prefs.clear();
    if (preservedProfileImage != null && preservedProfileImage.isNotEmpty) {
      await prefs.setString(_profileImageKey, preservedProfileImage);
    }
    await prefs.setBool(_loggedInKey, false);
  }

  Future<void> sendPasswordResetOtp(String email) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('البريد الإلكتروني يجب أن ينتهي بـ @gmail.com.');
    }

    try {
      await _client.auth.signInWithOtp(
        email: normalizedEmail,
        shouldCreateUser: false,
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otpCode,
  }) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    final token = otpCode.trim();

    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('البريد الإلكتروني يجب أن ينتهي بـ @gmail.com.');
    }
    if (token.isEmpty) {
      throw Exception('من فضلك أدخل كود التحقق.');
    }

    try {
      await _client.auth.verifyOTP(
        email: normalizedEmail,
        token: token,
        type: OtpType.email,
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return sendPasswordResetOtp(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await ensureSupabaseInitialized();

    final normalizedPassword = newPassword;
    if (!isStrongPassword(normalizedPassword)) {
      throw Exception(passwordRequirementMessage());
    }

    await _client.auth.updateUser(
      UserAttributes(password: normalizedPassword),
    );
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> _cacheUserSession({
    required String id,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authUserIdKey, id);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setBool(_loggedInKey, true);
  }
}
