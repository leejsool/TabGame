// 리듬 검사단의 효과음을 코드로 합성해 assets/rhythm/*.wav 로 저장한다.
//   dart run tool/make_rhythm_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sr = 44100;
final rng = Random(7);

double noise() => rng.nextDouble() * 2 - 1;

/// 지수로 줄어드는 소리 크기.
double env(double t, double decay) => exp(-t * decay);

Float64List render(double seconds, double Function(double t) f) {
  final n = (seconds * sr).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = f(i / sr);
  }
  // 끝을 부드럽게 (딱 소리 방지)
  final fade = min(n, 220);
  for (var i = 0; i < fade; i++) {
    out[n - 1 - i] *= i / fade;
  }
  return out;
}

void save(String name, Float64List data, {double gain = 0.9}) {
  var peak = 0.0;
  for (final v in data) {
    peak = max(peak, v.abs());
  }
  final k = peak == 0 ? 0.0 : gain / peak;
  final pcm = ByteData(44 + data.length * 2);
  void s(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      pcm.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  s(0, 'RIFF');
  pcm.setUint32(4, 36 + data.length * 2, Endian.little);
  s(8, 'WAVEfmt ');
  pcm.setUint32(16, 16, Endian.little);
  pcm.setUint16(20, 1, Endian.little);
  pcm.setUint16(22, 1, Endian.little);
  pcm.setUint32(24, sr, Endian.little);
  pcm.setUint32(28, sr * 2, Endian.little);
  pcm.setUint16(32, 2, Endian.little);
  pcm.setUint16(34, 16, Endian.little);
  s(36, 'data');
  pcm.setUint32(40, data.length * 2, Endian.little);
  for (var i = 0; i < data.length; i++) {
    pcm.setInt16(44 + i * 2, (data[i] * k * 32767).round().clamp(-32767, 32767), Endian.little);
  }
  final f = File('assets/rhythm/$name.wav');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(pcm.buffer.asUint8List());
  stdout.writeln('$name  ${(data.length / sr).toStringAsFixed(2)}s  ${f.lengthSync()} bytes');
}

/// 칼이 공기를 가르는 소리(휘익) + 땅/나무에 맞는 퍽 소리.
Float64List slash({required double pitch, required double clang}) {
  var lp = 0.0;
  return render(0.32, (t) {
    // 휘익: 주파수가 내려가는 필터 잡음
    final sweep = 0.12 + 0.5 * env(t, 22);
    lp += sweep * (noise() - lp);
    final whoosh = lp * 1.6 * env(t, 14) * (t < 0.12 ? sin(pi * t / 0.12) : 1);
    // 퍽: 낮은 사인 + 짧은 잡음
    final tt = max(0.0, t - 0.1);
    final thud = t < 0.1 ? 0.0 : sin(2 * pi * (120 * pitch) * tt * (1 - tt * 1.4)) * env(tt, 16) * 1.0;
    final crack = t < 0.1 ? 0.0 : noise() * env(tt, 70) * 0.7;
    // 챙: 금속 배음
    final ring = t < 0.1
        ? 0.0
        : (sin(2 * pi * 1480 * pitch * tt) * 0.35 + sin(2 * pi * 2230 * pitch * tt) * 0.2) *
            env(tt, 12) *
            clang;
    return whoosh + thud + crack + ring;
  });
}

Float64List kick() => render(0.28, (t) {
      final f = 46 + 110 * env(t, 30);
      return sin(2 * pi * f * t) * env(t, 11) + noise() * env(t, 160) * 0.2;
    });

Float64List hat() {
  var prev = 0.0;
  return render(0.08, (t) {
    final n = noise();
    final hp = n - prev; // 고음만
    prev = n;
    return hp * env(t, 55);
  });
}

Float64List tick({double freq = 1200}) => render(0.07, (t) {
      return sin(2 * pi * freq * t) * env(t, 70) + sin(2 * pi * freq * 2.01 * t) * env(t, 90) * 0.4;
    });

/// 완벽! 땡 — 맑은 종소리.
Float64List chime() => render(0.5, (t) {
      return (sin(2 * pi * 1568 * t) * 0.6 + sin(2 * pi * 2349 * t) * 0.35 + sin(2 * pi * 3136 * t) * 0.15) *
          env(t, 7);
    });

Float64List miss() => render(0.22, (t) {
      final f = 150 - 60 * t / 0.22;
      return (sin(2 * pi * f * t) * 0.8 + noise() * 0.15) * env(t, 14);
    });

/// 단계 통과 팡파르 (짧은 세 음).
Float64List fanfare({bool big = false}) {
  final notes = big ? [523.25, 659.25, 783.99, 1046.5] : [523.25, 783.99];
  final step = big ? 0.14 : 0.12;
  final len = step * notes.length + 0.7;
  return render(len, (t) {
    var v = 0.0;
    for (var i = 0; i < notes.length; i++) {
      final tt = t - i * step;
      if (tt < 0) continue;
      final f = notes[i];
      final isLast = i == notes.length - 1;
      final e = env(tt, isLast ? 3.2 : 9);
      v += (sin(2 * pi * f * tt) + 0.4 * sin(2 * pi * f * 2 * tt) + 0.2 * sin(2 * pi * f * 3 * tt)) * e * 0.5;
    }
    return v;
  });
}

/// 힘 모으기: 점점 높아지고 커지는 소리 (꾹 누르는 한 박 = 0.6초).
Float64List charge() => render(0.6, (t) {
      final k = t / 0.6;
      final f = 260 + 900 * k * k;
      final vib = 1 + 0.015 * sin(2 * pi * 14 * t);
      final env = 0.25 + 0.75 * k;
      return (sin(2 * pi * f * vib * t) * 0.7 + sin(2 * pi * f * 2.01 * t) * 0.25 * k) * env;
    });

void main() {
  save('hit_left', slash(pitch: 1.0, clang: 0.7));
  save('hit_right', slash(pitch: 1.18, clang: 0.7));
  // 선배들의 내려치기는 조금 작고 둔탁하게
  save('npc_left', slash(pitch: 0.92, clang: 0.35), gain: 0.62);
  save('npc_right', slash(pitch: 1.08, clang: 0.35), gain: 0.62);
  save('kick', kick(), gain: 0.55);
  save('hat', hat(), gain: 0.25);
  save('tick', tick(), gain: 0.5);
  save('tick_hi', tick(freq: 1800), gain: 0.55);
  save('chime', chime(), gain: 0.55);
  save('charge', charge(), gain: 0.45);
  save('miss', miss(), gain: 0.5);
  save('stage_clear', fanfare(), gain: 0.6);
  save('all_clear', fanfare(big: true), gain: 0.7);
}
