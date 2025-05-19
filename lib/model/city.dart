import 'place.dart';

class City {
  final int cityId;
  final List<Place> places;

  City({required this.cityId, required this.places});

  // تحويل البيانات من JSON إلى Model
  factory City.fromJson(Map<String, dynamic> json) {
    var placesJson = json['Places'] as List;
    List<Place> placesList =
        placesJson.map((place) => Place.fromJson(place)).toList();
    return City(
      cityId: json['CityId'],
      places: placesList,
    );
  }
}
