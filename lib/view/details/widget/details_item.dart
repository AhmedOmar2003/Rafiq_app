import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_image.dart';
import '../../../core/design/cached_network_image.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
import '../../../models/suggestion_item_model/suggestion_item.dart';

class DetailsItem extends StatefulWidget {
  final SuggestionItemModel model;
  final List<String> galleryImages;
  final bool isLoading;

  const DetailsItem({
    super.key,
    required this.model,
    required this.galleryImages,
    required this.isLoading,
  });

  @override
  State<DetailsItem> createState() => _DetailsItemState();
}

class _DetailsItemState extends State<DetailsItem> {
  final PageController _galleryController = PageController();
  int _currentGalleryIndex = 0;

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetailsItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.galleryImages.length != widget.galleryImages.length &&
        _currentGalleryIndex >= widget.galleryImages.length) {
      _currentGalleryIndex = 0;
      if (_galleryController.hasClients) {
        _galleryController.jumpToPage(0);
      }
    }
  }

  void openMap() async {
    final String query = "${widget.model.address}, ${widget.model.text}";
    final Uri googleMapsUri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}");
    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(
          googleMapsUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint("Could not launch $googleMapsUri");
      }
    } catch (e) {
      debugPrint("Error launching map: $e");
    }
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

    if (trimmed.startsWith('http://')) {
      return Uri.encodeFull(trimmed.replaceFirst('http://', 'https://'));
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.encodeFull(trimmed);
    }

    return trimmed;
  }

  Widget _buildGalleryImage(BuildContext context, String rawUrl) {
    final normalized = _normalizeImageUrl(rawUrl);
    if (normalized.isEmpty) {
      return _buildPlaceholder();
    }

    if (normalized.startsWith('http')) {
      return CachedNetworkImage(
        url: normalized,
        fit: BoxFit.cover,
        placeholder: (_) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
          ),
        ),
        errorWidget: (_) => _buildPlaceholder(),
      );
    }

    if (!kIsWeb) {
      return Image.file(
        File(normalized),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final gallery = widget.galleryImages.isNotEmpty
        ? widget.galleryImages
        : <String>[widget.model.image];
    final hasGallery = gallery.length > 1;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          SizedBox(
            height: 240.h,
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _galleryController,
                      itemCount: gallery.length,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() => _currentGalleryIndex = index);
                      },
                      itemBuilder: (_, index) =>
                          _buildGalleryImage(context, gallery[index]),
                    ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 100.h,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColor.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Rating badge
                    Positioned(
                      top: 16.h,
                      right: 16.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColor.surfaceCard,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColor.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            horizontalSpace(4),
                            Text(
                              widget.model.rate.toString(),
                              style: TextStyleTheme.textStyle12Medium.copyWith(
                                color: AppColor.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (hasGallery)
                      Positioned(
                        left: 16.w,
                        top: 16.h,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceCard.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_currentGalleryIndex + 1}/${gallery.length}',
                            style: TextStyleTheme.textStyle12Medium.copyWith(
                              color: AppColor.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    if (widget.isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.12),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColor.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (hasGallery) ...[
            verticalSpace(12),
            SizedBox(
              height: 64.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, __) => horizontalSpace(8),
                itemBuilder: (context, index) {
                  final thumb = gallery[index];
                  final isActive = index == _currentGalleryIndex;
                  return GestureDetector(
                    onTap: () {
                      _galleryController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isActive ? AppColor.primary : AppColor.border,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13.r),
                        child: _buildGalleryImage(context, thumb),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          verticalSpace(20),

          // Category badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: model.color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: model.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppImage(
                  model.icon,
                  color: AppColor.white,
                  width: 20.w,
                  height: 20.h,
                ),
                horizontalSpace(8),
                Text(
                  model.suggestionText,
                  style: TextStyleTheme.textStyle16Medium.copyWith(
                    color: AppColor.surfaceCard,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),

          verticalSpace(16),

          // Title
          Text(
            model.text,
            style: TextStyleTheme.textStyle20Bold.copyWith(
              color: AppColor.textPrimary,
              height: 1.3,
              fontSize: 24.sp,
            ),
          ),

          verticalSpace(12),

          // Description
          Text(
            model.body.toString(),
            style: TextStyleTheme.textStyle16Medium.copyWith(
              color: AppColor.textSecondary,
              height: 1.6,
            ),
          ),

          verticalSpace(20),

          // Location section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColor.neutral50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColor.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppColor.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: AppColor.primary,
                        size: 20.sp,
                      ),
                    ),
                    horizontalSpace(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "الموقع",
                            style: TextStyleTheme.textStyle16Medium.copyWith(
                              color: AppColor.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                          verticalSpace(4),
                          Text(
                            model.address,
                            style: TextStyleTheme.textStyle16Medium.copyWith(
                              color: AppColor.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                verticalSpace(16),
                GestureDetector(
                  onTap: openMap,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColor.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        "عرض على الخريطة",
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: AppColor.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          verticalSpace(20),

          // Price section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColor.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "السعر يبدأ من",
                      style: TextStyleTheme.textStyle16Medium.copyWith(
                        color: AppColor.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                    verticalSpace(4),
                    Text(
                      _formatPriceLabel(model.price),
                      style: TextStyleTheme.textStyle20Bold.copyWith(
                        color: AppColor.primary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceCard,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16.sp,
                      ),
                      horizontalSpace(4),
                      Text(
                        "${model.rate} (4.1k)",
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: AppColor.textPrimary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColor.neutral200,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40.sp,
          color: AppColor.textTertiary,
        ),
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
