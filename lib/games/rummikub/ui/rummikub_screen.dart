import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../../../core/tablet_scale.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/rummikub_ai.dart';
import '../core/rummikub_rules.dart';
import '../data/rummikub_history.dart';
import '../game/rummikub_controller.dart';
import '../game/rummikub_layout.dart';
import '../tutorial/rummikub_tutorial.dart';
import 'rummikub_celebration.dart';
import 'rummikub_tiles.dart';
import '../../../versus/vs_screen_parts.dart';

part 'rummikub_screen_net.dart';
part 'rummikub_screen_flow.dart';
part 'rummikub_screen_layout.dart';
part 'rummikub_screen_fly.dart';
part 'rummikub_screen_table.dart';
part 'rummikub_screen_hand.dart';
part 'rummikub_screen_extras.dart';

/// 루미큐브 플레이 화면.
///
/// 내 손은 이 기기에만 보이고, 상대(CPU 또는 같은 Wi‑Fi의 사람)의 패는 몇 장인지만 보인다.
class RummikubScreen extends StatefulWidget {
  const RummikubScreen({
    super.key,
    this.mode = PlayMode.vsCpu,
    this.players = 2,
    this.humanSeat = 0,
    this.level = RkLevel.normal,
    this.seed,
    this.controller,
    this.link,
    this.links,
    this.linkSeats,
    this.names,
    this.cpuSeats,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (CPU 포함, 같은 Wi‑Fi 대결은 2~4명).
  final int players;
  final int humanSeat;
  final RkLevel level;

  /// 패를 나눌 씨앗 (같은 Wi‑Fi 대결에서는 두 기기가 같은 값으로 시작한다).
  final int? seed;

  /// 같은 Wi‑Fi 대결에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// 같은 Wi‑Fi 대결에서 이어진 연결들. 방을 만든 쪽(방장)은 손님마다 하나씩, 손님은 방장과의 연결 하나다.
  /// 3명 이상이 할 때는 모든 수가 방장을 거쳐 오간다 (방장이 확인하고 다른 손님들에게 전해 준다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 대결에서 자리(0번부터)별 이름. 없으면 2명 대결은 상대의 별명을 쓴다.
  final List<String>? names;

  /// 같은 Wi‑Fi 방에서 CPU가 앉은 자리들 (사람 n명 + CPU m명으로 할 때). CPU의 수는 방장 기기가 정해서 알려 준다.
  final List<int>? cpuSeats;

  /// (테스트용) 미리 만든 컨트롤러.
  final RummikubController? controller;

  /// 처음 내 차례에 "처음 내려놓을 때" 팝업을 띄우는가 (시험에서는 끈다).
  static bool showFirstHint = true;

  /// 타일 소리를 내는가 (시험에서는 끈다). 설정의 "효과음"이 꺼져 있으면 이게 켜져 있어도 소리가 나지 않는다.
  static bool playSounds = true;

  @override
  State<RummikubScreen> createState() => _RummikubScreenState();
}

/// 화면 바깥 좌우 여백 (가능한 한 좁게).
const double _edge = 1;
const double _tablePad = 1;

class _RummikubScreenState extends State<RummikubScreen> {
  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  late final RummikubController c = widget.controller ??
      RummikubController(
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
  late final GameSaver _saver = GameSaver(gameId: 'rummikub', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAtMove = -1;

  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];
  bool _opponentGone = false;
  bool _leaving = false;



  /// "한 판 더"를 누른 자리들 (나 포함). 사람이 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};


  /// 타일 소리 (패를 뽑거나, 놓거나, 옮길 때의 "딸깍"). 시험에서는 끈다 ([RummikubScreen.playSounds]).
  static String? get _tileSound => RummikubScreen.playSounds ? 'rummikub/tile.wav' : null;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  /// 소리: 패를 뽑거나(draw) 놓거나 옮길 때(place), 상대가 패를 옮길 때(step) "딸깍".
  final GameFx _fx = GameFx({
    'turn': const Fx(haptic: Haptic.medium),
    'place': Fx(haptic: Haptic.select, sound: _tileSound),
    'draw': Fx(haptic: Haptic.light, sound: _tileSound),
    'step': Fx(sound: _tileSound),
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
      c.onLocalMove = (move) => _sendAll({'t': 'move', ...move});
      c.onLocalLive = (live) => _sendAll({'t': 'live', ...live}); // (판을 만질 때마다 상대 화면에 실시간으로 보인다)
      c.onDesync = _desync;
      for (var i = 0; i < links.length; i++) {
        final from = i;
        _linkSubs.add(links[i].messages.listen((m) => _onNet(from, m)));
        links[i].closed.then((_) => _onLinkClosed());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.start();
      _maybeFirstHint();
    });
  }

  @override
  void dispose() {
    _fx.dispose();
    _saver.detach();
    _turnTimer?.cancel();
    _hoverTarget.dispose();
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
    c.onLocalLive = null;
    c.onDesync = null;
    c.dispose();
    super.dispose();
  }

  bool _hintShown = false;


  // ── 내 차례 알림 ──

  bool _prevCanAct = false;
  bool _turnBanner = false;
  Timer? _turnTimer;

  // ── 승리 축하 ──

  bool _celebrate = false;




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




  // ── 타일이 날아가는 연출 (바닥 → 손, 바닥 → 상대) ──

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _rackAreaKey = GlobalKey();
  final Map<int, GlobalKey> _tileKeys = {};
  final Map<int, GlobalKey> _floorKeys = {};
  final Map<int, GlobalKey> _chipKeys = {};

  /// 날아가는 중인 뒷면 타일 (없으면 null)과 연출 번호.
  _Fly? _fly;
  int _flySerial = 0;

  /// 내가 뽑아서 아직 날아오는 중인 타일 (손에서는 숨겨 둔다).
  int? _hiddenTile;

  /// 상대가 뽑는 타일에 대해 이미 날려 보낸 번호 (같은 타일에 연출을 두 번 시작하지 않으려고).
  int? _flownPick;

  /// 끌고 있는 타일들이 지금 놓이면 붙게 될 묶음 (없으면 null). 놓기 전에 미리 강조해서 보여 준다.
  /// (값만 바뀌어도 화면 전체가 아니라 묶음 테두리만 다시 그려지도록 알림 통로로 둔다)
  final ValueNotifier<List<int>?> _hoverTarget = ValueNotifier(null);

  // ── 끌기와 타일 ──

  /// 묶음 통째로 끌고 있는 동안 그 묶음의 타일들 (흐리게 보인다).
  Set<int> _setDrag = {};

  // ── 녹색 판 ──


  final GlobalKey _canvasKey = GlobalKey();


  // ── 바닥에 깔린 더미 ──




  // ── 내 손 + 단추 ──


  /// 손 타일을 늘어놓는 계획: 가로로 딱 붙여 한 줄, 한 줄이 넘치면 [maxRows]줄까지, 그래도 넘치면 그 줄 안에서 겹쳐 놓는다.
  /// 타일이 한 줄에 들어갈 만큼 줄면 저절로 한 줄로 줄어들어 자리를 녹색 판에 내준다.
  ({int rows, int perRow, double step}) _rackPlan(int n, double innerW, double tw, int maxRows) {
    final fit = max(1, (innerW / tw).floor());
    if (n <= fit) return (rows: 1, perRow: max(1, n), step: tw);
    if (n <= fit * maxRows) return (rows: (n / fit).ceil(), perRow: fit, step: tw);
    final perRow = (n / maxRows).ceil();
    return (rows: maxRows, perRow: perRow, step: perRow <= 1 ? tw : (innerW - tw) / (perRow - 1));
  }

}
