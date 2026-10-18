import '../core/nickname.dart';
import 'package:flutter/material.dart';

import '../core/card_look.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import '../core/update/update_service.dart';
import '../core/update/update_ui.dart';
import '../games/freecell/ui/playing_card.dart';
import '../games/solitaire/ui/card_back.dart';
import '../tutorial/tutorial_progress.dart';
import 'game_visibility_screen.dart';

part 'settings_screen_suit_pickers.dart';
part 'settings_screen_card_pickers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(top: false, child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          // 가로로 넓은 태블릿에서도 글자와 스위치가 너무 멀어지지 않게 폭을 제한한다
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
          // 맨 아래 항목이 태블릿의 아래 시스템 바(내비게이션 바)에 가리지 않게 그만큼 띄운다
          padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            const _SectionTitle('내 정보'),
            ListTile(
              leading: const Icon(Icons.badge_rounded),
              title: const Text('내 별명'),
              subtitle: Text('${settings.nickname} · 같은 Wi‑Fi로 함께 할 때 상대에게 보여요'),
              trailing: const Icon(Icons.edit_rounded),
              onTap: () => editNickname(context, settings: settings),
            ),
            ListTile(
              key: const ValueKey('settings-visible-games'),
              leading: const Icon(Icons.visibility_rounded),
              title: const Text('메인 화면에 보일 게임'),
              subtitle: Text(settings.hiddenGames.isEmpty
                  ? '모든 게임이 보여요 · 안 할 게임은 꺼서 메인 화면을 정리할 수 있어요'
                  : '${allGames.length}개 중 ${allGames.where((g) => settings.isGameVisible(g.id)).length}개가 보여요'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => GameVisibilityScreen(settings: settings)),
              ),
            ),
            const _SectionTitle('소리와 진동'),
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
            const _SectionTitle('화면'),
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
            _CardStylePicker(settings: settings),
            _CardLayoutPicker(settings: settings),
            _CardBackStylePicker(settings: settings),
            _SuitColorPicker(settings: settings),
            SwitchListTile(
              secondary: const Icon(Icons.fast_forward_rounded),
              title: const Text('빠른 진행'),
              subtitle: const Text('CPU가 덜 기다리고, 상대의 수가 더 빨리 움직여요'),
              value: settings.fastPace,
              onChanged: (v) => settings.fastPace = v,
            ),
            const _SectionTitle('게임별 도우미'),
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
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('솔리테어 자동 올리기'),
              subtitle: const Text('손해 없는 카드는 완성 칸으로 알아서 올려요'),
              value: settings.solitaireAutoMove,
              onChanged: (v) => settings.solitaireAutoMove = v,
            ),
            const _SectionTitle('처음 안내'),
            SwitchListTile(
              secondary: const Icon(Icons.school_rounded),
              title: const Text('게임 방법 안내'),
              subtitle: const Text('게임을 처음 열 때 방법을 알려 줘요 (언제든 건너뛸 수 있어요)'),
              value: settings.showTutorials,
              onChanged: (v) => settings.showTutorials = v,
            ),
            ListTile(
              leading: const Icon(Icons.replay_rounded),
              title: const Text('게임 방법 안내 다시 받기'),
              subtitle: const Text('모든 게임의 처음 안내를 다시 보여줘요'),
              onTap: () async {
                await TutorialProgress.resetSeen();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('다음에 게임을 열 때 방법 안내가 다시 나와요')),
                  );
              },
            ),
            if (updatesSupported) ...[
              const _SectionTitle('앱 업데이트'),
              SwitchListTile(
                secondary: const Icon(Icons.system_update_rounded),
                title: const Text('시작할 때 업데이트 확인'),
                subtitle: const Text('새 버전이 나오면 알려 주고, 눌러서 바로 내려받아 설치해요'),
                value: settings.autoUpdateCheck,
                onChanged: (v) => settings.autoUpdateCheck = v,
              ),
              _UpdateTile(settings: settings),
            ],
          ],
        ))),
      )),
    );
  }
}

/// 설정 묶음의 제목 줄.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.refresh_rounded),
      title: const Text('지금 업데이트 확인'),
      subtitle: FutureBuilder<AppVersion?>(
        future: UpdateService().currentVersion().then<AppVersion?>((v) => v).catchError((_) => null),
        builder: (_, snap) => Text(snap.data == null ? '현재 버전을 알 수 없어요' : '현재 버전 v${snap.data}'),
      ),
      onTap: () => checkForUpdate(context, settings, manual: true),
    );
  }
}
