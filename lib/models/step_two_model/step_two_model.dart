class StepTwoModel {
  final String text;
  final String? icon;

  StepTwoModel({
    required this.text,
    this.icon,
  });
}

List<StepTwoModel> stepTwoList = [
  StepTwoModel(text: "أقل من 100 جنيه"),
  StepTwoModel(text: "100 إلى 500 جنيه"),
  StepTwoModel(text: "500 إلى 1000 جنيه"),
  StepTwoModel(text: " 1000 إلى 1500 جنيه"),
  StepTwoModel(text: "لسة محددتش"),
];
