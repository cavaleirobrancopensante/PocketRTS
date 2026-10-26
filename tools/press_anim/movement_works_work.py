from PIL import Image
import numpy as np, math
exec(open('mw_key.py').read().split("frames=[]")[0])   # gives cell, base (key erased), bow, bm, AX, BX0, BY0
B=np.array(base).astype(int)
lum=B.sum(2)
# body sprite: the second hanging body, below the rail
bx0,by0,bx1,by1=117,298,153,374
from scipy import ndimage as _n
body=B[by0:by1,bx0:bx1].copy(); bmask=_n.binary_dilation(body.sum(2)>150,iterations=1)
_yy=np.arange(by1-by0)[:,None]; bmask&=np.ones_like(bmask)
bc=((bx0+bx1)/2,by0)                 # hang point of that body
STEP=np.array([33.0,15.0])
# erase all four bodies: dilated masks, filled by interpolating each row across the hole
from scipy import ndimage as ndi
clean=B.copy()
EM=np.zeros(B.shape[:2],bool)
for (x0,y0,x1,y1) in [(84,283,121,358),(117,298,153,370),(150,314,187,385)]:
    m=np.zeros(B.shape[:2],bool); m[y0:y1,x0:x1]=B[y0:y1,x0:x1].sum(2)>150
    m=ndi.binary_dilation(m,iterations=2)&(np.mgrid[0:B.shape[0],0:B.shape[1]][0]<y1)
    # keep the rail: only below the rail line through the hang points
    yy,xx=np.mgrid[0:B.shape[0],0:B.shape[1]]
    m&=yy>(298+(xx-135)*15/33.0+3)
    EM|=m
_rng=np.random.default_rng(3)
clean[EM]=np.array([20,17,24])+_rng.integers(-3,4,(int(EM.sum()),1))
# foreground parts that stand in front of the line (pasted back on top)
def fg(box,th=150):
    x0,y0,x1,y1=box; m=np.zeros(B.shape[:2],bool); sub=B[y0:y1,x0:x1].sum(2)>th; m[y0:y1,x0:x1]=sub; return m
FG=fg((38,240,82,430),90)|fg((187,318,226,425),90)|fg((250,330,282,430),90)|fg((60,382,270,440),90)
PRESS=(187,318,226,372)
def frame(i):
    t0=i/8.0; u=0.0 if t0<0.5 else (t0-0.5)*2; t=u*u*(3-2*u)   # hold, then step one slot
    f=clean.copy()
    # press stamp: down on frames 2-4
    d=[0,0,0,0,1,5,9,4][i]
    # bodies sliding along the rail, one slot every 8 frames
    for k in range(-2,6):
        p=np.array(bc)+(k-1+t)*STEP
        if not (70<p[0]<285): continue
        x=int(round(p[0]-(bx1-bx0)/2)); y=int(round(p[1]))
        if p[0]>=196: continue
        al=float(np.clip(1-(p[0]-168)/14.0,0,1))   # the leading body fades into the press as it is stamped
        w=min(body.shape[1],186-x)
        if w<=0: continue
        sub=f[y:y+body.shape[0],x:x+w]
        h=sub.shape[0]
        mm=bmask[:h,:w]
        sub[mm]=(al*body[:h,:w][mm]+(1-al)*sub[mm])
    # parts in front go back on top (posts, beam, press frame) except the moving press head
    keep=FG.copy(); x0,y0,x1,y1=PRESS; keep[y0:y1,x0:x1]=False
    f[keep]=B[keep]
    # the press head on top, shifted by d
    blk=B[y0:y1,x0:x1]; pm=blk.sum(2)>90
    sub=f[y0+d:y1+d,x0:x1]; sub[pm]=blk[pm]
    img=Image.fromarray(f.astype('uint8'))
    # the key
    th=math.pi*i/8; c=math.cos(th); w=max(0.13,abs(c)); bw=max(3,int(bow.width*w))
    bi=bow.resize((bw,bow.height),Image.LANCZOS); mi=bm.resize((bw,bow.height),Image.LANCZOS)
    if c<0: bi=bi.transpose(Image.FLIP_LEFT_RIGHT); mi=mi.transpose(Image.FLIP_LEFT_RIGHT)
    from PIL import ImageEnhance
    bi=ImageEnhance.Brightness(bi).enhance(0.78+0.22*abs(c))
    img.paste(bi,(int(AX-bw/2),BY0),mi)
    return img
fr=[frame(i) for i in range(8)]
fr[0].save('mw_all7.gif',save_all=True,append_images=fr[1:],duration=140,loop=0)
big=[f.crop((20,60,384,480)).resize((728,840),Image.NEAREST) for f in fr[:4]]
s=Image.new('RGB',(728*4,840)); [s.paste(b,(i*728,0)) for i,b in enumerate(big)]
s.resize((1456,420)).save('mw_all7_strip.png')
