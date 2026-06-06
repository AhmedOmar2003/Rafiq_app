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
                return const Center(
                    child: CircularProgressIndicator(color: AppColor.primary));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 48.sp, color: AppColor.textTertiary),
                        gapV(AppSpacing.lg),
                        Text(
                          AppCopy.errorGeneric,
                          style: AppText.titleMd
                              .copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        gapV(AppSpacing.lg),
                        AppButton(text: AppCopy.refresh, onPress: _refresh),
                      ],
                    ),
                  ),
                );
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
                      AppCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg.w,
                          vertical: AppSpacing.md.h,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColor.textSecondary, size: 16.sp),
                            gapH(AppSpacing.sm),
                            Expanded(
                              child: Text(
                                AppCopy.anaRealDataHint,
                                style: AppText.bodySm.copyWith(
                                  color: AppColor.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      gapV(AppSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 340.w;
                          final cardWidth = isNarrow
                              ? constraints.maxWidth
                              : (constraints.maxWidth - AppSpacing.sm.w) / 2;
                          return Wrap(
                            spacing: AppSpacing.sm.w,
                            runSpacing: AppSpacing.sm.h,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.visibility_rounded,
                                  label: AppCopy.anaViewsReal,
                                  value: data.snapshot.views.toString(),
                                  tone: AppColor.info,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.touch_app_rounded,
                                  label: AppCopy.anaTotalActions,
                                  value: data.snapshot.totalActions.toString(),
                                  tone: AppColor.primary,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.favorite_rounded,
                                  label: AppCopy.anaFavoriteAdds,
                                  value: data.snapshot.favoriteAdds.toString(),
                                  tone: AppColor.error,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.map_rounded,
                                  label: AppCopy.anaMapClicks,
                                  value: data.snapshot.mapClicks.toString(),
                                  tone: AppColor.success,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.heart_broken_outlined,
                                  label: AppCopy.anaFavoriteRemovals,
                                  value:
                                      data.snapshot.favoriteRemovals.toString(),
                                  tone: AppColor.warning,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _KpiCard(
                                  icon: Icons.bolt_rounded,
                                  label: AppCopy.anaOtherActions,
                                  value: data.snapshot.otherActions.toString(),
                                  tone: AppColor.info,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      gapV(AppSpacing.xxl),
                      _TrendCard(
                        points: data.snapshot.trendPoints,
                        rangeDays: _selectedRangeDays,
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
    if (places.isEmpty) return AppCopy.anaNoApprovedTitle;
    if (_selectedPlaceId == null) return AppCopy.anaAllPlaces;
    final place = places.cast<Place?>().firstWhere(
          (p) => p?.placeUuid == _selectedPlaceId,
          orElse: () => null,
        );
    return place?.name ?? AppCopy.anaAllPlaces;
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.anaLastDays.replaceFirst('%d', '$selectedRangeDays'),
                style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              ),
              if (selectedPlaceName.isNotEmpty) ...[
                gapV(AppSpacing.xs / 2),
                Text(
                  selectedPlaceName,
                  style: AppText.labelMd.copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
    return Wrap(
      spacing: AppSpacing.xs.w,
      runSpacing: AppSpacing.xs.h,
      children: values.map((days) {
        final label = AppCopy.anaLastDays.replaceFirst('%d', '$days');
        return AppChip(
          label: label,
          selected: days == selectedDays,
          onTap: () => onChanged(days),
          semanticLabel: label,
        );
      }).toList(growable: false),
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
    return Wrap(
      spacing: AppSpacing.xs.w,
      runSpacing: AppSpacing.xs.h,
      children: [
        AppChip(
          label: AppCopy.anaAllPlaces,
          selected: selectedPlaceId == null,
          onTap: () => onChanged(null),
          semanticLabel: AppCopy.anaAllPlaces,
        ),
        ...places.map((place) => AppChip(
              label: place.name,
              selected: place.placeUuid == selectedPlaceId,
              onTap: () => onChanged(place.placeUuid),
              semanticLabel: '${AppCopy.anaFilterByLabel} ${place.name}',
            )),
      ],
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
    return Semantics(
      label: '$label: $value',
      child: AppCard(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
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
            Text(
              label,
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points, required this.rangeDays});

  final List<int> points;
  final int rangeDays;

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
                  AppCopy.anaTrendTitle,
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: AppSpacing.xs.h,
                ),
                decoration: BoxDecoration(
                  color: AppColor.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  AppCopy.anaLastDays.replaceFirst('%d', '$rangeDays'),
                  style: AppText.caption.copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          gapV(AppSpacing.xs),
          Text(
            AppCopy.anaTrendHint,
            style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
          ),
          if (points.isNotEmpty) ...[
            gapV(AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Text(
                '${points.reduce(math.max)}',
                style: AppText.caption.copyWith(color: AppColor.textTertiary),
              ),
            ),
          ],
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
          Container(
            width: 72.w,
            height: 72.w,
            decoration: const BoxDecoration(
              color: AppColor.warningBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: AppColor.warning,
              size: 32.sp,
            ),
          ),
          gapV(AppSpacing.md),
          Text(
            AppCopy.anaNoApprovedTitle,
            style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          gapV(AppSpacing.sm),
          Text(
            AppCopy.anaNoApprovedBody,
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
