import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../security/password_policy.dart';
import '../tokens/tokens.dart';

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final requirements = [
      ('8 حروف أو أكتر', PasswordPolicy.hasMinimumLength(password)),
      (
        'حرف كبير وصغير',
        PasswordPolicy.hasUppercase(password) &&
            PasswordPolicy.hasLowercase(password),
      ),
      ('رقم', PasswordPolicy.hasNumber(password)),
      ('رمز مميز', PasswordPolicy.hasSpecialCharacter(password)),
    ];

    return Semantics(
      container: true,
      label: 'شروط كلمة السر',
      child: Wrap(
        spacing: AppSpacing.sm.w,
        runSpacing: AppSpacing.sm.h,
        children: requirements
            .map(
              (requirement) => _RequirementChip(
                label: requirement.$1,
                isMet: requirement.$2,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColor.success : AppColor.textSecondary;
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.xs.h,
      ),
      decoration: BoxDecoration(
        color: isMet
            ? AppColor.success.withValues(alpha: 0.10)
            : AppColor.surfaceVariant,
        borderRadius: AppRadii.rPill,
        border: Border.all(
          color: isMet
              ? AppColor.success.withValues(alpha: 0.30)
              : AppColor.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 15.sp,
            color: color,
          ),
          gapH(AppSpacing.xs),
          Text(label, style: AppText.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}
