import '../core/utils/app_microcopy.dart';
import '../core/utils/assets.dart';

class OnBoardingModel {
  final String text;
  final String? body;
  final String image;

  OnBoardingModel({
    required this.text,
    this.body,
    required this.image,
  });
}

List<OnBoardingModel> onBoardingList = [
  OnBoardingModel(
    text: AppCopy.onboardingTitle1,
    image: AppImages.onboarding1,
  ),
  OnBoardingModel(
    text: AppCopy.onboardingTitle2,
    body: AppCopy.onboardingBody2,
    image: AppImages.onboarding2,
  ),
  OnBoardingModel(
    text: AppCopy.onboardingTitle3,
    image: AppImages.onboarding3,
  ),
];
