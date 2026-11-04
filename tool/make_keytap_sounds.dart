// 건반 톡톡의 피아노 음(n55.wav ~ n84.wav)과 틀렸을 때 소리를 코드로 합성해 assets/keytap/ 에 저장한다.
//   dart run tool/make_keytap_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sr = 22050;

void save(String name, Float64List data, {double gain = 0.85}) {
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
  final f = File('assets/keytap/$name.wav');
  f.parent.createSync(recursive: true);
  f.writeAsBytesSync(pcm.buffer.asUint8List());
  stdout.writeln('$name  ${(data.length / sr).toStringAsFixed(2)}s  ${f.lengthSync()} bytes');
}

/// 피아노 비슷한 소리: 배음마다 줄어드는 빠르기가 다르고(높은 배음이 빨리 사라짐), 살짝 어긋난 두 줄이 겹친다.
Float64List piano(int midi) {
  final f0 = 440 * pow(2, (midi - 69) / 12).toDouble();
  const seconds = 1.1;
  final n = (seconds * sr).round();
  final out = Float64List(n);
  const amps = [1.0, 0.55, 0.32, 0.2, 0.12, 0.08, 0.05];
  final lowBoost = (72 - midi).clamp(0, 20) / 20; // 낮은 음은 조금 더 길게 울린다
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    var v = 0.0;
    for (var h = 0; h < amps.length; h++) {
      final fh = f0 * (h + 1) * (1 + 0.0004 * h * h); // 줄의 비조화성
      if (fh > sr / 2.2) break;
      final decay = 2.2 + h * 1.6 - lowBoost * 0.8;
      final e = exp(-t * decay);
      v += amps[h] * e * (sin(2 * pi * fh * t) + 0.6 * sin(2 * pi * fh * 1.0012 * t));
    }
    // 망치가 줄을 때리는 짧은 소리
    final attack = t < 0.004 ? t / 0.004 : 1.0;
    final thump = sin(2 * pi * f0 * 0.5 * t) * exp(-t * 40) * 0.25;
    out[i] = (v + thump) * attack;
  }
  final fade = (0.08 * sr).round();
  for (var i = 0; i < fade; i++) {
    out[n - 1 - i] *= i / fade;
  }
  return out;
}

/// 틀렸을 때: 낮은 음 두 개가 부딪히는 "둥".
Float64List wrong() {
  final n = (0.5 * sr).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    out[i] = (sin(2 * pi * 98 * t) + sin(2 * pi * 104 * t) + 0.5 * sin(2 * pi * 147 * t)) * exp(-t * 6) * (t < 0.005 ? t / 0.005 : 1);
  }
  return out;
}

void main() {
  for (var m = 55; m <= 84; m++) {
    save('n$m', piano(m));
  }
  save('wrong', wrong(), gain: 0.7);
}
