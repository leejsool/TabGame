import 'dart:async';

import '../../../net/lan_connection.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_rejoin.dart';
import '../../../net/lan_screens.dart' show roomNumberOf;
import '../core/snake_body.dart';
import '../core/snake_net.dart';
import '../core/snake_world.dart';

/// 뱀 게임이 같은 Wi‑Fi에서 쓰는 게임 이름.
const String kSnakeLanGame = 'snake';

/// 방장 기기의 같은 Wi‑Fi 일: 판을 시작하면서 방 문을 열어 두고, 판 도중에 언제든 손님을 받는다.
///
/// 손님 자리는 들어온 순서대로 1, 2, … (방장은 0). 손님이 잠깐 멈추면 그 뱀은 CPU가 잠시 몰고,
/// 한참 응답이 없으면 [LanHubKeeper]로 자리를 CPU에게 맡긴다 (돌아오면 표로 같은 자리에 다시 앉는다).
/// 손님이 "나가기"를 누르면(`bye`) 그 뱀은 먹이로 흩어지고 자리가 없어진다.
///
/// 방장이 나가서 손님이 판을 이어받은 방이면 [predecessorRoom](옛 방 번호표)과 [migrants](옛 방에서 이어 오는 손님들의 자리)를 준다.
/// 그 손님들은 옛 표 대신 `migrate`(옛 방 번호표 + 자리)를 담아 들어오고, 같은 자리에 다시 앉는다.
/// [migrantWait] 안에 돌아오지 않은 자리는 비운다.
class SnakeHostNet {
  SnakeHostNet(
    this.world, {
    required this.hostNick,
    required this.cover,
    required this.uncover,
    this.onToast,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
    this.predecessorRoom,
    Set<int> migrants = const {},
    this.migrantWait = const Duration(seconds: 30),
  }) : _pending = {...migrants};

  final SnakeWorld world;
  final String hostNick;
  final void Function(int seat) cover, uncover;
  void Function(String text)? onToast;
  final int gamePort;
  final int? discoveryPort;
  final String? predecessorRoom;
  final Duration migrantWait;

  /// 아직 돌아오지 않은 이어받기 손님의 자리.
  final Set<int> _pending;
  Timer? _migrantTimer;

  /// [link]번째 손님이 앉은 자리.
  final List<int> _seats = [];

  LanRejoinDesk? _desk;
  LanHubKeeper? _keeper;
  final List<StreamSubscription<Map<String, dynamic>>> _subs = [];
  bool _closed = false;

  /// 마지막으로 보낸 변화의 번호.
  int seq = 0;
  double _sendTimer = 0, _stallTimer = 0;

  /// 같은 Wi‑Fi에서 이 기기를 가리키는 방 번호 (주소 끝 숫자). 방을 못 열었으면 null.
  String? roomNumber;

  /// 손님을 기다리는 포트 (방을 못 열었으면 null).
  int? port;

  bool get isOpen => _desk != null && !_closed;

  List<LanConnection> get links => _desk?.links ?? const [];

  /// 지금 이어져 있는 손님 수.
  int get guests => links.where((l) => !l.isClosed).length;

  /// 방을 연다. Wi‑Fi가 없거나 못 열면 혼자(CPU들과) 하는 판으로 그대로 한다.
  Future<void> open() async {
    try {
      final host = await LanHost.open(game: kSnakeLanGame, info: _info(), maxGuests: SnakeRules.maxHumans - 1, gamePort: gamePort, discoveryPort: discoveryPort);
      if (_closed) {
        await host.close();
        return;
      }
      port = host.port;
      final desk = LanRejoinDesk.open(host: host, guests: <LanConnection>[], info: _info());
      desk.onNewcomer = _newcomer;
      _desk = desk;
      _keeper = LanHubKeeper(
        desk: desk,
        seatOfLink: (link) => _seats[link],
        isActive: () => !_closed,
        cover: cover,
        uncover: uncover,
        snapshot: (_) => encodeFull(world, seq),
        sendAll: sendAll,
      );
      roomNumber = roomNumberOf(await localLanAddresses());
      if (_pending.isNotEmpty) _migrantTimer = Timer(migrantWait, _dropMissing);
    } catch (_) {
      // 방을 못 열어도 CPU들과는 그대로 논다
    }
  }

  Map<String, dynamic> _info() => {'open': true, 'nick': hostNick, 'people': 1 + guests, if (predecessorRoom != null) 'from': predecessorRoom};

  /// 옛 방에서 이어 오기로 했지만 끝내 안 돌아온 사람들의 자리를 비운다 (그 뱀은 먹이로 흩어진다).
  void _dropMissing() {
    if (_closed) return;
    for (final seat in _pending.toList()) {
      world.removeSeat(seat);
    }
    _pending.clear();
    _desk?.updateInfo(_info());
  }

  /// 새 손님이 앉을 자리: 비어 있는 가장 작은 번호 (방장 자리는 0이거나, 이어받은 방이면 그 손님의 자리).
  int _freeSeat() {
    var s = 1;
    while (world.seatNames.containsKey(s) || s == world.hostSeat) {
      s++;
    }
    return s;
  }

  bool _newcomer(LanConnection conn, Map<String, dynamic> hello) {
    final desk = _desk, keeper = _keeper;
    if (_closed || desk == null || keeper == null) return false;
    // 옛 방에서 이어 오는 손님: 같은 자리에 다시 앉힌다
    final migrate = hello['migrate'];
    final claimed = migrate is Map && predecessorRoom != null && migrate['room'] == predecessorRoom && migrate['seat'] is int && _pending.contains(migrate['seat'])
        ? migrate['seat'] as int
        : null;
    if (claimed == null && world.seatNames.length >= SnakeRules.maxHumans) return false;
    conn.peer = hello;
    final link = desk.addGuest(conn);
    keeper.watch(link);
    final seat = claimed ?? _freeSeat();
    _seats.add(seat);
    if (claimed != null) {
      _pending.remove(seat);
      uncover(seat);
    } else {
      world.addSeat(seat, conn.peerNick);
    }
    _listen(link);
    conn.send({'t': 'start', 'seat': seat, 'rejoin': desk.ticketFor(link), 'nick': hostNick, 'snap': encodeFull(world, seq)});
    if (claimed != null) {
      sendAll({'t': 'back', 'seat': seat}, except: link);
    } else {
      sendAll({'t': 'join', 'name': conn.peerNick, 'seat': seat}, except: link);
      onToast?.call('${conn.peerNick}님이 들어왔어요');
    }
    desk.updateInfo(_info());
    return true;
  }

  void _listen(int link) {
    final c = links[link];
    final seat = _seats[link];
    _subs.add(c.messages.listen((m) {
      switch (m['t']) {
        case 'in':
          final a = m['a'];
          if (a is int) world.steer(seat, a / 1000, m['b'] == 1);
        case 'again':
          world.respawnSeat(seat);
        case 'sync':
          c.send({'t': 'full', 'snap': encodeFull(world, seq)});
        case 'bye':
          _gone(link);
          c.close();
      }
    }));
    c.closed.then((_) => _gone(link));
  }

  /// 손님이 아주 나갔다.
  void _gone(int link) {
    final seat = _seats[link];
    final name = world.seatNames[seat];
    if (_closed || name == null) return;
    world.removeSeat(seat);
    sendAll({'t': 'left', 'name': name, 'seat': seat}, except: link);
    onToast?.call('$name님이 나갔어요');
    _desk?.updateInfo(_info());
  }

  /// 판을 한 장 그릴 때마다: 1초에 15번 바뀐 것을 보내고, 한참 응답 없는 손님 자리는 CPU에게 맡긴다.
  void tick(double dt) {
    _sendTimer += dt;
    if (_sendTimer >= 1 / 15) {
      _sendTimer = 0;
      seq++;
      final m = encodeDelta(world, seq);
      if (isOpen) sendAll(m);
    }
    _stallTimer += dt;
    if (_stallTimer >= 1) {
      _stallTimer = 0;
      final keeper = _keeper;
      for (var i = 0; i < links.length; i++) {
        final l = links[i];
        final since = l.stalledSince;
        if (keeper != null && since != null && !l.cpuCovered && !l.isClosed && DateTime.now().difference(since).inSeconds >= 2) keeper.takeOver(i);
      }
    }
  }

  void sendAll(Map<String, dynamic> message, {int? except}) {
    for (var i = 0; i < links.length; i++) {
      if (i != except) links[i].send(message);
    }
  }

  /// 방을 닫는다. [handover]이면 "방장이 나가요, 손님 중 한 명이 이어받아요"(`handover`)를, 아니면 "판이 끝났어요"(`end`)를 알린다.
  Future<void> close({bool handover = false}) async {
    if (_closed) return;
    sendAll(handover ? const {'t': 'handover'} : const {'t': 'end'});
    _closed = true;
    _migrantTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    for (final l in links) {
      await l.close();
    }
    _keeper?.dispose();
    await _desk?.close();
  }
}
