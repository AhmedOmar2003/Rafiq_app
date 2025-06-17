import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/models/Api_model/api_model.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();
  bool isTimerFinished = false;
  final int countdownDuration = 60;

  Future<void> verifyCode() async {
    final String url = "http://${GlopalVariable.ipConfig}/Api/verify_code.php";
    final body = {
      "email": widget.email,
      "otp_code": codeController.text.trim(),
    };

    try {
      final response = await http.post(Uri.parse(url), body: body);
      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "تم التحقق من الكود بنجاح",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(
              email: widget.email,
              otpCode: codeController.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "رمز التحقق غير صحيح أو منتهي الصلاحية",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تعذر الاتصال بالخادم",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.ofWhite,
      appBar: AppBar(
        backgroundColor: AppColor.ofWhite,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: AppColor.black,
              size: 24.sp,
            ),
          ),
        ),
        title: Text(
          "رمز التحقق",
          style: TextStyleTheme.textStyle20Medium.copyWith(
            color: AppColor.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Section
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: AppColor.primary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColor.primary.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.primary.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColor.primary.withOpacity(0.1),
                              AppColor.primary.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 32.sp,
                          color: AppColor.primary,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        "تم إرسال الرمز",
                        style: TextStyleTheme.textStyle16Regular.copyWith(
                          color: AppColor.black.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        widget.email,
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: AppColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),
                // Verification Code Section
                Form(
                  key: formKey,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: PinCodeTextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      length: 4,
                      obscureText: true,
                      obscuringCharacter: "•",
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(12.r),
                        fieldHeight: 55.h,
                        fieldWidth: 55.h,
                        borderWidth: 1,
                        inactiveColor: AppColor.primary.withOpacity(0.2),
                        activeColor: AppColor.primary,
                        selectedColor: AppColor.primary,
                        activeFillColor: AppColor.primary.withOpacity(0.03),
                        inactiveFillColor: AppColor.primary.withOpacity(0.03),
                        selectedFillColor: AppColor.primary.withOpacity(0.05),
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      backgroundColor: Colors.transparent,
                      enableActiveFill: true,
                      appContext: context,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "يرجى إدخال رمز التحقق";
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                // Verify Button
                Container(
                  width: double.infinity,
                  height: 55.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColor.primary,
                        AppColor.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AppButton(
                    text: "تحقق",
                    textStyle: TextStyleTheme.textStyle18Medium.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    buttonStyle: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                    onPress: () {
                      if (formKey.currentState!.validate()) {
                        verifyCode();
                      }
                    },
                  ),
                ),
                SizedBox(height: 32.h),
                // Timer Section
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: AppColor.primary.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColor.primary.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.primary.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "الوقت المتبقي",
                        style: TextStyleTheme.textStyle16Regular.copyWith(
                          color: AppColor.black.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularCountDownTimer(
                            duration: countdownDuration,
                            initialDuration: 0,
                            width: 70.w,
                            height: 70.h,
                            ringColor: AppColor.primary.withOpacity(0.2),
                            fillColor: AppColor.primary,
                            backgroundColor: Colors.transparent,
                            textStyle: TextStyleTheme.textStyle16Medium.copyWith(
                              color: AppColor.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            isReverse: true,
                            isTimerTextShown: true,
                            onComplete: () {
                              setState(() {
                                isTimerFinished = true;
                              });
                            },
                          ),
                          Container(
                            width: 70.w,
                            height: 70.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColor.primary.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isTimerFinished) ...[
                  SizedBox(height: 24.h),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColor.primary.withOpacity(0.1),
                          AppColor.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColor.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          isTimerFinished = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColor.primary, width: 1),
                        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                      child: Text(
                        "إعادة الإرسال",
                        style: TextStyleTheme.textStyle16Medium.copyWith(
                          color: AppColor.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
