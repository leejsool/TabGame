import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../tutorial/goblet_tutorial.dart';
import '../../../records/records_screen.dart';
import '../core/goblet_ai.dart';
import '../data/goblet_history.dart';
import '../core/goblet_rules.dart';
import '../game/goblet_controller.dart';
import 'goblet_piece.dart';
import 'goblet_stage.dart';

/// 고블렛 고블러스 플레이 화면.
class GobbletScreen extends StatefulWidget {
  const GobbletScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanTeam = Team.red,
    this.level = CpuLevel.normal,
    this.controller,
    this.link,
  });

  final PlayMode mode;
  final Team humanTeam;
  final CpuLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// (테스트용) 미리 만든 컨트롤러를 쓰고 싶을 때.
  final GobbletController? controller;

  @override
  State<GobbletScreen> createState() => _GobbletScreenState();
}

class _GobbletScreenState extends State<GobbletScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final GobbletController c = widget.controller ??
      GobbletController(
        mode: widget.mode,
        humanTeam: widget.humanTeam,
        level: widget.level,
      );
  bool _resultShown = false;

  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  late final GameSaver _saver = GameSaver(gameId: 'goblet_gobblers', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAtMove = -1;

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;

  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool _opponentGone = false;
  bool _leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다 (둘 다 하면 새로 시작한다).
  bool _rematchAsked = false;
  bool _rematchOffered = false;

  /// 말을 놓을 때 나는 "탁" 소리 (assets/goblet/clack.wav).

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  /// 소리: 말을 놓을 때 (내 수도, 상대·CPU의 수도) "탁".
  final GameFx _fx = GameFx({
    'pick': const Fx(haptic: Haptic.select),
    'drop': const Fx(haptic: Haptic.light, sound: 'goblet/clack.wav'),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    if (!c.online) {
      _savedAtMove = c.moveCount;
      _saver.attach();
    }
    final link = _link;
    if (link != null) {
      c.onLocalMove = (m) => link.send({'t': 'move', 'i': c.moveCount - 1, 'f': m.from, 'to': m.to, 's': m.size});
      _linkSub = link.messages.listen(_onNet);
      link.closed.then((_) => _onLinkClosed());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    _saver.detach();
    _leaving = true;
    _linkSub?.cancel();
    final link = _link;
    if (link != null) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (_saver.active && !await confirmNewGame(context)) return;
    if (!mounted) return;
    c.restart();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        final f = m['f'], to = m['to'], size = m['s'];
        if (f is! int || to is! int || size is! int || size < 1 || size > 3 || f < -1 || f > 8 || to < 0 || to > 8) {
          _desync();
          return;
        }
        final move = f < 0 ? GobbletMove.place(size, to) : GobbletMove.slide(f, to, size);
        if (!c.receiveMove(move, index: m['i'] as int?)) _desync();
      case 'resign':
        _onOpponentResigned();
      case 'again':
        setState(() => _rematchOffered = true);
        if (_rematchAsked) _startRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  /// 판이 서로 어긋났다 (있을 수 없는 일이지만, 어긋난 채로 계속하지는 않는다).
  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    await _link?.close();
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '두 기기의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    setState(() => _opponentGone = true);
    if (c.isOver) return; // 끝난 판이면 결과를 마저 볼 수 있게 두고, "한 판 더"만 막는다
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _notice(String title, String body) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.wifi_off_rounded, size: 32),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(body, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('나가기'))],
        ),
      );

  /// 상대가 기권했다: 내 승리로 끝나고 (기록은 [_onChanged]가 남긴다), 결과 창이 뜬다.
  void _onOpponentResigned() {
    if (c.isOver) return;
    c.opponentResigned();
  }

  /// "한 판 더": 상대도 하자고 했으면 바로 시작하고, 아니면 상대를 기다린다.
  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _rematchAsked = true);
    _link?.send(const {'t': 'again'});
    if (_rematchOffered) _startRematch();
  }

  void _startRematch() {
    setState(() {
      _rematchAsked = false;
      _rematchOffered = false;
    });
    _resultShown = false;
    c.restart(); // 먼저 시작하는 팀이 바뀐다 (두 기기가 똑같이)
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('판에서 나갈까요?'),
        content: const Text('나가면 상대와의 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  void _feedback(String kind) => _fx.play(context, kind);

  void _onChanged() {
    final r = c.result;
    if (r != null && !_resultShown) {
      _resultShown = true;
      if (!c.oneSeat || r.winner == c.humanTeam) WinSound.play(context); // 이겼을 때 "짜잔"
      // 한 판이 끝날 때마다 한 번만 기록한다
      GobbletHistory.add(GobbletRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: r.winner,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanTeam : null,
        byReveal: r.byReveal,
        resigned: r.resigned,
        online: c.online,
      ));
      Future<void>.delayed(const Duration(milliseconds: 1300), _showResult);
    } else if (r == null) {
      if (_resultShown) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultShown = false;
    }
    if (!c.online) _autosave();
  }

  /// 수를 둘 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void _autosave() {
    if (c.moveCount == 0 && !c.isOver) _saver.rearm(); // 새 판이 시작됐다
    if (c.isOver) {
      _saver.finish();
    } else if (c.moveCount != _savedAtMove) {
      _savedAtMove = c.moveCount;
      _saver.save();
    }
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final team = c.resigningTeam;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '${team.label}이 기권하고, ${team.other.label}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted) return;
    if (c.resign()) _link?.send(const {'t': 'resign'}); // 끝난 판으로 기록되고 결과 창이 뜬다
  }

  Future<void> _showResult() async {
    if (!mounted || c.result == null) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ResultDialog(controller: c),
    );
    if (!mounted) return;
    if (again == true) {
      if (c.online) {
        _requestRematch();
      } else {
        c.restart();
      }
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wi‑Fi 대결 도중에 나가려 하면 먼저 물어본다 (연결이 끊기니까).
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (!c.online) {
          // 한 기기·CPU 대결: 나가기 전에 저장할지 묻는다
          return SaveLeaveGuard(active: () => _saver.active, onSave: _saver.save, onDiscard: _saver.discard, child: child!);
        }
        final askBeforeLeave = c.online && !c.isOver && !_opponentGone;
        return PopScope(
          canPop: !askBeforeLeave,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: child!,
        );
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF1F2430), Color(0xFF181B24)]
                : const [Color(0xFFFFF3DC), Color(0xFFFFE6C9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(scheme),
              _statusBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: GobbletStage(controller: c),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '고블렛 고블러스',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'goblet_gobblers'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showGobbletRules(context),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final r = c.result;
        final String text;
        final Team? team;
        if (r != null) {
          if (r.kind == ResultKind.draw) {
            text = '무승부예요 (같은 모양이 3번 반복됐어요)';
            team = null;
          } else if (c.online && r.resigned) {
            text = r.winner == c.humanTeam ? '상대가 기권해서 이겼어요! 🎉' : '기권했어요';
            team = r.winner;
          } else if (c.online) {
            final me = r.winner == c.humanTeam;
            text = me ? '이겼어요! 🎉' : '졌어요';
            team = r.winner;
          } else {
            text = r.byReveal
                ? '${r.winner!.label} 승리! 말을 들어 올리자 줄이 드러났어요'
                : '${r.winner!.label} 승리!';
            team = r.winner;
          }
        } else if (c.thinking) {
          text = 'CPU가 생각하는 중…';
          team = c.turn;
        } else if (_opponentGone) {
          text = '상대와 연결이 끊겼어요';
          team = null;
        } else if (c.oneSeat && c.turn == c.humanTeam) {
          text = '내 차례예요. 말을 끌어다 칸에 놓아요';
          team = c.turn;
        } else if (c.online) {
          text = '상대가 두기를 기다리는 중이에요';
          team = c.turn;
        } else {
          text = '${c.turn.label} 차례예요';
          team = c.turn;
        }
        final pal = team == null ? null : TeamPalette.of(team);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (pal?.main ?? Colors.grey).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (pal?.main ?? Colors.grey).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (team != null)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: pal!.main, shape: BoxShape.circle),
                ),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        // 좁은 화면(폰·옆 칸)에서는 단추가 다음 줄로 넘어간다
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            // (Wi‑Fi 대결에는 되돌리기·새 판이 없다)
            if (!c.online) ...[
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canUndo ? c.undo : null,
                icon: const Icon(Icons.undo_rounded, size: 20),
                label: const Text('되돌리기'),
              ),
              OutlinedButton.icon(
                style: compact,
                onPressed: _newGameNow,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('새 판'),
              ),
            ],
            if (c.online && c.isOver)
              FilledButton.icon(
                onPressed: _rematchAsked || _opponentGone ? null : _requestRematch,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: Text(_opponentGone
                    ? '상대가 나갔어요'
                    : _rematchAsked
                        ? '상대를 기다려요…'
                        : _rematchOffered
                            ? '한 판 더 (상대가 원해요)'
                            : '한 판 더'),
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

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.controller});

  final GobbletController controller;

  @override
  Widget build(BuildContext context) {
    final r = controller.result!;
    final c = controller;
    String title;
    String body;
    Team? face;
    if (r.kind == ResultKind.draw) {
      title = '무승부';
      body = '같은 모양이 3번 나와서 비겼어요.';
    } else if (c.online) {
      final me = r.winner == c.humanTeam;
      title = r.resigned ? (me ? '상대가 기권했어요' : '기권했어요') : (me ? '이겼어요! 🎉' : '졌어요');
      body = r.resigned ? (me ? '내 승리로 기록해 두었어요.' : '상대의 승리로 기록해 두었어요.') : (me ? '${r.winner!.label} 승리!' : '다음엔 꼭 이겨 봐요!');
      face = r.winner;
    } else if (r.resigned) {
      // 기권: 진 쪽이 기권했다 (기록에도 남았다)
      title = c.vsCpu ? '기권했어요' : '${r.winner!.other.label}이 기권했어요';
      body = c.vsCpu ? '기록에 남겨 두었어요. 다음엔 끝까지 도전해 봐요!' : '${r.winner!.label}의 승리로 기록했어요.';
      face = r.winner;
    } else if (c.vsCpu) {
      final me = r.winner == c.humanTeam;
      title = me ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      body = me ? '${r.winner!.label} 승리!' : '다음엔 꼭 이겨 봐요!';
      face = r.winner;
    } else {
      title = '${r.winner!.label} 승리! 🎉';
      body = r.byReveal ? '말을 들어 올리는 바람에 상대 줄이 완성됐어요.' : '축하해요!';
      face = r.winner;
    }
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (face != null)
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: GobblerPainter(team: face, size: 3, mood: PieceMood.happy),
              ),
            ),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center),
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
Future<void> showGobbletRules(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('고블렛 고블러스 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RuleLine('가로·세로·대각선으로 내 말 3개가 "위에서 보이게" 나란히 놓이면 이겨요.'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final t in Team.values)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var s = 1; s <= 3; s++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: SizedBox(
                                width: 22.0 + s * 12,
                                height: 22.0 + s * 12,
                                child: CustomPaint(painter: GobblerPainter(team: t, size: s)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t == Team.red ? '빨강팀 (뾰족 귀)' : '파랑팀 (둥근 귀)',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const _RuleLine('말은 크기가 3가지(점 1·2·3개)이고, 크기마다 2개씩 있어요.'),
            const _RuleLine('큰 말은 작은 말을 덮을 수 있어요. 내 말도, 상대 말도요!'),
            const _RuleLine('덮인 말은 보이지 않고, 아래에 뭐가 깔렸는지 표시도 없어요. 무엇을 덮었는지 기억해 두세요!'),
            const _RuleLine('내 차례에 대기 중인 말을 올리거나, 판 위의 내 말(맨 위에 보이는 것)을 옮겨요.'),
            const _RuleLine('조심! 말을 들어 올렸을 때 상대 줄이 드러나면, 막지 못하는 한 상대가 이겨요.'),
            const _RuleLine('같은 모양이 3번 반복되면 무승부예요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            gobletTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}

class _RuleLine extends StatelessWidget {
  const _RuleLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
