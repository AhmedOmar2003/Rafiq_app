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
    final imageValue = json['image_path'] ??
        json['image_url'] ??
        json['ImagePath'] ??
        json['ImageUrl'];

    return Place(
      name: json['PlaceName']?.toString() ??
          json['place_name']?.toString() ??
          json['name']?.toString() ??
          'غير معروف',
      description: json['Description']?.toString() ??
          json['description']?.toString() ??
          'لا يوجد وصف متاح',
      priceRange: json['PriceRange']?.toString() ??
          json['price_range']?.toString() ??
          json['budget']?.toString() ??
          'غير محدد',
      budget: json['budget']?.toString() ??
          json['PriceRange']?.toString() ??
          json['price_range']?.toString() ??
          'غير محدد',
      rating: (json['Rating'] ?? json['rating'] ?? 0).toDouble(),
      placeAddress: json['PlaceAddress']?.toString() ??
          json['place_address']?.toString() ??
          'لا يوجد عنوان',
      imageUrl: imageValue?.toString().isNotEmpty == true
          ? imageValue.toString()
          : null,
      activityName: json['ActivityName']?.toString() ??
          json['activity_name']?.toString() ??
          'غير معروف',
      cityName: json['CityName']?.toString() ??
          json['city_name']?.toString() ??
          'غير معروفة',
      placeId: () {
        final placeIdValue = json['PlaceID'] ?? json['place_id'] ?? json['id'];
        if (placeIdValue is num) {
          return placeIdValue.toInt();
        }
        return int.tryParse(placeIdValue?.toString() ?? '0') ?? 0;
      }(),
    );
  }
}
