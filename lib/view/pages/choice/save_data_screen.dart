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
                            style: TextStyleTheme.textStyle22Medium.copyWith(
                              height: 1.4,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.1),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeView(),
                        ),
                      );
                    },
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColor.primary.withOpacity(0.2),
                            offset: const Offset(0, 3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
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
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          animationDuration: const Duration(milliseconds: 150),
                        ),
                        textStyle: TextStyleTheme.textStyle20Medium.copyWith(
                          color: AppColor.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
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
