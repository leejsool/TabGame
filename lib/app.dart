import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'core/settings_scope.dart';
import 'hub/hub_screen.dart';
import 'net/lan_stall_overlay.dart';

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
          // 같은 Wi‑Fi 대결에서 상대 응답이 끊기면 어느 화면에서든 "기다리는 중" 안내가 위에 뜬다
          builder: (context, child) => LanStallOverlay(child: child ?? const SizedBox.shrink()),
          home: HubScreen(settings: settings),
        ),
      ),
    );
  }
}
