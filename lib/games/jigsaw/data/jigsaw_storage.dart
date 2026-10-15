import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/jigsaw_controller.dart';
import '../ui/jigsaw_images.dart';
import 'jigsaw_history.dart';

class JigsawSave {
  const JigsawSave({required this.state, required this.source, required this.pieceTarget});

  final Map<String, dynamic> state;
  final JigsawSource source;

  /// 처음에 고른 목표 조각 수 (12/24/48/96).
  final int pieceTarget;
}

/// 내 퍼즐 보관함의 한 칸: 같은 그림(출처)으로 만든 퍼즐 하나.
///
/// 갤러리 사진으로 만든 퍼즐은 지우기 전까지 남고, 그림마다 이어하던 판을 따로 저장한다.
/// 샘플 그림은 이어하던 판이 있는 동안에만 보관함에 나타난다.
class JigsawEntry {
  const JigsawEntry({
    required this.source,
    required this.updatedAt,
    this.pieceTarget = 24,
    this.state,
    this.wins = 0,
  });

  final JigsawSource source;

  /// 마지막으로 하거나 만든 때 (ms).
  final int updatedAt;

  /// 마지막으로 고른 조각 수 (12/24/48/96).
  final int pieceTarget;

  /// 이어하던 판의 저장 상태 (없으면 null = 새로 시작할 수 있는 그림).
  final Map<String, dynamic>? state;

  /// 이 그림을 완성한 횟수.
  final int wins;

  bool get inProgress => state != null;

  /// 이어하던 판에서 맞춘 조각 수 / 전체 조각 수.
  (int, int) get progress {
    final placed = state?['placed'] as List?;
    if (placed == null) return (0, 0);
    return (placed.where((v) => v == 1).length, placed.length);
  }

  JigsawSave? get save =>
      state == null ? null : JigsawSave(state: state!, source: source, pieceTarget: pieceTarget);

  bool sameSource(JigsawSource s) => source.kind == s.kind && source.ref == s.ref;

  JigsawEntry copyWith({int? updatedAt, int? pieceTarget, Map<String, dynamic>? state, bool clearState = false, int? wins}) =>
      JigsawEntry(
        source: source,
        updatedAt: updatedAt ?? this.updatedAt,
        pieceTarget: pieceTarget ?? this.pieceTarget,
        state: clearState ? null : (state ?? this.state),
        wins: wins ?? this.wins,
      );

  Map<String, dynamic> toJson() => {
        'src': source.toJson(),
        'at': updatedAt,
        'target': pieceTarget,
        if (state != null) 'state': state,
        'wins': wins,
      };

  static JigsawEntry fromJson(Map<String, dynamic> j) => JigsawEntry(
        source: JigsawSource.fromJson(j['src'] as Map<String, dynamic>),
        updatedAt: j['at'] as int,
        pieceTarget: j['target'] as int,
        state: j['state'] as Map<String, dynamic>?,
        wins: (j['wins'] as int?) ?? 0,
      );
}

/// 진행 중인 퍼즐과 기록을 기기에 저장한다.
class JigsawStorage {
  JigsawStorage._();

  /// 예전 버전의 "이어하기 한 칸" 저장 (보관함으로 옮겨 담은 뒤 지운다).
  static const _legacySaveKey = 'jigsaw.save';
  static const _libraryKey = 'jigsaw.library';

  /// 보관함에 둘 수 있는 퍼즐 수. 넘치면 오래된 것부터 정리한다 (사진 파일도 함께 보관하므로).
  static const maxEntries = 40;

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static JigsawController? _active;

  static void setActive(JigsawController c) => _active = c;

  // 보관함은 "읽기 → 고치기 → 쓰기"를 중간에 기다리는 곳(await) 없이 한 번에 끝낸다.
  // 그러면 여러 저장이 동시에 와도 서로 덮어쓰지 않는다 (SharedPreferences 의 메모리 값은 바로 바뀐다).
  static List<JigsawEntry> _read(SharedPreferences prefs) {
    final out = <JigsawEntry>[];
    final raw = prefs.getString(_libraryKey);
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          out.add(JigsawEntry.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        unawaited(prefs.remove(_libraryKey));
        out.clear();
      }
    }
    // 예전 형식의 이어하기 저장이 있으면 보관함으로 옮긴다
    final legacy = prefs.getString(_legacySaveKey);
    if (legacy != null) {
      try {
        final j = jsonDecode(legacy) as Map<String, dynamic>;
        final source = JigsawSource.fromJson(j['source'] as Map<String, dynamic>);
        if (source.kind != 'none' && !out.any((e) => e.sameSource(source))) {
          out.add(JigsawEntry(
            source: source,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            pieceTarget: j['target'] as int,
            state: j['state'] as Map<String, dynamic>,
          ));
        }
      } catch (_) {}
      unawaited(prefs.remove(_legacySaveKey));
      unawaited(_commit(prefs, out));
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static Future<void> _commit(SharedPreferences prefs, List<JigsawEntry> list) {
    // 넘치면 이어하던 판이 없는 오래된 퍼즐부터, 그래도 넘치면 오래된 것부터 뺀다
    final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    while (sorted.length > maxEntries) {
      final idle = sorted.lastIndexWhere((e) => !e.inProgress);
      sorted.removeAt(idle >= 0 ? idle : sorted.length - 1);
    }
    return prefs.setString(_libraryKey, jsonEncode([for (final e in sorted) e.toJson()]));
  }

  /// 내 퍼즐 보관함 (최근에 한 순서).
  static Future<List<JigsawEntry>> library() async => _read(await SharedPreferences.getInstance());

  /// 이 그림의 보관함 칸. 없으면 null.
  static Future<JigsawEntry?> entryFor(JigsawSource source) async {
    for (final e in await library()) {
      if (e.sameSource(source)) return e;
    }
    return null;
  }

  /// 진행 중인 판을 저장한다. 이 그림이 보관함에 없으면 새로 넣는다.
  static Future<void> save(JigsawController c, JigsawSource source, int pieceTarget) async {
    if (!identical(c, _active) || c.completed || c.gaveUp || source.kind == 'none') return;
    // 화면이 정리되기 전에 지금 상태를 먼저 굳혀 둔다.
    final state = jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs);
    final now = DateTime.now().millisecondsSinceEpoch;
    final at = list.indexWhere((e) => e.sameSource(source));
    if (at >= 0) {
      list[at] = list[at].copyWith(updatedAt: now, pieceTarget: pieceTarget, state: state);
    } else {
      list.add(JigsawEntry(source: source, updatedAt: now, pieceTarget: pieceTarget, state: state));
    }
    await _commit(prefs, list);
  }

  /// 판을 완성했을 때: 이어하던 판을 지운다. 갤러리 사진은 보관함에 남기고, 샘플은 보관함에서도 뺀다.
  static Future<void> clear(JigsawController c, JigsawSource source) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs);
    final at = list.indexWhere((e) => e.sameSource(source));
    if (at < 0) return;
    if (source.kind == 'file') {
      list[at] = list[at].copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        clearState: true,
        wins: list[at].wins + 1,
      );
    } else {
      list.removeAt(at);
    }
    await _commit(prefs, list);
  }

  /// 판을 포기했을 때: 이어하던 판을 지운다 (완성한 것이 아니니 완성 횟수는 올리지 않는다).
  /// 갤러리 사진은 보관함에 남기고, 샘플은 보관함에서도 뺀다. 다시 하려면 기록의 "포기한 판"에서 한다.
  static Future<void> abandon(JigsawController c, JigsawSource source) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs);
    final at = list.indexWhere((e) => e.sameSource(source));
    if (at < 0) return;
    if (source.kind == 'file') {
      list[at] = list[at].copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch, clearState: true);
    } else {
      list.removeAt(at);
    }
    await _commit(prefs, list);
  }

  /// 보관함에서 퍼즐을 지운다 (이어하던 판도 함께). 더 이상 쓰이지 않는 사진 파일은 정리된다.
  static Future<void> remove(JigsawSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _read(prefs)..removeWhere((e) => e.sameSource(source));
    await _commit(prefs, list);
    await pruneAfterHistoryChange();
  }

  /// 갤러리에서 고른 사진을 앱 안에 복사해 둔다 (이어하기·기록에서 다시 하기 위해). 실패하면 null.
  /// 판마다 다른 파일 이름을 쓰고, 더 이상 쓰이지 않는 오래된 사진은 [pruneFiles]가 정리한다.
  static Future<String?> storePhoto(Uint8List bytes) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = 'jigsaw_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// 기록(최근 판들)이나 이어하기에 쓰이지 않는 사진 파일을 지운다.
  static Future<void> pruneFiles(Iterable<String> keepPaths) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final keep = keepPaths.toSet();
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (name.startsWith('jigsaw_') && name.endsWith('.jpg') && !keep.contains(e.path)) {
          await e.delete();
        }
      }
    } catch (_) {}
  }

  /// 지금 필요한 사진(최근 기록 + 내 퍼즐 보관함)만 남기고 나머지를 정리한다.
  static Future<void> pruneAfterHistoryChange() async {
    final keep = <String>{
      for (final r in await JigsawHistory.load())
        if (r.source.kind == 'file') r.source.ref,
      for (final r in await JigsawHistory.favorites.load())
        if (r.source.kind == 'file') r.source.ref,
      for (final e in await library())
        if (e.source.kind == 'file') e.source.ref,
    };
    await pruneFiles(keep);
  }

  /// 저장된 출처에서 그림을 다시 불러온다. 못 불러오면 null.
  static Future<ui.Image?> loadImage(JigsawSource source) async {
    try {
      switch (source.kind) {
        case 'sample':
          return await SampleArt.render(source.ref);
        case 'file':
          return await decodeImageBytes(await File(source.ref).readAsBytes());
      }
    } catch (_) {}
    return null;
  }

  // ── 기록 (조각 수별 최단 시간) ──

  static Future<int?> bestSeconds(int pieceTarget) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('jigsaw.best.$pieceTarget');
  }

  static Future<int> wins(int pieceTarget) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('jigsaw.wins.$pieceTarget') ?? 0;
  }

  /// 완성 기록. 최단 기록이면 true.
  static Future<bool> recordWin(int pieceTarget, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('jigsaw.wins.$pieceTarget', (prefs.getInt('jigsaw.wins.$pieceTarget') ?? 0) + 1);
    final best = prefs.getInt('jigsaw.best.$pieceTarget');
    if (best == null || seconds < best) {
      await prefs.setInt('jigsaw.best.$pieceTarget', seconds);
      return true;
    }
    return false;
  }
}
