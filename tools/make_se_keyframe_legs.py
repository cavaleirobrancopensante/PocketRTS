"""Owner-requested keyframe for the ChatGPT south-east walk (prompt 37): the labourer from /tmp/gait_blocks.png (a 6px-block sampling of the owner image) with its legs deleted and code legs drawn: an inverted V, the picture-left leg leading (lowest, flat boot), the picture-right leg trailing (higher, heel up), black outline."""
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
# the picture-RIGHT leg: trailing, farther, a little higher on the picture, knee bent, heel up, going to the lower right
bt,bb=leg([(48,93),(52,104)],8,[(52,104),(58,113)],6.5,[(53,108),(62,109),(65,119),(71,125),(71,129),(56,129),(53,121)])
# the picture-LEFT leg: leading, nearer, lowest on the picture, straight, boot flat on the ground, going to the lower left
ft,fb=leg([(38,93),(33,106)],8.5,[(33,106),(27,121)],7,[(21,116),(31,117),(32,127),(36,131),(36,136),(14,136),(14,131),(21,128)])
paint([(bt,GREY),(bb,BRO),(ft,GREY),(fb,BRO)])
Image.fromarray(g).save("/tmp/gait/coded_blocks.png")
Image.fromarray(g).resize((W*8,H*8),Image.NEAREST).save("/tmp/gait/coded_big.png")
