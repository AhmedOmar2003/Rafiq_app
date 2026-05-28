import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/forget_password.dart';
import 'package:rafiq_app/auth/register/register_screen.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/core/utils/assets.dart';
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
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(
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

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final completed = await AuthService().signInWithGoogle();
      if (!mounted || !completed) return;
      setState(() => _showSuccessOverlay = true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
                        child: _buildLogo(),
                      ),
                      Expanded(child: _buildLoginForm()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showSuccessOverlay)
          AppSuccessView(
            title: AppCopy.welcomeBack,
            message: AppCopy.loginSuccess,
            imageAsset: AppImages.loginSuccess,
            onContinue: () {
              setState(() => _showSuccessOverlay = false);
              _navigateToChoiceScreen();
            },
          ),
      ],
    );
  }

  Widget _buildLogo() {
    return Center(child: AppImage(AppImages.logo, height: 100.h, width: 180.w));
  }

  Widget _buildLoginForm() {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: AppSpacing.xxxl.h, horizontal: AppSpacing.xxl.w),
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
                AppCopy.loginTitle,
                style: AppText.displayMd.copyWith(
                    color: AppColor.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            gapV(AppSpacing.xxl),
            _buildEmailInput(),
            _buildPasswordInput(),
            _buildForgotPassword(),
            gapV(AppSpacing.xl),
            AppButton(
                text: AppCopy.loginCta,
                onPress: _handleLogin,
                isLoading: _isLoading),
            gapV(AppSpacing.lg),
            AppButton(
              text: AppCopy.loginGoogle,
              onPress: _handleGoogleLogin,
              isLoading: _isLoading,
              variant: AppButtonVariant.outline,
              icon: Icons.g_mobiledata_rounded,
            ),
            gapV(AppSpacing.xxl),
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return AppInput(
      label: AppCopy.authEmailLabel,
      hintText: AppCopy.authEmailHint,
      controller: emailController,
      suffixIcon:
          const Icon(Icons.email_outlined, color: AppColor.textSecondary),
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
      label: AppCopy.authPasswordLabel,
      hintText: AppCopy.authPasswordHint,
      controller: passwordController,
      isPassword: true,
      textInputAction: TextInputAction.done,
      validator: (value) =>
          (value == null || value.isEmpty) ? AppCopy.passwordRequired : null,
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GestureDetector(
        onTap: () => navigateTo(const ForgotPasswordScreen()),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          child: Text(AppCopy.authForgotPasswordLink,
              style: AppText.labelMd.copyWith(color: AppColor.primary)),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
                text: AppCopy.loginNoAccountPrefix,
                style: AppText.bodyMd.copyWith(color: AppColor.textPrimary)),
            TextSpan(
              text: AppCopy.loginGoToRegister,
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()),
                    ),
              style: AppText.labelMd.copyWith(color: AppColor.primary),
            ),
          ],
        ),
      ),
    );
  }
}
