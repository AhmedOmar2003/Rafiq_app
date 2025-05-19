import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
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

  void _navigateToLogin() {
    navigateTo(const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
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
      padding: EdgeInsets.only(
        top: 71.h,
        bottom: 58.h,
        left: 15.w,
        right: 15.w,
      ),
      child: Column(
        children: [
          Expanded(
            child: AppImage(
              model.image,
              height: 360.h,
              width: 360.h,
            ),
          ),
          verticalSpace(30),
          CustomTextWidget(
            textAlign: TextAlign.center,
            label: model.text,
            style: TextStyleTheme.textStyle30Medium,
          ),
          verticalSpace(16),
          CustomTextWidget(
            textAlign: TextAlign.center,
            label: model.body ?? "",
            style: TextStyleTheme.textStyle20Regular,
          ),
          verticalSpace(90),
          isLastPage ? _buildLastPageControls() : _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildLastPageControls() {
    return Column(
      children: [
        AppButton(
          text: "يلا نبدا",
          textStyle: TextStyleTheme.textStyle25Medium.copyWith(
            color: AppColor.white,
          ),
          onPress: onLoginPressed,
        ),
        verticalSpace(70),
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
          child: CustomTextWidget(
            label: "التالي",
            style: TextStyleTheme.textStyle25Medium,
          ),
        ),
        const Spacer(),
        _buildPageIndicator(),
        const Spacer(),
        TextButton(
          onPressed: onLoginPressed,
          child: CustomTextWidget(
            label: "تخطي",
            style: TextStyleTheme.textStyle25Medium,
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return SmoothPageIndicator(
      controller: pageController,
      count: onBoardingList.length,
      effect: ExpandingDotsEffect(
        dotColor: AppColor.primary.withOpacity(.15),
        dotHeight: 10.h,
        dotWidth: 10.h,
        expansionFactor: 4,
        spacing: 5.0,
        activeDotColor: AppColor.primary,
      ),
    );
  }
}
