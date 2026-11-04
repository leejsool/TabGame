/// 건반 톡톡의 곡들. 모두 저작권이 끝난 옛 곡(동요·클래식)의 멜로디만 쓴다.
///
/// 음은 MIDI 번호(60 = 가운데 도). 블록 한 줄 = 음 하나. 소리 파일은 [kLowNote]~[kHighNote]만 있다.
library;

const int kLowNote = 55; // 솔(가운데 도 아래)
const int kHighNote = 84; // 높은 도

/// 곡 하나.
class KtSong {
  const KtSong({required this.id, required this.title, required this.speed, required this.notes, this.composer = ''});

  /// 저장·Wi‑Fi에 쓰는 이름 (바꾸지 않는다).
  final String id;
  final String title;
  final String composer;

  /// 첫 바퀴에서 1초에 내려오는 줄 수.
  final double speed;
  final List<int> notes;

  int get length => notes.length;

  /// 난이도 표시 (별 1~5): 속도로 정한다.
  int get level => (speed - 2.2).clamp(0, 4).round() + 1;

  static KtSong? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static const List<KtSong> all = [_twinkle, _airplane, _joy, _jingle, _elise, _turkish];
}

// 음 이름 → MIDI 번호 (4 = 가운데 옥타브)
const _c4 = 60, _d4 = 62, _e4 = 64, _f4 = 65, _g4 = 67, _a4 = 69, _b4 = 71;
const _c5 = 72, _d5 = 74, _e5 = 76, _f5 = 77;
const _g3 = 55, _gs4 = 68, _ds5 = 75, _fs4 = 66, _ds4 = 63;

const _twinkle = KtSong(
  id: 'twinkle',
  title: '작은 별',
  composer: '프랑스 민요',
  speed: 2.4,
  notes: [
    _c4, _c4, _g4, _g4, _a4, _a4, _g4, //
    _f4, _f4, _e4, _e4, _d4, _d4, _c4,
    _g4, _g4, _f4, _f4, _e4, _e4, _d4,
    _g4, _g4, _f4, _f4, _e4, _e4, _d4,
    _c4, _c4, _g4, _g4, _a4, _a4, _g4,
    _f4, _f4, _e4, _e4, _d4, _d4, _c4,
  ],
);

const _airplane = KtSong(
  id: 'airplane',
  title: '비행기',
  composer: '미국 민요',
  speed: 2.8,
  notes: [
    _e4, _d4, _c4, _d4, _e4, _e4, _e4, //
    _d4, _d4, _d4, _e4, _g4, _g4,
    _e4, _d4, _c4, _d4, _e4, _e4, _e4,
    _d4, _d4, _e4, _d4, _c4,
  ],
);

const _joy = KtSong(
  id: 'joy',
  title: '환희의 송가',
  composer: '베토벤',
  speed: 3.2,
  notes: [
    _e4, _e4, _f4, _g4, _g4, _f4, _e4, _d4, _c4, _c4, _d4, _e4, _e4, _d4, _d4, //
    _e4, _e4, _f4, _g4, _g4, _f4, _e4, _d4, _c4, _c4, _d4, _e4, _d4, _c4, _c4,
    _d4, _d4, _e4, _c4, _d4, _e4, _f4, _e4, _c4, _d4, _e4, _f4, _e4, _d4, _c4, _d4, _g3,
    _e4, _e4, _f4, _g4, _g4, _f4, _e4, _d4, _c4, _c4, _d4, _e4, _d4, _c4, _c4,
  ],
);

const _jingle = KtSong(
  id: 'jingle',
  title: '징글벨',
  composer: '피어폰트',
  speed: 3.7,
  notes: [
    _e4, _e4, _e4, _e4, _e4, _e4, _e4, _g4, _c4, _d4, _e4, //
    _f4, _f4, _f4, _f4, _f4, _e4, _e4, _e4, _e4, _d4, _d4, _e4, _d4, _g4,
    _e4, _e4, _e4, _e4, _e4, _e4, _e4, _g4, _c4, _d4, _e4,
    _f4, _f4, _f4, _f4, _f4, _e4, _e4, _e4, _g4, _g4, _f4, _d4, _c4,
  ],
);

const _elise = KtSong(
  id: 'elise',
  title: '엘리제를 위하여',
  composer: '베토벤',
  speed: 4.2,
  notes: [
    _e5, _ds5, _e5, _ds5, _e5, _b4, _d5, _c5, _a4, //
    _c4, _e4, _a4, _b4, _e4, _gs4, _b4, _c5,
    _e4, _e5, _ds5, _e5, _ds5, _e5, _b4, _d5, _c5, _a4,
    _c4, _e4, _a4, _b4, _e4, _c5, _b4, _a4,
    _b4, _c5, _d5, _e5, _g4, _f5, _e5, _d5, _f4, _e5, _d5, _c5, _e4, _d5, _c5, _b4,
    _e4, _e5, _ds5, _e5, _ds5, _e5, _b4, _d5, _c5, _a4,
  ],
);

const _turkish = KtSong(
  id: 'turkish',
  title: '터키 행진곡',
  composer: '모차르트',
  speed: 4.8,
  notes: [
    _b4, _a4, _gs4, _a4, _c5, _d5, _c5, _b4, _c5, _e5, //
    _f5, _e5, _ds5, _e5, _b4, _a4, _gs4, _a4, _b4, _a4, _gs4, _a4, _c5,
    _a4, _c5, _b4, _a4, _g4, _a4, _b4, _a4, _g4, _a4, _b4, _a4, _g4, _fs4, _e4,
    _b4, _a4, _gs4, _a4, _c5, _d5, _c5, _b4, _c5, _e5,
    _f5, _e5, _ds5, _e5, _b4, _a4, _gs4, _a4, _b4, _a4, _gs4, _a4, _c5,
    _a4, _b4, _c5, _b4, _a4, _gs4, _a4, _e4, _f4, _ds4, _e4,
  ],
);
