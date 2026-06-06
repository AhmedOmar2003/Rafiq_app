import 'package:flutter/material.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/view/home/widget/preference_step_layout.dart';
import '../../../models/step_three_model/step_three_model.dart';

class StepThree extends StatefulWidget {
  final Function(String) onActivitySelected;
  const StepThree({super.key, required this.onActivitySelected});

  @override
  State<StepThree> createState() => _StepThreeState();
}

class _StepThreeState extends State<StepThree>
    with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedActivity = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PreferenceStepLayout(
      title: AppCopy.stepActivityTitle,
      subtitle: AppCopy.stepActivityBody,
      children: List.generate(
        stepThreeList.length,
        (index) => PreferenceOptionCard(
          label: stepThreeList[index].text,
          isSelected: currentIndex == index,
          iconAsset: stepThreeList[index].icon,
          onTap: () {
            setState(() {
              currentIndex = index;
              selectedActivity = stepThreeList[index].text;
            });
            widget.onActivitySelected(selectedActivity);
          },
        ),
      ),
    );
  }
}
