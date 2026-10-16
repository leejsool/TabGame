import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/davinci_ai.dart';
import '../core/davinci_rules.dart';
import '../data/davinci_history.dart';
import '../game/davinci_controller.dart';
import '../tutorial/davinci_tutorial.dart';
import 'davinci_tiles.dart';

/// 다빈치 코드 플레이 화면.
///
/// 내 타일은 모두 보이고, 남의 숨은 타일은 색만 보인다. 상대(CPU 또는 같은 Wi‑Fi의 사람)의 타일을 눌러 고른 뒤 숫자를 맞힌다.
class DavinciScreen extends StatefulWidget {
  const DavinciScreen({
    super.key,
    this.mode = PlayMode.vsCpu,
    this.players = 2,
    this.humanSeat = 0,
    this.level = DvLevel.normal,
    this.seed,
    this.controller,
    this.link,
    this.links,
    this.linkSeats,
    this.names,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (CPU 포함, 2~4).
  final int players;
  final int humanSeat;
  final DvLevel level;

  /// 패를 나눌 씨앗 (같은 Wi‑Fi 대결에서는 모든 기기가 같은 값으로 시작한다).
  final int? seed;

  /// 같은 Wi‑Fi 대결에서 상대 기기와의 연결 (2명 대결에서 하나뿐일 때). 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// 같은 Wi‑Fi 대결에서 이어진 연결들. 방을 만든 쪽(방장)은 손님마다 하나씩, 손님은 방장과의 연결 하나다.
  /// 3~4명이 할 때는 모든 수가 방장을 거쳐 오간다 (방장이 확인하고 다른 손님들에게 전해 준다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 대결에서 자리(0번부터)별 이름. 없으면 2명 대결은 상대의 별명을 쓴다.
  final List<String>? names;

  /// (테스트용) 미리 만든 컨트롤러.
  final DavinciController? controller;

  @override
  State<DavinciScreen> createState() => _DavinciScreenState();
}

class _DavinciScreenState extends State<DavinciScreen> {
  late final DavinciController c = widget.controller ??
      DavinciController(mode: widget.mode, players: widget.players, humanSeat: widget.humanSeat, level: widget.level, seed: widget.seed);
  bool _resultHandled = false;

  // ── 같은 Wi‑Fi 대결 ──
  List<LanConnection> get _links => c.online ? (widget.links ?? [if (widget.link != null) widget.link!]) : const [];
  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];

  /// 방장이고 손님이 여럿인가 (그러면 손님이 보낸 수를 확인해서 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null && _links.length > 1;

  bool _opponentGone = false;
  bool _leaving = false;

  /// "한 판 더"를 누른 자리들 (나 포함). 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};
  bool get _rematchAsked => _againSeats.contains(c.humanSeat);
  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    final links = _links;
    if (links.isNotEmpty) {
      c.onLocalMove = (move) => _sendAll({'t': 'move', 'i': c.moveCount - 1, 'mv': move});
      for (var i = 0; i < links.length; i++) {
        _linkSubs.add(links[i].messages.listen((m) => _onNet(i, m)));
        links[i].closed.then((_) => _onLinkClosed());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _leaving = true;
    for (final s in _linkSubs) {
      s.cancel();
    }
    for (final link in _links) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  void _sendAll(Map<String, dynamic> m, {int? except}) {
    final links = _links;
    for (var i = 0; i < links.length; i++) {
      if (i != except) links[i].send(m);
    }
  }

  void _onNet(int from, Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        final raw = m['mv'];
        final move = raw is List && raw.every((e) => e is int) ? raw.cast<int>() : null;
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || widget.linkSeats![from] == c.turn;
        if (move == null || !fromOk || !c.receiveMove(move, index: m['i'] as int?)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'resign':
        c.opponentResigned();
      case 'again':
        final seat = _hub ? widget.linkSeats![from] : (m['seat'] is int ? m['seat'] as int : (c.players == 2 ? 1 - c.humanSeat : null));
        if (seat == null || seat < 0 || seat >= c.players) return;
        setState(() => _againSeats.add(seat));
        if (_hub) _sendAll({'t': 'again', 'seat': seat}, except: from);
        _checkRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    for (final link in _links) {
      await link.close();
    }
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '기기들의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    setState(() => _opponentGone = true);
    if (c.isOver || c.halted) return;
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 누군가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
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

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  void _checkRematch() {
    if (_againSeats.length >= c.players) {
      setState(_againSeats.clear);
      _resultHandled = false;
      c.restart();
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('판에서 나갈까요?'),
        content: const Text('나가면 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'draw':
        HapticFeedback.selectionClick();
      case 'right':
        HapticFeedback.mediumImpact();
      case 'wrong':
        HapticFeedback.vibrate();
      case 'bad':
        HapticFeedback.vibrate();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> _record({required int winner, bool resigned = false}) {
    return DvHistory.add(DvRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      human: c.humanSeat,
      turns: c.state.turnCount,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner!);
    } else if (c.halted && !_resultHandled && c.resignWinner != null) {
      // 상대가 기권해서 끝났을 때 (내가 기권한 경우는 [_resign]이 기록한다)
      if (c.resignWinner == c.humanSeat) {
        _resultHandled = true;
        _record(winner: c.humanSeat, resigned: true);
      }
    } else if (!c.isOver && !c.halted) {
      _resultHandled = false;
    }
  }

  String _name(int seat) {
    if (seat == c.humanSeat) return '나';
    final given = widget.names;
    if (c.online && given != null && seat < given.length) return given[seat];
    if (c.online) return _links.isEmpty ? '상대' : _links.first.peerNick;
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final ok = await confirmGiveUp(context, detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '상대의 승리로 기록돼요.', retry: false, verb: '기권');
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _sendAll(const {'t': 'resign'});
    await _record(winner: c.resignWinner!, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.state.turnCount}차례' : '${c.state.turnCount}차례',
      againLabel: c.online ? '한 판 더' : '새 판',
      offerAgain: !_opponentGone,
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again && c.online) {
      _requestRematch();
    } else if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 글 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner!;
      return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
    }
    if (c.halted) {
      final w = c.resignWinner;
      return w == c.humanSeat ? '상대가 기권해서 이겼어요! 🎉' : '기권했어요';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (!c.humanCanAct) {
      return c.thinking && c.turn != c.humanSeat ? '${_name(s.turn)}이(가) 생각하는 중…' : '${_name(s.turn)} 차례';
    }
    return switch (s.phase) {
      DvPhase.draw => '내 차례 · 더미에서 타일을 한 장 뽑아요',
      DvPhase.placeJoker => '조커를 뽑았어요 · 내 줄에서 놓을 자리를 골라요',
      DvPhase.guess => c.selSeat < 0 ? '맞힐 상대 타일을 눌러 고르세요' : '고른 타일의 숫자를 골라요',
      DvPhase.decide => c.selSeat < 0 ? '맞혔어요! 계속 맞힐 타일을 고르거나, 멈춰요' : '고른 타일의 숫자를 골라요',
      DvPhase.reveal => '틀렸어요! 내 숨은 타일 하나를 눌러 공개해요',
    };
  }

  /// 가장 최근 맞히기를 한 줄로.
  String? get _lastEvent {
    final g = c.state.lastGuess;
    if (g == null || c.isOver) return null;
    final num = g.number == kJokerGuess ? '조커' : '${g.number}';
    final target = g.target == c.humanSeat ? '내' : '${_name(g.target)}의';
    return '${_name(g.guesser)}: $target ${g.index + 1}번째 타일을 "$num"(이)라고 추측 → ${g.correct ? '맞혔어요!' : '틀렸어요'}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        final askBeforeLeave = c.online && !c.isOver && !c.halted && !_opponentGone;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF1F262B), Color(0xFF171C20)] : const [Color(0xFFE7ECEF), Color(0xFFD3DBE0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListenableBuilder(
                      listenable: c,
                      builder: (context, _) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _statusBanner(),
                            const SizedBox(height: 8),
                            for (var seat = 0; seat < c.players; seat++)
                              if (seat != c.humanSeat) ...[_playerRow(seat), const SizedBox(height: 8)],
                            _actionPanel(),
                            const SizedBox(height: 8),
                            _playerRow(c.humanSeat),
                            const SizedBox(height: 8),
                            if (c.isOver) _resultPanel() else _bottomBar(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Flexible(
            child: Text('다빈치 코드', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: 'davinci_code')),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showDavinciRules(context)),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final color = c.isOver || c.halted ? Colors.grey : (c.turn == c.humanSeat ? kDavinciColor : const Color(0xFF6B7A85));
    final event = _lastEvent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          if (event != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(event, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            ),
        ],
      ),
    );
  }

  // ── 타일 줄 ──

  /// 한 사람의 타일 줄. 남의 줄은 숨은 타일이 색만 보이고, 내 줄은 전부 보인다.
  Widget _playerRow(int seat) {
    final s = c.state;
    final row = s.rows[seat];
    final me = seat == c.humanSeat;
    final active = !c.isOver && !c.halted && c.turn == seat;
    final out = s.isOut(seat);
    final scheme = Theme.of(context).colorScheme;
    final canPick = c.humanCanAct && !me && !out && (s.phase == DvPhase.guess || s.phase == DvPhase.decide);
    final placing = me && c.humanCanAct && s.phase == DvPhase.placeJoker;
    final revealing = me && c.humanCanAct && s.phase == DvPhase.reveal;
    final g = s.lastGuess;

    return LayoutBuilder(
      builder: (context, box) {
        final n = row.length + (placing ? 1 : 0);
        final tw = (me ? 44.0 : 38.0).clamp(20.0, (box.maxWidth - 34) / max(1, n) - 4);
        Widget slot(int pos) => GestureDetector(
              key: ValueKey('slot$pos'),
              behavior: HitTestBehavior.opaque,
              onTap: () => c.placeJoker(pos),
              child: Container(
                width: tw * 0.5,
                height: tw * 1.4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF5B8DEF), width: 1.6),
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF5B8DEF)),
              ),
            );
        final tiles = <Widget>[];
        for (var i = 0; i < row.length; i++) {
          if (placing) tiles.add(slot(i));
          final t = row[i];
          final revealed = s.isRevealed(t);
          final hit = g != null && g.target == seat && g.index == i;
          tiles.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DvTile(
              key: ValueKey('tile-$seat-$i'),
              id: t,
              width: tw,
              faceUp: me || revealed,
              revealed: revealed,
              selected: c.selSeat == seat && c.selIndex == i,
              mark: hit ? g.correct : null,
              fresh: me && s.drawn == t && !revealed && !s.isOver,
              onTap: canPick && !revealed
                  ? () => c.selectTarget(seat, i)
                  : (revealing && !revealed ? () => c.revealOwn(i) : null),
            ),
          ));
        }
        if (placing) tiles.add(slot(row.length));

        return Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: (active ? kDavinciColor : Colors.white).withValues(alpha: active ? 0.1 : 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? kDavinciColor : scheme.outlineVariant, width: active ? 2.2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(me ? Icons.person_rounded : (c.online ? Icons.wifi_rounded : Icons.smart_toy_rounded), size: 18, color: kDavinciColor),
                  const SizedBox(width: 5),
                  Text(_name(seat), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (out)
                    Text('탈락', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.error))
                  else if (active)
                    const Text('차례', style: TextStyle(fontWeight: FontWeight.w800, color: kDavinciColor)),
                  const Spacer(),
                  if (me) Text('숨은 타일 ${s.hiddenCount(seat)}장', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65))),
                ],
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: out ? 0.6 : 1,
                child: Wrap(runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: tiles),
              ),
              if (me)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('주황 밑줄 = 이미 모두에게 공개된 타일', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.55))),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 지금 할 일 ──

  Widget _actionPanel() {
    final s = c.state;
    if (c.isOver || c.halted || !c.humanCanAct) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Widget box(Widget child) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
          child: child,
        );

    switch (s.phase) {
      case DvPhase.draw:
        return box(Column(
          children: [
            const Text('어느 색 더미에서 뽑을까요?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final color in const [0, 1]) ...[
                  if (color == 1) const SizedBox(width: 24),
                  _pileButton(color),
                ],
              ],
            ),
          ],
        ));
      case DvPhase.placeJoker:
      case DvPhase.reveal:
        return const SizedBox.shrink(); // 내 줄에서 직접 고른다 (자리 칸 / 숨은 타일)
      case DvPhase.guess:
      case DvPhase.decide:
        final picking = c.selSeat >= 0;
        return box(Column(
          children: [
            if (picking) _numberPicker() else Text(s.phase == DvPhase.decide ? '계속 맞히려면 상대 타일을 고르고, 아니면 멈춰요' : '위에서 맞힐 상대 타일을 눌러요', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75))),
            if (s.phase == DvPhase.decide) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: c.stop,
                icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
                label: const Text('멈추기 (내 타일은 그대로 숨겨요)'),
                style: FilledButton.styleFrom(backgroundColor: kDavinciColor),
              ),
            ],
          ],
        ));
    }
  }

  Widget _pileButton(int color) {
    final count = c.state.poolOf(color);
    return GestureDetector(
      key: ValueKey('pile$color'),
      behavior: HitTestBehavior.opaque,
      onTap: count > 0 ? () => c.draw(color) : null,
      child: Opacity(
        opacity: count > 0 ? 1 : 0.45,
        child: Column(
          children: [
            DvPile(color: color, count: count),
            const SizedBox(height: 4),
            Text(color == 0 ? '검정 더미' : '흰색 더미', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  /// 고른 타일의 숫자를 고르는 판. 이미 보여서 그 색 타일일 수 없는 숫자는 흐리게 막는다.
  Widget _numberPicker() {
    final s = c.state;
    final tile = s.rows[c.selSeat][c.selIndex];
    final color = dvColor(tile);
    final seen = <int>{...s.revealed, ...s.rows[c.humanSeat]};
    final black = color == 0;
    return Column(
      children: [
        Text('${_name(c.selSeat)}의 ${c.selIndex + 1}번째 ${black ? '검정' : '흰색'} 타일은?', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 0; n <= kJokerGuess; n++)
              Builder(builder: (context) {
                final known = n == kJokerGuess ? seen.contains(24 + color) : seen.contains(dvTile(color, n));
                return SizedBox(
                  key: ValueKey('num$n'),
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: black ? const Color(0xFF2A2D32) : const Color(0xFFF6F1E4),
                      foregroundColor: black ? Colors.white : const Color(0xFF2A2D32),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
                      disabledForegroundColor: Colors.grey,
                      side: BorderSide(color: black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: known ? null : () => c.guess(n),
                    child: Text(n == kJokerGuess ? '‑' : '$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        if (c.selSeat >= 0 && c.humanCanAct)
          OutlinedButton.icon(style: compact, onPressed: c.clearSelection, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('고름 풀기')),
        if (c.vsCpu)
          OutlinedButton.icon(style: compact, onPressed: () {
            _resultHandled = false;
            c.restart();
          }, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('새 판')),
        if (c.vsCpu || c.players == 2)
          OutlinedButton.icon(style: compact, onPressed: c.canResign ? _resign : null, icon: const Icon(Icons.flag_outlined, size: 20), label: const Text('기권')),
      ],
    );
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2A900)),
              const SizedBox(width: 8),
              Text('${_name(s.winner!)} 승리 · ${s.turnCount}차례', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.online
                    ? (_rematchAsked || _opponentGone ? null : _requestRematch)
                    : () {
                        _resultHandled = false;
                        c.restart();
                      },
                child: Text(!c.online
                    ? '한 판 더'
                    : _opponentGone
                        ? '상대가 나갔어요'
                        : _rematchAsked
                            ? '상대를 기다려요…'
                            : _rematchOffered
                                ? '한 판 더 (상대가 원해요)'
                                : '한 판 더'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 규칙 설명.
Future<void> showDavinciRules(BuildContext context) {
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
      title: const Text('다빈치 코드 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('타일은 검정·흰색 0~11, 그리고 조커(‑) 두 장이에요. 각자 타일을 받아 숫자가 작은 쪽부터 왼쪽에서 오른쪽으로 늘어놓아요. 같은 숫자는 검정이 먼저예요.'),
            line('내 타일은 나만 볼 수 있고, 남의 타일은 색과 자리만 보여요.'),
            line('내 차례에 검정이나 흰색 더미에서 타일을 한 장 뽑아요 (순서에 맞는 자리에 저절로 끼워져요).'),
            line('그다음 상대의 숨은 타일 하나를 골라 숫자를 맞혀요.'),
            line('맞히면 그 타일이 공개돼요. 계속 맞히거나, 멈추고 차례를 넘길 수 있어요.'),
            line('틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어가요.'),
            line('조커는 뽑았을 때 내가 놓을 자리를 골라요. 맞힐 때는 "‑"를 골라요.'),
            line('숨은 타일이 모두 공개되면 탈락이에요. 마지막까지 남은 사람이 이겨요.'),
            line('더미가 다 떨어지면 뽑지 않고 바로 맞혀요. 이때 틀리면 내 숨은 타일 하나를 직접 공개해요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            davinciTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
