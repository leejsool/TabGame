"""리듬 검사단 '철검' 그림 준비 도구.

assets/rhythm/art/c{0-3}_{idle,windup,strike}.png 의 목검을 철검으로 바꿔
c{0-3}_{idle,windup,strike}_iron.png 로 저장한다. (옆으로 휘두르는 그림 c*_side_*.png 는 처음부터 철검이다)
크기·발 위치가 그대로라서 art.json 은 건드리지 않고, 앱이 원래 그림의 정보를 그대로 쓴다.

    python tool/prepare_rhythm_iron_art.py            # 실제 생성
    python tool/prepare_rhythm_iron_art.py --sheet    # 확인용 연두색 바탕 시트 (art_src/_check_iron.png)

방법: 목검 색(주황빛 갈색)이 이어진 덩어리 중 "가늘고 긴 것"을 칼로 보고(머리카락·장화는 두꺼운 덩어리라 걸러진다),
칼의 가운데 축을 구해 손에 가까운 쪽 끝 22%는 손잡이·날밑(금색), 나머지는 칼날(강철색)로 칠한다.
윤곽선과 명암은 밝기를 그대로 옮겨서 남긴다. 타격 그림의 갈색 칼바람 선은 은빛으로 바꾼다.

필요: Pillow, numpy
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'art_src')
ART = os.path.join(os.path.dirname(ROOT), 'assets', 'rhythm', 'art')

# 칼날(강철) / 손잡이·날밑(금) 색 띠: 어두운 곳 → 중간 → 밝은 곳
STEEL = [(52, 60, 78), (140, 152, 170), (240, 245, 252)]
GOLD = [(104, 72, 18), (214, 164, 48), (255, 228, 130)]
LINE = [(120, 135, 160), (190, 205, 225), (245, 250, 255)]  # 타격 그림의 칼바람 선


def hsv(arr):
    rgb = arr[..., :3].astype(np.float32) / 255.0
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    d = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm = nz & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    return h * 60.0, s, mx


def components(mask, min_area):
    h, w = mask.shape
    flat = mask.ravel()
    seen = np.zeros(h * w, bool)
    out = []
    for st in np.flatnonzero(flat):
        if seen[st]:
            continue
        seen[st] = True
        comp = [st]
        dq = deque([st])
        while dq:
            p = dq.popleft()
            y, x = divmod(p, w)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w:
                        q = yy * w + xx
                        if flat[q] and not seen[q]:
                            seen[q] = True
                            comp.append(q)
                            dq.append(q)
        if len(comp) >= min_area:
            out.append(np.array(comp))
    return out


def pca(idx, w):
    ys, xs = np.divmod(idx, w)
    pts = np.stack([xs, ys], axis=1).astype(np.float32)
    c = pts.mean(axis=0)
    cov = np.cov((pts - c).T)
    vals, vecs = np.linalg.eigh(cov)
    major = vecs[:, 1]
    minor = vecs[:, 0]
    along = (pts - c) @ major
    across = (pts - c) @ minor
    return c, major, float(along.min()), float(along.max()), float(np.sqrt(max(vals[1], 1e-6) / max(vals[0], 1e-6)))


def dilate(mask, r=1):
    out = mask.copy()
    for _ in range(r):
        m = out.copy()
        m[1:, :] |= out[:-1, :]
        m[:-1, :] |= out[1:, :]
        m[:, 1:] |= out[:, :-1]
        m[:, :-1] |= out[:, 1:]
        out = m
    return out


def erode(mask, r=1):
    return ~dilate(~mask, r)


def ramp(lum, stops):
    """밝기(0~255) → 어두움/중간/밝음 3색 띠."""
    t = np.clip((lum - 60.0) / (215.0 - 60.0), 0, 1)
    a = np.array(stops, np.float32)
    lo = np.where(t[..., None] < 0.5, a[0], a[1])
    hi = np.where(t[..., None] < 0.5, a[1], a[2])
    f = np.where(t < 0.5, t * 2, (t - 0.5) * 2)[..., None]
    return lo + (hi - lo) * f


def find_sword(arr):
    """(칼 픽셀 마스크, 칼 축 정보) — 목검 색 덩어리 중 길고 곧은 것 가운데 가장 큰 것.
    (머리카락·장화는 둥글고, 망토 금장식·허리띠는 가늘지만 칼보다 작다)"""
    h, s, v = hsv(arr)
    alpha = arr[..., 3] > 200
    wood = alpha & (h >= 14) & (h <= 48) & (s >= 0.35) & (v >= 0.3) & (v <= 0.9)
    height, width = wood.shape
    best = None
    for comp in components(wood, 60):
        c, axis, lo, hi, elong = pca(comp, width)
        if elong >= 3.0 and (hi - lo) >= 0.15 * height and (best is None or len(comp) > len(best[0])):
            best = (comp, c, axis, lo, hi)
    if best is None:
        return None
    comp, c, axis, lo, hi = best
    mask = np.zeros(wood.shape, bool)
    mask.ravel()[comp] = True
    # 날밑·손잡이는 칼날과 윤곽선으로 갈라진 별개의 작은 조각이다: 칼 축 가까이에 통째로 들어 있는 조각을 더한다.
    # (허리띠·머리카락·망토 장식은 축에서 멀거나 커서 걸러진다)
    normal = np.array([-axis[1], axis[0]])
    for other in components(wood & ~mask, 25):
        if len(other) > 1500:
            continue
        ys, xs = np.divmod(other, width)
        pts = np.stack([xs, ys], axis=1).astype(np.float32) - c
        along = pts @ axis
        off = np.abs(pts @ normal)
        if off.max() <= 30 and along.min() >= lo - 60 and along.max() <= hi + 60:
            mask.ravel()[other] = True
    comp = np.flatnonzero(mask.ravel())
    c, axis, lo, hi, _ = pca(comp, width)
    return mask, (c, axis, lo, hi)


def recolor(arr, sword, axis_info):
    """칼 픽셀을 강철색으로, 손에 가까운 쪽 22%는 금색으로. 칼 안쪽의 밝은 점·명암 구멍도 같이 칠한다."""
    c, axis, lo, hi = axis_info
    hh, ss, vv = hsv(arr)
    lum_all = (arr[..., :3].astype(np.float32) * [0.299, 0.587, 0.114]).sum(axis=2)
    skin = (arr[..., 3] > 200) & (arr[..., 0] > 215) & (arr[..., 1] > 165) & (arr[..., 1] < 235) & (arr[..., 2] > 120) & (arr[..., 2] < 210) & (hh >= 10) & (hh <= 36) & (ss >= 0.1) & (ss <= 0.5)
    # 칼 모양의 틈(밝은 점 등)을 메우고, 윤곽선(아주 어두운 줄)과 손은 그대로 둔다
    closed = erode(dilate(sword, 3), 3)
    region = dilate(closed, 1) & (arr[..., 3] > 0) & ~skin & (lum_all >= 52) & (vv >= 0.25)
    # 칼 둘레의 한 겹에서 칼과 상관없는 색(머리카락의 갈색 등)이 섞이지 않게, 목검의 갈색~노랑 계열만
    region &= (arr[..., 0] >= arr[..., 2] - 4) & (hh >= 6) & (hh <= 62)
    # 자루 쪽 끝 찾기: 칼끝은 뾰족하게 좁아지고, 날밑·손잡이 쪽은 더 넓다 → 양 끝 15% 구간의 넓이를 비교한다
    ys_m, xs_m = np.nonzero(sword)
    al = (np.stack([xs_m, ys_m], axis=1).astype(np.float32) - c) @ axis
    span = hi - lo
    low_area = int(((al >= lo) & (al <= lo + 0.15 * span)).sum())
    high_area = int(((al <= hi) & (al >= hi - 0.15 * span)).sum())
    hand_low = low_area >= high_area
    y, x = np.nonzero(region)
    along = (np.stack([x, y], axis=1).astype(np.float32) - c) @ axis
    t_hand = (along - lo) / (hi - lo) if hand_low else (hi - along) / (hi - lo)  # 0 = 손 쪽 끝
    lum = lum_all[y, x]
    steel = ramp(lum, STEEL)
    gold = ramp(lum, GOLD)
    is_hilt = (t_hand <= 0.22)[:, None]
    col = np.where(is_hilt, gold, steel)
    out = arr.copy()
    out[y, x, :3] = np.clip(col + 0.5, 0, 255).astype(np.uint8)
    return out, region


def recolor_swish(arr, region, sword):
    """타격 그림의 갈색 칼바람 선(가늘고 긴 갈색 조각)을 은빛으로."""
    h, s, v = hsv(arr)
    warm = (arr[..., 3] > 0) & (arr[..., 0] > arr[..., 2] + 10) & (h >= 5) & (h <= 50) & (v <= 0.85) & (s >= 0.15)
    hh, ww = warm.shape
    near_sword = dilate(sword, 10)
    out = arr.copy()
    # 칼 가까이가 아니고, 위쪽 반(칼바람 선은 칼 위쪽 공중에 있다)에 있는 가는 조각만
    cand = warm & ~near_sword & ~region
    for comp in components(dilate(cand, 1) & warm, 30):
        c, axis, lo, hi, elong = pca(comp, ww)
        # 칼바람 선은 몸 오른쪽 공중에 있다 (왼쪽 어깨의 망토 금장식 같은 것은 건드리지 않는다)
        if elong >= 3.0 and (hi - lo) >= 40 and c[0] >= 0.62 * ww:
            y, x = np.divmod(comp, ww)
            lum = (arr[y, x, :3].astype(np.float32) * [0.299, 0.587, 0.114]).sum(axis=1)
            out[y, x, :3] = np.clip(ramp(lum, LINE) + 0.5, 0, 255).astype(np.uint8)
    return out


def main():
    sheet = '--sheet' in sys.argv
    outs = []
    for kind in ('idle', 'windup', 'strike'):
        row = []
        for i in range(4):
            name = f'c{i}_{kind}'
            arr = np.array(Image.open(os.path.join(ART, f'{name}.png')).convert('RGBA'))
            found = find_sword(arr)
            if found is None:
                sys.exit(f'{name}: 칼을 찾지 못했다 — 임계값을 확인할 것')
            sword, info = found
            out, region = recolor(arr, sword, info)
            if kind == 'strike':
                out = recolor_swish(out, region, sword)
            Image.fromarray(out, 'RGBA').save(os.path.join(ART, f'{name}_iron.png'), optimize=True)
            row.append(out)
            print(name, '칼 픽셀', int(region.sum()))
        outs.append(row)
    if sheet:
        hs = [max(a.shape[0] for a in row) for row in outs]
        wd = max(sum(a.shape[1] + 10 for a in row) for row in outs)
        canvas = Image.new('RGBA', (wd, sum(hs) + 30), (60, 200, 90, 255))
        y = 0
        for row, h in zip(outs, hs):
            x = 0
            for a in row:
                canvas.alpha_composite(Image.fromarray(a, 'RGBA'), (x, y + h - a.shape[0]))
                x += a.shape[1] + 10
            y += h + 10
        canvas.convert('RGB').save(os.path.join(SRC, '_check_iron.png'))
    print('done ->', ART)


if __name__ == '__main__':
    main()
