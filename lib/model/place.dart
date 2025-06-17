// class Place {
//   final String name;
//   final String description;
//   final String priceRange;
//   final double rating;
//   final String placeAddress;
//   final String? imageUrl; // مسموح بالقيم null

//   Place({
//     required this.name,
//     required this.description,
//     required this.priceRange,
//     required this.rating,
//     required this.placeAddress,
//     this.imageUrl, // غير مطلوب
//   });

//   factory Place.fromJson(Map<String, dynamic> json) {
//     return Place(
//       name: json['PlaceName'] ?? '',
//       description: json['Description'] ?? '',
//       priceRange: json['PriceRange'] ?? '',
//       rating: (json['Rating'] ?? 0).toDouble(),
//       placeAddress: json['PlaceAddress'] ?? '',
//       imageUrl: json['image_path'], // يمكن أن تكون null
//     );
//   }
// }

class Place {
  final String name;
  final String description;
  final String priceRange; // حقل السعر
  final String budget; // الميزانية
  final double rating;
  final String placeAddress;
  final String? imageUrl;
  final String activityName;
  final String cityName;
  final int placeId;

  Place(
      {required this.name,
      required this.description,
      required this.priceRange,
      required this.budget,
      required this.rating,
      required this.placeAddress,
      this.imageUrl,
      required this.activityName,
      required this.cityName,
      required this.placeId});

  // تحويل البيانات من JSON
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['PlaceName']?.toString() ?? 'غير معروف',
      description: json['Description']?.toString() ?? 'لا يوجد وصف متاح',
      priceRange: json['PriceRange']?.toString() ?? 'غير محدد',
      budget: json['budget']?.toString() ?? 'غير محدد',
      rating: (json['Rating'] is num ? json['Rating'] : 0).toDouble(),
      placeAddress: json['PlaceAddress']?.toString() ?? 'لا يوجد عنوان',
      imageUrl: json['image_path']?.toString(),
      activityName: json['ActivityName']?.toString() ?? 'غير معروف',
      cityName: json['CityName']?.toString() ?? 'غير معروفة',
      placeId: json['PlaceID'],
    );
  }
}
