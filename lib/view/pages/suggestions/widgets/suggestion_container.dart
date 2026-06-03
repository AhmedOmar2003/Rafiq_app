import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/cached_network_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';

/// Suggestion card — simple, readable, and close to the design system.
class CustomSuggestionContainer extends StatelessWidget {
  const CustomSuggestionContainer({
    super.key,
    required this.model,
    required this.onTap,
  });

  final SuggestionItemModel model;
  final VoidCallback onTap;

  static const double _heroHeight = 176;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Semantics(
        button: true,
        label: 'افتح ${model.text}',
        hint: '${model.suggestionText} - ${model.address}',
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          elevation: 1,
          radius: AppRadii.rLg,
          child: ClipRRect(
            borderRadius: AppRadii.rLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(image: model.image, rating: model.rate),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryPill(
                        label: model.suggestionText,
                        icon: model.icon,
                        color: model.color,
                      ),
                      gapV(AppSpacing.md),
                      Text(
                        model.text,
                        style: AppText.titleLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      gapV(AppSpacing.sm),
                      Text(
                        model.body,
                        style: AppText.bodySm.copyWith(
                          color: AppColor.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      gapV(AppSpacing.sm),
                      _AddressRow(address: model.address),
                      gapV(AppSpacing.md),
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
}

// ---------------------------------------------------------------------------
// Hero image with floating rating chip
// ---------------------------------------------------------------------------
class _Hero extends StatelessWidget {
  const _Hero({required this.image, required this.rating});

  final String image;
  final dynamic rating;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: CustomSuggestionContainer._heroHeight.h,
          child: _SmartImage(path: image),
        ),
        Positioned(
          top: AppSpacing.md.h,
          right: AppSpacing.md.w,
          child: _RatingChip(rating: rating),
        ),
      ],
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
        color: color.withValues(alpha: 0.92),
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
          size: 20.sp,
        ),
        gapH(AppSpacing.sm),
        Expanded(
          child: Text(
            address,
            style: AppText.bodyMd,
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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppCopy.priceStartsFrom, style: AppText.bodySm),
              gapV(AppSpacing.xs),
              Text(
                _formatPrice(price),
                style: AppText.titleMd.copyWith(
                  color: AppColor.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: AppColor.primary50,
            borderRadius: AppRadii.rPill,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: AppColor.primary,
            size: 18.sp,
          ),
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
