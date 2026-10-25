import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:flutter/material.dart';

import '../core/settings_scope.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';
import 'lan_rejoin.dart';

export 'lan_join_screen.dart';
export 'lan_lobby_screen.dart';

/// 같은 Wi‑Fi로 함께 하기의 공통 화면들: 첫 화면(방 만들기 / 방 찾기), 방을 열고 기다리는 화면, 방을 찾아 들어가는 화면.
///
/// 게임마다 다른 것(방 이름, 방 정보 글, 시작할 때 주고받는 메시지, 게임 화면)만 매개변수로 받는다.
/// 이어진 뒤의 수 주고받기는 각 게임 화면이 [LanConnection]으로 직접 한다.

/// 방을 만드는 쪽이 "내 쪽"을 상대가 들어올 때 무작위로 정하겠다고 할 때의 값.
const int kRandomSide = -1;

/// 방 크기 글: CPU가 없으면 "3명", 있으면 "4명 (사람 3 + CPU 1)".
String roomSizeText(int players, int cpus) => cpus > 0 ? '$players명 (사람 ${players - cpus} + CPU $cpus)' : '$players명';

/// 같은 Wi‑Fi 안에서 이 기기를 가리키는 짧은 "방 번호": 주소의 마지막 숫자 (예: 192.168.0.37 → 37).
/// 방 목록에 방이 안 떠도 이 번호만 입력하면 들어갈 수 있다. (주소가 없으면 null)
String? roomNumberOf(List<String> addresses) => addresses.isEmpty ? null : addresses.first.split('.').last;

/// 방 번호나 주소 입력 [text]를 (주소, 포트)로 바꾼다. 번호만 쓰면 이 기기의 Wi‑Fi 주소 앞부분([myAddresses])을 붙인다. 못 바꾸면 null.
({String host, int port})? parseRoomInput(String text, List<String> myAddresses) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final parts = t.split(':');
  final port = parts.length > 1 ? int.tryParse(parts[1]) : kLanGamePort;
  if (parts.length > 2 || port == null || port <= 0 || port > 65535) return null;
  final host = parts[0].trim();
  final number = int.tryParse(host);
  if (number != null && !host.contains('.')) {
    if (number < 1 || number > 254 || myAddresses.isEmpty) return null;
    final mine = myAddresses.first.split('.');
    return (host: '${mine.take(3).join('.')}.$number', port: port);
  }
  return InternetAddress.tryParse(host)?.type == InternetAddressType.IPv4 ? (host: host, port: port) : null;
}

/// 손님이 들어왔을 때 게임이 정하는 것: 손님에게 보낼 시작 메시지(`t: 'start'`)와, 방을 연 쪽이 띄울 게임 화면.
///
/// 게임 화면은 손님 연결과 함께 "다시 들어오기 접수처"([LanRejoinDesk])를 받는다. 판이 시작된 뒤에도 방 문을 열어 두고,
/// 나갔던 손님이 돌아오면 이 접수처가 받아 준다 (게임 화면이 `VsTwoPlayer`로 처리한다).
class LanStart {
  const LanStart({required this.message, required this.hostScreen});

  final Map<String, dynamic> message;
  final Widget Function(LanConnection conn, LanRejoinDesk desk) hostScreen;
}

/// 같은 Wi‑Fi로 함께 하기 첫 화면: 곧바로 열려 있는 방을 찾는 화면([LanJoinScreen])이고,
/// 위에는 별명, 아래에는 "방 만들기" 단추가 붙는다 ([LanHubScope]로 그 정보를 아래 화면에 알려 준다).
class LanChooseScreen extends StatelessWidget {
  const LanChooseScreen({
    super.key,
    required this.title,
    required this.color,
    required this.recordsGame,
    required this.createRoom,
    required this.findRoom,
  });

  /// 앱바 제목 (예: "예언 · 같은 Wi‑Fi로 함께").
  final String title;
  final Color color;

  /// 내 기록 버튼이 여는 게임 id.
  final String recordsGame;

  /// "방 만들기"가 여는 화면 (보통 방의 설정 화면).
  final WidgetBuilder createRoom;

  /// 방 찾기 화면 ([LanJoinScreen]을 돌려주면 된다).
  final WidgetBuilder findRoom;

  @override
  Widget build(BuildContext context) {
    return LanHubScope(
      title: title,
      color: color,
      recordsGame: recordsGame,
      createRoom: createRoom,
      child: Builder(builder: findRoom),
    );
  }
}

/// [LanChooseScreen]이 아래의 방 찾기 화면에 건네는 정보. 있으면 방 찾기 화면이 제목·내 기록·모드 전환·별명(위)과
/// "방 만들기" 단추(아래)를 함께 보여 준다.
class LanHubScope extends InheritedWidget {
  const LanHubScope({
    super.key,
    required this.title,
    required this.color,
    required this.recordsGame,
    required this.createRoom,
    required super.child,
  });

  final String title;
  final Color color;
  final String recordsGame;
  final WidgetBuilder createRoom;

  static LanHubScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LanHubScope>();

  @override
  bool updateShouldNotify(LanHubScope old) => title != old.title || color != old.color || recordsGame != old.recordsGame;
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class LanHostScreen extends StatefulWidget {
  const LanHostScreen({
    super.key,
    required this.game,
    required this.gameName,
    required this.info,
    required this.summary,
    required this.onGuest,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 게임 id (방 찾기에서 같은 게임끼리만 보인다).
  final String game;

  /// 안내 글에 나올 게임 이름.
  final String gameName;

  /// 방을 찾는 기기에게 알려 줄 방 정보 (JSON으로 보낼 수 있는 값만).
  final Map<String, dynamic> info;

  /// 기다리는 화면에 보일 방 설정 글 (한 줄씩).
  final List<String> summary;

  /// 손님이 들어왔을 때 시작 메시지와 방을 연 쪽의 게임 화면을 정한다.
  final LanStart Function() onGuest;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  State<LanHostScreen> createState() => _LanHostScreenState();
}

class _LanHostScreenState extends State<LanHostScreen> {
  /// 이 방의 이름 = 방을 연 사람의 별명 (방 찾기 목록과 이 화면에 보인다).
  late String _roomName;
  bool _opened = false;
  LanHost? _host;
  StreamSubscription<LanConnection>? _sub;
  List<String> _addresses = const [];
  String? _error;
  bool _starting = false;

  /// 시작한 뒤의 "다시 들어오기 접수처" (방 문을 열어 둔다). 이 화면이 사라질 때 같이 닫는다.
  LanRejoinDesk? _desk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    _roomName = SettingsScope.of(context).nickname;
    _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final host = await LanHost.open(
        game: widget.game,
        info: {...widget.info, 'room': _roomName, 'nick': _roomName},
        gamePort: widget.gamePort,
        discoveryPort: widget.discoveryPort,
      );
      if (!mounted) {
        await host.close();
        return;
      }
      _host = host;
      _sub = host.guests.listen(_onGuest);
      final addresses = await localLanAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (_) {
      if (mounted) setState(() => _error = '방을 열 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  Future<void> _onGuest(LanConnection conn) async {
    if (_starting) {
      conn.close();
      return;
    }
    _starting = true;
    final start = widget.onGuest();
    final host = _host!;
    _host = null;
    // 방 문은 닫지 않고 접수처에 넘긴다: 나갔던 손님이 (앱을 껐다 켜도) 표를 들고 다시 들어올 수 있게
    final desk = _desk = LanRejoinDesk.open(host: host, guests: [conn], info: {...widget.info, 'room': _roomName, 'nick': _roomName});
    conn.send({'t': 'start', 'nick': _roomName, 'rejoin': desk.ticketFor(0), ...start.message});
    if (!mounted) {
      conn.close();
      await desk.close();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => start.hostScreen(conn, desk)));
    await desk.close();
    // 게임에서 나오면 방도 끝난 것이니 방 설정 화면으로 돌아간다.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
    _desk?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('상대를 기다리는 중', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null) ...[
                  Icon(Icons.wifi_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _open, child: const Text('다시 시도')),
                ] else ...[
                  const Center(child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5))),
                  const SizedBox(height: 18),
                  const Text('방이 열렸어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '다른 기기에서 ${widget.gameName} → "같은 Wi‑Fi로 함께" → "방 찾기"를 눌러\n이 방에 들어오면 바로 시작해요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 20),
                  LanInfoCard(
                    title: '우리 방 이름 (내 별명)',
                    lines: [_roomName, if (roomNumberOf(_addresses) != null) '방 번호 ${roomNumberOf(_addresses)}'],
                    big: true,
                  ),
                  const SizedBox(height: 12),
                  LanInfoCard(lines: widget.summary),
                  const SizedBox(height: 12),
                  LanInfoCard(
                    title: '방이 안 보이면, 상대 기기에 방 번호나 이 주소를 입력하세요',
                    lines: [
                      if (_addresses.isEmpty) 'Wi‑Fi 주소를 찾지 못했어요. Wi‑Fi에 연결되어 있는지 확인해 주세요.',
                      for (final a in _addresses) _host != null && _host!.port != kLanGamePort ? '$a:${_host!.port}' : a,
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 글 몇 줄이 든 둥근 상자.
class LanInfoCard extends StatelessWidget {
  const LanInfoCard({super.key, this.title, required this.lines, this.big = false});

  final String? title;
  final List<String> lines;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65))),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(l, textAlign: TextAlign.center, style: TextStyle(fontSize: big ? 22 : 15, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}
