import 'package:rafiq_app/core/utils/assets.dart';

/// A model class representing a suggestion item with text, icon and possible answers
class SuggestionModel {
  final String text;
  final String icon;
  final List<String> answer;

  const SuggestionModel({
    required this.answer,
    required this.text,
    required this.icon,
  });
}

/// A list of predefined suggestions for the app
final List<SuggestionModel> suggestionList = [
  SuggestionModel(
    text: "النشاط",
    icon: AppImages.activitie,
    answer: [
      "ترفيه",
      "طعام",
      "سياحي",
      "فعايات ثقافية",
    ],
  ),
  SuggestionModel(
    text: "المكان",
    icon: AppImages.mapPin,
    answer: [
      "القاهرة",
      "الإسكندرية",
      "المنصورة",
      "طنطا",
    ],
  ),
  SuggestionModel(
    text: "الميزانية",
    icon: AppImages.money,
    answer: [
      "أقل من 100 جنيه",
      "100 إلى 500 جنيه",
      "500 إلى 1000 جنيه",
      "1000 إلى 1500 جنيه",
    ],
  ),
];
