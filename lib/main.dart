import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:rafiq_app/rafiq_app.dart';
import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/view/pages/cubit.dart';
import 'core/logic/cache_helper.dart';
// استيراد الـ FilterCubit

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  Future.delayed(const Duration(seconds: 2), () {
    FlutterNativeSplash.remove();
  });
  await CacheHelper.init();

  // إضافة الـ Provider في أعلى الشجرة
  runApp(
    MultiProvider(
      providers: [
        // إضافة FilterCubit هنا
        Provider(create: (context) => FilterCubit(ApiService())),
        // إضافة أي Providers آخرين هنا إذا لزم الأمر
      ],
      child: const RafiqApp(),
    ),
  );
}
