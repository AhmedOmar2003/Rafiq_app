import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/forget_password.dart';
import 'package:rafiq_app/auth/register/register_screen.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/app_input.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';

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
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
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
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColor.primary,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: _buildLogo(),
                      ),
                      Expanded(
                        child: _buildLoginForm(),
                      ),
                    ],
                  ),
                ),
              ],
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
      child: AppImage(
        AppImages.logo,
        height: 100.h,
        width: 180.w,
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.ofWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36.r),
          topRight: Radius.circular(36.r),
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(),
            SizedBox(height: 24.h),
            _buildEmailInput(),
            SizedBox(height: 16.h),
            _buildPasswordInput(),
            SizedBox(height: 12.h),
            _buildForgotPassword(),
            SizedBox(height: 32.h),
            _buildLoginButton(),
            SizedBox(height: 24.h),
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
        style: TextStyleTheme.textStyle35Medium.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColor.black,
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return AppInput(
      hintText: "ادخل البريد الالكتروني",
      controller: emailController,
      suffixIcon: const Icon(Icons.email_outlined, color: AppColor.black),
      textInputAction: TextInputAction.next,
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
        textStyle: TextStyleTheme.textStyle20Medium.copyWith(
          color: AppColor.white,
          fontWeight: FontWeight.bold,
        ),
        onPress: _isLoading ? () {} : _handleLogin,
        buttonStyle: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          minimumSize: Size(double.infinity, 56.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 4,
          shadowColor: AppColor.primary.withOpacity(0.4),
          disabledBackgroundColor: AppColor.primary.withOpacity(0.5),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24.h,
                width: 24.w,
                child: const CircularProgressIndicator(
                  color: AppColor.white,
                  strokeWidth: 2.5,
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
