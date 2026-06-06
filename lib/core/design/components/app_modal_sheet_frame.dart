import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// Shared structure for focused mobile bottom-sheet tasks.
///
/// Keeps the header and primary action reachable while only the body scrolls.
/// The height adapts to the keyboard and never consumes the full viewport.
class AppModalSheetFrame extends StatelessWidget {
  const AppModalSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.footer,
    this.maxHeightFactor = 0.88,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget body;
  final Widget? footer;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height - media.viewInsets.bottom)
        .clamp(240.0, double.infinity);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight * maxHeightFactor,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              AppSpacing.sm.h,
              AppSpacing.lg.w,
              AppSpacing.lg.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        gapH(AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppText.headingSm.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty) ...[
                              gapV(AppSpacing.xs),
                              Text(
                                subtitle!,
                                style: AppText.bodySm.copyWith(
                                  color: AppColor.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      gapH(AppSpacing.sm),
                      Semantics(
                        button: true,
                        label: AppCopy.cancel,
                        child: IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          tooltip: AppCopy.cancel,
                          icon: const Icon(Icons.close_rounded),
                          color: AppColor.textSecondary,
                          constraints: BoxConstraints.tightFor(
                            width: 48.w,
                            height: 48.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                gapV(AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: body,
                  ),
                ),
                if (footer != null) ...[
                  gapV(AppSpacing.md),
                  Container(
                    padding: EdgeInsets.only(top: AppSpacing.md.h),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColor.border),
                      ),
                    ),
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
