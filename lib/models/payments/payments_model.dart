import 'package:rafiq_app/core/utils/assets.dart';

class PaymentsModel {
  final String text, icon;

  PaymentsModel({
    required this.text,
    required this.icon,
  });
}

List<PaymentsModel> paymentsList = [
  PaymentsModel(
    text: "ڤيزا",
    icon: AppImages.visa,
  ),
  PaymentsModel(
    text: "ميزة",
    icon: AppImages.miza,
  ),
  PaymentsModel(
    text: "ماستر كارد",
    icon: AppImages.masterCard,
  ),
  PaymentsModel(
    text: "ڤودافون كاش",
    icon: AppImages.vodafone,
  ),
  PaymentsModel(
    text: "اتصالات كاش",
    icon: AppImages.etisalat,
  ),
  PaymentsModel(
    text: "أورنچ  كاش",
    icon: AppImages.orange,
  ),
  PaymentsModel(
    text: "انستا باى",
    icon: AppImages.instaPay,
  ),
];
