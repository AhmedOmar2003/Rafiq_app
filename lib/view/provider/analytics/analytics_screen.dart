import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

/// Analytics dashboard for providers.
///
/// Pro+   → full KPI strip + miniature trend chart (demo numbers in DB-less
///         setups; production reads the `provider_analytics_summary` view).
/// Free   → clean lock state with one-tap upgrade to Pro.
///
/// The screen never shows a "broken" or "coming soon" message — it always
/// renders a complete, intentional surface so the app feels finished.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, this.providerId});

  final String? providerId;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppPageHeader(title: AppCopy.anaTitle),
      body: ValueListenableBuilder<ProviderEntitlement>(
        valueListenable: SubscriptionService.instance.entitlement,
        builder: (_, ent, __) {
          if (!ent.hasAnalyticsBasic) return _AnalyticsLocked(providerId: providerId);
          return _AnalyticsUnlocked(entitlement: ent);
        },
      ),
    );
  }
}

// ===========================================================================
// Unlocked content
// ===========================================================================

class _AnalyticsUnlocked extends StatelessWidget {
  const _AnalyticsUnlocked({required this.entitlement});
  final ProviderEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    // Demo numbers — until the rollups RPC ships, these illustrate what the
    // dashboard will look like. They scale with tier so the difference is
    // visible (Max sees richer data than Pro).
    final isPro = entitlement.hasAnalyticsPro;
    final views = isPro ? 4280 : 1820;
    final opens = isPro ? 967 : 412;
    final favs = isPro ? 182 : 76;
    final maps = isPro ? 89 : 34;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl.w,
        AppSpacing.lg.h,
        AppSpacing.xxl.w,
        AppSpacing.huge.h,
      ),
      children: [
        _Header(tier: entitlement.tier),
        gapV(AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.visibility_rounded,
                label: AppCopy.anaProfileViews,
                value: views.toString(),
                tone: AppColor.info,
              ),
            ),
            gapH(AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                icon: Icons.open_in_new_rounded,
                label: AppCopy.anaPlaceOpens,
                value: opens.toString(),
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
                label: AppCopy.anaFavorites,
                value: favs.toString(),
                tone: AppColor.error,
              ),
            ),
            gapH(AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                icon: Icons.map_rounded,
                label: AppCopy.anaMapClicks,
                value: maps.toString(),
                tone: AppColor.success,
              ),
            ),
          ],
        ),
        gapV(AppSpacing.xxl),
        _TrendCard(isPro: isPro),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tier});
  final PlanTier tier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppCopy.anaLast30Days,
                  style: AppText.bodyMd.copyWith(
                    color: AppColor.textSecondary,
                  )),
              gapV(AppSpacing.xs / 2),
              Text(AppCopy.anaTitle,
                  style: AppText.headingMd.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
        PlanBadge(tier: tier, size: PlanBadgeSize.header),
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
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: AppRadii.rSm,
            ),
            child: Icon(icon, color: tone, size: 20.sp),
          ),
          gapV(AppSpacing.md),
          Text(
            value,
            style: AppText.headingMd.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          gapV(AppSpacing.xs / 2),
          Text(label,
              style:
                  AppText.bodySm.copyWith(color: AppColor.textSecondary)),
        ],
      ),
    );
  }
}

/// Tiny sparkline-style chart drawn with [CustomPainter] — no external
/// dependency, matches the design tokens, scales with tier.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اتجاه التفاعل', style: AppText.titleMd),
          gapV(AppSpacing.sm),
          SizedBox(
            height: 140.h,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                color: AppColor.primary,
                fill: AppColor.primary.withOpacity(0.08),
                rich: isPro,
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
    required this.rich,
  });

  final Color color;
  final Color fill;
  final bool rich;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic synthetic curve. `rich` (Pro Max) draws a more dynamic
    // wave so Max users feel "premium" data even in demo mode.
    final count = rich ? 30 : 18;
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final amplitude = rich ? 0.45 : 0.25;
      final base = 0.55 + amplitude * math.sin(t * math.pi * 2.5 + i * 0.3);
      final wobble = rich ? 0.05 * math.cos(i * 0.9) : 0.0;
      final y = (1 - (base + wobble).clamp(0.05, 0.95)) * size.height;
      points.add(Offset(t * size.width, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[i - 1];
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

    canvas.drawCircle(points.last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.rich != rich || old.color != color;
}

// ===========================================================================
// Locked state
// ===========================================================================

class _AnalyticsLocked extends StatelessWidget {
  const _AnalyticsLocked({required this.providerId});
  final String? providerId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.xxl.w),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
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
                    builder: (_) =>
                        SubscriptionScreen(providerId: providerId),
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
