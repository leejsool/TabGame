import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/nickname.dart';

/// 같은 Wi‑Fi(공유기)에 연결된 두 기기가 주고받는 한 줄짜리 JSON 메시지 연결.
///
/// 한 메시지는 JSON 객체 하나 + 줄바꿈이다. 게임은 `{'t': 'move', ...}`처럼 `t`(종류)가 있는 메시지를 주고받는다.
/// 끊긴 연결을 빨리 알아채도록 2초마다 신호(`t: 'p'`)를 보내고, 9초 동안 아무것도 안 오면 끊긴 것으로 본다.
/// (이 신호는 [messages]에 나오지 않는다)
///
/// 나중에 서버를 거치는 멀리서 함께하기를 만들 때는 이 클래스와 같은 모양([messages]/[send]/[closed]/[close])의
/// 다른 구현을 끼우면 게임 쪽은 그대로 쓸 수 있다.
class LanConnection {
  LanConnection(this._socket, {Duration heartbeat = const Duration(seconds: 2), Duration timeout = const Duration(seconds: 9)}) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _lastRx = DateTime.now();
    _socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      _onLine,
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
    _timer = Timer.periodic(heartbeat, (_) {
      if (DateTime.now().difference(_lastRx) > timeout) {
        _finish();
        return;
      }
      send(const {'t': 'p'});
    });
  }

  /// 이미 열린 주소로 연결한다. 못 하면(주소가 틀렸거나 방이 닫힘) 예외.
  static Future<LanConnection> connect(String host, int port, {Duration timeout = const Duration(seconds: 4)}) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return LanConnection(socket);
  }

  final Socket _socket;
  late final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast(onListen: () => scheduleMicrotask(_drain));
  final List<Map<String, dynamic>> _queue = [];
  final Completer<void> _closed = Completer<void>();
  late Timer _timer;
  late DateTime _lastRx;

  /// 상대가 보낸 메시지들 (신호 제외). 듣는 쪽이 없을 때 온 메시지는 모아 두었다가 듣기 시작하면 차례대로 준다
  /// (방 화면에서 게임 화면으로 넘어가는 사이에 온 첫 수를 놓치지 않으려고).
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// 연결이 끊기거나 닫히면 완료된다.
  Future<void> get closed => _closed.future;

  bool get isClosed => _closed.isCompleted;

  /// 상대 기기의 주소.
  String get peerAddress => _socket.remoteAddress.address;

  /// 상대가 처음에 보낸 소개 메시지 (방을 연 쪽은 손님의 `hello`, 들어간 쪽은 방의 `start`).
  Map<String, dynamic> peer = const {};

  /// 상대의 별명 (소개에 없거나 비었으면 "상대").
  String get peerNick => cleanNickname(peer['nick']) ?? '상대';

  void _onLine(String line) {
    _lastRx = DateTime.now();
    if (line.isEmpty) return;
    try {
      final m = jsonDecode(line);
      if (m is Map<String, dynamic> && m['t'] != 'p') {
        _queue.add(m);
        _drain();
      }
    } catch (_) {
      // 깨진 줄은 무시한다.
    }
  }

  void _drain() {
    while (_queue.isNotEmpty && _messages.hasListener && !_messages.isClosed) {
      _messages.add(_queue.removeAt(0));
    }
  }

  /// 메시지를 보낸다. 이미 끊겼으면 아무 일도 하지 않는다.
  void send(Map<String, dynamic> message) {
    if (isClosed) return;
    try {
      _socket.write('${jsonEncode(message)}\n');
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (_closed.isCompleted) return;
    _closed.complete();
    _timer.cancel();
    _socket.destroy();
    _messages.close();
  }

  /// 연결을 닫는다 (상대에게는 끊김으로 보인다).
  Future<void> close() async {
    if (isClosed) return;
    try {
      await _socket.flush();
    } catch (_) {}
    _finish();
  }
}
