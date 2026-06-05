import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_image.dart';
import '../../../core/design/cached_network_image.dart';
import '../../../core/design/components/components.dart';
import '../../../core/design/tokens/tokens.dart';
import '../../../core/utils/app_microcopy.dart';
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
      }
    } catch (_) {
      // Map launch failed silently — user stays in-app.
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
    return Semantics(
      container: true,
      label:
          '${model.text}. ${model.city.isNotEmpty ? model.city : model.address}. السعر ${_formatPriceLabel(model.price)}.',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220.h,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: AppRadii.rXl,
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
                  top: AppSpacing.md.h,
                  right: AppSpacing.md.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: AppRadii.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColor.warning,
                          size: 16,
                        ),
                        gapH(AppSpacing.xs),
                        Text(
                          widget.model.rate > 0
                              ? widget.model.rate.toString()
                              : AppCopy.ratingFallback,
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
                    left: AppSpacing.md.w,
                    top: AppSpacing.md.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w,
                        vertical: AppSpacing.xs.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surfaceCard.withValues(alpha: 0.92),
                        borderRadius: AppRadii.rPill,
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
                    separatorBuilder: (_, __) => gapH(AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final thumb = gallery[index];
                      final isActive = index == _currentGalleryIndex;
                      return Semantics(
                        button: true,
                        selected: isActive,
                        label: 'صورة ${index + 1} من ${gallery.length}',
                        child: GestureDetector(
                          onTap: () {
                            _galleryController.animateToPage(
                              index,
                              duration: AppMotion.base,
                              curve: AppMotion.standard,
                            );
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 64.w,
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.rMd,
                              border: Border.all(
                                color: isActive
                                    ? AppColor.primary
                                    : AppColor.border,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: AppRadii.rMd,
                              child: _buildGalleryImage(context, thumb),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                gapV(AppSpacing.xl),
              ],
              _TypeBadge(model: model),
              gapV(AppSpacing.lg),
              Text(
                model.text,
                style: AppText.headingMd.copyWith(
                  color: AppColor.textPrimary,
                  height: 1.3,
                ),
              ),
              gapV(AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm.w,
                runSpacing: AppSpacing.sm.h,
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
              gapV(AppSpacing.xl),
              _LocationCard(
                address: model.address,
                onOpenMap: openMap,
              ),
              gapV(AppSpacing.xl),
              _PriceCard(
                priceLabel: _formatPriceLabel(model.price),
                rateLabel: model.rate > 0 ? "${model.rate}" : AppCopy.ratingFallback,
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
      return AppCopy.priceUnspecified;
    }

    if (normalized.contains("جنيه") || normalized.contains("جنية")) {
      return normalized;
    }

    return "$normalized ${AppCopy.currencyEgp}";
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.model});

  final SuggestionItemModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: model.color.withValues(alpha: 0.9),
        borderRadius: AppRadii.rMd,
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
          gapH(AppSpacing.sm),
          Text(
            model.suggestionText,
            style: AppText.labelMd.copyWith(
              color: AppColor.surfaceCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.address,
    required this.onOpenMap,
  });

  final String address;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: AppColor.surfaceVariant,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm.w),
                decoration: BoxDecoration(
                  color: AppColor.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadii.rSm,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColor.primary,
                  size: 20.sp,
                ),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.detailsLocationLabel,
                      style: AppText.labelSm.copyWith(
                        color: AppColor.textSecondary,
                      ),
                    ),
                    gapV(AppSpacing.xs),
                    Text(
                      address,
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
          gapV(AppSpacing.lg),
          AppButton(
            text: AppCopy.detailsOpenMap,
            onPress: onOpenMap,
            variant: AppButtonVariant.outline,
            icon: Icons.map_outlined,
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.priceLabel,
    required this.rateLabel,
  });

  final String priceLabel;
  final String rateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: AppColor.primary.withValues(alpha: 0.05),
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: AppColor.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.md.h,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.detailsPriceLabel,
                style: AppText.labelSm.copyWith(
                  color: AppColor.textSecondary,
                ),
              ),
              gapV(AppSpacing.xs),
              Text(
                priceLabel,
                style: AppText.titleLg.copyWith(
                  color: AppColor.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(AppSpacing.sm.w),
            decoration: BoxDecoration(
              color: AppColor.surfaceCard,
              borderRadius: AppRadii.rSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: AppColor.warning,
                  size: 16.sp,
                ),
                gapH(AppSpacing.xs),
                Text(
                  rateLabel,
                  style: AppText.labelMd.copyWith(
                    color: AppColor.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: AppColor.surfaceVariant,
        borderRadius: AppRadii.rPill,
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColor.textSecondary),
          gapH(AppSpacing.sm),
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
