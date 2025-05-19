import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/forget%20password/forget_password.dart';
import '../../auth/login/login_screen.dart';
import '../../core/design/app_button.dart';
import '../../core/design/app_input.dart';
import '../../core/design/custom_app_bar.dart';
import '../../core/design/title_text.dart';
import '../../core/logic/my_app_methods.dart';
import '../../core/utils/app_color.dart';
import '../../core/utils/text_style_theme.dart';
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
  File? _image;
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
    await prefs.setString('profile_image', path);
  }

  Future<void> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profile_image');
    if (savedPath != null) {
      setState(() {
        _image = File(savedPath);
      });
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _saveImage(pickedFile.path);
    }
  }

  Future<void> deleteUser(String? email) async {
    if (email == null) return;

    String deleteUrl = "${ApiConfig.baseUrl}/logout_user.php";

    try {
      final response = await http.post(
        Uri.parse(deleteUrl),
        body: {"email": email},
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Failed to log out")),
        );
      }
    } catch (e) {
      print("Error: $e"); // يعرض الخطأ في الـ Debug Console
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر الاتصال بالخادم: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        backgroundColor: AppColor.primary,
        backIconColor: Colors.white,
        title: Align(
          alignment: AlignmentDirectional.centerStart,
          child: CustomTextWidget(
            label: "الملف الشخصي",
            style: TextStyleTheme.textStyle24Medium.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                verticalSpace(32),
                _buildProfileImage(),
                verticalSpace(16),
                CustomTextWidget(
                  textAlign: TextAlign.center,
                  label: userName ?? "اسم المستخدم",
                  style: TextStyleTheme.textStyle20Medium.copyWith(
                    color: AppColor.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                verticalSpace(8),
                CustomTextWidget(
                  textAlign: TextAlign.center,
                  label: userEmail ?? "البريد الإلكتروني",
                  style: TextStyleTheme.textStyle14Regular.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                verticalSpace(40),
                _buildInfoSection(),
                verticalSpace(40),
                _buildLogoutButton(),
                verticalSpace(32),
              ],
            ),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 70.w,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 67.w,
                backgroundImage: _image != null
                    ? FileImage(_image!)
                    : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
                child: _image == null
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
          Divider(height: 1, color: Colors.grey[200]),
          _buildInfoField(
            icon: Icons.email_outlined,
            value: userEmail ?? "البريد الإلكتروني",
          ),
          Divider(height: 1, color: Colors.grey[200]),
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
        borderRadius: isFirst
            ? BorderRadius.vertical(top: Radius.circular(20.r))
            : null,
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
            child: CustomTextWidget(
              label: value,
              style: TextStyleTheme.textStyle16Regular.copyWith(
                color: Colors.black87,
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
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
            child: CustomTextWidget(
              label: "••••••••",
              style: TextStyleTheme.textStyle16Regular.copyWith(
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30.r),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );
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
      height: 55.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          if (_isLoading) return;
          setState(() => _isLoading = true);
          
          MyAppMethods.showErrorORWarningDialog(
            context: context,
            subtitle: "هل تريد تسجيل الخروج بالفعل؟",
            onPress: () async {
              final prefs = await SharedPreferences.getInstance();
              String? userEmail = prefs.getString('userEmail');
              await deleteUser(userEmail);
              await prefs.clear();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
          );
          
          setState(() => _isLoading = false);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: Colors.white,
              size: 24.sp,
            ),
            SizedBox(width: 12.w),
            CustomTextWidget(
              label: "تسجيل الخروج",
              style: TextStyleTheme.textStyle18Medium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
