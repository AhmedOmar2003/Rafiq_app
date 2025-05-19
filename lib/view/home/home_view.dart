import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/home/chat.dart';
import 'package:rafiq_app/view/home/widget/stepper_component.dart';
import 'package:rafiq_app/view/pages/step_one_screen/step_one_screen.dart';
import 'package:rafiq_app/view/pages/step_two_screen/step_two_screen.dart';
import 'package:rafiq_app/view/pages/step_three_screen/step_three_screen.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/view/pages/suggestions/suggestions_screen.dart';
import '../pages/choice/choice_screen.dart';

/// A widget that displays a multi-step form for selecting travel preferences.
/// Users can select their city, budget, and activity preferences through a
/// step-by-step process.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Constants
  static const int _totalSteps = 3;
  static const double _buttonHeight = 55.0;
  static const double _buttonWidth = 342.0;
  static const double _horizontalPadding = 24.0;
  static const double _verticalPadding = 47.0;
  static const double _bottomMargin = 25.0;

  // Controllers and state variables
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isLoading = false;

  // Form data
  String _cityName = "";
  String _budget = "";
  String _activity = "";

  // Step icons
  final List<String> _stepIcons = [
    AppImages.location,
    AppImages.dollar,
    AppImages.entertainment,
  ];

  // Step pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      StepOne(
        onCitySelected: (value) => _updateFormData('city', value),
      ),
      StepTwo(
        onBudgetSelected: (value) => _updateFormData('budget', value),
      ),
      StepThree(
        onActivitySelected: (value) => _updateFormData('activity', value),
      ),
    ];
  }

  void _updateFormData(String field, String value) {
    setState(() {
      switch (field) {
        case 'city':
          _cityName = value.trim();
          break;
        case 'budget':
          _budget = value.trim();
          break;
        case 'activity':
          _activity = value.trim();
          break;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Validates if all required form fields are filled
  bool _isFormValid() {
    return _cityName.isNotEmpty && _budget.isNotEmpty && _activity.isNotEmpty;
  }

  /// Shows an error message using SnackBar
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Navigates to the suggestions screen with the selected preferences
  Future<void> _navigateToSuggestions() async {
    if (!_isFormValid()) {
      _showErrorMessage("تأكد من إدخال جميع البيانات!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<Place> places = await ApiService().fetchPlaces(
        cityName: _cityName,
        budget: _budget,
        activity: _activity,
      );

      if (places.isEmpty) {
        _showErrorMessage("لا توجد أماكن متاحة تتطابق مع معايير البحث.");
        return;
      }

      final suggestionItems =
          places.map((place) => SuggestionItemModel.fromPlace(place)).toList();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuggestionsScreen(
            suggestionItemList: suggestionItems,
          ),
        ),
      );
    } catch (e) {
      _showErrorMessage("حدث خطأ أثناء تحميل الأماكن: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handles the next button press
  void _handleNextButtonPress() {
    if (_currentIndex < _totalSteps - 1) {
      setState(() => _currentIndex++);
      _pageController.jumpToPage(_currentIndex);
    } else {
      _navigateToSuggestions();
    }
  }

  /// Handles the back button press to navigate to ChoiceScreen
  Future<bool> _onWillPop() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChoiceScreen(
          onPlanSelected: () {},
          onNoPlanSelected: () {},
          onNext: () {},
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            bottomNavigationBar: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _horizontalPadding.w,
                vertical: _verticalPadding.h,
              ),
              child: AppButton(
                text: _currentIndex == _totalSteps - 1 ? "فسحني!" : "اللي بعده",
                textStyle: TextStyleTheme.textStyle24Medium,
                buttonStyle: ElevatedButton.styleFrom(
                  fixedSize: Size(_buttonWidth.w, _buttonHeight.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPress: _handleNextButtonPress,
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  verticalSpace(15),
                  _buildStepper(),
                  Expanded(
                    child: _buildPageView(),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BotScreen()),
              ),
              child: const Icon(Icons.chat),
              backgroundColor: Colors.blueAccent,
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w),
      margin: EdgeInsets.only(bottom: _bottomMargin.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          _totalSteps,
          (index) => StepperComponent(
            currentIndex: _currentIndex,
            index: index,
            icon: _stepIcons[index],
            isLast: index == _totalSteps - 1,
            onTap: () {
              setState(() => _currentIndex = index);
              _pageController.jumpToPage(index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      itemCount: _pages.length,
      itemBuilder: (context, index) => _pages[index],
    );
  }
}
