import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/model/place.dart';

void main() {
  test('Place parses the approved edit-request workflow fields', () {
    final place = Place.fromJson({
      'id': '8d560949-5d0e-4d17-9b35-4308f1637f8c',
      'place_id': 42,
      'provider_id': 'e0b458db-68db-44bc-91ad-c546ac7fbfa8',
      'place_name': 'مكان تجريبي',
      'description': 'وصف',
      'price_range': '100 إلى 500 جنيه',
      'budget': '100 إلى 500 جنيه',
      'rating': 4.5,
      'place_address': 'الإسكندرية',
      'activity_name': 'طعام',
      'city_name': 'الإسكندرية',
      'status': 'approved',
      'edit_allowed': true,
      'edit_request_status': 'approved',
      'edit_request_note': 'تحديث الصور',
      'edit_request_response': 'اتفتح التعديل',
      'edit_request_requested_at': '2026-06-07T08:00:00Z',
      'edit_request_reviewed_at': '2026-06-07T09:00:00Z',
      'edit_submitted_at': null,
    });

    expect(place.status, 'approved');
    expect(place.editAllowed, isTrue);
    expect(place.editRequestStatus, 'approved');
    expect(place.editRequestNote, 'تحديث الصور');
    expect(place.editRequestResponse, 'اتفتح التعديل');
    expect(place.editRequestRequestedAt, isNotNull);
    expect(place.editRequestReviewedAt, isNotNull);
    expect(place.editSubmittedAt, isNull);
  });
}
