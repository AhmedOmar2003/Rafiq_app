import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
import 'package:rafiq_app/view/pages/profile_page.dart';
import 'package:rafiq_app/view/pages/suggestions/suggestions_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'userName': 'مستخدم تجريبي',
      'userEmail': 'tester@gmail.com',
    });
  });

  group('Rafiq smoke routes', () {
    testWidgets('profile renders the favorites section and empty state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePage(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text(AppCopy.profileFavoritesTitle), findsOneWidget);
      expect(find.text(AppCopy.emptyFavoritesTitle), findsOneWidget);
      expect(find.text(AppCopy.emptyFavoritesBody), findsOneWidget);
    });

    testWidgets('suggestions screen renders seeded places', (tester) async {
      final items = <SuggestionItemModel>[
        SuggestionItemModel(
          text: 'مكان رائع',
          address: 'الإسكندرية',
          body: 'وصف مختصر للمكان',
          image: '',
          icon: '',
          suggestionText: 'طعام',
          price: '300',
          rate: 4.5,
          color: Colors.orange,
          city: 'الإسكندرية',
          placeId: 1,
          placeUuid: '00000000-0000-0000-0000-000000000001',
        ),
        SuggestionItemModel(
          text: 'مكان هادئ',
          address: 'القاهرة',
          body: 'وصف آخر للمكان',
          image: '',
          icon: '',
          suggestionText: 'ترفيه',
          price: '500',
          rate: 4.2,
          color: Colors.blue,
          city: 'القاهرة',
          placeId: 2,
          placeUuid: '00000000-0000-0000-0000-000000000002',
        ),
      ];

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => FilterCubit(ApiService()),
          child: MaterialApp(
            home: SuggestionsScreen(suggestionItemList: items),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(AppCopy.suggestionsTitle), findsOneWidget);
      expect(find.text('مكان رائع'), findsOneWidget);
      expect(find.text('مكان هادئ'), findsOneWidget);
    });
  });
}
