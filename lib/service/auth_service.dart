import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/config/supabase_config.dart';
import 'package:rafiq_app/core/security/password_policy.dart';
import 'package:rafiq_app/model/user_model.dart';
import 'package:rafiq_app/service/api_service.dart';

enum GoogleAuthIntent { login, register }

class AuthService {
  static const String _loggedInKey = 'isLoggedIn';
  static const String _authUserIdKey = 'authUserId';
  static const String _userNameKey = 'userName';
  static const String _userEmailKey = 'userEmail';
  static const String _pendingGoogleIntentKey = 'pendingGoogleAuthIntent';
  static const String _pendingAuthMessageKey = 'pendingAuthMessage';
  static Future<void>? _googleSignInInitFuture;
  static const String _debugApkSha1 =
      '18:F5:9B:36:DB:62:46:91:1C:7E:AF:84:A7:FE:ED:0F:4C:68:D0:94';
  static const String _debugApkSha256 =
      '28:D2:CB:18:50:97:DE:27:31:5D:C4:D7:41:D7:A8:2D:66:BC:58:C4:FB:BD:77:BB:2C:20:1E:F5:B7:7F:A6:38';

  static Future<void> ensureSupabaseInitialized() {
    return ApiService.ensureSupabaseInitialized();
  }

  SupabaseClient get _client => Supabase.instance.client;

  static bool isGmailEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return RegExp(r'^[a-z0-9._%+-]+@gmail\.com$').hasMatch(normalized);
  }

  static bool isStrongPassword(String password) {
    return PasswordPolicy.isStrong(password);
  }

  static String passwordRequirementMessage() {
    return PasswordPolicy.requirementMessage;
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
    if (message.contains('Invalid login credentials') ||
        message.contains('invalid login credentials') ||
        message.contains('wrong password') ||
        message.contains('password authentication failed')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة. تأكد أنك سجلت الحساب من شاشة إنشاء حساب، أو استخدم "نسيت كلمة السر؟" إذا كنت لا تتذكرها.';
    }
    if (message.contains('user_not_found')) {
      return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
    }
    if (message.contains('weak_password') ||
        message.contains('Password should contain') ||
        message.contains('password should contain')) {
      return passwordRequirementMessage();
    }
    if (message.contains('Developer console is not set up correctly') ||
        message.contains('clientConfigurationError') ||
        message.contains('GoogleSignInExceptionCode.unknownError') ||
        message.contains('Developer console')) {
      return 'إعداد Google Sign-In غير مكتمل. هذا الـ APK موقّع حاليًا بشهادة Android Debug، لذلك أضف SHA-1 و SHA-256 التاليين في Firebase/Google Cloud ثم أعد تنزيل google-services.json: SHA-1 = $_debugApkSha1, SHA-256 = $_debugApkSha256. كذلك تأكد أن Google Sign-In مفعّل وأن الملف يحتوي على oauth_client من نوع web.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  /// Raw Supabase sign-up call.
  ///
  /// Behaviour depends on the dashboard setting
  /// (Authentication → Providers → Email → "Confirm email"):
  ///   * **OFF** → returned [AuthResponse] contains a live session; user is
  ///     immediately logged in. The wrapping [signUp] caches it.
  ///   * **ON**  → session is null; user must verify via [verifySignUpOtp]
  ///     before they can sign in. Supabase sends the OTP email automatically.
  ///
  /// Throws [Exception] with a friendly Arabic message on failure.
  Future<AuthResponse> signUpWithEmailOtp({
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
      return await _client.auth.signUp(
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

  Future<bool> signInWithGoogle() =>
      _authenticateWithGoogle(GoogleAuthIntent.login);

  Future<bool> signUpWithGoogle() =>
      _authenticateWithGoogle(GoogleAuthIntent.register);

  /// Google authentication with an explicit user intent.
  ///
  /// Selecting a Google identity does not automatically mean "create a RAFIQ
  /// account". Login accepts only completed accounts; registration accepts
  /// only new or previously incomplete OAuth accounts.
  Future<bool> _authenticateWithGoogle(GoogleAuthIntent intent) async {
    await ensureSupabaseInitialized();
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingGoogleIntentKey, intent.name);
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: SupabaseConfig.googleWebRedirectUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
          queryParams: const {'prompt': 'select_account'},
        );
        return false;
      }

      await _ensureGoogleSignInInitialized();
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate();
      final googleAuthentication = googleUser.authentication;

      final idToken = googleAuthentication.idToken;
      if (idToken == null) {
        throw Exception('تعذر الحصول على رموز Google الآمنة.');
      }

      final emailState = await _lookupLoginEmailState(googleUser.email);
      _validateGoogleIntent(intent: intent, emailState: emailState);

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user ?? _client.auth.currentUser;
      if (user == null) {
        throw Exception('تعذر تسجيل الدخول عبر Google.');
      }

      final profile = await _loadProfile(user.id);
      final signupCompleted = profile?['signup_completed'] == true;
      if (intent == GoogleAuthIntent.login && !signupCompleted) {
        await _client.auth.signOut();
        throw Exception(_googleAccountMissingMessage);
      }
      if (intent == GoogleAuthIntent.register && !signupCompleted) {
        await _client.rpc('complete_google_signup');
      }

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

  static const String _googleAccountMissingMessage =
      'الحساب ده لسه مش متسجل عندنا. اعمل حساب جديد الأول وبعدين تقدر تسجل دخول بسهولة.';
  static const String _googleAccountExistsMessage =
      'الحساب ده متسجل بالفعل. ارجع لصفحة تسجيل الدخول وكمل بحساب Google.';

  void _validateGoogleIntent({
    required GoogleAuthIntent intent,
    required Map<String, dynamic> emailState,
  }) {
    final error = googleIntentError(intent: intent, emailState: emailState);
    if (error != null) {
      throw Exception(error);
    }
  }

  @visibleForTesting
  static String? googleIntentError({
    required GoogleAuthIntent intent,
    required Map<String, dynamic> emailState,
  }) {
    if (!emailState.containsKey('signup_completed')) {
      return 'معرفناش نتحقق من الحساب دلوقتي. اتأكد من الإنترنت وجرّب تاني.';
    }

    final exists = emailState['exists'] == true;
    final signupCompleted = emailState['signup_completed'] == true;

    if (intent == GoogleAuthIntent.login && (!exists || !signupCompleted)) {
      return _googleAccountMissingMessage;
    }
    if (intent == GoogleAuthIntent.register && exists && signupCompleted) {
      return _googleAccountExistsMessage;
    }
    return null;
  }

  /// Completes or rejects a browser OAuth callback using the intent saved
  /// before leaving the app for Google.
  Future<void> finalizePendingGoogleOAuth() async {
    if (!kIsWeb) return;
    await ensureSupabaseInitialized();

    final prefs = await SharedPreferences.getInstance();
    final rawIntent = prefs.getString(_pendingGoogleIntentKey);
    if (rawIntent == null) return;
    await prefs.remove(_pendingGoogleIntentKey);

    final user = _client.auth.currentUser;
    if (user == null) return;

    final intent = rawIntent == GoogleAuthIntent.register.name
        ? GoogleAuthIntent.register
        : GoogleAuthIntent.login;
    final profile = await _loadProfile(user.id);
    final signupCompleted = profile?['signup_completed'] == true;

    if (intent == GoogleAuthIntent.login && !signupCompleted) {
      await _client.auth.signOut();
      await prefs.setString(
        _pendingAuthMessageKey,
        _googleAccountMissingMessage,
      );
      return;
    }

    if (intent == GoogleAuthIntent.register && signupCompleted) {
      await _client.auth.signOut();
      await prefs.setString(
        _pendingAuthMessageKey,
        _googleAccountExistsMessage,
      );
      return;
    }

    if (intent == GoogleAuthIntent.register) {
      await _client.rpc('complete_google_signup');
    }
  }

  Future<String?> takePendingAuthMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final message = prefs.getString(_pendingAuthMessageKey);
    if (message != null) {
      await prefs.remove(_pendingAuthMessageKey);
    }
    return message;
  }

  /// Direct sign-up — creates the account and immediately logs the user in.
  ///
  /// Requires **Email Confirmation = OFF** in the Supabase dashboard
  /// (Authentication → Providers → Email). With it disabled, `signUp`
  /// returns an active session straight away and we cache it.
  ///
  /// If confirmation is still ON in Supabase, the returned session will be
  /// null and the user will be unable to sign in — Supabase rejects the
  /// password until the email is verified.
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();

    final response = await signUpWithEmailOtp(
      name: normalizedName,
      email: normalizedEmail,
      password: password,
    );

    final user = response.user ?? _client.auth.currentUser;
    final session = response.session;

    // If email confirmation is OFF, Supabase returns a live session — cache it.
    if (user != null && session != null) {
      final profile = await _loadProfile(user.id);
      final cachedName = profile?['full_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          normalizedName;
      final cachedEmail =
          profile?['email']?.toString() ?? user.email ?? normalizedEmail;

      await _cacheUserSession(
        id: user.id,
        name: cachedName,
        email: cachedEmail,
      );

      return UserModel(id: user.id, name: cachedName, email: cachedEmail);
    }

    // No session — user must verify their email before signing in.
    return UserModel(
      id: user?.id ?? '',
      name: normalizedName,
      email: normalizedEmail,
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

    final loginState = await _lookupLoginEmailState(normalizedEmail);
    final accountExists = loginState['exists'] == true;
    final emailConfirmed = loginState['confirmed'] == true;
    if (!accountExists) {
      throw Exception(
        'هذا البريد غير مسجل. أنشئ حسابًا جديدًا أولًا، أو استخدم البريد الصحيح إذا كان لديك حساب سابق.',
      );
    }
    if (!emailConfirmed) {
      throw Exception(
        'هذا الحساب موجود لكنه غير مؤكد بعد. افتح رسالة تأكيد الحساب في بريدك، أو أعد إرسال كود التأكيد من شاشة إنشاء الحساب.',
      );
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

  Future<Map<String, dynamic>> _lookupLoginEmailState(String email) async {
    try {
      final response = await _client.rpc(
        'lookup_auth_email_state',
        params: {'p_email': email},
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (_) {
      // If the lookup RPC is unavailable, fall back to the normal sign-in flow
      // by assuming the account exists and is confirmed.
    }
    return const <String, dynamic>{
      'exists': true,
      'confirmed': true,
      'profile_exists': true,
    };
  }

  /// Permanently deletes the caller's account.
  ///
  /// Preferred path:
  ///   1. Invoke the `delete-account` Edge Function so storage artefacts are
  ///      removed before the account disappears from the app.
  ///   2. Fall back to the hardened `delete_my_account(reason)` RPC if the
  ///      function is unavailable in the current environment.
  ///
  /// After the RPC returns, the Supabase session is invalid; this method
  /// also issues a local `signOut()` so the client cache + prefs are
  /// scrubbed before the caller navigates to login.
  Future<Map<String, dynamic>> deleteMyAccount({String? reason}) async {
    await ensureSupabaseInitialized();
    Map<String, dynamic> summary = const {};
    try {
      final functionResponse = await _client.functions.invoke(
        'delete-account',
        body: {'reason': reason},
      );
      final functionData = functionResponse.data;
      if (functionData is Map) {
        summary = Map<String, dynamic>.from(functionData);
      } else {
        final raw = await _client.rpc(
          'delete_my_account',
          params: {'_reason': reason},
        );
        if (raw is Map) {
          summary = Map<String, dynamic>.from(raw);
        }
      }
    } catch (e) {
      try {
        final raw = await _client.rpc(
          'delete_my_account',
          params: {'_reason': reason},
        );
        if (raw is Map) {
          summary = Map<String, dynamic>.from(raw);
        }
      } catch (fallbackError) {
        throw Exception(_friendlyAuthError(fallbackError));
      }
    }
    // Local cleanup runs even if the auth row was already invalidated.
    try {
      await _client.auth.signOut();
    } catch (_) {/* the session may already be dead — fine */}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {/* swallow */}
    return summary;
  }

  Future<void> signOut() async {
    await ensureSupabaseInitialized();
    await _client.auth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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

  Future<void> changeCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ensureSupabaseInitialized();

    final user = _client.auth.currentUser ?? _client.auth.currentSession?.user;
    final email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw Exception('لقيناش البريد الإلكتروني، سجل دخول تاني.');
    }
    if (currentPassword.trim().isEmpty) {
      throw Exception('من فضلك اكتب كلمة السر الحالية.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } catch (_) {
      throw Exception('كلمة السر الحالية غير صحيحة.');
    }

    try {
      await updatePassword(newPassword);
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<UserModel?> fetchCurrentUserProfile() async {
    await ensureSupabaseInitialized();

    final user = _client.auth.currentUser ?? _client.auth.currentSession?.user;
    if (user == null) {
      return null;
    }

    final profile = await _loadProfile(user.id);
    final resolvedEmail =
        profile?['email']?.toString().trim().isNotEmpty == true
            ? profile!['email'].toString().trim()
            : (user.email?.trim().isNotEmpty == true ? user.email!.trim() : '');
    final resolvedName = profile?['full_name']?.toString().trim().isNotEmpty ==
            true
        ? profile!['full_name'].toString().trim()
        : (user.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
            ? user.userMetadata!['full_name'].toString().trim()
            : (user.userMetadata?['name']?.toString().trim().isNotEmpty == true
                ? user.userMetadata!['name'].toString().trim()
                : (resolvedEmail.isNotEmpty
                    ? resolvedEmail.split('@').first
                    : 'مستخدم')));

    await _cacheUserSession(
      id: user.id,
      name: resolvedName,
      email: resolvedEmail,
    );

    return UserModel(
      id: user.id,
      name: resolvedName,
      email: resolvedEmail,
    );
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
