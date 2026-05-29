import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import '../../../core/utils/spacing.dart';
import '../../evaluations/evaluations_page.dart';

/// Last-review preview embedded on the place details screen.
///
/// PERFORMANCE NOTES:
///   * No more `File.existsSync()` / `base64Decode()` in `build()` — the
///     old `userImage` String path forced both. The avatar now reads from
///     [ProfileImageStore], which decoded once (off-isolate) at startup.
///   * No more `print()` in the build path.
///   * Star icons are `const` so the 5-icon row is reused across rebuilds.
class CustomEvaluations extends StatelessWidget {
  const CustomEvaluations({
    super.key,
    required this.placeId,
    this.lastEvaluation,
    @Deprecated('Avatar now reads from ProfileImageStore.') this.userImage,
  });

  final int placeId;
  final EvaluationsItemModel? lastEvaluation;
  final String? userImage;

  static String _formatDate(String? date) {
    if (date == null || date.isEmpty) return AppCopy.reviewDateUnknown;
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
    } catch (_) {
      return AppCopy.reviewDateUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 358.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(),
          verticalSpace(16),
          if (lastEvaluation != null)
            _LastReviewRow(
              review: lastEvaluation!,
              formattedDate: _formatDate(lastEvaluation!.date),
            )
          else
            Text(
              AppCopy.emptyResultsTitle,
              style: AppText.titleMd.copyWith(
                color: AppColor.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          verticalSpace(20),
          _SeeAllLink(placeId: placeId),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(AppCopy.reviewsTitle, style: AppText.titleLg),
            horizontalSpace(5),
            Text(AppCopy.detailsBeFirstReview, style: AppText.bodySm),
          ],
        ),
      ],
    );
  }
}

class _LastReviewRow extends StatelessWidget {
  const _LastReviewRow({required this.review, required this.formattedDate});

  final EvaluationsItemModel review;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _UserAvatar(),
            horizontalSpace(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.name,
                    style: AppText.titleMd.copyWith(color: AppColor.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  verticalSpace(3),
                  Row(
                    children: [
                      const _StarsRow(),
                      horizontalSpace(8.w),
                      Text(formattedDate, style: AppText.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        verticalSpace(17),
        Text(review.body, style: AppText.bodySm),
      ],
    );
  }
}

/// Five-star row. `const` so it's a single Element shared between rebuilds
/// instead of allocating 5 Icons every time the row builds.
class _StarsRow extends StatelessWidget {
  const _StarsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Star(),
        _Star(),
        _Star(),
        _Star(),
        _Star(),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star();

  @override
  Widget build(BuildContext context) {
    // Use a brand-warm amber via the warning token rather than Colors.yellow.
    return const Padding(
      padding: EdgeInsetsDirectional.only(start: 1),
      child: Icon(Icons.star, size: 15, color: AppColor.warning),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProfileImageState>(
      valueListenable: ProfileImageStore.instance,
      builder: (_, snap, __) {
        final ImageProvider? provider = snap.bytes != null
            ? MemoryImage(snap.bytes!)
            : snap.file != null
                ? FileImage(snap.file!)
                : null;

        if (provider == null) {
          return CircleAvatar(
            radius: 20.w,
            backgroundColor: AppColor.primary50,
            child: Icon(Icons.person, color: AppColor.primary, size: 22.sp),
          );
        }
        return CircleAvatar(radius: 20.w, backgroundImage: provider);
      },
    );
  }
}

class _SeeAllLink extends StatelessWidget {
  const _SeeAllLink({required this.placeId});
  final int placeId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EvaluationsPage(placeId: placeId),
          ),
        ),
        child: Text(
          AppCopy.reviewsTitle,
          style: AppText.titleLg.copyWith(
            decoration: TextDecoration.underline,
            color: AppColor.black,
          ),
        ),
      ),
    );
  }
}
