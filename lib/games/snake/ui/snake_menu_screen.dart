import 'package:flutter/material.dart';

import '../../../core/nickname.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_screens.dart';
import '../../../records/records_screen.dart';
import '../data/snake_prefs.dart';
import '../game/snake_controller.dart';
import '../game/snake_host_net.dart';
import '../tutorial/snake_tutorial.dart';
import 'snake_icon.dart';
import 'snake_screen.dart';

const Color kSnakeColor = Color(0xFF2ED1A2);

/// 지렁이의 모험 첫 화면: 바로 시작하기 (같은 Wi‑Fi 방을 열고 CPU들과 시작) / 친구 판에 들어가기.
class SnakeMenuScreen extends StatefulWidget {
  const SnakeMenuScreen({super.key});

  @override
  State<SnakeMenuScreen> createState() => _SnakeMenuScreenState();
}

class _SnakeMenuScreenState extends State<SnakeMenuScreen> {
  @override
  void initState() {
    super.initState();
    SnakePrefs.load();
  }

  void _start(BuildContext context) {
    final nick = SettingsScope.of(context).nickname;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SnakeScreen(controller: SnakeController.host(nick: nick), openRoomAs: nick),
    ));
  }

  void _join(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LanJoinScreen(
        game: kSnakeLanGame,
        color: kSnakeColor,
        roomTitle: (r) => '${r.info['nick'] ?? '친구'}님의 판',
        roomSubtitle: (r) => '지금 사람 ${r.info['people'] ?? 1}명 · 언제든 끼어들 수 있어요',
        buildGame: snakeResume,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const big = TextStyle(fontFamily: 'NanumGothic', fontSize: 18, fontWeight: FontWeight.w800);
    return Scaffold(
      appBar: AppBar(
        title: const Text('지렁이의 모험', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(tooltip: '게임 방법', icon: const Icon(Icons.help_outline_rounded), onPressed: () => snakeTutorial().open(context)),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: 'snake')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const NicknameBar(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14192B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      SizedBox(width: 120, height: 120, child: CustomPaint(painter: _IconPainter())),
                      const SizedBox(height: 10),
                      const Text(
                        '먹이를 먹고 길게 자라서 1등을 노려요!\n다른 지렁이 몸이나 벽에 머리를 박으면 끝나요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.45, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '30마리가 한 필드에서 겨뤄요. 친구가 없어도 CPU들과 바로 시작하고, 같은 Wi‑Fi의 친구는 판 도중에 언제든 들어올 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.45, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('바로 시작하기'),
                  style: FilledButton.styleFrom(backgroundColor: kSnakeColor, foregroundColor: const Color(0xFF0B2A22), padding: const EdgeInsets.symmetric(vertical: 18), textStyle: big),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _join(context),
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: const Text('친구 판에 들어가기'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), textStyle: big),
                ),
                const SizedBox(height: 18),
                const _HandPicker(),
                const SizedBox(height: 16),
                Text(
                  '"바로 시작하기"를 누르면 내 기기에 방이 열려요. 친구는 같은 Wi‑Fi에서 "친구 판에 들어가기"로 들어오면 돼요. '
                  '사람이 늘면 그만큼 CPU가 줄어서 늘 30마리 정도가 돼요.',
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 손 바꾸기: 부스터를 오른쪽(기본)에 둘지 왼쪽에 둘지.
class _HandPicker extends StatelessWidget {
  const _HandPicker();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'NanumGothic', fontSize: 13.5, fontWeight: FontWeight.w800);
    return ValueListenableBuilder<bool>(
      valueListenable: SnakePrefs.boostLeft,
      builder: (context, left, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('부스터 위치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          // (좁은 폰에서도 한 줄로 보이게 짧게: 부스터가 있는 쪽의 반대쪽 손으로 방향을 잡는다)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('오른쪽', maxLines: 1, softWrap: false, style: style)),
              ButtonSegment(value: true, label: Text('왼쪽', maxLines: 1, softWrap: false, style: style)),
            ],
            selected: {left},
            showSelectedIcon: false,
            onSelectionChanged: (v) => SnakePrefs.setBoostLeft(v.first),
          ),
          const SizedBox(height: 6),
          Text(
            left ? '왼쪽 화면을 꾹 누르면 부스터, 오른쪽 화면을 끌면 방향이에요.' : '오른쪽 화면을 꾹 누르면 부스터, 왼쪽 화면을 끌면 방향이에요.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width);
    paintSnakeIcon(canvas, size.width);
  }

  @override
  bool shouldRepaint(_IconPainter old) => false;
}
