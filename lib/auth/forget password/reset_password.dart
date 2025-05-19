import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/config/api_config.dart';
import 'package:rafiq_app/core/utils/assets.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otpCode;

  ResetPasswordPage({Key? key, required this.email, required this.otpCode})
      : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isProcessing = false;
  bool _showSuccessOverlay = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSuccess() {
    setState(() {
      _showSuccessOverlay = true;
    });
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    final url = '${ApiConfig.baseUrl}/reset_password.php';
    final body = {
      'email': widget.email.trim(),
      'otp_code': widget.otpCode.trim(),
      'new_password': _passwordController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        _showSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "حدث خطأ غير متوقع"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("حدث خطأ أثناء الاتصال بالخادم"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColor.ofWhite,
          appBar: AppBar(
            backgroundColor: AppColor.ofWhite,
            elevation: 0,
            leading: Padding(
              padding: EdgeInsets.only(right: 12.w), // إضافة padding للسهم من اليمين
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context); // العودة إلى الصفحة السابقة
                },
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColor.black,
                  size: 24.sp,
                ),
              ),
            ),
            title: const Padding(
              padding: EdgeInsets.only(left: 15),
              child: Text(
                "كلمة المرور",
                style: TextStyle(fontSize: 24, color: Colors.black),
              ),
            ),
          ),
          //centerTitle: true,

          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "كلمة المرور",
                      style: TextStyleTheme.textStyle25Medium.copyWith(
                        color: AppColor.black,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "يجب أن تكون ٦ أحرف على الأقل",
                      style: TextStyleTheme.textStyle16Regular.copyWith(
                        color: AppColor.black.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 40.h),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColor.ofWhite,
                        borderRadius: BorderRadius.circular(15.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: AppColor.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "كلمة المرور",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColor.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          AppInput(
                            hintText: "كلمة المرور",
                            controller: _passwordController,
                            textInputAction: TextInputAction.next,
                            isPassword: true,
                            paddingBottom: 24.h,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "يرجى إدخال كلمة المرور";
                              } else if (value.length < 6) {
                                return "يجب أن تكون كلمة المرور على الأقل 6 أحرف";
                              }
                              return null;
                            },
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColor.primary,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "تأكيد",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColor.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          AppInput(
                            hintText: "تأكيد",
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                            isPassword: true,
                            paddingBottom: 16.h,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "يرجى تأكيد كلمة المرور";
                              } else if (value != _passwordController.text) {
                                return "كلمة المرور غير متطابقة";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      height: 55.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColor.primary,
                            AppColor.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColor.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: AppButton(
                        text: _isProcessing ? "..." : "حفظ",
                        textStyle: TextStyleTheme.textStyle25Medium.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        buttonStyle: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPress: _isProcessing
                            ? () {}
                            : () {
                                if (_formKey.currentState != null &&
                                    _formKey.currentState!.validate()) {
                                  updatePassword();
                                }
                              },
                        child: _isProcessing
                            ? SizedBox(
                                height: 24.h,
                                width: 24.w,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),
          // زر حفظ في أسفل الصفحة
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
                  decoration: TextDecoration.none, // إزالة الخط التحتي
                  decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                "يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة",
                style: TextStyleTheme.textStyle16Regular.copyWith(
                  color: AppColor.black.withOpacity(0.7),
                  decoration: TextDecoration.none, // إزالة الخط التحتي
                  decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              Container(
                width: double.infinity,
                height: 50.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColor.primary,
                      AppColor.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColor.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToLogin,
                    borderRadius: BorderRadius.circular(12.r),
                    child: Center(
                      child: Text(
                        "تسجيل الدخول",
                        style: TextStyleTheme.textStyle18Medium.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.5,
                          decoration: TextDecoration.none, // إزالة الخط التحتي
                          decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
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
