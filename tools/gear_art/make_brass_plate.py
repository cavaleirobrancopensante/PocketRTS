"""The POLISHED BRASS floor plate (owner, 2026-10-27, docs/gear_rules.md): the buildings that use Tension (Mainspring,
Escapement, Heavy Works, Clock Aviary) sit on a brass deck, the others on the dark iron one. Made in code from the iron
plate (assets/gear/floor_plate.png, tools/gear_art/import_buildings.py): its grey iron is mapped onto a warm brass ramp by
its brightness (its rivets, seams and grilles stay as they are drawn, only in brass), the brass rim kept, and a soft
diagonal sheen laid over it (polished). Writes assets/gear/floor_plate_brass.png. Code-drawn: docs/art_style_inconsistency.md.
  python3 tools/gear_art/make_brass_plate.py"""
import numpy as np
from PIL import Image

src = np.array(Image.open('assets/gear/floor_plate.png').convert('RGBA')).astype(np.float32) / 255.0
rgb, a = src[..., :3], src[..., 3:]
lum = (rgb * [0.299, 0.587, 0.114]).sum(2, keepdims=True)
sat = rgb.max(2, keepdims=True) - rgb.min(2, keepdims=True)
# the iron (grey) -> brass: dark brown at the bottom of the ramp, warm gold at the top
lo = np.array([0.20, 0.12, 0.04])
mid = np.array([0.62, 0.42, 0.15])
hi = np.array([1.00, 0.86, 0.52])
t = np.clip((lum - 0.04) / 0.42, 0.0, 1.0)
brass = np.where(t < 0.5, lo + (mid - lo) * (t / 0.5), mid + (hi - mid) * ((t - 0.5) / 0.5))
grey = np.clip(1.0 - sat * 4.0, 0.0, 1.0)          # (the painted brass rim keeps its own colours)
out = rgb * (1.0 - grey) + brass * grey
# polished: a soft sheen across the deck from the top left, and a little more contrast
h, w = lum.shape[:2]
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
u = (xx / w + yy / h) * 0.5
sheen = np.exp(-((u - 0.38) / 0.10) ** 2) * 0.22 + np.exp(-((u - 0.62) / 0.05) ** 2) * 0.10
out = np.clip((out - 0.5) * 1.08 + 0.5 + sheen[..., None] * np.array([1.0, 0.92, 0.7]), 0.0, 1.0)
Image.fromarray((np.dstack([out, a]) * 255).astype(np.uint8), 'RGBA').save('assets/gear/floor_plate_brass.png')
print('assets/gear/floor_plate_brass.png')
