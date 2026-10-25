"""Owner-requested keyframe for the ChatGPT south-east walk: the labourer from /tmp/gait_blocks.png (a 6px-block sampling of the owner image) with its legs deleted and code legs drawn (picture-left leg leading and nearer, picture-right leg trailing and higher), black outline. Reference for prompt 37. Run from a scratch dir; paths are /tmp."""
import numpy as np
from PIL import Image, ImageDraw
g=np.array(Image.open("/tmp/gait_blocks.png")).copy()
H,W=g.shape[:2]
NAVY=(0,22,48)
g[93:,:]=NAVY                    # delete the legs (everything under the coat hem)
BLACK=(8,5,5)
GREY=[(150,150,150),(122,122,122),(88,88,88)]      # light, mid, dark
BRO=[(176,96,44),(140,74,26),(100,50,18)]
def mask_of(f):
    im=Image.new("L",(W,H),0); d=ImageDraw.Draw(im); f(d); return np.array(im)>0
def thick(d,pts,w):
    for (x0,y0),(x1,y1) in zip(pts,pts[1:]):
        d.line([(x0,y0),(x1,y1)],fill=255,width=int(round(w)))
        for (x,y) in ((x0,y0),(x1,y1)):
            r=w/2; d.ellipse([x-r,y-r,x+r,y+r],fill=255)
def shade(mask,pal,light_dir=(1,0)):
    out=np.zeros((H,W,3),np.uint8); out[mask]=pal[1]
    left=mask & ~np.roll(mask,1,1); right=mask & ~np.roll(mask,-1,1)
    top=mask & ~np.roll(mask,1,0)
    out[left|top]=pal[0]; out[right]=pal[2]
    return out
def outline(mask): # one block all round
    m=mask.copy()
    for dx,dy in((1,0),(-1,0),(0,1),(0,-1)):
        m|=np.roll(np.roll(mask,dx,1),dy,0)
    return m&~mask
def paint(layers):
    for mask,pal in layers:
        o=outline(mask); g[o]=BLACK
        sh=shade(mask,pal); g[mask]=sh[mask]
def leg(pts_t,w_t,pts_s,w_s,boot_poly):
    trou=mask_of(lambda d:(thick(d,pts_t,w_t),thick(d,pts_s,w_s)))
    boot=mask_of(lambda d:d.polygon(boot_poly,fill=255))
    return trou&~boot,boot
def clip(m): m=m.copy(); m[:93,:]=False; return m
def paint(layers):
    for mask,pal in layers:
        o=clip(outline(mask)); g[o]=BLACK
        m=clip(mask); sh=shade(m,pal); g[m]=sh[m]
# back leg (the picture-RIGHT hip): trailing, farther, higher on the picture, knee bent, heel up, on its toes
bt,bb=leg([(48,93),(47,103)],8,[(47,103),(40,111)],6.5,[(34,106),(44,108),(45,115),(37,123),(29,124),(29,120),(33,114)])
# front leg (the picture-LEFT hip): leading, nearer, lower on the picture, straight, heel down, toe toward the lower right
ft,fb=leg([(38,93),(42,106)],8.5,[(42,106),(49,122)],7,[(44,117),(53,118),(54,128),(64,131),(64,136),(45,136),(43,129)])
paint([(bt,GREY),(bb,BRO),(ft,GREY),(fb,BRO)])
Image.fromarray(g).save("/tmp/gait/coded_blocks.png")
Image.fromarray(g).resize((W*8,H*8),Image.NEAREST).save("/tmp/gait/coded_big.png")
