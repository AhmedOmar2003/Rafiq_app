import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rafiq_app/core/utils/app_color.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void navigateTo(Widget page, {bool removeHistory = false }) {
  Navigator.pushAndRemoveUntil(
    navigatorKey.currentContext!,
    MaterialPageRoute(
      builder: (context) => page,
    ),
        (route) => !removeHistory,
  );
}

enum ToastStates { success, fail, warning }

void showToast(
    {required String msg, ToastStates state = ToastStates.success}) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: state == ToastStates.fail
        ? AppColor.error
        : state == ToastStates.warning
        ? AppColor.warning
        : AppColor.success,
    textColor: Colors.white,
    fontSize: 16.sp,
  );
}

enum MessageType { success, fail, warning }

void showMessage(String message, {MessageType type = MessageType.fail}) {
  if (message.isNotEmpty) {
    ScaffoldMessenger.of(
      navigatorKey.currentContext!,
    ).showSnackBar(
      SnackBar(
        backgroundColor: type == MessageType.fail
            ? AppColor.error
            : type == MessageType.warning
            ? AppColor.warning
            : AppColor.success,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
    log(message);
  }
}
