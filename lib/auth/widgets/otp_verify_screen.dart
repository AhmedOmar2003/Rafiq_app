import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// Which auth flow this OTP screen is serving.
enum OtpFlow { signup, recovery }

/// Polished, reusable 6-digit OTP entry screen.
///
/// Used by:
///   * Register flow → [OtpFlow.signup]    (verify email after sign-up)
///   * Forgot-password flow → [OtpFlow.recovery] (verify before resetting)
///
/// The screen is presentation-only: callers supply [onVerify] (returns success
/// future) and [onResend] (returns future). The screen owns the cooldown timer,
/// loading state, and validation.
///
/// Visual rules (per design system):
///   * Hero block on brand background with soft ring around the icon.
///   * Cream sheet with rounded top edges containing all content.
///   * 6 brand-themed PIN boxes with focus glow.
///   * Resend section: countdown chip → button transition.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.email,
    required this.flow,
    required this.onVerify,
    required this.onResend,
    required this.onSuccess,
    this.cooldownSeconds = 60,
  });

  final String email;
  final OtpFlow flow;

  /// Called with the 6-digit code. Throw to surface a friendly error.
  final Future<void> Function(String code) onVerify;

  /// Called when user taps "resend". Throw to surface a friendly error.
  final Future<void> Function() onResend;

  /// Called after [onVerify] succeeds (after the optional success overlay).
  final VoidCallback onSuccess;

  final int cooldownSeconds;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  bool _showSuccessOverlay = false;
  int _secondsLeft = 0;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = widget.cooldownSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String _formatCountdown() {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isVerifying) return;

    setState(() => _isVerifying = true);
    try {
      await widget.onVerify(_codeController.text.trim());
      if (!mounted) return;
      if (widget.flow == OtpFlow.signup) {
        setState(() => _showSuccessOverlay = true);
      } else {
        widget.onSuccess();
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      _codeController.clear();
      _startCooldown();
      AppFeedback.success(AppCopy.forgotCodeSent);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Copy
  // ---------------------------------------------------------------------------
  String get _title => switch (widget.flow) {
        OtpFlow.signup => AppCopy.signupVerifyTitle,
        OtpFlow.recovery => AppCopy.resetVerifyTitle,
      };

  String get _bodyTop => switch (widget.flow) {
        OtpFlow.signup => AppCopy.signupVerifyBody,
        OtpFlow.recovery => AppCopy.resetVerifyBody,
      };

  String get _bodyTail => switch (widget.flow) {
        OtpFlow.signup => AppCopy.signupVerifyTail,
        OtpFlow.recovery => AppCopy.resetVerifyTail,
      };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColor.primary,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _BackBar(onBack: () => Navigator.maybePop(context)),
                _Hero(collapsed: keyboardOpen, email: widget.email, title: _title),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColor.surface,
                      borderRadius: AppRadii.topOnly(AppRadii.xxl),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.xxl.w,
                        keyboardOpen ? AppSpacing.lg.h : AppSpacing.xxxl.h,
                        AppSpacing.xxl.w,
                        AppSpacing.xl.h,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _BodyText(top: _bodyTop, tail: _bodyTail),
                            gapV(AppSpacing.xl),
                            _PinField(
                              controller: _codeController,
                              onCompleted: (_) => _verify(),
                            ),
                            gapV(AppSpacing.xl),
                            AppButton(
                              text: AppCopy.verifyCta,
                              onPress: _verify,
                              isLoading: _isVerifying,
                            ),
                            gapV(AppSpacing.lg),
                            _ResendBlock(
                              secondsLeft: _secondsLeft,
                              countdown: _formatCountdown(),
                              isResending: _isResending,
                              onTap: _resend,
                            ),
                          ],
                        ),
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
            title: AppCopy.signupVerifySuccessTitle,
            message: AppCopy.signupVerifySuccessBody,
            onContinue: () {
              setState(() => _showSuccessOverlay = false);
              widget.onSuccess();
            },
          ),
      ],
    );
  }
}

// ===========================================================================
// Internals
// ===========================================================================

class _BackBar extends StatelessWidget {
  const _BackBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          label: AppCopy.back,
          child: Material(
            color: AppColor.white.withOpacity(0.12),
            shape: const CircleBorder(),
            child: InkResponse(
              onTap: onBack,
              radius: 24.w,
              child: SizedBox(
                width: 44.w,
                height: 44.w,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColor.white,
                  size: 20.sp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.collapsed,
    required this.email,
    required this.title,
  });

  final bool collapsed;
  final String email;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      child: collapsed
          ? SizedBox(height: AppSpacing.md.h)
          : Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.xxl.w,
                right: AppSpacing.xxl.w,
                bottom: AppSpacing.xxl.h,
                top: AppSpacing.sm.h,
              ),
              child: Column(
                children: [
                  _RingedIcon(),
                  gapV(AppSpacing.lg),
                  Text(
                    title,
                    style: AppText.headingLg.copyWith(
                      color: AppColor.white,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  gapV(AppSpacing.xs),
                  Text(
                    email,
                    style: AppText.labelMd.copyWith(
                      color: AppColor.white.withOpacity(0.88),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Mail icon inside a soft white ring + inner circle — the only decorative
/// element on the screen; keeps the hero visually distinct without noise.
class _RingedIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104.w,
      height: 104.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColor.white.withOpacity(0.08),
        border: Border.all(
          color: AppColor.white.withOpacity(0.16),
          width: 1,
        ),
      ),
      child: Container(
        width: 72.w,
        height: 72.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColor.white.withOpacity(0.16),
        ),
        child: Icon(
          Icons.mark_email_read_outlined,
          size: 36.sp,
          color: AppColor.white,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText({required this.top, required this.tail});
  final String top;
  final String tail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(top, style: AppText.bodyLg, textAlign: TextAlign.center),
        gapV(AppSpacing.xs),
        Text(
          tail,
          style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.onCompleted});
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PinCodeTextField(
        appContext: context,
        controller: controller,
        length: 6,
        keyboardType: TextInputType.number,
        autoDisposeControllers: false,
        animationType: AnimationType.fade,
        animationDuration: AppMotion.base,
        enableActiveFill: true,
        textStyle: AppText.titleLg.copyWith(fontWeight: FontWeight.w700),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: AppRadii.rMd,
          fieldHeight: 56.h,
          fieldWidth: 46.w,
          borderWidth: 1.4,
          activeBorderWidth: 1.8,
          inactiveColor: AppColor.border,
          activeColor: AppColor.primary,
          selectedColor: AppColor.primary,
          disabledColor: AppColor.neutral200,
          activeFillColor: AppColor.surfaceCard,
          inactiveFillColor: AppColor.surfaceCard,
          selectedFillColor: AppColor.primary50,
        ),
        cursorColor: AppColor.primary,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return AppCopy.fieldRequired;
          }
          if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
            return AppCopy.verifyCodeWrongLength;
          }
          return null;
        },
        onCompleted: onCompleted,
        onChanged: (_) {},
        beforeTextPaste: (_) => true,
      ),
    );
  }
}

class _ResendBlock extends StatelessWidget {
  const _ResendBlock({
    required this.secondsLeft,
    required this.countdown,
    required this.isResending,
    required this.onTap,
  });

  final int secondsLeft;
  final String countdown;
  final bool isResending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        child: secondsLeft > 0
            ? Container(
                key: const ValueKey('cooldown'),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w,
                  vertical: AppSpacing.sm.h,
                ),
                decoration: BoxDecoration(
                  color: AppColor.neutral100,
                  borderRadius: AppRadii.rPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16.sp,
                      color: AppColor.textSecondary,
                    ),
                    gapH(AppSpacing.sm),
                    Text(
                      '${AppCopy.verifyResendIn} $countdown',
                      style: AppText.labelSm
                          .copyWith(color: AppColor.textSecondary),
                    ),
                  ],
                ),
              )
            : TextButton.icon(
                key: const ValueKey('resend'),
                onPressed: isResending ? null : onTap,
                icon: isResending
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColor.primary),
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        size: 18.sp,
                        color: AppColor.primary,
                      ),
                label: Text(
                  isResending ? AppCopy.loading : AppCopy.verifyResend,
                  style: AppText.labelMd.copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}
