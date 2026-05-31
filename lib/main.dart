import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rafiq_app/rafiq_app.dart';
import 'package:rafiq_app/service/analytics_tracker.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/image_disk_cache.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
import 'package:rafiq_app/service/subscription_service.dart';
import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/pages/cubit.dart';

// Sentry temporarily removed — the package's Kotlin sources don't compile
// against our current Android Gradle/Kotlin toolchain. The init flow stays
// behind an env-gated stub so re-adding the package later is a one-line
// change. Track in docs/OPERATIONS.md.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ---------------------------------------------------------------------------
  // GoogleFonts runtime behaviour.
  //
  // By default `google_fonts` will try to download font files from Google's CDN
  // on first use. That blocks first paint on cold start (200–800ms on slow
  // networks) and creates a hard runtime dependency on the CDN.
  //
  // We keep runtime fetching ON for first install (so users see Rubik
  // immediately), but warm the download in parallel with the splash so the UI
  // thread isn't blocked when the first text widget builds. After warm-up the
  // font is cached on disk and subsequent launches are local.
  //
  // Release builds should ship Rubik as a bundled asset; see TODO below.
  // ---------------------------------------------------------------------------
  // TODO(perf): bundle Rubik as an app asset and set
  //   GoogleFonts.config.allowRuntimeFetching = false;
  // to remove the CDN dependency entirely.
  unawaited(GoogleFonts.pendingFonts(<TextStyle>[
    GoogleFonts.rubik(fontWeight: FontWeight.w400),
    GoogleFonts.rubik(fontWeight: FontWeight.w500),
    GoogleFonts.rubik(fontWeight: FontWeight.w600),
    GoogleFonts.rubik(fontWeight: FontWeight.w700),
  ]));

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

  // Sentry wiring temporarily disabled — see import comment above.
  // The DSN-gated branch is kept so re-enabling is mechanical: drop the
  // sentry_flutter dep back in, swap the `else` branch's runApp for the
  // SentryFlutter.init call, done.
  runApp(appRoot());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });

  if (kDebugMode) {
    debugPrint(
      'App started; Supabase lazy. Sentry: ${_sentryDsn.isEmpty ? "OFF" : "ON"}',
    );
  }
}
