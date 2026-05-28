import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Unified page header (an AppBar that follows the design system).
///
/// One header DNA across the app — replaces the mix of `AppBar` /
/// `CustomAppBar` / inline Containers each screen used to roll its own.
///
/// Composition:
///   leading  → back button (auto when canPop, hidden otherwise)
///   title    → page title (label.lg)
///   subtitle → optional second line (body.sm, muted)
///   actions  → optional trailing icon buttons
///
/// Visual rules (per design-system spec):
///   - Surface: `color.surface.default` (cream) — sits flush with the page.
///   - Border: 1px hairline at the bottom (`color.border.default`).
///   - Title typography: `headline.sm` weight 600 — same on every screen.
///   - Touch target: 48dp on the leading button (DS accessibility rule).
/// Tonal variants for [AppPageHeader].
///
///   surface → cream background, dark text, hairline border (default).
///   brand   → primary background, white text, no border. Use for hero pages
///             like profile, chat, or anything that benefits from a strong
///             brand anchor at the top.
///   transparent → fully see-through (legacy `transparent: true`).
enum AppHeaderTone { surface, brand, transparent }

class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.tone = AppHeaderTone.surface,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final AppHeaderTone tone;
  final VoidCallback? onBack;

  /// Backward-compat: lets callers spell `transparent: true` instead of `tone:`.
  @Deprecated('Use tone: AppHeaderTone.transparent instead.')
  AppPageHeader.transparent({
    Key? key,
    required String title,
    String? subtitle,
    Widget? leading,
    List<Widget>? actions,
    bool centerTitle = false,
    VoidCallback? onBack,
  }) : this(
          key: key,
          title: title,
          subtitle: subtitle,
          leading: leading,
          actions: actions,
          centerTitle: centerTitle,
          tone: AppHeaderTone.transparent,
          onBack: onBack,
        );

  Color get _bg => switch (tone) {
        AppHeaderTone.surface => AppColor.surfaceDefault,
        AppHeaderTone.brand => AppColor.primary,
        AppHeaderTone.transparent => Colors.transparent,
      };

  Color get _fg => switch (tone) {
        AppHeaderTone.brand => AppColor.white,
        _ => AppColor.textPrimary,
      };

  BoxBorder? get _border => switch (tone) {
        AppHeaderTone.surface =>
          Border(bottom: BorderSide(color: AppColor.border, width: 1)),
        _ => null,
      };

  @override
  Size get preferredSize => Size.fromHeight(
        subtitle == null ? kToolbarHeight : kToolbarHeight + 18,
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final showLeading = leading != null || canPop;
    final fg = _fg;

    return Container(
      decoration: BoxDecoration(color: _bg, border: _border),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w,
            vertical: AppSpacing.xs.h,
          ),
          child: Row(
            children: [
              if (showLeading)
                leading ??
                    _HeaderIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      color: fg,
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      semanticLabel: 'رجوع',
                    )
              else
                SizedBox(width: AppSpacing.lg.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
                  child: Column(
                    crossAxisAlignment: centerTitle
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppText.headingSm.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: AppText.bodySm.copyWith(
                            color: tone == AppHeaderTone.brand
                                ? AppColor.white.withOpacity(0.85)
                                : AppColor.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: actions!)
              else
                SizedBox(width: showLeading ? 48.w : AppSpacing.lg.w),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact circular icon button used inside [AppPageHeader].
///
/// 40dp visual / 48dp hit area — meets accessibility minimums.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24.w,
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Center(
            child: Icon(icon, size: 22.sp, color: color ?? AppColor.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Trailing icon-button used in [AppPageHeader.actions].
class AppHeaderAction extends StatelessWidget {
  const AppHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.tone,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24.w,
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Center(
            child: Icon(icon, size: 22.sp, color: tone ?? AppColor.textPrimary),
          ),
        ),
      ),
    );
  }
}
