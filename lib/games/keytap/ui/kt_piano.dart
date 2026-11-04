import 'package:flutter/widgets.dart';

import '../../../core/settings_scope.dart';
import '../../../core/sfx_pool.dart';
import '../core/kt_songs.dart';

/// 건반 톡톡의 피아노 소리 (tool/make_keytap_sounds.dart 로 만든 assets/keytap/n55~n84.wav).
///
/// 음마다 재생기를 두 개씩 두고 돌아가며 튼다. 설정의 효과음 스위치를 따른다. 화면을 닫을 때 [dispose].
class KtPiano {
  KtPiano() {
    for (var m = kLowNote; m <= kHighNote; m++) {
      _notes[m] = SfxPool('keytap/n$m.wav', voices: 2)..load();
    }
  }

  final Map<int, SfxPool> _notes = {};
  final SfxPool _wrong = SfxPool('keytap/wrong.wav', voices: 1)..load();

  void note(BuildContext context, int midi) {
    if (!SettingsScope.of(context).sound) return;
    _notes[midi.clamp(kLowNote, kHighNote)]?.play();
  }

  void wrong(BuildContext context) {
    if (SettingsScope.of(context).sound) _wrong.play();
  }

  void dispose() {
    for (final p in _notes.values) {
      p.dispose();
    }
    _wrong.dispose();
  }
}
