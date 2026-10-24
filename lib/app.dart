import 'package:flutter/material.dart';

import 'core/click_sound.dart';
import 'core/game_filter.dart';
import 'core/settings.dart';
import 'core/settings_scope.dart';
import 'hub/hub_screen.dart';
import 'net/lan_stall_overlay.dart';

class TabGameApp extends StatelessWidget {
  const TabGameApp({super.key, required this.settings, this.hubFilter = GameFilter.mentoring});

  final Settings settings;

  /// 첫 화면에서 골라져 있는 분류 (멘토링 수업용으로 멘토링부터 보인다).
  final GameFilter hubFilter;

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F7CAC),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NanumGothic',
      // 버튼을 누를 때마다 딸깍 소리 (설정의 "효과음"을 끄면 나지 않는다)
      splashFactory: const ClickSplashFactory(),
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
        builder: (context, _) {
          ClickSound.soundOn = settings.sound;
          ClickSound.load(); // (소리를 미리 불러 둔다. 이미 불렀으면 아무것도 안 한다)
          return MaterialApp(
          title: 'TabGame',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: settings.themeMode,
          // 같은 Wi‑Fi 대결에서 상대 응답이 끊기면 어느 화면에서든 "기다리는 중" 안내가 위에 뜬다
          builder: (context, child) => LanStallOverlay(child: child ?? const SizedBox.shrink()),
          home: HubScreen(settings: settings, initialFilter: hubFilter),
          );
        },
      ),
    );
  }
}
