import 'dart:async';

import '../../../net/lan_connection.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_rejoin_flow.dart';
import 'snake_controller.dart';
import 'snake_host_net.dart';

/// 방장이 사라졌을 때 (일부러 나갔거나 [handover], 앱이 꺼지거나 Wi‑Fi가 끊겨서) 판을 이어 가는 길을 찾는다.
///
/// 이어받을 사람은 명단에서 가장 앞 자리의 손님([SnakeMirror.successor])이다. 모든 손님이 같은 명단을 가졌으니 각자 계산해도 같은 사람이 나온다.
///  - 이어받을 사람: 갑자기 끊긴 경우라면 먼저 옛 방에 다시 들어가 본다 (내 Wi‑Fi가 잠깐 끊긴 것일 수도 있으니). 안 되면 판을 이어받아 새 방장이 된다.
///  - 나머지 손님: 같은 Wi‑Fi에서 "옛 방에서 이어 온" 새 방을 찾아 같은 자리로 들어간다 (옛 방이 아직 있으면 거기로 다시 들어간다).
///
/// 이어 갈 새 컨트롤러를 돌려준다 (이어받은 방장이면 [SnakeController.isHost], 새 방에 붙은 손님이면 손님). 길이 없으면 null.
Future<SnakeController?> snakeRecoverHost(
  SnakeController c, {
  required bool handover,
  required String nick,
  Duration lookFor = const Duration(seconds: 25),
  int discoveryPort = kLanDiscoveryPort,
  List<String> extraTargets = const [],
}) async {
  final mirror = c.mirror;
  final ticket = await RejoinTickets.of(kSnakeLanGame);
  if (mirror == null || ticket == null) return null;
  final successor = mirror.successor();
  if (successor == null) return null;
  final me = c.mySeat;

  if (successor == me) {
    if (!handover) {
      final back = await _rejoinOld(ticket, nick, const Duration(seconds: 4), discoveryPort, extraTargets);
      if (back != null) return back;
    }
    await RejoinTickets.forget(kSnakeLanGame);
    return SnakeController.takeover(from: mirror, seat: me, oldHostSeat: mirror.hostSeat, oldRoom: ticket.roomId, nick: nick)
      ..startNote = '방장이 나가서 내가 방장이 되었어요. 친구들이 다시 들어오면 이어져요';
  }

  LanFinder? finder;
  try {
    finder = await LanFinder.start(game: kSnakeLanGame, discoveryPort: discoveryPort, extraTargets: extraTargets, interval: const Duration(milliseconds: 700));
    final until = DateTime.now().add(lookFor);
    var triedOld = false;
    while (DateTime.now().isBefore(until)) {
      for (final room in finder.current) {
        if (room.info['from'] == ticket.roomId) {
          final g = await _joinNewHost(room, ticket, me, nick);
          if (g != null) return g;
        } else if (!handover && !triedOld && room.info['roomId'] == ticket.roomId) {
          triedOld = true; // 옛 방이 아직 있다: 내 연결만 잠깐 끊겼던 것이다
          final g = await _rejoinOld(ticket, nick, Duration.zero, discoveryPort, extraTargets);
          if (g != null) return g;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } catch (_) {
    // Wi‑Fi가 없으면 새 방을 찾을 수 없다
  } finally {
    finder?.close();
  }
  return null;
}

/// 옛 방에 표로 다시 들어간다 (성공하면 그 판을 이어 하는 손님 컨트롤러).
Future<SnakeController?> _rejoinOld(RejoinTicket ticket, String nick, Duration lookFor, int discoveryPort, List<String> extraTargets) async {
  final r = await lanRejoin(ticket, nick: nick, lookFor: lookFor, discoveryPort: discoveryPort, extraTargets: extraTargets);
  if (!r.ok) return null;
  final g = SnakeControllerRejoin.fromWifiSnapshot(r.resume!, r.conn!);
  if (g == null) {
    r.conn!.close();
    return null;
  }
  return g..startNote = '다시 연결됐어요';
}

/// 새 방장의 방에 "옛 방에서 이어 왔어요"(`migrate`)로 들어가 같은 자리에 앉는다. 새 방이 준 표는 보관해 둔다.
Future<SnakeController?> _joinNewHost(LanRoom room, RejoinTicket old, int seat, String nick) async {
  final LanConnection conn;
  try {
    conn = await LanConnection.connect(room.address, room.port, timeout: const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
  conn.send({
    't': 'hello',
    'game': kSnakeLanGame,
    'nick': nick,
    'migrate': {'room': old.roomId, 'seat': seat},
  });
  final answer = Completer<Map<String, dynamic>?>();
  final sub = conn.messages.listen((m) {
    final kind = m['t'];
    if ((kind == 'start' || kind == 'gone' || kind == 'busy') && !answer.isCompleted) answer.complete(m);
  });
  conn.closed.then((_) {
    if (!answer.isCompleted) answer.complete(null);
  });
  final m = await answer.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
  await sub.cancel();
  if (m == null || m['t'] != 'start') {
    conn.close();
    return null;
  }
  conn.peer = m;
  final g = SnakeControllerRejoin.fromWifiSnapshot(m, conn);
  if (g == null) {
    conn.close();
    return null;
  }
  final t = m['rejoin'];
  if (t is Map && t['room'] is String && t['token'] is String) {
    await RejoinTickets.save(RejoinTicket(
      game: kSnakeLanGame,
      roomId: t['room'] as String,
      token: t['token'] as String,
      host: room.address,
      port: room.port,
      hostNick: m['nick'] is String ? m['nick'] as String : '',
      savedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }
  return g..startNote = '방장이 바뀌었어요. 판이 이어져요';
}
