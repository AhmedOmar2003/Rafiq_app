import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Unified page scaffold.
///
/// One container for every product page so backgrounds, padding, header and
/// sticky-footer behavior are decided in ONE place, not per-screen.
///
/// Composition slots:
///   `header`    PreferredSizeWidget (AppPageHeader recommended).
///   `body`      page content. Padding is auto-applied unless [unpadded].
///   `footer`    sticky bottom region (CTA bar, comment composer).
///   `floatingOverlay` for full-screen success / error overlays.
///
/// Defaults follow the design-system spec:
///   - Surface: `color.surface.default` (cream) — cards on top will pop.
///   - Horizontal padding: `space.16` (DS gutter for mobile).
///   - Resizes for keyboard automatically.
///   - SafeArea handled.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.header,
    required this.body,
    this.footer,
    this.floatingOverlay,
    this.floatingActionButton,
    this.background,
    this.unpadded = false,
    this.scrollable = false,
  });

  /// PreferredSize header — usually [AppPageHeader].
  final PreferredSizeWidget? header;

  /// Main page content.
  final Widget body;

  /// Sticky footer pinned above the keyboard (sticky CTA, composer, etc.).
  final Widget? footer;

  /// Optional overlay shown above the whole page (e.g. AppSuccessView).
  final Widget? floatingOverlay;

  /// Floating action button (Scaffold-level).
  final Widget? floatingActionButton;

  /// Background override. Defaults to cream surface.
  final Color? background;

  /// Skip the default horizontal page padding (16dp). Use when the body
  /// manages its own gutters (e.g. full-bleed lists).
  final bool unpadded;

  /// Wrap the body in a [SingleChildScrollView] automatically.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final paddedBody = unpadded
        ? body
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: body,
          );

    final maybeScrolling = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
            child: paddedBody,
          )
        : Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
            child: paddedBody,
          );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: background ?? AppColor.surfaceDefault,
          resizeToAvoidBottomInset: true,
          appBar: header,
          floatingActionButton: floatingActionButton,
          body: SafeArea(
            top: header == null,
            child: footer == null
                ? maybeScrolling
                : Column(
                    children: [
                      Expanded(child: maybeScrolling),
                      footer!,
                    ],
                  ),
          ),
        ),
        if (floatingOverlay != null) floatingOverlay!,
      ],
    );
  }
}

/// Sticky footer container for a primary CTA — pairs with [AppPageScaffold.footer].
///
/// Sits above the keyboard, uses an elevated surface and a 1px hairline so it
/// reads as a separate plane without competing with the body.
class AppStickyFooter extends StatelessWidget {
  const AppStickyFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColor.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColor.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w,
            AppSpacing.md.h,
            AppSpacing.lg.w,
            AppSpacing.md.h,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section header inside a page body — the small "what's below" label above
/// a stack of cards / list rows. Matches the DS typography rhythm.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding,
  });

  final String title;

  /// Optional trailing action (text button, count badge, etc.).
  final Widget? action;

  /// Override the vertical padding around the section header.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.md.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.titleLg.copyWith(
                color: AppColor.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
