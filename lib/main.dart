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
import 'package:rafiq_app/view/pages/cubit.dart';

void main() async {
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

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FilterCubit(ApiService())),
      ],
      child: const RafiqApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });

  if (kDebugMode) {
    debugPrint('App started; Supabase will initialize lazily on first use.');
  }
}
