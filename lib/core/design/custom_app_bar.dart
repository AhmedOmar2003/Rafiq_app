import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? action;
  final Color? backgroundColor;
  final bool hideBack;
  final double? height;
  final Color backIconColor; // خاصية جديدة لتحديد لون سهم الرجوع

  const CustomAppBar({
    this.title,
    this.hideBack = false,
    this.action,
    this.backgroundColor,
    this.height,
    this.backIconColor = Colors.black, // اللون الافتراضي هو الأسود
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0.0,
      toolbarHeight: height ?? 80.h,
      title: title ?? const Text(''),
      titleSpacing: 0,
      actions: [action ?? Container()],
      leading: hideBack
          ? null
          : IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.arrow_back,
                size: 25,
                color: backIconColor, // استخدام اللون المحدد
              ),
            ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? 80.h);
}
