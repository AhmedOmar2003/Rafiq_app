import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/service/api_service.dart'; // استيراد ApiService
import 'package:rafiq_app/model/place.dart'; // استيراد Place

/// Represents the state of the filter system
class FilterState {
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
    String? errorMessage,
    bool? isLoading,
  }) {
    return FilterState(
      activity: activity ?? this.activity,
      city: city ?? this.city,
      budget: budget ?? this.budget,
      places: places ?? this.places,
      errorMessage: errorMessage ?? this.errorMessage,
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
  final ApiService _apiService;

  FilterCubit(this._apiService) : super(const FilterState());

  /// Updates the activity filter and triggers a search
  void updateActivity(String activity) {
    emit(state.copyWith(activity: activity));
    _applyFiltersIfReady();
  }

  /// Updates the city filter and triggers a search
  void updateCity(String city) {
    emit(state.copyWith(city: city));
    _applyFiltersIfReady();
  }

  /// Updates the budget filter and triggers a search
  void updateBudget(String budget) {
    emit(state.copyWith(budget: budget));
    _applyFiltersIfReady();
  }

  /// Applies filters if all required fields are present
  void _applyFiltersIfReady() {
    if (state.hasRequiredFilters) {
      applyFilters();
    }
  }

  /// Applies all filters and fetches matching places
  Future<void> applyFilters() async {
    if (!state.hasRequiredFilters) {
      emit(state.copyWith(
        errorMessage: 'يرجى اختيار النشاط، المدينة، والميزانية.',
        places: [],
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final places = await _apiService.fetchPlaces(
        activity: state.activity!,
        cityName: state.city!,
        budget: state.budget!,
      );

      emit(state.copyWith(
        places: places,
        errorMessage: null,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'حدث خطأ أثناء الاتصال بالـ API: $e',
        places: [],
        isLoading: false,
      ));
    }
  }
}
