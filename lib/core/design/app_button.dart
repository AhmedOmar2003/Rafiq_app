import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Button variants — one component, five intents.
enum AppButtonVariant {
  /// Filled coffee-brown. The single primary action on a screen.
  primary,

  /// Soft cream-filled. Secondary action sitting next to a primary.
  secondary,

  /// Transparent with brand border. Lower emphasis / alternative action.
  outline,

  /// Text-only, no background. Tertiary / inline action.
  ghost,

  /// Filled error. Irreversible / dangerous action (delete, remove).
  destructive,
}

/// Button sizes (control height + horizontal padding + label style).
enum AppButtonSize { sm, md, lg }

/// The one button to rule them all.
///
/// Replaces the three inconsistent button implementations (radius 8/15/25,
/// font 15/24/25). Defaults to a full-width primary CTA. Backward compatible:
/// existing call sites that pass [buttonStyle] / [textStyle] / [child] keep
/// working — those overrides take precedence over the variant system.
///
/// ```dart
/// AppButton(text: 'تسجيل الدخول', onPress: _login);                 // primary
/// AppButton(text: 'إلغاء', onPress: _cancel, variant: AppButtonVariant.outline);
/// AppButton(text: 'احذف', onPress: _del, variant: AppButtonVariant.destructive);
/// AppButton(text: 'حفظ', onPress: _save, isLoading: _saving);      // spinner
/// ```
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback onPress;

  // Design-system API
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isEnabled;
  final bool isFullWidth;
  final IconData? icon;

  // Backward-compatible escape hatches (take precedence when provided)
  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;
  final Widget? child;

  const AppButton({
    super.key,
    required this.text,
    required this.onPress,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.isEnabled = true,
    this.isFullWidth = true,
    this.icon,
    this.buttonStyle,
    this.textStyle,
    this.child,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        AppButtonSize.sm => 40.h,
        AppButtonSize.md => 52.h,
        AppButtonSize.lg => 58.h,
      };

  TextStyle get _labelStyle => switch (widget.size) {
        AppButtonSize.sm => AppText.labelMd,
        AppButtonSize.md => AppText.labelLg,
        AppButtonSize.lg => AppText.labelLg,
      };

  ({Color bg, Color fg, Color? border, List<BoxShadow> shadow}) get _colors {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return (bg: AppColor.primary, fg: AppColor.textOnPrimary, border: null, shadow: AppShadows.primaryGlow);
      case AppButtonVariant.secondary:
        return (bg: AppColor.sand200, fg: AppColor.primary, border: null, shadow: AppShadows.level0);
      case AppButtonVariant.outline:
        return (bg: Colors.transparent, fg: AppColor.primary, border: AppColor.primary, shadow: AppShadows.level0);
      case AppButtonVariant.ghost:
        return (bg: Colors.transparent, fg: AppColor.primary, border: null, shadow: AppShadows.level0);
      case AppButtonVariant.destructive:
        return (bg: AppColor.error, fg: AppColor.white, border: null, shadow: AppShadows.level0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Back-compat path: caller supplied a raw ElevatedButton style/child.
    if (widget.buttonStyle != null || widget.child != null) {
      return _ScaleOnPress(
        child: ElevatedButton(
          style: widget.buttonStyle,
          onPressed: _effectiveOnPress,
          child: widget.child ??
              Text(widget.text, textAlign: TextAlign.center, style: widget.textStyle),
        ),
      );
    }

    final c = _colors;
    final bool disabled = !widget.isEnabled || widget.isLoading;
    final double opacity = disabled ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: _ScaleOnPress(
        enabled: !disabled,
        onPressedDown: (v) => setState(() => _pressed = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : widget.onPress,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: _height,
            width: widget.isFullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: AppRadii.rMd,
              border: c.border != null ? Border.all(color: c.border!, width: 1.5) : null,
              boxShadow: _pressed ? AppShadows.level0 : c.shadow,
            ),
            child: _content(c.fg),
          ),
        ),
      ),
    );
  }

  Widget _content(Color fg) {
    if (widget.isLoading) {
      return SizedBox(
        height: 22.h,
        width: 22.h,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
      );
    }
    final label = Text(
      widget.text,
      textAlign: TextAlign.center,
      style: (widget.textStyle ?? _labelStyle).copyWith(color: fg),
    );
    if (widget.icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 20.sp, color: fg),
        gapH(AppSpacing.sm),
        Flexible(child: label),
      ],
    );
  }

  VoidCallback? get _effectiveOnPress =>
      (!widget.isEnabled || widget.isLoading) ? null : widget.onPress;
}

/// Tactile press-scale wrapper (shared press feel for all buttons).
class _ScaleOnPress extends StatefulWidget {
  const _ScaleOnPress({
    required this.child,
    this.enabled = true,
    this.onPressedDown,
  });

  final Widget child;
  final bool enabled;
  final ValueChanged<bool>? onPressedDown;

  @override
  State<_ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<_ScaleOnPress> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled) return;
    setState(() => _down = v);
    widget.onPressedDown?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
