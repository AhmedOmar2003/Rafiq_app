import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomStartButtonQuestionScreen extends StatelessWidget {
  const CustomStartButtonQuestionScreen({
    super.key,
    required this.onPressed,
    required this.isActiveOutputStream,
    required this.text,
  });

  final VoidCallback onPressed;
  final Stream<bool> isActiveOutputStream;
  final String text;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: isActiveOutputStream,
      builder: (context, snapshot) => MaterialButton(
        height: 10.h,
        minWidth: 20.w,
        onPressed: snapshot.data == null
            ? null
            : snapshot.data == true
                ? onPressed
                : null,
        child: Container(
          alignment: AlignmentDirectional.center,
          height: 55.h,
          width: 342.w,
          decoration: BoxDecoration(
            color: snapshot.data == null
                ? AppColor.gray
                : snapshot.data == true
                    ? AppColor.primary
                    : AppColor.gray,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            text,
            style: AppText.headingLg,
          ),
        ),
      ),
    );
  }
}
