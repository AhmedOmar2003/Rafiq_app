import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/service/auth_service.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      await AuthService().sendPasswordResetOtp(widget.email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة إرسال كود التحقق'),
          backgroundColor: Colors.green,
        ),
      );
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
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.primary,
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
            Padding(
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
                padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "تحقق من الكود",
                        style: TextStyleTheme.textStyle25Medium.copyWith(
                          color: AppColor.black,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        "أدخل كود التحقق المكوّن من 6 أرقام المرسل إلى:",
                        style: TextStyleTheme.textStyle16Regular.copyWith(
                          color: AppColor.black.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        widget.email,
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: AppColor.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 28.h),
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
                            inactiveColor: AppColor.primary.withOpacity(0.25),
                            activeColor: AppColor.primary,
                            selectedColor: AppColor.primary,
                            activeFillColor: AppColor.primary.withOpacity(0.04),
                            inactiveFillColor:
                                AppColor.primary.withOpacity(0.03),
                            selectedFillColor:
                                AppColor.primary.withOpacity(0.06),
                          ),
                          enableActiveFill: true,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "يرجى إدخال كود التحقق";
                            }
                            if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                              return "الكود يجب أن يكون 6 أرقام";
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 18.h),
                      AppButton(
                        text: _isVerifying ? "..." : "تأكيد الكود",
                        textStyle: TextStyleTheme.textStyle20Medium.copyWith(
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
                          shadowColor: AppColor.primary.withOpacity(0.4),
                          disabledBackgroundColor:
                              AppColor.primary.withOpacity(0.5),
                        ),
                        onPress: _isVerifying ? () {} : _verifyCode,
                      ),
                      SizedBox(height: 14.h),
                      TextButton(
                        onPressed: _isResending ? null : _resendCode,
                        child: Text(
                          _isResending
                              ? "جارٍ إعادة الإرسال..."
                              : "إعادة إرسال الكود",
                          style: TextStyleTheme.textStyle16Medium.copyWith(
                            color: AppColor.primary,
                          ),
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
    );
  }
}
