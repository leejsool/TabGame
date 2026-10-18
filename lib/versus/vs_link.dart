import 'dart:async';

import 'package:flutter/material.dart';

import '../core/leave_guard.dart';
import '../net/lan_connection.dart';
import 'vs_screen_parts.dart';

/// 두 사람이 겨루는 대결 화면(같은 기기 / CPU / 같은 Wi‑Fi)의 공통 동작.
///
/// - 같은 Wi‑Fi: 상대 기기와의 연결, 상대가 나감·판이 어긋남 안내, "한 판 더"(서로 눌러야 시작), 나가기 전에 묻기.
/// - 같은 기기·CPU: 이어하기용 보관([GameSaver]), 나가기 전에 저장할지 묻기, "새 판" 전에 묻기.
///
/// 게임 화면은 [vsLink]·[vsOnline]·[vsOver]·[vsHalted]·[vsMoveCount]와 "한 판 더"로 새 판을 여는 [vsRestartForRematch]만 알려 주고,
/// 받은 메시지 중 게임만 아는 것(수 등)은 [vsOnMessage]에서 처리한다.
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

  // ── 공통 상태 ──
  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool opponentGone = false;
  bool leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다.
  bool rematchAsked = false;
  bool rematchOffered = false;

  StreamSubscription<Map<String, dynamic>>? _vsSub;
  int _savedAtMove = -1;

  /// initState에서: 보관을 시작하거나 상대 기기와 이어 둔다.
  void vsAttach() {
    if (!vsOnline) {
      _savedAtMove = vsMoveCount;
      vsSaver.attach();
    }
    final link = vsLink;
    if (link != null) {
      _vsSub = link.messages.listen(_vsOnNet);
      link.closed.then((_) => vsOnLinkClosed());
    }
  }

  /// dispose에서: 보관을 멈추고, 상대에게 나간다고 알리고 연결을 닫는다.
  void vsDetach() {
    vsSaver.detach();
    leaving = true;
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
    showVsNotice(context, '상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
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
        if (!didPop && await confirmVsLeave(context) && mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
