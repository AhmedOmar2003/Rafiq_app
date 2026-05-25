import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:rafiq_app/core/design/custom_app_bar.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: CustomAppBar(
        backgroundColor: AppColor.surface,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text("الدفع", style: AppText.headingLg),
        ),
      ),
    );
  }
}
