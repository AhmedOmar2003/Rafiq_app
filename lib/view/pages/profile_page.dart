import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/login/login_screen.dart';
import '../../service/auth_service.dart';
import '../../core/design/components/components.dart';
import '../../core/design/custom_app_bar.dart';
import '../../core/utils/app_microcopy.dart';
import '../../core/utils/spacing.dart';
import '../../core/config/api_config.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _profileImageKey = 'profile_image';
  static const String _profileImageWebKey = 'profile_image_base64';
  File? _image;
  Uint8List? _webImageBytes;
  String? userName;
  String? userEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadImage();
  }

  Future<void> _saveImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey, path);
    await prefs.remove(_profileImageWebKey);
  }

  Future<void> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      final base64Image = prefs.getString(_profileImageWebKey);
      if (base64Image == null || base64Image.isEmpty) {
        if (!mounted) return;
        setState(() {
          _webImageBytes = null;
          _image = null;
        });
        return;
      }

      try {
        final bytes = base64Decode(base64Image);
        if (!mounted) return;
        setState(() {
          _webImageBytes = bytes;
          _image = null;
        });
      } catch (_) {
        await prefs.remove(_profileImageWebKey);
      }
      return;
    }

    final savedPath = prefs.getString(_profileImageKey);
    if (savedPath == null || savedPath.isEmpty) return;

    final file = File(savedPath);
    if (await file.exists()) {
      if (!mounted) return;
      setState(() {
        _image = file;
      });
    } else {
      await prefs.remove(_profileImageKey);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "اسم غير متوفر";
      userEmail = prefs.getString('userEmail') ?? "بريد إلكتروني غير متوفر";
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.isEmpty) return;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_profileImageWebKey, base64Encode(bytes));
        await prefs.remove(_profileImageKey);

        if (!mounted) return;
        setState(() {
          _webImageBytes = bytes;
          _image = null;
        });
        return;
      }

      final persistedPath = await _persistProfileImage(File(pickedFile.path));
      if (persistedPath == null) return;

      setState(() {
        _image = File(persistedPath);
      });
      await _saveImage(persistedPath);
    }
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
      AppFeedback.error('معرفناش نحفظ الصورة دلوقتي، جرّب تاني');
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

  Future<void> _handleLogoutConfirmed(BuildContext dialogContext) async {
    if (_isLoading) return;
    Navigator.of(dialogContext).pop();

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
      AppFeedback.error('معرفناش نسجّل خروجك دلوقتي، جرّب تاني');
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
    ValueNotifier<bool> isLoading = ValueNotifier(false);
    ValueNotifier<String?> errorMessage = ValueNotifier(null);

    Future<void> changePassword() async {
      if (!_formKey.currentState!.validate()) return;
      isLoading.value = true;
      errorMessage.value = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('userEmail');
        if (email == null) {
          errorMessage.value = "تعذر العثور على البريد الإلكتروني للمستخدم.";
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
          AppFeedback.success(result['message'] ?? 'اتغيّرت كلمة السر بنجاح');
        } else {
          errorMessage.value = result['message'] ?? 'معرفناش نغيّر كلمة السر، راجع بياناتك';
        }
      } catch (e) {
        errorMessage.value = AppCopy.offlineBody;
      } finally {
        isLoading.value = false;
      }
    }

    showDialog(
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
                                "تغيير كلمة المرور",
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
                          labelText: "كلمة المرور الحالية",
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
                          labelText: "كلمة المرور الجديدة",
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
                          labelText: "تأكيد كلمة المرور الجديدة",
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
                          "إلغاء",
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface, // Better separation for bottom list
      appBar: CustomAppBar(
        backgroundColor: AppColor.primary,
        backIconColor: AppColor.white,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            "الملف الشخصي",
            style: AppText.headingLg.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 32.h, bottom: 32.h),
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36.r),
                    bottomRight: Radius.circular(36.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColor.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildProfileImage(),
                    verticalSpace(16),
                    Text(
                      userName ?? "اسم المستخدم",
                      textAlign: TextAlign.center,
                      style: AppText.headingSm.copyWith(
                        color: AppColor.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    verticalSpace(8),
                    Text(
                      userEmail ?? "البريد الإلكتروني",
                      textAlign: TextAlign.center,
                      style: AppText.bodyLg.copyWith(
                        color: AppColor.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpace(24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    _buildInfoSection(),
                    verticalSpace(32),
                    _buildLogoutButton(),
                    verticalSpace(40),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
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
            child: CircleAvatar(
              radius: 70.w,
              backgroundColor: AppColor.surfaceCard,
              child: CircleAvatar(
                radius: 67.w,
                backgroundImage: _webImageBytes != null
                    ? MemoryImage(_webImageBytes!)
                    : _image != null
                        ? FileImage(_image!)
                        : const AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                child: (_image == null && _webImageBytes == null)
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.black.withOpacity(0.4),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: AppColor.white,
                          size: 35.w,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoField(
            icon: Icons.person_2_outlined,
            value: userName ?? "اسم المستخدم",
            isFirst: true,
          ),
          Divider(height: 1, color: AppColor.border),
          _buildInfoField(
            icon: Icons.email_outlined,
            value: userEmail ?? "البريد الإلكتروني",
          ),
          Divider(height: 1, color: AppColor.border),
          _buildPasswordField(),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required IconData icon,
    required String value,
    bool isFirst = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        borderRadius:
            isFirst ? BorderRadius.vertical(top: Radius.circular(16.r)) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColor.primary,
            size: 24.sp,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              value,
              style: AppText.bodyLg.copyWith(
                color: AppColor.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: AppColor.primary,
            size: 24.sp,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              "••••••••",
              style: AppText.bodyLg.copyWith(
                color: AppColor.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30.r),
              onTap: () {
                showChangePasswordDialog(context);
              },
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColor.primary,
                  size: 24.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 52.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (_isLoading) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColor.white,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.textTertiary,
                        blurRadius: 10.0,
                        offset: const Offset(0.0, 10.0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(15.w),
                        decoration: BoxDecoration(
                          color: AppColor.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          size: 40.sp,
                          color: AppColor.error,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        "تأكيد تسجيل الخروج",
                        style: AppText.headingSm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColor.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        "هل أنت متأكد أنك تريد تسجيل الخروج من التطبيق؟",
                        textAlign: TextAlign.center,
                        style: AppText.bodyLg.copyWith(
                          color: AppColor.textSecondary,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                side: BorderSide(color: AppColor.primary),
                              ),
                              child: Text(
                                "إلغاء",
                                style:
                                    AppText.titleMd.copyWith(
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 15.w),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleLogoutConfirmed(dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColor.error,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "تأكيد",
                                style:
                                    AppText.titleMd.copyWith(
                                  color: AppColor.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.surfaceCard,
          foregroundColor: AppColor.error,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          side: const BorderSide(color: AppColor.error, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppColor.error, size: 24.sp),
            SizedBox(width: 12.w),
            Text(
              "تسجيل الخروج",
              style: AppText.titleLg.copyWith(
                color: AppColor.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
