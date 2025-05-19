import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomDivider extends StatelessWidget {
  const CustomDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Divider(
        color: const Color(0xff00004D).withOpacity(.30),
        height: 5,
        thickness: 1.5,
      ),
    );
  }
}
