import 'package:flutter/material.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/view/home/widget/preference_step_layout.dart';
import '../../../models/step_two_model/step_two_model.dart';

class StepTwo extends StatefulWidget {
  final Function(String) onBudgetSelected;
  const StepTwo({super.key, required this.onBudgetSelected});

  @override
  State<StepTwo> createState() => _StepTwoState();
}

class _StepTwoState extends State<StepTwo> with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedBudget = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PreferenceStepLayout(
      title: AppCopy.stepBudgetTitle,
      subtitle: AppCopy.stepBudgetBody,
      children: List.generate(
        stepTwoList.length,
        (index) => PreferenceOptionCard(
          label: stepTwoList[index].text,
          isSelected: currentIndex == index,
          icon: Icons.account_balance_wallet_outlined,
          onTap: () {
            setState(() {
              currentIndex = index;
              selectedBudget = stepTwoList[index].text;
            });
            widget.onBudgetSelected(selectedBudget);
          },
        ),
      ),
    );
  }
}
