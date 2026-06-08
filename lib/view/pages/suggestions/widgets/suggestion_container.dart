import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/models/subscription/plan.dart';

/// Suggestion card — simple, readable, and close to the design system.
class CustomSuggestionContainer extends StatelessWidget {
  const CustomSuggestionContainer({
    super.key,
    required this.model,
    required this.onTap,
  });

  final SuggestionItemModel model;
  final VoidCallback onTap;

  static const double _heroHeight = 204;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Semantics(
        button: true,
        label: '${AppCopy.placeOpenPrefix} ${model.text}',
        hint: '${model.suggestionText} - ${model.address}',
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          elevation: model.planTier == PlanTier.max ? 2 : 1,
          radius: AppRadii.rXl,
          border: _planBorder(model.planTier),
          child: ClipRRect(
            borderRadius: AppRadii.rXl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(model: model),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg.w,
                    AppSpacing.md.h,
                    AppSpacing.lg.w,
                    AppSpacing.lg.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.text,
                        style: AppText.titleLg.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      gapV(AppSpacing.xs),
                      Text(
                        model.body,
                        style: AppText.bodySm.copyWith(
                          color: AppColor.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      gapV(AppSpacing.sm),
                      _AddressRow(address: model.address),
                      gapV(AppSpacing.sm),
                      const Divider(height: 1, thickness: 1),
                      gapV(AppSpacing.sm),
                      _PriceRow(price: model.price),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxBorder? _planBorder(PlanTier? tier) {
    return switch (tier) {
      PlanTier.pro => Border.all(
          color: AppColor.primary.withValues(alpha: 0.24),
          width: 1.2,
        ),
      PlanTier.max => Border.all(
          color: AppColor.primary700.withValues(alpha: 0.36),
          width: 1.4,
        ),
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// Hero image with floating rating chip
// ---------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  const _Hero({required this.model});

  final SuggestionItemModel model;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: CustomSuggestionContainer._heroHeight.h,
          child: _SmartImage(path: model.image),
        ),
        // Subtle gradient so the rating chip is readable on any image
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.28),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: AppSpacing.md.h,
          right: AppSpacing.md.w,
          child: _RatingChip(rating: model.rate),
        ),
        if (model.planTier == PlanTier.pro || model.planTier == PlanTier.max)
          Positioned(
            top: AppSpacing.md.h,
            left: AppSpacing.md.w,
            child: _FeedPlanBadge(tier: model.planTier!),
          ),
        Positioned(
          right: AppSpacing.md.w,
          bottom: AppSpacing.md.h,
          child: _CategoryPill(
            label: model.suggestionText,
            icon: model.icon,
            color: model.color,
          ),
        ),
      ],
    );
  }
}

class _FeedPlanBadge extends StatelessWidget {
  const _FeedPlanBadge({required this.tier});

  final PlanTier tier;

  @override
  Widget build(BuildContext context) {
    final isMax = tier == PlanTier.max;
    return Semantics(
      label:
          isMax ? AppCopy.placePlanMaxSemantic : AppCopy.placePlanProSemantic,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w,
          vertical: AppSpacing.xs.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.surfaceCard.withValues(alpha: 0.94),
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: isMax
                ? AppColor.primary700.withValues(alpha: 0.32)
                : AppColor.primary.withValues(alpha: 0.24),
          ),
          boxShadow: AppShadows.level1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMax
                  ? Icons.workspace_premium_rounded
                  : Icons.auto_awesome_rounded,
              size: 15.sp,
              color: isMax ? AppColor.primary700 : AppColor.primary,
            ),
            gapH(AppSpacing.xs),
            Text(
              isMax ? AppCopy.placePlanMax : AppCopy.placePlanPro,
              style: AppText.labelSm.copyWith(
                color: isMax ? AppColor.primary700 : AppColor.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final dynamic rating;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null && rating.toString().isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rPill,
        boxShadow: AppShadows.level1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: AppColor.warning, size: 18.sp),
          gapH(AppSpacing.xs),
          Text(
            hasRating ? rating.toString() : AppCopy.ratingFallback,
            style: AppText.labelSm.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category pill
// ---------------------------------------------------------------------------
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadii.rMd,
        color: color.withValues(alpha: 0.94),
        boxShadow: AppShadows.level1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppImage(icon, color: AppColor.white, height: 18.h, width: 18.w),
          gapH(AppSpacing.sm),
          Text(label, style: AppText.labelSm.copyWith(color: AppColor.white)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Address row
// ---------------------------------------------------------------------------
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          color: AppColor.primary,
          size: 16.sp,
        ),
        gapH(AppSpacing.xs),
        Expanded(
          child: Text(
            address,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Price row + forward affordance
// ---------------------------------------------------------------------------
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price});

  final String price;

  String _formatPrice(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return AppCopy.priceUnspecified;
    if (value.contains('جنيه') || value.contains('جنية')) return value;
    return '$value ${AppCopy.currencyEgp}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.priceStartsFrom,
                style: AppText.caption.copyWith(color: AppColor.textSecondary),
              ),
              gapV(AppSpacing.xs / 2),
              Text(
                _formatPrice(price),
                style: AppText.titleMd.copyWith(
                  color: AppColor.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_left_rounded,
          color: AppColor.primary,
          size: 22.sp,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image loader — handles file / network / asset / fallback with one widget.
// ---------------------------------------------------------------------------
class _SmartImage extends StatelessWidget {
  const _SmartImage({required this.path});

  final String path;

  static String _normalize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('//')) return 'https:${Uri.encodeFull(t)}';
    if (t.startsWith('www.')) return 'https://${Uri.encodeFull(t)}';
    if (t.startsWith('http://') && kIsWeb) {
      return Uri.encodeFull(t.replaceFirst('http://', 'https://'));
    }
    if (t.startsWith('http://') || t.startsWith('https://')) {
      return Uri.encodeFull(t);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalize(path);
    if (normalized.isEmpty) return const _ImageFallback();

    // Remote image → goes through the persistent disk cache. This is the
    // hot path for the suggestions feed and the biggest perf win: scrolling
    // back and forth no longer redownloads, and second-launch is offline-fast.
    if (normalized.startsWith('http')) {
      return CachedNetworkImage(
        url: normalized,
        width: double.infinity,
        height: CustomSuggestionContainer._heroHeight.h,
        fit: BoxFit.cover,
        placeholder: (_) => const _ImageLoadingPlaceholder(),
        errorWidget: (_) => const _ImageFallback(),
      );
    }

    if (!kIsWeb) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round();
      final cacheHeight =
          (CustomSuggestionContainer._heroHeight.h * dpr).round();
      return Image.file(
        File(normalized),
        height: CustomSuggestionContainer._heroHeight.h,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      );
    }

    return const _ImageFallback();
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: CustomSuggestionContainer._heroHeight.h,
      width: double.infinity,
      color: AppColor.neutral100,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40.sp,
        color: AppColor.textTertiary,
      ),
    );
  }
}

/// Indeterminate placeholder shown while the disk cache resolves / downloads.
/// No progress fraction because [CachedNetworkImage] uses `http.get` (not
/// streamed), so a percentage would just freeze at 0 then snap to 100.
class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: CustomSuggestionContainer._heroHeight.h,
      color: AppColor.neutral50,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
        ),
      ),
    );
  }
}
