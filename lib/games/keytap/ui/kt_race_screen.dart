import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/settings_scope.dart';
import '../../../core/win_celebration.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin.dart';
import '../../../net/lan_rejoin_flow.dart';
import '../../../versus/vs_screen_parts.dart' show showVsNotice;
import '../core/kt_run.dart';
import '../data/kt_history.dart';
import '../game/kt_race.dart';
import 'kt_board.dart';
import 'kt_hud.dart';
import 'kt_piano.dart';
import 'kt_scoreboard.dart';

part 'kt_race_screen_net.dart';

/// 같은 Wi‑Fi에서 이 게임이 쓰는 이름.
const String kKeytapLanGame = 'keytap';

/// 같은 Wi‑Fi 경주 화면. 방장 기기는 손님 연결 여럿([links] + [linkSeats])을, 손님 기기는 방장 연결 하나를 받는다.
class KtRaceScreen extends StatefulWidget {
  const KtRaceScreen({super.key, required this.race, required this.links, this.linkSeats, this.rejoinDesk, this.resumeAt});

  final KtRace race;
  final List<LanConnection> links;

  /// (방장) 손님 연결마다 앉은 자리.
  final List<int>? linkSeats;
  final LanRejoinDesk? rejoinDesk;

  /// (다시 들어온 손님) 판 시계가 이미 흐른 시간. 없으면 3-2-1부터 시작한다.
  final double? resumeAt;

  @override
  State<KtRaceScreen> createState() => _KtRaceScreenState();
}

class _KtRaceScreenState extends State<KtRaceScreen> with SingleTickerProviderStateMixin {
  KtRace get race => widget.race;
  KtRun get run => race.run;
  bool get _host => race.isHost;

  late final Ticker _ticker = createTicker(_onTick);
  final KtPiano _piano = KtPiano();
  final Map<int, double> _hitAt = {};
  final List<StreamSubscription<Map<String, dynamic>>> _subs = [];
  LanHubKeeper? _keeper;

  double _clock = 0;

  /// 판 시계 0이 되는 화면 시계 값 (그 전까지는 3-2-1).
  double? _zero;
  double _lastSent = -1;
  double _lastBoard = -1;
  int _sentHits = -1, _sentMisses = -1;
  bool _sentFinal = false;

  /// 블록이 다 내려온 화면 시계 값. 방장은 잠깐 더 기다려 손님들의 마지막 점수를 받는다.
  double? _endedAt;
  bool _resultShown = false;
  bool _leaving = false;

  /// 손님: 방장이 일부러 나갔다 (다시 들어갈 방이 없다).
  bool _hostLeft = false;
  bool _gone = false;

  double get _t => _zero == null ? 0 : _clock - _zero!;

  void _update(VoidCallback f) => setState(f);

  @override
  void initState() {
    super.initState();
    _initNet();
    _ticker.start();
  }

  @override
  void dispose() {
    _leaving = true;
    _ticker.dispose();
    _piano.dispose();
    _disposeNet();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _clock = elapsed.inMicroseconds / 1e6;
    if (_zero == null) {
      final r = widget.resumeAt;
      _zero = r != null ? _clock - r : _clock + 3;
    }
    if (_t >= 0 && !run.started) run.started = true;
    if (run.started && !race.ended) {
      race.tick(_t);
      if (race.ended) _endedAt = _clock;
    }
    _netTick();
    setState(() {});
  }

  void _onTap(int lane, double y) {
    if (race.ended || !run.started) return;
    final row = run.next;
    final r = run.tap(lane, y);
    if (r == KtTap.hit) {
      _hitAt[row] = _clock;
      _piano.note(context, run.note(row));
    } else if (r == KtTap.wrong) {
      _piano.wrong(context);
      if (SettingsScope.of(context).haptics) HapticFeedback.mediumImpact();
    }
  }

  /// 결과가 정해졌다: 기록을 남기고 결과 카드를 띄운다.
  void _showResult() {
    if (_resultShown) return;
    _resultShown = true;
    final ranks = race.ranks!;
    final rank = ranks[race.mySeat] + 1;
    KtHistory.add(KtRecord(kind: 'race', song: race.song.id, score: run.hits, rank: rank, players: race.players, at: DateTime.now()));
    if (rank == 1) {
      WinSound.play(context);
      showWinCelebration(context, title: '1등!');
    }
    _keeper?.settleIfEnded();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: race.ranks != null || _gone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1EADB),
        body: SafeArea(child: LayoutBuilder(builder: (context, box) => _body(box.maxWidth > box.maxHeight * 1.1))),
      ),
    );
  }

  Widget _body(bool wide) {
    final board = KtScoreboard(race: race, compact: !wide);
    return Column(
            children: [
              _topBar(),
              if (!wide) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: board),
              Expanded(
                child: KtBoardFrame(
                  side: wide ? board : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      KtBoard(run: run, hitAt: _hitAt, clock: _clock, onTap: _onTap, startLabel: null),
                      Align(alignment: const Alignment(0, -0.92), child: KtScoreText(score: run.hits, caption: '${min(run.lap + 1, 2)}/2바퀴')),
                      if (_t < 0.6) KtCountdown(left: -_t),
                      if (_host && race.ranks == null && _endedAt != null || !_host && race.ended && race.ranks == null)
                        const Align(alignment: Alignment(0, -0.3), child: KtBanner(text: '끝! 결과를 모으는 중…')),
                      if (race.ranks != null) _resultCard(),
                    ],
                  ),
                ),
              ),
            ],
          );
  }

  Widget _topBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(tooltip: '나가기', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Expanded(child: Text('${race.song.title} · 경주', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          if (run.started && run.t < run.stunUntil)
            const Padding(padding: EdgeInsets.only(right: 12), child: Text('잠깐 멈춤!', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE5484D)))),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final ranks = race.ranks!;
    final order = [for (var i = 0; i < race.players; i++) i]..sort((a, b) => ranks[a] - ranks[b]);
    final me = ranks[race.mySeat] + 1;
    return KtResultCard(
      title: me == 1 ? '1등이에요!' : '$me등이에요',
      body: [
        for (final s in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('${ranks[s] + 1}등', style: const TextStyle(fontWeight: FontWeight.w900))),
                Expanded(
                  child: Text('${race.names[s]}${s == race.mySeat ? ' (나)' : ''}',
                      style: TextStyle(fontWeight: s == race.mySeat ? FontWeight.w900 : FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                Text('${race.scores[s].hits}점', style: const TextStyle(fontWeight: FontWeight.w800, color: kKeytapColor)),
                SizedBox(width: 56, child: Text(' 틀림 ${race.scores[s].misses}', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        if (!_host && !_gone) const Padding(padding: EdgeInsets.only(top: 10), child: Text('방장이 "한 번 더"를 누르면 같이 시작해요', style: TextStyle(fontSize: 13))),
      ],
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('나가기')),
        if (_host) FilledButton(onPressed: _again, child: const Text('한 번 더')),
      ],
    );
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('경주에서 나갈까요?'),
        content: Text(_host ? '방장이 나가면 모두의 경주가 끝나요.' : '내 자리는 CPU가 이어서 쳐요. 홈 화면의 카드로 다시 들어올 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true && mounted) {
      _gone = true;
      Navigator.of(context).pop();
    }
  }
}
