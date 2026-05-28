import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/auth/widgets/otp_verify_screen.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/service/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
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
            onResend: () =>
                AuthService().sendPasswordResetOtp(normalizedEmail),
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
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.primary,
      appBar: AppBar(
        backgroundColor: AppColor.primary,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: AppColor.white, size: 22.sp),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
                    child: Center(
                      child: Container(
                        width: 100.w,
                        height: 100.w,
                        decoration: BoxDecoration(
                          color: AppColor.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_reset_rounded, size: 50.sp, color: AppColor.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: AppRadii.topOnly(AppRadii.xxl),
                      ),
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl.h, horizontal: AppSpacing.xxl.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          gapV(AppSpacing.lg),
                          Text(
                            AppCopy.forgotTitle,
                            style: AppText.headingMd.copyWith(color: AppColor.textPrimary, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          gapV(AppSpacing.md),
                          Text(
                            AppCopy.forgotBody,
                            style: AppText.bodyMd,
                            textAlign: TextAlign.center,
                          ),
                          gapV(AppSpacing.xxxl),
                          Form(
                            key: formKey,
                            child: AppInput(
                              label: AppCopy.authEmailLabel,
                              hintText: AppCopy.authEmailHint,
                              controller: emailController,
                              textInputAction: TextInputAction.done,
                              type: TextInputType.emailAddress,
                              suffixIcon: Icon(Icons.email_outlined, color: AppColor.primary, size: 20.sp),
                              validator: (value) {
                                if (value == null || value.isEmpty) return AppCopy.fieldRequired;
                                if (!AuthService.isGmailEmail(value)) return AppCopy.emailGmailOnly;
                                return null;
                              },
                            ),
                          ),
                          gapV(AppSpacing.xl),
                          AppButton(text: AppCopy.forgotSendCode, onPress: _sendResetOtp, isLoading: _isLoading),
                          gapV(AppSpacing.xxl),
                          Center(
                            child: Text(
                              AppCopy.forgotHint,
                              style: AppText.bodySm,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
