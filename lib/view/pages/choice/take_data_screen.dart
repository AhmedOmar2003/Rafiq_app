import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/feature_gate.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/view/provider/hub/provider_hub_screen.dart';
import 'package:rafiq_app/view/provider/subscription/subscription_screen.dart';

import '../../../core/utils/app_microcopy.dart';
import '../../../core/utils/spacing.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key, this.editingPlace, this.providerId});

  final Place? editingPlace;
  final String? providerId;

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

  // Image picker state — provider can attach up to [entitlement.maxGalleryImages]
  // pictures. The first one in the list is treated as the cover.
  final List<File> _images = <File>[];
  final ImagePicker _picker = ImagePicker();

  // Provider entitlement — read once on mount, refreshed after a successful
  // upgrade so the form respects new caps immediately.
  ProviderEntitlement? _entitlement;
  String? _providerId;
  bool get _isEditing => widget.editingPlace != null;

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

  @override
  void initState() {
    super.initState();
    _prefillIfNeeded();
    _preloadEntitlement();
  }

  void _prefillIfNeeded() {
    final place = widget.editingPlace;
    if (place == null) return;
    _placeNameController.text = place.name;
    _descriptionController.text = place.description;
    _addressController.text = place.placeAddress;
    _selectedPlaceType = place.activityName;
    _selectedCity = place.cityName;
    _selectedBudget = place.budget.isNotEmpty ? place.budget : place.priceRange;
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
      _providerId = widget.providerId ?? prefs.getString('providerId');
      _providerId ??= await ApiService().ensureCurrentProviderId();
      if (_providerId == null) {
        await Future.delayed(const Duration(milliseconds: 250));
        _providerId ??= await ApiService().ensureCurrentProviderId();
      }
      if (_providerId == null) return;

      final ent =
          await SubscriptionService.instance.loadEntitlement(_providerId!);
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

  Future<void> _submitPlace() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Resolve a provider id JIT — if the user just signed up they may not
    // have a row yet, and the cached `_providerId` is null. The helper
    // creates a default row on the fly when there's a live auth session.
    final prefs = await SharedPreferences.getInstance();
    String? providerId = _providerId;
    providerId ??= prefs.getString('providerId');
    providerId ??= await ApiService().ensureCurrentProviderId();
    if (providerId == null) {
      await Future.delayed(const Duration(milliseconds: 250));
      providerId = await ApiService().ensureCurrentProviderId();
    }
    if (providerId == null) {
      if (_isMounted) setState(() => _isLoading = false);
      _showSnackBar(AppCopy.providerSessionExpired, isError: true);
      return;
    }
    _providerId = providerId; // cache for future submits

    try {
      final existingPlaces =
          await ApiService().fetchProviderPlaces(providerId: providerId);
      if (!_isEditing) {
        if (!mounted) return;
        final allowed = await FeatureGate.requirePlaceSlot(
          context,
          _entitlement ?? ProviderEntitlement.freeFallback,
          existingPlaces.length,
        );
        if (!allowed) {
          return;
        }
      }

      final coverPath = _images.isEmpty ? null : _images.first.path;
      if (_isEditing) {
        await ApiService().updatePlace(
          placeUuid: widget.editingPlace!.placeUuid,
          legacyPlaceId: widget.editingPlace!.placeId,
          placeName: _placeNameController.text.trim(),
          activityName: _selectedPlaceType ?? '',
          budget: _selectedBudget ?? '',
          address: _addressController.text.trim(),
          cityName: _selectedCity ?? '',
          description: _descriptionController.text.trim(),
          imagePath: coverPath,
        );
      } else {
        await ApiService().addPlace(
          providerId: providerId,
          placeName: _placeNameController.text.trim(),
          activityName: _selectedPlaceType ?? '',
          budget: _selectedBudget ?? '',
          address: _addressController.text.trim(),
          cityName: _selectedCity ?? '',
          description: _descriptionController.text.trim(),
          imagePath: coverPath,
          galleryImages: _images,
        );
      }

      if (!_isMounted) return;

      await _saveUserPlaceLocally();
      _showSnackBar(
        _isEditing ? 'تم تعديل المكان بنجاح' : AppCopy.providerAddedSuccess,
      );
      _returnToHub();
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
      'imageUrl': _images.isEmpty ? '' : _images.first.path,
      'galleryImageUrls': _images.map((f) => f.path).toList(),
      'activityName': _selectedPlaceType ?? '',
      'cityName': _selectedCity ?? '',
      'placeId': DateTime.now().millisecondsSinceEpoch,
    };
    userPlacesJson.add(jsonEncode(newPlace));
    await prefs.setStringList('user_places', userPlacesJson);
  }

  void _returnToHub() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ProviderHubScreen()),
      (route) => false,
    );
  }

  void _handleBack() {
    _returnToHub();
  }

  /// Inline reminder of the active plan + current gallery usage. Reacts to
  /// demo upgrades through [SubscriptionService.entitlement] so the cap
  /// changes the moment a user "subscribes" on the pricing page.
  Widget _buildEntitlementBanner() {
    return ValueListenableBuilder<ProviderEntitlement>(
      valueListenable: SubscriptionService.instance.entitlement,
      builder: (_, ent, __) {
        return Container(
          margin: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          decoration: BoxDecoration(
            color: AppColor.surfaceCard,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: AppColor.border),
          ),
          child: Row(
            children: [
              PlanBadge(tier: ent.tier),
              const Spacer(),
              EntitlementChip(
                label: AppCopy.subFeatGallery,
                used: _images.length,
                limit: ent.maxGalleryImages,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    // Entitlement preflight — Free fallback is used while billing loads,
    // which always allows ≥1 image, so the form never freezes here.
    final ent = _entitlement ?? ProviderEntitlement.freeFallback;

    final allowed = await FeatureGate.requireImageSlot(
      context,
      ent,
      _images.length,
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
        setState(() => _images.add(File(pickedFile.path)));
      }
    } catch (_) {
      _showSnackBar(AppCopy.providerImagePickError, isError: true);
    }
  }

  void _removeImage(int index) {
    if (!_isMounted) return;
    setState(() => _images.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
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
                  _buildEntitlementBanner(),
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
                  color: AppColor.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.only(right: 6.w),
              icon: Icon(Icons.arrow_back_ios,
                  color: AppColor.black, size: 20.sp),
              onPressed: _handleBack,
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

  /// Plan-aware gallery picker.
  ///
  /// Visual:
  ///   • Section header with title + subtitle ("الصورة الأولى هتبقى الكوفر").
  ///   • Horizontally scrollable tiles, one per image, plus an "add" tile
  ///     at the end while the user is below their plan cap.
  ///   • First tile carries a small "COVER" chip so the user understands
  ///     reordering matters.
  ///   • If the cap is reached, the add tile disappears and the entitlement
  ///     chip above turns red (handled by [EntitlementChip]).
  Widget _buildTopImage() {
    return ValueListenableBuilder<ProviderEntitlement>(
      valueListenable: SubscriptionService.instance.entitlement,
      builder: (_, ent, __) {
        final canAdd = _images.length < ent.maxGalleryImages;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    AppCopy.providerGalleryTitle,
                    style: AppText.titleLg.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _galleryCountLabel(ent),
                    style: AppText.labelSm.copyWith(
                      color: AppColor.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                AppCopy.providerCoverHint,
                style: AppText.bodySm.copyWith(color: AppColor.textTertiary),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                height: 130.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + (canAdd ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(width: 10.w),
                  itemBuilder: (_, i) {
                    if (i == _images.length) return _AddTile(onTap: _pickImage);
                    return _GalleryTile(
                      file: _images[i],
                      isCover: i == 0,
                      onRemove: () => _removeImage(i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _galleryCountLabel(ProviderEntitlement ent) {
    if (ent.maxGalleryImages >= 999) {
      return AppCopy.providerImagesUnlimited
          .replaceFirst('%u', _images.length.toString());
    }
    return AppCopy.providerImagesUsed
        .replaceFirst('%u', _images.length.toString())
        .replaceFirst('%m', ent.maxGalleryImages.toString());
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
            color: AppColor.black.withValues(alpha: 0.02),
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
          contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w, vertical: maxLines > 1 ? 20.h : 18.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
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
            color: AppColor.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        validator: validator,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColor.textSecondary),
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
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
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
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
            ),
          )
        : AppButton(
            text: _isEditing ? 'حفظ التعديلات' : "حفظ البيانات",
            onPress: _submitPlace,
            buttonStyle: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 56.h),
              backgroundColor: AppColor.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 4,
              shadowColor: AppColor.primary.withValues(alpha: 0.4),
            ),
            textStyle: AppText.titleLg.copyWith(
              color: AppColor.white,
              fontWeight: FontWeight.w700,
            ),
          );
  }
}

// ===========================================================================
// Gallery widgets — kept private to this screen.
// ===========================================================================

/// One image tile in the horizontally-scrolling gallery.
///
/// Layout: 130×130 rounded square with the picture, a small "COVER" pill on
/// the first tile, and a delete button in the top-right corner. The delete
/// button stays a fixed hit-target size regardless of screen DPR.
class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.file,
    required this.isCover,
    required this.onRemove,
  });

  final File file;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130.w,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Image.file(
              file,
              width: 130.w,
              height: 130.h,
              fit: BoxFit.cover,
              // Cap decoded size to avoid 8MB+ pics sitting at full res in
              // RAM just to be displayed as a 130dp thumbnail.
              cacheWidth:
                  (130 * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
          ),
          if (isCover)
            Positioned(
              left: 6.w,
              bottom: 6.h,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: AppColor.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'COVER',
                  style: AppText.caption.copyWith(
                    color: AppColor.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4.h,
            right: 4.w,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkResponse(
                onTap: onRemove,
                radius: 18,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColor.white,
                    size: 16.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed-style "add image" tile that sits at the end of the gallery.
/// Only renders while the user is below their plan's gallery cap.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: 130.w,
        height: 130.h,
        decoration: BoxDecoration(
          color: AppColor.primary50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColor.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: AppColor.primary,
              size: 30.sp,
            ),
            SizedBox(height: 6.h),
            Text(
              AppCopy.providerAddImage,
              style: AppText.labelSm.copyWith(
                color: AppColor.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
