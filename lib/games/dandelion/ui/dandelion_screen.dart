import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../records/records_screen.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../data/dandelion_history.dart';
import '../game/dandelion_controller.dart';
import '../tutorial/dandelion_tutorial.dart';
import 'dandelion_art.dart';
import 'dandelion_board.dart';
import 'dandelion_lesson_screen.dart';

/// 민들레 플레이 화면.
class DandelionScreen extends StatefulWidget {
  const DandelionScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanRole = Role.dandelion,
    this.level = DandLevel.normal,
    this.controller,
  });

  final PlayMode mode;
  final Role humanRole;
  final DandLevel level;

  /// (테스트용) 미리 만든 컨트롤러.
  final DandelionController? controller;

  @override
  State<DandelionScreen> createState() => _DandelionScreenState();
}

class _DandelionScreenState extends State<DandelionScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final DandelionController c = widget.controller ??
      DandelionController(mode: widget.mode, humanRole: widget.humanRole, level: widget.level);
  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.dispose();
    super.dispose();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'plant':
        HapticFeedback.selectionClick();
      case 'wind':
        HapticFeedback.lightImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      DandelionHistory.add(DandelionRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: c.winner!,
        moves: c.moveCount,
        empties: c.state.emptyCount,
        level: c.vsCpu ? c.level : null,
        human: c.vsCpu ? c.humanRole : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 2600), _showResult);
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final role = c.resigningRole;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '${role.label}이(가) 기권하고, ${role.other.label}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    await DandelionHistory.add(DandelionRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      winner: role.other,
      moves: c.moveCount,
      empties: c.state.emptyCount,
      level: c.vsCpu ? c.level : null,
      human: c.vsCpu ? c.humanRole : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${role.label} 기권 · ${c.moveCount}수',
      againLabel: '새 판',
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showResult() async {
    if (!mounted || !c.isOver) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ResultDialog(controller: c),
    );
    if (!mounted) return;
    if (again == true) {
      c.restart();
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 문구 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = c.winner!;
      if (c.vsCpu) return w == c.humanRole ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      return '${w.label} 승리!';
    }
    if (c.thinking) return c.cpuRole == Role.dandelion ? 'CPU가 꽃을 심는 중…' : 'CPU가 바람을 고르는 중…';
    final who = c.vsCpu ? (s.turn == c.humanRole ? '내 차례' : 'CPU 차례') : '${s.turn.label} 차례';
    final what = s.turn == Role.dandelion ? '꽃을 심을 칸을 누르세요' : '불어 보낼 방향을 고르세요';
    return '$who · $what';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF1F2A24), Color(0xFF18201B)]
                : const [Color(0xFFE9F5D6), Color(0xFFD3EBB2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.2;
              return Column(
                children: [
                  _topBar(),
                  Expanded(child: landscape ? _landscape() : _portrait()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _board() => Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: DandelionBoard(
            controller: c,
            onPlant: (cell) {
              if (!c.plant(cell) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
            },
          ),
        ),
      );

  Widget _compass({double size = 150}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final canBlow = c.humanCanAct && c.state.turn == Role.wind;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DandelionCompass(
              size: size,
              usedMask: c.state.usedWinds,
              enabled: canBlow,
              windsLeft: c.state.windsLeft,
              onBlow: (d) {
                if (!c.blow(d) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(height: 2),
            Text(
              canBlow ? '화살표를 눌러 바람을 불어요' : '바람은 방향마다 한 번씩',
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        );
      },
    );
  }

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _board()),
          _compass(),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _board()),
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _playerChips(),
                  _statusBanner(),
                  const SizedBox(height: 8),
                  _compass(size: 190),
                  const SizedBox(height: 8),
                  _bottomBar(),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Flexible(
            child: Text(
              '민들레',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openDandelionLesson(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'dandelion'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDandelionRules(context),
          ),
        ],
      ),
    );
  }

  /// 민들레 / 바람 두 칩: 지금 차례인 쪽이 강조된다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(Role role) {
          final active = !c.isOver && c.state.turn == role;
          final who = c.vsCpu ? (role == c.humanRole ? ' · 나' : ' · CPU') : '';
          final color = roleColor(role);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active ? 1 : 0.3), width: active ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 24, height: 24, child: CustomPaint(painter: _RoleIconPainter(role))),
                const SizedBox(width: 8),
                Text('${role.label}$who', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [chip(Role.dandelion), chip(Role.wind)],
          ),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final color = c.isOver ? Colors.grey : roleColor(c.state.turn);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        // 좁은 화면(폰·옆 칸)에서는 단추가 다음 줄로 넘어간다
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              style: compact,
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text('되돌리기'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: () => c.restart(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('새 판'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: c.canResign ? _resign : null,
              icon: const Icon(Icons.flag_outlined, size: 20),
              label: const Text('기권'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 역할을 나타내는 작은 그림 (민들레 = 꽃, 바람 = 휘날리는 선).
class _RoleIconPainter extends CustomPainter {
  const _RoleIconPainter(this.role);

  final Role role;

  @override
  void paint(Canvas canvas, Size size) => paintRoleIcon(canvas, size, role);

  @override
  bool shouldRepaint(_RoleIconPainter old) => old.role != role;
}

/// 민들레는 꽃, 바람은 바람 줄무늬 두 줄.
void paintRoleIcon(Canvas canvas, Size size, Role role) {
  if (role == Role.dandelion) {
    drawFlower(canvas, size.center(Offset.zero), size.width * 0.5);
    return;
  }
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = size.width * 0.11
    ..color = kWindColor;
  final w = size.width, h = size.height;
  for (final (y, len) in [(0.3, 0.85), (0.52, 0.7), (0.74, 0.55)]) {
    final path = Path()
      ..moveTo(w * 0.08, h * y)
      ..quadraticBezierTo(w * len * 0.55, h * (y - 0.14), w * len, h * y);
    canvas.drawPath(path, p);
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.controller});

  final DandelionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final w = c.winner!;
    final left = c.state.emptyCount;
    String title, body;
    if (c.vsCpu) {
      final me = w == c.humanRole;
      title = me ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      body = w == Role.dandelion
          ? (me ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '초원이 꽃과 씨앗으로 가득 찼어요. 다음엔 바람을 잘 골라 봐요!')
          : (me ? '빈칸이 $left칸 남았어요. 바람이 이겼어요!' : '빈칸이 $left칸 남았어요. 다음엔 꽃을 더 잘 심어 봐요!');
    } else {
      title = '${w.label} 승리! 🎉';
      body = w == Role.dandelion ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '빈칸이 $left칸 남았어요!';
    }
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 72, height: 72, child: CustomPaint(painter: _RoleIconPainter(w))),
          const SizedBox(height: 12),
          Text('$body\n(${c.moveCount}수)', textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('메뉴로')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('한 판 더')),
      ],
    );
  }
}

/// 규칙 설명.
Future<void> showDandelionRules(BuildContext context) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('민들레 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('민들레는 5×5 초원 전체를 꽃과 씨앗으로 덮는 게 목표예요.'),
            line('바람은 한 칸이라도 덮이지 않게 하는 게 목표예요.'),
            line('민들레가 먼저 아무 칸에나 꽃을 심어요.'),
            line('그다음 바람이 방향을 하나 골라요. 그 방향으로 모든 꽃에서 씨앗이 날아가, 길에 있는 빈칸을 채워요.'),
            line('바람은 8방향 가운데 7방향만 불 수 있고, 같은 방향은 한 번뿐이에요.'),
            line('이어서 민들레가 또 꽃을 심어요. 빈칸이나 씨앗이 있는 칸에 심을 수 있어요.'),
            line('씨앗은 꽃에서만 날아가고, 씨앗에서는 날아가지 않아요.'),
            line('일곱 번째 바람이 지난 뒤 초원이 가득 차 있으면 민들레, 빈칸이 하나라도 있으면 바람의 승리예요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            dandelionTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
