class EvaluationsItemModel {
  final int placeId;
  final String name;
  final String body;
  final String date;
  final String image;

  EvaluationsItemModel({
    required this.placeId,
    required this.name,
    required this.body,
    required this.date,
    required this.image,
  });

  factory EvaluationsItemModel.fromJson(Map<String, dynamic> json) {
    return EvaluationsItemModel(
      placeId: json['place_id'] != null
          ? int.tryParse(json['place_id'].toString()) ?? 0
          : 0,
      name: json['name'] ?? '',
      body: json['review_text'] ?? '',
      date: json['created_at'] ?? '',
      image: "assets/user_placeholder.png", // صورة افتراضية
    );
  }
}
