import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key, this.providerId});
  final String? providerId;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  String? _selectedPlaceId;
  String? _busyCampaignId;
  late Future<_PromotionsScreenData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PromotionsScreenData> _load() async {
    final providerId = widget.providerId;
    if (providerId == null || providerId.isEmpty) {
      return const _PromotionsScreenData(
        places: <Place>[],
        allCampaigns: <PromotionCampaignSnapshot>[],
      );
    }

    final places = await ApiService().fetchProviderPlaces(
      providerId: providerId,
      forceRefresh: true,
    );
    final approvedPlaces = places.where((p) => p.status == 'approved').toList();
    final selectedPlaceId =
        approvedPlaces.any((p) => p.placeUuid == _selectedPlaceId)
            ? _selectedPlaceId
            : (approvedPlaces.length > 1
                ? null
                : (approvedPlaces.isNotEmpty
                    ? approvedPlaces.first.placeUuid
                    : null));
    _selectedPlaceId = selectedPlaceId;

    final allCampaigns = await ApiService().fetchPromotionCampaigns(
      providerId: providerId,
    );

    return _PromotionsScreenData(
      places: approvedPlaces,
      allCampaigns: allCampaigns,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openCreateSheet(
    ProviderEntitlement ent,
    _PromotionsScreenData data,
  ) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (_) => _CreateCampaignSheet(
        places: data.places,
        entitlement: ent,
        providerId: widget.providerId,
        initialPlaceId: _selectedPlaceId ?? data.places.first.placeUuid,
      ),
    );

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openEditSheet(
    ProviderEntitlement ent,
    _PromotionsScreenData data,
    PromotionCampaignSnapshot campaign,
  ) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (_) => _CreateCampaignSheet(
        places: data.places,
        entitlement: ent,
        providerId: widget.providerId,
        initialPlaceId: campaign.placeId ?? _selectedPlaceId,
        initialCampaign: campaign,
      ),
    );

    if (edited == true) {
      await _refresh();
    }
  }

  Future<void> _requestEdit(PromotionCampaignSnapshot campaign) async {
    if (_busyCampaignId == campaign.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _EditRequestDialog(campaign: campaign),
    );
    if (confirmed != true) return;

    setState(() => _busyCampaignId = campaign.id);
    try {
      await ApiService().requestPromotionCampaignEdit(campaignId: campaign.id);
      if (!mounted) return;
      AppFeedback.success(AppCopy.promoRequestEditSuccess);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _busyCampaignId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      unpadded: true,
      header: const AppPageHeader(title: AppCopy.promoTitle),
      body: ValueListenableBuilder<ProviderEntitlement>(
        valueListenable: SubscriptionService.instance.entitlement,
        builder: (_, ent, __) {
          if (!ent.hasPromotions) {
            return _PromotionsLocked(providerId: widget.providerId);
          }

          return FutureBuilder<_PromotionsScreenData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColor.primary),
                );
              }

              final data = snapshot.data ??
                  const _PromotionsScreenData(
                    places: <Place>[],
                    allCampaigns: <PromotionCampaignSnapshot>[],
                  );
              final visibleCampaigns = data.filteredCampaigns(_selectedPlaceId);
              final countedCampaigns = data.countedCampaignsForPlan();
              final reachedLimit =
                  ent.maxCampaigns > 0 && countedCampaigns >= ent.maxCampaigns;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg.w,
                    AppSpacing.lg.h,
                    AppSpacing.lg.w,
                    AppSpacing.huge.h,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppCopy.promoSectionTitle,
                                style: AppText.headingMd.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              gapV(AppSpacing.xs / 2),
                              Text(
                                _selectedPlaceLabel(data.places),
                                style: AppText.bodySm.copyWith(
                                  color: AppColor.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PlanBadge(tier: ent.tier, size: PlanBadgeSize.header),
                      ],
                    ),
                    gapV(AppSpacing.md),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.lg.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppCopy.promoCreatePendingBody,
                            style: AppText.bodySm.copyWith(
                              color: AppColor.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          gapV(AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppCopy.promoQuotaAvailable.replaceFirst('%n', ent.maxCampaigns.toString()),
                                  style: AppText.labelMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                AppCopy.promoQuotaUsed.replaceFirst('%n', countedCampaigns.toString()),
                                style: AppText.bodySm.copyWith(
                                  color: AppColor.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          gapV(AppSpacing.sm),
                          Text(
                            AppCopy.promoPlanNote,
                            style: AppText.caption.copyWith(
                              color: AppColor.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.places.length > 1) ...[
                      gapV(AppSpacing.lg),
                      _PlaceSelector(
                        places: data.places,
                        selectedPlaceId: _selectedPlaceId,
                        onChanged: (value) {
                          setState(() => _selectedPlaceId = value);
                        },
                      ),
                    ],
                    gapV(AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: reachedLimit
                            ? AppCopy.promoLimitReached
                            : AppCopy.promoCreateCta,
                        onPress: data.places.isEmpty || reachedLimit
                            ? () {}
                            : () => _openCreateSheet(ent, data),
                        isEnabled: data.places.isNotEmpty && !reachedLimit,
                      ),
                    ),
                    gapV(AppSpacing.xl),
                    if (data.places.isEmpty)
                      const _NoApprovedPlacesState()
                    else if (visibleCampaigns.isEmpty)
                      _PromotionsEmpty(
                        tier: ent.tier,
                        selectedPlaceName: _selectedPlaceLabel(data.places),
                      )
                    else ...[
                      _PromotionStats(campaigns: visibleCampaigns),
                      gapV(AppSpacing.lg),
                      ...visibleCampaigns.map(
                        (campaign) => _CampaignCard(
                          campaign: campaign,
                          isBusy: _busyCampaignId == campaign.id,
                          onRequestEdit: () => _requestEdit(campaign),
                          onEditNow: () => _openEditSheet(ent, data, campaign),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _selectedPlaceLabel(List<Place> places) {
    if (places.isEmpty) return AppCopy.promoNoApprovedPlaces;
    if (_selectedPlaceId == null) return AppCopy.promoAllPlaces;
    final place = places.cast<Place?>().firstWhere(
          (p) => p?.placeUuid == _selectedPlaceId,
          orElse: () => null,
        );
    return place?.name ?? AppCopy.promoSelectedPlaceFallback;
  }
}

class _PromotionsScreenData {
  const _PromotionsScreenData({
    required this.places,
    required this.allCampaigns,
  });

  final List<Place> places;
  final List<PromotionCampaignSnapshot> allCampaigns;

  List<PromotionCampaignSnapshot> filteredCampaigns(String? placeId) {
    if (placeId == null || placeId.isEmpty) return allCampaigns;
    return allCampaigns
        .where((campaign) => campaign.placeId == placeId)
        .toList();
  }

  int countedCampaignsForPlan() {
    return allCampaigns.where((campaign) {
      return switch (campaign.status) {
        'draft' || 'pending_review' || 'active' || 'paused' => true,
        _ => false,
      };
    }).length;
  }
}

class _PlaceSelector extends StatelessWidget {
  const _PlaceSelector({
    required this.places,
    required this.selectedPlaceId,
    required this.onChanged,
  });

  final List<Place> places;
  final String? selectedPlaceId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs.w,
      runSpacing: AppSpacing.xs.h,
      children: [
        _chip(
          label: AppCopy.promoAllPlaces,
          selected: selectedPlaceId == null,
          onTap: () => onChanged(null),
        ),
        ...places.map(
          (place) => _chip(
            label: place.name,
            selected: place.placeUuid == selectedPlaceId,
            onTap: () => onChanged(place.placeUuid),
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'تصفية الحملات حسب $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rPill,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColor.primary : AppColor.surfaceCard,
            borderRadius: AppRadii.rPill,
            border: Border.all(
              color: selected ? AppColor.primary : AppColor.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.labelSm.copyWith(
                color: selected ? AppColor.white : AppColor.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromotionStats extends StatelessWidget {
  const _PromotionStats({required this.campaigns});

  final List<PromotionCampaignSnapshot> campaigns;

  @override
  Widget build(BuildContext context) {
    final active = campaigns.where((c) => c.status == 'active').length;
    final pending = campaigns.where((c) => c.status == 'pending_review').length;
    final impressions = campaigns.fold<int>(0, (sum, c) => sum + c.impressions);
    final clicks = campaigns.fold<int>(0, (sum, c) => sum + c.clicks);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - AppSpacing.sm.w) / 2;
        return Wrap(
          spacing: AppSpacing.sm.w,
          runSpacing: AppSpacing.sm.h,
          children: [
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                label: AppCopy.promoAllCampaigns,
                value: campaigns.length.toString(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(label: AppCopy.promoCampaignsActive, value: active.toString()),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                label: AppCopy.promoCampaignsPending,
                value: pending.toString(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _StatCard(
                label: 'CTR',
                value: impressions == 0
                    ? '0%'
                    : '${((clicks / impressions) * 100).toStringAsFixed(0)}%',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800)),
          gapV(AppSpacing.xs / 2),
          Text(label,
              style: AppText.caption.copyWith(color: AppColor.textSecondary)),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.onRequestEdit,
    required this.onEditNow,
    this.isBusy = false,
  });

  final PromotionCampaignSnapshot campaign;
  final VoidCallback onRequestEdit;
  final VoidCallback onEditNow;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M');
    final reviewDeadline = (campaign.createdAt ?? DateTime.now()).add(
      const Duration(hours: 6),
    );
    final hasImage = (campaign.imagePath ?? '').trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: Semantics(
        container: true,
        label:
            '${campaign.title}. حالة الإعلان ${campaign.status}. المشاهدات ${campaign.impressions}. النقرات ${campaign.clicks}.',
        child: AppCard(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (hasImage)
              ClipRRect(
                borderRadius: AppRadii.rLg,
                child: Image.network(
                  campaign.imagePath!,
                  height: 150.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (hasImage) gapV(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style:
                        AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(status: campaign.status),
              ],
            ),
            gapV(AppSpacing.xs),
            Text(
              '${_kindLabel(campaign.kind)} • ${campaign.startsAt != null ? fmt.format(campaign.startsAt!) : AppCopy.promoDateNow} - ${campaign.endsAt != null ? fmt.format(campaign.endsAt!) : AppCopy.promoDateOpen}',
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            ),
            if (campaign.status == 'pending_review') ...[
              gapV(AppSpacing.xs),
              _InlineNotice(
                tone: AppColor.warning,
                text:
                    '${AppCopy.promoPendingReview} حتى ${reviewDeadline.hour.toString().padLeft(2, '0')}:${reviewDeadline.minute.toString().padLeft(2, '0')}',
              ),
            ],
            if (campaign.status == 'rejected' &&
                (campaign.rejectionReason ?? '').trim().isNotEmpty) ...[
              gapV(AppSpacing.sm),
              _InlineNotice(
                tone: AppColor.error,
                text:
                    '${AppCopy.promoRejectedReason}: ${campaign.rejectionReason}',
              ),
            ],
            if ((campaign.body ?? '').trim().isNotEmpty) ...[
              gapV(AppSpacing.sm),
              Text(
                campaign.body!,
                style: AppText.bodySm.copyWith(
                  color: AppColor.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (campaign.editRequestStatus == 'pending') ...[
              gapV(AppSpacing.sm),
              const _InlineNotice(
                tone: AppColor.warning,
                text: AppCopy.promoEditRequestPendingNotice,
              ),
            ],
            if (campaign.editRequestStatus == 'approved' &&
                campaign.editAllowed) ...[
              gapV(AppSpacing.sm),
              const _InlineNotice(
                tone: AppColor.success,
                text: AppCopy.promoEditRequestApprovedNotice,
              ),
            ],
            if (campaign.editRequestStatus == 'rejected' &&
                (campaign.editRequestResponse ?? '').trim().isNotEmpty) ...[
              gapV(AppSpacing.sm),
              _InlineNotice(
                tone: AppColor.error,
                text: campaign.editRequestResponse!,
              ),
            ],
            gapV(AppSpacing.md),
            Row(
              children: [
                _MiniMetric(
                    label: AppCopy.promoMetricImpressions,
                    value: campaign.impressions.toString()),
                gapH(AppSpacing.lg),
                _MiniMetric(
                    label: AppCopy.promoMetricClicks,
                    value: campaign.clicks.toString()),
              ],
            ),
            if (_canRenderAction) ...[
              gapV(AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _actionLabel,
                  onPress: _actionCallback ?? () {},
                  isEnabled: !isBusy && _actionCallback != null,
                  variant: _isEditNow
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _isEditNow =>
      campaign.editAllowed && campaign.editRequestStatus == 'approved';

  bool get _canRequestEdit =>
      campaign.status == 'active' &&
      campaign.editRequestStatus != 'pending' &&
      !_isEditNow;

  bool get _canRenderAction =>
      _canRequestEdit || campaign.editRequestStatus == 'pending' || _isEditNow;

  String get _actionLabel {
    if (isBusy) return AppCopy.loading;
    if (_isEditNow) return AppCopy.promoActionEditNow;
    if (campaign.editRequestStatus == 'pending') {
      return AppCopy.promoActionEditPending;
    }
    return AppCopy.promoActionRequestEdit;
  }

  VoidCallback? get _actionCallback {
    if (isBusy) return null;
    if (_isEditNow) return onEditNow;
    if (_canRequestEdit) return onRequestEdit;
    return null;
  }

  String _kindLabel(String kind) {
    return switch (kind) {
      'featured'          => AppCopy.promoKindFeatured,
      'spotlight'         => AppCopy.promoKindSpotlight,
      'push_notification' => AppCopy.promoKindPush,
      'discount'          => AppCopy.promoKindDiscount,
      _                   => AppCopy.promoKindDefault,
    };
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.tone,
    required this.text,
  });

  final Color tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: AppRadii.rMd,
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: AppText.bodySm.copyWith(
          color: tone,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppText.labelLg.copyWith(fontWeight: FontWeight.w800)),
        Text(label,
            style: AppText.caption.copyWith(color: AppColor.textSecondary)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final map = switch (status) {
      'active'         => (AppCopy.promoCampaignStatusActive,   AppColor.success),
      'pending_review' => (AppCopy.promoCampaignStatusPending,  AppColor.warning),
      'paused'         => (AppCopy.promoCampaignStatusPaused,   AppColor.textSecondary),
      'rejected'       => (AppCopy.promoCampaignStatusRejected, AppColor.error),
      'ended'          => (AppCopy.promoCampaignStatusEnded,    AppColor.textSecondary),
      _                => (AppCopy.promoCampaignStatusDraft,    AppColor.info),
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: map.$2.withValues(alpha: 0.10),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: map.$2.withValues(alpha: 0.22)),
      ),
      child: Text(
        map.$1,
        style: AppText.labelSm
            .copyWith(color: map.$2, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PromotionsEmpty extends StatelessWidget {
  const _PromotionsEmpty({
    required this.tier,
    required this.selectedPlaceName,
  });

  final PlanTier tier;
  final String selectedPlaceName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlanBadge(tier: tier, size: PlanBadgeSize.header),
            gapV(AppSpacing.xl),
            Container(
              width: 96.w,
              height: 96.w,
              decoration: const BoxDecoration(
                color: AppColor.primary50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_rounded,
                  color: AppColor.primary, size: 44.sp),
            ),
            gapV(AppSpacing.xl),
          Text(
            AppCopy.promoEmptyTitle,
            style: AppText.headingSm,
            textAlign: TextAlign.center,
          ),
          gapV(AppSpacing.md),
          Text(
            AppCopy.promoEmptyPlaceBody.replaceFirst('%n', selectedPlaceName),
            style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
          ],
        ),
      ),
    );
  }
}

class _NoApprovedPlacesState extends StatelessWidget {
  const _NoApprovedPlacesState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded,
              color: AppColor.warning, size: 36.sp),
          gapV(AppSpacing.md),
          Text(
            AppCopy.promoNoApprovedPlacesTitle,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          gapV(AppSpacing.sm),
          Text(
            AppCopy.promoNoApprovedPlacesBody,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PromotionsLocked extends StatelessWidget {
  const _PromotionsLocked({required this.providerId});
  final String? providerId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: const BoxDecoration(
                color: AppColor.warningBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  color: AppColor.warning, size: 44.sp),
            ),
            gapV(AppSpacing.xl),
            Text(
              AppCopy.promoLockedTitle,
              style: AppText.headingSm,
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.md),
            Text(
              AppCopy.promoLockedBody,
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.subUpgrade,
                onPress: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionScreen(providerId: providerId),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCampaignSheet extends StatefulWidget {
  const _CreateCampaignSheet({
    required this.places,
    required this.entitlement,
    required this.providerId,
    this.initialPlaceId,
    this.initialCampaign,
  });

  final List<Place> places;
  final ProviderEntitlement entitlement;
  final String? providerId;
  final String? initialPlaceId;
  final PromotionCampaignSnapshot? initialCampaign;

  @override
  State<_CreateCampaignSheet> createState() => _CreateCampaignSheetState();
}

class _CreateCampaignSheetState extends State<_CreateCampaignSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _ctaCtrl = TextEditingController(text: AppCopy.promoCtaDefault);
  final ImagePicker _picker = ImagePicker();
  String? _placeId;
  String _kind = 'discount';
  int _durationDays = 7;
  bool _busy = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final campaign = widget.initialCampaign;
    _placeId = widget.initialPlaceId ??
        (widget.places.isNotEmpty ? widget.places.first.placeUuid : null);
    if (campaign != null) {
      _titleCtrl.text = campaign.title;
      _bodyCtrl.text = campaign.body ?? '';
      _ctaCtrl.text = campaign.ctaLabel ?? AppCopy.promoCtaDefault;
      _kind = campaign.kind;
      final startsAt = campaign.startsAt;
      final endsAt = campaign.endsAt;
      if (startsAt != null && endsAt != null) {
        final days = endsAt.difference(startsAt).inDays;
        if (days >= 3 && days <= 30) {
          _durationDays = days == 0 ? 7 : days;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _selectedImage = File(picked.path));
  }

  List<DropdownMenuItem<String>> _kindOptions() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
          value: 'discount', child: Text(AppCopy.promoKindDiscount)),
    ];
    if (widget.entitlement.hasFeaturedSlot) {
      items.add(const DropdownMenuItem(
          value: 'featured', child: Text(AppCopy.promoKindFeatured)));
    }
    if (widget.entitlement.hasHomepageSpotlight) {
      items.add(const DropdownMenuItem(
          value: 'spotlight', child: Text(AppCopy.promoKindSpotlight)));
    }
    if (widget.entitlement.hasPushCampaigns) {
      items.add(const DropdownMenuItem(
          value: 'push_notification', child: Text(AppCopy.promoKindPush)));
    }
    return items;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if ((_placeId ?? '').isEmpty || _titleCtrl.text.trim().length < 3) {
      AppFeedback.warning(AppCopy.promoValidationError);
      return;
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final effectiveStart = now.subtract(const Duration(minutes: 1));
      String? uploadedImageUrl;
      if (_selectedImage != null &&
          (widget.providerId ?? '').isNotEmpty &&
          (_placeId ?? '').isNotEmpty) {
        uploadedImageUrl = await ApiService().uploadCampaignImage(
          providerId: widget.providerId!,
          placeId: _placeId!,
          file: _selectedImage!,
        );
      }
      final campaign = widget.initialCampaign;
      final finalImagePath = uploadedImageUrl ?? campaign?.imagePath;
      if (campaign == null) {
        await ApiService().createPromotionCampaign(
          placeId: _placeId!,
          kind: _kind,
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          imagePath: finalImagePath,
          ctaLabel: _ctaCtrl.text.trim(),
          startsAt: effectiveStart,
          endsAt: now.add(Duration(days: _durationDays)),
        );
      } else {
        await ApiService().updatePromotionCampaign(
          campaignId: campaign.id,
          placeId: _placeId!,
          kind: _kind,
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          imagePath: finalImagePath,
          ctaLabel: _ctaCtrl.text.trim(),
          startsAt: effectiveStart,
          endsAt: now.add(Duration(days: _durationDays)),
        );
      }
      if (!mounted) return;
      AppFeedback.success(
        campaign == null ? AppCopy.promoSentSuccess : AppCopy.promoEditSentSuccess,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
                  borderRadius: AppRadii.rSm,
                ),
              ),
            ),
            gapV(AppSpacing.xl),
            Text(
              widget.initialCampaign == null ? AppCopy.promoCreateTitle : AppCopy.promoEditTitle,
              style: AppText.headingSm,
            ),
            gapV(AppSpacing.sm),
            Text(
              widget.initialCampaign == null
                  ? AppCopy.promoCreatePendingBody
                  : AppCopy.promoEditReviewBody,
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            ),
            gapV(AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _placeId,
              decoration: const InputDecoration(labelText: AppCopy.promoFieldPlace),
              items: widget.places
                  .map(
                    (place) => DropdownMenuItem(
                      value: place.placeUuid,
                      child: Text(place.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _placeId = value),
            ),
            gapV(AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: AppCopy.promoFieldKind),
              items: _kindOptions(),
              onChanged: (value) => setState(() => _kind = value ?? 'discount'),
            ),
            gapV(AppSpacing.md),
            AppInput(
              controller: _titleCtrl,
              hintText: AppCopy.promoFieldTitleHint,
              label: AppCopy.promoFieldTitle,
              textInputAction: TextInputAction.next,
            ),
            gapV(AppSpacing.md),
            AppInput(
              controller: _bodyCtrl,
              hintText: AppCopy.promoFieldBodyHint,
              label: AppCopy.promoFieldBody,
              maxLines: 4,
            ),
            gapV(AppSpacing.md),
            AppInput(
              controller: _ctaCtrl,
              hintText: AppCopy.promoFieldCtaHint,
              label: AppCopy.promoFieldCta,
              textInputAction: TextInputAction.done,
            ),
            gapV(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedImage == null
                        ? (widget.initialCampaign?.imagePath?.trim().isNotEmpty ==
                                true
                            ? AppCopy.promoImageExisting
                            : AppCopy.promoImageNone)
                        : AppCopy.promoImageSelected,
                    style: AppText.bodySm.copyWith(
                      color: AppColor.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                      _selectedImage == null ? AppCopy.promoImagePick : AppCopy.promoImageChange),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              gapV(AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadii.rLg,
                child: Image.file(
                  _selectedImage!,
                  height: 140.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (widget.initialCampaign?.imagePath?.trim().isNotEmpty ==
                true) ...[
              gapV(AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadii.rLg,
                child: Image.network(
                  widget.initialCampaign!.imagePath!,
                  height: 140.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            gapV(AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _durationDays,
              decoration: const InputDecoration(labelText: AppCopy.promoFieldDuration),
              items: const [
                DropdownMenuItem(value: 3, child: Text(AppCopy.promoDuration3Days)),
                DropdownMenuItem(value: 7, child: Text(AppCopy.promoDuration7Days)),
                DropdownMenuItem(value: 14, child: Text(AppCopy.promoDuration14Days)),
                DropdownMenuItem(value: 30, child: Text(AppCopy.promoDuration30Days)),
              ],
              onChanged: (value) => setState(() => _durationDays = value ?? 7),
            ),
            gapV(AppSpacing.lg),
            const _CampaignReviewNotice(),
            gapV(AppSpacing.md),
            AppButton(
              text: widget.initialCampaign == null
                  ? AppCopy.promoSendCta
                  : AppCopy.promoEditSendCta,
              onPress: _submit,
              isLoading: _busy,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline 6-hour review notice shown at the bottom of the create/edit sheet.
class _CampaignReviewNotice extends StatelessWidget {
  const _CampaignReviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.primary.withValues(alpha: 0.06),
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColor.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColor.primary, size: 16.sp),
          gapH(AppSpacing.sm),
          Expanded(
            child: Text(
              AppCopy.promoReviewNotice6h,
              style: AppText.bodySm.copyWith(
                color: AppColor.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRequestDialog extends StatelessWidget {
  const _EditRequestDialog({required this.campaign});

  final PromotionCampaignSnapshot campaign;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppCopy.promoEditDialogTitle,
              style: AppText.titleLg.copyWith(fontWeight: FontWeight.w800),
            ),
            gapV(AppSpacing.sm),
            Text(
              AppCopy.promoEditDialogBody,
              style: AppText.bodyMd.copyWith(
                color: AppColor.textSecondary,
                height: 1.5,
              ),
            ),
            gapV(AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md.w),
              decoration: BoxDecoration(
                color: AppColor.primary50,
                borderRadius: AppRadii.rLg,
              ),
              child: Text(
                campaign.title,
                style: AppText.labelLg.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            gapV(AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: AppCopy.cancel,
                    variant: AppButtonVariant.secondary,
                    onPress: () => Navigator.pop(context, false),
                  ),
                ),
                gapH(AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    text: AppCopy.promoEditDialogConfirm,
                    onPress: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
