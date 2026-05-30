import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Generic, reusable layout for any legal / informational document inside
/// the app (Privacy Policy, Terms, Help Center, etc.).
///
/// Why a single widget:
///   * Same design DNA across every "long-form Arabic text" surface — the
///     user sees a consistent hero card, the same hairline section
///     dividers, and the same updated-on chip on every page.
///   * Adding a new document is a one-liner: pass [icon], [title], [intro],
///     and a list of [LegalSection]s. No layout work needed.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.intro,
    required this.sections,
    this.lastUpdated,
  });

  final String title;
  final IconData icon;
  final String intro;
  final List<LegalSection> sections;

  /// Optional "آخر تحديث" chip shown under the hero.
  final String? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppPageHeader(title: title),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w,
          AppSpacing.lg.h,
          AppSpacing.lg.w,
          AppSpacing.huge.h,
        ),
        children: [
          // Hero — soft branded card with the document icon + intro
          _Hero(icon: icon, title: title, intro: intro, lastUpdated: lastUpdated),
          gapV(AppSpacing.xl),
          for (var i = 0; i < sections.length; i++) ...[
            _SectionBlock(index: i + 1, section: sections[i]),
            if (i < sections.length - 1) gapV(AppSpacing.lg),
          ],
          gapV(AppSpacing.xl),
          _FooterNote(),
        ],
      ),
    );
  }
}

/// One titled paragraph + optional bullet list.
class LegalSection {
  const LegalSection({
    required this.title,
    required this.body,
    this.bullets = const [],
  });

  final String title;
  final String body;
  final List<String> bullets;
}

// ===========================================================================
// Internals
// ===========================================================================

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.title,
    required this.intro,
    this.lastUpdated,
  });

  final IconData icon;
  final String title;
  final String intro;
  final String? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColor.primary.withValues(alpha: 0.10),
            AppColor.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: AppRadii.rXl,
        border: Border.all(color: AppColor.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: AppRadii.rMd,
                  boxShadow: AppShadows.primaryGlow,
                ),
                child: Icon(icon, color: AppColor.white, size: 26.sp),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          gapV(AppSpacing.md),
          Text(
            intro,
            style: AppText.bodyMd.copyWith(
              color: AppColor.textSecondary,
              height: 1.7,
            ),
          ),
          if (lastUpdated != null) ...[
            gapV(AppSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: 6.h,
              ),
              decoration: BoxDecoration(
                color: AppColor.surfaceCard,
                borderRadius: AppRadii.rPill,
                border: Border.all(color: AppColor.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update_rounded,
                      size: 14.sp, color: AppColor.textSecondary),
                  gapH(AppSpacing.xs),
                  Text(
                    'آخر تحديث: $lastUpdated',
                    style: AppText.caption.copyWith(
                      color: AppColor.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.index, required this.section});
  final int index;
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: AppColor.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: AppText.labelSm.copyWith(
                    color: AppColor.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              gapH(AppSpacing.sm),
              Expanded(
                child: Text(
                  section.title,
                  style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          gapV(AppSpacing.md),
          Text(
            section.body,
            style: AppText.bodyMd.copyWith(height: 1.85),
          ),
          if (section.bullets.isNotEmpty) ...[
            gapV(AppSpacing.md),
            ...section.bullets.map(
              (b) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: const BoxDecoration(
                          color: AppColor.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    gapH(AppSpacing.sm),
                    Expanded(
                      child: Text(
                        b,
                        style: AppText.bodyMd.copyWith(height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: AppColor.primary, size: 16.sp),
          gapH(AppSpacing.sm),
          Expanded(
            child: Text(
              'شكراً إنك بتقرأ. لو عندك أي استفسار، تواصل معانا من صفحة البروفايل.',
              style: AppText.bodySm.copyWith(color: AppColor.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
