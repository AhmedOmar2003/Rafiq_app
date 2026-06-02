import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.providerId});

  final String? providerId;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _selectedPlaceId;
  int _selectedRangeDays = 30;
  late Future<_AnalyticsScreenData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsScreenData> _load() async {
    final providerId = widget.providerId;
    if (providerId == null || providerId.isEmpty) {
      return const _AnalyticsScreenData(
        places: <Place>[],
        snapshot: PlaceAnalyticsSnapshot.empty,
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

    final snapshot = await ApiService().fetchPlaceAnalytics(
      providerId: providerId,
      placeId: selectedPlaceId,
      days: _selectedRangeDays,
    );

    return _AnalyticsScreenData(
      places: approvedPlaces,
      snapshot: snapshot,
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
      header: const AppPageHeader(title: AppCopy.anaTitle),
      body: ValueListenableBuilder<ProviderEntitlement>(
        valueListenable: SubscriptionService.instance.entitlement,
        builder: (_, ent, __) {
          if (!ent.hasAnalyticsBasic) {
            return _AnalyticsLocked(providerId: widget.providerId);
          }

          return FutureBuilder<_AnalyticsScreenData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data ??
                  const _AnalyticsScreenData(
                    places: <Place>[],
                    snapshot: PlaceAnalyticsSnapshot.empty,
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
                    _Header(
                      tier: ent.tier,
                      selectedPlaceName: _selectedPlaceLabel(data.places),
                      selectedRangeDays: _selectedRangeDays,
                    ),
                    gapV(AppSpacing.sm),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.lg.w),
                      child: Text(
                        _rangeHint(_selectedRangeDays),
                        style: AppText.bodySm.copyWith(
                          color: AppColor.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    gapV(AppSpacing.lg),
                    _RangeSelector(
                      selectedDays: _selectedRangeDays,
                      onChanged: (days) {
                        if (days == _selectedRangeDays) return;
                        setState(() {
                          _selectedRangeDays = days;
                          _future = _load();
                        });
                      },
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
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.visibility_rounded,
                              label: AppCopy.anaViewsReal,
                              value: data.snapshot.views.toString(),
                              tone: AppColor.info,
                            ),
                          ),
                          gapH(AppSpacing.sm),
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.touch_app_rounded,
                              label: AppCopy.anaTotalActions,
                              value: data.snapshot.totalActions.toString(),
                              tone: AppColor.primary,
                            ),
                          ),
                        ],
                      ),
                      gapV(AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.favorite_rounded,
                              label: AppCopy.anaFavoriteAdds,
                              value: data.snapshot.favoriteAdds.toString(),
                              tone: AppColor.error,
                            ),
                          ),
                          gapH(AppSpacing.sm),
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.map_rounded,
                              label: AppCopy.anaMapClicks,
                              value: data.snapshot.mapClicks.toString(),
                              tone: AppColor.success,
                            ),
                          ),
                        ],
                      ),
                      gapV(AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.heart_broken_outlined,
                              label: AppCopy.anaFavoriteRemovals,
                              value: data.snapshot.favoriteRemovals.toString(),
                              tone: AppColor.warning,
                            ),
                          ),
                          gapH(AppSpacing.sm),
                          Expanded(
                            child: _KpiCard(
                              icon: Icons.bolt_rounded,
                              label: AppCopy.anaOtherActions,
                              value: data.snapshot.otherActions.toString(),
                              tone: AppColor.info,
                            ),
                          ),
                        ],
                      ),
                      gapV(AppSpacing.xxl),
                      _TrendCard(points: data.snapshot.trendPoints),
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

  String _rangeHint(int days) {
    return 'الأرقام هنا من تفاعل حقيقي لمستخدمين مسجلين خلال آخر $days يوم: فتح صفحة المكان، حفظه في المفضلة، وفتح الاتجاهات.';
  }
}

class _AnalyticsScreenData {
  const _AnalyticsScreenData({
    required this.places,
    required this.snapshot,
  });

  final List<Place> places;
  final PlaceAnalyticsSnapshot snapshot;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tier,
    required this.selectedPlaceName,
    required this.selectedRangeDays,
  });

  final PlanTier tier;
  final String selectedPlaceName;
  final int selectedRangeDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'آخر $selectedRangeDays يوم',
                style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              ),
              gapV(AppSpacing.xs / 2),
              Text(
                AppCopy.anaTitle,
                style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
              ),
              gapV(AppSpacing.xs / 2),
              Text(
                selectedPlaceName,
                style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
        ),
        PlanBadge(tier: tier, size: PlanBadgeSize.header),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = <int>[7, 14, 30, 90];
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => gapH(AppSpacing.xs),
        itemBuilder: (_, index) {
          final days = values[index];
          final selected = days == selectedDays;
          return InkWell(
            onTap: () => onChanged(days),
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
                  'آخر $days يوم',
                  style: AppText.labelSm.copyWith(
                    color: selected ? AppColor.white : AppColor.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          if (index == 0) {
            final selected = selectedPlaceId == null;
            return _selectorChip(
              label: 'كل الأماكن',
              selected: selected,
              onTap: () => onChanged(null),
            );
          }

          final place = places[index - 1];
          final selected = place.placeUuid == selectedPlaceId;
          return _selectorChip(
            label: place.name,
            selected: selected,
            onTap: () => onChanged(place.placeUuid),
          );
        },
        separatorBuilder: (_, __) => gapH(AppSpacing.xs),
        itemCount: places.length + 1,
      ),
    );
  }

  Widget _selectorChip({
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: AppRadii.rSm,
            ),
            child: Icon(icon, color: tone, size: 20.sp),
          ),
          gapV(AppSpacing.md),
          Text(
            value,
            style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
          ),
          gapV(AppSpacing.xs / 2),
          Text(label,
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary)),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

  final List<int> points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اتجاه فتح المكان', style: AppText.titleMd),
          gapV(AppSpacing.sm),
          SizedBox(
            height: 140.h,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                color: AppColor.primary,
                fill: AppColor.primary.withValues(alpha: 0.08),
                points: points,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.color,
    required this.fill,
    required this.points,
  });

  final Color color;
  final Color fill;
  final List<int> points;

  @override
  void paint(Canvas canvas, Size size) {
    final safePoints = points.isEmpty ? const <int>[0, 0] : points;
    final maxValue = safePoints.reduce(math.max).clamp(1, 1 << 20).toDouble();
    final offsets = <Offset>[];
    for (var i = 0; i < safePoints.length; i++) {
      final t = safePoints.length == 1 ? 1.0 : i / (safePoints.length - 1);
      final normalized = safePoints[i] / maxValue;
      final y = size.height - (normalized * (size.height * 0.82)) - 8;
      offsets.add(Offset(t * size.width, y));
    }

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final p = offsets[i];
      final prev = offsets[i - 1];
      final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fill);

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(offsets.last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
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
          Icon(
            Icons.hourglass_empty_rounded,
            color: AppColor.warning,
            size: 36.sp,
          ),
          gapV(AppSpacing.md),
          Text(
            'هتظهر التحليلات أول ما يتعتمد لك مكان',
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          gapV(AppSpacing.sm),
          Text(
            'لو عندك أماكن لسه تحت المراجعة، هتظهر هنا تلقائيًا بعد الاعتماد.',
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLocked extends StatelessWidget {
  const _AnalyticsLocked({required this.providerId});
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
                color: AppColor.primary50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.insights_rounded,
                  color: AppColor.primary, size: 44.sp),
            ),
            gapV(AppSpacing.xl),
            Text(
              AppCopy.anaLockedTitle,
              style: AppText.headingSm,
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.md),
            Text(
              AppCopy.anaLockedBody,
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.anaUpgradeCta,
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
