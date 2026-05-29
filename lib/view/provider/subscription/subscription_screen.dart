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
  const SubscriptionScreen({
    super.key,
    this.providerId,
    this.onboarding = false,
    this.onPlanChosen,
  });

  /// Resolved provider id of the signed-in user. `null` for users who haven't
  /// onboarded as a provider yet — the screen still shows the catalog as
  /// marketing material but disables the upgrade CTAs.
  final String? providerId;

  /// When true the page becomes the *first* step in the provider onboarding:
  /// a plan picker. The Free plan card gets a real CTA, and any successful
  /// selection fires [onPlanChosen] (or pops to the previous route) so the
  /// caller can continue to the add-place screen.
  final bool onboarding;

  /// Called after the user successfully picks any plan (Free, Pro, or Max)
  /// while in onboarding mode. The screen does NOT pop itself; the caller
  /// decides whether to push the next step or replace the route.
  final Future<void> Function()? onPlanChosen;

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
    final pid = widget.providerId;
    if (pid != null) svc.loadEntitlement(pid);
  }

  /// DEMO upgrade flow.
  ///
  /// 1. Opens a confirm sheet listing features + amount (paid plans only).
  /// 2. On confirm, applies the entitlement *locally* via
  ///    [SubscriptionService.applyDemoUpgrade] so every screen reacts
  ///    immediately (current-plan badge, manage section, etc.).
  /// 3. Shows a celebratory full-screen success overlay.
  /// 4. In onboarding mode, fires [widget.onPlanChosen] so the caller can
  ///    push the next step (typically the add-place screen).
  ///
  /// When the real payment gateway is wired, replace step 2 with the
  /// `startCheckout` RPC — the rest of the UX stays the same.
  Future<void> _onUpgrade(SubscriptionPlan plan) async {
    if (_busy) return;

    // Free plan path -------------------------------------------------------
    if (plan.tier == PlanTier.free) {
      setState(() => _busy = true);
      try {
        await SubscriptionService.instance
            .applyDemoFree(providerId: widget.providerId);
        if (!mounted) return;
        if (widget.onboarding) {
          await widget.onPlanChosen?.call();
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Paid plan path -------------------------------------------------------
    final confirmed = await _ConfirmUpgradeSheet.show(
      context,
      plan: plan,
      yearly: _yearly,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SubscriptionService.instance.applyDemoUpgrade(
        plan: plan,
        yearly: _yearly,
        providerId: widget.providerId,
      );
      if (!mounted) return;
      await _UpgradeSuccessOverlay.show(
        context,
        plan: plan,
        ctaLabel: widget.onboarding
            ? AppCopy.subOnboardingContinueCta
            : AppCopy.subSuccessCta,
      );
      if (!mounted) return;
      if (widget.onboarding) {
        await widget.onPlanChosen?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle =
        widget.onboarding ? AppCopy.subOnboardingTitle : AppCopy.subTitle;
    return AppPageScaffold(
      unpadded: true,
      header: AppPageHeader(title: headerTitle),
      body: ValueListenableBuilder<List<SubscriptionPlan>>(
        valueListenable: SubscriptionService.instance.catalog,
        builder: (_, plans, __) {
          if (plans.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColor.primary),
            );
          }
          return ValueListenableBuilder<ProviderEntitlement>(
            valueListenable: SubscriptionService.instance.entitlement,
            builder: (_, ent, __) {
              // The service initialises with `freeFallback`, so this is safe
              // even when no provider id has been resolved yet. Demo upgrades
              // publish here too, which is why the UI reacts instantly to a
              // successful confirm.
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg.w,
                  AppSpacing.lg.h,
                  AppSpacing.lg.w,
                  AppSpacing.huge.h,
                ),
                children: [
                  _Hero(currentTier: ent.tier, onboarding: widget.onboarding),
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
                  if (ent.tier != PlanTier.free) ...[
                    gapV(AppSpacing.huge),
                    _ManageSection(
                      entitlement: ent,
                      onCancel: () async {
                        // In demo mode just drop to Free locally. Once the
                        // payment webhook is live, swap this for the real
                        // `cancelAtPeriodEnd` call below.
                        final providerId = widget.providerId;
                        if (providerId != null) {
                          try {
                            await SubscriptionService.instance
                                .cancelAtPeriodEnd(providerId);
                          } catch (_) {
                            await SubscriptionService.instance
                                .applyDemoFree(providerId: providerId);
                          }
                        } else {
                          await SubscriptionService.instance.applyDemoFree();
                        }
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
            onboarding: widget.onboarding,
            onCta: () => _onUpgrade(plan),
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
  const _Hero({required this.currentTier, this.onboarding = false});

  final PlanTier currentTier;
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    final title = onboarding ? AppCopy.subOnboardingTitle : AppCopy.subTitle;
    final subtitle =
        onboarding ? AppCopy.subOnboardingSubtitle : AppCopy.subSubtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          subtitle,
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
    this.onboarding = false,
  });

  final SubscriptionPlan plan;
  final bool yearly;
  final bool isCurrent;
  final bool isRecommended;
  final bool disabled;
  final VoidCallback onCta;
  final bool onboarding;

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
        boxShadow: isRecommended ? AppShadows.primaryGlow : AppShadows.level1,
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
                const _Chip(label: AppCopy.subCurrent, color: AppColor.success)
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
                  style:
                      AppText.displayMd.copyWith(color: AppColor.textPrimary),
                ),
                gapH(AppSpacing.xs),
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    'ج.م ${per.trim()}',
                    style:
                        AppText.bodyLg.copyWith(color: AppColor.textSecondary),
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
              // During onboarding the free card needs a real CTA so the user
              // can confirm their choice and move on. Outside onboarding it
              // stays as "إدارة الاشتراك" when current.
              text: () {
                if (onboarding && plan.isFree) {
                  return AppCopy.subOnboardingFreeCta;
                }
                if (isCurrent && !onboarding) return AppCopy.subManage;
                return plan.ctaLabel;
              }(),
              onPress:
                  disabled ? () {} : (isCurrent && !onboarding ? () {} : onCta),
              isEnabled: !disabled && (onboarding || !isCurrent),
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
      if (plan.isVerified) const _Feature(label: AppCopy.subFeatVerified),
      if (plan.hasAnalyticsBasic)
        const _Feature(label: AppCopy.subFeatAnalytics),
      if (plan.hasPromotions) const _Feature(label: AppCopy.subFeatPromotions),
      if (plan.hasFeaturedSlot) const _Feature(label: AppCopy.subFeatFeatured),
      if (plan.hasPushCampaigns) const _Feature(label: AppCopy.subFeatPush),
      if (plan.hasHomepageSpotlight)
        const _Feature(label: AppCopy.subFeatSpotlight),
      if (plan.hasPrioritySupport)
        const _Feature(label: AppCopy.subFeatSupport),
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
        color: color.withValues(alpha: 0.12),
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
        plans
            .map((p) => p.maxVideos == 0 ? '—' : p.maxVideos.toString())
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
          const Expanded(flex: 3, child: SizedBox.shrink()),
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

// ===========================================================================
// Confirm-upgrade bottom sheet
// ===========================================================================

/// Premium bottom sheet that summarises the plan being purchased: title,
/// price, benefits list, demo notice, confirm/cancel buttons.
///
/// Returns `true` from [show] when the user confirms, `false` / `null`
/// otherwise.
class _ConfirmUpgradeSheet extends StatelessWidget {
  const _ConfirmUpgradeSheet({required this.plan, required this.yearly});

  final SubscriptionPlan plan;
  final bool yearly;

  static Future<bool?> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    required bool yearly,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (_) => _ConfirmUpgradeSheet(plan: plan, yearly: yearly),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = yearly ? plan.priceYearlyEgp : plan.priceMonthlyEgp;
    final per = yearly ? AppCopy.subPerYear : AppCopy.subPerMonth;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl.w,
          AppSpacing.lg.h,
          AppSpacing.xxl.w,
          AppSpacing.xxl.h,
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
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: plan.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: plan.accentColor,
                    size: 30.sp,
                  ),
                ),
                gapH(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppCopy.subConfirmTitle, style: AppText.headingSm),
                      gapV(AppSpacing.xs / 2),
                      Text(
                        '${AppCopy.subConfirmSubtitlePrefix} ${plan.displayName}',
                        style: AppText.bodyMd
                            .copyWith(color: AppColor.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            gapV(AppSpacing.xl),
            // Price row -----------------------------------------------------
            Container(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: AppRadii.rLg,
                border: Border.all(color: AppColor.border),
              ),
              child: Row(
                children: [
                  Text(AppCopy.subConfirmPriceLabel,
                      style: AppText.bodyMd
                          .copyWith(color: AppColor.textSecondary)),
                  const Spacer(),
                  Text(
                    '$price ج.م ${per.trim()}',
                    style: AppText.titleLg.copyWith(
                      color: plan.accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            gapV(AppSpacing.xl),
            Text(AppCopy.subConfirmBenefitsHeading, style: AppText.titleMd),
            gapV(AppSpacing.md),
            ..._benefitBullets(),
            gapV(AppSpacing.xl),
            // Demo notice ---------------------------------------------------
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              decoration: BoxDecoration(
                color: AppColor.warningBg,
                borderRadius: AppRadii.rMd,
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined,
                      color: AppColor.warning, size: 18.sp),
                  gapH(AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppCopy.subDemoExplainer,
                      style: AppText.bodySm.copyWith(color: AppColor.warning),
                    ),
                  ),
                ],
              ),
            ),
            gapV(AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.subConfirmCta,
                onPress: () => Navigator.pop(context, true),
              ),
            ),
            gapV(AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.cancel,
                onPress: () => Navigator.pop(context, false),
                variant: AppButtonVariant.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _benefitBullets() {
    String unlimited(int v) =>
        v >= 999 ? AppCopy.subFeatureUnlimited : v.toString();

    final benefits = <String>[
      '${AppCopy.subFeatGallery}: ${unlimited(plan.maxGalleryImages)}',
      if (plan.maxVideos > 0)
        '${AppCopy.subFeatVideos}: ${unlimited(plan.maxVideos)}',
      if (plan.isVerified) AppCopy.subFeatVerified,
      if (plan.hasAnalyticsBasic) AppCopy.subFeatAnalytics,
      if (plan.hasPromotions) AppCopy.subFeatPromotions,
      if (plan.hasFeaturedSlot) AppCopy.subFeatFeatured,
      if (plan.hasPushCampaigns) AppCopy.subFeatPush,
      if (plan.hasHomepageSpotlight) AppCopy.subFeatSpotlight,
      if (plan.hasPrioritySupport) AppCopy.subFeatSupport,
    ];

    return benefits.map((b) {
      return Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColor.success, size: 20.sp),
            gapH(AppSpacing.sm),
            Expanded(child: Text(b, style: AppText.bodyMd)),
          ],
        ),
      );
    }).toList();
  }
}

// ===========================================================================
// Celebratory success overlay
// ===========================================================================

/// Full-screen modal shown after a demo "subscription" lands. Has a soft
/// scaling + opacity entrance so the moment feels rewarding rather than
/// transactional.
class _UpgradeSuccessOverlay extends StatefulWidget {
  const _UpgradeSuccessOverlay({required this.plan, required this.ctaLabel});
  final SubscriptionPlan plan;
  final String ctaLabel;

  static Future<void> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    String? ctaLabel,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        barrierDismissible: false,
        transitionDuration: AppMotion.base,
        pageBuilder: (_, __, ___) => _UpgradeSuccessOverlay(
          plan: plan,
          ctaLabel: ctaLabel ?? AppCopy.subSuccessCta,
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<_UpgradeSuccessOverlay> createState() => _UpgradeSuccessOverlayState();
}

class _UpgradeSuccessOverlayState extends State<_UpgradeSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _ctl, curve: Curves.elasticOut);
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl.w),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.xxl.w),
              decoration: BoxDecoration(
                color: AppColor.surfaceCard,
                borderRadius: AppRadii.rXl,
                boxShadow: AppShadows.level3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Halo + check ------------------------------------------
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: plan.accentColor.withValues(alpha: 0.08),
                        ),
                      ),
                      Container(
                        width: 88.w,
                        height: 88.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: plan.accentColor.withValues(alpha: 0.18),
                        ),
                      ),
                      Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: plan.accentColor,
                          boxShadow: AppShadows.primaryGlow,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColor.white,
                          size: 36.sp,
                        ),
                      ),
                    ],
                  ),
                  gapV(AppSpacing.xl),
                  Text(
                    '${AppCopy.subSuccessTitlePrefix} '
                    '${plan.displayName} '
                    '${AppCopy.subSuccessTitleSuffix}',
                    textAlign: TextAlign.center,
                    style: AppText.headingMd.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  gapV(AppSpacing.md),
                  Text(
                    AppCopy.subSuccessBody,
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd.copyWith(
                      color: AppColor.textSecondary,
                    ),
                  ),
                  gapV(AppSpacing.xl),
                  if (plan.badgeLabel != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      decoration: BoxDecoration(
                        color: plan.accentColor.withValues(alpha: 0.12),
                        borderRadius: AppRadii.rPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: plan.accentColor, size: 16.sp),
                          gapH(AppSpacing.xs),
                          Text(
                            plan.badgeLabel!,
                            style: AppText.labelSm.copyWith(
                              color: plan.accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    gapV(AppSpacing.xl),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: widget.ctaLabel,
                      onPress: () => Navigator.pop(context),
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
