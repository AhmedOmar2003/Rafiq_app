class EvaluationsItemModel {
  final int? reviewId;
  final int placeId;
  final String name;
  final String body;
  final String date;
  final String image;
  final int rating;

  EvaluationsItemModel({
    this.reviewId,
    required this.placeId,
    required this.name,
    required this.body,
    required this.date,
    required this.image,
    required this.rating,
  });

  factory EvaluationsItemModel.fromJson(Map<String, dynamic> json) {
    return EvaluationsItemModel(
      reviewId: json['review_id'] != null
          ? int.tryParse(json['review_id'].toString())
          : null,
      placeId: json['place_id'] != null
          ? int.tryParse(json['place_id'].toString()) ?? 0
          : 0,
      name: json['name']?.toString() ?? '',
      body: json['review_text']?.toString() ?? '',
      date: json['created_at']?.toString() ?? '',
      image: (json['image']?.toString().isNotEmpty == true)
          ? json['image'].toString()
          : "assets/images/default_profile.webp",
      rating: json['rating'] != null
          ? int.tryParse(json['rating'].toString()) ?? 5
          : 5,
    );
  }
}
