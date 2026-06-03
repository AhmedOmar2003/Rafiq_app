import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_image.dart';
import '../../../core/design/cached_network_image.dart';
import '../../../core/design/tokens/tokens.dart';
import '../../../core/utils/spacing.dart';
import '../../../models/suggestion_item_model/suggestion_item.dart';

class DetailsItem extends StatefulWidget {
  final SuggestionItemModel model;
  final List<String> galleryImages;
  final bool isLoading;
  final VoidCallback? onMapOpen;

  const DetailsItem({
    super.key,
    required this.model,
    required this.galleryImages,
    required this.isLoading,
    this.onMapOpen,
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
    widget.onMapOpen?.call();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220.h,
          width: double.infinity,
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
                Positioned(
                  top: 16.h,
                  right: 16.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColor.warning,
                          size: 16,
                        ),
                        horizontalSpace(4),
                        Text(
                          widget.model.rate > 0
                              ? widget.model.rate.toString()
                              : 'جديد',
                          style: AppText.labelSm.copyWith(
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
                        color: AppColor.surfaceCard.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_currentGalleryIndex + 1}/${gallery.length}',
                        style: AppText.labelSm.copyWith(
                          color: AppColor.textPrimary,
                        ),
                      ),
                    ),
                  ),
                if (widget.isLoading)
                  Positioned.fill(
                    child: Container(
                      color: AppColor.black.withValues(alpha: 0.10),
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
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w,
            AppSpacing.lg.h,
            AppSpacing.lg.w,
            AppSpacing.lg.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasGallery) ...[
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
                              color:
                                  isActive ? AppColor.primary : AppColor.border,
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
                verticalSpace(20),
              ],
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: model.color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12.r),
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
                      style: AppText.labelMd.copyWith(
                        color: AppColor.surfaceCard,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(16),
              Text(
                model.text,
                style: AppText.headingMd.copyWith(
                  color: AppColor.textPrimary,
                  height: 1.3,
                ),
              ),
              verticalSpace(12),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _MetaChip(
                    icon: Icons.place_outlined,
                    label: model.city.isNotEmpty ? model.city : model.address,
                  ),
                  _MetaChip(
                    icon: Icons.category_outlined,
                    label: model.suggestionText,
                  ),
                ],
              ),
              verticalSpace(20),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColor.surfaceVariant,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColor.border),
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
                                style: AppText.labelSm.copyWith(
                                  color: AppColor.textSecondary,
                                ),
                              ),
                              verticalSpace(4),
                              Text(
                                model.address,
                                style: AppText.bodyMd.copyWith(
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
                          color: AppColor.surfaceCard,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: AppColor.primary),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: AppColor.primary,
                              size: 18.sp,
                            ),
                            horizontalSpace(8),
                            Text(
                              "عرض على الخريطة",
                              style: AppText.labelMd.copyWith(
                                color: AppColor.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(20),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColor.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColor.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "السعر يبدأ من",
                          style: AppText.labelSm.copyWith(
                            color: AppColor.textSecondary,
                          ),
                        ),
                        verticalSpace(4),
                        Text(
                          _formatPriceLabel(model.price),
                          style: AppText.titleLg.copyWith(
                            color: AppColor.primary,
                            fontWeight: FontWeight.w700,
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
                            Icons.star_rounded,
                            color: AppColor.warning,
                            size: 16.sp,
                          ),
                          horizontalSpace(4),
                          Text(
                            model.rate > 0 ? "${model.rate}" : 'جديد',
                            style: AppText.labelMd.copyWith(
                              color: AppColor.textPrimary,
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
        ),
      ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColor.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColor.textSecondary),
          horizontalSpace(6),
          Text(
            label,
            style: AppText.labelSm.copyWith(
              color: AppColor.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
