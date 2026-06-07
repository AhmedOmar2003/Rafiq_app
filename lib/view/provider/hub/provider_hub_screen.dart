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

enum _PlaceFilter { all, pending, approved, rejected, suspended }

class _ProviderHubScreenState extends State<ProviderHubScreen> {
  String? _providerId;
  String? _providerName;
  List<Place> _places = const [];
  bool _loadingPlaces = false;
  bool _isBootstrapping = true;
  _PlaceFilter _placeFilter = _PlaceFilter.all;

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
              AppFeedback.success(
                  AppCopy.hubPlaceApproved.replaceFirst('%s', name));
              break;
            case 'rejected':
              AppFeedback.warning(
                  AppCopy.hubPlaceRejected.replaceFirst('%s', name));
              break;
            case 'suspended':
              AppFeedback.warning(
                  AppCopy.hubPlaceSuspended.replaceFirst('%s', name));
              break;
            case 'pending':
              AppFeedback.info(
                  AppCopy.hubPlacePending.replaceFirst('%s', name));
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
    final status = place.status.trim().toLowerCase();
    if (status == 'approved') {
      if (place.editRequestStatus == 'pending') {
        AppFeedback.info(AppCopy.hubEditRequestPending);
        return;
      }
      if (place.editRequestStatus == 'submitted') {
        AppFeedback.info(AppCopy.hubEditRequestSubmitted);
        return;
      }
      if (!(place.editRequestStatus == 'approved' && place.editAllowed)) {
        final confirmed = await AppConfirmDialog.show(
          context,
          title: AppCopy.hubApprovedEditTitle,
          message: AppCopy.hubApprovedEditBody,
          confirmLabel: AppCopy.hubApprovedEditConfirm,
          cancelLabel: AppCopy.cancel,
          icon: Icons.edit_note_rounded,
        );
        if (!confirmed || !mounted) return;
        final placeUuid = place.placeUuid;
        if (placeUuid == null || placeUuid.isEmpty) {
          AppFeedback.error(AppCopy.hubEditRequestUnavailable);
          return;
        }
        try {
          await ApiService().requestPlaceEdit(placeUuid: placeUuid);
          AppFeedback.success(AppCopy.hubEditRequestSent);
          await _refreshHub();
        } catch (error) {
          AppFeedback.error(error.toString());
        }
        return;
      }
    } else if (status == 'suspended' ||
        (status == 'rejected' && !place.editAllowed)) {
      AppFeedback.warning(AppCopy.hubEditRequestUnavailable);
      return;
    }

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
      title: AppCopy.hubDeletePlaceTitle,
      message: AppCopy.hubDeletePlaceMessage.replaceFirst('%s', place.name),
      confirmLabel: AppCopy.hubDeletePlaceConfirm,
      cancelLabel: AppCopy.cancel,
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
          title: AppCopy.hubBootstrapTitle,
          actions: [ProfilePill()],
        ),
        body: Center(child: CircularProgressIndicator(color: AppColor.primary)),
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
                  AppCopy.hubBootstrapError,
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.xs),
                Text(
                  AppCopy.hubBootstrapRetryHint,
                  style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: AppCopy.hubRetryLabel,
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
    final hubTitle =
        placeCount > 1 ? AppCopy.hubTabPlatformTitle : AppCopy.hubTitle;
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
                  _PlacesSection(
                    places: _places,
                    loading: _loadingPlaces,
                    maxPlaces: ent.maxPlaces,
                    selectedFilter: _placeFilter,
                    onFilterChanged: (filter) {
                      setState(() => _placeFilter = filter);
                    },
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
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
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
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || message.isEmpty) {
      AppFeedback.warning(AppCopy.hubAppealFillAllFields);
      return;
    }
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(phone)) {
      AppFeedback.warning(AppCopy.hubAppealInvalidPhone);
      return;
    }

    setState(() => _sending = true);
    try {
      // Write directly to the place_appeals table via the SECURITY DEFINER
      // RPC. The admin reads it from /dashboard/appeals and contacts the
      // provider on the phone/email of their choice. No mailto, no leaving
      // the app.
      await ApiService.ensureSupabaseInitialized();
      final isEditAppeal = widget.place.status == 'approved' &&
          widget.place.editRequestStatus == 'rejected';
      await Supabase.instance.client.rpc<dynamic>(
        isEditAppeal ? 'submit_place_edit_appeal' : 'submit_place_appeal',
        params: isEditAppeal
            ? {
                '_place_id': widget.place.placeUuid,
                '_contact_name': name,
                '_contact_phone': phone,
                '_message': message,
              }
            : {
                '_place_id': widget.place.placeId,
                '_contact_name': name,
                '_contact_phone': phone,
                '_message': message,
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
    return AppModalSheetFrame(
      title: AppCopy.appealTitle,
      subtitle: AppCopy.appealSubtitle,
      leading: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppColor.warning.withValues(alpha: 0.12),
          borderRadius: AppRadii.rMd,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.gavel_rounded,
          color: AppColor.warning,
          size: 23.sp,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 20.sp,
                  color: AppColor.primary,
                ),
                gapH(AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.place.name,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          gapV(AppSpacing.md),
          AppInput(
            label: AppCopy.appealNameHint,
            hintText: AppCopy.appealNameHint,
            controller: _nameCtrl,
            prefixIcon:
                const Icon(Icons.person_outline, color: AppColor.textSecondary),
            textInputAction: TextInputAction.next,
          ),
          gapV(AppSpacing.md),
          AppInput(
            label: AppCopy.appealPhoneHint,
            hintText: AppCopy.appealPhoneHint,
            controller: _phoneCtrl,
            prefixIcon:
                const Icon(Icons.phone_outlined, color: AppColor.textSecondary),
            type: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          gapV(AppSpacing.md),
          AppInput(
            label: AppCopy.appealMessageHint,
            hintText: AppCopy.appealPlaceholder,
            controller: _messageCtrl,
            prefixIcon:
                const Icon(Icons.chat_outlined, color: AppColor.textSecondary),
            maxLines: 4,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      footer: AppButton(
        text: AppCopy.appealSend,
        onPress: _send,
        isLoading: _sending,
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
    return Semantics(
      header: true,
      label: greeting,
      child: Text(
        greeting,
        style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
      ),
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
    return Semantics(
      label:
          'ملخص الخطة الحالية. ${entitlement.tier.name}. أماكنك المتاحة ${entitlement.maxPlaces}.',
      child: AppCard(
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
                  Expanded(
                    child: Text(
                      '${AppCopy.subRenewsOn} ${_formatDate(entitlement.periodEnd)}',
                      style: AppText.bodySm,
                    ),
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
                variant: isPaid
                    ? AppButtonVariant.outline
                    : AppButtonVariant.primary,
              ),
            ),
          ],
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (AppSpacing.sm.w * 2)) / 3;
        return Wrap(
          spacing: AppSpacing.sm.w,
          runSpacing: AppSpacing.sm.h,
          children: [
            SizedBox(
              width: itemWidth,
              child: _KpiCell(
                icon: Icons.store_rounded,
                label: AppCopy.hubKpiPlaces,
                value: unlimited(entitlement.maxPlaces),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _KpiCell(
                icon: Icons.photo_library_rounded,
                label: AppCopy.hubKpiImages,
                value: unlimited(entitlement.maxGalleryImages),
              ),
            ),
            SizedBox(
              width: itemWidth,
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
      },
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
    return Semantics(
      label: '$label: $value',
      child: Container(
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
              maxLines: 2,
            ),
          ],
        ),
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
    return Semantics(
      button: true,
      label: '$title. $body',
      child: AppCard(
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
                            vertical: AppSpacing.xs.h / 2,
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
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                placeCount > 1
                    ? AppCopy.hubPlacesMultiTitle
                    : AppCopy.hubPlacesSingleTitle,
                style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
              ),
              AppButton(
                text: AppCopy.refresh,
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
                ? AppCopy.hubPlacesEmptyBody
                : AppCopy.hubPlacesBodyCount
                    .replaceFirst('%p', '$placeCount')
                    .replaceFirst('%m', '$maxPlaces')
                    .replaceFirst('%i', '$imagesPerPlace'),
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
                  label: AppCopy.hubStepPlan,
                ),
                StepperComponent(
                  index: 1,
                  currentIndex: stepIndex,
                  onTap: onAddPlace,
                  icon: AppImages.location,
                  label: AppCopy.hubFeatTitlePlaces,
                ),
                StepperComponent(
                  index: 2,
                  currentIndex: stepIndex,
                  onTap: onRefresh,
                  icon: AppImages.search,
                  label: AppCopy.hubStepPreview,
                  isLast: true,
                ),
              ],
            ),
          ),
          gapV(AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 320.w;
              final itemWidth = isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - AppSpacing.sm.w) / 2;
              return Wrap(
                spacing: AppSpacing.sm.w,
                runSpacing: AppSpacing.sm.h,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _MiniStat(
                      label: AppCopy.hubFeatTitlePlaces,
                      value: '$placeCount/$maxPlaces',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MiniStat(
                      label: AppCopy.hubKpiImages,
                      value: imagesPerPlace >= 999 ? '∞' : '$imagesPerPlace',
                    ),
                  ),
                ],
              );
            },
          ),
          gapV(AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: canAddPlace
                  ? AppCopy.hubAddPlace
                  : AppCopy.hubAddPlaceLimitReached,
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
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onPreviewPlace,
    required this.onEditPlace,
    required this.onDeletePlace,
    required this.onAddPlace,
  });

  final List<Place> places;
  final bool loading;
  final int maxPlaces;
  final _PlaceFilter selectedFilter;
  final ValueChanged<_PlaceFilter> onFilterChanged;
  final ValueChanged<Place> onPreviewPlace;
  final ValueChanged<Place> onEditPlace;
  final ValueChanged<Place> onDeletePlace;
  final VoidCallback onAddPlace;

  bool _matchesFilter(Place place, _PlaceFilter filter) {
    final status = place.status.trim().toLowerCase();
    return switch (filter) {
      _PlaceFilter.all => true,
      _PlaceFilter.pending => _isAwaitingModeration(status),
      _PlaceFilter.approved => status == 'approved',
      _PlaceFilter.rejected => status == 'rejected',
      _PlaceFilter.suspended => status == 'suspended',
    };
  }

  int _countFor(_PlaceFilter filter) {
    return places.where((place) => _matchesFilter(place, filter)).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = places
        .where((place) => _matchesFilter(place, selectedFilter))
        .toList(growable: false);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final listHeight = (viewportHeight * 0.62).clamp(420.0, 680.0);

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppCopy.hubMyPlacesTitle,
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
                ? AppCopy.hubPlacesEmptyFirstBody
                : AppCopy.hubPlacesManageBody,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          if (places.isNotEmpty) ...[
            gapV(AppSpacing.md),
            Semantics(
              container: true,
              label: AppCopy.hubPlacesFilterSemantics,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _PlaceFilter.values.map((filter) {
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: filter == _PlaceFilter.values.last
                            ? 0
                            : AppSpacing.sm.w,
                      ),
                      child: _PlaceFilterChip(
                        filter: filter,
                        count: _countFor(filter),
                        selected: selectedFilter == filter,
                        onTap: () => onFilterChanged(filter),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
          ],
          gapV(AppSpacing.lg),
          if (loading)
            const Center(
                child: CircularProgressIndicator(color: AppColor.primary))
          else if (places.isEmpty)
            _EmptyPlacesState(onAddPlace: onAddPlace)
          else if (filteredPlaces.isEmpty)
            _FilteredPlacesEmptyState(filter: selectedFilter)
          else if (filteredPlaces.length == 1)
            _PlaceCard(
              place: filteredPlaces.first,
              onPreview: () => onPreviewPlace(filteredPlaces.first),
              onEdit: () => onEditPlace(filteredPlaces.first),
              onDelete: () => onDeletePlace(filteredPlaces.first),
            )
          else
            SizedBox(
              height: listHeight,
              child: Scrollbar(
                interactive: false,
                child: ListView.separated(
                  primary: false,
                  padding: EdgeInsetsDirectional.only(end: AppSpacing.sm.w),
                  itemCount: filteredPlaces.length,
                  separatorBuilder: (_, __) => gapV(AppSpacing.md),
                  itemBuilder: (_, index) {
                    final place = filteredPlaces[index];
                    return _PlaceCard(
                      place: place,
                      onPreview: () => onPreviewPlace(place),
                      onEdit: () => onEditPlace(place),
                      onDelete: () => onDeletePlace(place),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceFilterChip extends StatelessWidget {
  const _PlaceFilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _PlaceFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  String get _label => switch (filter) {
        _PlaceFilter.all => AppCopy.hubFilterAll,
        _PlaceFilter.pending => AppCopy.hubFilterPending,
        _PlaceFilter.approved => AppCopy.hubFilterApproved,
        _PlaceFilter.rejected => AppCopy.hubFilterRejected,
        _PlaceFilter.suspended => AppCopy.hubFilterSuspended,
      };

  IconData get _icon => switch (filter) {
        _PlaceFilter.all => Icons.apps_rounded,
        _PlaceFilter.pending => Icons.hourglass_top_rounded,
        _PlaceFilter.approved => Icons.check_circle_outline_rounded,
        _PlaceFilter.rejected => Icons.cancel_outlined,
        _PlaceFilter.suspended => Icons.pause_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColor.primary : AppColor.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$_label، $count',
      child: Material(
        color: selected ? AppColor.primary50 : AppColor.surfaceMuted,
        borderRadius: AppRadii.rPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.rPill,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 48.h),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.rPill,
                border: Border.all(
                  color: selected ? AppColor.primary : AppColor.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 18.sp, color: foreground),
                  gapH(AppSpacing.xs),
                  Text(
                    _label,
                    style: AppText.labelSm.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  gapH(AppSpacing.xs),
                  Container(
                    constraints:
                        BoxConstraints(minWidth: 24.w, minHeight: 24.h),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColor.primary.withValues(alpha: 0.12)
                          : AppColor.surfaceCard,
                      borderRadius: AppRadii.rPill,
                    ),
                    child: Text(
                      '$count',
                      style: AppText.caption.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilteredPlacesEmptyState extends StatelessWidget {
  const _FilteredPlacesEmptyState({required this.filter});

  final _PlaceFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _PlaceFilter.pending => AppCopy.hubFilterPending,
      _PlaceFilter.approved => AppCopy.hubFilterApproved,
      _PlaceFilter.rejected => AppCopy.hubFilterRejected,
      _PlaceFilter.suspended => AppCopy.hubFilterSuspended,
      _PlaceFilter.all => AppCopy.hubFilterAll,
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.xxl.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceMuted,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: AppColor.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 34.sp,
            color: AppColor.textTertiary,
          ),
          gapV(AppSpacing.sm),
          Text(
            AppCopy.hubFilterEmpty.replaceFirst('%s', label),
            style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
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
          AppCopy.hubEmptyPlacesTitle,
          style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
        ),
        gapV(AppSpacing.sm),
        Text(
          AppCopy.hubEmptyPlacesMsgBody,
          style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          textAlign: TextAlign.center,
        ),
        gapV(AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: AppCopy.hubAddPlaceNow,
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

  void _openAppealSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColor.surfaceCard,
      barrierColor: AppColor.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (_) => _AppealSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = place.imageUrl?.trim() ?? '';
    final model = SuggestionItemModel.fromPlace(place);
    final isRejected = place.status.trim().toLowerCase() == 'rejected';
    final isPending = place.status.trim().toLowerCase() == 'pending' ||
        place.status.trim().toLowerCase() == 'under_review';
    final rejectionReason = (place.rejectionReason ?? '').trim();
    return Semantics(
      container: true,
      label:
          '${place.name}. ${place.cityName}. ${place.activityName}. حالة المكان ${place.status}.',
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surfaceCard,
          borderRadius: AppRadii.rLg,
          border: Border.all(color: AppColor.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadii.topOnly(AppRadii.lg),
              child: SizedBox(
                height: 172.h,
                width: double.infinity,
                child: cover.isNotEmpty
                    ? CachedNetworkImage(
                        url: cover,
                        width: double.infinity,
                        height: 172.h,
                        fit: BoxFit.cover,
                        errorWidget: (_) => _placePlaceholder(),
                      )
                    : _placePlaceholder(),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: AppText.titleMd.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  gapV(AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs.w,
                    runSpacing: AppSpacing.xs.h,
                    children: [
                      _MetaChip(
                        icon: Icons.location_city_rounded,
                        text: place.cityName,
                      ),
                      _MetaChip(
                        icon: Icons.category_rounded,
                        text: place.activityName,
                      ),
                    ],
                  ),
                  gapV(AppSpacing.sm),
                  _PlaceModerationBanner(
                    status: place.status,
                    createdAt: place.editRequestStatus == 'submitted'
                        ? place.editSubmittedAt
                        : place.createdAt,
                    reviewSla: place.editRequestStatus == 'submitted'
                        ? const Duration(hours: 6)
                        : const Duration(hours: 24),
                  ),
                  if (isPending) ...[
                    gapV(AppSpacing.sm),
                    const _PlaceEditNotice(
                      icon: Icons.edit_note_rounded,
                      text: AppCopy.hubPendingEditHint,
                      tone: AppColor.info,
                    ),
                  ],
                  if (place.editRequestStatus == 'pending') ...[
                    gapV(AppSpacing.sm),
                    const _PlaceEditNotice(
                      icon: Icons.hourglass_top_rounded,
                      text: AppCopy.hubEditRequestPending,
                      tone: AppColor.warning,
                    ),
                  ],
                  if (place.editRequestStatus == 'approved' &&
                      place.editAllowed) ...[
                    gapV(AppSpacing.sm),
                    const _PlaceEditNotice(
                      icon: Icons.lock_open_rounded,
                      text: AppCopy.hubEditRequestApproved,
                      tone: AppColor.success,
                    ),
                  ],
                  if (place.editRequestStatus == 'submitted') ...[
                    gapV(AppSpacing.sm),
                    _EditReviewBanner(
                      submittedAt: place.editSubmittedAt,
                    ),
                  ],
                  if (place.editRequestStatus == 'rejected' &&
                      (place.editRequestResponse ?? '').trim().isNotEmpty) ...[
                    gapV(AppSpacing.sm),
                    _PlaceEditNotice(
                      icon: Icons.info_outline_rounded,
                      text:
                          '${AppCopy.hubEditRequestRejected}: ${place.editRequestResponse}',
                      tone: AppColor.error,
                    ),
                  ],
                  if (isRejected && rejectionReason.isNotEmpty) ...[
                    gapV(AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.md.w),
                      decoration: BoxDecoration(
                        color: AppColor.error.withValues(alpha: 0.06),
                        borderRadius: AppRadii.rMd,
                        border: Border.all(
                          color: AppColor.error.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Text(
                        '${AppCopy.hubRejectedReasonPrefix} $rejectionReason',
                        style: AppText.bodySm.copyWith(
                          color: AppColor.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (place.description.trim().isNotEmpty) ...[
                    gapV(AppSpacing.sm),
                    Text(
                      place.description,
                      style: AppText.bodySm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  gapV(AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: AppCopy.hubPlacePreview,
                      onPress: onPreview,
                      size: AppButtonSize.sm,
                    ),
                  ),
                  gapV(AppSpacing.sm),
                  if (place.status == 'approved' &&
                      place.editRequestStatus == 'rejected')
                    _EditRejectedActions(
                      onAppeal: () => _openAppealSheet(context),
                      onDelete: onDelete,
                    )
                  else if (isRejected)
                    _RejectedPlaceActions(
                      canEdit: place.editAllowed,
                      onEdit: onEdit,
                      onAppeal: () => _openAppealSheet(context),
                      onDelete: onDelete,
                    )
                  else
                    _StandardPlaceActions(
                      editLabel: place.editRequestStatus == 'pending'
                          ? AppCopy.hubEditRequestPending
                          : place.editRequestStatus == 'submitted'
                              ? AppCopy.hubEditRequestSubmitted
                              : place.editRequestStatus == 'approved' &&
                                      place.editAllowed
                                  ? AppCopy.hubEditRequestApproved
                                  : AppCopy.hubPlaceEdit,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  gapV(AppSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14.sp,
                        color: AppColor.textSecondary,
                      ),
                      gapH(AppSpacing.xs),
                      Expanded(
                        child: Text(
                          model.address,
                          style: AppText.caption
                              .copyWith(color: AppColor.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _EditRejectedActions extends StatelessWidget {
  const _EditRejectedActions({
    required this.onAppeal,
    required this.onDelete,
  });

  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: AppCopy.appealTitle,
            onPress: onAppeal,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.outline,
          ),
        ),
        gapV(AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _PlaceMoreMenu(onDelete: onDelete),
        ),
      ],
    );
  }
}

class _EditReviewBanner extends StatelessWidget {
  const _EditReviewBanner({required this.submittedAt});

  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${AppCopy.hubEditRequestSubmitted}. مدة المراجعة 6 ساعات أو أقل',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.sm.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.info.withValues(alpha: 0.08),
          borderRadius: AppRadii.rMd,
          border: Border.all(color: AppColor.info.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, size: 16.sp, color: AppColor.info),
            gapH(AppSpacing.xs),
            Expanded(
              child: Text(
                AppCopy.hubEditRequestSubmitted,
                style: AppText.labelSm.copyWith(
                  color: AppColor.info,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            gapH(AppSpacing.sm),
            AppCountdownBadge(
              createdAt: submittedAt,
              sla: const Duration(hours: 6),
              color: AppColor.info,
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardPlaceActions extends StatelessWidget {
  const _StandardPlaceActions({
    required this.editLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final String editLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 280.w;
        if (stack) {
          return Column(
            children: [
              AppButton(
                text: editLabel,
                onPress: onEdit,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
              ),
              gapV(AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _PlaceMoreMenu(onDelete: onDelete),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: AppButton(
                text: editLabel,
                onPress: onEdit,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
              ),
            ),
            gapH(AppSpacing.sm),
            _PlaceMoreMenu(onDelete: onDelete),
          ],
        );
      },
    );
  }
}

class _RejectedPlaceActions extends StatelessWidget {
  const _RejectedPlaceActions({
    required this.canEdit,
    required this.onEdit,
    required this.onAppeal,
    required this.onDelete,
  });

  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onAppeal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canEdit) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.sm.h,
            ),
            decoration: BoxDecoration(
              color: AppColor.success.withValues(alpha: 0.10),
              borderRadius: AppRadii.rMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_open_rounded,
                  size: 18.sp,
                  color: AppColor.success,
                ),
                gapH(AppSpacing.xs),
                Expanded(
                  child: Text(
                    AppCopy.hubRejectedEditAllowed,
                    style: AppText.labelSm.copyWith(
                      color: AppColor.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          gapV(AppSpacing.sm),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 300.w;
            final appealButton = AppButton(
              text: AppCopy.appealTitle,
              onPress: onAppeal,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
            );
            if (!canEdit) return appealButton;
            final editButton = AppButton(
              text: AppCopy.hubEditAndResubmit,
              onPress: onEdit,
              size: AppButtonSize.sm,
            );
            if (stack) {
              return Column(
                children: [
                  editButton,
                  gapV(AppSpacing.sm),
                  appealButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: editButton),
                gapH(AppSpacing.sm),
                Expanded(child: appealButton),
              ],
            );
          },
        ),
        gapV(AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _PlaceMoreMenu(onDelete: onDelete),
        ),
      ],
    );
  }
}

class _PlaceMoreMenu extends StatelessWidget {
  const _PlaceMoreMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: AppCopy.hubPlaceMore,
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColor.error,
                size: 20.sp,
              ),
              gapH(AppSpacing.sm),
              Text(
                AppCopy.hubPlaceDelete,
                style: AppText.labelMd.copyWith(color: AppColor.error),
              ),
            ],
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: AppCopy.hubPlaceMore,
        child: Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: AppColor.surfaceMuted,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColor.border),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            color: AppColor.textSecondary,
            size: 24.sp,
          ),
        ),
      ),
    );
  }
}

class _PlaceEditNotice extends StatelessWidget {
  const _PlaceEditNotice({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.md.w),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: AppRadii.rMd,
          border: Border.all(color: tone.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tone, size: 18.sp),
            gapH(AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppText.bodySm.copyWith(
                  color: AppColor.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceMuted,
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColor.textSecondary),
          gapH(AppSpacing.xs),
          Text(
            text,
            style: AppText.caption.copyWith(color: AppColor.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PlaceModerationBanner extends StatefulWidget {
  const _PlaceModerationBanner({
    required this.status,
    required this.createdAt,
    required this.reviewSla,
  });

  final String status;
  final DateTime? createdAt;
  final Duration reviewSla;

  @override
  State<_PlaceModerationBanner> createState() => _PlaceModerationBannerState();
}

class _PlaceModerationBannerState extends State<_PlaceModerationBanner> {
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
        ? AppCopy.hubStatusRejected
        : suspended
            ? AppCopy.hubStatusSuspended
            : awaitingReview
                ? (underReview
                    ? AppCopy.hubStatusUnderReview
                    : AppCopy.hubStatusAwaitingReview)
                : AppCopy.hubStatusApproved;
    return Semantics(
      label: awaitingReview ? '$label. يتم عرض العداد التنازلي' : label,
      child: Container(
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
            Icon(icon, size: 16.sp, color: tone),
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
            if (awaitingReview) ...[
              gapH(AppSpacing.sm),
              AppCountdownBadge(
                createdAt: widget.createdAt,
                sla: widget.reviewSla,
                color: tone,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
