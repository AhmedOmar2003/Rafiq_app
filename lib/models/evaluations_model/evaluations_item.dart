import '../../core/utils/assets.dart';

class EvaluationsItemModel {
  final String image, name, date, body;

  EvaluationsItemModel({
    required this.image,
    required this.name,
    required this.date,
    required this.body,
  });
}

List<EvaluationsItemModel> evaluationsItemList = [
  EvaluationsItemModel(
    image: AppImages.bird,
    name: "عصفور الجنة",
    date: "27/11/2020",
    body: "حفلة أسطورية بكل معنى الكلمة! صوت أنغام كان مليئًا بالإحساس وأخذنا في رحلة رائعة بين أغانيها الكلاسيكية والجديدة. الأجواء كانت ساحرة، والتنظيم كان ممتازًا. تجربة فنية لا تُنسى وأتمنى تكرارها قريبًا!",
  ),
  EvaluationsItemModel(
    image: AppImages.bird,
    name: "محمد أحمد",
    date: "29/1/2023",
    body: "التنظيم كان سئ  و الزحمة كانت كبيرة جدا و مقدرتش استمتع بالحفل زي ما توقعت.",
  ),
  EvaluationsItemModel(
    image: AppImages.bird,
    name: "مريم أحمد",
    date: "24/8/2023",
    body: "حفلة لا تنسي, انغام قدمت كل اغانيها المميزة باحساس لا يوصف , و استمعت بكل لحظة.",
  ),
  EvaluationsItemModel(
    image: AppImages.bird,
    name: "هند سُليمان",
    date: "20/5/2023",
    body: "حفلات انغام دائما ما تكون استثنائية ! الاداء الموسيقي الرئع و الاجواء الراقية و اغاني الالبوم الجديد و لا اروع من كدة .",
  ),
  EvaluationsItemModel(
    image: AppImages.bird,
    name: "يونس يزن",
    date: "30/11/2023",
    body: "من اوحش الحفلات اللي حضرتها في حياتي تنظيم صفر و اداء انغام مكنش في افضل حال .",
  ),
];
