import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
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
    if (!formKey.currentState!.validate()) {
      return;
    }

    final normalizedEmail = emailController.text.trim().toLowerCase();

    setState(() => _isLoading = true);
    try {
      await AuthService().sendPasswordResetOtp(normalizedEmail);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال كود إعادة التعيين إلى بريدك الإلكتروني'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordPage(
            emailForOtpFlow: normalizedEmail,
            requiresOtpVerification: true,
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
        setState(() => _isLoading = false);
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
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
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
                          Icons.lock_reset_rounded,
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
                      padding: EdgeInsets.symmetric(
                          vertical: 32.h, horizontal: 24.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 16.h),
                          Text(
                            "نسيت كلمة المرور",
                            style: TextStyleTheme.textStyle25Medium.copyWith(
                              color: AppColor.black,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            "أدخل بريد Gmail وسنرسل لك كود OTP لإعادة التعيين",
                            style: TextStyleTheme.textStyle16Regular.copyWith(
                              color: AppColor.black.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32.h),
                          Form(
                            key: formKey,
                            child: AppInput(
                              hintText: "البريد الإلكتروني",
                              controller: emailController,
                              textInputAction: TextInputAction.done,
                              type: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "البريد الإلكتروني مطلوب";
                                }
                                if (!AuthService.isGmailEmail(value)) {
                                  return "يجب أن ينتهي البريد بـ @gmail.com";
                                }
                                return null;
                              },
                              suffixIcon: Icon(
                                Icons.email_outlined,
                                color: AppColor.primary,
                                size: 20.sp,
                              ),
                            ),
                          ),
                          SizedBox(height: 32.h),
                          AppButton(
                            text: _isLoading ? "..." : "إرسال الكود",
                            textStyle:
                                TextStyleTheme.textStyle20Medium.copyWith(
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
                            onPress: _isLoading ? () {} : _sendResetOtp,
                          ),
                          SizedBox(height: 24.h),
                          Center(
                            child: Text(
                              "بعد استلام الكود، أدخله في الشاشة التالية ثم اختر كلمة مرور جديدة.",
                              style: TextStyleTheme.textStyle14Regular.copyWith(
                                color: AppColor.black.withOpacity(0.6),
                              ),
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
