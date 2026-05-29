import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import 'package:rafiq_app/view/pages/profile_page.dart';

/// One-tap entry to the [ProfilePage].
///
/// Goes in the trailing slot of an [AppPageHeader] on every primary
/// surface (HomeView, ProviderHub) so the user always has a visible exit
/// to settings, logout, subscription, and delete-account.
///
/// Reads the current avatar from [ProfileImageStore] so it stays in sync
/// when the user changes their picture.
class ProfilePill extends StatelessWidget {
  const ProfilePill({super.key, this.radius = 18});

  /// Visual radius in design pixels; the [SizedBox] scales it by ScreenUtil.
  final double radius;

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    ).then((_) {
      // Picture may have changed inside Profile — refresh the store so the
      // pill swaps to the new image without a full screen rebuild.
      ProfileImageStore.instance.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'الملف الشخصي',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        child: InkResponse(
          onTap: () => _open(context),
          radius: 24.w,
          child: ValueListenableBuilder<ProfileImageState>(
            valueListenable: ProfileImageStore.instance,
            builder: (_, snap, __) {
              final ImageProvider provider = snap.bytes != null
                  ? MemoryImage(snap.bytes!)
                  : snap.file != null
                      ? FileImage(snap.file!)
                      : const AssetImage(
                              'assets/images/default_profile.webp')
                          as ImageProvider;
              return CircleAvatar(
                radius: radius.w,
                backgroundColor: AppColor.surfaceMuted,
                backgroundImage: provider,
              );
            },
          ),
        ),
      ),
    );
  }
}
