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
    if (message.contains('Invalid login credentials') ||
        message.contains('invalid login credentials') ||
        message.contains('wrong password') ||
        message.contains('password authentication failed')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة. تأكد أنك سجلت الحساب من شاشة إنشاء حساب، أو استخدم "نسيت كلمة السر؟" إذا كنت لا تتذكرها.';
    }
    if (message.contains('user_not_found')) {
      return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
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

      final idToken = googleAuthentication.idToken;
      if (idToken == null) {
        throw Exception('تعذر الحصول على رموز Google الآمنة.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
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
  /// Calls the SECURITY DEFINER `delete_my_account(reason)` RPC which:
  ///   1. Cancels any active subscription on the provider.
  ///   2. Deletes the provider row (cascades to places, reviews, etc.).
  ///   3. Deletes the auth.users row.
  ///   4. Appends an audit entry in `account_deletions`.
  ///
  /// After the RPC returns, the Supabase session is invalid; this method
  /// also issues a local `signOut()` so the client cache + prefs are
  /// scrubbed before the caller navigates to login.
  Future<Map<String, dynamic>> deleteMyAccount({String? reason}) async {
    await ensureSupabaseInitialized();
    Map<String, dynamic> summary = const {};
    try {
      final raw = await _client.rpc(
        'delete_my_account',
        params: {'_reason': reason},
      );
      if (raw is Map) {
        summary = Map<String, dynamic>.from(raw);
      }
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
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
    // Warm the provider row immediately so provider screens never race auth
    // restoration after a fresh login.
    await ApiService().ensureCurrentProviderId();
  }
}
