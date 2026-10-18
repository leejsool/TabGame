import '../../../core/win_celebration.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../core/quoridor_ai.dart';
import '../data/quoridor_history.dart';
import '../game/quoridor_controller.dart';
import '../tutorial/quoridor_tutorial.dart';
import 'quoridor_board.dart';
import 'quoridor_wall_stock.dart';
import '../../../versus/vs_screen_parts.dart';

part 'quoridor_screen_flow.dart';
part 'quoridor_screen_board.dart';
part 'quoridor_screen_extras.dart';

/// 쿼리도 플레이 화면.
class QuoridorScreen extends StatefulWidget {
  const QuoridorScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.players = 2,
    this.humanSeat = 0,
    this.level = QLevel.normal,
    this.controller,
    this.link,
    this.links,
    this.linkSeats,
    this.names,
    this.cpuSeats,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (2 또는 4, CPU 포함).
  final int players;
  final int humanSeat;
  final QLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결 (2명 대결에서 하나뿐일 때). 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// 같은 Wi‑Fi 대결에서 이어진 연결들. 방을 만든 쪽(방장)은 손님마다 하나씩, 손님은 방장과의 연결 하나다.
  /// 4명이 할 때는 모든 수가 방장을 거쳐 오간다 (방장이 확인하고 다른 손님들에게 전해 준다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 대결에서 자리(0번부터)별 이름. 없으면 2명 대결은 상대의 별명을 쓴다.
  final List<String>? names;

  /// 같은 Wi‑Fi 방에서 CPU가 앉은 자리들 (사람 n명 + CPU m명으로 할 때). CPU의 수는 방장 기기가 정해서 알려 준다.
  final List<int>? cpuSeats;

  /// (테스트용) 미리 만든 컨트롤러.
  final QuoridorController? controller;

  @override
  State<QuoridorScreen> createState() => _QuoridorScreenState();
}

class _QuoridorScreenState extends State<QuoridorScreen> {
  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  late final QuoridorController c = widget.controller ??
      QuoridorController(
        mode: widget.mode,
        players: widget.players,
        humanSeat: widget.humanSeat,
        level: widget.level,
        cpuSeats: widget.mode == PlayMode.wifi ? (widget.cpuSeats ?? const []) : null,
        cpuHost: widget.linkSeats != null, // (방을 연 기기가 CPU의 수를 정한다)
      );
  bool _resultHandled = false;

  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  late final GameSaver _saver = GameSaver(gameId: 'quoridor', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAtMove = -1;

  // ── 같은 Wi‑Fi 대결 ──
  List<LanConnection> get _links => c.online ? (widget.links ?? [if (widget.link != null) widget.link!]) : const [];
  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];

  /// 방장인가 (그러면 손님이 보낸 수가 그 손님 차례의 수인지 확인하고, 손님이 여럿이면 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null;

  /// [link]번째 연결의 손님이 지금 앉은 자리 (한 판 더 할 때마다 자리가 한 칸씩 돈다).
  int _seatOfLink(int link) => (widget.linkSeats![link] + c.rotation) % c.players;

  bool _opponentGone = false;
  bool _leaving = false;

  /// "한 판 더"를 누른 자리들 (나 포함). 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};
  bool get _rematchAsked => _againSeats.contains(c.humanSeat);
  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'move': const Fx(haptic: Haptic.select),
    'wall': const Fx(haptic: Haptic.light),
    'bad': const Fx(haptic: Haptic.vibrate),
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
    final links = _links;
    if (links.isNotEmpty) {
      c.onLocalMove = (move) => _sendAll({'t': 'move', 'i': c.moveCount - 1, 'm': move});
      for (var i = 0; i < links.length; i++) {
        _linkSubs.add(links[i].messages.listen((m) => _onNet(i, m)));
        links[i].closed.then((_) => _onLinkClosed());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    _saver.detach();
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

  // ── 안내 글 ──



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (!c.online) {
          // 한 기기·CPU 대결: 나가기 전에 저장할지 묻는다
          return SaveLeaveGuard(active: () => _saver.active, onSave: _saver.save, onDiscard: _saver.discard, child: child!);
        }
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

}
