import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings_scope.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';

/// 손님이 방에 들어갈 때 받아 둔 "다시 들어오기 표". 앱을 껐다 켜도 이 표로 하던 방에 다시 앉을 수 있다.
class RejoinTicket {
  const RejoinTicket({
    required this.game,
    required this.roomId,
    required this.token,
    required this.host,
    required this.port,
    required this.hostNick,
    required this.savedAt,
  });

  /// 같은 Wi‑Fi에서 쓰는 게임 이름 (방 찾기·들어가기 때 쓰는 값).
  final String game;
  final String roomId;
  final String token;

  /// 방장 기기의 마지막으로 안 주소와 포트 (바뀌었으면 방 찾기로 다시 찾는다).
  final String host;
  final int port;
  final String hostNick;
  final int savedAt;

  Map<String, dynamic> toJson() => {'game': game, 'roomId': roomId, 'token': token, 'host': host, 'port': port, 'hostNick': hostNick, 'savedAt': savedAt};

  static RejoinTicket? fromJson(Object? j) {
    if (j is! Map) return null;
    final game = j['game'], roomId = j['roomId'], token = j['token'], host = j['host'], port = j['port'], nick = j['hostNick'], at = j['savedAt'];
    if (game is! String || roomId is! String || token is! String || host is! String || port is! int || at is! int) return null;
    return RejoinTicket(game: game, roomId: roomId, token: token, host: host, port: port, hostNick: nick is String ? nick : '', savedAt: at);
  }
}

/// 받아 둔 표들을 기기에 보관한다 (게임마다 하나). 오래된 표는 버린다.
class RejoinTickets {
  RejoinTickets._();

  /// 보관이 바뀔 때마다 올라가는 값 (허브의 "다시 들어가기" 카드가 다시 그리려고 듣는다).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static const String _key = 'lan.rejoin';

  /// 이만큼 지나면 표를 버린다 (방은 그 사이 닫혔을 것이다).
  static const Duration maxAge = Duration(hours: 12);

  static Future<List<RejoinTicket>> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return const []; // (보관소를 못 열면 표가 없는 것으로 본다)
    }
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      return [
        for (final j in jsonDecode(raw) as List)
          if (RejoinTicket.fromJson(j) case final t? when now - t.savedAt < maxAge.inMilliseconds) t,
      ];
    } catch (_) {
      await prefs.remove(_key); // 깨진 보관은 버린다
      return const [];
    }
  }

  static Future<RejoinTicket?> of(String game) async {
    for (final t in await load()) {
      if (t.game == game) return t;
    }
    return null;
  }

  /// 표를 보관한다 (같은 게임의 옛 표는 바꾼다).
  static Future<void> save(RejoinTicket ticket) async {
    final list = [for (final t in await load()) if (t.game != ticket.game) t, ticket];
    await _write(list);
  }

  /// 그 게임의 표를 버린다 (판이 끝났거나 일부러 나갔을 때).
  static Future<void> forget(String game) async {
    final all = await load();
    if (!all.any((t) => t.game == game)) return;
    await _write([for (final t in all) if (t.game != game) t]);
  }

  static Future<void> _write(List<RejoinTicket> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (list.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode([for (final t in list) t.toJson()]));
      }
      changes.value++;
    } catch (_) {
      // 보관을 못 해도 판은 그대로 한다
    }
  }
}

/// 다시 들어가려다 안 된 까닭.
enum LanRejoinFail {
  /// 방을 찾지 못했다 (방장 기기가 꺼졌거나 다른 Wi‑Fi라서). 표는 그대로 둔다.
  notFound,

  /// 방은 있는데 이미 끝났거나 받아 주지 않는다. 표는 버린다.
  gone,
}

class LanRejoinResult {
  const LanRejoinResult.ok(LanConnection this.conn, Map<String, dynamic> this.resume) : fail = null;
  const LanRejoinResult.failed(LanRejoinFail this.fail)
      : conn = null,
        resume = null;

  final LanConnection? conn;

  /// 방장이 보낸 `resume` 메시지 (`seat`, `snap` …).
  final Map<String, dynamic>? resume;
  final LanRejoinFail? fail;

  bool get ok => conn != null;
}

/// 표를 들고 방에 다시 들어간다: 먼저 마지막으로 안 주소로, 안 되면 같은 Wi‑Fi에서 방 번호가 같은 방을 찾아서.
/// 성공하면 방장이 보낸 판의 모습(`resume`)과 연결을 돌려준다.
Future<LanRejoinResult> lanRejoin(
  RejoinTicket ticket, {
  required String nick,
  int discoveryPort = kLanDiscoveryPort,
  List<String> extraTargets = const [],
  Duration lookFor = const Duration(seconds: 6),
}) async {
  final direct = await _handshake(ticket, ticket.host, ticket.port, nick);
  if (direct != null) return direct;
  LanFinder? finder;
  try {
    finder = await LanFinder.start(game: ticket.game, discoveryPort: discoveryPort, extraTargets: extraTargets, interval: const Duration(milliseconds: 700));
    final until = DateTime.now().add(lookFor);
    while (DateTime.now().isBefore(until)) {
      for (final r in finder.current) {
        if (r.info['roomId'] != ticket.roomId) continue;
        final found = await _handshake(ticket, r.address, r.port, nick);
        if (found != null) return found;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  } catch (_) {
    // Wi‑Fi가 없으면 방을 찾을 수 없다
  } finally {
    finder?.close();
  }
  return const LanRejoinResult.failed(LanRejoinFail.notFound);
}

/// 한 주소에 들어가 보고 답을 기다린다. 연결이 안 되면 null (다른 주소를 찾아본다).
Future<LanRejoinResult?> _handshake(RejoinTicket t, String host, int port, String nick) async {
  final LanConnection conn;
  try {
    conn = await LanConnection.connect(host, port, timeout: const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
  conn.send({
    't': 'hello',
    'game': t.game,
    'nick': nick,
    'rejoin': {'room': t.roomId, 'token': t.token},
  });
  final answer = Completer<Map<String, dynamic>?>();
  final sub = conn.messages.listen((m) {
    final kind = m['t'];
    if ((kind == 'resume' || kind == 'gone' || kind == 'busy') && !answer.isCompleted) answer.complete(m);
  });
  conn.closed.then((_) {
    if (!answer.isCompleted) answer.complete(null);
  });
  final m = await answer.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
  await sub.cancel();
  if (m == null) {
    conn.close();
    return null;
  }
  if (m['t'] != 'resume') {
    conn.close();
    return const LanRejoinResult.failed(LanRejoinFail.gone);
  }
  conn.peer = m;
  return LanRejoinResult.ok(conn, m);
}

/// "방에 다시 들어가는 중…"을 보여 주면서 [lanRejoin]을 한다.
Future<LanRejoinResult> lanRejoinWithProgress(BuildContext context, RejoinTicket ticket, {int discoveryPort = kLanDiscoveryPort, List<String> extraTargets = const []}) async {
  final nick = SettingsScope.of(context).nickname;
  final navigator = Navigator.of(context, rootNavigator: true);
  var shown = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 16),
            Expanded(child: Text('방에 다시 들어가는 중…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    ),
  ).then((_) => shown = false);
  final result = await lanRejoin(ticket, nick: nick, discoveryPort: discoveryPort, extraTargets: extraTargets);
  if (shown) navigator.pop();
  if (result.fail == LanRejoinFail.gone) await RejoinTickets.forget(ticket.game);
  return result;
}

/// 못 들어갔을 때 보여 줄 말.
String lanRejoinFailText(LanRejoinFail fail) => switch (fail) {
      LanRejoinFail.notFound => '방을 찾지 못했어요. 방장 기기가 켜져 있고 같은 Wi‑Fi에 연결되어 있는지 확인해 주세요.',
      LanRejoinFail.gone => '이 방은 이미 끝났거나 닫혔어요.',
    };

/// [lanOfferRejoin]의 결과.
enum LanOffer {
  /// 다시 들어갈 표가 없어서 묻지 않았다.
  unavailable,

  /// 다시 들어가서 이 화면이 새 화면으로 바뀌었다.
  rejoined,

  /// 나가기를 골랐거나 방이 이미 끝났다.
  declined,
}

/// 손님 쪽 게임 화면에서 방장과의 연결이 끊겼을 때 (판이 아직 이어지던 중이면): "다시 들어가기 / 나가기"를 묻는다.
/// 다시 들어가면 이 화면을 새로 받은 판의 모습으로 바꾼다. 나가기를 고르면 표를 버린다.
Future<LanOffer> lanOfferRejoin(
  BuildContext context, {
  required String game,
  required Widget? Function(Map<String, dynamic> resume, LanConnection conn) build,
}) async {
  final ticket = await RejoinTickets.of(game);
  if (ticket == null || !context.mounted) return LanOffer.unavailable;
  var failText = '';
  while (true) {
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wifi_off_rounded, size: 32),
        title: const Text('연결이 끊겼어요', textAlign: TextAlign.center),
        content: Text(
          '${failText.isEmpty ? '' : '$failText\n\n'}방이 아직 열려 있으면 하던 판으로 바로 다시 들어갈 수 있어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('나가기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('다시 들어가기')),
        ],
      ),
    );
    if (!context.mounted) return LanOffer.declined;
    if (again != true) {
      await RejoinTickets.forget(game);
      return LanOffer.declined;
    }
    final result = await lanRejoinWithProgress(context, ticket);
    if (!context.mounted) {
      result.conn?.close();
      return LanOffer.declined;
    }
    if (result.ok) {
      final screen = build(result.resume!, result.conn!);
      if (screen != null) {
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
        return LanOffer.rejoined;
      }
      result.conn!.close();
      failText = '판의 모습을 받지 못했어요.';
    } else {
      failText = lanRejoinFailText(result.fail!);
      if (result.fail == LanRejoinFail.gone) return LanOffer.declined;
    }
  }
}

/// 손님 쪽 게임 화면이 방장과 끊겼을 때 부른다: 다시 들어갈 수 있으면 묻고, 표가 없으면 [fallbackNotice](평소의 끊김 안내)를 보인 뒤,
/// 다시 들어가지 않았으면 화면을 닫는다.
Future<void> lanGuestDropped(
  BuildContext context, {
  required String game,
  required Widget? Function(Map<String, dynamic> resume, LanConnection conn) build,
  required Future<void> Function() fallbackNotice,
}) async {
  final r = await lanOfferRejoin(context, game: game, build: build);
  if (r == LanOffer.rejoined) return;
  if (r == LanOffer.unavailable) await fallbackNotice();
  if (context.mounted) Navigator.of(context).pop();
}

/// 화면 아래에 잠깐 뜨는 짧은 알림 (누가 CPU로 바뀌었다 / 돌아왔다).
void lanToast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 2600), behavior: SnackBarBehavior.floating));
}
