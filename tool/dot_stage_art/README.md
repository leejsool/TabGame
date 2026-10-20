# 도트 캐논 기본 그림 만들기

메뉴에서는 묶음(`theme`)마다 한 줄씩 보이고, 줄 안에서는 `stages.json`에 적은 순서대로 이어집니다
('애니메이션과 게임' 줄 맨 앞에는 손으로 그린 그림 4장이 먼저 온다). 잠금은 없어서 어느 그림이든 바로 할 수 있습니다.
(줄 안에서는 쉬운 것부터 적으세요.)

```json
[
  {"file": "mona_lisa.jpg", "name": "모나리자", "size": 48, "colors": 10, "capacity": 4}
]
```

| 키 | 뜻 | 기본값 |
|---|---|---|
| `file` | 이 폴더 안의 그림 파일 | (필수) |
| `theme` | 묶음: `anime`(애니메이션과 게임), `movie`(영화), `art`(명화) | `art` |
| `name` | 메뉴에 보이는 이름 | (필수) |
| `size` | 긴 쪽 도트 칸 수 (16~64) | 32 |
| `colors` | 쓸 색 수 (2~12) | 8 |
| `capacity` | 벨트 자리 (3 어렵게 ~ 5 쉽게). 풀리는 배치가 없으면 자동으로 늘어남 | 4 |
| `enhance` | 모양 또렷하게 | true |
| `exact` | 이미 도트 아트인 그림을 칸 그대로 읽기 (`tool/prepare_dot_sprites.py`로 1칸 = 1점인 PNG를 먼저 만든다) | false |
| `scale` | `exact`일 때 한 칸을 scale×scale 칸으로 키우기 | 1 |
| `removeBg` | 배경색 지우기 | false |
| `saturation`, `edge` | 선명하게 하는 정도, 윤곽 살리는 정도 (`enhance`가 켜져 있을 때) | 1.35, 0.8 |
| `crop` | 그림의 일부만 쓰기: `[왼쪽, 위, 너비, 높이]` (0~1 비율) | 전체 |
| `landTint` | 회색빛으로 바랜 칸을 `[r, g, b]` 쪽으로 물들이기 (지구의 육지를 초록으로) | 없음 |
| `merge` | 애매한 색 합치기: `[["앞 색", "뒤 색"], ...]` (`RRGGBB`, 앞 색 칸이 뒤 색이 된다. 차례대로 적용). 아래 색 합치기 도구로 고르면 저절로 적힌다 | 없음 |
| `paint` | 칸 하나씩 다시 칠하기: `{"x,y": "RRGGBB" 또는 "."}` (`.`은 빈 칸 = 부술 타일 없음. 그림에 없던 색이면 새 색으로 들어간다). 합치기 뒤에 적용. 도구의 "칸 칠하기"로 고르면 저절로 적힌다 | 없음 |

만들기:

```
flutter test tool/make_dot_stages.dart
```

`lib/games/dotcannon/core/dot_stage_data.dart`가 다시 만들어집니다. 풀리지 않는 그림은 만들다가 멈춥니다.

### 비즈 도안·구슬 사진에서 그림 뽑기

`tool/prepare_dot_sprites.py`의 `SPRITES`에 적고 `python tool/prepare_dot_sprites.py tool/dot_stage_art/src <이름>`.
- 번호가 적힌 반듯한 모눈 도안: `GRIDS`에 첫 칸 왼쪽·위, 칸 너비·높이, 칸 수를 적는다 (칸마다 정확히 읽는다).
- 구슬을 찍은 사진처럼 살짝 휘어진 그림: `WARPED`에 칸 너비·높이를 적으면 작은 조각마다 칸 위치를 따로 찾는다
  (`C:/ftmp/warp_check.png`에 구슬 가운데라고 본 곳이 빨갛게 찍힌다).

### 색 합치기 도구

`tool/도트색합치기.bat`을 더블클릭하면 검은 창이 하나 뜨고 브라우저에 도구가 열립니다 (다 쓰면 검은 창을 닫는다).
(직접 켜려면 `python tool/dot_stage_editor.py --open`, 주소는 http://localhost:8765)

왼쪽 목록은 게임 메뉴와 같은 묶음·차례입니다 (손그림 4장은 여기서 못 고친다).
- **색 통째로 합치기**: 색 하나를 누르고 합칠 색을 누른다 (그림의 점을 눌러도 된다). "비슷한 색 짝"을 누르면 적은 쪽이 많은 쪽으로 합쳐진다.
- **칸 칠하기**: 붓 색(그림에 있는 색, "빈 칸", 또는 "＋ 새 색"으로 고른 새 색)을 고르고 그림을 누르거나 끌어서 칠한다. 오른쪽 클릭은 그 칸 색을 붓으로 집는다. 색은 16개까지.
- **묶음**: 오른쪽 위 "묶음"을 바꾸면 그 그림이 다른 줄로 옮겨진다 (`theme`).

"저장하고 그림 다시 만들기"를 누르면 `stages.json`에 `merge`/`paint`가 적히고 고친 그림 하나만 다시 만들어 게임 그림이 바뀝니다 (다른 그림은 그대로. 명령으로는 `DOT_ONLY=<stages.json 번호, 0부터>`).
"모두 지우고 다시 만들기"는 그 그림에 저장한 것을 지우고 원래 그림으로 되돌립니다.

**저작권:** 그림 파일은 저작권이 풀린(공유 저작물·퍼블릭 도메인·CC0) 것이나 직접 만든 것만 넣으세요.
출처와 라이선스는 아래에 적어 둡니다.

## 출처

모두 위키미디어 커먼즈(commons.wikimedia.org)에서 폭 600으로 내려받은 것입니다.
옛 그림은 저작권 보호 기간이 지난 공유 저작물이고, 지구 사진은 NASA 공개 사진(미국 정부 저작물)입니다.

| 파일 | 작품 | 파일 이름(커먼즈) |
|---|---|---|
| `earth_blue.jpg` | 아폴로 17호가 찍은 지구 (NASA, 색을 다듬은 판) | The_Blue_Marble_(remastered).jpg |
| `great_wave.jpg` | 가쓰시카 호쿠사이, 가나가와 해변의 큰 파도 | Tsunami_by_hokusai_19th_century.jpg |
| `sunflowers.jpg` | 빈센트 반 고흐, 해바라기 | Vincent_Willem_van_Gogh_127.jpg |
| `scream.jpg` | 에드바르 뭉크, 절규 | The_Scream.jpg |
| `kiss.jpg` | 구스타프 클림트, 키스 | The_Kiss_-_Gustav_Klimt_-_Google_Cultural_Institute.jpg |
| `pearl_earring.jpg` | 요하네스 페르메이르, 진주 귀걸이를 한 소녀 | 1665_Girl_with_a_Pearl_Earring.jpg |
| `starry_night.jpg` | 빈센트 반 고흐, 별이 빛나는 밤 | Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg |
| `van_gogh_self.jpg` | 빈센트 반 고흐, 자화상 (1887) | Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project_(454045).jpg |
| `mona_lisa.jpg` | 레오나르도 다 빈치, 모나리자 | Mona_Lisa,_by_Leonardo_da_Vinci,_from_C2RMF_retouched.jpg |
| `iron_man.png` | **마블 캐릭터(저작권 있음)** — 출처 미상의 도트 그림. 스토어에 올리는 앱에는 넣지 마세요 | (사용자가 준 파일) |

### 저작권이 있는 그림 (개인 시험용)

아래는 사용자가 준 캐릭터 도트 그림입니다. 모두 회사의 저작물·상표라서 **스토어에 올리는 앱에는 넣지 마세요.**
(`tool/dot_stage_art/src/`에 원본, 같은 폴더의 `mario.png` 등에 칸 그대로 되돌린 그림이 있습니다.)

| 파일 | 그림 |
|---|---|
| `mario.png`, `mario_face.png` | 마리오 (닌텐도) |
| `bowser.png` | 쿠파 (닌텐도) |
| `charmander.png`, `pikachu.png` | 파이리, 피카츄 (포켓몬) |
| `dragon.png` | 푸른 용 (출처 미상) |
| `iron_man.png` | 아이언맨 (마블) |
