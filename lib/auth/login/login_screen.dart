import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/forget%20password/forget_password.dart';
import 'package:rafiq_app/auth/register/register_screen.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_error_formatter.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/auth/post_auth_router.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final message = await AuthService().takePendingAuthMessage();
      if (!mounted || message == null || message.isEmpty) return;
      AppFeedback.error(message);
    });
  }

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
      AppFeedback.error(AppErrorFormatter.userMessage(e));
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
      AppFeedback.error(AppErrorFormatter.userMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterAuth() => PostAuthRouter.replaceWithHome(context);

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
            onContinue: () async {
              setState(() => _showSuccessOverlay = false);
              await _navigateAfterAuth();
            },
          ),
      ],
    );
  }

  Widget _buildLogo() {
    return ExcludeSemantics(
      child: Center(
        child: AppImage(AppImages.logo, height: 100.h, width: 180.w),
      ),
    );
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
            gapV(AppSpacing.sm),
            Text(
              AppCopy.loginSubtitle,
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
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
            _OrDivider(),
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
      autofillHints: const [AutofillHints.username, AutofillHints.email],
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
      helperText: AppCopy.authPasswordHelper,
      autofillHints: const [AutofillHints.password],
      isPassword: true,
      type: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      validator: (value) =>
          (value == null || value.isEmpty) ? AppCopy.passwordRequired : null,
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => navigateTo(const ForgotPasswordScreen()),
        style: TextButton.styleFrom(
          minimumSize: Size(0, 44.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xs.w,
            vertical: AppSpacing.xs.h,
          ),
          foregroundColor: AppColor.primary700,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          AppCopy.authForgotPasswordLink,
          style: AppText.labelMd.copyWith(
            color: AppColor.primary700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs.w,
        runSpacing: AppSpacing.xs.h,
        children: [
          Text(
            AppCopy.loginNoAccountPrefix,
            style: AppText.bodyMd.copyWith(color: AppColor.textPrimary),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            ),
            style: TextButton.styleFrom(
              minimumSize: Size(0, 44.h),
              foregroundColor: AppColor.primary700,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppCopy.loginGoToRegister,
              style: AppText.labelMd.copyWith(
                color: AppColor.primary700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColor.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Text(
              AppCopy.authSeparatorOr,
              style: AppText.labelSm.copyWith(color: AppColor.textTertiary),
            ),
          ),
          const Expanded(child: Divider(color: AppColor.border)),
        ],
      ),
    );
  }
}
