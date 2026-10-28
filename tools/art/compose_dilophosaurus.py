# Builds art/redraws/dilophosaurus_concept_composed.png from the owner's ChatGPT concept (its fertilising figure had its tail hidden behind another figure): the three poses cut apart by connected parts, the walker's tail grafted on the fertilising one.
#   python3 tools/art/compose_dilophosaurus.py art/redraws/dilophosaurus_concept_chatgpt.png art/redraws/dilophosaurus_concept_composed.png
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
src = np.array(Image.open(sys.argv[1]).convert('RGB'))
bgc = np.array([15, 27, 37], float)
d = np.sqrt(((src.astype(float) - bgc) ** 2).sum(-1))
soft = np.clip((d - 18) * 12, 0, 255)
lab, n = ndimage.label(ndimage.binary_closing(d > 30, iterations=2))
sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
def piece(mask, box):
    x0, y0, x1, y1 = box
    others = ndimage.binary_dilation((lab > 0) & ~mask & (sizes_map > 2000), iterations=4)
    m = ndimage.binary_dilation(mask, iterations=3) & ~(others & ~mask)
    al = (soft * m)[y0:y1, x0:x1].astype(np.uint8)
    return Image.fromarray(np.dstack([src[y0:y1, x0:x1], al]), 'RGBA')
sizes_map = np.concatenate([[0], sizes])[lab]
big = [i + 1 for i, s in enumerate(sizes) if s > 2000]
walker = lab == lab[300, 300]
spitter = lab == lab[700, 500]
top = lab == lab[300, 1000]
# small bits (venom drops, sparks, smoke) belong with the nearest figure
small = (lab > 0) & ~walker & ~spitter & ~top
xx = np.arange(src.shape[1])[None, :].repeat(src.shape[0], 0)
yy = np.arange(src.shape[0])[:, None].repeat(src.shape[1], 1)
fert = top & (xx >= 872) & ~((xx < 935) & (yy > 225) & (yy < 300)) | small & (xx >= 1180) & (yy < 520) & (yy > 300)
spit = spitter | small & (yy > 330) & (xx < 1100) & (xx > 240)
walk = walker | small & (xx < 640) & (yy < 460)
tailm = walker & (xx < 238) & (yy < 262)
W, H = 1860, 560
canvas = Image.new('RGBA', (W, H), (15, 27, 37, 255))
canvas.alpha_composite(piece(walk, (10, 60, 600, 470)), (10, 90))
canvas.alpha_composite(piece(spit, (240, 340, 1100, 810)), (600, 70))
tail = piece(tailm, (10, 130, 245, 265)).rotate(-10, resample=Image.BICUBIC, expand=True)
fx, fy = 1430, 110
canvas.alpha_composite(tail, (fx - 228, fy + 12))
canvas.alpha_composite(piece(fert, (868, 60, 1264, 520)), (fx - 6, fy))
canvas.convert('RGB').save(sys.argv[2])
