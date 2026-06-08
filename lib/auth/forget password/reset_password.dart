import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/security/password_policy.dart';
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
  String _password = '';

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
      AppFeedback.error(AppCopy.errorGeneric);
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
        AppPageScaffold(
          header: const AppPageHeader(title: AppCopy.resetTitle),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              keyboardOpen ? AppSpacing.md.h : AppSpacing.xl.h,
              AppSpacing.lg.w,
              AppSpacing.huge.h,
            ),
            children: [
              if (!keyboardOpen)
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
                currentEmail.isEmpty
                    ? AppCopy.resetBody
                    : (widget.requiresOtpVerification
                        ? '${AppCopy.verifyBodyPrefix.trim()} $currentEmail'
                        : currentEmail),
                style: AppText.bodyMd.copyWith(
                  color: AppColor.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              gapV(AppSpacing.xl),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      hintText: AppCopy.authPasswordHint,
                      controller: _passwordController,
                      textInputAction: TextInputAction.next,
                      isPassword: true,
                      type: TextInputType.visiblePassword,
                      helperText: AppCopy.registerPasswordHelper,
                      onChanged: (value) => setState(() => _password = value),
                      paddingBottom: AppSpacing.md,
                      validator: PasswordPolicy.validateNewPassword,
                    ),
                    PasswordRequirements(password: _password),
                    gapV(AppSpacing.md),
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
                    gapV(AppSpacing.xl),
                    AppButton(
                      text: widget.requiresOtpVerification
                          ? AppCopy.resetCta
                          : AppCopy.done,
                      onPress: _updatePassword,
                      isLoading: _isProcessing,
                    ),
                  ],
                ),
              ),
            ],
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
