import 'package:flutter/material.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/model/place.dart';

class SuggestionItemModel {
  final String text;
  final String address;
  final String body;
  final String image;
  final String icon;
  final String suggestionText;
  final String price;
  final double rate;
  final Color color;
  final String city;
  final int placeId;

  SuggestionItemModel({
    required this.text,
    required this.address,
    required this.body,
    required this.image,
    required this.icon,
    required this.suggestionText,
    required this.price,
    required this.rate,
    required this.color,
    required this.city,
    required this.placeId,
  });

  factory SuggestionItemModel.fromPlace(Place place) {
    return SuggestionItemModel(
      text: place.name,
      address: place.placeAddress,
      body: place.description,
      image: place.imageUrl ?? AppImages.activities,
      icon: _mapCategoryToIcon(place.activityName),
      suggestionText: place.activityName,
      price: place.priceRange,
      rate: place.rating,
      color: _mapCategoryToColor(place.activityName),
      city: place.cityName,
      placeId: place.placeId,
    );
  }

  // دالة لتحويل price إلى double وإرجاع القيمة الأكبر في حالة النطاق
  double getPrice() {
    if (price == 'غير محدد' || price.isEmpty) {
      return 0.0;
    }
    if (price.contains('-')) {
      final parts = price.split('-');
      final minPrice = double.tryParse(parts[0].trim()) ?? 0.0;
      final maxPrice = double.tryParse(parts[1].trim()) ?? minPrice;
      return maxPrice; // إرجاع القيمة الأكبر بدلاً من المتوسط
    }
    return double.tryParse(price) ?? 0.0; // إرجاع القيمة المفردة
  }

  static String _mapCategoryToIcon(String description) {
    switch (description.toLowerCase()) {
      case "ترفيه":
        return AppImages.entertainment;
      case "رياضة":
        return AppImages.ball;
      case "طعام":
        return AppImages.eating;
      case "سياحي":
        return AppImages.dollar;
      default:
        return AppImages.activities;
    }
  }

  static Color _mapCategoryToColor(String description) {
    switch (description.toLowerCase()) {
      case "ترفيه":
        return const Color(0xff0434C3);
      case "رياضة":
        return const Color(0xffB7280F);
      case "طعام":
        return const Color(0xffF29339);
      case "سياحي":
        return const Color.fromARGB(255, 221, 48, 4);
      default:
        return Colors.grey;
    }
  }
}
