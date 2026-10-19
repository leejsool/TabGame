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
class SnakeHostNet {
  SnakeHostNet(this.world, {required this.hostNick, required this.cover, required this.uncover, this.onToast, this.gamePort = kLanGamePort, this.discoveryPort = kLanDiscoveryPort});

  final SnakeWorld world;
  final String hostNick;
  final void Function(int seat) cover, uncover;
  void Function(String text)? onToast;
  final int gamePort;
  final int? discoveryPort;

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
        seatOfLink: (link) => link + 1,
        isActive: () => !_closed,
        cover: cover,
        uncover: uncover,
        snapshot: (_) => encodeFull(world, seq),
        sendAll: sendAll,
      );
      roomNumber = roomNumberOf(await localLanAddresses());
    } catch (_) {
      // 방을 못 열어도 CPU들과는 그대로 논다
    }
  }

  Map<String, dynamic> _info() => {'open': true, 'nick': hostNick, 'people': 1 + guests};

  bool _newcomer(LanConnection conn, Map<String, dynamic> hello) {
    final desk = _desk, keeper = _keeper;
    if (_closed || desk == null || keeper == null || world.seatNames.length >= SnakeRules.maxHumans) return false;
    conn.peer = hello;
    final link = desk.addGuest(conn);
    keeper.watch(link);
    final seat = link + 1;
    world.addSeat(seat, conn.peerNick);
    _listen(link);
    conn.send({'t': 'start', 'seat': seat, 'rejoin': desk.ticketFor(link), 'nick': hostNick, 'snap': encodeFull(world, seq)});
    sendAll({'t': 'join', 'name': conn.peerNick}, except: link);
    onToast?.call('${conn.peerNick}님이 들어왔어요');
    desk.updateInfo(_info());
    return true;
  }

  void _listen(int link) {
    final c = links[link];
    final seat = link + 1;
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
    final seat = link + 1;
    final name = world.seatNames[seat];
    if (_closed || name == null) return;
    world.removeSeat(seat);
    sendAll({'t': 'left', 'name': name}, except: link);
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

  /// 판을 끝낸다: 손님들에게 알리고 방을 닫는다.
  Future<void> close() async {
    if (_closed) return;
    sendAll(const {'t': 'end'});
    _closed = true;
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
