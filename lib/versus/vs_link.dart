import 'dart:async';

import 'package:flutter/material.dart';

import '../core/leave_guard.dart';
import '../net/lan_connection.dart';
import '../net/lan_rejoin.dart';
import '../net/lan_rejoin_flow.dart';
import 'vs_screen_parts.dart';

/// 두 사람이 겨루는 대결 화면(같은 기기 / CPU / 같은 Wi‑Fi)의 공통 동작.
///
/// - 같은 Wi‑Fi: 상대 기기와의 연결, 상대가 나감·판이 어긋남 안내, "한 판 더"(서로 눌러야 시작), 나가기 전에 묻기.
/// - 같은 기기·CPU: 이어하기용 보관([GameSaver]), 나가기 전에 저장할지 묻기, "새 판" 전에 묻기.
///
/// 게임 화면은 [vsLink]·[vsOnline]·[vsOver]·[vsHalted]·[vsMoveCount]와 "한 판 더"로 새 판을 여는 [vsRestartForRematch]만 알려 주고,
/// 받은 메시지 중 게임만 아는 것(수 등)은 [vsOnMessage]에서 처리한다.
///
/// 같은 Wi‑Fi 판에서 상대가 나가면(앱을 껐거나 Wi‑Fi가 끊겼거나) 방장은 바로 끝내지 않고 기다리다가, 한참 지나면 "CPU가 대신하기"를 고를 수 있다.
/// 상대는 돌아오면 (앱을 껐다 켰어도) 하던 판의 자리로 바로 다시 들어온다. 이를 위해 게임 화면은 [vsLanGame]·[vsSnapshot]·[vsCoverOpponent]·
/// [vsUncoverOpponent] (방장) 와 [vsResumeBuilder] (손님)를 알려 준다. **새 2인용 대결 게임도 반드시 이것들을 채운다.**
mixin VsTwoPlayer<T extends StatefulWidget> on State<T> {
  // ── 게임이 알려 주는 것 ──
  LanConnection? get vsLink;
  bool get vsOnline;
  bool get vsOver;
  bool get vsHalted;
  int get vsMoveCount;

  /// 이어하기 보관 도우미 (게임 id와 저장할 모습).
  GameSaver get vsSaver;

  /// 두 기기 모두 "한 판 더"를 눌렀다: 새 판을 연다 (보통 먼저 하는 쪽을 바꿔서).
  void vsRestartForRematch();

  /// 'resign' · 'again' · 'bye' 말고 받은 메시지 (예: 수). 처리했으면 true, 모르는 메시지면 false.
  bool vsOnMessage(Map<String, dynamic> m);

  /// 상대가 기권했다 (게임이 기록·안내를 한다).
  Future<void> vsOnOpponentResigned();

  // ── 다시 들어오기 (같은 Wi‑Fi) ──

  /// 같은 Wi‑Fi에서 이 게임의 이름 (방 찾기·다시 들어오기 표에 적힌 값). null이면 다시 들어오기를 지원하지 않는다.
  String? get vsLanGame => null;

  /// 방장 화면이 받은 "다시 들어오기 접수처" (손님 화면이면 null).
  LanRejoinDesk? get vsRejoinDesk => null;

  /// 방장: 나간 상대 자리를 CPU가 대신 맡는다 / 돌아온 상대에게 돌려준다.
  /// (컨트롤러에서 CPU가 상대 쪽을 두게 하고, 돌려줄 때는 생각 중이던 CPU의 수를 버린다)
  void vsCoverOpponent() {}
  void vsUncoverOpponent() {}

  /// 방장: 돌아오는 상대에게 보낼 판의 모습 (이 판을 상대 쪽에서 되살리는 데 필요한 모든 것). 판이 없으면 null.
  Map<String, dynamic>? vsSnapshot() => null;

  /// 손님: 연결이 끊겼다가 다시 들어갈 때, 방장이 보낸 `resume`으로 이 게임 화면을 만든다 (맞지 않으면 null).
  Widget? Function(Map<String, dynamic> resume, LanConnection conn)? get vsResumeBuilder => null;

  // ── 공통 상태 ──
  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool opponentGone = false;
  bool leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다.
  bool rematchAsked = false;
  bool rematchOffered = false;

  StreamSubscription<Map<String, dynamic>>? _vsSub;
  int _savedAtMove = -1;

  /// 방장이 나간 상대의 자리를 돌본다 (CPU가 대신하기 · 돌아오면 되찾기). 방장 화면에서만 있다.
  LanHubKeeper? _vsKeeper;
  bool _vsTicketDropped = false;

  /// 손님: 방장이 일부러 나간다고 알려 왔는가 (그러면 다시 들어갈 방이 없다).
  bool _vsHostLeft = false;

  /// 같은 Wi‑Fi 손님 화면인가 (다시 들어오기를 지원하는 게임에서, 방장이 아닌 쪽).
  bool get _vsIsGuest => vsOnline && vsLanGame != null && vsRejoinDesk == null && vsLink != null;

  /// initState에서: 보관을 시작하거나 상대 기기와 이어 둔다.
  void vsAttach() {
    if (!vsOnline) {
      _savedAtMove = vsMoveCount;
      vsSaver.attach();
    }
    final link = vsLink;
    if (link != null) {
      final desk = vsRejoinDesk;
      if (desk != null && vsLanGame != null && vsSnapshot() != null) {
        _vsKeeper = LanHubKeeper(
          desk: desk,
          seatOfLink: (_) => 1,
          isActive: () => !vsOver && !vsHalted,
          cover: (_) => vsCoverOpponent(),
          uncover: (_) => vsUncoverOpponent(),
          snapshot: (_) => vsSnapshot() ?? const {},
          sendAll: (m, {except}) {},
        );
      }
      _vsSub = link.messages.listen(_vsOnNet);
      link.closed.then((_) => vsOnLinkClosed());
    }
  }

  /// dispose에서: 보관을 멈추고, 상대에게 나간다고 알리고 연결을 닫는다.
  void vsDetach() {
    vsSaver.detach();
    leaving = true;
    _vsKeeper?.dispose();
    _vsSub?.cancel();
    final link = vsLink;
    if (link != null) {
      link.send(const {'t': 'bye'});
      link.close();
    }
  }

  void _vsOnNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'resign':
        vsOnOpponentResigned();
      case 'again':
        setState(() => rematchOffered = true);
        if (rematchAsked) _startRematch();
      case 'bye':
        // 방장은 나간 상대를 바로 내보내지 않고 기다린다 (CPU가 대신하거나, 돌아오면 이어 간다)
        if (_vsKeeper != null && !vsOver && !vsHalted && (vsLink?.suspend() ?? false)) return;
        if (_vsIsGuest) _vsHostLeft = true; // 방장이 일부러 나갔다: 다시 들어갈 방이 없다
        vsOnLinkClosed();
      default:
        if (!vsOnMessage(m)) vsDesync();
    }
  }

  /// 판이 서로 어긋났다 (있을 수 없는 일이지만, 어긋난 채로 계속하지는 않는다).
  Future<void> vsDesync() async {
    if (opponentGone || leaving) return;
    opponentGone = true;
    await vsLink?.close();
    if (!mounted) return;
    await showVsNotice(context, '판이 서로 어긋났어요', '두 기기의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void vsOnLinkClosed() {
    if (!mounted || leaving || opponentGone) return;
    setState(() => opponentGone = true);
    if (vsOver || vsHalted) return; // 끝난 판이면 결과를 마저 볼 수 있게 두고, "한 판 더"만 막는다
    Future<void> notice() => showVsNotice(context, '상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.');
    final game = vsLanGame, build = vsResumeBuilder;
    if (_vsIsGuest && !_vsHostLeft && game != null && build != null) {
      // 손님: 방이 아직 열려 있으면 하던 판으로 다시 들어갈 수 있다
      lanGuestDropped(context, game: game, build: build, fallbackNotice: notice);
      return;
    }
    if (_vsHostLeft && game != null) RejoinTickets.forget(game);
    notice().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// "한 판 더": 상대도 하자고 했으면 바로 시작하고, 아니면 상대를 기다린다.
  void requestRematch() {
    if (rematchAsked || opponentGone) return;
    setState(() => rematchAsked = true);
    vsLink?.send(const {'t': 'again'});
    if (rematchOffered) _startRematch();
  }

  void _startRematch() {
    setState(() {
      rematchAsked = false;
      rematchOffered = false;
    });
    vsRestartForRematch();
  }

  /// 판이 바뀔 때마다 (컨트롤러 알림에서) 부른다: 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void vsAutosave() {
    if (vsOnline && (vsOver || vsHalted)) {
      _vsKeeper?.settleIfEnded(); // (나가 있는 상대의 안내 카드가 남지 않게)
      final game = vsLanGame;
      if (_vsIsGuest && game != null && !_vsTicketDropped) {
        _vsTicketDropped = true;
        RejoinTickets.forget(game); // 끝난 판에는 다시 들어갈 수 없다
      }
    }
    if (vsOnline) return;
    if (vsMoveCount == 0 && !vsOver) vsSaver.rearm(); // 새 판이 시작됐다
    if (vsOver || vsHalted) {
      vsSaver.finish();
    } else if (vsMoveCount != _savedAtMove) {
      _savedAtMove = vsMoveCount;
      vsSaver.save();
    }
  }

  /// 하던 판 도중에 "새 판"을 눌렀다: 하던 판이 사라지니 먼저 묻는다. 새로 시작해도 되면 true.
  Future<bool> vsConfirmNewGame() async {
    if (vsSaver.active && !await confirmNewGame(context)) return false;
    return mounted;
  }

  /// 화면 전체를 감싼다: 같은 기기·CPU면 나갈 때 저장할지, 진행 중인 Wi‑Fi 판이면 나갈지 묻는다.
  Widget vsLeaveGuard(Widget child) {
    if (!vsOnline) {
      return SaveLeaveGuard(active: () => vsSaver.active, onSave: vsSaver.save, onDiscard: vsSaver.discard, child: child);
    }
    final ask = !vsOver && !vsHalted && !opponentGone;
    return PopScope(
      canPop: !ask,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await confirmVsLeave(context) && mounted) {
          final game = vsLanGame;
          if (_vsIsGuest && game != null) RejoinTickets.forget(game); // 일부러 나간 것이니 "다시 들어가기"를 남기지 않는다
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
