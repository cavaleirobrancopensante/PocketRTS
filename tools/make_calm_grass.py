"""Calmer copies of the bright grass tiles (the bright green is hard on the eye as the
whole map's ground): grass_calm_N (much less saturated, a little darker) and grass_mid_N
(half way), used by the grass biome as its ground with the bright grass only in patches,
the mid tiles between so the patches fade in.  python3 tools/make_calm_grass.py"""
import glob, os, colorsys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")


def tone(src, dst, sat, val):
    im = np.array(Image.open(src).convert("RGBA")).astype(np.float32) / 255.0
    rgb = im[..., :3]
    grey = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    out = grey[..., None] + (rgb - grey[..., None]) * sat
    out = np.clip(out * val, 0, 1)
    im[..., :3] = out
    Image.fromarray((im * 255).round().astype(np.uint8)).save(dst)


for path in sorted(glob.glob(os.path.join(ROOT, "assets/terrain/grass_[0-9]*.png"))):
    n = os.path.basename(path)[len("grass_"):-4]
    tone(path, os.path.join(ROOT, "assets/terrain/grass_calm_%s.png" % n), 0.55, 0.9)
    tone(path, os.path.join(ROOT, "assets/terrain/grass_mid_%s.png" % n), 0.77, 0.95)
print("calm grass tiles written")
