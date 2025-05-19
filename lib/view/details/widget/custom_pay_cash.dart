import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/models/payments/payments_model.dart';
import 'package:rafiq_app/view/details/widget/payments.dart';
import 'package:rafiq_app/view/pages/cash/cash_page.dart';
import '../../../core/design/app_button.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';

class CustomPayCash extends StatefulWidget {
  const CustomPayCash({
    super.key,
  });

  @override
  State<CustomPayCash> createState() => _CustomPayCashState();
}

class _CustomPayCashState extends State<CustomPayCash> {
  int currentIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.h),
      height: 592.h,
      width: double.infinity.w,
      color: AppColor.ofWhite,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: CustomTextWidget(
                label: "اختار طريقة الدفع",
                style: TextStyleTheme.textStyle20Bold,
              ),
            ),
            verticalSpace(15),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 33.w),
              child: CustomTextWidget(
                label: "المحافظ الإلكترونية او البطاقات البنكية",
                style: TextStyleTheme.textStyle18Medium,
              ),
            ),
            verticalSpace(16),
            ...List.generate(
              paymentsList.length,
              (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  child: Payments(
                    model: paymentsList[index],
                    color: currentIndex == index ? Colors.green : Colors.white,
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: AppButton(
                text: "اللي بعده",
                textStyle: TextStyleTheme.textStyle24Medium,
                buttonStyle: ElevatedButton.styleFrom(
                  fixedSize: Size(342.w, 55.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPress: () {
                  navigateTo(const CashPage());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
