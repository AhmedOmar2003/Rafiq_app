import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
        ? Colors.red
        : state == ToastStates.warning
        ? Colors.yellow
        : Colors.green,
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
            ? Colors.red
            : type == MessageType.warning
            ? Colors.yellow
            : Colors.green,
        content: Text(
          message,
          style: TextStyle(
            color: type == MessageType.fail
                ? Colors.white
                : type == MessageType.warning
                ? Colors.black
                : Colors.white,
          ),
        ),
      ),
    );
    log(message);
  }
}
