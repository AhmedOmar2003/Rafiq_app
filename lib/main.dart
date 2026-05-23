import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:rafiq_app/rafiq_app.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
// استيراد الـ FilterCubit

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  PaintingBinding.instance.imageCache.maximumSize = 120;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => FilterCubit(ApiService())),
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
