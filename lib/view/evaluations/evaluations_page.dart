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
  int _selectedRating = 0;

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
    final userName =
        prefs.getString('userName') ?? AppCopy.reviewAuthorAnonymous;

    if (userId == null || _selectedRating == 0 || textController.text.trim().isEmpty) {
      AppFeedback.warning(
        _selectedRating == 0
            ? AppCopy.reviewPickStars
            : AppCopy.reviewEmptyText,
      );
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
        rating: _selectedRating,
        image: imagePath,
      );

      if (!mounted) return;
      setState(() {
        evaluationsItemList.insert(0, insertedReview);
        textController.clear();
        _selectedRating = 0;
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
            ...List.generate(
                3,
                (i) => Padding(
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
    return AppStickyFooter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppCopy.reviewPickStars,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
          ),
          gapV(AppSpacing.xs),
          Text(
            AppCopy.reviewStarsHelper,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          gapV(AppSpacing.md),
          _RatingSelector(
            value: _selectedRating,
            onChanged: (value) => setState(() => _selectedRating = value),
          ),
          gapV(AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: AppRadii.rLg,
              border: Border.all(color: AppColor.border),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w,
              vertical: AppSpacing.md.h,
            ),
            child: TextField(
              controller: textController,
              textAlign: TextAlign.right,
              style: AppText.bodyMd.copyWith(color: AppColor.textPrimary),
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: AppCopy.reviewWriteOptional,
                hintStyle:
                    AppText.bodyMd.copyWith(color: AppColor.textTertiary),
              ),
            ),
          ),
          gapV(AppSpacing.md),
          AppButton(
            text: isLoading ? 'جارٍ الإرسال...' : AppCopy.reviewSendCta,
            onPress: submitReview,
            isEnabled: !isLoading,
            isLoading: isLoading,
          ),
        ],
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
                color: AppColor.primary.withValues(alpha: 0.1),
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
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w, vertical: AppSpacing.xxl.h),
              decoration: BoxDecoration(
                color: AppColor.surfaceCard,
                borderRadius: AppRadii.rXl,
                boxShadow: AppShadows.level1,
              ),
              child: Column(
                children: [
                  _buildEmptyStateItem(
                      AppCopy.reviewsEmptyShare, Icons.share_outlined),
                  gapV(AppSpacing.lg),
                  _buildEmptyStateItem(
                      AppCopy.reviewsEmptyHelp, Icons.lightbulb_outline),
                  gapV(AppSpacing.lg),
                  _buildEmptyStateItem(
                      AppCopy.reviewsEmptyDiscover, Icons.explore_outlined),
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
            color: AppColor.primary.withValues(alpha: 0.1),
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
          _ReviewerAvatar(name: evaluation.name, imagePath: evaluation.image),
          gapH(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evaluation.name, style: AppText.titleLg),
                gapV(AppSpacing.xs),
                Row(
                  children: [
                    ...List.generate(
                        5,
                        (i) => Padding(
                              padding: EdgeInsets.only(left: 2.w),
                              child: Icon(Icons.star_rounded,
                                  color: i < evaluation.rating
                                      ? AppColor.warning
                                      : AppColor.border,
                                  size: 18.w),
                            )),
                    gapH(AppSpacing.sm),
                    Text(formattedDate, style: AppText.bodySm),
                  ],
                ),
                gapV(AppSpacing.sm),
                Text(evaluation.body.isNotEmpty
                        ? evaluation.body
                        : AppCopy.reviewNoCommentFallback,
                    style: AppText.bodyMd.copyWith(height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final rating = index + 1;
        final selected = rating <= value;
        return Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm.w),
          child: InkWell(
            borderRadius: AppRadii.rPill,
            onTap: () => onChanged(rating),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.sm.w),
              decoration: BoxDecoration(
                color: selected
                    ? AppColor.warning.withValues(alpha: 0.12)
                    : AppColor.surfaceMuted,
                borderRadius: AppRadii.rPill,
                border: Border.all(
                  color: selected ? AppColor.warning : AppColor.border,
                ),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 24.sp,
                color: selected ? AppColor.warning : AppColor.textTertiary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReviewerAvatar extends StatelessWidget {
  const _ReviewerAvatar({
    required this.name,
    required this.imagePath,
  });

  final String name;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final trimmed = imagePath.trim();
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '؟';
    final imageProvider = trimmed.startsWith('http')
        ? NetworkImage(trimmed)
        : trimmed.startsWith('assets/')
            ? AssetImage(trimmed) as ImageProvider
            : null;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withValues(alpha: 0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundImage: imageProvider,
        radius: 26.r,
        backgroundColor: AppColor.primary.withValues(alpha: 0.10),
        child: imageProvider == null
            ? Text(
                initial,
                style: AppText.titleMd.copyWith(
                  color: AppColor.primary,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}
