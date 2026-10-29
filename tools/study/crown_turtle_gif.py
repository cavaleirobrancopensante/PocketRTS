#!/usr/bin/env python3
"""Stills and small GIFs from a filmed Crown turtle fight (tools/study_crown_turtle.gd film:DIR, a frame every 0.5 s).

    python3 -I tools/study/crown_turtle_gif.py FILM_DIR CONFIG OUT_DIR still:NAME:SECONDS gif:NAME:FROM:TO ...

still: one frame (at that fight time) as a JPEG, 1280x720 scaled to 960 wide.
gif: the frames from FROM to TO seconds, the middle 800x450 cut out and shown 400 wide, played at double speed (a frame every 0.25 s on screen).
"""
import os
import sys

from PIL import Image

# (a frame is taken every 0.5 s of fight time plus the two rendered frames it waits for: 2/30 s more at --fixed-fps 30)
STEP = 0.5 + 2.0 / 30.0


def frame(film, cfg, sec):
    i = int(round(sec / STEP))
    p = os.path.join(film, "%s_%04d.png" % (cfg, i))
    while not os.path.exists(p) and i > 0:
        i -= 1
        p = os.path.join(film, "%s_%04d.png" % (cfg, i))
    return Image.open(p).convert("RGB")


def main():
    film, cfg, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    for spec in sys.argv[4:]:
        parts = spec.split(":")
        if parts[0] == "still":
            im = frame(film, cfg, float(parts[2]))
            im = im.resize((960, 540), Image.LANCZOS)
            im.save(os.path.join(out, parts[1] + ".jpg"), quality=78)
        elif parts[0] == "gif":
            a, b = float(parts[2]), float(parts[3])
            ims = []
            s = a
            while s <= b + 0.01:
                im = frame(film, cfg, s).crop((240, 20, 1040, 470)).resize((400, 225), Image.LANCZOS)
                ims.append(im.quantize(colors=40, method=Image.MEDIANCUT, dither=Image.NONE))
                s += STEP
            ims[0].save(os.path.join(out, parts[1] + ".gif"), save_all=True, append_images=ims[1:], duration=250, loop=0,
                        optimize=True)
        print("wrote", parts[1])


if __name__ == "__main__":
    main()
