import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/subscription_service.dart';

/// Premium SaaS-grade subscription page.
///
/// Visual structure:
///   ┌─ AppPageHeader (transparent over cream)
///   │
///   │  Hero title + subtitle
///   │  Monthly / Yearly billing toggle (yearly highlights savings %)
///   │
///   │  3 pricing cards in a Row on tablet+, stacked on mobile.
///   │   • Current plan card → highlighted ring + "خطتك الحالية" chip.
///   │   • Recommended plan → tilted-up + accent ribbon.
///   │
///   │  Comparison table — feature × tier matrix.
///   │  Manage section — period_end, cancel button, billing history link.
///   └─
///
/// Data flow:
///   * Catalog & entitlement both come from [SubscriptionService] (singleton
///     with TTL cache). The screen subscribes via [ValueListenableBuilder]
///     so a successful checkout immediately reflows the UI.
///   * Upgrade CTA fires `startCheckout` and shows a soft success toast —
///     the real entitlement flip happens after the webhook lands.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.providerId});

  /// Resolved provider id of the signed-in user.
  final String providerId;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _yearly = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final svc = SubscriptionService.instance;
    svc.loadCatalog();
    svc.loadEntitlement(widget.providerId);
  }

  Future<void> _onUpgrade(PlanTier targetTier) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SubscriptionService.instance.startCheckout(
        providerId: widget.providerId,
        targetTier: targetTier,
        yearly: _yearly,
      );
      if (!mounted) return;
      AppFeedback.success(AppCopy.subUpgradeInProgress);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      header: const AppPageHeader(title: AppCopy.subTitle),
      body: ValueListenableBuilder<List<SubscriptionPlan>>(
        valueListenable: SubscriptionService.instance.catalog,
        builder: (_, plans, __) {
          if (plans.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            );
          }
          return ValueListenableBuilder<ProviderEntitlement>(
            valueListenable: SubscriptionService.instance.entitlement,
            builder: (_, ent, __) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxl.w,
                  AppSpacing.lg.h,
                  AppSpacing.xxl.w,
                  AppSpacing.huge.h,
                ),
                children: [
                  _Hero(currentTier: ent.tier),
                  gapV(AppSpacing.xl),
                  _BillingToggle(
                    yearly: _yearly,
                    discountPct: _maxYearlyDiscount(plans),
                    onChanged: (v) => setState(() => _yearly = v),
                  ),
                  gapV(AppSpacing.xxxl),
                  ..._planCards(plans, ent),
                  gapV(AppSpacing.huge),
                  Text(
                    AppCopy.subCompareTitle,
                    style: AppText.headingSm,
                    textAlign: TextAlign.start,
                  ),
                  gapV(AppSpacing.lg),
                  _ComparisonTable(plans: plans),
                  if (!ent.tier.name.startsWith('free')) ...[
                    gapV(AppSpacing.huge),
                    _ManageSection(
                      entitlement: ent,
                      onCancel: () async {
                        await SubscriptionService.instance
                            .cancelAtPeriodEnd(widget.providerId);
                      },
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  int _maxYearlyDiscount(List<SubscriptionPlan> plans) {
    int best = 0;
    for (final p in plans) {
      if (p.yearlySavingsPct > best) best = p.yearlySavingsPct;
    }
    return best;
  }

  List<Widget> _planCards(
    List<SubscriptionPlan> plans,
    ProviderEntitlement ent,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
          child: _PlanCard(
            plan: plan,
            yearly: _yearly,
            isCurrent: plan.tier == ent.tier,
            isRecommended: plan.tier == PlanTier.pro,
            disabled: _busy,
            onCta: () => _onUpgrade(plan.tier),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ===========================================================================
// Hero
// ===========================================================================

class _Hero extends StatelessWidget {
  const _Hero({required this.currentTier});

  final PlanTier currentTier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppCopy.subTitle, style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          AppCopy.subSubtitle,
          style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
        ),
      ],
    );
  }
}

// ===========================================================================
// Billing toggle
// ===========================================================================

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({
    required this.yearly,
    required this.discountPct,
    required this.onChanged,
  });

  final bool yearly;
  final int discountPct;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xs.w),
        decoration: BoxDecoration(
          color: AppColor.surfaceCard,
          borderRadius: AppRadii.rPill,
          border: Border.all(color: AppColor.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleChip(
              label: AppCopy.subBillingMonthly,
              selected: !yearly,
              onTap: () => onChanged(false),
            ),
            _ToggleChip(
              label: AppCopy.subBillingYearly,
              trailing: discountPct > 0
                  ? AppCopy.subYearlyDiscount.replaceFirst(
                      '%p',
                      discountPct.toString(),
                    )
                  : null,
              selected: yearly,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColor.primary : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.labelMd.copyWith(
                  color: selected ? AppColor.white : AppColor.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[
                gapH(AppSpacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColor.white : AppColor.successBg,
                    borderRadius: AppRadii.rSm,
                  ),
                  child: Text(
                    trailing!,
                    style: AppText.caption.copyWith(
                      color: selected ? AppColor.primary : AppColor.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Plan card
// ===========================================================================

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.isCurrent,
    required this.isRecommended,
    required this.disabled,
    required this.onCta,
  });

  final SubscriptionPlan plan;
  final bool yearly;
  final bool isCurrent;
  final bool isRecommended;
  final bool disabled;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final price = yearly ? plan.priceYearlyEgp : plan.priceMonthlyEgp;
    final per = yearly ? AppCopy.subPerYear : AppCopy.subPerMonth;
    final accent = isCurrent ? AppColor.success : plan.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rXl,
        border: Border.all(
          color: isCurrent || isRecommended ? accent : AppColor.border,
          width: isCurrent || isRecommended ? 2 : 1,
        ),
        boxShadow:
            isRecommended ? AppShadows.primaryGlow : AppShadows.level1,
      ),
      padding: EdgeInsets.all(AppSpacing.xxl.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan.displayName,
                style: AppText.headingMd.copyWith(color: accent),
              ),
              const Spacer(),
              if (isCurrent)
                _Chip(label: AppCopy.subCurrent, color: AppColor.success)
              else if (isRecommended)
                _Chip(label: 'الأكثر اختياراً', color: plan.accentColor),
            ],
          ),
          gapV(AppSpacing.xs),
          Text(
            plan.tagline,
            style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
          ),
          gapV(AppSpacing.lg),
          if (plan.isFree)
            Text(
              AppCopy.subFreeForever,
              style: AppText.displayMd.copyWith(color: AppColor.textPrimary),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price.toString(),
                  style: AppText.displayMd.copyWith(color: AppColor.textPrimary),
                ),
                gapH(AppSpacing.xs),
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    'ج.م ${per.trim()}',
                    style: AppText.bodyLg
                        .copyWith(color: AppColor.textSecondary),
                  ),
                ),
              ],
            ),
          gapV(AppSpacing.lg),
          ..._featureBullets(),
          gapV(AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: isCurrent ? AppCopy.subManage : plan.ctaLabel,
              onPress: isCurrent || disabled ? () {} : onCta,
              isEnabled: !disabled && !isCurrent,
              variant: isRecommended
                  ? AppButtonVariant.primary
                  : AppButtonVariant.outline,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _featureBullets() {
    String unlimited(int v) =>
        v == 0 ? '0' : (v >= 999 ? AppCopy.subFeatureUnlimited : v.toString());

    final bullets = <Widget>[
      _Feature(label: '${AppCopy.subFeatPlaces}: ${plan.maxPlaces}'),
      _Feature(
          label:
              '${AppCopy.subFeatGallery}: ${unlimited(plan.maxGalleryImages)}'),
      if (plan.maxVideos > 0)
        _Feature(
            label: '${AppCopy.subFeatVideos}: ${unlimited(plan.maxVideos)}'),
      if (plan.isVerified) _Feature(label: AppCopy.subFeatVerified),
      if (plan.hasAnalyticsBasic) _Feature(label: AppCopy.subFeatAnalytics),
      if (plan.hasPromotions) _Feature(label: AppCopy.subFeatPromotions),
      if (plan.hasFeaturedSlot) _Feature(label: AppCopy.subFeatFeatured),
      if (plan.hasPushCampaigns) _Feature(label: AppCopy.subFeatPush),
      if (plan.hasHomepageSpotlight) _Feature(label: AppCopy.subFeatSpotlight),
      if (plan.hasPrioritySupport) _Feature(label: AppCopy.subFeatSupport),
    ];
    return bullets;
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColor.success, size: 18.sp),
          gapH(AppSpacing.sm),
          Expanded(child: Text(label, style: AppText.bodyMd)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: 2.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadii.rSm,
      ),
      child: Text(
        label,
        style: AppText.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ===========================================================================
// Comparison table
// ===========================================================================

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.plans});

  final List<SubscriptionPlan> plans;

  @override
  Widget build(BuildContext context) {
    final rows = <_CompareRow>[
      _CompareRow(AppCopy.subFeatPlaces,
          plans.map((p) => p.maxPlaces.toString()).toList()),
      _CompareRow(
        AppCopy.subFeatGallery,
        plans.map((p) {
          if (p.maxGalleryImages >= 999) return AppCopy.subFeatureUnlimited;
          return p.maxGalleryImages.toString();
        }).toList(),
      ),
      _CompareRow(
        AppCopy.subFeatVideos,
        plans.map((p) => p.maxVideos == 0 ? '—' : p.maxVideos.toString())
            .toList(),
      ),
      _CompareRow(
        AppCopy.subFeatRanking,
        plans.map((p) => '×${p.rankingBoost.toStringAsFixed(2)}').toList(),
      ),
      _CompareRow(AppCopy.subFeatVerified,
          plans.map((p) => p.isVerified ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatAnalytics,
          plans.map((p) => p.hasAnalyticsBasic ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatPromotions,
          plans.map((p) => p.hasPromotions ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatFeatured,
          plans.map((p) => p.hasFeaturedSlot ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatPush,
          plans.map((p) => p.hasPushCampaigns ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatSpotlight,
          plans.map((p) => p.hasHomepageSpotlight ? '✓' : '—').toList()),
      _CompareRow(AppCopy.subFeatSupport,
          plans.map((p) => p.hasPrioritySupport ? '✓' : '—').toList()),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CompareHeader(plans: plans),
          for (var i = 0; i < rows.length; i++)
            _CompareRowView(
              row: rows[i],
              isEven: i.isEven,
            ),
        ],
      ),
    );
  }
}

class _CompareRow {
  _CompareRow(this.label, this.values);
  final String label;
  final List<String> values;
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader({required this.plans});
  final List<SubscriptionPlan> plans;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.lg.h,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: const SizedBox.shrink()),
          for (final p in plans)
            Expanded(
              flex: 2,
              child: Text(
                p.displayName,
                textAlign: TextAlign.center,
                style: AppText.labelMd.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompareRowView extends StatelessWidget {
  const _CompareRowView({required this.row, required this.isEven});
  final _CompareRow row;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? AppColor.surfaceVariant : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(row.label, style: AppText.bodyMd),
          ),
          for (final v in row.values)
            Expanded(
              flex: 2,
              child: Text(
                v,
                textAlign: TextAlign.center,
                style: AppText.labelMd.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Manage section
// ===========================================================================

class _ManageSection extends StatelessWidget {
  const _ManageSection({required this.entitlement, required this.onCancel});

  final ProviderEntitlement entitlement;
  final VoidCallback onCancel;

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final renewalLabel = entitlement.cancelAtPeriodEnd
        ? AppCopy.subCancelsOn
        : AppCopy.subRenewsOn;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.xxl.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppCopy.subManage, style: AppText.headingSm),
          gapV(AppSpacing.md),
          _Row(label: renewalLabel, value: _formatDate(entitlement.periodEnd)),
          gapV(AppSpacing.lg),
          if (!entitlement.cancelAtPeriodEnd)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'إلغاء التجديد التلقائي',
                onPress: onCancel,
                variant: AppButtonVariant.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppText.bodyMd),
        const Spacer(),
        Text(
          value,
          style: AppText.labelMd.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
