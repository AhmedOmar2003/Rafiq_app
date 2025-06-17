import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/paymob/paymob_manager.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/view/evaluations/evaluations_page.dart';
import '../../core/design/app_button.dart';
import '../../core/design/custom_app_bar.dart';
import '../../core/design/title_text.dart';
import '../../core/utils/app_color.dart';
import '../../core/utils/text_style_theme.dart';
import '../../models/suggestion_item_model/suggestion_item.dart';
import 'widget/custom_divider.dart';
import 'widget/custom_evaluations.dart';
import 'widget/details_item.dart';
import 'widget/similar_events.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafiq_app/core/config/api_config.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/spacing.dart';
import 'package:flutter/rendering.dart';

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
  late SuggestionItemModel currentModel;
  EvaluationsItemModel? lastEvaluation;
  OverlayEntry? _overlayEntry;
  String? userImage;
  bool _isLoading = false;
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
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  Future<void> _loadUserImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
    } catch (e) {
      if (!_isMounted) return;
      _showSnackBar("Error loading user image: $e", Colors.red);
    }
  }

  Future<void> _fetchLastEvaluationFromAPI(int placeId) async {
    if (!_isMounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/fetch_reviews.php"),
        body: {"place_id": placeId.toString()},
      ).timeout(const Duration(seconds: 10));

      if (!_isMounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          final reviews = jsonResponse['data'] as List<dynamic>;
          final lastReview = reviews.isNotEmpty
              ? reviews.firstWhere(
                  (review) =>
                      review['place_id'].toString() == placeId.toString(),
                  orElse: () => null,
                )
              : null;

          setState(() {
            lastEvaluation = lastReview != null
                ? EvaluationsItemModel.fromJson(
                    lastReview as Map<String, dynamic>)
                : null;
          });
        } else {
          setState(() => lastEvaluation = null);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      if (!_isMounted) return;
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
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

  void _showSnackBar(String message, Color color) {
    if (!_isMounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

 void _showSuccessOverlay() {
  if (!_isMounted) return;

  _overlayEntry = OverlayEntry(
    builder: (context) => GestureDetector(
      onTap: () {}, // Prevent dismissal on outside tap
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  tween: Tween<double>(begin: 0.7, end: 1.0),
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 320.w,
                      padding: EdgeInsets.all(28.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: 8,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Success Icon with Ring Animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            tween: Tween<double>(begin: 0.5, end: 1.0),
                            builder: (context, scale, child) => Transform.scale(
                              scale: scale,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 120.w,
                                    height: 120.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                                      border: Border.all(
                                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                                        width: 8.w,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 90.w,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 28.h),
                          
                          // Success Title with Scale Animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) => Transform.scale(
                              scale: value,
                              child: Text(
                                "تم الدفع بنجاح!",
                                style: GoogleFonts.cairo(
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E7D32),
                                  height: 1.2,
                                  decoration: TextDecoration.none, // إزالة الخط التحتي
                                  decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          
                          // Success Message with Fade Animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOut,
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Text(
                                "شكراً لثقتك بنا\nنتمنى لك رحلة ممتعة",
                                style: GoogleFonts.cairo(
                                  fontSize: 18.sp,
                                  color: Colors.black54,
                                  height: 1.5,
                                  decoration: TextDecoration.none, // إزالة الخط التحتي
                                  decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          SizedBox(height: 32.h),
                          
                          // Action Button with Slide Animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutBack,
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) => Transform.translate(
                              offset: Offset(0, 50 * (1 - value)),
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _overlayEntry?.remove();
                                      if (!_isMounted) return;
                                      setState(() => _overlayEntry = null);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16.h),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.r),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      "حسناً",
                                      style: GoogleFonts.cairo(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        height: 1.2,
                                        decoration: TextDecoration.none, // إزالة الخط التحتي
                                        decorationColor: Colors.transparent, // التأكد من إزالة لون الخط
                                      ),
                                    ),
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
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(_overlayEntry!);
}

  Future<void> _handlePayment() async {
    if (!_isMounted) return;
    setState(() => _isLoading = true);

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
        _showSnackBar("فشل الدفع!", Colors.red);
      }
    } catch (e) {
      if (!_isMounted) return;
      _showSnackBar("خطأ في الدفع: $e", Colors.red);
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuggestions = widget.suggestionItemList
        .where((item) => item != currentModel)
        .toList();

    return Scaffold(
      backgroundColor: AppColor.white,
      appBar: CustomAppBar(
        backgroundColor: AppColor.ofWhite,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CustomTextWidget(
            label: "التفاصيل",
            style: TextStyleTheme.textStyle24Medium.copyWith(
              color: AppColor.black,
            ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: lastEvaluation != null
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
                                        builder: (context) => EvaluationsPage(
                                          placeId: currentModel.placeId,
                                        ),
                                      ),
                                    ).then((_) {
                                      if (!_isMounted) return;
                                      _fetchLastEvaluationFromAPI(currentModel.placeId);
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.rate_review_outlined,
                                        size: 48.sp,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 12.h),
                                      CustomTextWidget(
                                        label: "كن أول من يعلق",
                                        style: TextStyleTheme.textStyle16Medium.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                        decoration: BoxDecoration(
                                          color: AppColor.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_comment_outlined,
                                              size: 16.sp,
                                              color: AppColor.primary,
                                            ),
                                            SizedBox(width: 8.w),
                                            CustomTextWidget(
                                              label: "أضف تعليقك",
                                              style: TextStyleTheme.textStyle12Regular.copyWith(
                                                color: AppColor.primary,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                              CustomTextWidget(
                                label: "فعاليات مشابهة",
                                style: TextStyleTheme.textStyle20Medium.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: AppColor.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: AppColor.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event,
                                      size: 16.sp,
                                      color: AppColor.primary,
                                    ),
                                    SizedBox(width: 4.w),
                                    CustomTextWidget(
                                      label: filteredSuggestions.length.toString(),
                                      style: TextStyleTheme.textStyle16Medium.copyWith(
                                        color: AppColor.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 48.sp,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 12.h),
                        CustomTextWidget(
                          label: "لا يوجد مشابه",
                          style: TextStyleTheme.textStyle16Medium.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 90.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColor.ofWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, -4),
              blurRadius: 20,
            ),
          ],
        ),
        child: AppButton(
          text: "احجز دلوقتي",
          textStyle: TextStyleTheme.textStyle20Medium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          buttonStyle: ElevatedButton.styleFrom(
            backgroundColor: AppColor.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            elevation: 2,
            padding: EdgeInsets.symmetric(vertical: 14.h),
          ),
          onPress: _handlePayment,
        ),
      ),
    );
  }
}
