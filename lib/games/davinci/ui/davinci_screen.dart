import '../../../core/turn_glow.dart';
import '../../../core/win_celebration.dart';
import '../../../core/game_speed.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/tablet_scale.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin.dart';
import '../../../net/lan_rejoin_flow.dart';
import '../core/davinci_ai.dart';
import '../core/davinci_rules.dart';
import '../data/davinci_history.dart';
import '../game/davinci_controller.dart';
import '../tutorial/davinci_tutorial.dart';
import 'davinci_tiles.dart';
import '../../../versus/vs_screen_parts.dart';

part 'davinci_screen_fly.dart';
part 'davinci_screen_flow.dart';
part 'davinci_screen_board.dart';
part 'davinci_screen_actions.dart';
part 'davinci_screen_extras.dart';

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
    this.cpuSeats,
    this.rejoinDesk,
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

  /// 같은 Wi‑Fi 방에서 CPU가 앉은 자리들 (사람 n명 + CPU m명으로 할 때). CPU의 수는 방장 기기가 정해서 알려 준다.
  final List<int>? cpuSeats;

  /// 방장일 때: 판이 시작된 뒤에도 방 문을 열어 두고 나갔던 손님을 다시 받아 주는 접수처. 없으면 나간 손님을 기다리기만 한다.
  final LanRejoinDesk? rejoinDesk;

  /// (테스트용) 미리 만든 컨트롤러.
  final DavinciController? controller;

  @override
  State<DavinciScreen> createState() => _DavinciScreenState();
}

class _DavinciScreenState extends State<DavinciScreen> {
  /// 폰에서 3~4명이 함께 할 때 한 화면에 다 담기도록 간격과 타일을 줄이는가 (화면을 그릴 때마다 높이를 보고 정한다).
  bool _dense = false;

  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  late final DavinciController c = widget.controller ??
      DavinciController(
        mode: widget.mode,
        players: widget.players,
        humanSeat: widget.humanSeat,
        level: widget.level,
        seed: widget.seed,
        cpuSeats: widget.mode == PlayMode.wifi ? (widget.cpuSeats ?? const []) : null,
        cpuHost: widget.linkSeats != null, // (방을 연 기기가 CPU의 수를 정한다)
      );
  bool _resultHandled = false;

  /// CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  late final GameSaver _saver = GameSaver(gameId: 'davinci_code', snapshot: () => c.savable ? c.toJson() : null);
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

  /// 방장이 나간 손님의 자리를 돌본다 (CPU가 대신하기 · 돌아오면 되찾기). 방장 화면에서만 있다.
  LanHubKeeper? _keeper;
  bool _ticketDropped = false;

  /// 손님: 방장이 일부러 나간다고 알려 왔는가 (그러면 다시 들어갈 방이 없다).
  bool _hostLeft = false;

  /// 아직 보내지 않은 "조커 뽑기" 수 (자리를 정하면 다음 수와 함께 보낸다).
  Map<String, dynamic>? _heldMove;

  // ── 타일을 뽑아 오는 연출 (더미 → 뽑은 사람의 줄) ──

  final GlobalKey _stackKey = GlobalKey();
  final Map<int, GlobalKey> _pileKeys = {};
  final Map<int, GlobalKey> _tileKeys = {};
  final Map<int, GlobalKey> _rowKeys = {};

  _Fly? _fly;
  int _flySerial = 0;

  /// 날아오는 중이라 줄에서는 아직 안 보여야 하는 타일.
  int? _hiddenTile;

  /// 이미 날려 보낸 상대의 뽑기 연출 (같은 연출에 두 번 시작하지 않으려고).
  DvEffect? _flownEffect;


  /// 뽑은 조커가 자리를 정할 때까지 내 손패 한가운데 떠 있는 곳 (화면 스택 좌표).
  Offset? _hover;
  int? _hoverTile;


  /// "한 판 더"를 누른 자리들 (나 포함). 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'draw': const Fx(haptic: Haptic.select),
    // 추측이 맞았을 때 "번뜩" (내가 맞혀도, 컴퓨터·상대가 맞혀도)
    'right': const Fx(haptic: Haptic.medium, sound: 'sfx/idea.wav'),
    // 차례에 상대 타일을 눌러 숫자를 고민할 때 "흐음" (세 가지 중 하나, 내가 눌러도 CPU·상대가 눌러도)
    'think0': const Fx(sound: 'sfx/hmm1.wav', volume: 0.8),
    'think1': const Fx(sound: 'sfx/hmm2.wav', volume: 0.8),
    'think2': const Fx(sound: 'sfx/hmm3.wav', volume: 0.8),
    // 추측이 틀렸을 때 "삐-" (✕와 같은 순간)
    'wrong': const Fx(haptic: Haptic.vibrate, sound: 'sfx/beep.wav', volume: 0.7),
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
    final desk = widget.rejoinDesk;
    if (_hub && desk != null) {
      _keeper = LanHubKeeper(
        desk: desk,
        seatOfLink: _seatOfLink,
        isActive: () => !c.isOver && !c.halted,
        cover: c.coverSeat,
        uncover: c.uncoverSeat,
        snapshot: (_) => {...c.wifiSnapshot(), if (widget.names != null) 'names': widget.names},
        sendAll: _sendAll,
      );
    }
    if (links.isNotEmpty) {
      c.onLocalMove = (move) {
        final msg = {'t': 'move', 'i': c.moveCount - 1, 'mv': move};
        // 조커를 뽑은 수는 자리를 정할 때까지 보내지 않는다. (뽑자마자 상대 화면에 보이면 조커를 뽑은 걸 들킨다)
        if (move[0] == 0 && c.state.phase == DvPhase.placeJoker) {
          _heldMove = msg;
          return;
        }
        final held = _heldMove;
        _heldMove = null;
        if (held != null) _sendAll(held);
        _sendAll(msg);
      };
      // 맞히려고 상대 타일을 고르면(또는 고름을 풀면) 다른 기기에도 알려서, 무슨 숫자일까 고민하는 모습이 보이게 한다
      c.onLocalSelect = (seat, index) => _sendAll({'t': 'sel', 'a': c.humanSeat, 's': seat, 'n': index});
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
    _keeper?.dispose();
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
    c.onLocalSelect = null;
    c.dispose();
    super.dispose();
  }

  /// 이긴 소리를 이미 냈는가 (판이 끝난 뒤 마지막 ○ / ✕ 연출까지 다 보이면 한 번만 낸다).
  bool _winSounded = false;

  // ── 안내 글 ──



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (!c.online) {
          // CPU 대결: 나가기 전에 저장할지 묻는다
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

  // ── 타일 줄 ──



  // ── 지금 할 일 ──


}

/// 방장이 보낸 `resume`(나갔다 다시 들어올 때 받는 판의 모습)으로 다빈치 코드 화면을 만든다. 맞지 않는 내용이면 null.
Widget? davinciResume(Map<String, dynamic> resume, LanConnection conn) {
  final seat = resume['seat'], snap = resume['snap'];
  if (seat is! int || snap is! Map<String, dynamic>) return null;
  final c = DavinciControllerRejoin.fromWifiSnapshot(snap, humanSeat: seat);
  if (c == null) return null;
  final raw = snap['names'];
  final names = raw is List && raw.length == c.players ? [for (final n in raw) '$n'] : null;
  return DavinciScreen(mode: PlayMode.wifi, players: c.players, humanSeat: seat, names: names, controller: c, links: [conn]);
}
