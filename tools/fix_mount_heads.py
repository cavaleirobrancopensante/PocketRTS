"""The front-view (south) mounting strips of both Dragoons: in frame 4 the man's head was drawn
turned away (the back of the head). The head of frame 5 (facing the viewer) is pasted in its
place: the old head's pixels above the shoulders are cleared to the backdrop, then frame 5's
head (hat and face, backdrop left out) is laid on at the old head's place.
  art/crown/mount/dragoon_mount_s_raw.png          -> dragoon_mount_s.png
  art/crown/mount/dragoon_armoured_mount_s_raw.png -> dragoon_armoured_mount_s.png
"""
from PIL import Image
import numpy as np

# name: (clear box in frame 4, source box in frame 5, (dx, dy) from the source to frame 4)
FIX = {
    "dragoon_mount_s": ((1205, 125, 1310, 178), (1628, 115, 1706, 185), (-405, 11)),
    "dragoon_armoured_mount_s": ((1188, 168, 1260, 200), (1596, 160, 1652, 224), (-395, 8)),
}

for name, (clr, src, (dx, dy)) in FIX.items():
    im = Image.open("art/crown/mount/%s_raw.png" % name).convert("RGB")
    a = np.asarray(im).astype(int).copy()
    bg = np.median(a[:8].reshape(-1, 3), axis=0)
    fg = np.abs(a - bg).sum(2) > 60
    x0, y0, x1, y1 = clr
    soft = np.abs(a - bg).sum(2) > 18          # (the old head's faint outline too)
    a[y0:y1, x0:x1][soft[y0:y1, x0:x1]] = bg
    sx0, sy0, sx1, sy1 = src
    patch = a[sy0:sy1, sx0:sx1].copy()
    m = fg[sy0:sy1, sx0:sx1]
    tgt = a[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx]
    tgt[m] = patch[m]
    Image.fromarray(a.astype(np.uint8)).save("art/crown/mount/%s.png" % name)
    print(name)
