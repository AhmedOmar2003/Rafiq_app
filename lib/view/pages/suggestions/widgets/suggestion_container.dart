import 'package:flutter/material.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CustomSuggestionContainer extends StatelessWidget {
  final SuggestionItemModel model;
  final VoidCallback onTap;

  const CustomSuggestionContainer({
    super.key,
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadii.rXl,
          color: AppColor.surfaceCard,
          boxShadow: AppShadows.level2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl.r)),
                  child: model.image.isNotEmpty
                      ? _buildImage(context, model.image)
                      : Container(
                          height: 220.h,
                          color: AppColor.neutral100,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 40.sp,
                            color: AppColor.textTertiary,
                          ),
                        ),
                ),
                // Rating Badge
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: AppRadii.rPill,
                      boxShadow: AppShadows.level1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 18.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          model.rate.toString(),
                          style: AppText.labelSm.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "(4.8)",
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Content Section
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.rMd,
                      color: model.color.withOpacity(0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppImage(
                          model.icon,
                          color: AppColor.white,
                          height: 18.h,
                          width: 18.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          model.suggestionText,
                          style: AppText.labelSm.copyWith(color: AppColor.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Title
                  Text(
                    model.text,
                    style: AppText.titleLg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  gapV(AppSpacing.md),
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: AppColor.primary, size: 20.sp),
                      gapH(AppSpacing.sm),
                      Expanded(
                        child: Text(
                          model.address,
                          style: AppText.bodyMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // Price Section
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("تبدأ من", style: AppText.bodySm),
                          gapV(AppSpacing.xs),
                          Text(
                            _formatPriceLabel(model.price),
                            style: AppText.titleMd.copyWith(
                              color: AppColor.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColor.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          color: AppColor.primary,
                          size: 22.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('//')) {
      return 'https:${Uri.encodeFull(trimmed)}';
    }

    if (trimmed.startsWith('www.')) {
      return 'https://${Uri.encodeFull(trimmed)}';
    }

    if (trimmed.startsWith('http://') && kIsWeb) {
      return Uri.encodeFull(trimmed.replaceFirst('http://', 'https://'));
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.encodeFull(trimmed);
    }

    return trimmed;
  }

  Widget _buildImage(BuildContext context, String imagePath) {
    final normalizedPath = _normalizeImageUrl(imagePath);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final targetCacheWidth = !kIsWeb
        ? (MediaQuery.sizeOf(context).width * devicePixelRatio).round()
        : null;
    final targetCacheHeight =
        !kIsWeb ? (220.h * devicePixelRatio).round() : null;

    if (!kIsWeb &&
        normalizedPath.isNotEmpty &&
        !normalizedPath.startsWith('http')) {
      return Image.file(
        File(normalizedPath),
        height: 220.h,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback();
        },
      );
    } else if (normalizedPath.startsWith('http')) {
      return Image.network(
        normalizedPath,
        height: 220.h,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        webHtmlElementStrategy: kIsWeb
            ? WebHtmlElementStrategy.prefer
            : WebHtmlElementStrategy.never,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 220.h,
            color: AppColor.neutral50,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        'assets/images/default_profile.png',
        height: 220.h,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
      );
    }
  }

  Widget _buildImageFallback() {
    return Container(
      height: 220.h,
      color: AppColor.neutral100,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 40.sp,
        color: AppColor.textTertiary,
      ),
    );
  }

  String _formatPriceLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return "غير محدد";
    }

    if (normalized.contains("جنيه") || normalized.contains("جنية")) {
      return normalized;
    }

    return "$normalized جنيه مصري";
  }
}
