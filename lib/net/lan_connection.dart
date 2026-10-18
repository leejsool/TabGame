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
/// 방장 기기의 손님 연결은 [canResume]이 참인 동안 소켓이 닫혀도 끝내지 않고 "나간 상태"([suspended])로 둔다.
/// 그 손님이 (앱을 껐다 켜서라도) 다시 들어오면 [adopt]로 새 소켓을 이어 붙여서, 게임 화면은 같은 연결을 계속 쓴다.
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
    _peerAddress = _socket.remoteAddress.address;
    KeepAwake.acquire(); // 이어져 있는 동안 화면이 꺼지지 않게 (끊기면 푼다)
    _holdsAwake = true;
    _lastRx = DateTime.now();
    _lastTick = _lastRx;
    _listenSocket();
    _timer = Timer.periodic(heartbeat, (_) {
      final now = DateTime.now();
      // 이 기기가 한동안 멈춰 있었다면(앱이 뒤로 갔다 온 경우) 그동안 쌓인 신호를 아직 못 읽은 것일 수 있으니, 바로 응답 없음으로 보지 않는다
      if (now.difference(_lastTick) > heartbeat * 3 && !_suspended) _lastRx = now;
      _lastTick = now;
      final silent = now.difference(_lastRx);
      if (giveUp != null && silent > giveUp!) {
        _finish();
        return;
      }
      _setStalled(_suspended || silent > timeout);
      send(const {'t': 'p'});
    });
  }

  /// 이만큼 아무것도 안 오면 끊긴 것으로 본다. null이면 (기본) 스스로 끊지 않는다. (시험용)
  final Duration? giveUp;

  /// 지금 응답이 없거나 나가 있거나 CPU가 대신 하고 있는 연결들 (화면에 "상대를 기다리는 중"을 보여 주는 데 쓴다).
  static final ValueNotifier<List<LanConnection>> stalledConnections = ValueNotifier(const []);

  /// 상대의 응답이 끊긴 지 얼마나 됐는가 (응답이 있으면 null).
  DateTime? stalledSince;

  bool get stalled => stalledSince != null;

  /// 기다리는 걸 잠깐 접어 둔 시각 ("계속 기다리기"를 누른 뒤 한동안 결정 단추를 다시 안 보이려고).
  DateTime? decisionSnoozedUntil;

  /// 이 연결이 끊겨도 끝내지 않고 "나간 상태"로 기다려도 되는가 (방장 쪽: 진행 중인 판에서만 참).
  bool Function()? canResume;

  /// 소켓이 닫혀서(앱을 껐거나 Wi‑Fi가 끊겨서) 다시 들어오기를 기다리는 중인가.
  bool get suspended => _suspended;
  bool _suspended = false;

  /// 방장이 이 사람 자리를 CPU에게 맡겼는가 (안내 카드에 "CPU가 대신하는 중"을 보여 준다).
  bool get cpuCovered => _cpuCovered;
  bool _cpuCovered = false;
  set cpuCovered(bool on) {
    if (_cpuCovered == on) return;
    _cpuCovered = on;
    _publishStalled();
  }

  /// "CPU가 대신하기"를 눌렀을 때 할 일 (게임 화면이 정해 준다). null이면 단추를 보이지 않는다.
  VoidCallback? onTakeOver;

  void _setStalled(bool on) {
    if (on == stalled) return;
    stalledSince = on ? DateTime.now() : null;
    if (!on) decisionSnoozedUntil = null;
    _publishStalled();
  }

  void _publishStalled() {
    final list = [...stalledConnections.value]..remove(this);
    if ((stalled || _cpuCovered) && !isClosed) list.add(this);
    stalledConnections.value = List.unmodifiable(list);
  }

  /// 이미 열린 주소로 연결한다. 못 하면(주소가 틀렸거나 방이 닫힘) 예외.
  static Future<LanConnection> connect(String host, int port, {Duration timeout = const Duration(seconds: 4)}) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return LanConnection(socket);
  }

  Socket _socket;
  StreamSubscription<String>? _sub;
  late final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast(onListen: () => scheduleMicrotask(_drain));
  final List<Map<String, dynamic>> _queue = [];
  final Completer<void> _closed = Completer<void>();
  late Timer _timer;
  late DateTime _lastRx;
  late DateTime _lastTick;
  late String _peerAddress;
  bool _holdsAwake = false;

  /// 다시 들어오는 기기의 소켓을 대신 받아 준 "문지기" 연결이면, 그 소켓에서 온 것을 넘겨줄 원래 연결.
  LanConnection? _forwardTo;

  /// 상대가 보낸 메시지들 (신호 제외). 듣는 쪽이 없을 때 온 메시지는 모아 두었다가 듣기 시작하면 차례대로 준다
  /// (방 화면에서 게임 화면으로 넘어가는 사이에 온 첫 수를 놓치지 않으려고).
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// 연결이 끊기거나 닫히면 완료된다.
  Future<void> get closed => _closed.future;

  bool get isClosed => _closed.isCompleted;

  /// 상대 기기의 주소.
  String get peerAddress => _peerAddress;

  /// 상대가 처음에 보낸 소개 메시지 (방을 연 쪽은 손님의 `hello`, 들어간 쪽은 방의 `start`).
  Map<String, dynamic> peer = const {};

  /// 상대의 별명 (소개에 없거나 비었으면 "상대").
  String get peerNick => cleanNickname(peer['nick']) ?? '상대';

  void _listenSocket() {
    final socket = _socket;
    _sub = socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      _onLine,
      onError: (Object _) => _socketLost(socket),
      onDone: () => _socketLost(socket),
      cancelOnError: true,
    );
  }

  /// 소켓이 닫혔다. 다시 들어올 수 있는 연결이면 "나간 상태"로 두고, 아니면 끝낸다.
  void _socketLost(Socket socket) {
    final to = _forwardTo;
    if (to != null) {
      to._socketLost(socket);
      return;
    }
    if (!identical(socket, _socket) || isClosed) return; // (이미 새 소켓으로 바뀐 뒤에 온 옛 소식)
    if (canResume?.call() ?? false) {
      suspend();
    } else {
      _finish();
    }
  }

  void _onLine(String line) {
    final to = _forwardTo;
    if (to != null) {
      to._onLine(line);
      return;
    }
    _lastRx = DateTime.now();
    if (stalled && !_suspended) _setStalled(false);
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

  /// 메시지를 보낸다. 이미 끊겼거나 나가 있으면 아무 일도 하지 않는다.
  void send(Map<String, dynamic> message) {
    if (isClosed || _suspended) return;
    try {
      _socket.write('${jsonEncode(message)}\n');
    } catch (_) {
      _socketLost(_socket);
    }
  }

  /// 소켓을 버리고 "나간 상태"로 둔다 (다시 들어오면 [adopt]로 이어진다). 다시 들어올 수 없는 연결이면 아무 일도 하지 않고 false.
  bool suspend() {
    if (isClosed || !(canResume?.call() ?? false)) return false;
    if (_suspended) return true;
    _suspended = true;
    _sub?.cancel();
    _sub = null;
    try {
      _socket.destroy();
    } catch (_) {}
    _setStalled(true);
    return true;
  }

  /// 나가 있던(또는 응답이 없던) 이 연결에, 방금 들어온 연결 [fresh]의 소켓을 이어 붙인다.
  /// [fresh]는 방이 받은 새 연결이고 첫 인사(`hello`)를 이미 읽은 상태여야 한다. 이 뒤로 이 연결은 새 소켓으로 말한다.
  void adopt(LanConnection fresh) {
    if (isClosed || fresh.isClosed) {
      fresh.close();
      return;
    }
    _sub?.cancel();
    try {
      _socket.destroy();
    } catch (_) {}
    _socket = fresh._socket;
    _peerAddress = fresh._peerAddress;
    // 새 연결은 소켓만 빌려주는 문지기가 된다: 받은 것은 이 연결로 넘기고, 신호·화면 켜 두기는 이 연결이 맡는다
    fresh._forwardTo = this;
    fresh._timer.cancel();
    fresh._releaseAwake();
    _queue.addAll(fresh._queue);
    fresh._queue.clear();
    _suspended = false;
    _lastRx = DateTime.now();
    _lastTick = _lastRx;
    stalledSince = null;
    decisionSnoozedUntil = null;
    _publishStalled();
    _drain();
  }

  void _releaseAwake() {
    if (!_holdsAwake) return;
    _holdsAwake = false;
    KeepAwake.release();
  }

  void _finish() {
    if (_closed.isCompleted) return;
    _closed.complete();
    _releaseAwake();
    _timer.cancel();
    _suspended = false;
    _cpuCovered = false;
    stalledSince = null;
    _publishStalled();
    _sub?.cancel();
    try {
      _socket.destroy();
    } catch (_) {}
    _messages.close();
  }

  /// 연결을 닫는다 (상대에게는 끊김으로 보인다).
  Future<void> close() async {
    if (isClosed) return;
    if (!_suspended) {
      try {
        await _socket.flush();
      } catch (_) {}
    }
    _finish();
  }
}
