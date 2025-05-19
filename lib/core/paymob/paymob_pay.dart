import 'package:flutter/material.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/paymob/paymob_manager.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/utils/text_style_theme.dart';

class PayMobPay extends StatelessWidget {
  final double price;
  final int placeId;

  const PayMobPay({
    Key? key,
    required this.price,
    required this.placeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("دفع الفعالية"),
        backgroundColor: Color(0xff0AA7CB),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "المبلغ المطلوب: ${price.toStringAsFixed(2)} جنيه",
              style: TextStyleTheme.textStyle20Bold,
            ),
            SizedBox(height: 20.h),
            AppButton(
              text: "ادفع الآن",
              textStyle: TextStyleTheme.textStyle18Medium,
              buttonStyle: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff0AA7CB),
                fixedSize: Size(300.w, 50.h),
              ),
              onPress: () async {
                try {
                  await PayMobManager().getPaymentKey(
                    amount: price,
                    currency: "EGP",
                    context: context,
                    placeId: placeId,
                  );
                  // العودة إلى الصفحة السابقة بعد الدفع
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ في الدفع: $e")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
