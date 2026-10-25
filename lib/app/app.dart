import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:galeria_eventos/app/router/app_router.dart';
import 'package:galeria_eventos/app/theme/app_theme.dart';
import 'package:galeria_eventos/core/config/app_info.dart';

class GaleriaApp extends ConsumerWidget {
  const GaleriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
