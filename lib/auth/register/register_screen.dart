import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/security/password_policy.dart';
import 'package:rafiq_app/core/utils/app_error_formatter.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/auth/post_auth_router.dart';

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
  String _password = '';

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
      AppFeedback.error(AppErrorFormatter.userMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() => _isLoading = true);
    try {
      final completed = await AuthService().signUpWithGoogle();
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
            message: AppCopy.registerSuccess,
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

  Widget _buildRegisterForm() {
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
                AppCopy.registerTitle,
                style: AppText.displayMd.copyWith(
                    color: AppColor.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            gapV(AppSpacing.sm),
            Text(
              AppCopy.registerSubtitle,
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.xxl),
            _buildUsernameInput(),
            _buildEmailInput(),
            _buildPasswordInput(),
            _buildPasswordRules(),
            gapV(AppSpacing.lg),
            AppButton(
                text: AppCopy.registerCta,
                onPress: _handleRegister,
                isLoading: _isLoading),
            _OrDivider(),
            AppButton(
              text: AppCopy.registerGoogle,
              onPress: _handleGoogleRegister,
              isLoading: _isLoading,
              variant: AppButtonVariant.outline,
              icon: Icons.g_mobiledata_rounded,
            ),
            gapV(AppSpacing.xxl),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameInput() {
    return AppInput(
      label: AppCopy.registerNameLabel,
      hintText: AppCopy.registerNameHint,
      controller: userNameController,
      autofillHints: const [AutofillHints.name],
      suffixIcon: const Icon(Icons.person_outline_rounded,
          color: AppColor.textSecondary),
      textInputAction: TextInputAction.next,
      validator: (value) => (value == null || value.trim().isEmpty)
          ? AppCopy.fieldRequired
          : null,
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
      autofillHints: const [AutofillHints.newPassword],
      isPassword: true,
      type: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onChanged: (value) => setState(() => _password = value),
      onFieldSubmitted: (_) => _handleRegister(),
      validator: PasswordPolicy.validateNewPassword,
    );
  }

  Widget _buildPasswordRules() {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs.h, bottom: AppSpacing.sm.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PasswordRequirements(password: _password),
          if (_password.isNotEmpty) ...[
            gapV(AppSpacing.sm),
            Text(
              AppCopy.registerPasswordTip,
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs.w,
        runSpacing: AppSpacing.xs.h,
        children: [
          Text(
            AppCopy.registerHasAccountPrefix,
            style: AppText.bodyMd.copyWith(color: AppColor.textPrimary),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
            style: TextButton.styleFrom(
              minimumSize: Size(0, 44.h),
              foregroundColor: AppColor.primary700,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppCopy.registerGoToLogin,
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
