import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/service/api_service.dart'; // استيراد ApiService
import 'package:rafiq_app/model/place.dart'; // استيراد Place

/// Represents the state of the filter system
class FilterState {
  static const Object _errorMessageUnset = Object();

  final String? activity;
  final String? city;
  final String? budget;
  final List<Place>? places;
  final String? errorMessage;
  final bool isLoading;

  const FilterState({
    this.activity,
    this.city,
    this.budget,
    this.places,
    this.errorMessage,
    this.isLoading = false,
  });

  /// Creates a copy of the current state with optional updates
  FilterState copyWith({
    String? activity,
    String? city,
    String? budget,
    List<Place>? places,
    Object? errorMessage = _errorMessageUnset,
    bool? isLoading,
  }) {
    return FilterState(
      activity: activity ?? this.activity,
      city: city ?? this.city,
      budget: budget ?? this.budget,
      places: places ?? this.places,
      errorMessage: identical(errorMessage, _errorMessageUnset)
          ? this.errorMessage
          : errorMessage as String?,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Checks if all required filters are set
  bool get hasRequiredFilters =>
      activity?.isNotEmpty == true &&
      city?.isNotEmpty == true &&
      budget?.isNotEmpty == true;
}

/// Cubit responsible for managing filter state and API interactions
class FilterCubit extends Cubit<FilterState> {
  static const Duration _autoApplyDebounce = Duration(milliseconds: 350);

  final ApiService _apiService;
  Timer? _debounceTimer;
  int _requestCounter = 0;
  String? _lastAppliedKey;

  FilterCubit(this._apiService) : super(const FilterState());

  /// Updates the activity filter and triggers a search
  void updateActivity(String activity) {
    final normalized = activity.trim();
    if (state.activity == normalized) return;
    emit(state.copyWith(activity: normalized, errorMessage: null));
    _scheduleApplyIfReady();
  }

  /// Updates the city filter and triggers a search
  void updateCity(String city) {
    final normalized = city.trim();
    if (state.city == normalized) return;
    emit(state.copyWith(city: normalized, errorMessage: null));
    _scheduleApplyIfReady();
  }

  /// Updates the budget filter and triggers a search
  void updateBudget(String budget) {
    final normalized = budget.trim();
    if (state.budget == normalized) return;
    emit(state.copyWith(budget: normalized, errorMessage: null));
    _scheduleApplyIfReady();
  }

  String _buildFilterKey() {
    return '${state.activity ?? ''}|${state.city ?? ''}|${state.budget ?? ''}';
  }

  /// Applies filters shortly after user finishes interaction.
  void _scheduleApplyIfReady() {
    _debounceTimer?.cancel();
    if (!state.hasRequiredFilters) return;

    _debounceTimer = Timer(_autoApplyDebounce, () {
      applyFilters();
    });
  }

  /// Applies all filters and fetches matching places
  Future<void> applyFilters({bool forceRefresh = false}) async {
    if (!state.hasRequiredFilters) {
      emit(state.copyWith(
        errorMessage: 'يرجى اختيار النشاط، المدينة، والميزانية.',
        places: [],
      ));
      return;
    }

    final currentKey = _buildFilterKey();
    final hasLocalResult = state.places != null;
    if (!forceRefresh && hasLocalResult && _lastAppliedKey == currentKey) {
      return;
    }

    final requestId = ++_requestCounter;
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final places = await _apiService.fetchPlaces(
        activity: state.activity!,
        cityName: state.city!,
        budget: state.budget!,
        forceRefresh: forceRefresh,
      );

      if (requestId != _requestCounter) {
        return;
      }

      _lastAppliedKey = currentKey;
      emit(state.copyWith(
        places: places,
        errorMessage: null,
        isLoading: false,
      ));
    } catch (e) {
      if (requestId != _requestCounter) {
        return;
      }

      emit(state.copyWith(
        errorMessage: 'حدث خطأ أثناء الاتصال بالـ API: $e',
        places: [],
        isLoading: false,
      ));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
