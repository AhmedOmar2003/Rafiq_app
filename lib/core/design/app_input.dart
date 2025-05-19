import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_color.dart';

class AppInput extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final Color? fillColor;
  final bool? isFilled;
  final String hintText;
  final bool readOnly;
  final bool isPassword;
  final Widget? suffixIcon,prefixIcon;
  final TextInputType? type;
  final Function(String)? onChanged;
  final double paddingBottom, paddingTop;
  final FormFieldValidator<String?>? validator;
  final Function(String)? onFieldSubmitted;
  final TextStyle? textStyle;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  const AppInput({
    super.key,
    this.validator,
    this.controller,
    required this.hintText,
    this.paddingBottom = 16,
    this.paddingTop = 0,
    this.type,
    this.onChanged,
    this.textStyle,
    this.onFieldSubmitted,
    this.focusNode,
    this.textInputAction,
    this.suffixIcon,
    this.readOnly = false,
    this.isPassword = false,
    this.autofillHints,
    this.decoration,
    this.isFilled,
    this.fillColor, this.prefixIcon,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  bool isPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: widget.paddingBottom, top: widget.paddingTop),
      child: TextFormField(
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: const Color(0xff000000).withOpacity(.70),
        ),
        autofillHints: widget.autofillHints,
        keyboardType: widget.type,
        readOnly: widget.readOnly,
        obscureText: isPasswordHidden && widget.isPassword,
        textInputAction: widget.textInputAction,
        focusNode: widget.focusNode,
        controller: widget.controller,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
          fillColor: widget.fillColor,
          filled: widget.isFilled,
          hintText: widget.hintText,
          hintStyle: widget.textStyle,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                    color: AppColor.black,
                  ),
                  onPressed: () {
                    isPasswordHidden = !isPasswordHidden;
                    setState(() {});
                  },
                )
              : widget.suffixIcon,
        ),
      ),
    );
  }
}
