import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Supabase realtime channel listening for INSERT/UPDATE/DELETE on places
  /// owned by the current provider. The admin's approve/reject action in the
  /// web dashboard writes to the same row; the channel fires, we refresh the
  /// list, the user sees the new status without ever leaving the hub.
  RealtimeChannel? _placesChannel;

  /// Track which place ids we've already shown a "status changed" toast for
  /// in this session, so a rebuild doesn't double-fire the snackbar.
  final Set<String> _notifiedStatusChange = <String>{};

  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.loadCatalog();
    _bootstrapHub();
  }

  @override
  void dispose() {
    _placesChannel?.unsubscribe();
    _placesChannel = null;
    super.dispose();
  }

  Future<void> _bootstrapProviderState(String providerId) async {
    await SubscriptionService.instance.loadEntitlement(providerId);
    await _loadProviderPlaces(providerId, forceRefresh: true);
    _subscribeToPlacesRealtime(providerId);
  }

  /// Open a realtime channel on `public.places` filtered to this provider's
  /// rows. The admin dashboard's approve/reject server action writes to the
  /// same row and the Postgres logical replication slot fires this stream —
  /// usually within ~300ms of the admin click. We then refetch the full list
  /// (cheap with the indexes from 0025) so the UI always reflects the truth.
  ///
  /// The channel is closed in [dispose] and re-opened if the provider id
  /// changes (e.g. account switch within a session).
  void _subscribeToPlacesRealtime(String providerId) {
    _placesChannel?.unsubscribe();
    final client = Supabase.instance.client;
    final channel = client.channel('places:provider:$providerId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'places',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'provider_id',
        value: providerId,
      ),
      callback: (payload) {
        if (!mounted) return;
        // Surface a toast for status transitions so the provider notices
        // even if they're scrolling somewhere else on the hub.
        final newRow = payload.newRecord;
        final oldRow = payload.oldRecord;
        final newStatus = newRow['status']?.toString();
        final oldStatus = oldRow['status']?.toString();
        final placeId = newRow['id']?.toString() ?? '';
        if (newStatus != null &&
            oldStatus != null &&
            newStatus != oldStatus &&
            placeId.isNotEmpty &&
            !_notifiedStatusChange.contains('$placeId:$newStatus')) {
          _notifiedStatusChange.add('$placeId:$newStatus');
          final name = newRow['place_name']?.toString() ??
              newRow['name']?.toString() ??
              'مكانك';
          switch (newStatus) {
            case 'approved':
              AppFeedback.success('تم اعتماد "$name" — ظاهر للجمهور دلوقتي');
              break;
            case 'rejected':
              AppFeedback.warning('تم رفض "$name" — راجع السبب وعدّل');
              break;
            case 'suspended':
              AppFeedback.warning('تم تعليق "$name" مؤقتاً');
              break;
            case 'pending':
              AppFeedback.info('"$name" رجع للمراجعة');
              break;
          }
        }
        // Always refetch to keep the list authoritative — cheaper than
        // patching rows by hand and avoids edge cases on delete events.
        _loadProviderPlaces(providerId);
      },
    );
    channel.subscribe();
    _placesChannel = channel;
  }

  Future<String?> _resolveProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    const delays = <Duration>[
      Duration(milliseconds: 180),
      Duration(milliseconds: 320),
      Duration(milliseconds: 480),
    ];

    for (var attempt = 0; attempt <= delays.length; attempt++) {
      final cachedId =
          widget.providerId ?? _providerId ?? prefs.getString('providerId');
      if (cachedId != null && cachedId.isNotEmpty) {
        return cachedId;
      }

      final resolved = await ApiService().ensureCurrentProviderId();
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }

      if (attempt < delays.length) {
        await Future.delayed(delays[attempt]);
      }
    }

    return null;
  }

  Future<void> _bootstrapHub() async {
    if (mounted) {
      setState(() => _isBootstrapping = true);
    }
    try {
      final resolved = await _resolveProviderId();
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
      try {
        await _bootstrapProviderState(resolved);
      } catch (_) {
        if (!mounted) return;
        setState(() => _places = const []);
      }
    } catch (_) {
      // Keep the free fallback; the hub still opens and shows the catalog.
      if (mounted) {
        setState(() {
          _places = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  Future<void> _loadProviderPlaces(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    setState(() => _loadingPlaces = true);
    try {
      final places = await ApiService().fetchProviderPlaces(
        providerId: providerId,
        forceRefresh: forceRefresh,
      );
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
    await _loadProviderPlaces(pid, forceRefresh: true);
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
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_providerId == null) {
      return AppPageScaffold(
        header: const AppPageHeader(
          title: AppCopy.hubTitle,
          actions: [ProfilePill()],
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
          actions: const [ProfilePill()],
        ),
        body: ValueListenableBuilder<ProviderEntitlement>(
          valueListenable: SubscriptionService.instance.entitlement,
          builder: (_, ent, __) {
            return RefreshIndicator(
              onRefresh: _refreshHub,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Horizontal gutter == AppPageHeader's horizontal padding
                // (lg.w == 16). Keeps the page title vertically aligned
                // with the body content directly underneath.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg.w,
                  AppSpacing.lg.h,
                  AppSpacing.lg.w,
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
                  // Surface anything that's still pending admin review at the
                  // top so the user always knows what the admin is sitting on.
                  if (_places.any((p) => _isAwaitingModeration(p.status)))
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
                      child: _ReviewQueueCard(
                        pendingPlaces: _places
                            .where((p) => _isAwaitingModeration(p.status))
                            .toList(),
                      ),
                    ),
                  // Rejected places also get a glance card so the user can
                  // act on the rejection reason and resubmit.
                  if (_places.any((p) => p.status == 'rejected'))
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
                      child: _RejectedCard(
                        rejectedPlaces:
                            _places.where((p) => p.status == 'rejected').toList(),
                        onEditPlace: _editPlace,
                      ),
                    ),
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

bool _isAwaitingModeration(String? status) {
  final normalized = status?.trim().toLowerCase();
  return normalized == 'pending' || normalized == 'under_review';
}

// ===========================================================================
// Review queue card — 24-hour countdown for pending places
// ===========================================================================
//
// While a place sits in `pending` state, this card keeps the provider in the
// loop: it lists every awaiting submission with a live HH:MM:SS countdown
// from the 24-hour SLA window. The admin can flip a place to `approved` /
// `rejected` at any moment from the web dashboard; the provider sees the
// state change on the next pull-to-refresh of the hub.
//
// Intentionally simple: no animations beyond the per-second tick, no
// network calls of its own — it just reflects whatever the parent fetched.

class _ReviewQueueCard extends StatefulWidget {
  const _ReviewQueueCard({required this.pendingPlaces});
  final List<Place> pendingPlaces;

  @override
  State<_ReviewQueueCard> createState() => _ReviewQueueCardState();
}

class _ReviewQueueCardState extends State<_ReviewQueueCard> {
  static const Duration _slaWindow = Duration(hours: 24);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatRemaining(DateTime? createdAt) {
    if (createdAt == null) return 'جارٍ الاحتساب';
    final deadline = createdAt.add(_slaWindow);
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'انتهت المهلة';
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColor.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadii.rMd,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColor.warning,
                  size: 22.sp,
                ),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قيد المراجعة',
                      style: AppText.titleMd
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'مهلة المراجعة 24 ساعة من وقت الإضافة',
                      style: AppText.bodySm.copyWith(
                        color: AppColor.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          gapV(AppSpacing.md),
          ...widget.pendingPlaces.map((p) {
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.sm.h,
                ),
                decoration: BoxDecoration(
                  color: AppColor.warning.withValues(alpha: 0.08),
                  borderRadius: AppRadii.rMd,
                  border: Border.all(
                    color: AppColor.warning.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: AppText.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          gapV(2),
                          Text(
                            '${p.cityName} — ${p.activityName}',
                            style: AppText.caption.copyWith(
                              color: AppColor.textSecondary,
                            ),
                          ),
                          gapV(4),
                          Text(
                            p.status == 'under_review'
                                ? 'المكان قيد المراجعة الآن'
                                : 'المكان في انتظار بدء المراجعة',
                            style: AppText.caption.copyWith(
                              color: AppColor.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    gapH(AppSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.surfaceCard,
                        borderRadius: AppRadii.rSm,
                        border: Border.all(color: AppColor.warning),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 12.sp, color: AppColor.warning),
                          gapH(AppSpacing.xs),
                          Text(
                            _formatRemaining(p.createdAt),
                            style: AppText.labelSm.copyWith(
                              color: AppColor.warning,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ===========================================================================
// Rejected places card — surface admin feedback so the provider can fix +
// resubmit. Same visual rhythm as the review queue card so the user reads
// both as part of the same "moderation" section.
// ===========================================================================
// Rejected places card + Appeal flow
// ===========================================================================
class _RejectedCard extends StatelessWidget {
  const _RejectedCard({
    required this.rejectedPlaces,
    required this.onEditPlace,
  });
  final List<Place> rejectedPlaces;
  final ValueChanged<Place> onEditPlace;

  void _openAppealSheet(BuildContext context, Place place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.topOnly(AppRadii.xxl)),
      builder: (_) => _AppealSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColor.error.withValues(alpha: 0.12),
                  borderRadius: AppRadii.rMd,
                ),
                child: Icon(Icons.cancel_outlined, color: AppColor.error, size: 22.sp),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تم رفض الإضافة',
                        style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800)),
                    Text('راجع السبب وعدّل أو قدّم طعناً',
                        style: AppText.bodySm.copyWith(color: AppColor.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          gapV(AppSpacing.md),
          ...rejectedPlaces.map((p) {
            final reason = (p.rejectionReason ?? '').trim();
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
              child: Container(
                padding: EdgeInsets.all(AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: AppColor.error.withValues(alpha: 0.06),
                  borderRadius: AppRadii.rMd,
                  border: Border.all(color: AppColor.error.withValues(alpha: 0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                    if (reason.isNotEmpty) ...[
                      gapV(AppSpacing.xs),
                      Text('السبب: $reason',
                          style: AppText.bodySm
                              .copyWith(color: AppColor.textSecondary)),
                    ],
                    gapV(AppSpacing.sm),
                    // When the admin opened the edit-and-resubmit door we
                    // surface a prominent primary CTA — the appeal path is
                    // secondary in that case. Otherwise only the appeal CTA
                    // shows, since editing isn't allowed.
                    if (p.editAllowed) ...[
                      // Hint chip — let the provider know they have a fix path
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColor.success.withValues(alpha: 0.12),
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open_rounded,
                                size: 14.sp, color: AppColor.success),
                            gapH(AppSpacing.xs),
                            Text(
                              'سمحنالك تعدّل وترجّعه للمراجعة',
                              style: AppText.labelSm.copyWith(
                                color: AppColor.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      gapV(AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'عدّل وارجّعه',
                              onPress: () => onEditPlace(p),
                            ),
                          ),
                          gapH(AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openAppealSheet(context, p),
                              icon: Icon(Icons.gavel_rounded,
                                  size: 14.sp, color: AppColor.primary),
                              label: Text(
                                'طعن',
                                style: AppText.labelMd.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: AppColor.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadii.rMd,
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm.h),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      // Edit locked → appeal is the only path forward
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openAppealSheet(context, p),
                          icon: Icon(Icons.gavel_rounded,
                              size: 16.sp, color: AppColor.primary),
                          label: Text(
                            AppCopy.appealTitle,
                            style: AppText.labelMd.copyWith(
                              color: AppColor.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColor.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadii.rMd,
                            ),
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appeal bottom sheet
// ---------------------------------------------------------------------------
class _AppealSheet extends StatefulWidget {
  const _AppealSheet({required this.place});
  final Place place;

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name    = _nameCtrl.text.trim();
    final phone   = _phoneCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || message.isEmpty) {
      AppFeedback.warning('من فضلك اكمل جميع الحقول');
      return;
    }
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(phone)) {
      AppFeedback.warning('رقم الموبايل غير صحيح');
      return;
    }

    setState(() => _sending = true);
    try {
      // Write directly to the place_appeals table via the SECURITY DEFINER
      // RPC. The admin reads it from /dashboard/appeals and contacts the
      // provider on the phone/email of their choice. No mailto, no leaving
      // the app.
      await ApiService.ensureSupabaseInitialized();
      await Supabase.instance.client.rpc<dynamic>(
        'submit_place_appeal',
        params: {
          '_place_id':      widget.place.placeId,
          '_contact_name':  name,
          '_contact_phone': phone,
          '_message':       message,
        },
      );
      if (!mounted) return;
      AppFeedback.success(AppCopy.appealSentSuccess);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppFeedback.error(AppCopy.appealSentFail);
      }
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
          // Handle
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
          Text(AppCopy.appealTitle,
              style: AppText.headingSm.copyWith(fontWeight: FontWeight.w800)),
          gapV(AppSpacing.xs),
          Text(AppCopy.appealSubtitle,
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary)),
          gapV(AppSpacing.lg),
          // Place name (read-only)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: AppRadii.rMd,
              border: Border.all(color: AppColor.border),
            ),
            child: Text(
              '📍 ${widget.place.name}',
              style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          gapV(AppSpacing.md),
          _Field(controller: _nameCtrl,    hint: AppCopy.appealNameHint,    icon: Icons.person_outline),
          gapV(AppSpacing.md),
          _Field(controller: _phoneCtrl,   hint: AppCopy.appealPhoneHint,   icon: Icons.phone_outlined,
              inputType: TextInputType.phone),
          gapV(AppSpacing.md),
          _Field(controller: _messageCtrl, hint: AppCopy.appealPlaceholder, icon: Icons.chat_outlined,
              maxLines: 4),
          gapV(AppSpacing.xl),
          AppButton(
            text: AppCopy.appealSend,
            onPress: _send,
            isEnabled: !_sending,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.inputType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? inputType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      textDirection: TextDirection.rtl,
      style: AppText.bodyMd,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.bodyMd.copyWith(color: AppColor.textMuted),
        prefixIcon: Icon(icon, size: 20.sp, color: AppColor.textSecondary),
        filled: true,
        fillColor: AppColor.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.md.h,
        ),
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
          borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
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
                gapV(AppSpacing.sm),
                _PlaceModerationBanner(
                  status: place.status,
                  createdAt: place.createdAt,
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

class _PlaceModerationBanner extends StatefulWidget {
  const _PlaceModerationBanner({
    required this.status,
    required this.createdAt,
  });

  final String status;
  final DateTime? createdAt;

  @override
  State<_PlaceModerationBanner> createState() => _PlaceModerationBannerState();
}

class _PlaceModerationBannerState extends State<_PlaceModerationBanner> {
  static const Duration _slaWindow = Duration(hours: 24);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatRemaining(DateTime? createdAt) {
    if (createdAt == null) return 'جارٍ الاحتساب';
    final remaining = createdAt.add(_slaWindow).difference(DateTime.now());
    if (remaining.isNegative) return 'انتهت المهلة';
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final normalized = widget.status.trim().toLowerCase();
    final underReview = normalized == 'under_review';
    final awaitingReview = normalized == 'pending' || underReview;
    final rejected = normalized == 'rejected';
    final suspended = normalized == 'suspended';

    final Color tone = rejected
        ? AppColor.error
        : suspended
            ? AppColor.textSecondary
            : awaitingReview
                ? AppColor.warning
                : AppColor.success;
    final IconData icon = rejected
        ? Icons.cancel_outlined
        : suspended
            ? Icons.pause_circle_outline_rounded
            : awaitingReview
                ? (underReview
                    ? Icons.fact_check_outlined
                    : Icons.hourglass_top_rounded)
                : Icons.check_circle_outline_rounded;
    final String label = rejected
        ? 'تم الرفض'
        : suspended
            ? 'موقوف مؤقتًا'
            : awaitingReview
                ? (underReview ? 'قيد المراجعة الآن' : 'في انتظار المراجعة')
                : 'تم الاعتماد';
    final String? trailing =
        awaitingReview ? _formatRemaining(widget.createdAt) : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: AppRadii.rMd,
        border: Border.all(
          color: tone.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: tone,
          ),
          gapH(AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: AppText.labelSm.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) ...[
            gapH(AppSpacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: 3.h,
              ),
              decoration: BoxDecoration(
                color: AppColor.surfaceCard,
                borderRadius: AppRadii.rPill,
                border: Border.all(color: tone.withValues(alpha: 0.28)),
              ),
              child: Text(
                trailing,
                style: AppText.labelSm.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
