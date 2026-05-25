import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// User / place avatar with graceful fallback to initials.
///
/// Never shows a broken image: if [imageUrl] is null or fails, it renders the
/// first letter of [name] on a brand-tinted circle.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.imageUrl, this.name, this.size = 44});

  final String? imageUrl;
  final String? name;
  final double size;

  String get _initial {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '؟';
    return n.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      color: AppColor.primary100,
      child: Text(_initial, style: AppText.titleMd.copyWith(color: AppColor.primary)),
    );

    return ClipOval(
      child: SizedBox(
        width: size.w,
        height: size.w,
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? fallback
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : Container(color: AppColor.neutral100),
              ),
      ),
    );
  }
}
