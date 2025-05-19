// import 'package:flutter/material.dart';

// class CustomTextWidget extends StatelessWidget {
//   final String label;
//   final TextAlign? textAlign;
//   final int? maxLines;
//   final TextStyle? style;
//   final TextDirection? textDirection;

//   const CustomTextWidget({
//     super.key,
//     required this.label,
//     this.textAlign,
//     this.maxLines,
//     this.style,
//     this.textDirection,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       textDirection: textDirection,
//       maxLines: maxLines,
//       textAlign: textAlign,
//       label,
//       style: style,
//     );
//   }
// }

// import 'package:flutter/material.dart';

// class CustomTextWidget extends StatelessWidget {
//   final String label;
//   final TextAlign? textAlign;
//   final int? maxLines;
//   final TextStyle? style;
//   final TextDirection? textDirection;

//   const CustomTextWidget({
//     super.key,
//     required this.label,
//     this.textAlign,
//     this.maxLines,
//     this.style,
//     this.textDirection,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       label,
//       textDirection: textDirection,
//       maxLines: maxLines ??
//           null, // يسمح بعدد غير محدود من الأسطر إذا لم يتم تحديد قيمة
//       textAlign: textAlign ?? TextAlign.start,
//       style: style,
//       overflow: TextOverflow.visible, // جعل النص ينزل إلى السطر التالي تلقائيًا
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomTextWidget extends StatelessWidget {
  final String label;
  final TextAlign textAlign;
  final int? maxLines;
  final TextStyle? style;
  final TextDirection? textDirection;
  //final TextOverflow overflow; // خاصية جديدة

  const CustomTextWidget({
    super.key,
    required this.label,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.style,
    this.textDirection,
    //this.overflow = TextOverflow., // القيمة الافتراضية
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textDirection: textDirection,
      maxLines: maxLines,
      textAlign: textAlign,
      style: style,
      overflow: TextOverflow.visible, // تمرير الخاصية الجديدة إلى Text
    );
  }
}
