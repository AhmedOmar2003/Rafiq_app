import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';

import '../../auth/login/login_screen.dart';
import '../../core/config/api_config.dart';
import '../../core/design/components/app_page_header.dart';
import '../../core/design/components/components.dart';
import '../../core/utils/app_microcopy.dart';
import '../../core/utils/spacing.dart';
import '../../service/auth_service.dart';
import '../../service/profile_image_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // ProfileImageStore is the single source of truth — just make sure it's
    // loaded. The hero image listens to its ValueNotifier so we never need
    // local setState plumbing for the picture.
    ProfileImageStore.instance.ensureLoaded();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? AppCopy.profileNameFallback;
      userEmail = prefs.getString('userEmail') ?? AppCopy.profileEmailFallback;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) return;
      await ProfileImageStore.instance.setWebBytes(bytes);
      return;
    }

    final persistedPath = await _persistProfileImage(File(pickedFile.path));
    if (persistedPath == null) return;
    await ProfileImageStore.instance.setMobileImage(File(persistedPath));
  }

  Future<String?> _persistProfileImage(File sourceImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authUserId =
          prefs.getString('authUserId') ?? (userEmail ?? 'default_user');
      final safeId = authUserId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/profile_images');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final extension =
          sourceImage.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final targetPath = '${profileDir.path}/profile_$safeId.$extension';
      final persistedFile = await sourceImage.copy(targetPath);
      return persistedFile.path;
    } catch (e) {
      if (!mounted) return null;
      AppFeedback.error(AppCopy.profileImageSaveError);
      return null;
    }
  }

  Future<void> _sendLegacyLogoutSignal(String? email) async {
    if (email == null) return;

    final deleteUrl = "${ApiConfig.baseUrl}/logout_user.php";

    try {
      await http.post(
        Uri.parse(deleteUrl),
        body: {"email": email},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _handleLogoutConfirmedDirect() async {
    if (_isLoading) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final email = userEmail;
    try {
      // Log out locally + Supabase first for immediate UX.
      await AuthService().signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );

      // Legacy API signal in background (non-blocking).
      unawaited(_sendLegacyLogoutSignal(email));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(AppCopy.logoutError);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showChangePasswordDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final ValueNotifier<bool> isLoading = ValueNotifier(false);
    final ValueNotifier<String?> errorMessage = ValueNotifier(null);

    // PERFORMANCE / CORRECTNESS: dialog-scoped controllers must be disposed
    // when the dialog closes, otherwise they leak ChangeNotifier subscribers
    // for the lifetime of the app.
    void _disposeResources() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
      isLoading.dispose();
      errorMessage.dispose();
    }

    Future<void> changePassword() async {
      if (!_formKey.currentState!.validate()) return;
      isLoading.value = true;
      errorMessage.value = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('userEmail');
        if (email == null) {
          errorMessage.value = AppCopy.changePwMissingEmail;
          isLoading.value = false;
          return;
        }
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/update_password_account.php"),
          body: {
            'email': email,
            'old_password': currentPasswordController.text,
            'new_password': newPasswordController.text,
          },
        );
        final result = jsonDecode(response.body);
        if (response.statusCode == 200 && result['status'] == 'success') {
          Navigator.of(context).pop();
          AppFeedback.success(result['message'] ?? AppCopy.changePwSuccess);
        } else {
          errorMessage.value = result['message'] ?? AppCopy.changePwGenericFail;
        }
      } catch (e) {
        errorMessage.value = AppCopy.offlineBody;
      } finally {
        isLoading.value = false;
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: AppColor.surfaceCard,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title and close icon
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                AppCopy.changePwTitle,
                                style:
                                    AppText.titleLg.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.close,
                              color: AppColor.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      // Current password
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: AppCopy.changePwCurrent,
                          prefixIcon:
                              Icon(Icons.lock_outline, color: AppColor.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى إدخال كلمة المرور الحالية";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      // New password
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: AppCopy.changePwNew,
                          prefixIcon:
                              Icon(Icons.lock_outline, color: AppColor.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى إدخال كلمة المرور الجديدة";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      // Confirm new password
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: AppCopy.changePwConfirm,
                          prefixIcon:
                              Icon(Icons.lock_outline, color: AppColor.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "يرجى تأكيد كلمة المرور الجديدة";
                          }
                          if (value != newPasswordController.text) {
                            return "كلمتا المرور غير متطابقتين";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24.h),
                      // Update button
                      ValueListenableBuilder<bool>(
                        valueListenable: isLoading,
                        builder: (context, loading, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15.r),
                                ),
                                elevation: 2,
                              ),
                              onPressed: loading
                                  ? () {}
                                  : () {
                                      changePassword();
                                    },
                              child: loading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: AppColor.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      "تحديث كلمة المرور",
                                      style: AppText.titleMd
                                          .copyWith(
                                        color: AppColor.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12.h),
                      // Error message with fade animation
                      ValueListenableBuilder<String?>(
                        valueListenable: errorMessage,
                        builder: (context, error, _) {
                          return AnimatedOpacity(
                            opacity: error == null ? 0.0 : 1.0,
                            duration: Duration(milliseconds: 300),
                            child: error == null
                                ? SizedBox.shrink()
                                : Padding(
                                    padding: EdgeInsets.only(top: 4.h),
                                    child: Text(
                                      error,
                                      style: AppText.bodyMd
                                          .copyWith(color: AppColor.error),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          );
                        },
                      ),
                      SizedBox(height: 8.h),
                      // Cancel button
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          AppCopy.cancel,
                          style: AppText.bodyLg.copyWith(
                            color: AppColor.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(_disposeResources);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: const AppPageHeader(
        title: AppCopy.profileTitle,
        tone: AppHeaderTone.brand,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _ProfileHero(
                name: userName,
                email: userEmail,
                child: _buildProfileImage(),
              ),
              gapV(AppSpacing.xxl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                child: Column(
                  children: [
                    _buildInfoSection(),
                    gapV(AppSpacing.xxxl),
                    _buildLogoutButton(),
                    gapV(AppSpacing.huge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _pickImage,
        child: ValueListenableBuilder<ProfileImageState>(
          valueListenable: ProfileImageStore.instance,
          builder: (_, snap, __) {
            final ImageProvider provider = snap.bytes != null
                ? MemoryImage(snap.bytes!)
                : snap.file != null
                    ? FileImage(snap.file!)
                    : const AssetImage(
                            'assets/images/default_profile.png')
                        as ImageProvider;
            return CircleAvatar(
              radius: 70.w,
              backgroundColor: AppColor.surfaceCard,
              child: CircleAvatar(
                radius: 67.w,
                backgroundImage: provider,
                child: snap.hasImage
                    ? null
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.black.withOpacity(0.4),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: AppColor.white,
                          size: 35.w,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _ProfileInfoRow(
            icon: Icons.person_2_outlined,
            label: AppCopy.profileNameLabel,
            value: userName ?? AppCopy.profileNameFallback,
          ),
          Divider(height: 1, color: AppColor.border),
          _ProfileInfoRow(
            icon: Icons.email_outlined,
            label: AppCopy.profileEmailLabel,
            value: userEmail ?? AppCopy.profileEmailFallback,
          ),
          Divider(height: 1, color: AppColor.border),
          _ProfileInfoRow(
            icon: Icons.lock_outline,
            label: AppCopy.profilePasswordLabel,
            value: '••••••••',
            trailing: IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: AppColor.primary,
                size: 22.sp,
              ),
              onPressed: () => showChangePasswordDialog(context),
              tooltip: AppCopy.changePwTitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (_isLoading) return;
          final confirmed = await AppConfirmDialog.show(
            context,
            title: AppCopy.logoutTitle,
            message: AppCopy.logoutMessage,
            confirmLabel: AppCopy.logoutConfirm,
            cancelLabel: AppCopy.cancel,
            tone: AppConfirmTone.danger,
            icon: Icons.logout_rounded,
          );
          if (!mounted) return;
          if (confirmed) await _handleLogoutConfirmedDirect();
        },
        icon: Icon(Icons.logout_rounded, color: AppColor.error, size: 22.sp),
        label: Text(
          AppCopy.logoutCta,
          style: AppText.titleMd.copyWith(
            color: AppColor.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(52.h),
          backgroundColor: AppColor.surfaceCard,
          side: const BorderSide(color: AppColor.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        ),
      ),
    );
  }
}

// ===========================================================================
// Profile internals
// ===========================================================================

/// Brand hero block at the top of the profile screen.
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.child,
  });

  final String? name;
  final String? email;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl.w,
        vertical: AppSpacing.xxxl.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.xxl.r),
        ),
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Column(
        children: [
          child,
          gapV(AppSpacing.lg),
          Text(
            name ?? AppCopy.profileNameFallback,
            textAlign: TextAlign.center,
            style: AppText.headingSm.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          gapV(AppSpacing.xs),
          Text(
            email ?? AppCopy.profileEmailFallback,
            textAlign: TextAlign.center,
            style: AppText.bodyLg.copyWith(
              color: AppColor.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row inside the profile info card.
class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl.w,
        vertical: AppSpacing.lg.h,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm.w),
            decoration: BoxDecoration(
              color: AppColor.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColor.primary, size: 20.sp),
          ),
          gapH(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                gapV(AppSpacing.xs / 2),
                Text(
                  value,
                  style: AppText.bodyLg.copyWith(color: AppColor.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
