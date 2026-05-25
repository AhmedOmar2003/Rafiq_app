import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Unified text field.
///
/// One input style for the whole app (the codebase previously had two: a
/// shadow-card field and a bordered theme field). This is the shadow-card field,
/// now token-driven, with optional [label], [helperText] and a focus ring in the
/// brand color. RTL-first (defaults to right alignment). Backward compatible
/// with all previous parameters.
class AppInput extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? label;
  final String? helperText;

  final bool readOnly;
  final bool enabled;
  final bool isPassword;
  final int maxLines;
  final int? maxLength;

  final Widget? suffixIcon, prefixIcon;
  final TextInputType? type;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;

  final Function(String)? onChanged;
  final Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String?>? validator;

  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final TextStyle? textStyle;
  final double paddingBottom, paddingTop;

  // Back-compat escape hatches
  final InputDecoration? decoration;
  final Color? fillColor;
  final bool? isFilled;

  const AppInput({
    super.key,
    required this.hintText,
    this.controller,
    this.label,
    this.helperText,
    this.validator,
    this.paddingBottom = 16,
    this.paddingTop = 0,
    this.type,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.textStyle,
    this.focusNode,
    this.textInputAction,
    this.suffixIcon,
    this.prefixIcon,
    this.readOnly = false,
    this.enabled = true,
    this.isPassword = false,
    this.maxLines = 1,
    this.maxLength,
    this.textAlign = TextAlign.right,
    this.autofillHints,
    this.decoration,
    this.isFilled,
    this.fillColor,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.paddingBottom.h, top: widget.paddingTop.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!, style: AppText.labelMd.copyWith(color: AppColor.textPrimary)),
            gapV(AppSpacing.sm),
          ],
          Container(
            decoration: BoxDecoration(
              color: widget.fillColor ?? AppColor.surfaceCard,
              borderRadius: AppRadii.rLg,
              boxShadow: widget.enabled ? AppShadows.level1 : AppShadows.level0,
            ),
            child: TextFormField(
              textAlign: widget.textAlign,
              style: widget.textStyle ?? AppText.bodyLg.copyWith(color: AppColor.textPrimary),
              enabled: widget.enabled,
              autofillHints: widget.autofillHints,
              keyboardType: widget.type,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              obscureText: _obscure && widget.isPassword,
              textInputAction: widget.textInputAction,
              focusNode: widget.focusNode,
              controller: widget.controller,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onFieldSubmitted,
              validator: widget.validator,
              maxLines: widget.isPassword ? 1 : widget.maxLines,
              maxLength: widget.maxLength,
              decoration: widget.decoration ?? _decoration(),
            ),
          ),
          if (widget.helperText != null) ...[
            gapV(AppSpacing.xs),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              child: Text(widget.helperText!, style: AppText.bodySm),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration() {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: AppRadii.rLg,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      counterText: '',
      contentPadding:
          EdgeInsets.symmetric(horizontal: AppSpacing.xl.w, vertical: AppSpacing.lg.h),
      filled: widget.isFilled ?? true,
      fillColor: widget.fillColor ?? AppColor.surfaceCard,
      hintText: widget.hintText,
      hintStyle: AppText.bodyMd.copyWith(color: AppColor.textTertiary),
      prefixIcon: widget.prefixIcon != null
          ? Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w), child: widget.prefixIcon)
          : null,
      suffixIcon: _suffix(),
      border: border(Colors.transparent),
      enabledBorder: border(AppColor.border),
      focusedBorder: border(AppColor.primary, 1.5),
      errorBorder: border(AppColor.error),
      focusedErrorBorder: border(AppColor.error, 1.5),
      disabledBorder: border(AppColor.border.withOpacity(0.5)),
      errorStyle: AppText.bodySm.copyWith(color: AppColor.error),
    );
  }

  Widget? _suffix() {
    if (widget.isPassword) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        child: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColor.textTertiary,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );
    }
    if (widget.suffixIcon != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: widget.suffixIcon,
      );
    }
    return null;
  }
}
