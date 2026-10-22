import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/db/local_db.dart';
import 'core/design/nr_theme.dart';
import 'core/providers.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  final db = await LocalDb.open();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [localDbProvider.overrideWithValue(db), prefsProvider.overrideWithValue(prefs)],
    child: const NoriApp(),
  ));
}

class NoriApp extends ConsumerWidget {
  const NoriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    return MaterialApp.router(
      title: 'Nori',
      debugShowCheckedModeBanner: false,
      theme: NrTheme.light(accent),
      darkTheme: NrTheme.dark(accent),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
