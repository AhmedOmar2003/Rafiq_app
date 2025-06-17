import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/design/app_input.dart';
import '../../core/design/custom_app_bar.dart';
import '../../core/design/title_text.dart';
import '../../core/utils/app_color.dart';
import '../../core/utils/font_weight_helper.dart';
import '../../core/utils/spacing.dart';
import '../../core/utils/text_style_theme.dart';
import 'package:rafiq_app/core/config/api_config.dart';

class EvaluationsPage extends StatefulWidget {
  final int placeId;
  const EvaluationsPage({super.key, required this.placeId});

  @override
  State<EvaluationsPage> createState() => _EvaluationsPageState();
}

class _EvaluationsPageState extends State<EvaluationsPage> {
  final textController = TextEditingController();
  final List<EvaluationsItemModel> evaluationsItemList = [];
  bool isLoading = false;
  String? userImage; // مسار الصورة المحفوظة في SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadUserImage();
    fetchReviews();
  }

  /// **تحميل الصورة الشخصية من SharedPreferences**
  Future<void> _loadUserImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userImage = prefs.getString('profile_image');
    });
  }

  /// **تنسيق التاريخ بشكل آمن**
  String _formatDate(String? date) {
    try {
      if (date == null || date.isEmpty) return "تاريخ غير متاح";
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
    } catch (e) {
      return "تاريخ غير متاح";
    }
  }

  /// **تحميل التقييمات من الخادم**
  Future<void> fetchReviews() async {
    setState(() {
      isLoading = true;
    });

    String apiUrl = "${ApiConfig.baseUrl}/fetch_reviews.php";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {"place_id": widget.placeId.toString()},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] is List) {
          final List<dynamic> reviews = jsonResponse['data'];

          setState(() {
            evaluationsItemList.clear();
            evaluationsItemList.addAll(
              reviews
                  .map((review) => EvaluationsItemModel.fromJson(review))
                  .where((review) => review.placeId == widget.placeId),
            );
          });
        } else {
          _showSnackBar("لا توجد تقييمات حالياً.", Colors.orange);
        }
      } else {
        _showSnackBar("خطأ في الخادم: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالخادم: $e", Colors.red);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// **إرسال التقييم**
  Future<void> submitReview() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final userName = prefs.getString('userName') ?? 'مستخدم مجهول';

    if (userId == null || textController.text.isEmpty) {
      _showSnackBar("تأكد من تسجيل الدخول وإدخال التقييم.", Colors.orange);
      setState(() {
        isLoading = false;
      });
      return;
    }

    String apiUrl = "${ApiConfig.baseUrl}/submit_review.php";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          "place_id": widget.placeId.toString(),
          "user_id": userId.toString(),
          "name": userName,
          "review_text": textController.text.trim(),
          "rating": "5",
          "image": "",
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          setState(() {
            evaluationsItemList.add(
              EvaluationsItemModel(
                placeId: widget.placeId,
                name: userName,
                date: DateTime.now().toString(),
                body: textController.text.trim(),
                image: userImage ?? "",
              ),
            );
            textController.clear();
          });

          // عرض رسالة النجاح
          _showSuccessOverlay();
        } else {
          _showSnackBar(result['message'] ?? "حدث خطأ غير متوقع.", Colors.red);
        }
      } else {
        _showSnackBar("خطأ في الخادم: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالخادم. الخطأ: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSuccessOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColor.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColor.primary,
                      size: 48.w,
                    ),
                  ),
                  verticalSpace(16.h),
                  CustomTextWidget(
                    label: "تم إرسال تقييمك بنجاح!",
                    style: TextStyleTheme.textStyle18Medium.copyWith(
                      color: AppColor.primary,
                      height: 1.2,
                    ),
                  ),
                  verticalSpace(8.h),
                  CustomTextWidget(
                    label: "شكراً لمشاركة تجربتك مع الآخرين",
                    style: TextStyleTheme.textStyle14Regular.copyWith(
                      color: AppColor.black.withOpacity(0.7),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  verticalSpace(24.h),
                  Material(
                    color: AppColor.primary,
                    borderRadius: BorderRadius.circular(8.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.r),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Center(
                          child: CustomTextWidget(
                            label: "حسناً",
                            style: TextStyleTheme.textStyle16Medium.copyWith(
                              color: Colors.white,
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
        );
      },
    );
  }

  /// **عرض رسالة خطأ**
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColor.white,
      appBar: CustomAppBar(
        backgroundColor: AppColor.ofWhite,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CustomTextWidget(
            label: "التقييمات",
            style: TextStyleTheme.textStyle24Medium.copyWith(
              color: AppColor.black,
              height: 1.2,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        //crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CustomTextWidget(
                    label: "الكل",
                    style: TextStyleTheme.textStyle18Medium.copyWith(
                      fontWeight: FontWeightHelper.bold,
                      height: 1.2,
                    ),
                  ),
                  horizontalSpace(5.w),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () {},
                  splashColor: AppColor.primary.withOpacity(0.1),
                  highlightColor: AppColor.primary.withOpacity(0.05),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColor.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColor.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 20.w,
                          color: AppColor.primary,
                        ),
                        horizontalSpace(6.w),
                        CustomTextWidget(
                          label: "الأكثر شعبية",
                          style: TextStyleTheme.textStyle12Regular.copyWith(
                            color: AppColor.primary,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          verticalSpace(16.h),
          evaluationsItemList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: evaluationsItemList.length,
                  itemBuilder: (context, index) {
                    final evaluation = evaluationsItemList[index];
                    final String formattedDate = _formatDate(evaluation.date);
                    return _buildEvaluationItem(evaluation, formattedDate);
                  },
                ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: 77.h,
          decoration: BoxDecoration(
            color: AppColor.ofWhite,
            boxShadow: [
              BoxShadow(
                color: AppColor.black.withOpacity(0.05),
                offset: const Offset(0, -1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: AppInput(
                      hintText: "قولنا رأيك !",
                      fillColor: AppColor.white,
                      controller: textController,
                      isFilled: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 10.h, left: 21.w),
                child: Material(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.circular(25.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25.r),
                    onTap: isLoading ? null : submitReview,
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                    child: Container(
                      height: 45.h,
                      width: 45.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25.r),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.send_rounded,
                          size: 22.w,
                          color: AppColor.ofWhite,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppColor.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 64.w,
                color: AppColor.primary,
              ),
            ),
            verticalSpace(24.h),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              tween: Tween<double>(begin: 0.8, end: 1.0),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: CustomTextWidget(
                  label: "كن أول من يشارك رأيه!",
                  style: TextStyleTheme.textStyle20Bold.copyWith(
                    color: AppColor.primary,
                    fontSize: 26.sp,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            verticalSpace(16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.black.withOpacity(0.05),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildEmptyStateItem(
                    "شارك تجربتك مع الآخرين",
                    Icons.share_outlined,
                  ),
                  verticalSpace(16.h),
                  _buildEmptyStateItem(
                    "ساعد الآخرين في اتخاذ قرارات أفضل",
                    Icons.lightbulb_outline,
                  ),
                  verticalSpace(16.h),
                  _buildEmptyStateItem(
                    "اكتشف أماكن جديدة مع الجميع",
                    Icons.explore_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateItem(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: AppColor.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            size: 24.w,
            color: AppColor.primary,
          ),
        ),
        horizontalSpace(12.w),
        Expanded(
          child: CustomTextWidget(
            label: text,
            style: TextStyleTheme.textStyle16Regular.copyWith(
              color: AppColor.black.withOpacity(0.8),
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationItem(EvaluationsItemModel evaluation, String formattedDate) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          horizontalSpace(16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evaluation.name,
                  style: TextStyleTheme.textStyle18Medium.copyWith(
                    height: 1.2,
                  ),
                ),
                verticalSpace(8.h),
                Row(
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (starIndex) => Padding(
                          padding: EdgeInsets.only(right: 3.w),
                          child: Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 20.w,
                          ),
                        ),
                      ),
                    ),
                    horizontalSpace(12.w),
                    Text(
                      formattedDate,
                      style: TextStyleTheme.textStyle12Regular.copyWith(
                        color: AppColor.black.withOpacity(0.6),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                verticalSpace(12.h),
                Text(
                  evaluation.body,
                  style: TextStyleTheme.textStyle12Medium.copyWith(
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundImage: userImage != null &&
                userImage!.isNotEmpty &&
                File(userImage!).existsSync()
            ? FileImage(File(userImage!))
            : const AssetImage('assets/images/default_profile.png')
                as ImageProvider,
        radius: 26.r,
        backgroundColor: AppColor.primary.withOpacity(0.1),
        child: userImage == null ||
                userImage!.isEmpty ||
                !File(userImage!).existsSync()
            ? Icon(Icons.person, color: AppColor.primary, size: 26.w)
            : null,
      ),
    );
  }
}
