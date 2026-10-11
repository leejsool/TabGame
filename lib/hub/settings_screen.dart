import 'package:flutter/material.dart';

import '../core/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('효과음'),
              value: settings.sound,
              onChanged: (v) => settings.sound = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('진동'),
              value: settings.haptics,
              onChanged: (v) => settings.haptics = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('스도쿠 자동 완성'),
              subtitle: const Text('남은 칸이 15개 이하이고 바로 보이는 칸뿐이면 자동으로 채워서 끝내요'),
              value: settings.autoComplete,
              onChanged: (v) => settings.autoComplete = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.style_rounded),
              title: const Text('프리셀 자동 올리기'),
              subtitle: const Text('손해 없는 카드는 완성 칸으로 알아서 올려요'),
              value: settings.freecellAutoMove,
              onChanged: (v) => settings.freecellAutoMove = v,
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_rounded),
              title: const Text('화면 모드'),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('자동')),
                  ButtonSegment(value: ThemeMode.light, label: Text('밝게')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('어둡게')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.themeMode = s.first,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
