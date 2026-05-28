import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/config/supabase_config.dart';
import 'package:rafiq_app/model/user_model.dart';
import 'package:rafiq_app/service/api_service.dart';

class AuthService {
  static const String _loggedInKey = 'isLoggedIn';
  static const String _authUserIdKey = 'authUserId';
  static const String _userNameKey = 'userName';
  static const String _userEmailKey = 'userEmail';
  static const String _profileImageKey = 'profile_image';
  static Future<void>? _googleSignInInitFuture;

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
    if (message.contains('sign_in_canceled') ||
        message.contains('sign-in-canceled') ||
        message.contains('canceled by user')) {
      return 'تم إلغاء تسجيل الدخول عبر Google.';
    }
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
    if (message.contains('Developer console is not set up correctly') ||
        message.contains('clientConfigurationError') ||
        message.contains('GoogleSignInExceptionCode.unknownError') ||
        message.contains('Developer console')) {
      return 'إعداد Google Sign-In غير مكتمل. فعّل Google Sign-In في Firebase أو Google Cloud، وأضف SHA-1 و SHA-256 لتوقيع التطبيق، ثم أعد تنزيل google-services.json بحيث يحتوي على oauth_client من نوع web.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  /// Sign-up step 1 — collect user details and trigger the 6-digit OTP email.
  ///
  /// After this call Supabase has created an unconfirmed `auth.users` row
  /// and dispatched a 6-digit code via the "Confirm signup" email template.
  /// The session is intentionally `null` — the account is NOT logged in until
  /// [verifySignUpOtp] succeeds.
  ///
  /// Prerequisites (one-time, in Supabase dashboard):
  ///   Auth -> Providers -> Email   -> Enable email confirmations: ON
  ///   Auth -> Email templates -> Confirm signup
  ///     Subject: "كود رفيق"
  ///     Body MUST contain `{{ .Token }}` (6-digit code), not `{{ .ConfirmationURL }}`.
  ///
  /// Throws [Exception] with a friendly Arabic message on failure.
  Future<void> signUpWithEmailOtp({
    required String name,
    required String email,
    required String password,
  }) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw Exception('اسمك مطلوب.');
    }
    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('لازم يكون بريد @gmail.com.');
    }
    if (!isStrongPassword(password)) {
      throw Exception(passwordRequirementMessage());
    }

    try {
      await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': normalizedName,
          'name': normalizedName,
        },
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /// Sign-up step 2 — exchange the 6-digit code for an active session.
  ///
  /// On success the user is fully logged in; the local session cache is
  /// populated and the [UserModel] is returned for UI use.
  Future<UserModel> verifySignUpOtp({
    required String email,
    required String code,
  }) async {
    await ensureSupabaseInitialized();

    final normalizedEmail = email.trim().toLowerCase();
    final token = code.trim();

    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('بريد غير مظبوط.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      throw Exception('الكود لازم يكون 6 أرقام.');
    }

    late final AuthResponse response;
    try {
      response = await _client.auth.verifyOTP(
        email: normalizedEmail,
        token: token,
        type: OtpType.signup,
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }

    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw Exception('تعذر تأكيد الحساب. جرّب تاني.');
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

  /// Re-send the 6-digit signup OTP if the first email was lost.
  Future<void> resendSignUpOtp(String email) async {
    await ensureSupabaseInitialized();
    final normalizedEmail = email.trim().toLowerCase();
    if (!isGmailEmail(normalizedEmail)) {
      throw Exception('لازم يكون بريد @gmail.com.');
    }
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: normalizedEmail,
      );
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<void> _ensureGoogleSignInInitialized() {
    if (kIsWeb) {
      return Future.value();
    }

    final webClientId = SupabaseConfig.googleWebClientId.trim();

    const iosClientId = SupabaseConfig.googleIosClientId;
    final initFuture = _googleSignInInitFuture;
    if (initFuture != null) {
      return initFuture;
    }

    final googleSignIn = GoogleSignIn.instance;
    _googleSignInInitFuture = googleSignIn
        .initialize(
      clientId: (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS) &&
              iosClientId.isNotEmpty
          ? iosClientId
          : null,
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
    )
        .catchError((error) {
      _googleSignInInitFuture = null;
      throw error;
    });
    return _googleSignInInitFuture!;
  }

  /// Google sign-in.
  ///
  /// Web uses Supabase OAuth in the browser.
  /// Mobile uses the official Google Sign-In SDK and exchanges the resulting
  /// ID token with Supabase.
  Future<bool> signInWithGoogle() async {
    await ensureSupabaseInitialized();
    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: SupabaseConfig.googleWebRedirectUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
        return false;
      }

      await _ensureGoogleSignInInitialized();
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate();
      final googleAuthentication = googleUser.authentication;
      final googleAuthorization =
          await googleUser.authorizationClient.authorizationForScopes([]);

      final idToken = googleAuthentication.idToken;
      if (idToken == null) {
        throw Exception('تعذر الحصول على رموز Google الآمنة.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuthorization?.accessToken,
      );

      final user = response.user ?? _client.auth.currentUser;
      if (user == null) {
        throw Exception('تعذر تسجيل الدخول عبر Google.');
      }

      final profile = await _loadProfile(user.id);
      final fallbackName = profile?['full_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          'مستخدم';
      final email =
          profile?['email']?.toString() ?? user.email ?? googleUser.email;

      await _cacheUserSession(
        id: user.id,
        name: fallbackName,
        email: email,
      );
      return true;
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /// Legacy synchronous signUp kept for callers that don't yet use the OTP
  /// verification screen. Equivalent to [signUpWithEmailOtp] without the
  /// verification step — the user must still verify before they can sign in
  /// (Supabase's email confirmation requirement is now ON by design).
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await signUpWithEmailOtp(name: name, email: email, password: password);
    return UserModel(
      id: '',
      name: name.trim(),
      email: email.trim().toLowerCase(),
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
      await _client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: SupabaseConfig.recoveryRedirectUrl,
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
        type: OtpType.recovery,
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
