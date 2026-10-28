import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'data/app_store.dart';
import 'data/auth_service.dart';
import 'data/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final prefs = await SharedPreferences.getInstance();
  await AuthService.init();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  container.read(syncServiceProvider);
  container.read(authServiceProvider).listen();
  runApp(UncontrolledProviderScope(container: container, child: const PopoteApp()));
}

class PopoteApp extends ConsumerWidget {
  const PopoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le thème choisi change instantanément, sans redémarrage (F-PRF-02).
    final themeKey = ref.watch(appStoreProvider.select((d) => d.themeKey));
    final palette = paletteFor(themeKey);
    return MaterialApp.router(
      title: 'Popote',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
