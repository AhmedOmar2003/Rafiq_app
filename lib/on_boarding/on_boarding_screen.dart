import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/on_boarding/cashe_helper.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'model.dart';

/// A screen that displays onboarding content to introduce users to the app.
/// It shows a series of pages with images and text, allowing users to navigate
/// through them or skip to the login screen.
class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int index) {
    setState(() {
      _isLastPage = index == onBoardingList.length - 1;
    });
  }

  Future<void> _navigateToLogin() async {
    await CacheHelper.setOnBoardingSeen(true);
    navigateTo(const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView.builder(
          itemCount: onBoardingList.length,
          controller: _pageController,
          onPageChanged: _handlePageChanged,
          itemBuilder: (context, index) {
            return _OnBoardingItem(
              model: onBoardingList[index],
              pageController: _pageController,
              isLastPage: _isLastPage,
              onLoginPressed: _navigateToLogin,
            );
          },
        ),
      ),
    );
  }
}

/// A widget that displays a single onboarding page with its content and navigation controls.
class _OnBoardingItem extends StatelessWidget {
  final OnBoardingModel model;
  final PageController pageController;
  final bool isLastPage;
  final VoidCallback onLoginPressed;

  const _OnBoardingItem({
    required this.model,
    required this.pageController,
    required this.isLastPage,
    required this.onLoginPressed,
  });

  void _handleNextPage() {
    pageController.nextPage(
      duration: const Duration(milliseconds: 750),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 24.h,
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: AppImage(
              model.image,
            ),
          ),
          gapV(AppSpacing.xxxl),
          Text(
            model.text,
            textAlign: TextAlign.center,
            style: AppText.displayMd,
          ),
          gapV(AppSpacing.lg),
          Text(
            model.body ?? "",
            textAlign: TextAlign.center,
            style: AppText.headingSm.copyWith(fontWeight: FontWeight.w400),
          ),
          const Spacer(flex: 2),
          isLastPage ? _buildLastPageControls() : _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildLastPageControls() {
    return Column(
      children: [
        AppButton(text: "يلا نبدا", onPress: onLoginPressed),
        gapV(AppSpacing.huge),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildNavigationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _handleNextPage,
          child: Text("التالي", style: AppText.headingLg),
        ),
        const Spacer(),
        _buildPageIndicator(),
        const Spacer(),
        TextButton(
          onPressed: onLoginPressed,
          child: Text("تخطي",
              style: AppText.headingLg.copyWith(color: AppColor.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return SmoothPageIndicator(
      controller: pageController,
      count: onBoardingList.length,
      effect: ExpandingDotsEffect(
        dotColor: AppColor.primary.withValues(alpha: .15),
        dotHeight: 10.h,
        dotWidth: 10.h,
        expansionFactor: 4,
        spacing: 5.0,
        activeDotColor: AppColor.primary,
      ),
    );
  }
}
