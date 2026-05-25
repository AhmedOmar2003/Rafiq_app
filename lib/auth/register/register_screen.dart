import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';

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

  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signUp(
        name: userNameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) return;
      setState(() => _showSuccessOverlay = true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHomeScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ChoiceScreen(
          onPlanSelected: () {},
          onNoPlanSelected: () {},
          onNext: () {},
        ),
      ),
      (route) => false,
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
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
                        child: _buildLogo(),
                      ),
                      Expanded(child: _buildRegisterForm()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSuccessOverlay)
          AppSuccessView(
            title: AppCopy.successGeneric,
            message: 'تم إنشاء حسابك بنجاح',
            imageAsset: AppImages.loginSuccess,
            onContinue: () {
              setState(() => _showSuccessOverlay = false);
              _navigateToHomeScreen();
            },
          ),
      ],
    );
  }

  Widget _buildLogo() {
    return Center(child: AppImage(AppImages.logo, height: 100.h, width: 180.w));
  }

  Widget _buildRegisterForm() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl.h, horizontal: AppSpacing.xxl.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'إنشاء حساب',
                style: AppText.displayMd.copyWith(color: AppColor.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            gapV(AppSpacing.xxl),
            _buildUsernameInput(),
            _buildEmailInput(),
            _buildPasswordInput(),
            _buildPasswordRules(),
            gapV(AppSpacing.lg),
            AppButton(text: 'تسجيل', onPress: _handleRegister, isLoading: _isLoading),
            gapV(AppSpacing.xxl),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameInput() {
    return AppInput(
      hintText: 'اسم المستخدم',
      controller: userNameController,
      suffixIcon: const Icon(Icons.person_outline_rounded, color: AppColor.textSecondary),
      textInputAction: TextInputAction.next,
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? AppCopy.fieldRequired : null,
    );
  }

  Widget _buildEmailInput() {
    return AppInput(
      hintText: 'البريد الإلكتروني',
      controller: emailController,
      suffixIcon: const Icon(Icons.email_outlined, color: AppColor.textSecondary),
      textInputAction: TextInputAction.next,
      type: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) return AppCopy.fieldRequired;
        if (!AuthService.isGmailEmail(value)) return AppCopy.emailGmailOnly;
        return null;
      },
    );
  }

  Widget _buildPasswordInput() {
    return AppInput(
      hintText: 'كلمة المرور',
      controller: passwordController,
      isPassword: true,
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (value == null || value.isEmpty) return AppCopy.passwordRequired;
        if (!AuthService.isStrongPassword(value)) return AppCopy.passwordShort;
        return null;
      },
    );
  }

  Widget _buildPasswordRules() {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs.h, bottom: AppSpacing.sm.h),
      child: Text(AuthService.passwordRequirementMessage(), style: AppText.bodySm),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: 'بالفعل لديك حساب؟ ', style: AppText.bodyMd.copyWith(color: AppColor.textPrimary)),
            TextSpan(
              text: 'تسجيل الدخول',
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
              style: AppText.labelMd.copyWith(color: AppColor.primary),
            ),
          ],
        ),
      ),
    );
  }
}
