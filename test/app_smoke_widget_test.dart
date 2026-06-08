import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/models/suggestion_item_model/suggestion_item.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/home/home_view.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
import 'package:rafiq_app/view/pages/profile_page.dart';
import 'package:rafiq_app/view/pages/suggestions/suggestions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'userName': 'مستخدم تجريبي',
      'userEmail': 'tester@gmail.com',
    });
  });

  testWidgets('profile shows favorites section and empty state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => const MaterialApp(
          home: ProfilePage(enableRemoteBootstrap: false),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text(AppCopy.profileFavoritesTitle), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedCrossFade &&
            widget.crossFadeState == CrossFadeState.showFirst,
      ),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.text(AppCopy.profileFavoritesTitle));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedCrossFade &&
            widget.crossFadeState == CrossFadeState.showSecond,
      ),
      findsAtLeastNWidgets(1),
    );
    expect(find.text(AppCopy.emptyFavoritesTitle), findsOneWidget);
    expect(find.text(AppCopy.emptyFavoritesBody), findsOneWidget);
  });

  testWidgets('profile remains usable on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            );
          },
          home: const ProfilePage(enableRemoteBootstrap: false),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text(AppCopy.profileAccountSection), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppCopy.profileAppearanceSection), findsOneWidget);
    expect(find.text(AppCopy.profileSupportSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggestions screen renders seeded cards', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => BlocProvider(
          create: (_) => FilterCubit(ApiService()),
          child: MaterialApp(
            home: SuggestionsScreen(suggestionItemList: items),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppCopy.suggestionsTitle), findsOneWidget);
    expect(find.text('مكان رائع'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('مكان هادئ'), findsOneWidget);
  });

  testWidgets('modal sheet stays usable on a small screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            );
          },
          home: Scaffold(
            body: AppModalSheetFrame(
              title: 'حملة جديدة',
              subtitle: 'هنراجعها خلال 6 ساعات.',
              body: Column(
                children: List.generate(
                  12,
                  (index) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('تفاصيل الحملة'),
                  ),
                ),
              ),
              footer: const SizedBox(
                height: 48,
                child: Center(child: Text('إرسال للمراجعة')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('حملة جديدة'), findsOneWidget);
    expect(find.text('إرسال للمراجعة'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('preference flow requires each choice before moving forward',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            );
          },
          home: const HomeView(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text(AppCopy.stepCityTitle), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'city step overflowed');
    await tester.tap(find.text(AppCopy.next));
    await tester.pumpAndSettle();
    expect(find.text(AppCopy.stepCityTitle), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'city validation overflowed');

    await tester.tap(find.text('القاهرة'));
    await tester.tap(find.text(AppCopy.next));
    await tester.pumpAndSettle();
    expect(find.text(AppCopy.stepBudgetTitle), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'budget step overflowed');

    await tester.tap(find.text('100 إلى 500 جنيه'));
    await tester.tap(find.text(AppCopy.next));
    await tester.pumpAndSettle();
    expect(find.text(AppCopy.stepActivityTitle), findsOneWidget);
    expect(find.text(AppCopy.homeCtaFinal), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'activity step overflowed');
  });
}
