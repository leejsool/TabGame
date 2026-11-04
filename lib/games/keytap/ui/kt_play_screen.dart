import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/settings_scope.dart';
import '../../../core/win_celebration.dart';
import '../../../core/win_sound.dart';
import '../core/kt_run.dart';
import '../core/kt_songs.dart';
import '../data/kt_history.dart';
import 'kt_board.dart';
import 'kt_hud.dart';
import 'kt_piano.dart';

/// 혼자 하기 한 판 (곡 완주 또는 무한). 맨 아래 "시작" 블록을 누르면 내려오기 시작한다.
class KtPlayScreen extends StatefulWidget {
  const KtPlayScreen({super.key, this.song, this.seed});

  /// null이면 무한 모드.
  final KtSong? song;

  /// (시험용) 블록 배치 씨앗.
  final int? seed;

  @override
  State<KtPlayScreen> createState() => _KtPlayScreenState();
}

class _KtPlayScreenState extends State<KtPlayScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late KtRun _run;
  late final Ticker _ticker = createTicker(_onTick);
  final KtPiano _piano = KtPiano();
  final Map<int, double> _hitAt = {};

  /// 화면 시계 (초, 티커가 돈 시간).
  double _clock = 0;

  /// 판 시계가 0이던 화면 시계 값. 멈춰 있던 시간만큼 뒤로 민다.
  double _base = 0;
  double? _pausedAt;

  /// 다시 시작하기 전 3-2-1이 끝나는 화면 시계 값.
  double? _countdownEnd;

  String? _banner;
  double _bannerUntil = 0;
  int _lap = 0;

  bool _recorded = false;
  bool _newBest = false;
  bool _showResult = false;

  bool get _endless => widget.song == null;

  /// (시험용) 지금 판.
  @visibleForTesting
  KtRun get debugRun => _run;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newRun();
    _ticker.start();
  }

  void _newRun() {
    final song = widget.song;
    _run = KtRun(kind: song == null ? KtKind.endless : KtKind.song, song: song, seed: widget.seed ?? Random().nextInt(1 << 30));
    _hitAt.clear();
    _lap = 0;
    _recorded = false;
    _newBest = false;
    _showResult = false;
    _pausedAt = null;
    _countdownEnd = null;
    _banner = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _piano.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  bool get _running => _run.started && !_run.done && _pausedAt == null && _countdownEnd == null;

  void _onTick(Duration elapsed) {
    _clock = elapsed.inMicroseconds / 1e6;
    final cd = _countdownEnd;
    if (cd != null && _clock >= cd) {
      _base += _clock - _pausedAt!;
      _pausedAt = null;
      _countdownEnd = null;
    }
    if (_running) {
      final wasOver = _run.over;
      _run.tick(_clock - _base);
      if (!wasOver && _run.over) _onFail();
      _checkLap();
    }
    if (_run.done && !_recorded) _finish();
    setState(() {});
  }

  void _checkLap() {
    if (_run.lap == _lap) return;
    _lap = _run.lap;
    _say(_endless ? '더 빨라져요!' : '${_lap + 1}바퀴째 · 더 빠르게!');
  }

  void _say(String text) {
    _banner = text;
    _bannerUntil = _clock + 1.4;
  }

  void _onTap(int lane, double y) {
    if (_run.done || _pausedAt != null || _countdownEnd != null) return;
    final row = _run.next;
    final wasStarted = _run.started;
    final r = _run.tap(lane, y);
    if (r == KtTap.hit) {
      if (!wasStarted) _base = _clock;
      _hitAt[row] = _clock;
      _piano.note(context, _run.note(row));
      _checkLap();
    } else if (r == KtTap.wrong) {
      _onFail();
    }
  }

  void _onFail() {
    _piano.wrong(context);
    if (SettingsScope.of(context).haptics) HapticFeedback.vibrate();
  }

  Future<void> _finish() async {
    _recorded = true;
    final record = KtRecord(kind: _endless ? 'endless' : 'song', song: widget.song?.id ?? '', score: _run.hits, stars: _run.stars, at: DateTime.now());
    if (_run.finished) {
      WinSound.play(context);
      showWinCelebration(context, title: '완주!', subtitle: '별 3개를 모두 모았어요');
    }
    final best = await KtHistory.add(record);
    // 틀린 칸을 잠깐 보여 준 뒤 결과를 띄운다
    await Future<void>.delayed(Duration(milliseconds: _run.finished ? 300 : 1100));
    if (!mounted) return;
    setState(() {
      _newBest = best;
      _showResult = true;
    });
  }

  void _pause() {
    if (!_running) return;
    setState(() => _pausedAt = _clock);
  }

  void _resume() {
    if (_pausedAt == null || _countdownEnd != null) return;
    setState(() => _countdownEnd = _clock + 3);
  }

  void _restart() => setState(_newRun);

  @override
  Widget build(BuildContext context) {
    final title = widget.song?.title ?? '무한 모드';
    return Scaffold(
      backgroundColor: const Color(0xFFF1EADB),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(title),
            Expanded(
              child: KtBoardFrame(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    KtBoard(run: _run, hitAt: _hitAt, clock: _clock, onTap: _onTap),
                    Align(alignment: const Alignment(0, -0.92), child: KtScoreText(score: _run.hits, caption: _caption())),
                    if (_banner != null && _clock < _bannerUntil) Align(alignment: const Alignment(0, -0.5), child: KtBanner(text: _banner!)),
                    if (_countdownEnd != null) KtCountdown(left: _countdownEnd! - _clock),
                    if (_pausedAt != null && _countdownEnd == null) _pausedCard(),
                    if (_showResult) _resultCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _caption() {
    if (!_run.started) return _endless ? '틀릴 때까지 계속!' : '3바퀴를 돌면 별 3개';
    if (_endless) return '속도 ${_run.speed.toStringAsFixed(1)}';
    return '${min(_lap + 1, 3)}바퀴째';
  }

  Widget _topBar(String title) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(tooltip: '나가기', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          if (!_endless && _run.started) Padding(padding: const EdgeInsets.only(right: 4), child: KtStars(stars: _run.stars, size: 22)),
          IconButton(tooltip: '잠깐 멈춤', icon: const Icon(Icons.pause_rounded), onPressed: _running ? _pause : null),
        ],
      ),
    );
  }

  Widget _pausedCard() {
    return KtResultCard(
      title: '잠깐 멈춤',
      body: [Text('지금 ${_run.hits}점', style: const TextStyle(fontSize: 16))],
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('나가기')),
        OutlinedButton(onPressed: _restart, child: const Text('처음부터')),
        FilledButton(onPressed: _resume, child: const Text('계속하기')),
      ],
    );
  }

  Widget _resultCard() {
    final song = widget.song;
    final String title;
    if (_run.finished) {
      title = '완주했어요!';
    } else if (song != null && _run.stars > 0) {
      title = '${_run.stars}바퀴 성공!';
    } else {
      title = _endless ? '끝!' : '아쉬워요!';
    }
    return KtResultCard(
      title: title,
      body: [
        if (song != null) KtStars(stars: _run.stars),
        const SizedBox(height: 8),
        Text('${_run.hits}점', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kKeytapColor)),
        if (_newBest) const Text('새 최고 기록!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFE08A00))),
        if (song != null && !_run.finished)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_run.stars == 0 ? '한 바퀴를 끝까지 치면 별 1개예요' : '바퀴를 더 돌면 별이 늘어요', style: const TextStyle(fontSize: 13.5)),
          ),
      ],
      actions: [
        OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('곡 고르기')),
        FilledButton(onPressed: _restart, child: const Text('다시 하기')),
      ],
    );
  }
}
