import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:rafiq_app/rafiq_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:rafiq_app/service/analytics_tracker.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/accessibility_preferences.dart';
import 'package:rafiq_app/service/image_disk_cache.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/pages/cubit.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Make sure the disk-cache directory exists *now* so the first list of
  // suggestions can use the synchronous fast-path on cache hits.
  unawaited(ImageDiskCache.instance.warmUp());

  // Profile picture is read on most screens — fire-and-forget warm so the
  // first frame already has the avatar resolved.
  unawaited(ProfileImageStore.instance.ensureLoaded());

  // Analytics: attach the tracker so it flushes on background + every 5s.
  AnalyticsTracker.instance.attach();

  // Restore any persisted demo subscription so the UI keeps the chosen
  // tier across app restarts until the real payment webhook takes over.
  unawaited(SubscriptionService.instance.restorePersistedDemo());

  // Restore the provider-track flag so the Profile shows the right tiles
  // on first frame.
  unawaited(UserRoleStore.instance.ensureLoaded());
  unawaited(AccessibilityPreferences.instance.ensureLoaded());

  // Pre-warm the subscription plan catalog. The first screen that needs to
  // resolve a tier's display name / price (Profile, Hub, Subscription) used
  // to wait for a 200–400ms DB round-trip on cold open; doing this in the
  // splash window means the catalog is already in memory before the user
  // navigates anywhere.
  unawaited(SubscriptionService.instance.loadCatalog());

  // Initialise the Supabase client during the splash so the first authed
  // call (entitlement load, places fetch) doesn't pay the SDK init cost
  // on the user-facing path.
  unawaited(ApiService.ensureSupabaseInitialized());

  // ---------------------------------------------------------------------------
  // Image cache budget.
  //
  // The suggestions list can hold ~80 cards each with a 220h hero image. At
  // a typical decoded size of ~400KB per image, just the visible+nearby cards
  // can sit at ~32MB. The previous 120 / 80MB budget caused eviction during
  // scroll → re-decode → frame drops. Bumped to 250 / 150MB which comfortably
  // covers the active scroll window without starving low-end devices.
  // ---------------------------------------------------------------------------
  PaintingBinding.instance.imageCache.maximumSize = 250;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;

  // Portrait-only for now — fewer layout passes, simpler reasoning.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Widget appRoot() => MultiProvider(
        providers: [
          Provider(create: (_) => FilterCubit(ApiService())),
        ],
        child: const RafiqApp(),
      );

  if (_sentryDsn.isEmpty) {
    runApp(appRoot());
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.20;
        options.attachScreenshot = false;
      },
      appRunner: () => runApp(appRoot()),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });

  if (kDebugMode) {
    debugPrint(
      'App started; Supabase lazy. Sentry: ${_sentryDsn.isEmpty ? "OFF" : "ON"}',
    );
  }
}
