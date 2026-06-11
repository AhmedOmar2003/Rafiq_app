class PasswordPolicy {
  static const int minimumLength = 8;

  static bool hasMinimumLength(String password) =>
      password.length >= minimumLength;

  static bool hasUppercase(String password) =>
      RegExp(r'[A-Z]').hasMatch(password);

  static bool hasLowercase(String password) =>
      RegExp(r'[a-z]').hasMatch(password);

  static bool hasNumber(String password) => RegExp(r'\d').hasMatch(password);

  static bool hasSpecialCharacter(String password) =>
      RegExp(r'[#?!@$%^&*\-_.]').hasMatch(password);

  static bool isStrong(String password) =>
      hasMinimumLength(password) &&
      hasUppercase(password) &&
      hasLowercase(password) &&
      hasNumber(password) &&
      hasSpecialCharacter(password);

  static String? validateNewPassword(String? password) {
    if (password == null || password.isEmpty) return 'اكتب كلمة السر';
    if (!isStrong(password)) return requirementMessage;
    return null;
  }

  static const String requirementMessage =
      'استخدم 8 حروف على الأقل: حرف كبير، حرف صغير، رقم ورمز.';
}
