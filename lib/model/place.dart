import 'package:rafiq_app/core/config/supabase_config.dart';

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
  final String? placeUuid;
  final String? providerId;
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

  /// Moderation state. Matches `public.moderation_status` SQL enum:
  /// `pending` | `under_review` | `approved` | `rejected` | `suspended`.
  /// Used by the provider
  /// hub to render the 24-hour review countdown card while the admin
  /// hasn't acted yet.
  final String status;

  /// When the place was created — anchor for the 24-hour review window.
  final DateTime? createdAt;

  /// Free-text reason set by the admin when [status] is `rejected`.
  final String? rejectionReason;

  /// True when the admin rejected this place but explicitly allowed the
  /// provider to edit and resubmit. Drives the "تعديل المكان" button on
  /// the rejected card; meaningless outside of `status == 'rejected'`.
  final bool editAllowed;

  final String editRequestStatus;
  final String? editRequestNote;
  final String? editRequestResponse;
  final DateTime? editRequestRequestedAt;
  final DateTime? editRequestReviewedAt;
  final DateTime? editSubmittedAt;

  Place({
    this.placeUuid,
    this.providerId,
    required this.name,
    required this.description,
    required this.priceRange,
    required this.budget,
    required this.rating,
    required this.placeAddress,
    this.imageUrl,
    required this.activityName,
    required this.cityName,
    required this.placeId,
    this.status = 'pending',
    this.createdAt,
    this.rejectionReason,
    this.editAllowed = false,
    this.editRequestStatus = 'none',
    this.editRequestNote,
    this.editRequestResponse,
    this.editRequestRequestedAt,
    this.editRequestReviewedAt,
    this.editSubmittedAt,
  });

  // تحويل البيانات من JSON
  factory Place.fromJson(Map<String, dynamic> json) {
    final imageValue = json['image_path'] ??
        json['image_url'] ??
        json['ImagePath'] ??
        json['ImageUrl'];

    return Place(
      placeUuid: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : (json['place_uuid']?.toString().trim().isNotEmpty == true
              ? json['place_uuid'].toString()
              : null),
      providerId: json['provider_id']?.toString().trim().isNotEmpty == true
          ? json['provider_id'].toString()
          : null,
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
      imageUrl: _normalizeImageReference(imageValue),
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
      status: () {
        final rawStatus = json['status'] ?? json['Status'];
        final normalized = rawStatus?.toString().trim().toLowerCase();
        if (normalized == null || normalized.isEmpty) {
          return 'pending';
        }
        return normalized;
      }(),
      createdAt: () {
        final raw =
            json['created_at'] ?? json['createdAt'] ?? json['CreatedAt'];
        if (raw == null) return null;
        return DateTime.tryParse(raw.toString());
      }(),
      rejectionReason: json['rejection_reason']?.toString() ??
          json['RejectionReason']?.toString(),
      editAllowed: (json['edit_allowed'] as bool?) ??
          (json['editAllowed'] as bool?) ??
          false,
      editRequestStatus:
          json['edit_request_status']?.toString().trim().toLowerCase() ??
              'none',
      editRequestNote: json['edit_request_note']?.toString(),
      editRequestResponse: json['edit_request_response']?.toString(),
      editRequestRequestedAt: DateTime.tryParse(
        json['edit_request_requested_at']?.toString() ?? '',
      ),
      editRequestReviewedAt: DateTime.tryParse(
        json['edit_request_reviewed_at']?.toString() ?? '',
      ),
      editSubmittedAt: DateTime.tryParse(
        json['edit_submitted_at']?.toString() ?? '',
      ),
    );
  }

  static String? _normalizeImageReference(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    const storageScheme = 'place-images://';
    if (raw.startsWith(storageScheme)) {
      final storagePath = raw.substring(storageScheme.length);
      if (storagePath.isEmpty) return null;
      final encodedPath =
          storagePath.split('/').map(Uri.encodeComponent).join('/');
      final baseUrl = SupabaseConfig.url.replaceFirst(RegExp(r'/+$'), '');
      return '$baseUrl/storage/v1/object/public/place-images/$encodedPath';
    }

    if (raw.startsWith('https://') || raw.startsWith('http://')) {
      return raw;
    }

    if (raw.startsWith('assets/')) {
      return raw;
    }

    // Device-local paths are previews only and are invalid on another device
    // or after the picker cache is cleared.
    return null;
  }
}
