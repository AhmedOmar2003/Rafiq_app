import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/model/place.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/home/chat.dart';
import 'package:rafiq_app/view/home/widget/stepper_component.dart';
import 'package:rafiq_app/view/pages/step_one_screen/step_one_screen.dart';
import 'package:rafiq_app/view/pages/step_two_screen/step_two_screen.dart';
import 'package:rafiq_app/view/pages/step_three_screen/step_three_screen.dart';
import 'package:rafiq_app/view/pages/suggestions/suggestions_screen.dart';

/// Multi-step preference picker (city → budget → activity → suggestions).
///
/// UX rules:
///   * Hardware back returns to the `ChoiceScreen` (instead of killing the app).
///   * The bottom CTA is sticky and safe-area aware; copy changes on the last step.
///   * Steps animate via [AppMotion.base] instead of jumping.
///   * Users can jump backward/forward by tapping the step indicator.
///   * A floating chat FAB is always reachable but never overlaps the CTA.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const int _totalSteps = 3;

  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();

  int _currentIndex = 0;
  bool _isLoading = false;

  String _cityName = '';
  String _budget = '';
  String _activity = '';

  late final List<_StepDef> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      _StepDef(
        icon: AppImages.location,
        label: AppCopy.stepCity,
        builder: () => StepOne(
          onCitySelected: (v) => _setField(_Field.city, v),
        ),
      ),
      _StepDef(
        icon: AppImages.dollar,
        label: AppCopy.stepBudget,
        builder: () => StepTwo(
          onBudgetSelected: (v) => _setField(_Field.budget, v),
        ),
      ),
      _StepDef(
        icon: AppImages.entertainment,
        label: AppCopy.stepActivity,
        builder: () => StepThree(
          onActivitySelected: (v) => _setField(_Field.activity, v),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  void _setField(_Field field, String raw) {
    final value = raw.trim();
    setState(() {
      switch (field) {
        case _Field.city:
          _cityName = value;
        case _Field.budget:
          _budget = value;
        case _Field.activity:
          _activity = value;
      }
    });
  }

  bool get _isFormValid =>
      _cityName.isNotEmpty && _budget.isNotEmpty && _activity.isNotEmpty;

  bool get _isLastStep => _currentIndex == _totalSteps - 1;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------
  void _goToStep(int index) {
    if (_isLoading) return;
    if (index < 0 || index >= _totalSteps) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: AppMotion.base,
      curve: AppMotion.standard,
    );
  }

  void _handlePrimaryCta() {
    if (!_isLastStep) {
      _goToStep(_currentIndex + 1);
      return;
    }
    if (!_isFormValid) {
      AppFeedback.warning(AppCopy.homeIncomplete);
      return;
    }
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final List<Place> places = await _apiService.fetchPlaces(
        cityName: _cityName,
        budget: _budget,
        activity: _activity,
        forceRefresh: true,
      );
      if (places.isEmpty) {
        AppFeedback.info(AppCopy.emptyResultsBody);
        return;
      }
      final items =
          places.map((p) => SuggestionItemModel.fromPlace(p)).toList();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SuggestionsScreen(suggestionItemList: items),
        ),
      );
    } catch (_) {
      AppFeedback.error(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Hardware back from a primary surface should suspend the app, not
  /// teleport to ChoiceScreen. Switching role is a deliberate action
  /// inside Profile.
  Future<void> _backgroundApp() async {
    await SystemNavigator.pop();
  }

  void _openChatBot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BotScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backgroundApp();
      },
      child: LoadingManager(
        isLoading: _isLoading,
        message: AppCopy.loadingSuggestions,
        child: Scaffold(
          backgroundColor: AppColor.surface,
          resizeToAvoidBottomInset: true,
          // One AppPageHeader for every root surface keeps the title scale,
          // hairline border, and trailing slot identical across the app.
          appBar: const AppPageHeader(
            title: AppCopy.homeTitle,
            actions: [ProfilePill()],
          ),
          body: SafeArea(
            top: false, // header already pads for the system bar
            child: Column(
              children: [
                gapV(AppSpacing.md),
                _StepHeader(
                  steps: _steps,
                  currentIndex: _currentIndex,
                  onTap: _goToStep,
                ),
                gapV(AppSpacing.md),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemCount: _steps.length,
                    itemBuilder: (_, i) => _steps[i].builder(),
                  ),
                ),
                _BottomBar(
                  currentIndex: _currentIndex,
                  totalSteps: _totalSteps,
                  isLastStep: _isLastStep,
                  isLoading: _isLoading,
                  onBack: _currentIndex == 0
                      ? null
                      : () => _goToStep(_currentIndex - 1),
                  onNext: _handlePrimaryCta,
                  onChatTap: _openChatBot,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Internals
// ===========================================================================

enum _Field { city, budget, activity }

class _StepDef {
  const _StepDef({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final String icon;
  final String label;
  final Widget Function() builder;
}

/// Step indicator row + "step N of T" caption.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.steps,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_StepDef> steps;
  final int currentIndex;
  final ValueChanged<int> onTap;

  String _counterText() => AppCopy.homeStepCounter
      .replaceFirst('%d', '${currentIndex + 1}')
      .replaceFirst('%t', '${steps.length}');

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Aligned with AppPageHeader's lg.w gutter so the step counter sits
      // right under the title.
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_counterText(), style: AppText.caption),
          gapV(AppSpacing.sm),
          Row(
            children: List.generate(
              steps.length,
              (i) => StepperComponent(
                index: i,
                currentIndex: currentIndex,
                icon: steps[i].icon,
                label: steps[i].label,
                isLast: i == steps.length - 1,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar: back (when applicable) + primary CTA + chat FAB.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.totalSteps,
    required this.isLastStep,
    required this.isLoading,
    required this.onBack,
    required this.onNext,
    required this.onChatTap,
  });

  final int currentIndex;
  final int totalSteps;
  final bool isLastStep;
  final bool isLoading;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl.w,
        AppSpacing.md.h,
        AppSpacing.xxl.w,
        AppSpacing.lg.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.surfaceCard,
        boxShadow: AppShadows.level2,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _BackIconButton(onTap: onBack!),
            gapH(AppSpacing.md),
          ],
          Expanded(
            child: AppButton(
              text: isLastStep ? AppCopy.homeCtaFinal : AppCopy.next,
              onPress: onNext,
              isEnabled: !isLoading,
            ),
          ),
          gapH(AppSpacing.md),
          _ChatFab(onTap: onChatTap),
        ],
      ),
    );
  }
}

class _BackIconButton extends StatelessWidget {
  const _BackIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppCopy.back,
      child: Material(
        color: AppColor.surface,
        shape: const CircleBorder(),
        child: InkResponse(
          onTap: onTap,
          radius: 28.w,
          child: SizedBox(
            width: 52.w,
            height: 52.w,
            child: Icon(
              // arrow_back_ios_new_rounded auto-mirrors in RTL so it visually
              // points to the right — the natural "back" direction for Arabic
              // reading order. Matches the AppPageHeader leading icon.
              Icons.arrow_back_ios_new_rounded,
              color: AppColor.textPrimary,
              size: 22.sp,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatFab extends StatelessWidget {
  const _ChatFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppCopy.chatTitle,
      child: Material(
        color: AppColor.primary,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkResponse(
          onTap: onTap,
          radius: 28.w,
          child: SizedBox(
            width: 52.w,
            height: 52.w,
            child: Icon(
              Icons.chat_bubble_rounded,
              color: AppColor.white,
              size: 22.sp,
            ),
          ),
        ),
      ),
    );
  }
}
