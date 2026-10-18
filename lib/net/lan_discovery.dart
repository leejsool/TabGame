import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'keep_awake.dart';
import 'lan_connection.dart';

/// 같은 Wi‑Fi에서 방을 찾는 약속: 방을 연 기기는 이 UDP 포트로 "방 있나요?"를 기다리고,
/// 방을 찾는 기기는 같은 Wi‑Fi 안에 "방 있나요?"를 외친 다음 답을 모은다.
const int kLanDiscoveryPort = 45821;

/// 방을 연 기기가 손님을 기다리는 TCP 포트 (이미 쓰고 있으면 아무 빈 포트).
const int kLanGamePort = 45822;

const String _find = 'find', _here = 'here';

/// 이 기기의 Wi‑Fi(사설망) 주소들. 없으면 빈 목록.
Future<List<String>> localLanAddresses() async {
  try {
    final out = <String>[];
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in i.addresses) {
        if (a.isLoopback || a.isLinkLocal) continue;
        out.add(a.address);
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// 같은 Wi‑Fi에서 발견된 방.
class LanRoom {
  const LanRoom({required this.address, required this.port, required this.info});

  final String address;
  final int port;

  /// 방을 연 쪽이 알려 준 정보 (게임이 정한다: 표 크기 등).
  final Map<String, dynamic> info;

  String get key => '$address:$port';

  Future<LanConnection> join() => LanConnection.connect(address, port);
}

/// 방을 연 쪽: 손님을 기다린다 (보통 한 명, 여러 명이 함께 하는 게임은 [open]의 `maxGuests`만큼).
/// 손님이 오면 [guests]로 연결이 나온다 (첫 메시지 `hello` 확인 뒤).
///
/// 손님이 다 찬 동안에는 다른 손님에게 `busy`를 알리고, 손님이 나가면 다시 받는다.
/// 게임이 시작되면 [close]로 기다리기만 끝낸다 (이미 이어진 연결은 그대로).
class LanHost {
  LanHost._(this._server, this._udp, this.game, this._info, this.maxGuests);

  /// 방을 연다. [info]는 방을 찾는 기기에게 보여 줄 정보 (JSON으로 보낼 수 있는 값만).
  /// 시험에서는 [discoveryPort]를 바꿔 쓴다. [discoveryPort]가 null이면 방 찾기 응답은 하지 않는다.
  /// [maxGuests]는 한 번에 받을 손님 수 (기본 1명).
  static Future<LanHost> open({
    required String game,
    required Map<String, dynamic> info,
    int maxGuests = 1,
    int gamePort = kLanGamePort,
    int? discoveryPort = kLanDiscoveryPort,
    InternetAddress? bindAddress,
  }) async {
    final address = bindAddress ?? InternetAddress.anyIPv4;
    ServerSocket server;
    try {
      server = await ServerSocket.bind(address, gamePort);
    } on SocketException {
      server = await ServerSocket.bind(address, 0);
    }
    RawDatagramSocket? udp;
    if (discoveryPort != null) {
      try {
        udp = await RawDatagramSocket.bind(address, discoveryPort, reuseAddress: true);
      } on SocketException {
        udp = null; // 방 찾기 응답은 못 해도, 주소를 직접 입력해서 들어올 수는 있다.
      }
    }
    final host = LanHost._(server, udp, game, info, maxGuests);
    host._listen();
    KeepAwake.acquire(); // 방을 열어 두는 동안 화면이 꺼지지 않게 (닫으면 푼다)
    return host;
  }

  final ServerSocket _server;
  final RawDatagramSocket? _udp;
  final String game;
  final int maxGuests;
  Map<String, dynamic> _info;
  final List<LanConnection> _conns = [];
  bool _closed = false;
  final StreamController<LanConnection> _guests = StreamController<LanConnection>.broadcast();

  int get port => _server.port;

  /// 손님이 들어올 때마다 (손님이 나갔다 다시 들어올 수도 있다).
  Stream<LanConnection> get guests => _guests.stream;

  /// 지금 손님이 있는가.
  bool get hasGuest => _conns.isNotEmpty;

  /// 지금 들어와 있는 손님 수.
  int get guestCount => _conns.length;

  bool get _full => _conns.length >= maxGuests;

  /// 방 정보를 바꾼다 (방 찾는 기기에게 보이는 값).
  void updateInfo(Map<String, dynamic> info) => _info = info;

  /// 판이 시작된 뒤에 정해 두는 "다시 들어오기" 처리. 있으면 이 방은 새 손님은 받지 않고,
  /// 첫 인사(`hello`)에 든 표를 이 함수가 받아 주면(true) 이어 주고 아니면 돌려보낸다. 방 찾기에는 계속 답한다.
  bool Function(LanConnection conn, Map<String, dynamic> hello)? rejoinHandler;

  void _listen() {
    _server.listen((socket) {
      final conn = LanConnection(socket);
      late StreamSubscription<Map<String, dynamic>> sub;
      final timeout = Timer(const Duration(seconds: 5), conn.close);
      sub = conn.messages.listen((m) {
        if (m['t'] != 'hello') return;
        timeout.cancel();
        sub.cancel();
        final rejoin = rejoinHandler;
        if (rejoin != null) {
          // 이미 시작한 판: 처음 들어올 때 받은 표(ticket)를 가진 손님만 다시 받는다
          if (_closed || m['game'] != game || !rejoin(conn, m)) {
            conn.send(const {'t': 'gone'});
            conn.close();
          }
          return;
        }
        if (_closed || _full || m['game'] != game) {
          conn.send(const {'t': 'busy'});
          conn.close();
          return;
        }
        _conns.add(conn);
        conn.peer = m;
        conn.closed.then((_) => _conns.remove(conn));
        conn.send({'t': 'welcome'});
        if (!_guests.isClosed) _guests.add(conn);
      });
      conn.closed.then((_) => timeout.cancel());
    });
    _udp?.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = _udp.receive();
      if (d == null || (_full && rejoinHandler == null)) return;
      try {
        final m = jsonDecode(utf8.decode(d.data));
        if (m is Map && m['t'] == _find && m['game'] == game) {
          final reply = jsonEncode({'t': _here, 'game': game, 'port': port, 'info': _info});
          _udp.send(utf8.encode(reply), d.address, d.port);
        }
      } catch (_) {}
    });
  }

  /// 기다리기를 끝낸다. 이미 이어진 연결은 닫지 않는다.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    KeepAwake.release();
    _udp?.close();
    await _server.close();
    await _guests.close();
  }
}

/// 방을 찾는 쪽: 같은 Wi‑Fi에 "방 있나요?"를 계속 외치고, 답한 방을 [rooms]로 알려 준다.
class LanFinder {
  LanFinder._(this._socket, this.game, this._targets, this._discoveryPort);

  /// 시험에서는 [discoveryPort]와 [extraTargets](예: 127.0.0.1)를 바꿔 쓴다.
  static Future<LanFinder> start({
    required String game,
    Duration interval = const Duration(milliseconds: 1500),
    int discoveryPort = kLanDiscoveryPort,
    List<String> extraTargets = const [],
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    // 255.255.255.255 말고도 내 Wi‑Fi의 "모두에게" 주소(…255)로도 보낸다 (기기에 따라 앞의 것이 막혀 있다).
    final targets = <String>{
      '255.255.255.255',
      for (final a in await localLanAddresses()) '${a.substring(0, a.lastIndexOf('.'))}.255',
      ...extraTargets,
    };
    final finder = LanFinder._(socket, game, targets.toList(), discoveryPort);
    finder._run(interval);
    return finder;
  }

  final RawDatagramSocket _socket;
  final String game;
  final List<String> _targets;
  final int _discoveryPort;
  final Map<String, LanRoom> _found = {};
  final Map<String, DateTime> _seen = {};
  final StreamController<List<LanRoom>> _controller = StreamController<List<LanRoom>>.broadcast();
  Timer? _timer;
  bool _closed = false;

  /// 지금까지 찾은 방들 (바뀔 때마다).
  Stream<List<LanRoom>> get rooms => _controller.stream;

  List<LanRoom> get current => _found.values.toList();

  void _run(Duration interval) {
    final query = utf8.encode(jsonEncode({'t': _find, 'game': game}));
    void ask() {
      for (final t in _targets) {
        try {
          _socket.send(query, InternetAddress(t), _discoveryPort);
        } catch (_) {}
      }
    }

    ask();
    _timer = Timer.periodic(interval, (_) {
      // 한동안 답이 없는 방(닫혔거나 손님이 찼거나)은 목록에서 뺀다.
      final stale = [for (final e in _seen.entries) if (DateTime.now().difference(e.value) > interval * 3) e.key];
      if (stale.isNotEmpty) {
        for (final k in stale) {
          _seen.remove(k);
          _found.remove(k);
        }
        if (!_controller.isClosed) _controller.add(current);
      }
      ask();
    });
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = _socket.receive();
      if (d == null) return;
      try {
        final m = jsonDecode(utf8.decode(d.data));
        if (m is Map && m['t'] == _here && m['game'] == game) {
          final room = LanRoom(
            address: d.address.address,
            port: m['port'] as int,
            info: Map<String, dynamic>.from(m['info'] as Map? ?? const {}),
          );
          _found[room.key] = room;
          _seen[room.key] = DateTime.now();
          if (!_controller.isClosed) _controller.add(current);
        }
      } catch (_) {}
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _socket.close();
    _controller.close();
  }
}
