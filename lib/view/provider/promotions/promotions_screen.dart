import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

/// Promotional campaigns screen.
///
/// Pro+   → list / create / pause campaigns (currently a clean empty state
///         since campaigns are wired to the DB but not yet seeded).
/// Free   → upsell card explaining what promotions do, with an upgrade CTA.
class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key, this.providerId});
  final String? providerId;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      unpadded: true,
      header: const AppPageHeader(title: AppCopy.promoTitle),
      body: ValueListenableBuilder<ProviderEntitlement>(
        valueListenable: SubscriptionService.instance.entitlement,
        builder: (_, ent, __) {
          if (!ent.hasPromotions) {
            return _PromotionsLocked(providerId: providerId);
          }
          return _PromotionsEmpty(tier: ent.tier);
        },
      ),
    );
  }
}

class _PromotionsEmpty extends StatelessWidget {
  const _PromotionsEmpty({required this.tier});
  final PlanTier tier;

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
              AppCopy.promoEmptyBody,
              style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              textAlign: TextAlign.center,
            ),
            gapV(AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: AppCopy.promoCreateCta,
                onPress: () {
                  // Real form lives in a future migration; for the demo we
                  // simply confirm the action is reachable.
                  AppFeedback.info(AppCopy.loadingSuggestions);
                },
              ),
            ),
          ],
        ),
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
