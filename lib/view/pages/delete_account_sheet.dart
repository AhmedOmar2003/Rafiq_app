import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/subscription/plan.dart';

/// Context-aware delete-account confirmation sheet.
///
/// The message body adapts to what the user will actually lose:
///   • regular user        → "your account + reviews"
///   • provider on Free    → "+ your business + places"
///   • provider on Pro/Max → "+ your active <Plan> subscription will be
///                            canceled"
///
/// Returns `true` from [show] when the user confirms, `false` / `null`
/// otherwise. The caller is responsible for calling the RPC and signing
/// out.
class DeleteAccountSheet {
  DeleteAccountSheet._();

  static Future<({bool confirmed, String? reason})> show(
    BuildContext context, {
    required bool isProvider,
    required PlanTier tier,
    String? planDisplayName,
  }) async {
    final reasonCtl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColor.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xxl),
      ),
      builder: (sheetCtx) {
        final body = _resolveBody(
          isProvider: isProvider,
          tier: tier,
          planDisplayName: planDisplayName,
        );
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl.w,
              AppSpacing.lg.h,
              AppSpacing.xxl.w,
              MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.xxl.h,
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
                Row(
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: const BoxDecoration(
                        color: AppColor.errorBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: AppColor.error,
                        size: 30.sp,
                      ),
                    ),
                    gapH(AppSpacing.md),
                    Expanded(
                      child: Text(
                        AppCopy.deleteAccountTitle,
                        style: AppText.headingSm,
                      ),
                    ),
                  ],
                ),
                gapV(AppSpacing.lg),
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg.w),
                  decoration: BoxDecoration(
                    color: AppColor.errorBg,
                    borderRadius: AppRadii.rMd,
                    border: Border.all(
                      color: AppColor.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    body,
                    style: AppText.bodyMd.copyWith(
                      color: AppColor.error,
                      height: 1.6,
                    ),
                  ),
                ),
                gapV(AppSpacing.xl),
                AppInput(
                  controller: reasonCtl,
                  label: AppCopy.deleteAccountReasonHint,
                  hintText: '',
                  textInputAction: TextInputAction.done,
                  paddingBottom: 0,
                ),
                gapV(AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: AppCopy.deleteAccountConfirm,
                    onPress: () => Navigator.pop(sheetCtx, true),
                    // Danger override: keep AppButton's height/typography
                    // but swap the fill to error so the action reads as
                    // destructive at a glance.
                    buttonStyle: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.error,
                      foregroundColor: AppColor.white,
                      minimumSize: Size.fromHeight(52.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.rMd,
                      ),
                      elevation: 0,
                    ),
                    textStyle: AppText.labelLg.copyWith(
                      color: AppColor.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                gapV(AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: AppCopy.cancel,
                    onPress: () => Navigator.pop(sheetCtx, false),
                    variant: AppButtonVariant.outline,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final reason = reasonCtl.text.trim();
    reasonCtl.dispose();
    return (
      confirmed: result == true,
      reason: reason.isEmpty ? null : reason,
    );
  }

  static String _resolveBody({
    required bool isProvider,
    required PlanTier tier,
    String? planDisplayName,
  }) {
    if (!isProvider) return AppCopy.deleteAccountBodyRegular;
    if (tier == PlanTier.free) return AppCopy.deleteAccountBodyProviderFree;
    final name = planDisplayName ?? (tier == PlanTier.pro ? 'برو' : 'ماكس');
    return AppCopy.deleteAccountBodyProviderPaidPrefix +
        name +
        AppCopy.deleteAccountBodyProviderPaidSuffix;
  }
}
