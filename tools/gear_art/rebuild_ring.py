"""Reference implementation (the game does the same in GDScript): build a ring image of N evenly spaced teeth from
the strips made by unwrap_rings.py. ring(kind, n, size) -> RGBA PIL image, size x size, tooth tips at the edge."""
import json, math, numpy as np
from PIL import Image
D = 'art/clockwork/gear/'
META = json.load(open(D + 'gear_strips.json'))
TOOTH = np.array(Image.open(D + 'tooth.png').convert('RGBA')).astype(float)

def ring(kind, n, size):
    band = np.array(Image.open(D + 'band_%s.png' % kind).convert('RGBA')).astype(float)
    m = META[kind]
    R = size / 2.0
    th_frac = META['tooth']['height_frac'] * 22 / n * (META['tooth']['ring_radius_px'] / 252.0)
    # tooth height follows the pitch: a tooth is as tall, relative to its width, as in the art
    pitch = 2 * math.pi * R / n
    tooth_h = pitch * TOOTH.shape[0] / TOOTH.shape[1]
    r_root = R - tooth_h
    band_w = r_root * (1 - m['r_in'] / m['r_root'])   # keep the art's band-to-hole proportion
    r_in = r_root - band_w
    yy, xx = np.mgrid[0:size, 0:size]
    dx = xx + 0.5 - R; dy = yy + 0.5 - R
    r = np.hypot(dx, dy); th = (np.arctan2(dy, dx) + math.pi / 2) % (2 * math.pi)  # 0 at the top, clockwise
    out = np.zeros((size, size, 4))
    tz = (r >= r_root) & (r < R)
    u = (th * n / (2 * math.pi)) % 1.0
    tc = np.clip((u * TOOTH.shape[1]).astype(int), 0, TOOTH.shape[1] - 1)
    tr = np.clip(((R - r) / tooth_h * TOOTH.shape[0]).astype(int), 0, TOOTH.shape[0] - 1)
    out[tz] = TOOTH[tr[tz], tc[tz]]
    bz = (r >= r_in) & (r < r_root + 1)
    bu = (th / (math.pi / 2)) % 1.0
    bc = np.clip((bu * band.shape[1]).astype(int), 0, band.shape[1] - 1)
    br = np.clip(((r_root - r) / band_w * band.shape[0]).astype(int), 0, band.shape[0] - 1)
    fill = bz & (out[..., 3] < 128)
    out[fill] = band[br[fill], bc[fill]]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), 'RGBA')

if __name__ == '__main__':
    bg = Image.new('RGBA', (1500, 560), (0, 22, 48, 255))
    x = 10
    for kind, n, s in (('small', 32, 300), ('big', 46, 420), ('tower', 70, 540)):
        im = ring(kind, n, s); bg.alpha_composite(im, (x, 10)); x += s + 20
    bg.save('/tmp/claude-0/-home-claude/3bf5c283-94b1-59fe-b83b-7f9d81ecfc35/scratchpad/rebuild_test.png')
