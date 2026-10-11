import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'core/settings_scope.dart';
import 'hub/hub_screen.dart';

class TabGameApp extends StatelessWidget {
  const TabGameApp({super.key, required this.settings});

  final Settings settings;

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F7CAC),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NanumGothic',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F3EE)
          : const Color(0xFF15181C),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'TabGame',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: settings.themeMode,
          home: HubScreen(settings: settings),
        ),
      ),
    );
  }
}
