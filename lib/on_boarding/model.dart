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
    text: "محتار ؟\nهنساعدك في الاختيار",
    image: AppImages.onboarding1,
  ),
  OnBoardingModel(
    text: "هتلاقي مجموعة\nمتنوعة من الاختيارات",
    body: "اي مكان بتدور عليه هتلاقي المناسب\n ليك سواء داخل او خارج المدينة",
    image: AppImages.onboarding2,
  ),
  OnBoardingModel(
    text: "اكتشف الان الاماكن التي\n تناسب حالتك المزاجية و\n المادية",
    image: AppImages.onboarding3,
  ),
];
