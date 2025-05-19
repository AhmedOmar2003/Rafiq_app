import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;
  final VoidCallback onPress;
  final Widget? child;

  const AppButton({
    super.key,
    required this.text,
    required this.onPress,
    this.buttonStyle,
    this.textStyle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: buttonStyle,
      onPressed: onPress,
      child: child ??
          Text(
            textAlign: TextAlign.center,
            text,
            style: textStyle,
          ),
    );
  }
}
