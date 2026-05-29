import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/service/connectivity_service.dart';

/// Global, friendly offline indicator.
///
/// Wrap the whole app once (see RafiqApp). It overlays a soft amber banner at
/// the bottom whenever the device loses connectivity, with warm Egyptian-Arabic
/// copy — never a harsh technical error. When connection returns it briefly
/// confirms, then slides away. Does not block the UI: the app stays usable with
/// cached content.
class AppConnectivityScope extends StatefulWidget {
  const AppConnectivityScope({super.key, required this.child});
  final Widget child;

  @override
  State<AppConnectivityScope> createState() => _AppConnectivityScopeState();
}

class _AppConnectivityScopeState extends State<AppConnectivityScope> {
  bool _showBackOnline = false;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.init();
    ConnectivityService.instance.online.addListener(_onChange);
  }

  void _onChange() {
    final online = ConnectivityService.instance.isOnline;
    if (_lastOnline == false && online) {
      setState(() => _showBackOnline = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    }
    _lastOnline = online;
  }

  @override
  void dispose() {
    ConnectivityService.instance.online.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.online,
      builder: (context, online, _) {
        final bool showOffline = !online;
        return Stack(
          textDirection: TextDirection.rtl,
          children: [
            widget.child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                  child: showOffline
                      ? const _Banner(
                          key: ValueKey('offline'),
                          tone: _BannerTone.warning,
                          icon: Icons.wifi_off_rounded,
                          text: AppCopy.offlineBanner,
                        )
                      : _showBackOnline
                          ? const _Banner(
                              key: ValueKey('online'),
                              tone: _BannerTone.success,
                              icon: Icons.wifi_rounded,
                              text: AppCopy.backOnline,
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _BannerTone { warning, success }

class _Banner extends StatelessWidget {
  const _Banner(
      {super.key, required this.tone, required this.icon, required this.text});
  final _BannerTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool warn = tone == _BannerTone.warning;
    final Color bg = warn ? AppColor.warning : AppColor.success;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: EdgeInsets.all(AppSpacing.md.w),
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadii.rMd,
          boxShadow: AppShadows.level2,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            gapH(AppSpacing.md),
            Expanded(
              child: Text(text,
                  style: AppText.labelMd.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
