import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/view/home/home_view.dart';
import 'package:rafiq_app/view/pages/choice/take_data_screen.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
import '../../../core/design/app_button.dart';
import '../../../core/utils/assets.dart';

/// A screen that allows users to choose between being a regular user or a service provider.
class ChoiceScreen extends StatefulWidget {
  /// Callback triggered when a regular user plan is selected
  final VoidCallback onPlanSelected;

  /// Callback triggered when a service provider plan is selected
  final VoidCallback onNoPlanSelected;

  /// Callback triggered when the next button is pressed
  final VoidCallback onNext;

  const ChoiceScreen({
    super.key,
    required this.onPlanSelected,
    required this.onNoPlanSelected,
    required this.onNext,
  });

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen> {
  /// Tracks which option is selected (0 for regular user, 1 for service provider)
  int? _selectedIndex;

  /// Message shown when no option is selected
  static const String _noSelectionMessage = "الرجاء اختيار خيار قبل المتابعة";

  /// Handle back button press
  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    return false;
  }

  /// Navigate to the appropriate screen based on selection
  void _handleNavigation() {
    if (_selectedIndex == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    } else if (_selectedIndex == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AddPlaceScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_noSelectionMessage),
          duration: Duration(seconds: 2),
        ),
      );
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColor.ofWhite,
          body: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: AppColor.ofWhite,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          children: [
                            SizedBox(height: 80.h),
                            Container(
                              height: 220.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20.r),
                                child: Image.asset(
                                  AppImages.choice,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(height: 40.h),
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 600),
                              tween: Tween(begin: 0, end: 1),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: CustomTextWidget(
                                      label: "هل أنت مستخدم عادي ولا مقدم خدمة (صاحب مكان)؟",
                                      style: TextStyleTheme.textStyle22Medium.copyWith(
                                        height: 1.5,
                                        color: const Color(0xFF2B2B2B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 30.h),
                            _buildOptionButton(
                              label: "مستخدم عادي",
                              index: 0,
                              icon: Icons.person_outline_rounded,
                              onTap: () {
                                setState(() => _selectedIndex = 0);
                                widget.onPlanSelected();
                              },
                            ),
                            _buildOptionButton(
                              label: "مقدم خدمة",
                              index: 1,
                              icon: Icons.store_rounded,
                              onTap: () {
                                setState(() => _selectedIndex = 1);
                                widget.onNoPlanSelected();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    decoration: BoxDecoration(
                      color: AppColor.ofWhite,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: AppButton(
                      text: "اللي بعده",
                      onPress: _handleNavigation,
                      buttonStyle: ElevatedButton.styleFrom(
                        fixedSize: Size(342.w, 55.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                        backgroundColor: AppColor.primary,
                        shadowColor: Colors.transparent,
                      ),
                      textStyle: TextStyleTheme.textStyle20Medium.copyWith(
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required int index,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      builder: (context, value, child) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            splashColor: AppColor.primary.withOpacity(0.1),
            highlightColor: AppColor.primary.withOpacity(0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                color: Color.lerp(Colors.white, AppColor.primary, value),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFF000000).withOpacity(0.1),
                    AppColor.primary,
                    value,
                  )!,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                      ? AppColor.primary.withOpacity(0.1)
                      : Colors.black.withOpacity(0.04),
                    blurRadius: isSelected ? 12 : 6,
                    offset: Offset(0, isSelected ? 4 : 2),
                    spreadRadius: isSelected ? 0.5 : 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColor.primary.withOpacity(0.1),
                        Colors.white.withOpacity(0.2),
                        value,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Color.lerp(AppColor.primary, Colors.white, value),
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextWidget(
                          label: label,
                          style: TextStyleTheme.textStyle18Medium.copyWith(
                            color: Color.lerp(const Color(0xFF2B2B2B), Colors.white, value),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        SizedBox(height: 4.h),
                        CustomTextWidget(
                          label: index == 0 
                              ? "استكشف الأماكن وشارك تجاربك"
                              : "أضف مكانك وابدأ في استقبال الزوار",
                          style: TextStyleTheme.textStyle14Regular.copyWith(
                            color: Color.lerp(
                              const Color(0xFF666666),
                              Colors.white.withOpacity(0.8),
                              value,
                            ),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color.lerp(AppColor.primary.withOpacity(0.3), Colors.white, value),
                    size: 16.w,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
