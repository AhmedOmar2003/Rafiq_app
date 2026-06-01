import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

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
        campaigns: <PromotionCampaignSnapshot>[],
      );
    }

    final places = await ApiService().fetchProviderPlaces(
      providerId: providerId,
      forceRefresh: true,
    );
    final approvedPlaces = places.where((p) => p.status == 'approved').toList();
    final selectedPlaceId = approvedPlaces.any((p) => p.placeUuid == _selectedPlaceId)
        ? _selectedPlaceId
        : (approvedPlaces.length > 1
            ? null
            : (approvedPlaces.isNotEmpty ? approvedPlaces.first.placeUuid : null));
    _selectedPlaceId = selectedPlaceId;

    final campaigns = await ApiService().fetchPromotionCampaigns(
      providerId: providerId,
      placeId: selectedPlaceId,
    );

    return _PromotionsScreenData(
      places: approvedPlaces,
      campaigns: campaigns,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
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
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data ??
                  const _PromotionsScreenData(
                    places: <Place>[],
                    campaigns: <PromotionCampaignSnapshot>[],
                  );

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
                                'إعلاناتك وعروضك',
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
                    if (data.places.length > 1) ...[
                      gapV(AppSpacing.lg),
                      _PlaceSelector(
                        places: data.places,
                        selectedPlaceId: _selectedPlaceId,
                        onChanged: (value) {
                          setState(() {
                            _selectedPlaceId = value;
                            _future = _load();
                          });
                        },
                      ),
                    ],
                    gapV(AppSpacing.xl),
                    if (data.places.isEmpty)
                      const _NoApprovedPlacesState()
                    else if (data.campaigns.isEmpty)
                      _PromotionsEmpty(
                        tier: ent.tier,
                        selectedPlaceName: _selectedPlaceLabel(data.places),
                      )
                    else ...[
                      _PromotionStats(campaigns: data.campaigns),
                      gapV(AppSpacing.lg),
                      ...data.campaigns.map(_CampaignCard.new),
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
    if (places.isEmpty) return 'لا توجد أماكن معتمدة بعد';
    if (_selectedPlaceId == null) return 'كل الأماكن المعتمدة';
    final place = places.cast<Place?>().firstWhere(
          (p) => p?.placeUuid == _selectedPlaceId,
          orElse: () => null,
        );
    return place?.name ?? 'مكان محدد';
  }
}

class _PromotionsScreenData {
  const _PromotionsScreenData({
    required this.places,
    required this.campaigns,
  });

  final List<Place> places;
  final List<PromotionCampaignSnapshot> campaigns;
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
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: places.length + 1,
        separatorBuilder: (_, __) => gapH(AppSpacing.xs),
        itemBuilder: (_, index) {
          if (index == 0) {
            return _chip(
              label: 'كل الأماكن',
              selected: selectedPlaceId == null,
              onTap: () => onChanged(null),
            );
          }

          final place = places[index - 1];
          return _chip(
            label: place.name,
            selected: place.placeUuid == selectedPlaceId,
            onTap: () => onChanged(place.placeUuid),
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rPill,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.xs.h,
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
    );
  }
}

class _PromotionStats extends StatelessWidget {
  const _PromotionStats({required this.campaigns});

  final List<PromotionCampaignSnapshot> campaigns;

  @override
  Widget build(BuildContext context) {
    final active = campaigns.where((c) => c.status == 'active').length;
    final impressions = campaigns.fold<int>(0, (sum, c) => sum + c.impressions);
    final clicks = campaigns.fold<int>(0, (sum, c) => sum + c.clicks);
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'حملات', value: campaigns.length.toString())),
        gapH(AppSpacing.sm),
        Expanded(child: _StatCard(label: 'نشطة', value: active.toString())),
        gapH(AppSpacing.sm),
        Expanded(child: _StatCard(label: 'مشاهدات', value: impressions.toString())),
        gapH(AppSpacing.sm),
        Expanded(child: _StatCard(label: 'نقرات', value: clicks.toString())),
      ],
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
          Text(value, style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800)),
          gapV(AppSpacing.xs / 2),
          Text(label, style: AppText.caption.copyWith(color: AppColor.textSecondary)),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.campaign);

  final PromotionCampaignSnapshot campaign;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M');
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: AppCard(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusPill(status: campaign.status),
              ],
            ),
            gapV(AppSpacing.xs),
            Text(
              '${_kindLabel(campaign.kind)} • ${campaign.startsAt != null ? fmt.format(campaign.startsAt!) : 'الآن'} - ${campaign.endsAt != null ? fmt.format(campaign.endsAt!) : 'غير محدد'}',
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            ),
            gapV(AppSpacing.md),
            Row(
              children: [
                _MiniMetric(label: 'مشاهدات', value: campaign.impressions.toString()),
                gapH(AppSpacing.lg),
                _MiniMetric(label: 'نقرات', value: campaign.clicks.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'featured':
        return 'ظهور مميز';
      case 'spotlight':
        return 'سبوت لايت';
      case 'push_notification':
        return 'إشعار';
      case 'discount':
        return 'خصم';
      default:
        return 'حملة';
    }
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
        Text(value, style: AppText.labelLg.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: AppText.caption.copyWith(color: AppColor.textSecondary)),
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
      'active' => ('نشطة', AppColor.success),
      'pending_review' => ('قيد المراجعة', AppColor.warning),
      'paused' => ('موقوفة', AppColor.textSecondary),
      'rejected' => ('مرفوضة', AppColor.error),
      'ended' => ('انتهت', AppColor.textSecondary),
      _ => ('مسودة', AppColor.info),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: map.$2.withValues(alpha: 0.10),
        borderRadius: AppRadii.rPill,
        border: Border.all(color: map.$2.withValues(alpha: 0.22)),
      ),
      child: Text(
        map.$1,
        style: AppText.labelSm.copyWith(color: map.$2, fontWeight: FontWeight.w800),
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
              '$selectedPlaceName لسه ما عليهش حملات مفعلة. أول ما تنشئ عروض أو حملات، هتظهر هنا حسب المكان المختار.',
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.promoCreateCta,
                onPress: () => AppFeedback.info('جهزنا الفرز حسب المكان. مسار إنشاء الحملة نفسه هو الخطوة التالية.'),
              ),
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
          Icon(Icons.hourglass_empty_rounded, color: AppColor.warning, size: 36.sp),
          gapV(AppSpacing.md),
          Text(
            'هتظهر العروض حسب المكان بعد اعتماد أول مكان',
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          gapV(AppSpacing.sm),
          Text(
            'لو عندك أماكن تحت المراجعة، أول ما تتعتمد هتقدر تفرّق بين عروض كل مكان هنا.',
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
