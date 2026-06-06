import 'package:flutter/material.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/view/home/widget/preference_step_layout.dart';
import '../../../models/step_one_model/step_one_model.dart';

class StepOne extends StatefulWidget {
  final Function(String) onCitySelected;
  const StepOne({super.key, required this.onCitySelected});

  @override
  State<StepOne> createState() => _StepOneState();
}

class _StepOneState extends State<StepOne> with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedCity = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PreferenceStepLayout(
      title: AppCopy.stepCityTitle,
      subtitle: AppCopy.stepCityBody,
      children: List.generate(
        stepOneList.length,
        (index) => PreferenceOptionCard(
          label: stepOneList[index].text,
          isSelected: currentIndex == index,
          icon: Icons.location_city_outlined,
          onTap: () {
            setState(() {
              currentIndex = index;
              selectedCity = stepOneList[index].text;
            });
            widget.onCitySelected(selectedCity);
          },
        ),
      ),
    );
  }
}
