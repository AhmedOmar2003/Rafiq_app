import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/service/auth_service.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _otpCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsLeft = _otpCooldownSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _countdownTimer?.cancel();
    setState(() => _secondsLeft = _otpCooldownSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String _formattedCountdown() {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await AuthService().verifyPasswordResetOtp(
        email: widget.email,
        otpCode: _codeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordPage(
            emailForOtpFlow: widget.email,
            requiresOtpVerification: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0 || _isResending) {
      return;
    }

    setState(() => _isResending = true);
    try {
      await AuthService().sendPasswordResetOtp(widget.email);
      if (!mounted) {
        return;
      }
      _startCooldown();
      AppFeedback.success(AppCopy.forgotCodeSent);
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
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
                            Icons.mark_email_read_outlined,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        24.w,
                        keyboardOpen ? 16.h : 32.h,
                        24.w,
                        16.h,
                      ),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                AppCopy.verifyTitle,
                                style:
                                    AppText.headingLg.copyWith(
                                  color: AppColor.black,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: keyboardOpen ? 8.h : 12.h),
                              Text(
                                AppCopy.verifyBodyPrefix.trim(),
                                style:
                                    AppText.bodyLg.copyWith(
                                  color: AppColor.black.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                widget.email,
                                style:
                                    AppText.titleMd.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: keyboardOpen ? 20.h : 28.h),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: PinCodeTextField(
                                  appContext: context,
                                  controller: _codeController,
                                  length: 6,
                                  keyboardType: TextInputType.number,
                                  autoDisposeControllers: false,
                                  animationType: AnimationType.fade,
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(12.r),
                                    fieldHeight: 52.h,
                                    fieldWidth: 46.w,
                                    borderWidth: 1,
                                    inactiveColor:
                                        AppColor.primary.withOpacity(0.25),
                                    activeColor: AppColor.primary,
                                    selectedColor: AppColor.primary,
                                    activeFillColor:
                                        AppColor.primary.withOpacity(0.04),
                                    inactiveFillColor:
                                        AppColor.primary.withOpacity(0.03),
                                    selectedFillColor:
                                        AppColor.primary.withOpacity(0.06),
                                  ),
                                  enableActiveFill: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return AppCopy.fieldRequired;
                                    }
                                    if (!RegExp(r'^\d{6}$')
                                        .hasMatch(value.trim())) {
                                      return AppCopy.verifyCodeWrongLength;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(height: keyboardOpen ? 12.h : 18.h),
                              AppButton(
                                text: _isVerifying ? "..." : AppCopy.verifyCta,
                                textStyle:
                                    AppText.headingSm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                buttonStyle: ElevatedButton.styleFrom(
                                  backgroundColor: AppColor.primary,
                                  minimumSize: Size(double.infinity, 56.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      AppColor.primary.withOpacity(0.4),
                                  disabledBackgroundColor:
                                      AppColor.primary.withOpacity(0.5),
                                ),
                                onPress: _isVerifying ? () {} : _verifyCode,
                              ),
                              SizedBox(height: 12.h),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _secondsLeft > 0
                                    ? Text(
                                        "${AppCopy.verifyResendIn} ${_formattedCountdown()}",
                                        key: const ValueKey("cooldownText"),
                                        style: AppText.bodyMd
                                            .copyWith(
                                          color:
                                              AppColor.black.withOpacity(0.55),
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    : TextButton(
                                        key: const ValueKey("resendButton"),
                                        onPressed:
                                            _isResending ? null : _resendCode,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 8.h,
                                          ),
                                          foregroundColor: AppColor.primary
                                              .withOpacity(0.85),
                                        ),
                                        child: Text(
                                          _isResending
                                              ? AppCopy.loading
                                              : AppCopy.verifyResend,
                                          style: AppText.labelMd.copyWith(
                                            color: AppColor.primary
                                                .withOpacity(0.85),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
