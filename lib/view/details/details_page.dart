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
import '../../core/design/custom_app_bar.dart';
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
        AppFeedback.error("فشل الدفع، حاول تاني");
      }
    } catch (_) {
      if (!_isMounted) return;
      AppFeedback.error("حصل خطأ في الدفع، حاول تاني");
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

    return Stack(
      children: [
      Scaffold(
      backgroundColor: AppColor.surface,
      appBar: CustomAppBar(
        backgroundColor: AppColor.surface,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            "التفاصيل",
            style: AppText.headingLg,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.only(top: 24.h, bottom: 100.h),
              children: [
                // Details Section
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AppColor.surfaceCard,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      DetailsItem(model: currentModel),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: const CustomDivider(),
                      ),
                    ],
                  ),
                ),

                // Evaluations Section
                if (lastEvaluation != null || true)
                  Container(
                    margin: EdgeInsets.only(top: 24.h, left: 16.w, right: 16.w),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: _isReviewLoading && lastEvaluation == null
                              ? SizedBox(
                                  height: 120.h,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColor.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : lastEvaluation != null
                                  ? CustomEvaluations(
                                      placeId: currentModel.placeId,
                                      lastEvaluation: lastEvaluation,
                                      userImage: userImage,
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EvaluationsPage(
                                              placeId: currentModel.placeId,
                                            ),
                                          ),
                                        ).then((_) {
                                          if (!_isMounted) return;
                                          _fetchLastEvaluationFromAPI(
                                              currentModel.placeId);
                                        });
                                      },
                                      child: Column(
                                        children: [
                                          Icon(Icons.rate_review_outlined, size: 48.sp, color: AppColor.textTertiary),
                                          gapV(AppSpacing.md),
                                          Text(
                                            "كن أول من يعلق",
                                            style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
                                          ),
                                          gapV(AppSpacing.md),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
                                            decoration: BoxDecoration(
                                              color: AppColor.primary.withOpacity(0.1),
                                              borderRadius: AppRadii.rPill,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_comment_outlined, size: 16.sp, color: AppColor.primary),
                                                gapH(AppSpacing.sm),
                                                Text(
                                                  "أضف تعليقك",
                                                  style: AppText.labelMd.copyWith(color: AppColor.primary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  ),

                // Similar Events Section
                if (filteredSuggestions.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 24.h),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.black.withOpacity(0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("فعاليات مشابهة", style: AppText.headingSm),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
                                decoration: BoxDecoration(
                                  color: AppColor.primary.withOpacity(0.1),
                                  borderRadius: AppRadii.rPill,
                                  border: Border.all(color: AppColor.primary.withOpacity(0.2), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place_outlined, size: 14.sp, color: AppColor.primary),
                                    gapH(AppSpacing.xs),
                                    Text(
                                      filteredSuggestions.length.toString(),
                                      style: AppText.labelMd.copyWith(color: AppColor.primary, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SimilarEvents(
                          suggestionItemList: filteredSuggestions,
                          onItemSelected: updateModel,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: EdgeInsets.only(top: 24.h, left: 16.w, right: 16.w),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_outlined, size: 48.sp, color: AppColor.textTertiary),
                        gapV(AppSpacing.md),
                        Text("مفيش أماكن مشابهة دلوقتي", style: AppText.bodyLg.copyWith(color: AppColor.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isPaymentLoading)
            Container(
              color: AppColor.overlaySoft,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
          decoration: BoxDecoration(
            color: AppColor.surface,
            boxShadow: AppShadows.level2,
          ),
          child: AppButton(
            text: "احجز دلوقتي",
            onPress: _handlePayment,
            isLoading: _isPaymentLoading,
          ),
        ),
      ),
    ),
    if (_showPaymentSuccess)
      AppSuccessView(
        title: 'تم الحجز بنجاح! 🎉',
        message: 'ميّرتنا الاختيار\nنتمنالك وقت ممتع',
        onContinue: () {
          if (_isMounted) setState(() => _showPaymentSuccess = false);
        },
      ),
    ],
    );
  }
}
