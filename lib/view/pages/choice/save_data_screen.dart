import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/view/home/home_view.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColor.ofWhite,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          CustomTextWidget(
                            label: "\"مبروك عليك تم حفظ بيانات مكانك بنجاح\"",
                            style: TextStyleTheme.textStyle22Medium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    verticalSpace(50),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Screenshot 2024-12-15 181624-Photoroom 1.png',
                            height: 280.h,
                            fit: BoxFit.contain,
                          ),
                          Positioned(
                            top: -30.h,
                            child: Image.asset(
                              'assets/images/Screenshot 2024-12-15 185838-Photoroom 1.png',
                              height: 120.h,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: AppButton(
                  text: "ابحث عن مكانك الآن",
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeView(),
                      ),
                    );
                  },
                  buttonStyle: ElevatedButton.styleFrom(
                    fixedSize: Size(342.w, 55.h),
                    backgroundColor: AppColor.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  textStyle: TextStyleTheme.textStyle20Medium.copyWith(
                    color: AppColor.white,
                  ),
                ),
              ),
              verticalSpace(32),
            ],
          ),
        ),
      ),
    );
  }
}
