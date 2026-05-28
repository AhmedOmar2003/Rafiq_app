import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import '../../core/design/components/components.dart';
import '../../core/design/tokens/tokens.dart';
import '../../core/utils/app_microcopy.dart';

class EvaluationsPage extends StatefulWidget {
  final int placeId;
  const EvaluationsPage({super.key, required this.placeId});

  @override
  State<EvaluationsPage> createState() => _EvaluationsPageState();
}

class _EvaluationsPageState extends State<EvaluationsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController textController = TextEditingController();
  final List<EvaluationsItemModel> evaluationsItemList = [];
  bool isLoading = false;
  bool _showSuccessView = false;

  @override
  void initState() {
    super.initState();
    // Profile image now flows through ProfileImageStore — no more
    // per-screen disk reads.
    ProfileImageStore.instance.ensureLoaded();
    fetchReviews();
  }

  @override
  void dispose() {
    // PERFORMANCE / CORRECTNESS: TextEditingController owns a ChangeNotifier
    // that leaks if not disposed when the widget tree tears down.
    textController.dispose();
    super.dispose();
  }

  /// **تنسيق التاريخ بشكل آمن**
  String _formatDate(String? date) {
    try {
      if (date == null || date.isEmpty) return AppCopy.reviewDateUnknown;
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
    } catch (e) {
      return AppCopy.reviewDateUnknown;
    }
  }

  /// **تحميل التقييمات من الخادم**
  Future<void> fetchReviews() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final reviews = await _apiService.fetchReviews(placeId: widget.placeId);
      if (!mounted) return;
      setState(() {
        evaluationsItemList
          ..clear()
          ..addAll(reviews);
      });
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// **إرسال التقييم**
  Future<void> submitReview() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final userId =
        prefs.getString('authUserId') ?? prefs.getInt('userId')?.toString();
    final userName = prefs.getString('userName') ?? AppCopy.reviewAuthorAnonymous;

    if (userId == null || textController.text.isEmpty) {
      AppFeedback.warning(AppCopy.reviewEmptyText);
      setState(() => isLoading = false);
      return;
    }

    try {
      final imagePath = ProfileImageStore.instance.value.file?.path ?? '';
      final insertedReview = await _apiService.submitReview(
        placeId: widget.placeId,
        userId: userId,
        name: userName,
        reviewText: textController.text.trim(),
        rating: 5,
        image: imagePath,
      );

      if (!mounted) return;
      setState(() {
        evaluationsItemList.insert(0, insertedReview);
        textController.clear();
        _showSuccessView = true;
      });
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: AppPageHeader(
        title: AppCopy.reviewsTitle,
        subtitle: evaluationsItemList.isEmpty
            ? null
            : "${evaluationsItemList.length} تقييم",
      ),
      unpadded: true,
      footer: _buildCommentBar(),
      floatingOverlay: _showSuccessView
          ? AppSuccessView(
              title: AppCopy.reviewThanksTitle,
              message: AppCopy.reviewThanksBody,
              onContinue: () => setState(() => _showSuccessView = false),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.lg.h, AppSpacing.lg.w, AppSpacing.lg.h),
        children: [
          if (isLoading && evaluationsItemList.isEmpty)
            ...List.generate(3, (i) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md.h),
              child: AppSkeleton.card(),
            ))
          else if (evaluationsItemList.isEmpty)
            _buildEmptyState()
          else
            ...evaluationsItemList.map((evaluation) =>
                _buildEvaluationItem(evaluation, _formatDate(evaluation.date))),
        ],
      ),
    );
  }

  /// Sticky comment composer pinned above the keyboard.
  Widget _buildCommentBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        boxShadow: AppShadows.level3,
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.md.h),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                decoration: BoxDecoration(
                  color: AppColor.surface,
                  borderRadius: AppRadii.rPill,
                  border: Border.all(color: AppColor.border),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: textController,
                  textAlign: TextAlign.right,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppText.bodyLg.copyWith(color: AppColor.textPrimary),
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: isLoading ? null : (_) => submitReview(),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: AppCopy.reviewInputHint,
                    hintStyle: AppText.bodyLg.copyWith(color: AppColor.textTertiary),
                  ),
                ),
              ),
            ),
            gapH(AppSpacing.sm),
            Material(
              color: isLoading ? AppColor.primary.withOpacity(0.5) : AppColor.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isLoading ? null : submitReview,
                child: SizedBox(
                  height: 50.h,
                  width: 50.h,
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                                color: AppColor.white, strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded, size: 22.w, color: AppColor.white),
                  ),
                ),
              ),
            ),
          ],
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
            gapV(AppSpacing.xxl),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              tween: Tween<double>(begin: 0.8, end: 1.0),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Text(
                  AppCopy.reviewsEmptyHeadline,
                  style: AppText.headingLg.copyWith(color: AppColor.primary),
                ),
              ),
            ),
            gapV(AppSpacing.lg),
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.xxl.h),
              decoration: BoxDecoration(
                color: AppColor.surfaceCard,
                borderRadius: AppRadii.rXl,
                boxShadow: AppShadows.level1,
              ),
              child: Column(
                children: [
                  _buildEmptyStateItem(AppCopy.reviewsEmptyShare, Icons.share_outlined),
                  gapV(AppSpacing.lg),
                  _buildEmptyStateItem(AppCopy.reviewsEmptyHelp, Icons.lightbulb_outline),
                  gapV(AppSpacing.lg),
                  _buildEmptyStateItem(AppCopy.reviewsEmptyDiscover, Icons.explore_outlined),
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
          padding: EdgeInsets.all(AppSpacing.sm.w),
          decoration: BoxDecoration(
            color: AppColor.primary.withOpacity(0.1),
            borderRadius: AppRadii.rMd,
          ),
          child: Icon(icon, size: 22.w, color: AppColor.primary),
        ),
        gapH(AppSpacing.md),
        Expanded(child: Text(text, style: AppText.bodyLg)),
      ],
    );
  }

  Widget _buildEvaluationItem(
      EvaluationsItemModel evaluation, String formattedDate) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rLg,
        boxShadow: AppShadows.level1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          gapH(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evaluation.name, style: AppText.titleLg),
                gapV(AppSpacing.xs),
                Row(
                  children: [
                    ...List.generate(5, (i) => Padding(
                      padding: EdgeInsets.only(left: 2.w),
                      child: Icon(Icons.star_rounded, color: Colors.amber, size: 18.w),
                    )),
                    gapH(AppSpacing.sm),
                    Text(formattedDate, style: AppText.bodySm),
                  ],
                ),
                gapV(AppSpacing.sm),
                Text(evaluation.body, style: AppText.bodyMd.copyWith(height: 1.6)),
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
      // Only the avatar rebuilds when the user changes their picture; the
      // surrounding evaluation row stays cached.
      child: ValueListenableBuilder<ProfileImageState>(
        valueListenable: ProfileImageStore.instance,
        builder: (_, snap, __) {
          final ImageProvider provider = snap.bytes != null
              ? MemoryImage(snap.bytes!)
              : snap.file != null
                  ? FileImage(snap.file!)
                  : const AssetImage('assets/images/default_profile.png')
                      as ImageProvider;
          return CircleAvatar(
            backgroundImage: provider,
            radius: 26.r,
            backgroundColor: AppColor.primary.withOpacity(0.1),
            child: snap.hasImage
                ? null
                : Icon(Icons.person, color: AppColor.primary, size: 26.w),
          );
        },
      ),
    );
  }
}
