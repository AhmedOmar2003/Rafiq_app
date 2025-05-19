import 'package:rafiq_app/core/utils/assets.dart';

class StepThreeModel {
  final String text;
  final String? icon;

  StepThreeModel({
    required this.text,
    this.icon,
  });
}

List<StepThreeModel> stepThreeList = [
  StepThreeModel(text: "طعام", icon: AppImages.eating),
  StepThreeModel(text: "ترفيه", icon: AppImages.entertaiment),
  StepThreeModel(text: "سياحي", icon: AppImages.activities),
  StepThreeModel(text: "رياضة", icon: AppImages.sports),
  StepThreeModel(text: "فاجئني", icon: AppImages.surprise),
];
