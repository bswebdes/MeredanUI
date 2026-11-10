#!/usr/bin/env python3
"""Game-data dungeon map (buildmap.py output, 1536x1024 RGBA) on its themed background -> addon BLP.
Background: _assets/dungeon-backgrounds/<inst>.png, cover-cropped and darkened (x0.6, like Wailing
Caverns); a soft shadow under the map; map on top. Output: BLP2 DXT1 2048x1024, map in the left
1536 px (texCoord 0..0.75), plus a preview PNG.
usage: PYTHONPATH=pylib python3 compose.py <maps/inst_floor.png> <background.png> <out.blp> [--largest] [--half]
  --largest  keep only the biggest connected part (drops stray pieces of neighbouring zones)
  --soft     outdoor maps: drop flat-colour fill, fade the blocky terrain outline
  --half     half size: map 768x512 in a 1024x512 BLP (same texCoord 0..0.75, a quarter of the file size)"""
import sys, pathlib
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

W, H = 1536, 1024
src = pathlib.Path(__file__).with_name('santiago.py').read_text().replace('\nmain()\n', '\n')
S = {'__name__': 'x', '__file__': str(pathlib.Path(__file__).with_name('santiago.py'))}; exec(compile(src, 'santiago', 'exec'), S)


def largest_part(rgba):
    a = np.asarray(rgba)[..., 3] > 0
    small = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((W // 4, H // 4), Image.BILINEAR)) > 0
    h, w = small.shape
    label = np.zeros((h, w), np.int32); sizes = [0]
    for y in range(h):
        for x in range(w):
            if small[y, x] and not label[y, x]:
                n = len(sizes); sizes.append(0); q = deque([(y, x)]); label[y, x] = n
                while q:
                    cy, cx = q.popleft(); sizes[n] += 1
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and small[ny, nx] and not label[ny, nx]:
                            label[ny, nx] = n; q.append((ny, nx))
    if len(sizes) <= 2: return rgba
    keep = int(np.argmax(sizes))
    mask = np.asarray(Image.fromarray(((label == keep) * 255).astype(np.uint8)).resize((W, H), Image.NEAREST)) > 0
    mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
    arr = np.array(rgba); arr[~mask, 3] = 0
    return Image.fromarray(arr, 'RGBA')


def soften(rgba):
    """Outdoor maps: terrain comes in square chunks (area mask) and some ADT minimap tiles are flat colour
    fill. Drop flat areas (low local contrast) and fade the outline instead of hard stair-step edges."""
    arr = np.array(rgba).astype(np.float32)
    lum = arr[..., :3].mean(axis=2)
    a = arr[..., 3] > 0
    k = 24
    im = Image.fromarray(lum.clip(0, 255).astype(np.uint8))
    mean = np.asarray(im.filter(ImageFilter.BoxBlur(k)), np.float32)
    sq = np.asarray(Image.fromarray((lum ** 2 / 255).clip(0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(k)), np.float32) * 255
    std = np.sqrt(np.maximum(sq - mean ** 2, 0))
    flat = std < 6
    flat = np.asarray(Image.fromarray((flat * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))) > 0
    keep = a & ~flat
    keep = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(31)), np.float32)
    soft = np.asarray(Image.fromarray(keep.astype(np.uint8)).filter(ImageFilter.GaussianBlur(32)), np.float32)
    arr[..., 3] = np.minimum(arr[..., 3], soft)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), 'RGBA')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    mp, bgp, out = args
    m = Image.open(mp).convert('RGBA').resize((W, H))
    if '--largest' in sys.argv: m = largest_part(m)
    if '--soft' in sys.argv: m = soften(m)
    w, h, blur = W, H, 10
    if '--half' in sys.argv:
        w, h, blur = W // 2, H // 2, 5
        m = m.resize((w, h), Image.LANCZOS)
        S.update(W=w, H=h, TW=1024, TH=512)   # to_blp reads these module globals
    bg = Image.open(bgp).convert('RGB')
    s = max(w / bg.width, h / bg.height)
    bg = bg.resize((round(bg.width * s), round(bg.height * s)), Image.LANCZOS)
    l, t = (bg.width - w) // 2, (bg.height - h) // 2
    bg = np.asarray(bg.crop((l, t, l + w, t + h)), np.float32) * 0.6
    alpha = np.asarray(m)[..., 3].astype(np.float32) / 255
    shadow = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255
    bg *= (1 - 0.7 * shadow)[..., None]
    rgb = np.asarray(m)[..., :3].astype(np.float32)
    final = bg * (1 - alpha[..., None]) + rgb * alpha[..., None]
    img = Image.fromarray(final.clip(0, 255).astype(np.uint8), 'RGB')
    img.save(pathlib.Path(out).with_suffix('.png'))
    S['to_blp'](img.tobytes(), pathlib.Path(out))
    print('wrote', out)


main()
