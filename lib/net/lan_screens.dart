import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:flutter/material.dart';

import '../core/nickname.dart';
import '../core/settings_scope.dart';
import '../records/records_screen.dart';
import 'lan_connection.dart';
import 'lan_discovery.dart';

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
class LanStart {
  const LanStart({required this.message, required this.hostScreen});

  final Map<String, dynamic> message;
  final Widget Function(LanConnection conn) hostScreen;
}

/// 같은 Wi‑Fi로 함께 하기 첫 화면.
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

  /// "방 찾기"가 여는 화면.
  final WidgetBuilder findRoom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: recordsGame),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const NicknameBar(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_rounded, size: 48, color: color),
                      const SizedBox(height: 10),
                      const Text('같은 Wi‑Fi에 연결된 두 기기가 있으면\n서로 마주 보지 않아도 겨룰 수 있어요', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
                      const SizedBox(height: 8),
                      Text(
                        '한 기기에서 방을 만들고, 다른 기기에서 그 방을 찾아 들어오세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: createRoom)),
                  icon: const Icon(Icons.add_home_work_rounded),
                  label: const Text('방 만들기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: findRoom)),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('방 찾기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '공용 Wi‑Fi나 손님용 Wi‑Fi 중에는 기기끼리의 연결을 막아 둔 곳이 있어요. 방이 보이지 않으면 방을 만든 기기의 주소를 직접 입력해 보세요.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    conn.send({'t': 'start', 'nick': _roomName, ...start.message});
    await _host?.close(); // 방은 닫는다 (이미 이어진 연결은 그대로)
    _host = null;
    if (!mounted) {
      conn.close();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => start.hostScreen(conn)));
    // 게임에서 나오면 방도 끝난 것이니 방 설정 화면으로 돌아간다.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
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

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class LanJoinScreen extends StatefulWidget {
  const LanJoinScreen({
    super.key,
    required this.game,
    required this.color,
    required this.roomTitle,
    required this.roomSubtitle,
    required this.buildGame,
    this.discoveryPort = kLanDiscoveryPort,
    this.extraTargets = const [],
  });

  final String game;
  final Color color;

  /// 방 목록 한 줄의 제목·보조 글 (방 정보 [LanRoom.info]로 만든다).
  final String Function(LanRoom room) roomTitle;
  final String Function(LanRoom room) roomSubtitle;

  /// 방에서 온 시작 메시지로 이 기기의 게임 화면을 만든다. 메시지가 잘못됐으면 null.
  final Widget? Function(Map<String, dynamic> start, LanConnection conn) buildGame;

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  State<LanJoinScreen> createState() => _LanJoinScreenState();
}

class _LanJoinScreenState extends State<LanJoinScreen> {
  LanFinder? _finder;
  StreamSubscription<List<LanRoom>>? _sub;
  List<LanRoom> _rooms = const [];
  bool _connecting = false;
  String? _message;

  /// 여러 명이 모이는 방에 들어가 기다리는 중일 때: 지금 들어온 사람들 이름과 필요한 인원, 그 방과의 연결.
  List<String>? _lobbyNames;
  int? _lobbyNeed;
  LanConnection? _lobbyConn;
  bool _cancelled = false;
  final TextEditingController _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startFinder();
  }

  /// 방 이름 (옛 버전이 연 방처럼 이름이 없으면 주소 끝 숫자로).
  String _nameOf(LanRoom r) => r.info['room'] is String ? r.info['room'] as String : '${r.address.split('.').last}번 방';

  Future<void> _startFinder() async {
    try {
      final finder = await LanFinder.start(game: widget.game, discoveryPort: widget.discoveryPort, extraTargets: widget.extraTargets);
      if (!mounted) {
        finder.close();
        return;
      }
      _finder = finder;
      _sub = finder.rooms.listen((r) {
        if (mounted) setState(() => _rooms = r);
      });
    } catch (_) {
      if (mounted) setState(() => _message = '방을 찾을 수 없어요. 이 기기가 Wi‑Fi에 연결되어 있는지 확인해 주세요.');
    }
  }

  void _stopFinder() {
    _sub?.cancel();
    _finder?.close();
    _sub = null;
    _finder = null;
    _rooms = const [];
  }

  @override
  void dispose() {
    _stopFinder();
    _address.dispose();
    super.dispose();
  }

  Future<void> _join(String host, int port) async {
    if (_connecting) return;
    final nick = SettingsScope.of(context).nickname;
    setState(() {
      _connecting = true;
      _message = null;
    });
    LanConnection? conn;
    var started = false;
    _cancelled = false;
    try {
      conn = await LanConnection.connect(host, port);
      conn.send({'t': 'hello', 'game': widget.game, 'nick': nick});
      // 방이 시작 메시지를 보낼 때까지 기다린다. 여러 명이 모이는 방은 `lobby`(들어온 사람 목록)를 보내 주고,
      // 그때는 방장이 시작할 때까지 얼마든지 기다린다. (그런 소식이 없는 방은 8초 안에 시작하지 않으면 실패)
      final startC = Completer<Map<String, dynamic>>();
      Timer? limit = Timer(const Duration(seconds: 8), () {
        if (!startC.isCompleted) startC.completeError(TimeoutException('start'));
      });
      final sub = conn.messages.listen((m) {
        final t = m['t'];
        if (t == 'lobby') {
          limit?.cancel();
          limit = null;
          final names = m['names'];
          if (mounted && names is List) setState(() => _lobbyNames = [for (final n in names) '$n']);
          _lobbyNeed = m['need'] is int ? m['need'] as int : null;
        } else if ((t == 'start' || t == 'busy') && !startC.isCompleted) {
          startC.complete(m);
        }
      });
      conn.closed.then((_) {
        if (!startC.isCompleted) startC.completeError(StateError('closed'));
      });
      _lobbyConn = conn;
      final Map<String, dynamic> m;
      try {
        m = await startC.future;
      } finally {
        limit?.cancel();
        await sub.cancel();
        _lobbyConn = null;
        if (mounted) setState(() => _lobbyNames = null);
      }
      if (m['t'] == 'busy') {
        conn.close();
        if (mounted) setState(() => _message = '이미 다른 기기가 이 방에 들어와 있어요.');
        return;
      }
      conn.peer = m;
      final screen = widget.buildGame(m, conn);
      if (screen == null) throw const FormatException('start');
      if (!mounted) {
        conn.close();
        return;
      }
      started = true;
      _stopFinder();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
      if (mounted) _startFinder();
    } catch (_) {
      conn?.close();
      if (mounted && !started && !_cancelled) setState(() => _message = '방에 들어갈 수 없어요. 방이 아직 열려 있는지, 같은 Wi‑Fi인지 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// 모이는 중인 방에서 기다리다 나온다.
  void _leaveLobby() {
    _cancelled = true;
    _lobbyConn?.close();
  }

  /// 방 번호("37"), 주소("192.168.0.37") 또는 "192.168.0.37:45822".
  Future<void> _joinTyped() async {
    if (_address.text.trim().isEmpty) return;
    final target = parseRoomInput(_address.text, await localLanAddresses());
    if (target == null) {
      if (mounted) setState(() => _message = '방 번호나 주소를 다시 확인해 주세요. (예: 37 또는 192.168.0.37)');
      return;
    }
    _join(target.host, target.port);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('방 찾기', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_lobbyNames != null) ...[
                  LanInfoCard(
                    title: '방장이 시작하기를 기다리는 중이에요${_lobbyNeed == null ? '' : ' (${_lobbyNames!.length}/$_lobbyNeed명)'}',
                    lines: _lobbyNames!,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _leaveLobby, icon: const Icon(Icons.logout_rounded), label: const Text('방에서 나가기')),
                  const SizedBox(height: 16),
                ],
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: scheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_message!, style: const TextStyle(fontSize: 14, height: 1.35))),
                      ],
                    ),
                  ),
                Text('열려 있는 방', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_rooms.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
                        const SizedBox(height: 14),
                        const Text('같은 Wi‑Fi의 방을 찾는 중…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '다른 기기에서 "방 만들기 → 방 열기"를 먼저 눌러 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in _rooms)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scheme.outlineVariant)),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(Icons.wifi_rounded, color: widget.color),
                        ),
                        title: Text(widget.roomTitle(r), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_nameOf(r)} 방 · ${r.address.split('.').last}번', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.color)),
                            Text(widget.roomSubtitle(r), style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                        trailing: FilledButton(onPressed: _connecting ? null : () => _join(r.address, r.port), child: const Text('들어가기')),
                      ),
                    ),
                const SizedBox(height: 24),
                Text('방 번호로 들어가기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '방이 위에 안 보이면, 방을 만든 기기 화면에 나온 방 번호(또는 주소)를 입력하세요.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _address,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _joinTyped(),
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '방 번호 또는 주소', hintText: '37  또는  192.168.0.37', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: _connecting ? null : _joinTyped, child: const Text('들어가기')),
                  ],
                ),
                if (_connecting) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 방이 다 찼을 때 게임이 정하는 것: 손님마다 보낼 시작 메시지(`t: 'start'`, 들어온 순서대로)와, 방을 연 쪽이 띄울 게임 화면.
class LanLobbyPlan {
  const LanLobbyPlan({required this.messages, required this.hostScreen});

  final List<Map<String, dynamic>> messages;
  final Widget Function(List<LanConnection> guests) hostScreen;
}

/// 여러 명이 모이는 방: 방을 열고 [needGuests]명이 모두 들어오면 저절로 시작한다.
///
/// 들어온 사람의 이름은 방 화면에 모두 보이고, 손님들 화면에도 같은 목록이 보인다 (`lobby` 메시지).
/// 기다리는 동안 누가 나가면 목록에서 빠지고 그 자리는 다시 빈다. (한 명만 기다리는 게임은 [LanHostScreen])
class LanLobbyScreen extends StatefulWidget {
  const LanLobbyScreen({
    super.key,
    required this.game,
    required this.gameName,
    required this.info,
    required this.summary,
    required this.needGuests,
    required this.onFull,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  final String game;
  final String gameName;

  /// 방을 찾는 기기에게 알려 줄 방 정보. 들어온 사람 수(`joined`)와 필요한 사람 수(`need`)는 이 화면이 채운다.
  final Map<String, dynamic> info;
  final List<String> summary;

  /// 방장 말고 더 필요한 사람 수.
  final int needGuests;

  /// 방이 찼을 때 시작 메시지들과 방장의 게임 화면을 정한다. 손님은 들어온 순서대로 주어진다.
  final LanLobbyPlan Function(List<LanConnection> guests) onFull;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  State<LanLobbyScreen> createState() => _LanLobbyScreenState();
}

class _LanLobbyScreenState extends State<LanLobbyScreen> {
  late String _roomName;
  bool _opened = false;
  LanHost? _host;
  StreamSubscription<LanConnection>? _sub;
  List<String> _addresses = const [];
  String? _error;
  bool _starting = false;
  final List<LanConnection> _guests = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    _roomName = SettingsScope.of(context).nickname;
    _open();
  }

  Map<String, dynamic> get _info => {...widget.info, 'room': _roomName, 'nick': _roomName, 'joined': _guests.length + 1, 'need': widget.needGuests + 1};

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final host = await LanHost.open(
        game: widget.game,
        info: _info,
        maxGuests: widget.needGuests,
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

  /// 방에 있는 사람들 이름 (방장 먼저, 들어온 순서대로).
  List<String> get _names => [_roomName, for (final g in _guests) g.peerNick];

  void _publish() {
    _host?.updateInfo(_info);
    final lobby = {'t': 'lobby', 'names': _names, 'need': widget.needGuests + 1};
    for (final g in _guests) {
      g.send(lobby);
    }
  }

  void _onGuest(LanConnection conn) {
    if (_starting) {
      conn.close();
      return;
    }
    _guests.add(conn);
    conn.closed.then((_) {
      if (_starting || !_guests.remove(conn)) return;
      if (mounted) setState(_publish);
    });
    if (mounted) setState(_publish);
    if (_guests.length == widget.needGuests) _start();
  }

  Future<void> _start() async {
    _starting = true;
    final guests = [..._guests];
    final plan = widget.onFull(guests);
    for (var i = 0; i < guests.length; i++) {
      guests[i].send({'t': 'start', 'nick': _roomName, ...plan.messages[i]});
    }
    await _host?.close();
    _host = null;
    if (!mounted) {
      for (final g in guests) {
        g.close();
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => plan.hostScreen(guests)));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
    if (!_starting) {
      for (final g in _guests) {
        g.close();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final need = widget.needGuests + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('사람을 기다리는 중', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent),
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
                    '다른 기기에서 ${widget.gameName} → "같은 Wi‑Fi로 함께" → "방 찾기"를 눌러\n이 방에 들어오세요. $need명이 모두 모이면 바로 시작해요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 20),
                  LanInfoCard(
                    title: '모인 사람 (${_guests.length + 1}/$need명)',
                    lines: [for (var i = 0; i < need; i++) i < _names.length ? _names[i] : '… 기다리는 중'],
                  ),
                  const SizedBox(height: 12),
                  LanInfoCard(
                    title: '우리 방 이름 (방장 별명)',
                    lines: [_roomName, if (roomNumberOf(_addresses) != null) '방 번호 ${roomNumberOf(_addresses)}'],
                    big: true,
                  ),
                  const SizedBox(height: 12),
                  LanInfoCard(lines: widget.summary),
                  const SizedBox(height: 12),
                  LanInfoCard(
                    title: '방이 안 보이면, 다른 기기에 방 번호나 이 주소를 입력하세요',
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
