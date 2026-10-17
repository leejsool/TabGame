import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/nickname.dart';
import 'keep_awake.dart';

/// 같은 Wi‑Fi(공유기)에 연결된 두 기기가 주고받는 한 줄짜리 JSON 메시지 연결.
///
/// 한 메시지는 JSON 객체 하나 + 줄바꿈이다. 게임은 `{'t': 'move', ...}`처럼 `t`(종류)가 있는 메시지를 주고받는다.
/// 2초마다 신호(`t: 'p'`)를 보내고(이 신호는 [messages]에 나오지 않는다), 몇 초 동안 아무것도 안 오면 "응답이 없는" 상태([stalled])로 본다.
/// 상대가 카톡을 보러 잠깐 나간 것일 수 있어서 바로 끊지 않고 기다린다: 끊을지는 남은 사람이 정한다 ([LanStallOverlay]).
/// 상대가 돌아와서 신호가 다시 오면 아무 일 없던 듯 이어진다. 소켓 자체가 닫히면 그때는 끊긴 것이다.
///
/// 나중에 서버를 거치는 멀리서 함께하기를 만들 때는 이 클래스와 같은 모양([messages]/[send]/[closed]/[close])의
/// 다른 구현을 끼우면 게임 쪽은 그대로 쓸 수 있다.
class LanConnection {
  LanConnection(
    this._socket, {
    Duration heartbeat = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 7),
    this.giveUp,
  }) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
    KeepAwake.acquire(); // 이어져 있는 동안 화면이 꺼지지 않게 (끊기면 푼다)
    _lastRx = DateTime.now();
    _lastTick = _lastRx;
    _socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      _onLine,
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: true,
    );
    _timer = Timer.periodic(heartbeat, (_) {
      final now = DateTime.now();
      // 이 기기가 한동안 멈춰 있었다면(앱이 뒤로 갔다 온 경우) 그동안 쌓인 신호를 아직 못 읽은 것일 수 있으니, 바로 응답 없음으로 보지 않는다
      if (now.difference(_lastTick) > heartbeat * 3) _lastRx = now;
      _lastTick = now;
      final silent = now.difference(_lastRx);
      if (giveUp != null && silent > giveUp!) {
        _finish();
        return;
      }
      _setStalled(silent > timeout);
      send(const {'t': 'p'});
    });
  }

  /// 이만큼 아무것도 안 오면 끊긴 것으로 본다. null이면 (기본) 스스로 끊지 않는다. (시험용)
  final Duration? giveUp;

  /// 지금 응답이 없는 연결들 (화면에 "상대를 기다리는 중"을 보여 주는 데 쓴다).
  static final ValueNotifier<List<LanConnection>> stalledConnections = ValueNotifier(const []);

  /// 상대의 응답이 끊긴 지 얼마나 됐는가 (응답이 있으면 null).
  DateTime? stalledSince;

  bool get stalled => stalledSince != null;

  /// 기다리는 걸 잠깐 접어 둔 시각 ("계속 기다리기"를 누른 뒤 한동안 결정 단추를 다시 안 보이려고).
  DateTime? decisionSnoozedUntil;

  void _setStalled(bool on) {
    if (on == stalled) return;
    stalledSince = on ? DateTime.now() : null;
    if (!on) decisionSnoozedUntil = null;
    _publishStalled();
  }

  void _publishStalled() {
    final list = [...stalledConnections.value]..remove(this);
    if (stalled && !isClosed) list.add(this);
    stalledConnections.value = List.unmodifiable(list);
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
  late DateTime _lastTick;

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
    if (stalled) _setStalled(false);
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
    KeepAwake.release();
    _timer.cancel();
    stalledSince = null;
    _publishStalled();
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
