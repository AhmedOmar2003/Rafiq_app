import 'package:flutter/material.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      header: AppPageHeader(title: AppCopy.paymentTitle),
      body: SizedBox.shrink(),
    );
  }
}
