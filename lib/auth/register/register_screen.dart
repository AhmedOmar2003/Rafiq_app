import 'dart:convert'; // لتحويل النصوص من وإلى JSON
import 'package:http/http.dart' as http; // مكتبة HTTP
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/config/api_config.dart';
import '../../core/design/app_button.dart';
import '../../core/design/app_image.dart';
import '../../core/design/app_input.dart';
import '../../core/design/title_text.dart';
import '../../core/utils/app_color.dart';
import '../../core/utils/assets.dart';
import '../../core/utils/spacing.dart';
import '../../core/utils/text_style_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final userNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showSuccessOverlay = false;

  @override
  void dispose() {
    userNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSuccess() {
    setState(() {
      _showSuccessOverlay = true;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await registerUser();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> registerUser() async {
    final body = {
      "name": userNameController.text.trim(),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
    };

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerUrl),
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        await fetchUserData();
        _showSuccess();
      } else {
        _showSnackBar(result['message'] ?? 'حدث خطأ في التسجيل', isError: true);
      }
    } on http.ClientException {
      _showSnackBar('تعذر الاتصال بالخادم', isError: true);
    } catch (e) {
      _showSnackBar('حدث خطأ غير متوقع', isError: true);
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
          _showSnackBar('المستخدم غير موجود', isError: true);
        }
      } else {
        _showSnackBar('خطأ في الخادم: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnackBar('تعذر الاتصال بالخادم', isError: true);
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', int.parse(user['userId']));
    await prefs.setString('userName', user['name']);
    await prefs.setString('userEmail', user['email']);
  }

  void _navigateToLoginScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
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
                  _buildRegisterForm(),
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
                _navigateToLoginScreen();
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
                          "مرحباً بك في رفيق!",
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
                          "تم إنشاء حسابك بنجاح",
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
                            _navigateToLoginScreen();
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

  Widget _buildRegisterForm() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 50.h, horizontal: 30.w),
      width: double.infinity,
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
          shrinkWrap: true,
          children: [
            _buildTitle(),
            verticalSpace(30),
            _buildUsernameInput(),
            _buildEmailInput(),
            _buildPasswordInput(),
            verticalSpace(50),
            _buildRegisterButton(),
            verticalSpace(30),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Center(
      child: CustomTextWidget(
        label: "إنشاء حساب",
        style: TextStyleTheme.textStyle35Medium,
      ),
    );
  }

  Widget _buildUsernameInput() {
    return AppInput(
      hintText: "اسم المستخدم",
      controller: userNameController,
      suffixIcon: const Icon(Icons.person_outlined, color: AppColor.black),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "اسم المستخدم مطلوب";
        }
        return null;
      },
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

  Widget _buildRegisterButton() {
    return Center(
      child: AppButton(
        text: _isLoading ? "" : "تسجيل",
        textStyle: TextStyleTheme.textStyle25Medium.copyWith(
          color: AppColor.white,
        ),
        onPress: _isLoading ? () {} : _handleRegister,
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

  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "بالفعل لديك حساب؟ ",
              style: TextStyleTheme.textStyle15Regular.copyWith(
                color: AppColor.black,
              ),
            ),
            TextSpan(
              text: "تسجيل الدخول",
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
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
