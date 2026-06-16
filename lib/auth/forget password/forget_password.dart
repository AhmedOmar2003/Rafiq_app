import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/auth/widgets/otp_verify_screen.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_error_formatter.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/service/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Duration _authRetryDelay = Duration(minutes: 1);

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool _isLoading = false;
  DateTime? _authRetryAfter;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
    if (!_canStartResetRequest()) return;
    if (!formKey.currentState!.validate()) return;

    final normalizedEmail = emailController.text.trim().toLowerCase();
    setState(() => _isLoading = true);
    try {
      await AuthService().sendPasswordResetOtp(normalizedEmail);
      if (!mounted) return;
      AppFeedback.success(AppCopy.forgotCodeSent);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            email: normalizedEmail,
            flow: OtpFlow.recovery,
            onVerify: (code) => AuthService().verifyPasswordResetOtp(
              email: normalizedEmail,
              otpCode: code,
            ),
            onResend: () => AuthService().sendPasswordResetOtp(normalizedEmail),
            onSuccess: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ResetPasswordPage(
                    emailForOtpFlow: normalizedEmail,
                    requiresOtpVerification: false,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = AppErrorFormatter.userMessage(e);
      _rememberRateLimit(message);
      AppFeedback.error(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _canStartResetRequest() {
    if (_isLoading) return false;

    final retryAfter = _authRetryAfter;
    if (retryAfter == null || DateTime.now().isAfter(retryAfter)) {
      return true;
    }

    AppFeedback.error(AppCopy.authRateLimited);
    return false;
  }

  void _rememberRateLimit(String message) {
    if (message != AppCopy.authRateLimited) return;
    setState(() {
      _authRetryAfter = DateTime.now().add(_authRetryDelay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppPageHeader(title: AppCopy.forgotTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w,
          AppSpacing.xl.h,
          AppSpacing.lg.w,
          AppSpacing.huge.h,
        ),
        children: [
          Container(
            width: 88.w,
            height: 88.w,
            margin: EdgeInsets.only(bottom: AppSpacing.xl.h),
            decoration: const BoxDecoration(
              color: AppColor.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 42.sp,
              color: AppColor.primary,
            ),
          ),
          Text(
            AppCopy.forgotBody,
            style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
          ),
          gapV(AppSpacing.xl),
          Form(
            key: formKey,
            child: AppInput(
              label: AppCopy.authEmailLabel,
              hintText: AppCopy.authEmailHint,
              controller: emailController,
              textInputAction: TextInputAction.done,
              type: TextInputType.emailAddress,
              suffixIcon: Icon(Icons.email_outlined,
                  color: AppColor.primary, size: 20.sp),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppCopy.fieldRequired;
                }
                if (!AuthService.isGmailEmail(value)) {
                  return AppCopy.emailGmailOnly;
                }
                return null;
              },
            ),
          ),
          gapV(AppSpacing.lg),
          AppButton(
            text: AppCopy.forgotSendCode,
            onPress: _sendResetOtp,
            isLoading: _isLoading,
          ),
          gapV(AppSpacing.md),
          Text(
            AppCopy.forgotHint,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
