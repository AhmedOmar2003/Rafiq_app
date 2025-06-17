import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/models/Api_model/api_model.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:rafiq_app/view/pages/choice/save_data_screen.dart';

import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
import '../../../core/design/app_button.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  // Controllers
  final _placeNameController = TextEditingController();
  final _priceController = TextEditingController(text: "100");
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  // Form state
  final _formKey = GlobalKey<FormState>();

  // Selected values
  String? _selectedPlaceType;
  String? _selectedCity;
  String? _selectedPriceRange;

  // Loading state
  bool _isLoading = false;
  bool _isMounted = true;

  // Constants
  static const List<String> _placeTypes = [
    "طعام",
    "ترفيه",
    "فعاليات ثقافية",
    "سياحي"
  ];

  static const List<String> _cities = [
    "القاهرة",
    "المنصورة",
    "الإسكندرية",
    "طنطا"
  ];

  static const List<String> _priceRange = [
    "أقل من 100 جنيه",
    "100 إلى 500 جنيه",
    "500 إلى 1000 جنيه",
    "1000 إلى 1500 جنيه",
    "لسه محددتش"
  ];

  static const Map<String, int> _activityMap = {
    "طعام": 1,
    "ترفيه": 2,
    "فعاليات ثقافية": 3,
    "سياحي": 4,
  };

  @override
  void dispose() {
    _isMounted = false;
    _placeNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!_isMounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _addPlace() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final url =
          Uri.parse('http://${GlopalVariable.ipConfig}/Api/add_place.php');
      final body = {
        'placeName': _placeNameController.text.trim(),
        'activityId': _activityMap[_selectedPlaceType].toString(),
        'budget': _selectedPriceRange,
        'priceRange': _priceController.text.trim(),
        'address': _addressController.text.trim(),
        'cityName': _selectedCity,
        'description': _descriptionController.text.trim(),
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (!_isMounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] != null) {
        _showSnackBar(result['success']);
        _navigateToSplashScreen();
      } else {
        _showSnackBar(
          result['error'] ?? 'حدث خطأ أثناء إضافة المكان',
          isError: true,
        );
      }
    } on http.ClientException {
      _showSnackBar('تعذر الاتصال بالخادم', isError: true);
    } catch (e) {
      _showSnackBar('حدث خطأ غير متوقع', isError: true);
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      }
    }
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
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAppBar(),
                  _buildBackgroundImage(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          children: [
                            verticalSpace(16),
                            _buildImageUploadButton(),
                            verticalSpace(28),
                            _buildFormFields(),
                            verticalSpace(28),
                            _buildSubmitButton(),
                            verticalSpace(20),
                          ],
                        ),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _navigateToChoiceScreen,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Text(
                "أضف بيانات مكانك",
                style: TextStyleTheme.textStyle22Medium,
              ),
            ),
          ),
          SizedBox(width: 24.w),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return Container(
      height: 200.h,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/padel.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildImageUploadButton() {
    return ElevatedButton(
      onPressed: () {
        _showSnackBar("تم اختيار صورة (محاكاة)");
      },
      style: ElevatedButton.styleFrom(
        minimumSize: Size(132, 75),
        backgroundColor: AppColor.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt,
            color: Color.fromARGB(255, 252, 252, 195),
            size: 28,
          ),
          verticalSpace(5),
          Text(
            "أضف صورة",
            style: TextStyleTheme.textStyle18Medium.copyWith(
              color: AppColor.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _placeNameController,
          label: "اسم المكان",
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال اسم المكان';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "نوع المكان",
          value: _selectedPlaceType,
          items: _placeTypes,
          onChanged: (value) {
            setState(() => _selectedPlaceType = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار نوع المكان';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "نطاق الأسعار",
          value: _selectedPriceRange,
          items: _priceRange,
          onChanged: (value) {
            setState(() => _selectedPriceRange = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء اختيار نطاق الأسعار';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildTextField(
          controller: _priceController,
          label: "بداية الأسعار",
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال بداية الأسعار';
            }
            if (int.tryParse(value) == null) {
              return 'الرجاء إدخال رقم صحيح';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildTextField(
          controller: _addressController,
          label: "العنوان",
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال العنوان';
            }
            return null;
          },
        ),
        verticalSpace(16),
        _buildDropdown(
          label: "المدينة التي يوجد بها المكان",
          value: _selectedCity,
          items: _cities,
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
        _buildTextField(
          controller: _descriptionController,
          label: "وصف عن المكان",
          maxLines: 3,
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

  Widget _buildSubmitButton() {
    return _isLoading
        ? const CircularProgressIndicator()
        : AppButton(
            text: "حفظ",
            onPress: _addPlace,
            buttonStyle: ElevatedButton.styleFrom(
              fixedSize: Size(342.w, 55.h),
              backgroundColor: AppColor.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            textStyle: TextStyleTheme.textStyle20Medium.copyWith(
              color: AppColor.white,
            ),
          );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyleTheme.textStyle20Medium.copyWith(
          fontSize: 18.sp,
          color: Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColor.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      style: TextStyleTheme.textStyle20Medium,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyleTheme.textStyle20Medium),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyleTheme.textStyle20Medium.copyWith(
          fontSize: 18.sp,
          color: Colors.grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColor.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      style: TextStyleTheme.textStyle20Medium,
      icon: const Icon(Icons.arrow_drop_down),
      isExpanded: true,
      alignment: Alignment.centerRight,
    );
  }
}
