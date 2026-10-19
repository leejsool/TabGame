// 사진에서 도트 캐논 기본 그림을 뽑아 `lib/games/dotcannon/core/dot_stage_data.dart`를 만든다.
// 쓰는 법은 tool/dot_stage_art/README.md. (화면 그림 읽기가 필요해서 `flutter test`로 돌린다)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/dotcannon/core/dot_assess.dart';
import 'package:tabgame/games/dotcannon/core/dot_convert.dart';
import 'package:tabgame/games/dotcannon/core/dot_enhance.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';
import 'package:tabgame/games/dotcannon/core/dot_stages.dart';

void main() {
  testWidgets('기본 그림 만들기', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory('tool/dot_stage_art');
      final specs = (jsonDecode(File('${dir.path}/stages.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
      final out = StringBuffer()
        ..writeln('// 만든 파일입니다: `flutter test tool/make_dot_stages.dart`가 `tool/dot_stage_art/stages.json`을 읽어 다시 만듭니다.')
        ..writeln("import 'dot_stages.dart';")
        ..writeln()
        ..writeln('const List<DotStageData> dotStageData = [');
      for (final s in specs) {
        final name = s['name'] as String;
        final bytes = File('${dir.path}/${s['file']}').readAsBytesSync();
        final longSide = (s['size'] as int?) ?? 32;
        final colors = (s['colors'] as int?) ?? 8;
        final capacity = (s['capacity'] as int?) ?? 4;
        final full = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
        // "exact": 이미 도트 아트인 그림(tool/prepare_dot_sprites.py로 1칸 = 1점으로 만든 PNG)을 칸 그대로 읽는다. "scale"이면 한 칸을 scale×scale 칸으로 키운다
        final exact = s['exact'] == true;
        final scale = (s['scale'] as int?) ?? 1;
        late int dw, dh;
        late List<(double, double, double, double)> cells;
        if (exact) {
          final raw = (await full.image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          final sw0 = full.image.width, sh0 = full.image.height;
          dw = sw0 * scale;
          dh = sh0 * scale;
          cells = [
            for (var y = 0; y < dh; y++)
              for (var x = 0; x < dw; x++)
                () {
                  final i = ((y ~/ scale) * sw0 + (x ~/ scale)) * 4;
                  return (raw[i].toDouble(), raw[i + 1].toDouble(), raw[i + 2].toDouble(), raw[i + 3] / 255);
                }(),
          ];
        } else {
          // 그림의 일부만 쓰고 싶을 때: crop = [왼쪽, 위, 너비, 높이] (각각 전체에 대한 비율 0..1)
          final crop = (s['crop'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 1.0, 1.0];
          final src = ui.Rect.fromLTWH(
            crop[0] * full.image.width,
            crop[1] * full.image.height,
            crop[2] * full.image.width,
            crop[3] * full.image.height,
          );
          (dw, dh) = dotSizeFor(src.width.round(), src.height.round(), longSide);
          // 도트 한 칸을 4×4 점으로 읽어서 칸마다 평균 낸다
          final rec = ui.PictureRecorder();
          ui.Canvas(rec).drawImageRect(
            full.image,
            src,
            ui.Rect.fromLTWH(0, 0, dw * 4.0, dh * 4.0),
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );
          final scaled = await rec.endRecording().toImage(dw * 4, dh * 4);
          final data = (await scaled.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          cells = boxDownsample(data, scaled.width, scaled.height, dw, dh);
        }
        // 땅 색 입히기(선택): 파랗지도 하얗지도 어둡지도 않은 칸(= 사진에서 회색빛으로 바랜 땅)을 [r, g, b] 쪽으로 섞는다. 예: 지구의 육지를 초록으로
        final land = (s['landTint'] as List?)?.map((e) => (e as num).toDouble()).toList();
        if (land != null) {
          cells = [
            for (final c in cells)
              () {
                final lum = 0.299 * c.$1 + 0.587 * c.$2 + 0.114 * c.$3;
                final isBlue = c.$3 - c.$1 > 30;
                if (c.$4 < 0.5 || isBlue || lum < 70 || lum > 215) return c;
                const k = 0.75;
                return (c.$1 * (1 - k) + land[0] * k, c.$2 * (1 - k) + land[1] * k, c.$3 * (1 - k) + land[2] * k, c.$4);
              }(),
          ];
        }
        if (!exact && s['enhance'] != false) {
          cells = enhanceCells(
            cells,
            dw,
            dh,
            saturation: (s['saturation'] as num?)?.toDouble() ?? 1.35,
            edge: (s['edge'] as num?)?.toDouble() ?? 0.8,
          );
        }
        final art = quantizeCells(cells, dw, dh, colors: colors, removeBackground: s['removeBg'] == true);
        final sw = Stopwatch()..start();
        final a = assessArt(pixels: art.pixels, width: art.width, height: art.height, colors: art.colors.length, capacity: capacity);
        if (!a.solvable) fail('$name: 풀리는 배치를 못 찾았어요 (색 ${art.colors.length}, 도트 ${art.pixelCount})');
        final d = DotStageData(
          name: name,
          width: art.width,
          height: art.height,
          colors: [for (final c in art.colors) c.toARGB32()],
          runs: encodeDotRuns(art.pixels),
          columns: a.columns,
          ammoLo: a.ammoLo,
          ammoHi: a.ammoHi,
          seed: a.seed,
          capacity: a.capacity,
        );
        if (!botSolves(d.toLevel().newGame())) fail('$name: 만든 판이 풀리지 않아요');
        // ignore: avoid_print
        print('$name: ${art.width}x${art.height} 도트 ${art.pixelCount} 색 ${art.colors.length} 벨트 ${a.capacity}(요청 $capacity) '
            '난이도 ${a.difficulty} 대포 ${a.columns}줄 탄 ${a.ammoLo}-${a.ammoHi} (${sw.elapsedMilliseconds}ms)');
        out
          ..writeln('  DotStageData(')
          ..writeln("    name: '${name.replaceAll("'", r"\'")}',")
          ..writeln('    width: ${d.width},')
          ..writeln('    height: ${d.height},')
          ..writeln('    colors: [${d.colors.map((c) => '0x${c.toRadixString(16).toUpperCase()}').join(', ')}],')
          ..writeln("    runs: '${d.runs}',")
          ..writeln('    columns: ${d.columns},')
          ..writeln('    ammoLo: ${d.ammoLo},')
          ..writeln('    ammoHi: ${d.ammoHi},')
          ..writeln('    seed: ${d.seed},')
          ..writeln('    capacity: ${d.capacity},')
          ..writeln('  ),');
      }
      out.writeln('];');
      File('lib/games/dotcannon/core/dot_stage_data.dart').writeAsStringSync(out.toString());
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
