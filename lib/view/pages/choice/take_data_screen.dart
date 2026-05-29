import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/feature_gate.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:rafiq_app/view/pages/choice/save_data_screen.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

import '../../../core/design/app_button.dart';
import '../../../core/utils/app_microcopy.dart';
import '../../../core/utils/spacing.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  // Controllers
  final _placeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  // Form state
  final _formKey = GlobalKey<FormState>();

  // Selected values
  String? _selectedPlaceType;
  String? _selectedCity;
  String? _selectedBudget;

  // Loading state
  bool _isLoading = false;
  bool _isMounted = true;

  // Image picker state — currently single image; the gate is sized in
  // attached images so multi-image becomes a one-line extension.
  File? _image;
  final ImagePicker _picker = ImagePicker();

  // Provider entitlement — read once on mount, refreshed after a successful
  // upgrade so the form respects new caps immediately.
  ProviderEntitlement? _entitlement;
  String? _providerId;

  // Constants
  static const List<String> _placeTypes = [
    "طعام",
    "ترفيه",
    "سياحي",
    "رياضة",
    "فاجئني",
  ];

  static const List<String> _cities = [
    "القاهرة",
    "المنصورة",
    "الإسكندرية",
    "طنطا",
    "أي حتة",
  ];

  static const List<String> _budgets = [
    "أقل من 100 جنيه",
    "100 إلى 500 جنيه",
    "500 إلى 1000 جنيه",
    "1000 إلى 1500 جنيه",
    "لسه محددتش",
  ];

  static const Map<String, int> _activityMap = {
    "طعام": 1,
    "ترفيه": 2,
    "سياحي": 3,
    "رياضة": 4,
    "فاجئني": 5,
  };

  @override
  void initState() {
    super.initState();
    _preloadEntitlement();
  }

  @override
  void dispose() {
    _isMounted = false;
    _placeNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Looks up the current provider id from cached prefs, then fetches the
  /// resolved entitlement. The form gracefully degrades to the Free-tier
  /// fallback if anything fails — we never block the form on billing.
  Future<void> _preloadEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('authUserId');
      if (userId == null) return;

      // Resolve the provider row for this user.
      final providerRow = await Supabase.instance.client
          .from('providers')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();
      if (providerRow == null) return;
      _providerId = providerRow['id'] as String?;
      if (_providerId == null) return;

      final ent = await SubscriptionService.instance
          .loadEntitlement(_providerId!);
      if (!_isMounted) return;
      setState(() => _entitlement = ent);
    } catch (_) {
      // Silent — keep the Free fallback.
    }
  }

  void _openUpgrade() {
    if (_providerId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(providerId: _providerId!),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!_isMounted) return;
    isError ? AppFeedback.error(message) : AppFeedback.success(message);
  }

  Future<void> _addPlace() async {
    if (!_formKey.currentState!.validate()) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _showSnackBar(AppCopy.providerSessionExpired, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().addPlace(
        placeName: _placeNameController.text.trim(),
        activityName: _selectedPlaceType ?? '',
        budget: _selectedBudget ?? '',
        address: _addressController.text.trim(),
        cityName: _selectedCity ?? '',
        description: _descriptionController.text.trim(),
        imagePath: _image?.path,
      );

      if (!_isMounted) return;

      await _saveUserPlaceLocally();
      _showSnackBar(AppCopy.providerAddedSuccess);
      _navigateToSplashScreen();
    } catch (e) {
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserPlaceLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final userPlacesJson = prefs.getStringList('user_places') ?? [];
      final newPlace = {
        'name': _placeNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priceRange': _selectedBudget ?? '',
        'budget': _selectedBudget ?? '',
        'rating': 5.0,
        'placeAddress': _addressController.text.trim(),
        'imageUrl': _image?.path ?? '',
      'activityName': _selectedPlaceType ?? '',
      'cityName': _selectedCity ?? '',
      'placeId': DateTime.now().millisecondsSinceEpoch, // unique id
    };
    userPlacesJson.add(jsonEncode(newPlace));
    await prefs.setStringList('user_places', userPlacesJson);
  }

  void _navigateToSplashScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToChoiceScreen() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ChoiceScreen(
          onPlanSelected: () {},
          onNoPlanSelected: () {},
          onNext: () {},
        ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _pickImage() async {
    // Entitlement preflight — Free fallback is used while billing loads,
    // which always allows ≥1 image, so the form never freezes here.
    final ent = _entitlement ?? ProviderEntitlement.freeFallback;
    final currentImages = _image == null ? 0 : 1;

    final allowed = await FeatureGate.requireImageSlot(
      context,
      ent,
      currentImages,
    );
    if (!allowed) {
      // Sheet handles the upgrade path; nothing else to do here.
      _openUpgrade();
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (pickedFile != null && _isMounted) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (_) {
      _showSnackBar(AppCopy.providerImagePickError, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToChoiceScreen();
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColor.ofWhite,
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          verticalSpace(16),
                          _buildTopImage(),
                          verticalSpace(24),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: _buildFormFields(),
                          ),
                          verticalSpace(36),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: _buildSubmitButton(),
                          ),
                          verticalSpace(40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      color: AppColor.ofWhite,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColor.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppColor.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.only(right: 6.w),
              icon: Icon(Icons.arrow_back_ios, color: AppColor.black, size: 20.sp),
              onPressed: _navigateToChoiceScreen,
            ),
          ),
          Text(
            AppCopy.providerFormTitle,
            style: AppText.headingSm.copyWith(
               fontWeight: FontWeight.w700,
               color: AppColor.black,
            ),
          ),
          SizedBox(width: 48.w), // Spacer to balance the row
        ],
      ),
    );
  }

  Widget _buildTopImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        height: 200.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColor.white,
          borderRadius: BorderRadius.circular(20.r),
          border: _image == null 
              ? Border.all(color: AppColor.primary.withOpacity(0.3), width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: AppColor.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          image: _image != null
              ? DecorationImage(
                  image: FileImage(_image!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: AppColor.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, color: AppColor.primary, size: 40.w),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "إضافة صورة الغلاف للمكان",
                    style: AppText.titleMd.copyWith(
                      color: AppColor.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "يفضل أن تكون صورة عرضية بجودة عالية",
                    style: AppText.bodySm.copyWith(
                      color: AppColor.textTertiary,
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned(
                    bottom: 12.h,
                    right: 12.w,
                    child: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColor.black.withOpacity(0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColor.white.withOpacity(0.5), width: 1),
                      ),
                      child: Icon(Icons.edit_rounded, color: AppColor.white, size: 20.w),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _placeNameController,
          label: "اسم المكان",
          icon: Icons.storefront_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال اسم المكان';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "المدينة",
          value: _selectedCity,
          items: _cities,
          icon: Icons.location_city_outlined,
          onChanged: (value) {
            setState(() => _selectedCity = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار المدينة';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "نوع النشاط",
          value: _selectedPlaceType,
          items: _placeTypes,
          icon: Icons.category_outlined,
          onChanged: (value) {
            setState(() => _selectedPlaceType = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار نوع النشاط';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "الميزانية",
          value: _selectedBudget,
          items: _budgets,
          icon: Icons.account_balance_wallet_outlined,
          onChanged: (value) {
            setState(() => _selectedBudget = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار الميزانية';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildTextField(
          controller: _addressController,
          label: "العنوان التفصيلي",
          icon: Icons.map_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال العنوان';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildTextField(
          controller: _descriptionController,
          label: "وصف عن المكان ومميزاته",
          icon: Icons.description_outlined,
          maxLines: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال وصف عن المكان';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textAlign: TextAlign.right,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppText.bodyLg.copyWith(
            color: AppColor.textTertiary,
            fontSize: 16.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Icon(icon, color: AppColor.primary, size: 24.sp),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: maxLines > 1 ? 20.h : 18.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.error, width: 1),
          ),
          filled: true,
          fillColor: AppColor.white,
        ),
        style: AppText.titleMd.copyWith(color: AppColor.black),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColor.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        validator: validator,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColor.textSecondary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppText.bodyLg.copyWith(
            color: AppColor.textTertiary,
            fontSize: 16.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Icon(icon, color: AppColor.primary, size: 24.sp),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: AppColor.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.error, width: 1),
          ),
          filled: true,
          fillColor: AppColor.white,
        ),
        dropdownColor: AppColor.white,
        style: AppText.titleMd.copyWith(color: AppColor.black),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return _isLoading
        ? Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
            ),
          )
        : AppButton(
            text: "حفظ البيانات",
            onPress: _addPlace,
            buttonStyle: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 56.h),
              backgroundColor: AppColor.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 4,
              shadowColor: AppColor.primary.withOpacity(0.4),
            ),
            textStyle: AppText.titleLg.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.w700,
            ),
          );
  }
}
