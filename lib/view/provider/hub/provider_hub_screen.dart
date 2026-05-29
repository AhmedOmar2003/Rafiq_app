import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/details/details_page.dart';
import 'package:rafiq_app/view/pages/choice/take_data_screen.dart';
import 'package:rafiq_app/view/home/widget/stepper_component.dart';
import 'package:rafiq_app/view/provider/analytics/analytics_screen.dart';
import 'package:rafiq_app/view/provider/promotions/promotions_screen.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';
import 'package:rafiq_app/core/utils/assets.dart';

/// Central provider dashboard.
///
/// Aggregates: current plan summary card, KPI strip with the live limits
/// from [ProviderEntitlement], and four big tiles for the main provider
/// surfaces (Places, Analytics, Promotions, Subscription).
///
/// Locked tiles (Analytics/Promotions on Free) keep the same layout so the
/// hub doesn't reflow when the user upgrades — instead the lock overlay
/// fades out. That makes the difference between Free and Pro feel like an
/// "unlock", not a redesign.
class ProviderHubScreen extends StatefulWidget {
  const ProviderHubScreen({super.key, this.providerId, this.providerName});

  final String? providerId;
  final String? providerName;

  @override
  State<ProviderHubScreen> createState() => _ProviderHubScreenState();
}

class _ProviderHubScreenState extends State<ProviderHubScreen> {
  String? _providerId;
  String? _providerName;
  List<Place> _places = const [];
  bool _loadingPlaces = false;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.loadCatalog();
    _bootstrapHub();
  }

  Future<void> _bootstrapProviderState(String providerId) async {
    await SubscriptionService.instance.loadEntitlement(providerId);
    await _loadProviderPlaces(providerId);
  }

  Future<void> _bootstrapHub() async {
    if (mounted) {
      setState(() => _isBootstrapping = true);
    }
    try {
      final resolved =
          widget.providerId ?? await ApiService().ensureCurrentProviderId();
      if (!mounted) return;
      if (resolved == null || resolved.isEmpty) {
        setState(() {
          _providerId = null;
          _providerName = widget.providerName;
          _places = const [];
        });
        return;
      }
      setState(() {
        _providerId = resolved;
        _providerName = widget.providerName ?? _providerName;
      });
      await _bootstrapProviderState(resolved);
    } catch (_) {
      // Keep the free fallback; the hub still opens and shows the catalog.
      if (mounted) {
        setState(() {
          _providerId = null;
          _places = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  Future<void> _loadProviderPlaces(String providerId) async {
    if (!mounted) return;
    setState(() => _loadingPlaces = true);
    try {
      final places =
          await ApiService().fetchProviderPlaces(providerId: providerId);
      if (!mounted) return;
      setState(() => _places = places);
    } catch (_) {
      if (!mounted) return;
      setState(() => _places = const []);
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  Future<void> _refreshHub() async {
    final pid = _providerId;
    if (pid == null) {
      await _bootstrapHub();
      return;
    }
    await SubscriptionService.instance.loadEntitlement(pid, force: true);
    await _loadProviderPlaces(pid);
  }

  Future<void> _openAddPlace() async {
    var pid = _providerId ?? widget.providerId;
    pid ??= await ApiService().ensureCurrentProviderId();
    if (!mounted || pid == null) {
      await _bootstrapHub();
      return;
    }
    if (_providerId != pid) {
      setState(() {
        _providerId = pid;
      });
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(providerId: pid),
      ),
    );
    if (result == true) {
      await _refreshHub();
    }
  }

  Future<void> _previewPlace(Place place) async {
    final previewModel = SuggestionItemModel.fromPlace(place);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsPage(
          model: previewModel,
          suggestionItemList: _places
              .map((p) => SuggestionItemModel.fromPlace(p))
              .toList(growable: false),
        ),
      ),
    );
    final pid = _providerId ?? widget.providerId;
    if (pid != null) {
      await _loadProviderPlaces(pid);
    }
  }

  Future<void> _editPlace(Place place) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(
          editingPlace: place,
          providerId: _providerId ?? widget.providerId,
        ),
      ),
    );
    if (result == true) {
      await _refreshHub();
    }
  }

  Future<void> _deletePlace(Place place) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف المكان',
      message: 'هل تريد حذف "${place.name}"؟',
      confirmLabel: 'حذف',
      cancelLabel: 'إلغاء',
      tone: AppConfirmTone.danger,
      icon: Icons.delete_rounded,
    );
    if (!confirmed) return;
    await ApiService().deletePlaceByIdentifier(
      placeUuid: place.placeUuid,
      legacyPlaceId: place.placeId,
    );
    await _refreshHub();
  }

  Future<void> _backgroundApp() async {
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return const AppPageScaffold(
        header: AppPageHeader(
          title: 'جارٍ تجهيز حسابك',
          actions: [ProfilePill()],
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_providerId == null) {
      return AppPageScaffold(
        header: const AppPageHeader(
          title: AppCopy.hubTitle,
          actions: [ProfilePill()],
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 56.sp,
                  color: AppColor.textTertiary,
                ),
                gapV(AppSpacing.md),
                Text(
                  'تعذر تجهيز بيانات الحساب الآن',
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.xs),
                Text(
                  'اضغط إعادة المحاولة أو اسحب لأسفل لتحديث البيانات.',
                  style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'إعادة المحاولة',
                    onPress: _bootstrapHub,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final placeCount = _places.length;
    final hubTitle = placeCount > 1 ? 'تابع خدماتك' : AppCopy.hubTitle;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backgroundApp();
      },
      child: AppPageScaffold(
        // "تابع خدمتك" — same identity post-subscription, no role flip.
        // No back arrow: this is a *root* surface; the user backgrounds the
        // app instead. Switching role lives in Profile.
        header: AppPageHeader(
          title: hubTitle,
          centerTitle: true,
          actions: const [ProfilePill()],
        ),
        body: ValueListenableBuilder<ProviderEntitlement>(
          valueListenable: SubscriptionService.instance.entitlement,
          builder: (_, ent, __) {
            return RefreshIndicator(
              onRefresh: _refreshHub,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxl.w,
                  AppSpacing.lg.h,
                  AppSpacing.xxl.w,
                  AppSpacing.huge.h,
                ),
                children: [
                  _Greeting(name: _providerName ?? widget.providerName),
                  gapV(AppSpacing.lg),
                  _PlanSummaryCard(
                    entitlement: ent,
                    onManage: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionScreen(
                          providerId: _providerId,
                        ),
                      ),
                    ),
                  ),
                  gapV(AppSpacing.lg),
                  _ProviderFlowCard(
                    placeCount: placeCount,
                    maxPlaces: ent.maxPlaces,
                    imagesPerPlace: ent.maxGalleryImages,
                    onAddPlace: _openAddPlace,
                    onRefresh: _refreshHub,
                    canAddPlace: ent.maxPlaces > placeCount,
                  ),
                  gapV(AppSpacing.lg),
                  _KpiStrip(entitlement: ent),
                  gapV(AppSpacing.xxl),
                  _PlacesSection(
                    places: _places,
                    loading: _loadingPlaces,
                    maxPlaces: ent.maxPlaces,
                    onPreviewPlace: _previewPlace,
                    onEditPlace: _editPlace,
                    onDeletePlace: _deletePlace,
                    onAddPlace: _openAddPlace,
                  ),
                  gapV(AppSpacing.xxl),
                  _FeatureTile(
                    icon: Icons.bar_chart_rounded,
                    title: AppCopy.hubFeatTitleAnalytics,
                    body: AppCopy.hubFeatBodyAnalytics,
                    lockedLabel:
                        ent.hasAnalyticsBasic ? null : AppCopy.hubLockedTag,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalyticsScreen(
                          providerId: _providerId,
                        ),
                      ),
                    ),
                  ),
                  gapV(AppSpacing.md),
                  _FeatureTile(
                    icon: Icons.campaign_rounded,
                    title: AppCopy.hubFeatTitlePromotions,
                    body: AppCopy.hubFeatBodyPromotions,
                    lockedLabel:
                        ent.hasPromotions ? null : AppCopy.hubLockedTag,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromotionsScreen(
                          providerId: _providerId,
                        ),
                      ),
                    ),
                  ),
                  gapV(AppSpacing.md),
                  _FeatureTile(
                    icon: Icons.workspace_premium_rounded,
                    title: AppCopy.hubFeatTitleSubscription,
                    body: AppCopy.hubFeatBodySubscription,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionScreen(
                          providerId: _providerId,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================================
// Greeting
// ===========================================================================

class _Greeting extends StatelessWidget {
  const _Greeting({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final greeting = name != null && name!.isNotEmpty
        ? '${AppCopy.hubGreetingPrefix}، $name 👋'
        : '${AppCopy.hubGreetingPrefix} 👋';
    return Text(
      greeting,
      style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

// ===========================================================================
// Plan summary card
// ===========================================================================

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.entitlement, required this.onManage});

  final ProviderEntitlement entitlement;
  final VoidCallback onManage;

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = entitlement.tier != PlanTier.free;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.xxl.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(AppCopy.hubCurrentPlan, style: AppText.caption),
              const Spacer(),
              PlanBadge(tier: entitlement.tier, size: PlanBadgeSize.header),
            ],
          ),
          gapV(AppSpacing.sm),
          if (isPaid) ...[
            Row(
              children: [
                Icon(Icons.event_repeat_rounded,
                    color: AppColor.textSecondary, size: 16.sp),
                gapH(AppSpacing.xs),
                Text(
                  '${AppCopy.subRenewsOn} ${_formatDate(entitlement.periodEnd)}',
                  style: AppText.bodySm,
                ),
              ],
            ),
            gapV(AppSpacing.md),
          ] else ...[
            Text(
              AppCopy.subFreeForever,
              style: AppText.titleMd.copyWith(color: AppColor.textPrimary),
            ),
            gapV(AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: isPaid ? AppCopy.hubManagePlan : AppCopy.subUpgrade,
              onPress: onManage,
              variant:
                  isPaid ? AppButtonVariant.outline : AppButtonVariant.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// KPI strip
// ===========================================================================

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.entitlement});
  final ProviderEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    String unlimited(int v) =>
        v >= 999 ? AppCopy.subFeatureUnlimited : v.toString();

    return Row(
      children: [
        Expanded(
          child: _KpiCell(
            icon: Icons.store_rounded,
            label: AppCopy.hubKpiPlaces,
            value: unlimited(entitlement.maxPlaces),
          ),
        ),
        gapH(AppSpacing.sm),
        Expanded(
          child: _KpiCell(
            icon: Icons.photo_library_rounded,
            label: AppCopy.hubKpiImages,
            value: unlimited(entitlement.maxGalleryImages),
          ),
        ),
        gapH(AppSpacing.sm),
        Expanded(
          child: _KpiCell(
            icon: Icons.insights_rounded,
            label: AppCopy.hubKpiAnalytics,
            value: entitlement.hasAnalyticsPro
                ? 'PRO'
                : (entitlement.hasAnalyticsBasic ? '✓' : '—'),
          ),
        ),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.lg.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColor.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColor.primary, size: 20.sp),
          gapV(AppSpacing.sm),
          Text(
            value,
            style: AppText.titleLg.copyWith(fontWeight: FontWeight.w800),
          ),
          gapV(AppSpacing.xs),
          Text(
            label,
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Feature tile
// ===========================================================================

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.lockedLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final String? lockedLabel;

  @override
  Widget build(BuildContext context) {
    final locked = lockedLabel != null;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: locked ? AppColor.neutral100 : AppColor.primary50,
              borderRadius: AppRadii.rMd,
            ),
            child: Icon(
              icon,
              color: locked ? AppColor.textTertiary : AppColor.primary,
              size: 24.sp,
            ),
          ),
          gapH(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.titleMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: locked
                              ? AppColor.textSecondary
                              : AppColor.textPrimary,
                        ),
                      ),
                    ),
                    if (locked)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColor.warningBg,
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                color: AppColor.warning, size: 12.sp),
                            gapH(AppSpacing.xs),
                            Text(
                              lockedLabel!,
                              style: AppText.caption.copyWith(
                                color: AppColor.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                gapV(AppSpacing.xs / 2),
                Text(
                  body,
                  style: AppText.bodySm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded,
              color: AppColor.textTertiary, size: 24.sp),
        ],
      ),
    );
  }
}

// ===========================================================================
// Provider flow summary + places list
// ===========================================================================

class _ProviderFlowCard extends StatelessWidget {
  const _ProviderFlowCard({
    required this.placeCount,
    required this.maxPlaces,
    required this.imagesPerPlace,
    required this.onAddPlace,
    required this.onRefresh,
    required this.canAddPlace,
  });

  final int placeCount;
  final int maxPlaces;
  final int imagesPerPlace;
  final VoidCallback onAddPlace;
  final VoidCallback onRefresh;
  final bool canAddPlace;

  @override
  Widget build(BuildContext context) {
    final stepIndex = placeCount <= 0 ? 0 : (placeCount == 1 ? 1 : 2);
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  placeCount > 1 ? 'تابع خدماتك' : 'شوف مكانك',
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              AppButton(
                text: 'تحديث',
                onPress: onRefresh,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                isFullWidth: false,
              ),
            ],
          ),
          gapV(AppSpacing.xs),
          Text(
            placeCount == 0
                ? 'ابدأ بإضافة مكانك الأول، وبعدها هتشوف لوحة التحكم كاملة.'
                : 'عندك $placeCount من $maxPlaces أماكن. كل مكان يقدر يحمل حتى $imagesPerPlace صورة حسب الخطة.',
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          gapV(AppSpacing.lg),
          SizedBox(
            height: 88.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepperComponent(
                  index: 0,
                  currentIndex: stepIndex,
                  onTap: onRefresh,
                  icon: AppImages.money,
                  label: 'الخطة',
                ),
                StepperComponent(
                  index: 1,
                  currentIndex: stepIndex,
                  onTap: onAddPlace,
                  icon: AppImages.location,
                  label: 'أماكنك',
                ),
                StepperComponent(
                  index: 2,
                  currentIndex: stepIndex,
                  onTap: onRefresh,
                  icon: AppImages.search,
                  label: 'Preview',
                  isLast: true,
                ),
              ],
            ),
          ),
          gapV(AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'أماكنك',
                  value: '$placeCount/$maxPlaces',
                ),
              ),
              gapH(AppSpacing.sm),
              Expanded(
                child: _MiniStat(
                  label: 'صور لكل مكان',
                  value: imagesPerPlace >= 999 ? '∞' : '$imagesPerPlace',
                ),
              ),
            ],
          ),
          gapV(AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: canAddPlace ? 'أضف مكان جديد' : 'وصلت الحد',
              onPress: canAddPlace ? onAddPlace : onRefresh,
              variant: canAddPlace
                  ? AppButtonVariant.primary
                  : AppButtonVariant.outline,
              isEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesSection extends StatelessWidget {
  const _PlacesSection({
    required this.places,
    required this.loading,
    required this.maxPlaces,
    required this.onPreviewPlace,
    required this.onEditPlace,
    required this.onDeletePlace,
    required this.onAddPlace,
  });

  final List<Place> places;
  final bool loading;
  final int maxPlaces;
  final ValueChanged<Place> onPreviewPlace;
  final ValueChanged<Place> onEditPlace;
  final ValueChanged<Place> onDeletePlace;
  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'أماكني',
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${places.length}/$maxPlaces',
                style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          gapV(AppSpacing.sm),
          Text(
            places.isEmpty
                ? 'أضف مكانك الأول، وبعدها هتلاقيه هنا عشان تعدّل أو تحذف أو تعمل Preview.'
                : 'كل مكان تقدر تديره من هنا بسرعة.',
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          gapV(AppSpacing.lg),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (places.isEmpty)
            _EmptyPlacesState(onAddPlace: onAddPlace)
          else
            ListView.separated(
              itemCount: places.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => gapV(AppSpacing.md),
              itemBuilder: (_, index) {
                final place = places[index];
                return _PlaceCard(
                  place: place,
                  onPreview: () => onPreviewPlace(place),
                  onEdit: () => onEditPlace(place),
                  onDelete: () => onDeletePlace(place),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceMuted,
        borderRadius: AppRadii.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption),
          gapV(AppSpacing.xs),
          Text(
            value,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlacesState extends StatelessWidget {
  const _EmptyPlacesState({required this.onAddPlace});

  final VoidCallback onAddPlace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92.w,
          height: 92.w,
          decoration: const BoxDecoration(
            color: AppColor.primary50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.store_mall_directory_rounded,
              color: AppColor.primary, size: 42.sp),
        ),
        gapV(AppSpacing.lg),
        Text(
          'لسه ما أضفتش أي مكان',
          style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
        ),
        gapV(AppSpacing.sm),
        Text(
          'أضف مكانك الأول عشان تبدأ اللوحة وتظهر كل الإحصائيات.',
          style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
        gapV(AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'أضف مكانك الآن',
            onPress: onAddPlace,
          ),
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onPreview,
    required this.onEdit,
    required this.onDelete,
  });

  final Place place;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cover = place.imageUrl?.trim() ?? '';
    final model = SuggestionItemModel.fromPlace(place);
    return Container(
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            child: SizedBox(
              height: 172.h,
              width: double.infinity,
              child: cover.isNotEmpty
                  ? Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placePlaceholder(),
                    )
                  : _placePlaceholder(),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: AppText.titleMd.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PlanBadge(
                      tier: SubscriptionService.instance.entitlement.value.tier,
                    ),
                  ],
                ),
                gapV(AppSpacing.xs),
                Text(
                  '${place.cityName} • ${place.activityName}',
                  style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
                ),
                gapV(AppSpacing.xs),
                Text(
                  place.description,
                  style: AppText.bodySm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                gapV(AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Preview كما يراه المستخدم',
                        onPress: onPreview,
                        size: AppButtonSize.sm,
                      ),
                    ),
                  ],
                ),
                gapV(AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'تعديل',
                        onPress: onEdit,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.outline,
                      ),
                    ),
                    gapH(AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        text: 'حذف',
                        onPress: onDelete,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.destructive,
                      ),
                    ),
                  ],
                ),
                gapV(AppSpacing.sm),
                Text(
                  model.address,
                  style:
                      AppText.caption.copyWith(color: AppColor.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placePlaceholder() {
    return Container(
      color: AppColor.neutral100,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColor.textTertiary, size: 38.sp),
      ),
    );
  }
}
