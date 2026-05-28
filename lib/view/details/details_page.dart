import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/paymob/paymob_manager.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/evaluations/evaluations_page.dart';
import '../../core/utils/app_microcopy.dart';
import '../../models/suggestion_item_model/suggestion_item.dart';
import 'widget/custom_divider.dart';
import 'widget/custom_evaluations.dart';
import 'widget/details_item.dart';
import 'widget/similar_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailsPage extends StatefulWidget {
  final SuggestionItemModel model;
  final List<SuggestionItemModel> suggestionItemList;

  const DetailsPage({
    Key? key,
    required this.model,
    required this.suggestionItemList,
  }) : super(key: key);

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final ApiService _apiService = ApiService();
  late SuggestionItemModel currentModel;
  EvaluationsItemModel? lastEvaluation;
  String? userImage;
  bool _isReviewLoading = false;
  bool _isPaymentLoading = false;
  bool _showPaymentSuccess = false;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    currentModel = widget.model;
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadUserImage(),
      _fetchLastEvaluationFromAPI(currentModel.placeId),
    ]);
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _loadUserImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (kIsWeb) {
        final imageBase64 = prefs.getString('profile_image_base64');
        if (!_isMounted) return;
        setState(() => userImage = imageBase64);
        return;
      }

      final imagePath = prefs.getString('profile_image');

      if (!_isMounted) return;

      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          setState(() => userImage = imagePath);
        } else {
          setState(() => userImage = null);
        }
      } else {
        setState(() => userImage = null);
      }
    } catch (_) {
      // Silent — profile image is decorative; don't distract user
    }
  }

  Future<void> _fetchLastEvaluationFromAPI(int placeId) async {
    if (!_isMounted) return;
    setState(() => _isReviewLoading = true);

    try {
      final latestReview = await _apiService.fetchLastReview(placeId: placeId);

      if (!_isMounted) return;

      setState(() {
        lastEvaluation = latestReview;
      });
    } catch (_) {
      if (!_isMounted) return;
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (_isMounted) {
        setState(() => _isReviewLoading = false);
      }
    }
  }

  void updateModel(SuggestionItemModel newModel) {
    if (!_isMounted) return;
    setState(() {
      currentModel = newModel;
    });
    _fetchLastEvaluationFromAPI(newModel.placeId);
  }

  void _showSuccessOverlay() {
    if (!_isMounted) return;
    setState(() => _showPaymentSuccess = true);
  }

  Future<void> _handlePayment() async {
    if (_isPaymentLoading) return;
    if (!_isMounted) return;
    setState(() => _isPaymentLoading = true);

    try {
      final price = currentModel.getPrice();
      final isPaymentSuccessful = await PayMobManager().getPaymentKey(
        amount: price,
        currency: "EGP",
        context: context,
        placeId: currentModel.placeId,
      );

      if (!_isMounted) return;

      if (isPaymentSuccessful) {
        _showSuccessOverlay();
      } else {
        AppFeedback.error(AppCopy.paymentFailed);
      }
    } catch (_) {
      if (!_isMounted) return;
      AppFeedback.error(AppCopy.paymentError);
    } finally {
      if (_isMounted) {
        setState(() => _isPaymentLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuggestions = widget.suggestionItemList
        .where((item) => item != currentModel)
        .toList();

    return AppPageScaffold(
      unpadded: true,
      header: const AppPageHeader(title: AppCopy.detailsTitle),
      floatingOverlay: _showPaymentSuccess
          ? AppSuccessView(
              title: AppCopy.paymentSuccessTitle,
              message: AppCopy.paymentSuccessBody,
              onContinue: () {
                if (_isMounted) setState(() => _showPaymentSuccess = false);
              },
            )
          : null,
      footer: AppStickyFooter(
        child: AppButton(
          text: AppCopy.bookNow,
          onPress: _handlePayment,
          isLoading: _isPaymentLoading,
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                AppSpacing.xxl.h,
                AppSpacing.lg.w,
                AppSpacing.huge.h * 2, // room for sticky footer
              ),
              children: [
                _DetailsSection(model: currentModel),
                gapV(AppSpacing.xxl),
                _ReviewsSection(
                  placeId: currentModel.placeId,
                  isLoading: _isReviewLoading && lastEvaluation == null,
                  lastEvaluation: lastEvaluation,
                  userImage: userImage,
                  onOpenAll: _openEvaluationsPage,
                ),
                gapV(AppSpacing.xxl),
                if (filteredSuggestions.isNotEmpty)
                  _SimilarSection(
                    items: filteredSuggestions,
                    onItemSelected: updateModel,
                  )
                else
                  const _NoSimilarSection(),
              ],
            ),
          ),
          if (_isPaymentLoading) const _PaymentScrim(),
        ],
      ),
    );
  }

  void _openEvaluationsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluationsPage(placeId: currentModel.placeId),
      ),
    ).then((_) {
      if (!_isMounted) return;
      _fetchLastEvaluationFromAPI(currentModel.placeId);
    });
  }
}

// ===========================================================================
// Sections
// ===========================================================================

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.model});

  final SuggestionItemModel model;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          DetailsItem(model: model),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: const CustomDivider(),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.placeId,
    required this.isLoading,
    required this.lastEvaluation,
    required this.userImage,
    required this.onOpenAll,
  });

  final int placeId;
  final bool isLoading;
  final EvaluationsItemModel? lastEvaluation;
  final String? userImage;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 120.h,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
          ),
        ),
      );
    } else if (lastEvaluation != null) {
      child = CustomEvaluations(
        placeId: placeId,
        lastEvaluation: lastEvaluation,
        userImage: userImage,
      );
    } else {
      child = _EmptyReviews(onTap: onOpenAll);
    }

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: child,
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rLg,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md.w),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 48.sp,
              color: AppColor.textTertiary,
            ),
            gapV(AppSpacing.md),
            Text(
              AppCopy.detailsBeFirstReview,
              style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
            ),
            gapV(AppSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w,
                vertical: AppSpacing.sm.h,
              ),
              decoration: BoxDecoration(
                color: AppColor.primary50,
                borderRadius: AppRadii.rPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_comment_outlined,
                    size: 16.sp,
                    color: AppColor.primary,
                  ),
                  gapH(AppSpacing.sm),
                  Text(
                    AppCopy.detailsAddYourComment,
                    style: AppText.labelMd.copyWith(color: AppColor.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarSection extends StatelessWidget {
  const _SimilarSection({required this.items, required this.onItemSelected});

  final List<SuggestionItemModel> items;
  final ValueChanged<SuggestionItemModel> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppCopy.detailsSimilarHeading,
                  style: AppText.headingSm,
                ),
                _CountChip(count: items.length),
              ],
            ),
          ),
          SimilarEvents(
            suggestionItemList: items,
            onItemSelected: onItemSelected,
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.primary50,
        borderRadius: AppRadii.rPill,
        border: Border.all(color: AppColor.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 14.sp, color: AppColor.primary),
          gapH(AppSpacing.xs),
          Text(
            '$count',
            style: AppText.labelMd.copyWith(
              color: AppColor.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSimilarSection extends StatelessWidget {
  const _NoSimilarSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48.sp,
            color: AppColor.textTertiary,
          ),
          gapV(AppSpacing.md),
          Text(
            AppCopy.detailsNoSimilar,
            style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PaymentScrim extends StatelessWidget {
  const _PaymentScrim();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColor.overlaySoft,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
