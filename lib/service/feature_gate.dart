import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/subscription_service.dart';

/// Centralised entitlement preflight.
///
/// Use this anywhere the UI is about to do something a paid tier unlocks
/// (uploading another image, attaching a video, creating a campaign, etc.).
///
/// The gate first asks [SubscriptionService] for the resolved entitlement,
/// runs the requested check, and — on failure — opens an [UpgradeSheet] so
/// the user can convert without losing context.
class FeatureGate {
  FeatureGate._();

  /// Returns `true` if the provider can add one more gallery image.
  static bool canAttachAnotherImage({
    required ProviderEntitlement entitlement,
    required int currentImages,
  }) {
    return currentImages < entitlement.maxGalleryImages;
  }

  /// Returns `true` if the provider can attach a video.
  static bool canAttachVideo({
    required ProviderEntitlement entitlement,
    required int currentVideos,
  }) {
    return currentVideos < entitlement.maxVideos;
  }

  /// Returns `true` if the provider can create another place.
  static bool canCreatePlace({
    required ProviderEntitlement entitlement,
    required int currentPlaces,
  }) {
    return currentPlaces < entitlement.maxPlaces;
  }

  /// Returns `true` if the action is permitted; otherwise opens an upgrade
  /// sheet (non-modal) and returns `false`. Use this as a one-line guard
  /// at the top of an upload handler:
  ///
  ///   if (!await FeatureGate.requireImageSlot(context, ent, n)) return;
  static Future<bool> requireImageSlot(
    BuildContext context,
    ProviderEntitlement ent,
    int currentImages,
  ) async {
    if (canAttachAnotherImage(
      entitlement: ent,
      currentImages: currentImages,
    )) {
      return true;
    }
    await UpgradeSheet.show(
      context,
      reason: _ReasonText.gallery(ent.maxGalleryImages),
      currentTier: ent.tier,
    );
    return false;
  }

  static Future<bool> requireVideoSlot(
    BuildContext context,
    ProviderEntitlement ent,
    int currentVideos,
  ) async {
    if (canAttachVideo(
      entitlement: ent,
      currentVideos: currentVideos,
    )) {
      return true;
    }
    await UpgradeSheet.show(
      context,
      reason: _ReasonText.video(ent.maxVideos),
      currentTier: ent.tier,
    );
    return false;
  }

  static Future<bool> requirePlaceSlot(
    BuildContext context,
    ProviderEntitlement ent,
    int currentPlaces,
  ) async {
    if (canCreatePlace(
      entitlement: ent,
      currentPlaces: currentPlaces,
    )) {
      return true;
    }
    await UpgradeSheet.show(
      context,
      reason: _ReasonText.places(ent.maxPlaces),
      currentTier: ent.tier,
    );
    return false;
  }
}

class _ReasonText {
  static String gallery(int cap) =>
      'الخطة الحالية تسمحلك بـ $cap صورة في المعرض.';
  static String video(int cap) =>
      cap == 0
          ? 'الفيديوهات متاحة من خطة برو وفوق.'
          : 'الخطة الحالية تسمحلك بـ $cap فيديو.';
  static String places(int cap) =>
      'الخطة الحالية تسمحلك بـ $cap مكان.';
}

/// Bottom sheet shown when a gate fails. Lets the user upgrade in 1 tap
/// without leaving the form they're filling out.
class UpgradeSheet {
  UpgradeSheet._();

  static Future<void> show(
    BuildContext context, {
    required String reason,
    required PlanTier currentTier,
    VoidCallback? onUpgrade,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.topOnly(AppRadii.xxl)),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl.w,
              AppSpacing.xxl.h,
              AppSpacing.xxl.w,
              AppSpacing.xxl.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: AppColor.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 40.sp,
                    color: AppColor.primary,
                  ),
                ),
                gapV(AppSpacing.lg),
                Text(
                  AppCopy.subLimitReached,
                  style: AppText.headingSm,
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.sm),
                Text(
                  reason,
                  style: AppText.bodyMd.copyWith(
                    color: AppColor.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                gapV(AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: AppCopy.subUpgradeCta,
                    onPress: () {
                      Navigator.pop(sheetCtx);
                      onUpgrade?.call();
                    },
                  ),
                ),
                gapV(AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: AppCopy.cancel,
                    onPress: () => Navigator.pop(sheetCtx),
                    variant: AppButtonVariant.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Convenience: small inline status chip that shows on a form so the user
/// knows their current cap before they hit it.
class EntitlementChip extends StatelessWidget {
  const EntitlementChip({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final atCap = used >= limit;
    final color = atCap ? AppColor.error : AppColor.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: atCap ? AppColor.errorBg : AppColor.surface,
        borderRadius: AppRadii.rPill,
        border: Border.all(
          color: atCap ? AppColor.error : AppColor.border,
        ),
      ),
      child: Text(
        '$label  $used / $limit',
        style: AppText.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
