import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? emailForOtpFlow;
  final bool requiresOtpVerification;

  const ResetPasswordPage({
    super.key,
    this.emailForOtpFlow,
    this.requiresOtpVerification = false,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isProcessing = false;
  bool _showSuccessOverlay = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (widget.requiresOtpVerification) {
        final email = widget.emailForOtpFlow?.trim() ?? '';
        await AuthService().verifyPasswordResetOtp(
          email: email,
          otpCode: _otpController.text,
        );
      }
      await AuthService().updatePassword(_passwordController.text);
      await AuthService().signOut();
      if (!mounted) {
        return;
      }
      setState(() => _showSuccessOverlay = true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final explicitEmail = widget.emailForOtpFlow?.trim() ?? '';
    final currentEmail = explicitEmail.isNotEmpty
        ? explicitEmail
        : (Supabase.instance.client.auth.currentUser?.email ?? '');
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColor.primary,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: AppColor.primary,
            elevation: 0,
            leading: Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColor.white,
                  size: 24.sp,
                ),
              ),
            ),
            title: Text(
              AppCopy.resetTitle,
              style: AppText.headingSm.copyWith(
                color: AppColor.white,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: keyboardOpen
                      ? SizedBox(height: 8.h)
                      : Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: Center(
                            child: Container(
                              width: 100.w,
                              height: 100.w,
                              decoration: BoxDecoration(
                                color: AppColor.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 50.sp,
                                color: AppColor.white,
                              ),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColor.ofWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(36.r),
                        topRight: Radius.circular(36.r),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: keyboardOpen ? 16.h : 28.h,
                      horizontal: 24.w,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppCopy.resetTitle,
                            style: AppText.headingSm.copyWith(
                              color: AppColor.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: keyboardOpen ? 6.h : 8.h),
                          Text(
                            currentEmail.isEmpty
                                ? AppCopy.resetBody
                                : (widget.requiresOtpVerification
                                    ? '${AppCopy.verifyBodyPrefix.trim()} $currentEmail'
                                    : currentEmail),
                            style: AppText.bodyLg.copyWith(
                              color: AppColor.black.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: keyboardOpen ? 14.h : 24.h),
                          if (widget.requiresOtpVerification)
                            AppInput(
                              label: AppCopy.verifyTitle,
                              hintText: AppCopy.resetOtpHint,
                              controller: _otpController,
                              type: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              paddingBottom: AppSpacing.md,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return AppCopy.fieldRequired;
                                }
                                if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                                  return AppCopy.verifyCodeWrongLength;
                                }
                                return null;
                              },
                            ),
                          AppInput(
                            label: AppCopy.changePwNew,
                            hintText: "6 حروف على الأقل",
                            controller: _passwordController,
                            textInputAction: TextInputAction.next,
                            isPassword: true,
                            paddingBottom: AppSpacing.md,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppCopy.passwordRequired;
                              }
                              if (!AuthService.isStrongPassword(value)) {
                                return AppCopy.passwordShort;
                              }
                              return null;
                            },
                          ),
                          AppInput(
                            label: AppCopy.changePwConfirm,
                            hintText: AppCopy.resetConfirmHint,
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            isPassword: true,
                            paddingBottom: 0,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppCopy.fieldRequired;
                              }
                              if (value != _passwordController.text) {
                                return AppCopy.passwordsMismatch;
                              }
                              return null;
                            },
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 55.h,
                            child: AppButton(
                              text: _isProcessing
                                  ? "..."
                                  : (widget.requiresOtpVerification
                                      ? AppCopy.resetCta
                                      : AppCopy.done),
                              textStyle:
                                  AppText.titleLg.copyWith(
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              buttonStyle: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                              ),
                              onPress: _isProcessing ? () {} : _updatePassword,
                              child: _isProcessing
                                  ? SizedBox(
                                      height: 24.h,
                                      width: 24.w,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSuccessOverlay)
          AppSuccessView(
            title: AppCopy.resetSuccess,
            message: AppCopy.resetSuccessBody,
            onContinue: _navigateToLogin,
          ),
      ],
    );
  }
}
