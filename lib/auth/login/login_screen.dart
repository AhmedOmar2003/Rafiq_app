import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rafiq_app/auth/forget%20password/forget_password.dart';
import 'package:rafiq_app/auth/register/register_screen.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showSuccessOverlay = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await loginUser();
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    setState(() {
      _showSuccessOverlay = true;
    });
  }

  void _navigateToChoiceScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChoiceScreen(
          onPlanSelected: () {},
          onNoPlanSelected: () {},
          onNext: () {},
        ),
      ),
    );
  }

  Future<void> loginUser() async {
    final body = {
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
    };

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        await fetchUserData();
        _showSuccess();
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('البريد الإلكتروني أو كلمة المرور غير صحيحة')),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المستخدم غير موجود')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'حدث خطأ في تسجيل الدخول')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالخادم')),
      );
    }
  }

  Future<void> fetchUserData() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getUserUrl),
        body: {"email": emailController.text.trim()},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final user = result['users'].firstWhere(
          (user) => user['email'] == emailController.text.trim(),
          orElse: () => null,
        );

        if (user != null) {
          await _saveUserData(user);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المستخدم غير موجود')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الخادم: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الاتصال بالخادم')),
      );
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', int.parse(user['userId']));
    await prefs.setString('userName', user['name']);
    await prefs.setString('userEmail', user['email']);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColor.primary,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildLogo(),
                  verticalSpace(70),
                  _buildLoginForm(),
                ],
              ),
            ),
          ),
        ),
        if (_showSuccessOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showSuccessOverlay = false;
                });
                _navigateToChoiceScreen();
              },
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
                        Image.asset(
                          AppImages.loginSuccess,
                          width: 150.w,
                          height: 150.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          "مرحباً بعودتك!",
                          style: TextStyleTheme.textStyle25Medium.copyWith(
                            color: AppColor.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          "تم تسجيل دخولك بنجاح",
                          style: TextStyleTheme.textStyle16Regular.copyWith(
                            color: AppColor.black.withOpacity(0.7),
                            decoration: TextDecoration.none,
                            decorationColor: Colors.transparent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24.h),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSuccessOverlay = false;
                            });
                            _navigateToChoiceScreen();
                          },
                          icon: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppColor.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColor.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 28.w,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: AppImage(
          AppImages.logo,
          height: 140.h,
          width: 240.w,
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 50.h, horizontal: 30.w),
      height: 538.h,
      width: double.infinity.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30.r),
          topLeft: Radius.circular(30.r),
        ),
        color: AppColor.ofWhite,
      ),
      child: Form(
        key: formKey,
        child: ListView(
          children: [
            _buildTitle(),
            verticalSpace(30),
            _buildEmailInput(),
            _buildPasswordInput(),
            _buildForgotPassword(),
            verticalSpace(50),
            _buildLoginButton(),
            verticalSpace(30),
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Center(
      child: CustomTextWidget(
        label: "تسجيل الدخول",
        style: TextStyleTheme.textStyle35Medium,
      ),
    );
  }

  Widget _buildEmailInput() {
    return AppInput(
      hintText: "ادخل البريد الالكتروني",
      controller: emailController,
      suffixIcon: const Icon(Icons.email_outlined, color: AppColor.black),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "البريد الإلكتروني مطلوب";
        }
        return null;
      },
    );
  }

  Widget _buildPasswordInput() {
    return AppInput(
      hintText: "كلمة المرور",
      controller: passwordController,
      isPassword: true,
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "كلمة المرور مطلوبة";
        }
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return GestureDetector(
      onTap: () => navigateTo(const ForgotPasswordScreen()),
      child: CustomTextWidget(
        label: "هل نسيت كلمة المرور؟",
        style: TextStyleTheme.textStyle15Medium,
      ),
    );
  }

  Widget _buildLoginButton() {
    return Center(
      child: AppButton(
        text: _isLoading ? "" : "تسجيل الدخول",
        textStyle: TextStyleTheme.textStyle25Medium.copyWith(
          color: AppColor.white,
        ),
        onPress: _isLoading ? () {} : () => _handleLogin(),
        buttonStyle: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          disabledBackgroundColor: AppColor.primary.withOpacity(0.5),
        ),
        child: _isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: const CircularProgressIndicator(
                  color: AppColor.white,
                  strokeWidth: 2,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "ليس لديك حساب؟ ",
              style: TextStyleTheme.textStyle15Regular.copyWith(
                color: AppColor.black,
              ),
            ),
            TextSpan(
              text: "سجل الآن",
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
              style: TextStyleTheme.textStyle15Regular.copyWith(
                color: AppColor.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
