import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/home/home_view.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';
import 'package:rafiq_app/view/provider/hub/provider_hub_screen.dart';
import '../../../core/utils/app_microcopy.dart';
import '../../../core/utils/assets.dart';

/// A screen that allows users to choose between being a regular user or a service provider.
class ChoiceScreen extends StatefulWidget {
  /// Callback triggered when a regular user plan is selected
  final VoidCallback onPlanSelected;

  /// Callback triggered when a service provider plan is selected
  final VoidCallback onNoPlanSelected;

  /// Callback triggered when the next button is pressed
  final VoidCallback onNext;

  const ChoiceScreen({
    super.key,
    required this.onPlanSelected,
    required this.onNoPlanSelected,
    required this.onNext,
  });

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  /// Tracks which option is selected (0 for regular user, 1 for service provider)
  int? _selectedIndex;

  /// Navigate to the appropriate screen based on selection.
  ///
  /// Two states drive the provider track:
  ///   * **First visit** (`UserRoleStore.isProvider == false`)
  ///     → mark as provider → push the subscription onboarding → on plan
  ///       picked, push the Provider Hub.
  ///   * **Returning provider** (`UserRoleStore.isProvider == true`)
  ///     → skip onboarding entirely → push the Provider Hub directly.
  ///
  /// Regular user → mark as non-provider → HomeView.
  Future<void> _handleNavigation() async {
    if (_selectedIndex == null) {
      AppFeedback.warning(AppCopy.choicePickFirst);
      return;
    }

    if (_selectedIndex == 0) {
      await UserRoleStore.instance.chooseRegularUser();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeView()),
        (route) => false,
      );
    } else {
      final alreadyProvider = UserRoleStore.instance.isProvider.value;
      await UserRoleStore.instance.chooseProvider();
      if (!mounted) return;

      // Returning provider — go straight to the hub. Plan + places + every
      // setting they had already carries over via the SubscriptionService /
      // SharedPreferences persistence layers.
      if (alreadyProvider) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProviderHubScreen()),
          (route) => false,
        );
      } else {
        // First-time provider — onboarding funnel.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(
              onboarding: true,
              onPlanChosen: () {
                final navContext = navigatorKey.currentContext ?? context;
                Navigator.of(navContext, rootNavigator: true)
                    .pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const ProviderHubScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      }
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColor.ofWhite,
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColor.ofWhite,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          children: [
                            SizedBox(height: 80.h),
                            Container(
                              height: 220.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColor.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20.r),
                                child: Builder(
                                  builder: (context) {
                                    final dpr =
                                        MediaQuery.devicePixelRatioOf(context);
                                    return Image.asset(
                                      AppImages.choice,
                                      fit: BoxFit.contain,
                                      // Cap decoded size at the hero's visible
                                      // resolution × DPR. Otherwise a 4K asset
                                      // is decoded full-size into RAM.
                                      cacheHeight: (220 * dpr).round(),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 40.h),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 600),
                              tween: Tween(begin: 0, end: 1),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: Text(
                                      AppCopy.choiceQuestion,
                                      style: AppText.headingMd,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 30.h),
                            _buildOptionButton(
                              label: AppCopy.choiceRoleUser,
                              index: 0,
                              icon: Icons.person_outline_rounded,
                              onTap: () {
                                setState(() => _selectedIndex = 0);
                                widget.onPlanSelected();
                              },
                            ),
                            // The second card reacts to the persisted role
                            // flag: once a user has subscribed, this becomes
                            // the entry point to their service hub instead
                            // of a sign-up prompt.
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  UserRoleStore.instance.isProvider,
                              builder: (_, isProvider, __) {
                                return _buildOptionButton(
                                  label: isProvider
                                      ? AppCopy.choiceRoleProviderActive
                                      : AppCopy.choiceRoleProvider,
                                  index: 1,
                                  icon: isProvider
                                      ? Icons.storefront_rounded
                                      : Icons.store_rounded,
                                  onTap: () {
                                    setState(() => _selectedIndex = 1);
                                    widget.onNoPlanSelected();
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    decoration: BoxDecoration(
                      color: AppColor.ofWhite,
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AppButton(
                      text: AppCopy.next,
                      onPress: _handleNavigation,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required int index,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      builder: (context, value, child) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            splashColor: AppColor.primary.withValues(alpha: 0.1),
            highlightColor: AppColor.primary.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: Color.lerp(AppColor.white, AppColor.primary, value),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFF000000).withValues(alpha: 0.1),
                    AppColor.primary,
                    value,
                  )!,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColor.primary.withValues(alpha: 0.1)
                        : AppColor.black.withValues(alpha: 0.04),
                    blurRadius: isSelected ? 12 : 6,
                    offset: Offset(0, isSelected ? 4 : 2),
                    spreadRadius: isSelected ? 0.5 : 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColor.primary.withValues(alpha: 0.1),
                        AppColor.white.withValues(alpha: 0.2),
                        value,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color:
                          Color.lerp(AppColor.primary, AppColor.white, value),
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppText.titleLg.copyWith(
                            color: Color.lerp(
                                AppColor.textPrimary, AppColor.white, value),
                          ),
                        ),
                        gapV(AppSpacing.xs),
                        Text(
                          index == 0
                              ? AppCopy.choiceUserSubtitle
                              : (UserRoleStore.instance.isProvider.value
                                  ? AppCopy.choiceProviderActiveSubtitle
                                  : AppCopy.choiceProviderSubtitle),
                          style: AppText.bodyMd.copyWith(
                            color: Color.lerp(
                              AppColor.textSecondary,
                              AppColor.white.withValues(alpha: 0.8),
                              value,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color.lerp(AppColor.primary.withValues(alpha: 0.3),
                        AppColor.white, value),
                    size: 16.w,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
