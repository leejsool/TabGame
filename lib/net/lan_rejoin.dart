import 'dart:math';

import 'package:flutter/foundation.dart';

import 'lan_connection.dart';
import 'lan_discovery.dart';

/// 판이 시작된 뒤에도 방장 기기가 방 문을 열어 두고, 나갔던 손님이 다시 들어오면 받아 주는 "접수처".
///
/// 손님마다 시작할 때 표(방 번호 + 비밀 번호)를 받아 둔다. 앱을 껐다 켜도 이 표로 같은 자리에 다시 앉을 수 있다.
/// 표가 맞으면 나가 있던 그 손님의 연결([LanConnection.adopt])에 새 소켓을 이어 붙이고, 게임이 만들어 주는 판의 모습(`resume`)을 보낸다.
class LanRejoinDesk {
  LanRejoinDesk._(this._host, this.roomId, this.links, this._tokens, this._info, this._hex) {
    _host.rejoinHandler = _accept;
    _host.updateInfo({..._info, 'rejoin': true, 'roomId': roomId});
  }

  /// 방을 열어 둔 채로 접수처를 만든다. [guests]는 들어온 순서대로 (표도 그 순서로 만든다).
  factory LanRejoinDesk.open({required LanHost host, required List<LanConnection> guests, required Map<String, dynamic> info, Random? rng}) {
    final r = rng ?? Random.secure();
    String hex() => List.generate(4, (_) => r.nextInt(1 << 16).toRadixString(16).padLeft(4, '0')).join();
    return LanRejoinDesk._(host, hex(), guests, [for (var i = 0; i < guests.length; i++) hex()], info, hex);
  }

  final LanHost _host;
  final String roomId;

  /// 손님들의 연결 (들어온 순서).
  final List<LanConnection> links;
  final List<String> _tokens;
  final Map<String, dynamic> _info;
  final String Function() _hex;
  bool _closed = false;

  /// 판 도중에 처음 들어오는 손님 (표 없이 `hello`만 보낸 기기)을 받는 게임이면 채운다: 받으면 true.
  /// 받을 때는 [addGuest]로 손님 줄에 올리고 시작 메시지(`start`, 표 포함)를 직접 보낸다. (뱀 게임처럼 언제든 끼어드는 판)
  bool Function(LanConnection conn, Map<String, dynamic> hello)? onNewcomer;

  /// 방 찾는 기기에게 보이는 방 정보를 바꾼다 (지금 몇 명인지 등).
  void updateInfo(Map<String, dynamic> info) => _host.updateInfo({...info, 'rejoin': true, 'roomId': roomId});

  /// 판 도중에 들어온 손님을 줄 끝에 올리고 그 손님의 번호를 돌려준다 (표는 [ticketFor]).
  int addGuest(LanConnection conn) {
    links.add(conn);
    _tokens.add(_hex());
    return links.length - 1;
  }

  bool get isOpen => !_closed;

  /// [link]번째 손님에게 줄 표 (시작 메시지에 담아 보낸다).
  Map<String, dynamic> ticketFor(int link) => {'room': roomId, 'token': _tokens[link]};

  /// 손님이 다시 들어왔다: 그 손님의 자리를 되찾아 주고 보낼 판의 모습을 돌려준다. null이면 더는 이어 갈 수 없는 판이다.
  /// (이 함수가 돌려준 내용이 `resume` 메시지로 그 손님에게 가장 먼저 간다)
  Map<String, dynamic>? Function(int link)? onRejoin;

  /// 지금 다시 들어와도 되는 판인가 (끝났거나 멈춘 판이면 거짓).
  bool Function()? canRejoin;

  bool _accept(LanConnection fresh, Map<String, dynamic> hello) {
    final ticket = hello['rejoin'];
    if (!_closed && ticket == null && onNewcomer != null) return onNewcomer!(fresh, hello);
    if (_closed || ticket is! Map || ticket['room'] != roomId) return false;
    final i = _tokens.indexOf('${ticket['token']}');
    if (i < 0 || links[i].isClosed) return false;
    final handler = onRejoin;
    if (handler == null || !(canRejoin?.call() ?? true)) return false;
    final link = links[i];
    link.adopt(fresh);
    link.peer = {...link.peer, ...hello};
    final resume = handler(i);
    if (resume == null) {
      link.send(const {'t': 'gone'});
      link.suspend();
      return true; // (돌려보내는 말은 이미 이 연결로 했다)
    }
    link.send({'t': 'resume', ...resume});
    return true;
  }

  /// 방 문을 닫는다 (게임 화면이 닫힐 때). 이미 이어진 연결은 닫지 않는다.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _host.rejoinHandler = null;
    await _host.close();
  }
}

/// 방장 화면이 손님 자리를 돌보는 일: 안 돌아오는 손님의 자리를 CPU에게 맡기고, 돌아오면 되돌려 준다.
///
/// 세 게임(루미큐브·다빈치 코드·쿼리도)의 방장 화면이 같이 쓴다. 게임마다 다른 것은 함수로 받는다.
class LanHubKeeper {
  LanHubKeeper({
    required this.desk,
    required this.seatOfLink,
    required this.isActive,
    required this.cover,
    required this.uncover,
    required this.snapshot,
    required this.sendAll,
  }) {
    desk.onRejoin = _onRejoin;
    desk.canRejoin = isActive;
    for (var i = 0; i < links.length; i++) {
      watch(i);
    }
  }

  /// [link]번째 손님 연결을 돌보기 시작한다 (판 도중에 들어온 손님은 [LanRejoinDesk.addGuest] 뒤에 부른다).
  void watch(int link) {
    links[link].canResume = () => isActive() && desk.isOpen;
    links[link].onTakeOver = () => takeOver(link);
  }

  final LanRejoinDesk desk;
  List<LanConnection> get links => desk.links;

  /// [link]번째 손님이 지금 앉은 자리.
  final int Function(int link) seatOfLink;

  /// 아직 이어 가는 판인가 (끝났거나 기권으로 멈췄으면 거짓).
  final bool Function() isActive;

  /// 자리를 CPU가 맡게 / 사람에게 되돌려 준다 (방장 기기의 컨트롤러).
  final void Function(int seat) cover;
  final void Function(int seat) uncover;

  /// 그 자리에 다시 앉는 손님에게 보낼 판의 모습.
  final Map<String, dynamic> Function(int seat) snapshot;

  /// 모든 손님에게 (except번 연결만 빼고) 알린다.
  final void Function(Map<String, dynamic> message, {int? except}) sendAll;

  /// 안 돌아오는 [link]번째 손님의 자리를 CPU에게 맡긴다. 옛 연결은 끊어서, 나중에 낡은 소식이 끼어들지 못하게 한다
  /// (돌아오려면 새로 들어와서 판의 모습을 받아야 한다).
  void takeOver(int link) {
    final l = links[link];
    if (l.isClosed || l.cpuCovered || !isActive()) return;
    final seat = seatOfLink(link);
    l.cpuCovered = true;
    l.suspend();
    cover(seat);
    sendAll({'t': 'cpu', 'seat': seat}, except: link);
  }

  Map<String, dynamic>? _onRejoin(int link) {
    if (!isActive()) return null;
    final seat = seatOfLink(link);
    final l = links[link];
    final wasCovered = l.cpuCovered;
    l.cpuCovered = false;
    if (wasCovered) uncover(seat);
    sendAll({'t': 'back', 'seat': seat}, except: link);
    return {'seat': seat, 'snap': snapshot(seat)};
  }

  /// 판이 끝났을 때: 나가 있는 손님들의 연결을 정리하고 접수를 닫는다 (안내 카드가 남지 않게).
  void settleIfEnded() {
    if (isActive()) return;
    for (final l in links) {
      if (l.suspended || l.cpuCovered) l.close();
    }
  }

  void dispose() {
    desk.onRejoin = null;
    desk.canRejoin = null;
    for (final l in links) {
      l.canResume = null;
      l.onTakeOver = null;
    }
    desk.close();
  }

  @visibleForTesting
  Map<String, dynamic>? debugRejoin(int link) => _onRejoin(link);
}
