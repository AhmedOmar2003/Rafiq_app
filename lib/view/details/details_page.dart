import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/model/review_model.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import 'package:rafiq_app/view/evaluations/evaluations_page.dart';
import '../../core/utils/app_microcopy.dart';
import '../../models/suggestion_item_model/suggestion_item.dart';
import 'widget/custom_divider.dart';
import 'widget/custom_evaluations.dart';
import 'widget/details_item.dart';
import 'widget/similar_events.dart';

class DetailsPage extends StatefulWidget {
  final SuggestionItemModel model;
  final List<SuggestionItemModel> suggestionItemList;

  const DetailsPage({
    super.key,
    required this.model,
    required this.suggestionItemList,
  });

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final ApiService _apiService = ApiService();
  late SuggestionItemModel currentModel;
  EvaluationsItemModel? lastEvaluation;
  List<String> galleryImages = const [];
  bool _isReviewLoading = false;
  bool _isGalleryLoading = false;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    currentModel = widget.model;
    // Profile image is now owned by ProfileImageStore — just nudge it.
    ProfileImageStore.instance.ensureLoaded();
    _fetchGalleryImages(currentModel);
    _fetchLastEvaluationFromAPI(currentModel.placeId);
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
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

  Future<void> _fetchGalleryImages(SuggestionItemModel model) async {
    final placeUuid = model.placeUuid;
    if (placeUuid == null || placeUuid.isEmpty) {
      if (!_isMounted) return;
      setState(() => galleryImages = [model.image]);
      return;
    }

    if (!_isMounted) return;
    setState(() => _isGalleryLoading = true);
    try {
      final images =
          await _apiService.fetchPlaceGalleryImages(placeUuid: placeUuid);
      if (!_isMounted) return;
      setState(() {
        galleryImages = images.isNotEmpty ? images : [model.image];
      });
    } catch (_) {
      if (!_isMounted) return;
      setState(() => galleryImages = [model.image]);
    } finally {
      if (_isMounted) {
        setState(() => _isGalleryLoading = false);
      }
    }
  }

  void updateModel(SuggestionItemModel newModel) {
    if (!_isMounted) return;
    setState(() {
      currentModel = newModel;
    });
    _fetchGalleryImages(newModel);
    _fetchLastEvaluationFromAPI(newModel.placeId);
  }

  @override
  Widget build(BuildContext context) {
    // "فعاليات مشابهة" — strict match on city + activity + budget.
    //
    // The user explicitly asked for "نفس المدينة + نفس النشاط + نفس
    // الميزانية" so we filter on all three. If the strict match returns
    // nothing (small city, niche activity) we relax the budget filter first
    // — same city + same activity is still a meaningful suggestion. If even
    // that's empty, fall back to "same city" so the section never goes
    // dark with content available.
    bool sameCity(SuggestionItemModel other) =>
        other.city.trim() == currentModel.city.trim();
    bool sameActivity(SuggestionItemModel other) =>
        other.suggestionText.trim() == currentModel.suggestionText.trim();
    bool sameBudget(SuggestionItemModel other) =>
        other.price.trim() == currentModel.price.trim();

    final pool = widget.suggestionItemList
        .where((item) => item != currentModel)
        .toList();

    var filteredSuggestions = pool
        .where((i) => sameCity(i) && sameActivity(i) && sameBudget(i))
        .toList();
    if (filteredSuggestions.isEmpty) {
      filteredSuggestions =
          pool.where((i) => sameCity(i) && sameActivity(i)).toList();
    }
    if (filteredSuggestions.isEmpty) {
      filteredSuggestions = pool.where(sameCity).toList();
    }

    return AppPageScaffold(
      unpadded: true,
      header: AppPageHeader(
        title: AppCopy.detailsTitle,
        actions: [
          AppHeaderAction(
            icon: Icons.flag_outlined,
            semanticLabel: 'بلّغ عن هذا المكان',
            onTap: () => _openReportSheet(context, currentModel),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w,
          AppSpacing.lg.h,
          AppSpacing.lg.w,
          AppSpacing.huge.h * 2,
        ),
        children: [
          _DetailsSection(
            model: currentModel,
            galleryImages: galleryImages,
            isLoading: _isGalleryLoading,
          ),
          gapV(AppSpacing.xxl),
          _ReviewsSection(
            placeId: currentModel.placeId,
            isLoading: _isReviewLoading && lastEvaluation == null,
            lastEvaluation: lastEvaluation,
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

  void _openReportSheet(BuildContext context, SuggestionItemModel place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (_) => _ReportSheet(place: place),
    );
  }
}

// ===========================================================================
// Sections
// ===========================================================================

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.model,
    required this.galleryImages,
    required this.isLoading,
  });

  final SuggestionItemModel model;
  final List<String> galleryImages;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          DetailsItem(
            model: model,
            galleryImages: galleryImages,
            isLoading: isLoading,
          ),
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
    required this.onOpenAll,
  });

  final int placeId;
  final bool isLoading;
  final EvaluationsItemModel? lastEvaluation;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 120.h,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
          ),
        ),
      );
    } else if (lastEvaluation != null) {
      child = CustomEvaluations(
        placeId: placeId,
        lastEvaluation: lastEvaluation,
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
        border: Border.all(color: AppColor.primary.withValues(alpha: 0.2)),
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

// ===========================================================================
// Report sheet — user-facing abuse / content report
// ===========================================================================
//
// Opens from the flag icon in the AppPageHeader. Lets the user pick a reason
// code from a short whitelist and add optional details, then writes a row to
// `moderation_reports` via the submit_abuse_report SECURITY DEFINER RPC.
// Admins see it in /dashboard/reports.

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.place});
  final SuggestionItemModel place;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = <_ReasonOption>[
    _ReasonOption('spam',       'إعلانات مزعجة'),
    _ReasonOption('offensive',  'محتوى مسيء'),
    _ReasonOption('fake',       'معلومات مزيفة'),
    _ReasonOption('off_topic',  'خارج الموضوع'),
    _ReasonOption('illegal',    'محتوى غير قانوني'),
    _ReasonOption('harassment', 'تحرش'),
    _ReasonOption('other',      'أخرى'),
  ];

  String? _selected;
  final _detailsCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      AppFeedback.warning('من فضلك اختر سبب البلاغ');
      return;
    }
    final uuid = widget.place.placeUuid;
    if (uuid == null || uuid.isEmpty) {
      AppFeedback.error('لا يمكن تقديم البلاغ على هذا المكان');
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.ensureSupabaseInitialized();
      await Supabase.instance.client.rpc<dynamic>(
        'submit_abuse_report',
        params: {
          '_target_type': 'place',
          '_target_id':   uuid,
          '_reason_code': _selected,
          '_details':     _detailsCtrl.text.trim().isEmpty
              ? null
              : _detailsCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      AppFeedback.success('وصلنا بلاغك، هنراجعه قريباً ✅');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) AppFeedback.error('معرفناش نبعت البلاغ، جرّب تاني');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl.w,
        AppSpacing.lg.h,
        AppSpacing.xxl.w,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColor.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          gapV(AppSpacing.xl),
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: AppColor.error.withValues(alpha: 0.12),
                  borderRadius: AppRadii.rMd,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.flag_outlined,
                    color: AppColor.error, size: 22.sp),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بلّغ عن هذا المكان',
                      style: AppText.titleMd
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      widget.place.text,
                      style: AppText.bodySm
                          .copyWith(color: AppColor.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          gapV(AppSpacing.lg),
          Text(
            'اختر سبب البلاغ',
            style: AppText.labelMd.copyWith(
              color: AppColor.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          gapV(AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: _reasons.map((r) {
              final selected = _selected == r.code;
              return GestureDetector(
                onTap: () => setState(() => _selected = r.code),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w,
                    vertical: AppSpacing.sm.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColor.primary
                        : AppColor.surface,
                    borderRadius: AppRadii.rPill,
                    border: Border.all(
                      color: selected ? AppColor.primary : AppColor.border,
                    ),
                  ),
                  child: Text(
                    r.label,
                    style: AppText.labelMd.copyWith(
                      color: selected ? AppColor.white : AppColor.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          gapV(AppSpacing.lg),
          TextField(
            controller: _detailsCtrl,
            maxLines: 4,
            textDirection: TextDirection.rtl,
            style: AppText.bodyMd,
            decoration: InputDecoration(
              hintText: 'تفاصيل إضافية (اختياري)',
              hintStyle: AppText.bodyMd.copyWith(color: AppColor.textMuted),
              filled: true,
              fillColor: AppColor.surface,
              contentPadding: EdgeInsets.all(AppSpacing.md.w),
              border: OutlineInputBorder(
                borderRadius: AppRadii.rMd,
                borderSide: const BorderSide(color: AppColor.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.rMd,
                borderSide: const BorderSide(color: AppColor.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.rMd,
                borderSide:
                    const BorderSide(color: AppColor.primary, width: 1.5),
              ),
            ),
          ),
          gapV(AppSpacing.xl),
          AppButton(
            text: 'إرسال البلاغ',
            onPress: _submit,
            isEnabled: !_sending,
          ),
        ],
      ),
    );
  }
}

class _ReasonOption {
  const _ReasonOption(this.code, this.label);
  final String code;
  final String label;
}
