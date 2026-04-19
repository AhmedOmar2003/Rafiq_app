import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
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
              "إعادة تعيين كلمة المرور",
              style: TextStyleTheme.textStyle20Medium.copyWith(
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
                          if (!keyboardOpen) ...[
                            Container(
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColor.primary.withOpacity(0.1),
                                    AppColor.primary.withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 32.sp,
                                color: AppColor.primary,
                              ),
                            ),
                            SizedBox(height: 14.h),
                          ],
                          Text(
                            "إنشاء كلمة مرور جديدة",
                            style: TextStyleTheme.textStyle20Medium.copyWith(
                              color: AppColor.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: keyboardOpen ? 6.h : 8.h),
                          Text(
                            currentEmail.isEmpty
                                ? "أدخل البيانات المطلوبة لإعادة تعيين كلمة المرور"
                                : (widget.requiresOtpVerification
                                    ? "أدخل كود التحقق المرسل إلى: $currentEmail"
                                    : currentEmail),
                            style: TextStyleTheme.textStyle16Regular.copyWith(
                              color: AppColor.black.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: keyboardOpen ? 14.h : 24.h),
                          if (widget.requiresOtpVerification) ...[
                            if (!keyboardOpen)
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: AppColor.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      color: AppColor.primary,
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    "كود التحقق (OTP)",
                                    style: TextStyleTheme.textStyle16Medium
                                        .copyWith(
                                      color: AppColor.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            if (!keyboardOpen) SizedBox(height: 10.h),
                            AppInput(
                              hintText: "ادخل كود التحقق (6 أرقام)",
                              controller: _otpController,
                              type: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              paddingBottom: keyboardOpen ? 10.h : 18.h,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "يرجى إدخال كود التحقق";
                                }
                                if (!RegExp(r'^\d{6}$')
                                    .hasMatch(value.trim())) {
                                  return "كود التحقق يجب أن يكون 6 أرقام";
                                }
                                return null;
                              },
                            ),
                          ],
                          if (!keyboardOpen)
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: AppColor.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: AppColor.primary,
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "كلمة المرور الجديدة",
                                  style:
                                      TextStyleTheme.textStyle16Medium.copyWith(
                                    color: AppColor.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (!keyboardOpen) SizedBox(height: 10.h),
                          AppInput(
                            hintText: "كلمة المرور الجديدة",
                            controller: _passwordController,
                            textInputAction: TextInputAction.next,
                            isPassword: true,
                            paddingBottom: keyboardOpen ? 10.h : 18.h,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "يرجى إدخال كلمة المرور";
                              }
                              if (!AuthService.isStrongPassword(value)) {
                                return "كلمة المرور يجب أن تكون قوية";
                              }
                              return null;
                            },
                          ),
                          if (!keyboardOpen)
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: AppColor.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle_outline,
                                    color: AppColor.primary,
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  "تأكيد كلمة المرور",
                                  style:
                                      TextStyleTheme.textStyle16Medium.copyWith(
                                    color: AppColor.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (!keyboardOpen) SizedBox(height: 10.h),
                          AppInput(
                            hintText: "تأكيد كلمة المرور",
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            isPassword: true,
                            paddingBottom: 0,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "يرجى تأكيد كلمة المرور";
                              }
                              if (value != _passwordController.text) {
                                return "كلمة المرور غير متطابقة";
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
                                      ? "تأكيد وتغيير كلمة المرور"
                                      : "حفظ"),
                              textStyle:
                                  TextStyleTheme.textStyle18Medium.copyWith(
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
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: 320.w,
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          color: AppColor.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColor.primary,
                          size: 50.sp,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        "تم تغيير كلمة المرور بنجاح",
                        style: TextStyleTheme.textStyle20Medium.copyWith(
                          color: AppColor.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        "يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة",
                        style: TextStyleTheme.textStyle16Regular.copyWith(
                          color: AppColor.black.withOpacity(0.7),
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _navigateToLogin,
                            borderRadius: BorderRadius.circular(12.r),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColor.primary,
                                    AppColor.primary.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Center(
                                child: Text(
                                  "تسجيل الدخول",
                                  style:
                                      TextStyleTheme.textStyle18Medium.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    decoration: TextDecoration.none,
                                    decorationColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
