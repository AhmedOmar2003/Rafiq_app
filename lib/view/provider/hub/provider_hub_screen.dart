import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/pages/choice/take_data_screen.dart';
import 'package:rafiq_app/view/provider/analytics/analytics_screen.dart';
import 'package:rafiq_app/view/provider/promotions/promotions_screen.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final pid = widget.providerId;
    SubscriptionService.instance.loadCatalog();
    if (pid != null) {
      _providerId = pid;
      SubscriptionService.instance.loadEntitlement(pid);
    } else {
      _resolveProviderId();
    }
  }

  Future<void> _resolveProviderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('authUserId');
      if (userId == null) return;
      final row = await Supabase.instance.client
          .from('providers')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();
      final resolved = row?['id'] as String?;
      if (!mounted || resolved == null || resolved == _providerId) return;
      setState(() => _providerId = resolved);
      await SubscriptionService.instance.loadEntitlement(resolved);
    } catch (_) {
      // Keep the free fallback; the hub still opens and shows the catalog.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      // "تابع خدمتك" — same identity post-subscription, no role flip.
      header: const AppPageHeader(title: AppCopy.hubTitle),
      body: ValueListenableBuilder<ProviderEntitlement>(
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
              _Greeting(name: widget.providerName),
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
              _KpiStrip(entitlement: ent),
              gapV(AppSpacing.xxl),
              _FeatureTile(
                icon: Icons.store_rounded,
                title: AppCopy.hubFeatTitlePlaces,
                body: AppCopy.hubFeatBodyPlaces,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddPlaceScreen(),
                  ),
                ),
              ),
              gapV(AppSpacing.md),
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
          );
        },
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
              style:
                  AppText.titleMd.copyWith(color: AppColor.textPrimary),
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
              color: locked
                  ? AppColor.neutral100
                  : AppColor.primary50,
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
