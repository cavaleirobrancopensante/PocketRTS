"""Mouse cursors: art/ui/cursors.png (3 x 3 cursors on flat magenta, the designer's sheet) is cut
into nine cursors, keyed (near-magenta and the anti-aliased magenta fringe made transparent, the
edge pixels de-fringed), box-filtered down with one common scale (so the cursors keep their
relative sizes) and saved as assets/ui/cursors/<name>.png (32 x 32) and <name>_48.png (48 x 48,
for high-DPI desktop screens). Their hotspots go to scripts/cursor_hotspots.gd (generated).
Re-runnable (from the repo root).
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

# faction -> (sheet, output folder); the Crown's set is the base one (no sub-folder)
SETS = {
	"crown": ("art/ui/cursors.png", "assets/ui/cursors"),
	"brood": ("art/ui/cursors_brood.png", "assets/ui/cursors/brood"),
	"clockwork": ("art/ui/cursors_clockwork.png", "assets/ui/cursors/clockwork"),
}
GD = "scripts/cursor_hotspots.gd"
SIZES = (32, 48)

# Left to right, top to bottom on the sheet. "anchor": where the cut sits in its square
# ("tl": top-left, so an arrow's tip is near (0, 0); "c": centred).
CURSORS = [
	("pointer", "tl"), ("attack", "c"), ("attack_enemy", "c"),
	("move", "c"), ("select", "tl"), ("build", "c"),
	("rally", "c"), ("forbidden", "c"), ("patrol", "tl"),
]


def magenta_score(a):
	r, g, b = a[..., 0], a[..., 1], a[..., 2]
	return np.minimum(r, b) - g, np.abs(r - b)


def key(cell, trim=False):
	"""(rgb, alpha) of one cell: magenta and its fringe transparent, edge colours cleaned."""
	a = cell.astype(int)
	m, d = magenta_score(a)
	bg = (m > 100) & (d < 70)
	# fringe: pixels next to the backdrop that are still a mix of magenta and the dark outline
	near = nd.binary_dilation(bg, iterations=3)
	bg |= near & (m > 25) & (d < 60)
	# keep only the cursor itself (the biggest pieces; drops stray specks)
	lab, n = nd.label(~bg)
	sizes = nd.sum(~bg, lab, range(1, n + 1))
	# (the Brood's and Clockwork's sheets also drop anything much smaller than the biggest piece: the top of the next row's cursor can
	# poke into this cell when the sheet's rows are not on the exact thirds)
	big = sizes.max()
	fg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 200 and (not trim or s >= 0.2 * big)])
	# de-fringe: edge pixels with a magenta cast take the colour of the nearest clean pixel
	edge = fg & nd.binary_dilation(~fg, iterations=2)
	cast = edge & (m > 4) & (d < 60)
	clean = fg & ~cast
	_, (iy, ix) = nd.distance_transform_edt(~clean, return_indices=True)
	rgb = a.copy()
	rgb[cast] = a[iy[cast], ix[cast]]
	return rgb, fg


def downscale(rgb, fg, w, h):
	"""Box filter to w x h: a pixel is opaque when the cursor covers half its box; its colour is
	the mean of the box's commonest (quantised) colour, so outlines stay crisp, not muddy."""
	H, W = fg.shape
	out = np.zeros((h, w, 4), np.uint8)
	ys = np.linspace(0, H, h + 1).round().astype(int)
	xs = np.linspace(0, W, w + 1).round().astype(int)
	for j in range(h):
		for i in range(w):
			bf = fg[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
			if bf.size == 0 or bf.mean() < 0.5:
				continue
			px = rgb[ys[j]:ys[j + 1], xs[i]:xs[i + 1]][bf]
			q = px // 24
			keys = q[:, 0] * 10000 + q[:, 1] * 100 + q[:, 2]
			vals, counts = np.unique(keys, return_counts=True)
			pick = px[keys == vals[counts.argmax()]]
			out[j, i, :3] = pick.mean(axis=0).round().clip(0, 255)
			out[j, i, 3] = 255
	return out


def hotspot(name, rgb, fg):
	"""The hotspot in the cut's own (source) pixels."""
	ys, xs = np.nonzero(fg)
	h, w = fg.shape
	if name in ("pointer", "patrol"):  # arrow tip, top-left
		k = (xs + ys).argmin()
		return xs[k] + 4, ys[k] + 4
	if name == "select":  # the arrow's tip (inside the green ring): first brass / steel pixel
		r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
		arrow = fg & ~((g > r + 30) & (g > b + 30)) & (rgb.sum(axis=2) > 200)
		ay, ax = np.nonzero(arrow)
		k = (ax + ay).argmin()
		return ax[k], ay[k]
	if name == "move":  # the ring's centre, where the arrow points: middle of the ring's hole
		holes = nd.binary_fill_holes(fg) & ~fg
		hy, hx = np.nonzero(holes)
		if len(hy) == 0:       # an open ring (no closed hole): its middle is a little above the bottom
			return (xs.min() + xs.max()) / 2, ys.max() - 0.14 * (ys.max() - ys.min())
		return (xs.min() + xs.max()) / 2, hy.mean()
	if name == "build":  # the hammer head's striking corner (its leftmost point)
		x0 = xs.min()
		col = ys[xs <= x0 + 4]
		return x0 + 4, col.mean()
	if name == "rally":  # the foot of the pole: bottom middle of its base
		y1 = ys.max()
		row = xs[ys >= y1 - 4]
		return (row.min() + row.max()) / 2, y1 - 4
	return (w - 1) / 2, (h - 1) / 2  # crosshairs, forbidden: the centre


def cut_set(faction):
	"""Cut one faction's sheet; returns {size: {name: (x, y)}} hotspots."""
	src, out = SETS[faction]
	return cut(src, out, faction != "crown")


def cut(SRC, OUT, trim=False):
	sheet = np.asarray(Image.open(SRC).convert("RGB"))
	H, W = sheet.shape[:2]
	cuts = []
	for k, (name, anchor) in enumerate(CURSORS):
		r, c = divmod(k, 3)
		rgb, fg = key(sheet[r * H // 3:(r + 1) * H // 3, c * W // 3:(c + 1) * W // 3], trim)
		ys, xs = np.nonzero(fg)
		y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
		rgb, fg = rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1]
		cuts.append((name, anchor, rgb, fg, hotspot(name, rgb, fg)))
	biggest = max(max(fg.shape) for _, _, _, fg, _ in cuts)
	os.makedirs(OUT, exist_ok=True)
	spots = {size: {} for size in SIZES}
	for name, anchor, rgb, fg, (hx, hy) in cuts:
		for size in SIZES:
			s = size / biggest
			h, w = fg.shape
			sw, sh = max(1, round(w * s)), max(1, round(h * s))
			small = downscale(rgb, fg, sw, sh)
			ox, oy = (0, 0) if anchor == "tl" else ((size - sw) // 2, (size - sh) // 2)
			canvas = np.zeros((size, size, 4), np.uint8)
			canvas[oy:oy + sh, ox:ox + sw] = small
			Image.fromarray(canvas, "RGBA").save(f"{OUT}/{name}{'' if size == 32 else '_%d' % size}.png")
			px = min(size - 1, max(0, int(ox + (hx + 0.5) * sw / w)))
			py = min(size - 1, max(0, int(oy + (hy + 0.5) * sh / h)))
			spots[size][name] = (px, py)
		print(f"{name}: {w}x{h} -> {spots[32][name]} / {spots[48][name]}")
	return spots


def main():
	allspots = {f: cut_set(f) for f in SETS}
	with open(GD, "w") as f:
		f.write("# Generated by tools/import_cursors.py: do not edit by hand.\n")
		f.write("# Cursor hotspots (pixels from the top-left) in assets/ui/cursors/<name>.png (32 px)\n")
		f.write("# and <name>_48.png (48 px); the Brood's and Clockwork's sets are in the brood/ and\n")
		f.write("# clockwork/ sub-folders (HOTSPOT_BROOD_32 ...). The Crown's keep the plain names.\n")
		for fac, spots in allspots.items():
			for size in SIZES:
				pre = "HOTSPOT_%d" % size if fac == "crown" else "HOTSPOT_%s_%d" % (fac.upper(), size)
				f.write(f"const {pre} := {{\n")
				for name, _ in CURSORS:
					x, y = spots[size][name]
					f.write(f"\t\"{name}\": Vector2({x}, {y}),\n")
				f.write("}\n")


if __name__ == "__main__":
	main()
