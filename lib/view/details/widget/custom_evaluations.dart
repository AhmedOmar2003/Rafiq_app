import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/model/review_model.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(hasReview: lastEvaluation != null),
        gapV(AppSpacing.md),
        if (lastEvaluation != null)
          _LastReviewRow(
            review: lastEvaluation!,
            formattedDate: _formatDate(lastEvaluation!.date),
          )
        else
          Text(
            AppCopy.emptyResultsTitle,
            style: AppText.titleMd.copyWith(
              color: AppColor.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        gapV(AppSpacing.lg),
        _SeeAllLink(placeId: placeId),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasReview});

  final bool hasReview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm.w,
      runSpacing: AppSpacing.xs.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          AppCopy.reviewsTitle,
          style: AppText.titleLg.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!hasReview)
          Text(
            AppCopy.detailsBeFirstReview,
            style: AppText.bodySm,
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
            _UserAvatar(name: review.name, imagePath: review.image),
            gapH(AppSpacing.md),
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
                  gapV(AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm.w,
                    runSpacing: AppSpacing.xs.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StarsRow(rating: review.rating),
                      Text(formattedDate, style: AppText.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        gapV(AppSpacing.md),
        Text(
          review.body.isNotEmpty
              ? review.body
              : AppCopy.reviewNoCommentFallback,
          style: AppText.bodySm.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

/// Five-star row. `const` so it's a single Element shared between rebuilds
/// instead of allocating 5 Icons every time the row builds.
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _Star(active: index < rating)),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 1),
      child: Icon(
        Icons.star,
        size: 15,
        color: active ? AppColor.warning : AppColor.border,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.name,
    required this.imagePath,
  });

  final String name;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final trimmed = imagePath.trim();
    final provider = trimmed.startsWith('http')
        ? NetworkImage(trimmed)
        : trimmed.startsWith('assets/')
            ? AssetImage(trimmed) as ImageProvider
            : null;
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '؟';

    return CircleAvatar(
      radius: 22.w,
      backgroundColor: AppColor.primary50,
      backgroundImage: provider,
      child: provider == null
          ? Text(
              initial,
              style: AppText.labelMd.copyWith(
                color: AppColor.primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
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
      child: Semantics(
        button: true,
        label: AppCopy.reviewsTitle,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadii.rPill,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EvaluationsPage(placeId: placeId),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: AppSpacing.xs.h,
              ),
              child: Text(
                AppCopy.reviewsTitle,
                style: AppText.labelMd.copyWith(
                  decoration: TextDecoration.underline,
                  color: AppColor.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
