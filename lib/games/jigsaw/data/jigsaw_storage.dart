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

/// 진행 중인 퍼즐과 기록을 기기에 저장한다.
class JigsawStorage {
  JigsawStorage._();

  static const _saveKey = 'jigsaw.save';

  /// 지금 화면에서 하고 있는 판 (새 판으로 바뀐 뒤 이전 화면이 늦게 저장해 덮어쓰는 일을 막는다).
  static JigsawController? _active;

  static void setActive(JigsawController c) => _active = c;

  static Future<void> save(JigsawController c, JigsawSource source, int pieceTarget) async {
    if (!identical(c, _active) || c.completed || source.kind == 'none') return;
    // 화면이 정리되기 전에 지금 상태를 먼저 문자열로 굳혀 둔다.
    final json = jsonEncode({
      'state': c.toJson(),
      'source': source.toJson(),
      'target': pieceTarget,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, json);
  }

  static Future<JigsawSave?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return JigsawSave(
        state: j['state'] as Map<String, dynamic>,
        source: JigsawSource.fromJson(j['source'] as Map<String, dynamic>),
        pieceTarget: j['target'] as int,
      );
    } catch (_) {
      await prefs.remove(_saveKey);
      return null;
    }
  }

  static Future<void> clear(JigsawController c) async {
    if (!identical(c, _active)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
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

  /// 지금 필요한 사진(최근 기록 + 이어하기)만 남기고 나머지를 정리한다.
  static Future<void> pruneAfterHistoryChange() async {
    final keep = <String>{
      for (final r in await JigsawHistory.load())
        if (r.source.kind == 'file') r.source.ref,
    };
    final save = await load();
    if (save != null && save.source.kind == 'file') keep.add(save.source.ref);
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
