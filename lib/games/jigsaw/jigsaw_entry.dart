import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/jigsaw_geometry.dart';
import 'data/jigsaw_history.dart';
import 'data/jigsaw_storage.dart';
import 'game/jigsaw_controller.dart';
import 'ui/jigsaw_images.dart';
import 'ui/jigsaw_menu_screen.dart';
import 'ui/jigsaw_screen.dart';

/// 허브(game_registry)에서 직소퍼즐을 열 때 쓰는 진입점.
Widget buildJigsaw(BuildContext context, PlayMode mode) => const JigsawMenuScreen();

/// 목표 조각 수 선택지.
const List<(int, String)> kPieceChoices = [
  (12, '아주 쉬움'),
  (24, '쉬움'),
  (48, '보통'),
  (96, '어려움'),
];

/// 퍼즐로 만들 그림 한 장.
class PickedImage {
  const PickedImage({required this.image, required this.source, this.bytes});

  final ui.Image image;

  /// 갤러리에서 고른 사진이면 원본 바이트 (이어하기용으로 앱 안에 복사해 둔다).
  final Uint8List? bytes;
  final JigsawSource source;
}

/// 한 판을 진행하는 데 필요한 것들의 묶음 (화면이 끝나면 함께 정리된다).
class JigsawSession {
  JigsawSession({
    required this.image,
    required this.pieces,
    required this.controller,
    required this.source,
    required this.pieceTarget,
  });

  final ui.Image image;
  final PieceImages pieces;
  final JigsawController controller;
  final JigsawSource source;
  final int pieceTarget;

  void dispose() {
    controller.dispose();
    pieces.dispose();
    image.dispose();
  }
}

/// 새 퍼즐을 만들어 시작한다.
Future<void> startJigsawGame(
  BuildContext context,
  PickedImage pick, {
  required int pieceTarget,
  required bool ghost,

  /// true면 지금 화면(설정 화면)을 퍼즐 화면으로 바꾸고, false면 그 위에 새로 연다 (기록에서 다시 할 때).
  bool replace = true,
}) async {
  final navigator = Navigator.of(context);
  // 퍼즐 화면의 대략적인 가로세로비 (위아래 막대를 뺀 영역)
  final screen = MediaQuery.sizeOf(context);
  final tableAspect = screen.width / max(1.0, screen.height - 200);
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: Center(child: _BuildingCard(progress: progress))),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));

  var source = pick.source;
  if (pick.bytes != null) {
    final path = await JigsawStorage.storePhoto(pick.bytes!);
    source = path == null ? JigsawSource.none : JigsawSource('file', path);
  }

  final image = pick.image;
  final (rows, cols) = JigsawGeometry.gridFor(pieceTarget, image.width / image.height);
  final rng = Random();
  final geometry = JigsawGeometry(
    rows: rows,
    cols: cols,
    imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
    seed: rng.nextInt(1 << 30),
  );
  final controller = JigsawController(
    geometry: geometry,
    ghost: ghost,
    scatterSeed: rng.nextInt(1 << 30),
    tableAspect: tableAspect,
  );
  final pieces = await PieceImages.build(image, geometry, onProgress: (p) => progress.value = p);
  navigator.pop(); // 만드는 중 창 닫기
  progress.dispose();
  final route = MaterialPageRoute<void>(
    builder: (_) => JigsawScreen(
      session: JigsawSession(
        image: image,
        pieces: pieces,
        controller: controller,
        source: source,
        pieceTarget: pieceTarget,
      ),
    ),
  );
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 기록에서 고른 퍼즐을 같은 그림·같은 조각 수로 처음부터 다시 한다.
/// 이어하던 판이 있으면 먼저 물어보고, 그림을 못 불러오면 안내한다.
Future<void> replayJigsawRecord(BuildContext context, JigsawRecord record) async {
  final saved = await JigsawStorage.load();
  if (!context.mounted) return;
  if (saved != null) {
    final ok = await confirmOverwrite(context, gameName: '직소퍼즐');
    if (!ok || !context.mounted) return;
  }
  final image = await JigsawStorage.loadImage(record.source);
  if (!context.mounted) return;
  if (image == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('그림 파일을 찾을 수 없어서 다시 할 수 없어요.')));
    return;
  }
  await startJigsawGame(
    context,
    PickedImage(image: image, source: record.source),
    pieceTarget: record.target,
    ghost: true,
    replace: false,
  );
}

/// 저장된 퍼즐을 이어서 한다. 그림을 못 불러오면 false.
Future<bool> resumeJigsawGame(BuildContext context, JigsawSave save) async {
  final navigator = Navigator.of(context);
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: Center(child: _BuildingCard(progress: progress))),
  );
  await Future<void>.delayed(const Duration(milliseconds: 60));
  final image = await JigsawStorage.loadImage(save.source);
  if (image == null) {
    navigator.pop();
    progress.dispose();
    return false;
  }
  final controller = JigsawController.fromJson(save.state);
  final pieces = await PieceImages.build(image, controller.geometry,
      onProgress: (p) => progress.value = p);
  navigator.pop();
  progress.dispose();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => JigsawScreen(
        session: JigsawSession(
          image: image,
          pieces: pieces,
          controller: controller,
          source: save.source,
          pieceTarget: save.pieceTarget,
        ),
      ),
    ),
  );
  return true;
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({required this.progress});

  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v == 0 ? null : v,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('퍼즐 조각을 만드는 중…', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
