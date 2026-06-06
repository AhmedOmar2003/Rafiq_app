import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/design/app_image.dart';
import '../../../core/design/cached_network_image.dart';
import '../../../core/design/tokens/tokens.dart';
import '../../../models/suggestion_item_model/suggestion_item.dart';

class SimilarEvents extends StatelessWidget {
  final List<SuggestionItemModel> suggestionItemList;
  final Function(SuggestionItemModel) onItemSelected;

  const SimilarEvents({
    super.key,
    required this.suggestionItemList,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final cardWidth = viewportWidth < 360.w ? 196.w : 220.w;
        final listHeight = viewportWidth < 360.w ? 248.h : 264.h;

        return SizedBox(
          height: listHeight,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              0,
              AppSpacing.lg.w,
              AppSpacing.lg.h,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: suggestionItemList.length,
            separatorBuilder: (_, __) => gapH(AppSpacing.md),
            itemBuilder: (context, index) => SimilarEventsItem(
              width: cardWidth,
              model: suggestionItemList[index],
              onItemSelected: onItemSelected,
            ),
          ),
        );
      },
    );
  }
}

class SimilarEventsItem extends StatelessWidget {
  final SuggestionItemModel model;
  final Function(SuggestionItemModel) onItemSelected;
  final double width;

  const SimilarEventsItem({
    super.key,
    required this.width,
    required this.model,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${model.text}. ${model.city}. ${model.price} جنيه',
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.rLg,
        child: InkWell(
          onTap: () => onItemSelected(model),
          borderRadius: AppRadii.rLg,
          child: Container(
        width: width,
        decoration: BoxDecoration(
          color: AppColor.surfaceCard,
          borderRadius: AppRadii.rLg,
          boxShadow: AppShadows.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 122.h,
              decoration: BoxDecoration(
                borderRadius: AppRadii.topOnly(AppRadii.lg),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadii.topOnly(AppRadii.lg),
                    child: model.image.isNotEmpty
                        ? CachedNetworkImage(
                            url: model.image,
                            height: 122.h,
                            fit: BoxFit.cover,
                            placeholder: (_) => const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColor.primary),
                              ),
                            ),
                            errorWidget: (_) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  // Rating Badge
                  Positioned(
                    top: AppSpacing.sm.h,
                    right: AppSpacing.sm.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w,
                        vertical: AppSpacing.xs.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surfaceCard,
                        borderRadius: AppRadii.rPill,
                        boxShadow: AppShadows.level1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: AppColor.warning,
                            size: 12.sp,
                          ),
                          gapH(AppSpacing.xs),
                          Text(
                            model.rate.toString(),
                            style: AppText.caption.copyWith(
                              color: AppColor.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content Container
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: width - 32.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: AppSpacing.xs.h,
                        ),
                        decoration: BoxDecoration(
                          color: model.color.withValues(alpha: 0.9),
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppImage(
                              model.icon,
                              color: AppColor.white,
                              height: 13.h,
                              width: 13.w,
                            ),
                            gapH(AppSpacing.xs),
                            Flexible(
                              child: Text(
                                model.suggestionText,
                                style: AppText.caption.copyWith(
                                  color: AppColor.surfaceCard,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    gapV(AppSpacing.sm),
                    Flexible(
                      child: Text(
                        model.text,
                        style: AppText.labelMd.copyWith(
                          color: AppColor.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "يبدأ من",
                                style: AppText.caption.copyWith(
                                  color: AppColor.textSecondary,
                                ),
                              ),
                              Text(
                                "${model.price} جنيه",
                                style: AppText.labelMd.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 36.w,
                          height: 36.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColor.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            color: AppColor.primary,
                            size: 18.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColor.neutral200,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 30.sp,
          color: AppColor.textTertiary,
        ),
      ),
    );
  }
}
