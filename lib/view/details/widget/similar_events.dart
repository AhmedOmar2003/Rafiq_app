import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/app_image.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260.h,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            itemCount: suggestionItemList.length,
            itemBuilder: (context, index) => SimilarEventsItem(
              model: suggestionItemList[index],
              onItemSelected: onItemSelected,
            ),
          ),
        ),
      ],
    );
  }
}

class SimilarEventsItem extends StatelessWidget {
  final SuggestionItemModel model;
  final Function(SuggestionItemModel) onItemSelected;

  const SimilarEventsItem({
    super.key,
    required this.model,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onItemSelected(model),
      child: Container(
        width: 220.w,
        height: 280.h,
        margin: EdgeInsetsDirectional.only(end: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Container
            Container(
              height: 130.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                    child: model.image.isNotEmpty
                        ? Image.network(
                            model.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColor.primary),
                                ),
                              );
                            },
                          )
                        : _buildPlaceholder(),
                  ),
                  // Rating Badge
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 12.sp,
                          ),
                          horizontalSpace(2),
                          Text(
                            model.rate.toString(),
                            style: TextStyleTheme.textStyle12Medium.copyWith(
                              color: Colors.black87,
                              fontSize: 10.sp,
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
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Badge
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: model.color.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8.r),
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
                          horizontalSpace(3),
                          Flexible(
                            child: Text(
                              model.suggestionText,
                              style: TextStyleTheme.textStyle12Medium.copyWith(
                                color: Colors.white,
                                fontSize: 11.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    verticalSpace(6),
                    // Title
                    Flexible(
                      child: Text(
                        model.text,
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: Colors.black87,
                          height: 1.2,
                          fontSize: 15.sp,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    verticalSpace(6),
                    // Price
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
                                style: TextStyleTheme.textStyle12Medium.copyWith(
                                  color: Colors.black54,
                                  fontSize: 11.sp,
                                ),
                              ),
                              Text(
                                "${model.price} جنية",
                                style: TextStyleTheme.textStyle16Medium.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: AppColor.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            color: AppColor.primary,
                            size: 17.sp,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 30.sp,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
