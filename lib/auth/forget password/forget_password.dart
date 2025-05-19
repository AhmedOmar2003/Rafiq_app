import 'dart:convert'; // لتحويل النصوص من وإلى JSON
import 'package:http/http.dart' as http; // مكتبة HTTP
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/vriefy_code_page.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/core/config/api_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>(); // لتخزين حالة النموذج
  final emailController = TextEditingController();

  // الدالة لإعادة تعيين كلمة المرور
  Future<void> resetPassword() async {
    final String url = "${ApiConfig.baseUrl}/forgot_password.php";
    final body = {
      "email": emailController.text.trim(),
    };

    try {
      final response = await http.post(Uri.parse(url), body: body);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // تأكد من أن النتيجة تحتوي على حالة success ورمز التحقق otp_code
        if (result['status'] == 'success' && result['otp'] != null) {
          // تمرير البريد الإلكتروني ورمز التحقق (otpCode) إلى صفحة VerifyCodeScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyCodeScreen(
                email: emailController.text.trim(), // تمرير البريد الإلكتروني
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'حدث خطأ غير معروف')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ في الخادم: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذر الاتصال بالخادم.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.ofWhite,
      appBar: AppBar(
        backgroundColor: AppColor.ofWhite,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(right: 12.w), // لضبط المسافة للسهم
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context); // العودة إلى صفحة تسجيل الدخول
            },
            child: Icon(
              Icons.arrow_back_ios_new,
              color: AppColor.black,
              size: 24.sp,
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 80.0),
          child: Text(
            "نسيت كلمة المرور؟",
            style: TextStyleTheme.textStyle25Medium.copyWith(
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "أدخل بريدك الإلكتروني لإعادة التعيين",
                style: TextStyleTheme.textStyle16Regular.copyWith(
                  color: AppColor.black.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 40.h),
              Form(
                key: formKey,
                child: Container(
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
                    children: [
                      AppInput(
                        hintText: "البريد الإلكتروني",
                        controller: emailController,
                        textInputAction: TextInputAction.done,
                        type: TextInputType.emailAddress,
                        paddingBottom: 16.h,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !RegExp(r'^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z0-9]+')
                                  .hasMatch(value)) {
                            return "بريدك الالكتروني غير صحيح";
                          }
                          return null;
                        },
                        suffixIcon: Icon(
                          Icons.email_outlined,
                          color: AppColor.primary,
                          size: 24.sp,
                        ),
                      ),
                    ],
                  ),
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
                  text: "التالي",
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
                  onPress: () {
                    if (formKey.currentState != null &&
                        formKey.currentState!.validate()) {
                      resetPassword();
                    }
                  },
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
