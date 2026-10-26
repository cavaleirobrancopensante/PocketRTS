"""Assemble the frames of tools/shot_gear_lab.gd into a looping GIF (cropped to the middle of the screen).
  python3 tools/gear_art/frames_to_gif.py <dir> [out.gif]"""
import glob, sys
from PIL import Image
d = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else d + '/lab_turning.gif'
fs = sorted(glob.glob(d + '/frame_*.png'))
ims = [Image.open(f).convert('RGB') for f in fs]
W, H = ims[0].size
box = (W // 2 - 330, H // 2 - 250, W // 2 + 330, H // 2 + 250)
ims = [im.crop(box).quantize(colors=255, method=Image.Quantize.MEDIANCUT) for im in ims]
ims[0].save(out, save_all=True, append_images=ims[1:], duration=120, loop=0)
print(out, len(ims))
